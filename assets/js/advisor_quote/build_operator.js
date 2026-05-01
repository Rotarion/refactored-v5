const crypto = require('crypto');
const fs = require('fs');
const path = require('path');

const rootDir = __dirname;
const srcDir = path.join(rootDir, 'src');
const sourcePath = path.join(srcDir, 'operator.template.js');
const outputPath = path.join(rootDir, 'ops_result.js');
const checkMode = process.argv.includes('--check');

function sha256(buffer) {
  return crypto.createHash('sha256').update(buffer).digest('hex');
}

function readFileBuffer(filePath) {
  try {
    return fs.readFileSync(filePath);
  } catch (error) {
    if (error && error.code === 'ENOENT') return null;
    throw error;
  }
}

function requireRuntimeMarkers(buffer, filePath) {
  const text = buffer.toString('utf8');
  const required = ['@@OP@@', '@@ARGS@@', 'copy(String('];
  const missing = required.filter((marker) => !text.includes(marker));
  if (missing.length) {
    throw new Error(`${filePath} is missing required runtime marker(s): ${missing.join(', ')}`);
  }
}

function escapeRegExp(value) {
  return String(value).replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

function resolveInclude(spec) {
  const raw = String(spec || '').trim();
  const [includePath, snippetName = ''] = raw.split('#');
  if (!includePath || path.isAbsolute(includePath)) {
    throw new Error(`Invalid include path: ${raw}`);
  }
  const resolved = path.resolve(srcDir, includePath);
  const relative = path.relative(srcDir, resolved);
  if (!relative || relative.startsWith('..') || path.isAbsolute(relative)) {
    throw new Error(`Include escapes src directory: ${raw}`);
  }
  return { raw, includePath, snippetName, resolved };
}

function readInclude(spec) {
  const include = resolveInclude(spec);
  const buffer = readFileBuffer(include.resolved);
  if (!buffer) {
    throw new Error(`Missing include: ${include.raw}`);
  }
  if (!include.snippetName) {
    return { include, buffer };
  }
  const text = buffer.toString('utf8');
  const name = escapeRegExp(include.snippetName);
  const pattern = new RegExp(`/\\* @snippet ${name} \\*/\\r?\\n([\\s\\S]*?)/\\* @endsnippet \\*/\\r?\\n?`);
  const match = text.match(pattern);
  if (!match) {
    throw new Error(`Missing snippet "${include.snippetName}" in include: ${include.includePath}`);
  }
  return { include, buffer: Buffer.from(match[1], 'utf8') };
}

function renderTemplate(templateBuffer) {
  const included = [];
  const template = templateBuffer.toString('utf8');
  const rendered = template.replace(/^[ \t]*\/\* @include ([^*]+?) \*\/\r?\n?/gm, (marker, spec) => {
    const { include, buffer } = readInclude(spec);
    included.push(include);
    return buffer.toString('utf8');
  });
  return { buffer: Buffer.from(rendered, 'utf8'), included };
}

function formatIncludes(included) {
  if (!included.length) return '(none)';
  const seen = new Set();
  const names = [];
  for (const include of included) {
    const label = include.snippetName
      ? `${include.includePath}#${include.snippetName}`
      : include.includePath;
    if (seen.has(label)) continue;
    seen.add(label);
    names.push(label);
  }
  return names.join(', ');
}

function main() {
  const template = readFileBuffer(sourcePath);
  if (!template) {
    console.error(`advisor operator build: missing source ${sourcePath}`);
    process.exit(2);
  }
  const rendered = renderTemplate(template);
  const source = rendered.buffer;
  requireRuntimeMarkers(source, sourcePath);

  const current = readFileBuffer(outputPath);
  const generatedHash = sha256(source);

  if (checkMode) {
    if (!current) {
      console.error(`advisor operator build check: missing output ${outputPath}`);
      process.exit(1);
    }
    const currentHash = sha256(current);
    if (!current.equals(source)) {
      console.error('advisor operator build check: DRIFT detected');
      console.error(`source: ${sourcePath}`);
      console.error(`output: ${outputPath}`);
      console.error(`sourceSha256=${generatedHash}`);
      console.error(`outputSha256=${currentHash}`);
      process.exit(1);
    }
    console.log('advisor operator build check: OK');
    console.log(`output=${outputPath}`);
    console.log(`includes=${formatIncludes(rendered.included)}`);
    console.log(`sha256=${currentHash}`);
    return;
  }

  let status = 'written';
  if (current && current.equals(source)) {
    status = 'unchanged';
  } else {
    fs.writeFileSync(outputPath, source);
  }

  console.log(`advisor operator build: ${status}`);
  console.log(`source=${sourcePath}`);
  console.log(`output=${outputPath}`);
  console.log(`includes=${formatIncludes(rendered.included)}`);
  console.log(`sha256=${generatedHash}`);
}

main();
