/* @snippet text */
  const extractStreetNumber = (value) => ((normalizeAddressText(value).match(/^\d+/) || [])[0]) || '';
  const hasWholeNormalizedToken = (haystack, token) => {
    const text = normalizeAddressText(haystack);
    const wanted = normalizeAddressText(token);
    return !!wanted && new RegExp(`(^|\\s)${wanted}(\\s|$)`).test(text);
  };
/* @endsnippet */

/* @snippet ambiguity */
  const duplicateCandidatesAreAmbiguous = (candidates = []) => {
    if (candidates.length < 2) return false;
    return (candidates[0].score - candidates[1].score) <= 15;
  };
/* @endsnippet */
