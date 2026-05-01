copy(String((() => {
  const op = @@OP@@;
  const args = @@ARGS@@ || {};
  void args;

  switch (String(op || '')) {
    case 'focus_slate_composer': {
      const el = document.querySelector('[data-slate-editor="true"]');
      if (!el) return 'NO_COMPOSER';
      try { el.focus(); } catch {}
      return 'OK_COMPOSER';
    }

    case 'focus_slate_composer_ready': {
      const editors = Array.from(document.querySelectorAll('[data-slate-editor=true]'));
      const el = editors.find((node) => node.offsetParent !== null);
      if (!el) return 'NO_COMPOSER';
      try { el.focus(); } catch {}
      try { el.click(); } catch {}
      return 'OK_COMPOSER';
    }

    default:
      return 'NO_OP';
  }
})()));
