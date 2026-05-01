/* @snippet native */
  const getValueSetter = (el) => {
    if (!el) return null;
    let proto = Object.getPrototypeOf(el);
    while (proto) {
      const desc = Object.getOwnPropertyDescriptor(proto, 'value');
      if (desc && typeof desc.set === 'function') return desc.set;
      proto = Object.getPrototypeOf(proto);
    }
    return null;
  };
  const fireFieldEvents = (el) => {
    if (!el) return;
    try { el.dispatchEvent(new Event('input', { bubbles: true })); } catch {}
    try { el.dispatchEvent(new Event('change', { bubbles: true })); } catch {}
    try { el.dispatchEvent(new Event('blur', { bubbles: true })); } catch {}
  };
  const setNativeValue = (el, value) => {
    if (!el) return false;
    const setter = getValueSetter(el);
    try {
      if (setter) setter.call(el, safe(value));
      else el.value = safe(value);
      return true;
    } catch {
      try {
        el.value = safe(value);
        return true;
      } catch {
        return false;
      }
    }
  };
/* @endsnippet */
