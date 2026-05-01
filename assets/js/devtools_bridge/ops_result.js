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
  const findDoc = (predicate) => {
    for (const doc of walkDocs()) {
      try {
        if (predicate(doc)) return doc;
      } catch {}
    }
    return null;
  };
  const findByIdInDocs = (id) => {
    for (const doc of walkDocs()) {
      try {
        const el = doc.getElementById(id);
        if (el) return el;
      } catch {}
    }
    return null;
  };
  const findSelectorInDocs = (selector, requireVisible = false) => {
    for (const doc of walkDocs()) {
      try {
        const els = Array.from(doc.querySelectorAll(selector));
        const el = requireVisible ? els.find(visible) : els[0];
        if (el) return el;
      } catch {}
    }
    return null;
  };

  const compact = (value, max = 300) =>
    safeText(value)
      .replace(/\s+/g, ' ')
      .replace(/[|\r\n]/g, ' ')
      .trim()
      .slice(0, max);
  const flag = (value) => value ? '1' : '0';
  const visible = (el) => {
    if (!el) return false;
    try { return !!(el.offsetWidth || el.offsetHeight || el.getClientRects().length); }
    catch { return false; }
  };
  const pageUrl = (doc) => {
    try { return safeText(doc?.location?.href || doc?.URL || ''); }
    catch { return ''; }
  };
  const pageTitle = (doc) => {
    try { return safeText(doc?.title || ''); }
    catch { return ''; }
  };
  const bodyText = (doc) => {
    try { return safeText(doc?.body?.innerText || doc?.body?.textContent || ''); }
    catch { return ''; }
  };
  const hasControlText = (el, pattern) => pattern.test([
    el.id,
    el.name,
    el.value,
    el.title,
    el.placeholder,
    el.getAttribute?.('aria-label'),
    el.innerText,
    el.textContent
  ].map(safeText).join(' '));
  const hasFieldLike = (doc, pattern) =>
    Array.from(doc.querySelectorAll('input,select,textarea')).some((el) => hasControlText(el, pattern));
  const hasButtonLike = (doc, pattern) =>
    Array.from(doc.querySelectorAll('button,input[type="button"],input[type="submit"],a')).some((el) => visible(el) && hasControlText(el, pattern));
  const kvLines = (data) =>
    Object.entries(data).map(([key, value]) => `${key}=${compact(value, key === 'evidence' || key === 'missing' ? 800 : 300)}`).join('\n');
  const collectBlitzContexts = () => {
    const seen = new Set();
    const contexts = [];
    let frameCount = 0;
    let accessibleFrameCount = 0;

    const inspect = (doc, path) => {
      if (!doc || seen.has(doc)) return;
      seen.add(doc);

      const url = pageUrl(doc);
      const title = pageTitle(doc);
      const text = bodyText(doc);
      const leadListLinks = Array.from(doc.querySelectorAll("a[id*='lnkProspectLog'], a[title*='View Lead Log']")).filter(visible);
      const hasNextLead = !!doc.querySelector('a#ctl00_ContentPlaceHolder1_lnkNext');
      const hasActionDropdown = !!doc.getElementById('ctl00_ContentPlaceHolder1_DDLogType_Input');
      const hasHistorySave = !!doc.getElementById('ctl00_ContentPlaceHolder1_btnUpdate_input');
      const hasAddAppointment = typeof doc.defaultView?.AppointmentInserting === 'function'
        || !!doc.querySelector('a.js-Lead-Log-Add-New-Appointment');
      const hasAppointmentDate = !!doc.getElementById('ctl00_ContentPlaceHolder1_RadDateTimePicker1_dateInput');
      const hasAppointmentSave = !!doc.getElementById('ctl00_ContentPlaceHolder1_lnkSave_input');
      const hasStatus = !!doc.getElementById('ctl00_ContentPlaceHolder1_ddStatus_Input');
      const hasPhone = hasFieldLike(doc, /\bphone\b/i);
      const hasMobileOrIPhone = hasFieldLike(doc, /\b(?:mobile|iphone|cell)\b/i);
      const hasSaveButton = hasHistorySave || hasAppointmentSave || hasButtonLike(doc, /\b(?:save|update)\b/i);
      const leadListEvidence = /ProspectCompanies\.aspx/i.test(url)
        || (leadListLinks.length > 0 && /lead list/i.test(`${title} ${text}`));
      const leadLogEvidence = /ProspectLog\.aspx/i.test(url)
        || hasNextLead || hasActionDropdown || hasHistorySave || hasAddAppointment || hasStatus;
      const appointmentEvidence = hasAppointmentDate || hasAppointmentSave;

      contexts.push({
        doc,
        path,
        url,
        title,
        leadListLinkCount: leadListLinks.length,
        hasLeadListLinks: leadListLinks.length > 0,
        hasNextLead,
        hasActionDropdown,
        hasHistorySave,
        hasAddAppointment,
        hasAppointmentDate,
        hasAppointmentSave,
        hasPhone,
        hasMobileOrIPhone,
        hasStatus,
        hasSaveButton,
        leadListEvidence,
        leadLogEvidence,
        appointmentEvidence,
        attemptedContactReady: hasActionDropdown && hasHistorySave && hasAddAppointment,
        appointmentReady: hasAppointmentDate && hasAppointmentSave
      });

      for (const [index, frame] of Array.from(doc.querySelectorAll('iframe,frame')).entries()) {
        frameCount += 1;
        try {
          const child = frame.contentDocument || frame.contentWindow?.document;
          if (child) {
            accessibleFrameCount += 1;
            inspect(child, `${path}/frame[${index}]`);
          }
        } catch {}
      }
    };

    inspect(document, 'top');
    return { contexts, frameCount, accessibleFrameCount };
  };

  switch (safeText(op)) {
    case 'bridge_probe':
      return 'OK_BRIDGE';

    case 'blitz_page_status': {
      try {
        const { contexts, frameCount, accessibleFrameCount } = collectBlitzContexts();
        const top = contexts[0] || {};
        const topPage = top.leadListEvidence ? 'lead-list' : (top.leadLogEvidence ? 'lead-log' : 'unknown');
        const leadLogContexts = contexts.filter((ctx) => ctx.leadLogEvidence);
        const appointmentContext = contexts.find((ctx) => ctx.appointmentReady);
        const leadLogContext = leadLogContexts.find((ctx) => ctx.attemptedContactReady) || leadLogContexts[0] || null;
        const actionContext = appointmentContext || leadLogContext || null;
        const actionPage = appointmentContext ? 'appointment-frame' : (leadLogContext ? 'lead-log' : 'none');
        const page = appointmentContext
          ? 'appointment-frame'
          : (topPage === 'lead-list' && leadLogContext && leadLogContext.path !== 'top')
          ? 'lead-list-with-open-lead-log'
          : (leadLogContext && topPage === 'lead-log')
          ? 'lead-log'
          : topPage;

        const isBlitz = contexts.some((ctx) =>
          /blitzleadmanager\.com/i.test(ctx.url)
          || ctx.leadListEvidence
          || ctx.leadLogEvidence
          || ctx.appointmentEvidence
        );
        const evidence = [];
        const missing = [];
        if (top.leadListEvidence) evidence.push('top:lead-list');
        if (top.hasLeadListLinks) evidence.push(`leadListLinks:${top.leadListLinkCount}`);
        if (leadLogContext) evidence.push(`lead-log:${leadLogContext.path}`);
        if (appointmentContext) evidence.push(`appointment-frame:${appointmentContext.path}`);
        if (actionContext?.hasActionDropdown) evidence.push('actionDropdown');
        if (actionContext?.hasHistorySave) evidence.push('historySave');
        if (actionContext?.hasAddAppointment) evidence.push('addAppointment');
        if (actionContext?.hasNextLead) evidence.push('nextLead');
        if (actionContext?.hasStatus) evidence.push('status');
        if (actionContext?.hasAppointmentDate) evidence.push('appointmentDate');
        if (actionContext?.hasAppointmentSave) evidence.push('appointmentSave');

        if (actionPage === 'lead-log') {
          if (!actionContext.hasActionDropdown) missing.push('actionDropdown');
          if (!actionContext.hasHistorySave) missing.push('historySave');
          if (!actionContext.hasAddAppointment) missing.push('addAppointment');
        } else if (actionPage === 'appointment-frame') {
          if (!actionContext.hasAppointmentDate) missing.push('appointmentDate');
          if (!actionContext.hasAppointmentSave) missing.push('appointmentSave');
        } else if (topPage === 'lead-list') {
          if (!top.hasLeadListLinks) missing.push('leadListLinks');
        } else {
          missing.push('blitzPageEvidence');
        }

        const result = !isBlitz
          ? 'WRONG_PAGE'
          : (page === 'unknown')
          ? 'UNKNOWN'
          : (missing.length === 0)
          ? 'READY'
          : 'NOT_READY';
        const currentLeadTitle = leadLogContext ? leadLogContext.title : '';

        return kvLines({
          result,
          page,
          topPage,
          actionPage,
          url: top.url || '',
          title: top.title || '',
          frameCount,
          accessibleFrameCount,
          actionFramePath: actionContext ? actionContext.path : '',
          actionFrameUrl: actionContext ? actionContext.url : '',
          actionFrameTitle: actionContext ? actionContext.title : '',
          evidence: evidence.join('|'),
          missing: missing.join('|'),
          error: '',
          hasLeadListLinks: flag(top.hasLeadListLinks),
          leadListLinkCount: String(top.leadListLinkCount || 0),
          hasCurrentLeadTitle: flag(currentLeadTitle),
          currentLeadTitle,
          hasNextLead: flag(actionContext?.hasNextLead),
          hasActionDropdown: flag(actionContext?.hasActionDropdown),
          hasHistorySave: flag(actionContext?.hasHistorySave),
          hasAddAppointment: flag(actionContext?.hasAddAppointment),
          hasAppointmentDate: flag(actionContext?.hasAppointmentDate),
          hasAppointmentSave: flag(actionContext?.hasAppointmentSave),
          hasPhone: flag(actionContext?.hasPhone),
          hasMobileOrIPhone: flag(actionContext?.hasMobileOrIPhone),
          hasStatus: flag(actionContext?.hasStatus),
          hasSaveButton: flag(actionContext?.hasSaveButton)
        });
      } catch (err) {
        return kvLines({
          result: 'ERROR',
          page: 'unknown',
          topPage: 'unknown',
          actionPage: 'none',
          url: pageUrl(document),
          title: pageTitle(document),
          frameCount: '',
          accessibleFrameCount: '',
          actionFramePath: '',
          actionFrameUrl: '',
          actionFrameTitle: '',
          evidence: '',
          missing: '',
          error: err?.message || String(err),
          hasLeadListLinks: '0',
          leadListLinkCount: '0',
          hasCurrentLeadTitle: '0',
          currentLeadTitle: '',
          hasNextLead: '0',
          hasActionDropdown: '0',
          hasHistorySave: '0',
          hasAddAppointment: '0',
          hasAppointmentDate: '0',
          hasAppointmentSave: '0',
          hasPhone: '0',
          hasMobileOrIPhone: '0',
          hasStatus: '0',
          hasSaveButton: '0'
        });
      }
    }

    case 'focus_action_dropdown': {
      const el = findByIdInDocs('ctl00_ContentPlaceHolder1_DDLogType_Input');
      if (!el) return 'NO_ACTION';
      return clickEl(el) ? 'OK_ACTION' : 'NO_ACTION';
    }

    case 'save_history_note': {
      const el = findByIdInDocs('ctl00_ContentPlaceHolder1_btnUpdate_input');
      if (!el) return 'NO_SAVE';
      return clickEl(el) ? 'OK_SAVE' : 'NO_SAVE';
    }

    case 'add_new_appointment': {
      const d = findDoc((doc) => typeof doc.defaultView?.AppointmentInserting === 'function')
        || findDoc((doc) => !!doc.querySelector('a.js-Lead-Log-Add-New-Appointment'));
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
      const el = findByIdInDocs('ctl00_ContentPlaceHolder1_RadDateTimePicker1_dateInput');
      if (!el) return 'NO_TIME';
      try { el.focus(); el.select?.(); } catch {}
      return 'OK_TIME';
    }

    case 'save_appointment': {
      const el = findByIdInDocs('ctl00_ContentPlaceHolder1_lnkSave_input');
      if (!el) return 'NO_FINAL';
      return clickEl(el) ? 'OK_FINAL' : 'NO_FINAL';
    }

    case 'get_blitz_current_lead_title': {
      const { contexts } = collectBlitzContexts();
      const leadCtx = contexts.find((ctx) => ctx.attemptedContactReady)
        || contexts.find((ctx) => ctx.leadLogEvidence);
      const leadDoc = leadCtx?.doc || null;
      return safeText(leadDoc?.title || '');
    }

    case 'click_blitz_next_lead': {
      const el = findSelectorInDocs('a#ctl00_ContentPlaceHolder1_lnkNext', true);
      if (!el) return 'NO_NEXT';
      return clickEl(el) ? 'OK_NEXT' : 'NO_NEXT';
    }

    case 'open_blitz_lead_log_by_name': {
      const target = normalize(args.targetName);
      if (!target) return 'NO_MATCH';
      const selector = "a[id*='lnkProspectLog'], a[title*='View Lead Log']";
      const docs = walkDocs();
      for (const doc of docs) {
        const anchors = Array.from(doc.querySelectorAll(selector)).filter((el) => el.offsetParent !== null);
        for (const el of anchors) {
          const rowText = normalize(el.closest('tr')?.innerText || '');
          const text = normalize(el.textContent || '');
          if (text === target || rowText.includes(target))
            return clickEl(el) ? 'OK_OPEN' : 'NO_OPEN';
        }
      }
      return 'NO_MATCH';
    }

    default:
      return 'NO_OP';
  }
})()));
