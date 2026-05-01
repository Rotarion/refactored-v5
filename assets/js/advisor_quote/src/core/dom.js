/* @snippet stable */
  const cssEscape = (value) => {
    const text = safe(value);
    if (globalThis.CSS && typeof CSS.escape === 'function') return CSS.escape(text);
    return text.replace(/\\/g, '\\\\').replace(/"/g, '\\"');
  };
  const isAriaDisabled = (el) => lower(el && el.getAttribute && el.getAttribute('aria-disabled')) === 'true';
  const isDisabledLike = (el) => {
    if (!el) return true;
    if (el.disabled) return true;
    if (el.hidden) return true;
    if (isAriaDisabled(el)) return true;
    const disabledAncestor = el.closest && el.closest('[aria-disabled="true"]');
    return !!disabledAncestor;
  };
  const visible = (el) => {
    if (!el) return false;
    const r = el.getBoundingClientRect();
    const cs = getComputedStyle(el);
    return r.width > 0
      && r.height > 0
      && cs.display !== 'none'
      && cs.visibility !== 'hidden'
      && cs.opacity !== '0'
      && cs.pointerEvents !== 'none'
      && !el.hidden;
  };
  const findByStableId = (id) => {
    const key = safe(id);
    if (!key) return null;
    return document.getElementById(key)
      || document.querySelector(`[data-uid="${cssEscape(key)}"]`)
      || document.querySelector(`[name="${cssEscape(key)}"]`);
  };
/* @endsnippet */

/* @snippet text */
  const getText = (node) => {
    if (typeof node === 'string') return safe(node).replace(/\s+/g, ' ').trim();
    return safe(node ? (node.innerText || node.textContent || '') : '').replace(/\s+/g, ' ').trim();
  };
/* @endsnippet */

/* @snippet page */
  const bodyText = () => lower((document.body && document.body.innerText) || '');
  const pageUrl = () => safe(location.href || '');
/* @endsnippet */

/* @snippet stableVisible */
  const hasStableVisible = (id) => {
    const el = findByStableId(id);
    return !!el && visible(el);
  };
/* @endsnippet */

/* @snippet selectState */
  const readSelectState = (el) => {
    if (!el) return { value: '', text: '' };
    const opt = el.options && el.selectedIndex >= 0 ? el.options[el.selectedIndex] : null;
    return {
      value: safe(el.value).trim(),
      text: getText(opt)
    };
  };
/* @endsnippet */
