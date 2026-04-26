copy(String((() => {
  const op = @@OP@@;
  const args = @@ARGS@@ || {};

  const safeText = (v) => String(v || '');
  const normalize = (value) =>
    safeText(value)
      .replace(/\s+/g, ' ')
      .trim()
      .replace(/^\s*(?:duplicated\s+)?(?:opportunity\s+)?personal\s+lead\s*-\s*/i, '')
      .replace(/\s*\([^)]*\)\s*$/, '')
      .toLowerCase();

  const clickEl = (el) => {
    if (!el) return false;
    try { el.focus(); } catch {}
    try {
      ['mouseover', 'mousedown', 'mouseup', 'click'].forEach((t) =>
        el.dispatchEvent(
          new MouseEvent(t, {
            bubbles: true,
            cancelable: true,
            view: el.ownerDocument?.defaultView || window
          })
        )
      );
    } catch {}
    return true;
  };

  const getFrameDoc = () => document.querySelectorAll('iframe')[0]?.contentDocument || null;
  const walkDocs = () => {
    const seen = new Set();
    const docs = [];
    const walk = (doc) => {
      if (!doc || seen.has(doc)) return;
      seen.add(doc);
      docs.push(doc);
      for (const frame of doc.querySelectorAll('iframe')) {
        try { walk(frame.contentDocument); } catch {}
      }
    };
    walk(document);
    return docs;
  };

  switch (safeText(op)) {
    case 'focus_action_dropdown': {
      const d = getFrameDoc();
      const el = d?.getElementById('ctl00_ContentPlaceHolder1_DDLogType_Input');
      if (!el) return 'NO_ACTION';
      return clickEl(el) ? 'OK_ACTION' : 'NO_ACTION';
    }

    case 'save_history_note': {
      const d = getFrameDoc();
      const el = d?.getElementById('ctl00_ContentPlaceHolder1_btnUpdate_input');
      if (!el) return 'NO_SAVE';
      return clickEl(el) ? 'OK_SAVE' : 'NO_SAVE';
    }

    case 'add_new_appointment': {
      const d = getFrameDoc();
      if (!d) return 'NO_FRAME1';
      if (typeof d.defaultView?.AppointmentInserting === 'function') {
        d.defaultView.AppointmentInserting();
        return 'OK_FUNC';
      }
      const el = d.querySelector('a.js-Lead-Log-Add-New-Appointment');
      if (!el) return 'NO_APPT';
      return clickEl(el) ? 'OK_APPT' : 'NO_APPT';
    }

    case 'focus_date_time_field': {
      const d1 = getFrameDoc();
      const d2 = d1?.querySelectorAll('iframe')[0]?.contentDocument || null;
      const el = d2?.getElementById('ctl00_ContentPlaceHolder1_RadDateTimePicker1_dateInput');
      if (!el) return 'NO_TIME';
      try { el.focus(); el.select?.(); } catch {}
      return 'OK_TIME';
    }

    case 'save_appointment': {
      const d1 = getFrameDoc();
      const d2 = d1?.querySelectorAll('iframe')[0]?.contentDocument || null;
      const el = d2?.getElementById('ctl00_ContentPlaceHolder1_lnkSave_input');
      if (!el) return 'NO_FINAL';
      return clickEl(el) ? 'OK_FINAL' : 'NO_FINAL';
    }

    case 'get_blitz_current_lead_title': {
      const docs = walkDocs();
      const leadDoc = docs.find((doc) =>
        doc?.querySelector?.('a#ctl00_ContentPlaceHolder1_lnkNext') ||
        doc?.getElementById?.('ctl00_ContentPlaceHolder1_DDLogType_Input')
      );
      return safeText(leadDoc?.title || '');
    }

    case 'click_blitz_next_lead': {
      const docs = walkDocs();
      const leadDoc = docs.find((doc) =>
        doc?.querySelector?.('a#ctl00_ContentPlaceHolder1_lnkNext') ||
        doc?.getElementById?.('ctl00_ContentPlaceHolder1_DDLogType_Input')
      );
      const el = leadDoc?.querySelector?.('a#ctl00_ContentPlaceHolder1_lnkNext');
      if (!el || el.offsetParent === null) return 'NO_NEXT';
      return clickEl(el) ? 'OK_NEXT' : 'NO_NEXT';
    }

    case 'open_blitz_lead_log_by_name': {
      const target = normalize(args.targetName);
      if (!target) return 'NO_MATCH';
      const selector = "a[id*='lnkProspectLog'], a[title='View Lead Log']";
      const anchors = Array.from(document.querySelectorAll(selector)).filter((el) => el.offsetParent !== null);
      for (const el of anchors) {
        const rowText = normalize(el.closest('tr')?.innerText || '');
        const text = normalize(el.textContent || '');
        if (text === target || rowText.includes(target))
          return clickEl(el) ? 'OK_OPEN' : 'NO_OPEN';
      }
      return 'NO_MATCH';
    }

    default:
      return 'NO_OP';
  }
})()));
