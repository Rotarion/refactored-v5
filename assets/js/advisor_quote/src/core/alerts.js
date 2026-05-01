  const uniqText = (items) => {
    const seen = new Set();
    const out = [];
    for (const item of items) {
      const text = getText(item);
      if (!text) continue;
      const key = lower(text);
      if (seen.has(key)) continue;
      seen.add(key);
      out.push(text);
    }
    return out;
  };
  const collectVisibleAlerts = () => {
    const nodes = Array.from(document.querySelectorAll(
      '[id^="message_"], .c-alert a, .c-alert__content a, .c-alert__content, .c-alert, [role=alert], [class*=alert], [class*=error], [class*=validation]'
    )).filter(visible);
    const raw = [];
    for (const node of nodes) {
      const text = getText(node);
      if (!text) continue;
      for (const line of text.split(/\r?\n/)) {
        const cleaned = safe(line).replace(/\s+/g, ' ').trim();
        if (cleaned && !/^view all$/i.test(cleaned))
          raw.push(cleaned);
      }
    }
    return uniqText(raw);
  };
