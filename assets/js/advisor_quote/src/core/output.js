  const linesOut = (pairs = {}) => Object.entries(pairs).map(([k, v]) => `${k}=${safe(v)}`).join('\n');
  const isSuccessValue = (v, allowSkip = false) => {
    const raw = safe(v).toUpperCase();
    return v === true || raw === '1' || raw === 'OK' || (allowSkip && raw === 'SKIP');
  };
  const normalizeCheck = (check) => {
    if (typeof check === 'boolean')
      return { name: '', ok: check, allowSkip: false };
    if (!check || typeof check !== 'object')
      return { name: '', ok: false, allowSkip: false };
    return {
      name: safe(check.name),
      ok: ('ok' in check) ? !!check.ok : isSuccessValue(check.value, !!check.allowSkip),
      allowSkip: !!check.allowSkip,
      value: check.value
    };
  };
  const resultFromChecks = (requiredChecks = [], optionalChecks = []) => {
    const required = requiredChecks.map(normalizeCheck);
    const optional = optionalChecks.map(normalizeCheck);
    if (!required.every((check) => check.ok))
      return 'FAILED';
    return optional.every((check) => check.ok) ? 'OK' : 'PARTIAL';
  };
  const failedCheckNames = (checks = []) => checks
    .map(normalizeCheck)
    .filter((check) => !check.ok && check.name)
    .map((check) => check.name);
