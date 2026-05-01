/* @snippet basic */
  const dispatchPointerSequence = (el) => {
    const common = { bubbles: true, cancelable: true, composed: true, button: 0, buttons: 1 };
    try { el.dispatchEvent(new PointerEvent('pointerdown', common)); } catch {}
    try { el.dispatchEvent(new MouseEvent('mousedown', common)); } catch {}
    try { el.dispatchEvent(new PointerEvent('pointerup', common)); } catch {}
    try { el.dispatchEvent(new MouseEvent('mouseup', common)); } catch {}
  };
  const clickEl = (el, options = {}) => {
    if (!el || !visible(el) || isDisabledLike(el)) return false;
    try { el.scrollIntoView({ block: 'center', inline: 'center' }); } catch {}
    try { el.focus({ preventScroll: true }); } catch {
      try { el.focus(); } catch {}
    }
    const tag = safe(el.tagName);
    const role = lower(el.getAttribute && el.getAttribute('role'));
    const needsPointerSequence = options.preClickSequence === true
      || (!/^(BUTTON|A|INPUT|LABEL|OPTION|SELECT|TEXTAREA)$/i.test(tag)
        && /^(button|radio|checkbox|option|switch|tab)$/.test(role));
    if (needsPointerSequence)
      dispatchPointerSequence(el);
    try {
      el.click();
      return true;
    } catch {
      return false;
    }
  };
/* @endsnippet */

/* @snippet target */
  const isClickableLike = (node) => {
    if (!node || !visible(node)) return false;
    const tag = safe(node.tagName);
    const role = lower(node.getAttribute && node.getAttribute('role'));
    const cls = lower(node.className || '');
    const tabIndex = Number(node.tabIndex);
    return tag === 'BUTTON'
      || tag === 'A'
      || tag === 'LABEL'
      || role === 'button'
      || role === 'radio'
      || role === 'checkbox'
      || tabIndex >= 0
      || /button|btn|radio|toggle|choice|option|answer|pill|segment|chip|card/.test(cls);
  };
  const findClickableTarget = (node) => {
    let current = node;
    for (let depth = 0; depth < 7 && current; depth++, current = current.parentElement) {
      if (isClickableLike(current)) return current;
    }
    return node;
  };
  const clickCenterEl = (el) => {
    if (!el || !visible(el) || isDisabledLike(el)) return false;
    try { el.scrollIntoView({ block: 'center', inline: 'center' }); } catch {}
    const rect = el.getBoundingClientRect();
    const x = rect.left + (rect.width / 2);
    const y = rect.top + (rect.height / 2);
    const fromPoint = document.elementFromPoint(x, y);
    const target = findClickableTarget(fromPoint && visible(fromPoint) ? fromPoint : el);
    return clickEl(target || el, { preClickSequence: !!target && target !== el });
  };
/* @endsnippet */
