/* @snippet base */
  const safe = (v) => String(v ?? '');
  const compact = (v, max = 240) => safe(v).replace(/\r?\n+/g, ' ').replace(/\s+/g, ' ').trim().slice(0, max);
  const lower = (v) => safe(v).toLowerCase();
  const normUpper = (v) => safe(v).toUpperCase().replace(/[^A-Z0-9 ]/g, ' ').replace(/\s+/g, ' ').trim();
  const normLower = (v) => safe(v).toLowerCase().replace(/[^a-z0-9 ]/g, ' ').replace(/\s+/g, ' ').trim();
/* @endsnippet */

/* @snippet normalize */
  const normalizeDigits = (value) => safe(value).replace(/\D/g, '');
  const normalizePhoneKey = (value) => {
    const digits = normalizeDigits(value);
    return digits.length > 10 ? digits.slice(-10) : digits;
  };
  const normalizeDobKey = (value) => normalizeDigits(value);
  const normalizeEmailKey = (value) => lower(value).trim();
  const normalizeAddressText = (value) => normUpper(value)
    .replace(/\b(APT|APARTMENT|UNIT|STE|SUITE)\b/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
  const includesText = (haystack, expected) => {
    const needle = lower(expected);
    return !!needle && haystack.includes(needle);
  };
  const matchesNormalizedValue = (actual, wanted) => {
    const actualNorm = normUpper(actual);
    const wantedNorm = normUpper(wanted);
    return !!wantedNorm && (actualNorm === wantedNorm || actualNorm.includes(wantedNorm));
  };
  const exactNormalizedValue = (actual, wanted) => {
    const actualNorm = normUpper(actual);
    const wantedNorm = normUpper(wanted);
    return !!wantedNorm && actualNorm === wantedNorm;
  };
/* @endsnippet */
