/* @snippet scoring */
  const normalizeVehicleText = (value) => normUpper(value)
    .replace(/\bF[\s-]+(\d{3,4})\b/g, 'F$1')
    .replace(/\bMODEL[\s-]+(\d)\b/g, 'MODEL $1');
  const normalizeVehicleVin = (value) => normUpper(value).replace(/[^A-Z0-9]/g, '');
  const getVehicleMatchArgs = (source = {}) => {
    const vin = normalizeVehicleVin(source.vin);
    const vinSuffix = normalizeVehicleVin(source.vinSuffix || (vin ? vin.slice(-6) : ''));
    return {
      year: safe(source.year).trim(),
      make: normalizeVehicleText(source.make),
      model: normalizeVehicleText(source.model),
      trim: normalizeVehicleText(source.trim || source.trimHint),
      vin,
      vinSuffix
    };
  };
  const scoreVehicleCandidate = (cardText, source = {}) => {
    const match = getVehicleMatchArgs(source);
    const haystack = normalizeVehicleText(cardText);
    const yearMatch = !!match.year && new RegExp(`(^|\\s)${match.year}(\\s|$)`).test(haystack);
    const makeMatch = !!match.make && haystack.includes(match.make);
    const modelMatch = !!match.model && haystack.includes(match.model);
    const trimMatch = !!match.trim && haystack.includes(match.trim);
    const vinMatch = !!match.vin && haystack.includes(match.vin);
    const vinSuffixMatch = !vinMatch && !!match.vinSuffix && haystack.includes(match.vinSuffix);
    let score = 0;
    if (yearMatch) score += 40;
    if (makeMatch) score += 30;
    if (modelMatch) score += 30;
    if (trimMatch) score += 10;
    if (vinMatch || vinSuffixMatch) score += 50;
    return {
      score,
      threshold: 90,
      yearMatch,
      makeMatch,
      modelMatch,
      trimMatch,
      vinMatch,
      vinSuffixMatch
    };
  };
/* @endsnippet */

/* @snippet ambiguity */
  const vehicleCandidatesAreAmbiguous = (candidates = []) => {
    if (candidates.length < 2) return false;
    return (candidates[0].details.score - candidates[1].details.score) <= 10;
  };
/* @endsnippet */

/* @snippet summarize */
  const summarizeVehicleCandidate = (candidate) => compact(candidate && candidate.cardText, 140);
/* @endsnippet */
