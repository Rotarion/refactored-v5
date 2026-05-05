const fs = require('fs');
const path = require('path');

const repoRoot = path.resolve(__dirname, '..');
const sourcePath = path.join(repoRoot, 'data', 'vehicle_db_compact.json');
const outputPath = path.join(repoRoot, 'data', 'vehicle_db_runtime_index.tsv');

const normalizeText = (value) => String(value || '')
  .toUpperCase()
  .replace(/&/g, ' AND ')
  .replace(/[^A-Z0-9]+/g, ' ')
  .trim()
  .replace(/\s+/g, ' ');

const modelKey = (value) => normalizeText(value).replace(/[^A-Z0-9]/g, '');

const canonicalMakeFamily = (make) => {
  const text = normalizeText(make);
  if (['TOY', 'TOY TRUCKS', 'TOYOTA TRUCKS'].includes(text)) return 'TOYOTA';
  if (String(make || '').toUpperCase() === 'TOY. TRUCKS') return 'TOYOTA';
  if (['CHEVY', 'CHEVY TRUCKS', 'CHEVY VANS'].includes(text)) return 'CHEVROLET';
  if (['MERCEDES', 'MERCEDES BENZ', 'MERCEDES BNZ', 'MERCEDES-BNZ', 'MB'].includes(text)) return 'MERCEDES BENZ';
  if (['FORD TRUCKS', 'FORD VANS'].includes(text)) return 'FORD';
  if (['DODGE TRUCKS', 'DODGE VANS'].includes(text)) return 'DODGE';
  if (['RAM TRUCKS', 'RAM VANS'].includes(text)) return 'RAM';
  return text;
};

const canonicalModel = (model) => {
  let text = normalizeText(model)
    .replace(/\bF\s+(150|250|350|450)\b/g, 'F$1')
    .replace(/\bCR\s+V\b/g, 'CRV')
    .replace(/\bHR\s+V\b/g, 'HRV')
    .replace(/\bCX\s+30\b/g, 'CX30')
    .replace(/\bQX\s+56\b/g, 'QX56')
    .replace(/\bGLE\s+350\b/g, 'GLE350')
    .replace(/\b4\s+RUNNER\b/g, '4RUNNER')
    .replace(/\bGRAND\s+CARAVN\b/g, 'GRAND CARAVAN')
    .replace(/\bSILV\s*(1500|2500|3500)\b/g, 'SILVERADO $1');

  let match = text.match(/^(F(?:150|250|350|450))(?:\s+(?:2WD|4WD))?$/);
  if (match) return match[1];
  match = text.match(/^SILV(?:ERADO)?\s*(1500|2500|3500)(?:\s+(?:2WD|4WD))?$/);
  if (match) return `SILVERADO ${match[1]}`;
  match = text.match(/^(1500|2500|3500)(?:\s+(?:2WD|4WD))?$/);
  if (match) return match[1];
  return text;
};

const aliasSetFor = (indexes, year, makeNorm, model) => {
  const aliases = new Set([normalizeText(model), canonicalModel(model)]);
  const key = modelKey(canonicalModel(model));

  if (/^F(150|250|350|450)$/.test(key)) {
    const series = key.slice(1);
    aliases.add(`F${series}`);
    aliases.add(`F ${series}`);
    aliases.add(`F-${series}`);
  }
  if (key === 'CRV') {
    aliases.add('CR-V');
    aliases.add('CR V');
    aliases.add('CRV');
  }
  if (key === 'HRV') {
    aliases.add('HR-V');
    aliases.add('HR V');
    aliases.add('HRV');
  }
  if (key === 'CX30') {
    aliases.add('CX-30');
    aliases.add('CX 30');
    aliases.add('CX30');
  }
  if (key === '4RUNNER') {
    aliases.add('4RUNNER');
    aliases.add('4 RUNNER');
  }

  const subKey = `${year}|${makeNorm}|${normalizeText(model).toLowerCase()}`;
  const subRows = (indexes.subModelsByYearMakeModel && indexes.subModelsByYearMakeModel[subKey]) || [];
  const subText = subRows
    .map((row) => [row.subModel, row.trim, row.subModelValue].filter(Boolean).join(' '))
    .join(' ')
    .toUpperCase();
  if (key === 'WRANGLER' && /\bUNLTD\b|\bUNLIMITED\b|\bUNLIMITE\b/.test(subText)) {
    aliases.add('WRANGLER UNLIMITED');
    aliases.add('WRANGLER UNLIMITE');
    aliases.add('WRANGLER UNLTD');
  }
  if (key === 'PRIUS' && /\bPRIME\b/.test(subText)) {
    aliases.add('PRIUS PRIME');
  }
  return [...aliases].filter(Boolean).sort();
};

const db = JSON.parse(fs.readFileSync(sourcePath, 'utf8'));
const indexes = db.indexes || {};
const rows = [];
const years = new Set();
const makes = new Set();
const models = new Set();

for (const [yearMake, modelList] of Object.entries(indexes.modelsByYearMake || {})) {
  const [year, makeNorm] = yearMake.split('|');
  years.add(year);
  const makeOptions = (indexes.manufacturerOptionsByYear && indexes.manufacturerOptionsByYear[year]) || [];
  const makeLabel = (makeOptions.find((option) => normalizeText(option.norm || option.text || option.value).toLowerCase() === makeNorm) || {}).text
    || makeNorm.toUpperCase();
  const makeFamily = canonicalMakeFamily(makeLabel);

  for (const model of modelList) {
    const dbModel = normalizeText(model);
    if (!dbModel || /^(SELECT ONE|ALL MODELS)$/.test(dbModel)) continue;
    const canonical = canonicalModel(model);
    const aliases = aliasSetFor(indexes, year, makeNorm, model);
    rows.push([
      'RECORD',
      year,
      makeLabel,
      makeFamily,
      dbModel,
      canonical,
      modelKey(dbModel),
      modelKey(canonical),
      aliases.join('|'),
      aliases.map(modelKey).join('|')
    ]);
    makes.add(makeLabel);
    models.add(canonical);
  }
}

rows.sort((a, b) => a.slice(1, 5).join('\t').localeCompare(b.slice(1, 5).join('\t')));
const sortedYears = [...years].map(Number).sort((a, b) => a - b);
const lines = [
  '# advisor_vehicle_db_runtime_index_v1',
  ['META', 'sourcePath', 'data/vehicle_db_compact.json'].join('\t'),
  ['META', 'sourceRows', String((db.meta && db.meta.sourceRows) || '')].join('\t'),
  ['META', 'yearMin', String(sortedYears[0] || '')].join('\t'),
  ['META', 'yearMax', String(sortedYears[sortedYears.length - 1] || '')].join('\t'),
  ['META', 'yearCount', String(sortedYears.length)].join('\t'),
  ['META', 'makeCount', String(makes.size)].join('\t'),
  ['META', 'modelCount', String(models.size)].join('\t'),
  ['META', 'recordCount', String(rows.length)].join('\t')
];

fs.writeFileSync(outputPath, `${lines.concat(rows.map((row) => row.join('\t'))).join('\n')}\n`);
console.log(JSON.stringify({
  outputPath: path.relative(repoRoot, outputPath).replace(/\\/g, '/'),
  bytes: fs.statSync(outputPath).size,
  recordCount: rows.length,
  yearMin: sortedYears[0],
  yearMax: sortedYears[sortedYears.length - 1],
  makeCount: makes.size,
  modelCount: models.size
}, null, 2));
