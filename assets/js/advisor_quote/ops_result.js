copy(String((() => {
  const op = @@OP@@;
  const args = @@ARGS@@ || {};

  const safe = (v) => String(v ?? '');
  const lower = (v) => safe(v).toLowerCase();
  const normUpper = (v) => safe(v).toUpperCase().replace(/[^A-Z0-9 ]/g, ' ').replace(/\s+/g, ' ').trim();
  const normLower = (v) => safe(v).toLowerCase().replace(/[^a-z0-9 ]/g, ' ').replace(/\s+/g, ' ').trim();
  const cssEscape = (value) => {
    const text = safe(value);
    if (globalThis.CSS && typeof CSS.escape === 'function') return CSS.escape(text);
    return text.replace(/\\/g, '\\\\').replace(/"/g, '\\"');
  };
  const visible = (el) => {
    if (!el) return false;
    const r = el.getBoundingClientRect();
    const cs = getComputedStyle(el);
    return r.width > 0 && r.height > 0 && cs.display !== 'none' && cs.visibility !== 'hidden' && cs.opacity !== '0';
  };
  const findByStableId = (id) => {
    const key = safe(id);
    if (!key) return null;
    return document.getElementById(key)
      || document.querySelector(`[data-uid="${cssEscape(key)}"]`)
      || document.querySelector(`[name="${cssEscape(key)}"]`);
  };
  const clickEl = (el) => {
    if (!el || !visible(el) || el.disabled) return false;
    try { el.scrollIntoView({ block: 'center' }); } catch {}
    try { el.focus(); } catch {}
    try { el.dispatchEvent(new PointerEvent('pointerdown', { bubbles: true })); } catch {}
    try { el.dispatchEvent(new MouseEvent('mousedown', { bubbles: true })); } catch {}
    try { el.dispatchEvent(new PointerEvent('pointerup', { bubbles: true })); } catch {}
    try { el.dispatchEvent(new MouseEvent('mouseup', { bubbles: true })); } catch {}
    try { el.click(); } catch {}
    try { el.dispatchEvent(new MouseEvent('click', { bubbles: true })); } catch {}
    try {
      if (el.form && typeof el.form.requestSubmit === 'function' && /^(submit|button)$/i.test(safe(el.type)))
        el.form.requestSubmit(el);
    } catch {}
    return true;
  };
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
  const getText = (node) => {
    if (typeof node === 'string') return safe(node).replace(/\s+/g, ' ').trim();
    return safe(node ? (node.innerText || node.textContent || '') : '').replace(/\s+/g, ' ').trim();
  };
  const setInputValue = (el, value, onlyIfBlank = false) => {
    if (!el || !visible(el) || el.disabled || el.readOnly) return false;
    const current = safe(el.value).trim();
    if (onlyIfBlank && current !== '') return true;
    try { el.focus(); } catch {}
    if (!setNativeValue(el, value)) return false;
    fireFieldEvents(el);
    return true;
  };
  const setSelectValue = (el, value, onlyIfBlank = false) => {
    if (!el || !visible(el) || el.disabled) return false;
    const current = safe(el.value).trim();
    if (onlyIfBlank && current !== '') return true;
    const wanted = safe(value).trim();
    let option = Array.from(el.options || []).find((opt) => safe(opt.value) === wanted) || null;
    if (!option) {
      const wantedText = normUpper(wanted);
      option = Array.from(el.options || []).find((opt) => {
        const text = normUpper(opt.text || opt.innerText || '');
        return !!wantedText && (text === wantedText || text.includes(wantedText));
      }) || null;
    }
    if (!option) return false;
    try { el.focus(); } catch {}
    if (!setNativeValue(el, option.value)) return false;
    try { el.value = option.value; } catch {}
    fireFieldEvents(el);
    return safe(el.value) === safe(option.value);
  };
  const bodyText = () => lower((document.body && document.body.innerText) || '');
  const pageUrl = () => safe(location.href || '');
  const includesText = (haystack, expected) => {
    const needle = lower(expected);
    return !!needle && haystack.includes(needle);
  };
  const getUrlArgs = (source = {}) => {
    const urls = source.urls || {};
    return {
      rapportContains: safe(urls.rapportContains || source.rapportContains),
      customerSummaryContains: safe(urls.customerSummaryContains || source.customerSummaryContains),
      productOverviewContains: safe(urls.productOverviewContains || source.productOverviewContains),
      selectProductContains: safe(urls.selectProductContains || source.selectProductContains),
      ascProductContains: safe(urls.ascProductContains || source.ascProductContains)
    };
  };
  const getTextArgs = (source = {}) => {
    const texts = source.texts || {};
    return {
      duplicateHeading: safe(texts.duplicateHeading || source.duplicateHeading),
      customerSummaryStartHereText: safe(texts.customerSummaryStartHereText || source.customerSummaryStartHereText),
      customerSummaryQuoteHistoryText: safe(texts.customerSummaryQuoteHistoryText || source.customerSummaryQuoteHistoryText),
      customerSummaryAssetsDetailsText: safe(texts.customerSummaryAssetsDetailsText || source.customerSummaryAssetsDetailsText),
      productOverviewHeading: safe(texts.productOverviewHeading || source.productOverviewHeading),
      productOverviewAutoTile: safe(texts.productOverviewAutoTile || source.productOverviewAutoTile),
      productOverviewContinueText: safe(texts.productOverviewContinueText || source.productOverviewContinueText),
      incidentsHeading: safe(texts.incidentsHeading || source.incidentsHeading)
    };
  };
  const getSelectorArgs = (source = {}) => {
    const selectors = source.selectors || {};
    return {
      advisorQuotingButtonId: safe(selectors.advisorQuotingButtonId || source.advisorQuotingButtonId),
      searchCreateNewProspectId: safe(selectors.searchCreateNewProspectId || source.searchCreateNewProspectId),
      beginQuotingContinueId: safe(selectors.beginQuotingContinueId || source.beginQuotingContinueId),
      sidebarAddProductId: safe(selectors.sidebarAddProductId || source.sidebarAddProductId),
      quoteBlockAddProductId: safe(selectors.quoteBlockAddProductId || source.quoteBlockAddProductId),
      createQuotesButtonId: safe(selectors.createQuotesButtonId || source.createQuotesButtonId),
      selectProductProductId: safe(selectors.selectProductProductId || source.selectProductProductId),
      selectProductRatingStateId: safe(selectors.selectProductRatingStateId || source.selectProductRatingStateId),
      selectProductContinueId: safe(selectors.selectProductContinueId || source.selectProductContinueId)
    };
  };
  const hasStableVisible = (id) => {
    const el = findByStableId(id);
    return !!el && visible(el);
  };
  const isCustomerSummaryOverviewPage = (source = {}) => {
    const url = pageUrl();
    const text = bodyText();
    const urls = getUrlArgs(source);
    const texts = getTextArgs(source);
    const byUrl = !!urls.customerSummaryContains
      && url.includes(urls.customerSummaryContains)
      && url.includes('/overview');
    const hasStartHere = includesText(text, texts.customerSummaryStartHereText || 'START HERE (Pre-fill included)');
    const hasSummaryAnchors = includesText(text, texts.customerSummaryQuoteHistoryText || 'Quote History')
      || includesText(text, texts.customerSummaryAssetsDetailsText || 'Assets Details');
    return byUrl && hasStartHere && hasSummaryAnchors;
  };
  const isProductOverviewPage = (source = {}) => {
    const url = pageUrl();
    const text = bodyText();
    const urls = getUrlArgs(source);
    const texts = getTextArgs(source);
    const selectors = getSelectorArgs(source);
    const byUrl = !!urls.productOverviewContains && url.includes(urls.productOverviewContains);
    const byText = includesText(text, texts.productOverviewHeading || 'Select Product')
      && includesText(text, texts.productOverviewAutoTile || 'Auto')
      && includesText(text, texts.productOverviewContinueText || 'Save & Continue to Gather Data')
      && !hasStableVisible(selectors.beginQuotingContinueId);
    return byUrl && byText && !isCustomerSummaryOverviewPage(source);
  };
  const isSelectProductFormPage = (source = {}) => {
    const url = pageUrl();
    const text = bodyText();
    const urls = getUrlArgs(source);
    const texts = getTextArgs(source);
    const selectors = getSelectorArgs(source);
    const hasFormControls = hasStableVisible(selectors.selectProductProductId)
      || hasStableVisible(selectors.selectProductRatingStateId)
      || hasStableVisible(selectors.selectProductContinueId);
    const byUrl = !!urls.selectProductContains && url.includes(urls.selectProductContains);
    const byText = includesText(text, texts.productOverviewHeading || 'Select Product') && hasFormControls;
    return !isProductOverviewPage(source) && (byUrl || byText);
  };
  const isGatherDataPage = (source = {}) => {
    const url = pageUrl();
    const text = bodyText();
    const urls = getUrlArgs(source);
    const hasVehicleField = !!document.querySelector('input[id*="ConsumerData.Assets.Vehicles["],select[id*="ConsumerData.Assets.Vehicles["]');
    const hasGatherMarkers = text.includes('add car or truck') || hasVehicleField;
    return (!!urls.rapportContains && url.includes(urls.rapportContains))
      || (!isProductOverviewPage(source) && text.includes('gather data') && hasGatherMarkers);
  };
  const findOverviewProductTileTarget = (wantedText) => {
    const target = normLower(wantedText);
    if (!target) return null;
    const nodes = Array.from(document.querySelectorAll('button,a,[role=button],label,div,span,h1,h2,h3,h4,h5,p,li'))
      .filter(visible);
    const pickTarget = (node) => {
      let current = node;
      for (let depth = 0; depth < 6 && current; depth++, current = current.parentElement) {
        if (!visible(current)) continue;
        const cls = lower(current.className || '');
        const role = lower(current.getAttribute && current.getAttribute('role'));
        const tag = safe(current.tagName);
        const tabIndex = Number(current.tabIndex);
        if (tag === 'BUTTON' || tag === 'A' || tag === 'LABEL' || role === 'button' || tabIndex >= 0 || /product|tile|card|option|choice|select|grid|item/.test(cls))
          return current;
      }
      return node;
    };
    const exact = nodes.find((node) => normLower(node.innerText || node.textContent || '') === target);
    if (exact) return pickTarget(exact);
    const startsWith = nodes.find((node) => {
      const text = normLower(node.innerText || node.textContent || '');
      return text.startsWith(target) && text.length <= 80;
    });
    if (startsWith) return pickTarget(startsWith);
    return null;
  };
  const linesOut = (pairs = {}) => Object.entries(pairs).map(([k, v]) => `${k}=${safe(v)}`).join('\n');
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
  const readSelectState = (el) => {
    if (!el) return { value: '', text: '' };
    const opt = el.options && el.selectedIndex >= 0 ? el.options[el.selectedIndex] : null;
    return {
      value: safe(el.value).trim(),
      text: getText(opt)
    };
  };
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
    if (!el || !visible(el) || el.disabled) return false;
    try { el.scrollIntoView({ block: 'center' }); } catch {}
    const rect = el.getBoundingClientRect();
    const x = rect.left + (rect.width / 2);
    const y = rect.top + (rect.height / 2);
    const fromPoint = document.elementFromPoint(x, y);
    const target = findClickableTarget(fromPoint && visible(fromPoint) ? fromPoint : el);
    return clickEl(target || el);
  };
  const isSelectedNode = (node) => {
    if (!node) return false;
    if (/^(INPUT|OPTION)$/i.test(safe(node.tagName)) && 'checked' in node && node.checked) return true;
    if (safe(node.getAttribute && node.getAttribute('aria-checked')) === 'true') return true;
    if (safe(node.getAttribute && node.getAttribute('aria-pressed')) === 'true') return true;
    if (safe(node.getAttribute && node.getAttribute('aria-selected')) === 'true') return true;
    if (/selected|active|checked|current|chosen|pressed|on/.test(lower(node.className || ''))) return true;
    if (/selected|active|checked|on|true/.test(lower(node.getAttribute && node.getAttribute('data-state')))) return true;
    const checkedDescendant = node.querySelector && node.querySelector('input:checked,[aria-checked="true"],[aria-selected="true"],[aria-pressed="true"]');
    return !!checkedDescendant;
  };
  const readInputLabel = (input) => {
    if (!input) return '';
    const inputId = safe(input.id);
    if (inputId) {
      const byFor = document.querySelector(`label[for="${cssEscape(inputId)}"]`);
      if (byFor) return getText(byFor);
    }
    const parentLabel = input.closest('label');
    if (parentLabel) return getText(parentLabel);
    const row = input.closest('[class*=field],[class*=form],[class*=question],.l-grid__col,div');
    if (row) {
      const rowLabel = row.querySelector('label,.c-label,legend');
      if (rowLabel) return getText(rowLabel);
    }
    return getText(input);
  };
  const getInputClickTarget = (input) => {
    if (!input) return null;
    const inputId = safe(input.id);
    if (inputId) {
      const byFor = document.querySelector(`label[for="${cssEscape(inputId)}"]`);
      if (visible(byFor)) return findClickableTarget(byFor);
    }
    const parentLabel = input.closest('label');
    if (visible(parentLabel)) return findClickableTarget(parentLabel);
    let current = input.parentElement;
    for (let depth = 0; depth < 6 && current; depth++, current = current.parentElement) {
      if (!visible(current)) continue;
      const text = normLower(getText(current));
      if (text.includes('yes') || text.includes('no') || isClickableLike(current))
        return current;
    }
    return visible(input) ? input : null;
  };
  const setRadioByName = (namePart, value) => {
    const wanted = normUpper(value);
    const radios = Array.from(document.querySelectorAll('input[type=radio]'));
    const match = radios.find((el) => {
      const nameHit = safe(el.name).includes(safe(namePart));
      const valueHit = normUpper(el.value) === wanted || normUpper(readInputLabel(el)) === wanted;
      return nameHit && valueHit;
    });
    if (!match) return { ok: false, method: 'no-radio-match' };
    if (match.checked) return { ok: true, method: 'already-checked' };
    const target = getInputClickTarget(match);
    if (!target) return { ok: false, method: 'radio-target-missing' };
    return { ok: clickCenterEl(target), method: target === match ? 'radio-input' : 'radio-associated-control' };
  };
  const findQuestionContainers = (questionText) => {
    const wanted = normLower(questionText);
    if (!wanted) return [];
    const seeds = Array.from(document.querySelectorAll('legend,label,.c-label,p,span,div,h1,h2,h3,h4,h5,h6'))
      .filter(visible)
      .filter((node) => {
        const text = normLower(getText(node));
        return !!text && text.includes(wanted) && text.length <= 220;
      });
    const out = [];
    const seen = new Set();
    for (const seed of seeds) {
      let picked = seed;
      for (let depth = 0, current = seed; depth < 6 && current; depth++, current = current.parentElement) {
        if (!visible(current)) continue;
        const text = normLower(getText(current));
        if (!text.includes(wanted)) continue;
        if (text.includes('yes') || text.includes('no') || current.querySelector('input[type=radio],button,[role=button],[role=radio]')) {
          picked = current;
          break;
        }
      }
      const key = safe(picked && (picked.id || getText(picked)));
      if (!picked || seen.has(key)) continue;
      seen.add(key);
      out.push(picked);
    }
    return out;
  };
  const answerTextMatches = (candidateText, wantedText) => {
    const candidate = normLower(candidateText);
    const wanted = normLower(wantedText);
    if (!candidate || !wanted) return false;
    return candidate === wanted
      || candidate === `${wanted}:`
      || candidate.startsWith(`${wanted} `)
      || candidate.startsWith(`${wanted}: `);
  };
  const isCompoundYesNoText = (text) => {
    const normalized = normLower(text);
    return normalized.includes('yes') && normalized.includes('no');
  };
  const findSemanticAnswerTarget = (questionText, answerText) => {
    const containers = findQuestionContainers(questionText);
    for (const container of containers) {
      const radios = Array.from(container.querySelectorAll('input[type=radio]'));
      for (const radio of radios) {
        const labelText = readInputLabel(radio) || safe(radio.value);
        if (!answerTextMatches(labelText, answerText)) continue;
        const target = getInputClickTarget(radio);
        if (target) return target;
      }
      const nodes = Array.from(container.querySelectorAll('button,a,[role=button],[role=radio],label,span,div'))
        .filter((node) => visible(node) && node !== container)
        .map((node) => ({ node, text: getText(node) }))
        .filter(({ text }) => text && !isCompoundYesNoText(text) && text.length <= Math.max(20, safe(answerText).length + 8) && answerTextMatches(text, answerText))
        .sort((a, b) => a.text.length - b.text.length);
      for (const candidate of nodes) {
        const target = findClickableTarget(candidate.node);
        if (target) return target;
      }
    }
    return null;
  };
  const readSemanticAnswerState = (questionText) => {
    const values = ['YES', 'NO'];
    const containers = findQuestionContainers(questionText);
    for (const container of containers) {
      const radios = Array.from(container.querySelectorAll('input[type=radio]'));
      for (const radio of radios) {
        const labelText = normUpper(readInputLabel(radio) || radio.value);
        const value = values.find((wanted) => answerTextMatches(labelText, wanted));
        if (value && radio.checked) return { value, selected: true, source: 'radio' };
      }
      const nodes = Array.from(container.querySelectorAll('button,a,[role=button],[role=radio],label,span,div'))
        .filter((node) => visible(node) && node !== container);
      for (const node of nodes) {
        const text = getText(node);
        if (isCompoundYesNoText(text)) continue;
        const value = values.find((wanted) => answerTextMatches(text, wanted));
        if (!value) continue;
        if (isSelectedNode(node)) return { value, selected: true, source: 'semantic' };
      }
    }
    return { value: '', selected: false, source: containers.length ? 'question-found' : '' };
  };
  const normalizeVehicleText = (value) => normUpper(value).replace(/\bF\s+(\d{3,4})\b/g, 'F$1');
  const vehicleTokens = (source = {}) => [source.year, source.make, source.model].map(normalizeVehicleText).filter(Boolean);
  const vehicleTextMatches = (text, source = {}) => {
    const haystack = normalizeVehicleText(text);
    const tokens = vehicleTokens(source);
    return tokens.length > 0 && tokens.every((token) => haystack.includes(token));
  };
  const pickVehicleCard = (seed, source = {}) => {
    let fallback = null;
    for (let depth = 0, current = seed; depth < 8 && current; depth++, current = current.parentElement) {
      if (!visible(current)) continue;
      const text = getText(current);
      if (!text || text.length < 20 || text.length > 500) continue;
      if (!vehicleTextMatches(text, source)) continue;
      if (!fallback)
        fallback = current;
      const idClass = lower(`${safe(current.id)} ${safe(current.className)}`);
      const hasActionButtons = Array.from(current.querySelectorAll('button,a,[role=button]')).some((node) => {
        const textValue = getText(node);
        return visible(node) && (answerTextMatches(textValue, 'Confirm') || answerTextMatches(textValue, 'Remove'));
      });
      if (/cartruck|vehicle|card|tile|panel|item|row/.test(idClass) || hasActionButtons)
        return current;
    }
    return fallback;
  };
  const findVehicleMatchCards = (source = {}) => {
    const seeds = Array.from(document.querySelectorAll('h3,button,a,div,span'))
      .filter(visible)
      .filter((node) => {
        const text = getText(node);
        return !!text && text.length >= 10 && text.length <= 160 && vehicleTextMatches(text, source);
      });
    const cards = [];
    const seen = new Set();
    for (const seed of seeds) {
      const card = pickVehicleCard(seed, source);
      if (!card) continue;
      const key = lower(getText(card));
      if (!key || seen.has(key)) continue;
      seen.add(key);
      cards.push(card);
    }
    return cards;
  };
  const findCardButtonByText = (card, text) => Array.from((card && card.querySelectorAll('button,a,[role=button]')) || [])
    .find((node) => visible(node) && answerTextMatches(getText(node), text));
  const isVehicleAlreadyListedMatch = (source = {}) => findVehicleMatchCards(source).some((card) => {
    const text = lower(getText(card));
    if (!text) return false;
    if (text.includes('added to quote') || text.includes(' confirmed')) return true;
    return !findCardButtonByText(card, 'Confirm');
  });
  const startQuotingSectionMatches = (node) => {
    const text = normLower(getText(node));
    return !!text
      && text.includes('start quoting')
      && (text.includes('create quotes')
        || text.includes('order reports')
        || text.includes('add product')
        || text.includes('rating state')
        || text.includes('auto'));
  };
  const findStartQuotingSection = (source = {}) => {
    const selectors = getSelectorArgs(source);
    const anchors = [
      document.getElementById(selectors.createQuotesButtonId || 'consentModalTrigger'),
      document.getElementById(selectors.quoteBlockAddProductId || 'quotesButton'),
      document.getElementById('ConsumerReports.Auto.RatingState'),
      document.getElementById('ConsumerReports.Auto.Product-intel#102')
    ].filter(Boolean);
    for (const anchor of anchors) {
      for (let depth = 0, current = anchor; depth < 8 && current; depth++, current = current.parentElement) {
        if (!visible(current)) continue;
        if (startQuotingSectionMatches(current)) return current;
      }
    }
    const seeds = Array.from(document.querySelectorAll('h1,h2,h3,h4,h5,h6,legend,label,p,span,div,section,article'))
      .filter(visible)
      .filter((node) => normLower(getText(node)).includes('start quoting'));
    for (const seed of seeds) {
      for (let depth = 0, current = seed; depth < 8 && current; depth++, current = current.parentElement) {
        if (!visible(current)) continue;
        if (startQuotingSectionMatches(current)) return current;
      }
    }
    return null;
  };
  const startsWithTextToken = (candidateText, wantedText) => {
    const candidate = normLower(candidateText);
    const wanted = normLower(wantedText);
    if (!candidate || !wanted) return false;
    return candidate === wanted
      || candidate.startsWith(`${wanted} `)
      || candidate.startsWith(`${wanted}:`)
      || candidate.startsWith(`${wanted}-`);
  };
  const optionLooksSelected = (node) => isSelectedNode(node) || isSelectedNode(findClickableTarget(node));
  const findStartQuotingAutoCandidate = (section) => {
    const root = section || document;
    const candidates = Array.from(root.querySelectorAll('input,button,a,[role=button],[role=radio],[role=checkbox],label,span,div'))
      .filter((node) => visible(node) && node !== section)
      .map((node) => ({ node, text: getText(node) }))
      .filter(({ text }) => {
        const textNorm = normLower(text);
        return startsWithTextToken(text, 'Auto')
          && text.length <= 48
          && !textNorm.includes('create quotes')
          && !textNorm.includes('order reports')
          && !textNorm.includes('rating state')
          && !textNorm.includes('add product');
      })
      .sort((a, b) => a.text.length - b.text.length);
    for (const candidate of candidates) {
      const target = safe(candidate.node.tagName) === 'INPUT'
        ? (getInputClickTarget(candidate.node) || candidate.node)
        : findClickableTarget(candidate.node);
      if (target) {
        return {
          node: candidate.node,
          target,
          text: candidate.text,
          selected: optionLooksSelected(candidate.node) || optionLooksSelected(target)
        };
      }
    }
    return null;
  };
  const readStartQuotingAutoState = (source = {}) => {
    const section = findStartQuotingSection(source);
    const stableInput = document.getElementById('ConsumerReports.Auto.Product-intel#102');
    let present = false;
    let selected = false;
    let stateSource = '';
    let text = '';
    if (stableInput) {
      present = true;
      const target = getInputClickTarget(stableInput);
      selected = !!stableInput.checked || optionLooksSelected(target);
      stateSource = stableInput.checked ? 'stable-input' : (selected ? 'stable-associated-control' : 'stable-input');
      text = getText(target) || 'Auto';
    }
    if (!selected) {
      const semantic = findStartQuotingAutoCandidate(section);
      if (semantic) {
        present = true;
        selected = !!semantic.selected;
        stateSource = semantic.selected ? 'semantic-selected' : 'semantic-present';
        text = semantic.text || text;
      }
    }
    if (!present && section && includesText(normLower(getText(section)), 'auto')) {
      present = true;
      stateSource = 'section-text';
      text = 'Auto';
    }
    return {
      present,
      selected,
      source: stateSource,
      text
    };
  };
  const ratingStateMatches = (value, text, wanted) => {
    const wantedNorm = normUpper(wanted);
    return !!wantedNorm && (normUpper(value) === wantedNorm || normUpper(text) === wantedNorm || normUpper(text).includes(wantedNorm));
  };
  const findStartQuotingRatingControl = (section) => {
    const stable = document.getElementById('ConsumerReports.Auto.RatingState');
    if (stable) return { element: stable, source: 'stable-select' };
    const containers = findQuestionContainers('Rating State').filter((container) => !section || section.contains(container));
    for (const container of containers) {
      const select = container.querySelector('select');
      if (select) return { element: select, source: 'semantic-select' };
      const trigger = Array.from(container.querySelectorAll('button,a,[role=button],[role=combobox],label,span,div'))
        .filter(visible)
        .find((node) => {
          const text = getText(node);
          return !!text && text.length <= 32 && !startsWithTextToken(text, 'Rating State');
        });
      if (trigger) return { element: trigger, source: 'semantic-trigger' };
    }
    return { element: null, source: '' };
  };
  const readStartQuotingRatingState = (source = {}) => {
    const section = findStartQuotingSection(source);
    const ratingControl = findStartQuotingRatingControl(section);
    const el = ratingControl.element;
    if (!el) return { value: '', text: '', source: '', disabled: false };
    if (safe(el.tagName) === 'SELECT') {
      const state = readSelectState(el);
      return {
        value: state.value,
        text: state.text,
        source: ratingControl.source,
        disabled: !!el.disabled
      };
    }
    const text = getText(el);
    return {
      value: text,
      text,
      source: ratingControl.source,
      disabled: safe(el.getAttribute && el.getAttribute('aria-disabled')) === 'true' || !!el.disabled
    };
  };
  const setSemanticRatingState = (section, ratingState) => {
    const containers = findQuestionContainers('Rating State').filter((container) => !section || section.contains(container));
    for (const container of containers) {
      const trigger = Array.from(container.querySelectorAll('button,a,[role=button],[role=combobox],label,span,div'))
        .filter(visible)
        .find((node) => {
          const text = getText(node);
          if (!text || text.length > 32) return false;
          const role = lower(node.getAttribute && node.getAttribute('role'));
          return role === 'combobox'
            || role === 'button'
            || startsWithTextToken(text, 'Select One')
            || ratingStateMatches('', text, ratingState);
        });
      if (!trigger) continue;
      if (!clickCenterEl(trigger)) continue;
      const option = Array.from(document.querySelectorAll('[role=option],li,button,a,div,span,label'))
        .filter(visible)
        .find((node) => {
          const text = getText(node);
          return !!text && text.length <= 20 && ratingStateMatches('', text, ratingState);
        });
      if (!option) return { ok: false, method: 'semantic-option-missing' };
      return { ok: clickCenterEl(option), method: 'semantic-option' };
    }
    return { ok: false, method: 'rating-state-target-missing' };
  };
  const ensureStartQuotingRatingState = (source = {}, ratingState) => {
    const section = findStartQuotingSection(source);
    const ratingControl = findStartQuotingRatingControl(section);
    const el = ratingControl.element;
    if (!el) return { ok: false, method: 'rating-state-missing' };
    if (safe(el.tagName) === 'SELECT') {
      const current = readSelectState(el);
      if (ratingStateMatches(current.value, current.text, ratingState))
        return { ok: true, method: el.disabled ? 'stable-select-readonly-match' : 'stable-select-already' };
      if (!el.disabled && setSelectValue(el, ratingState, false))
        return { ok: true, method: ratingControl.source };
      if (el.disabled)
        return { ok: false, method: 'stable-select-disabled-mismatch' };
    }
    return setSemanticRatingState(section, ratingState);
  };
  const findCreateQuotesButton = (source = {}) => {
    const selectors = getSelectorArgs(source);
    const section = findStartQuotingSection(source);
    const stable = document.getElementById(selectors.createQuotesButtonId || 'consentModalTrigger');
    if (stable && visible(stable))
      return stable;
    const root = section || document;
    return Array.from(root.querySelectorAll('button,a,[role=button]'))
      .filter(visible)
      .find((node) => startsWithTextToken(getText(node), 'Create Quotes & Order Reports')) || null;
  };
  const findStartQuotingAddProductLink = (source = {}) => {
    const selectors = getSelectorArgs(source);
    const stable = document.getElementById(selectors.quoteBlockAddProductId || 'quotesButton');
    if (stable && visible(stable))
      return stable;
    const sidebar = document.getElementById(selectors.sidebarAddProductId || 'addProduct');
    if (sidebar && visible(sidebar))
      return sidebar;
    const section = findStartQuotingSection(source);
    const root = section || document;
    return Array.from(root.querySelectorAll('button,a,[role=button]'))
      .filter(visible)
      .find((node) => startsWithTextToken(getText(node), 'Add product')) || null;
  };
  const buildStartQuotingStatus = (source = {}) => {
    const section = findStartQuotingSection(source);
    const autoState = readStartQuotingAutoState(source);
    const ratingState = readStartQuotingRatingState(source);
    const createBtn = findCreateQuotesButton(source);
    const addProductLink = findStartQuotingAddProductLink(source);
    const hasStartQuotingText = !!section || bodyText().includes('start quoting');
    return {
      hasStartQuotingText: hasStartQuotingText ? '1' : '0',
      autoProductPresent: autoState.present ? '1' : '0',
      autoProductChecked: autoState.selected ? '1' : '0',
      autoProductSelected: autoState.selected ? '1' : '0',
      autoProductSource: autoState.source,
      ratingStateValue: ratingState.value,
      ratingStateText: ratingState.text,
      ratingStateSource: ratingState.source,
      createQuoteButtonPresent: createBtn ? '1' : '0',
      createQuoteButtonEnabled: createBtn && !createBtn.disabled ? '1' : '0',
      addProductLinkPresent: addProductLink ? '1' : '0',
      alerts: collectVisibleAlerts().join(' || ')
    };
  };

  switch (safe(op)) {
    case 'detect_state': {
      const url = pageUrl();
      const text = bodyText();
      const urls = getUrlArgs(args);
      const texts = getTextArgs(args);
      const selectors = getSelectorArgs(args);
      const isCustomerSummaryOverview = isCustomerSummaryOverviewPage(args);
      const isRapport = isGatherDataPage(args);
      const isProductOverview = isProductOverviewPage(args);
      const isSelectProductForm = isSelectProductFormPage(args);
      const isIncidents = (!!urls.ascProductContains && url.includes(urls.ascProductContains) && text.includes('incidents'));
      const isAsc = (!!urls.ascProductContains && url.includes(urls.ascProductContains))
        || text.includes('drivers and vehicles')
        || text.includes('order consumer reports');

      if (isCustomerSummaryOverview) return 'CUSTOMER_SUMMARY_OVERVIEW';
      if (isRapport) return 'RAPPORT';
      if (isProductOverview) return 'PRODUCT_OVERVIEW';
      if (isSelectProductForm) return 'SELECT_PRODUCT';
      if (isIncidents) return 'INCIDENTS';
      if (isAsc) return 'ASC_PRODUCT';
      if (safe(texts.duplicateHeading) && text.includes(lower(texts.duplicateHeading))) return 'DUPLICATE';
      if (safe(selectors.searchCreateNewProspectId) && findByStableId(selectors.searchCreateNewProspectId)) return 'BEGIN_QUOTING_SEARCH';
      if (safe(selectors.beginQuotingContinueId) && findByStableId(selectors.beginQuotingContinueId)) return 'BEGIN_QUOTING_FORM';
      if (safe(selectors.advisorQuotingButtonId) && findByStableId(selectors.advisorQuotingButtonId)) return 'ADVISOR_HOME';
      if (url.includes('advisorpro.allstate.com')) return 'ADVISOR_OTHER';
      if (text.includes('allstate advisor pro')) return 'GATEWAY';
      return 'NO_CONTEXT';
    }

    case 'click_product_overview_tile': {
      if (!isProductOverviewPage(args)) return 'NOT_OVERVIEW';
      const target = findOverviewProductTileTarget(args.productText || 'Auto');
      if (!target) return 'NO_TILE';
      return clickEl(target) ? 'OK' : 'CLICK_FAILED';
    }

    case 'focus_prospect_first_input': {
      const byIds = [
        'ConsumerData.People[0].Name.GivenName',
        'ConsumerData.People[0].Name.FirstName',
        'ConsumerData.People[0].Personal.GivenName',
        'FirstName', 'firstName', 'First_Name'
      ];
      for (const id of byIds) {
        const el = document.getElementById(id);
        if (visible(el)) {
          try { el.focus(); el.click(); } catch {}
          return '1';
        }
      }
      const textInputs = Array.from(document.querySelectorAll('input[type=text],input:not([type])')).filter(visible);
      if (textInputs.length) {
        try { textInputs[0].focus(); textInputs[0].click(); } catch {}
        return '1';
      }
      return '0';
    }

    case 'prospect_form_status': {
      const selectors = args.selectors || {};
      const readValue = (id) => {
        const el = findByStableId(id);
        if (!el || !visible(el)) return '';
        if (el.tagName === 'SELECT') {
          const opt = el.options && el.selectedIndex >= 0 ? el.options[el.selectedIndex] : null;
          return safe(opt ? (opt.text || opt.innerText) : el.value).trim();
        }
        if (/^(checkbox|radio)$/i.test(safe(el.type)))
          return el.checked ? safe(el.value).trim() : '';
        return safe(el.value).trim();
      };
      const uniq = (items) => {
        const seen = new Set();
        const out = [];
        for (const item of items) {
          const text = safe(item).replace(/\s+/g, ' ').trim();
          if (!text) continue;
          const key = text.toLowerCase();
          if (seen.has(key)) continue;
          seen.add(key);
          out.push(text);
        }
        return out;
      };
      const errorNodes = Array.from(document.querySelectorAll('[id^="message_"], .c-alert a, .c-alert__content a, .c-alert__content, .c-alert'))
        .filter(visible);
      const errors = uniq(
        errorNodes
          .map((el) => safe(el.innerText || el.textContent))
          .flatMap((text) => text.split(/\r?\n/))
          .map((line) => line.replace(/\s+/g, ' ').trim())
          .filter((line) => line && !/^view all$/i.test(line))
      );
      const submit = findByStableId(selectors.beginQuotingContinueId || args.submitId);
      const requiredIds = [
        selectors.prospectFirstNameId,
        selectors.prospectLastNameId,
        selectors.prospectDobId,
        selectors.prospectAddressId,
        selectors.prospectCityId,
        selectors.prospectStateId,
        selectors.prospectZipId,
        selectors.beginQuotingContinueId
      ].filter(Boolean);
      const ready = requiredIds.every((id) => {
        const el = findByStableId(id);
        return !!el && visible(el);
      });
      const lines = [
        `ready=${ready ? '1' : '0'}`,
        `firstName=${readValue(selectors.prospectFirstNameId)}`,
        `lastName=${readValue(selectors.prospectLastNameId)}`,
        `dob=${readValue(selectors.prospectDobId)}`,
        `gender=${readValue(selectors.prospectGenderId)}`,
        `address=${readValue(selectors.prospectAddressId)}`,
        `city=${readValue(selectors.prospectCityId)}`,
        `state=${readValue(selectors.prospectStateId)}`,
        `zip=${readValue(selectors.prospectZipId)}`,
        `phone=${readValue(selectors.prospectPhoneId)}`,
        `submitPresent=${submit ? '1' : '0'}`,
        `submitEnabled=${submit && !submit.disabled ? '1' : '0'}`,
        `errors=${errors.join(' || ')}`
      ];
      return lines.join('\n');
    }

    case 'handle_duplicate_prospect': {
      const firstName = normUpper(args.firstName);
      const lastName = normUpper(args.lastName);
      const street = normUpper(args.street);
      const zip = normUpper(args.zip);
      const dob = normUpper(args.dob);
      const streetNumber = ((street.match(/^\d+/) || [])[0]) || '';
      const streetTokens = street.split(' ').filter(Boolean);
      const streetPrimary = streetTokens.length >= 2 ? streetTokens[1] : '';
      const radios = Array.from(document.querySelectorAll('input[type=radio]')).filter(visible);
      let best = null;
      let bestScore = -1;
      for (const radio of radios) {
        const container = radio.closest('.sfmOption,.l-tile,[role=row],div') || radio.parentElement;
        const text = normUpper((container && (container.innerText || container.textContent)) || (radio.parentElement && radio.parentElement.innerText) || '');
        if (!text) continue;
        if (lastName && !new RegExp('(^|\\s)' + lastName + '(\\s|$)').test(text)) continue;
        if (zip && !text.includes(zip)) continue;
        if (streetNumber && !new RegExp('(^|\\s)' + streetNumber + '(\\s|$)').test(text)) continue;
        if (streetPrimary && !text.includes(streetPrimary)) continue;
        let score = 100;
        if (firstName) {
          if (new RegExp('(^|\\s)' + firstName + '(\\s|$)').test(text)) score += 35;
          else if (text.includes(firstName)) score += 20;
        }
        if (dob && text.includes(dob)) score += 5;
        if (score > bestScore) { bestScore = score; best = radio; }
      }
      if (best && bestScore >= 100) {
        clickEl(best);
        const continueBtn = Array.from(document.querySelectorAll('button,a'))
          .find((el) => visible(el) && /continue|use existing/i.test(safe(el.innerText || el.textContent).trim()));
        if (continueBtn) { clickEl(continueBtn); return 'SELECT_EXISTING'; }
        return 'SELECTED_NO_CONTINUE';
      }
      const buttons = Array.from(document.querySelectorAll('button,a,input[type=button],input[type=submit]')).filter(visible);
      const readText = (el) => normUpper(safe(el.innerText || el.textContent || el.value).trim());
      const createNewBtn = buttons.find((el) => {
        const t = readText(el);
        return t.includes('CREATE NEW PROSPECT') || t.includes('CREATE NEW') || t.includes('NEW PROSPECT');
      });
      if (createNewBtn) { clickEl(createNewBtn); return 'CREATE_NEW'; }
      const fallbackContinue = buttons.find((el) =>
        /continue|use selected|use existing/i.test(safe(el.innerText || el.textContent || el.value).trim())
      );
      if (fallbackContinue) { clickEl(fallbackContinue); return 'FALLBACK_CONTINUE'; }
      return 'NO_ACTION';
    }

    case 'fill_gather_defaults': {
      const ownershipSelect = Array.from(document.querySelectorAll('select[id]')).find((el) => safe(el.id).endsWith('.ResidenceOwnedRentedCd.SrcCd')) || null;
      const homeTypeSelect = Array.from(document.querySelectorAll('select[id]')).find((el) => safe(el.id).endsWith('.ResidenceTypeCd.SrcCd')) || null;
      const emailInput = Array.from(document.querySelectorAll('input[id]')).find((el) => safe(el.id).endsWith('.Communications.EmailAddr')) || null;
      const ageInput = Array.from(document.querySelectorAll('input[id]')).find((el) => safe(el.id).endsWith('.Driver.AgeFirstLicensed')) || null;
      const emailApplied = safe(args.emailValue) ? (setInputValue(emailInput, safe(args.emailValue), false) ? '1' : '0') : 'SKIP';
      const ageApplied = safe(args.ageValue) ? (setInputValue(ageInput, safe(args.ageValue), false) ? '1' : '0') : 'SKIP';
      const ownershipApplied = safe(args.ownershipValue) ? (setSelectValue(ownershipSelect, safe(args.ownershipValue), false) ? '1' : '0') : 'SKIP';
      const homeTypeApplied = safe(args.homeTypeValue) ? (setSelectValue(homeTypeSelect, safe(args.homeTypeValue), false) ? '1' : '0') : 'SKIP';
      return linesOut({
        result: 'OK',
        ageApplied,
        emailApplied,
        ownershipApplied,
        homeTypeApplied
      });
    }

    case 'gather_defaults_status': {
      const ageInput = Array.from(document.querySelectorAll('input[id]')).find((el) => safe(el.id).endsWith('.Driver.AgeFirstLicensed')) || null;
      const emailInput = Array.from(document.querySelectorAll('input[id]')).find((el) => safe(el.id).endsWith('.Communications.EmailAddr')) || null;
      const ownershipSelect = Array.from(document.querySelectorAll('select[id]')).find((el) => safe(el.id).endsWith('.ResidenceOwnedRentedCd.SrcCd')) || null;
      const homeTypeSelect = Array.from(document.querySelectorAll('select[id]')).find((el) => safe(el.id).endsWith('.ResidenceTypeCd.SrcCd')) || null;
      const licenseStateSelect = document.getElementById('ConsumerData.People[0].Driver.LicenseState');
      const ownership = readSelectState(ownershipSelect);
      const homeType = readSelectState(homeTypeSelect);
      const licenseState = readSelectState(licenseStateSelect);
      return linesOut({
        ageFirstLicensed: safe(ageInput && ageInput.value).trim(),
        email: safe(emailInput && emailInput.value).trim(),
        ownershipTypeValue: ownership.value,
        ownershipTypeText: ownership.text,
        homeTypeValue: homeType.value,
        homeTypeText: homeType.text,
        licenseStateValue: licenseState.value,
        licenseStateText: licenseState.text,
        alerts: collectVisibleAlerts().join(' || ')
      });
    }

    case 'vehicle_already_listed': {
      return isVehicleAlreadyListedMatch(args) ? '1' : '0';
    }

    case 'confirm_potential_vehicle': {
      const cards = findVehicleMatchCards(args).filter((card) => !!findCardButtonByText(card, 'Confirm'));
      if (!cards.length)
        return linesOut({ result: 'NO_MATCH', matches: '0', cardText: '' });
      if (cards.length > 1)
        return linesOut({ result: 'AMBIGUOUS', matches: String(cards.length), cards: cards.map((card) => getText(card)).join(' || ') });
      const card = cards[0];
      const confirmBtn = findCardButtonByText(card, 'Confirm');
      const cardText = getText(card);
      if (!confirmBtn)
        return linesOut({ result: 'NO_MATCH', matches: '0', cardText: '' });
      return linesOut({
        result: clickCenterEl(confirmBtn) ? 'CONFIRMED' : 'CLICK_FAILED',
        matches: '1',
        cardText
      });
    }

    case 'prepare_vehicle_row': {
      const year = safe(args.year);
      const ids = new Set();
      for (const el of document.querySelectorAll('input[id],select[id]')) {
        if (!safe(el.id).includes('ConsumerData.Assets.Vehicles[')) continue;
        const m = safe(el.id).match(/ConsumerData\.Assets\.Vehicles\[(\d+)\]/);
        if (m) ids.add(Number(m[1]));
      }
      const indexes = Array.from(ids).sort((a, b) => b - a);
      if (!indexes.length) return '-1';
      let target = indexes[0];
      for (const idx of indexes) {
        const yearInput = document.getElementById(`ConsumerData.Assets.Vehicles[${idx}].ModelYear`);
        if (yearInput && visible(yearInput) && safe(yearInput.value).trim() === '') { target = idx; break; }
      }
      const input = document.getElementById(`ConsumerData.Assets.Vehicles[${target}].ModelYear`);
      if (!input || !visible(input) || input.disabled || input.readOnly) return '-1';
      try { input.focus(); } catch {}
      input.value = year;
      input.dispatchEvent(new Event('input', { bubbles: true }));
      input.dispatchEvent(new Event('change', { bubbles: true }));
      return String(target);
    }

    case 'wait_vehicle_select_enabled': {
      const index = Number(args.index);
      const fieldName = safe(args.fieldName);
      const minOptions = Number(args.minOptions || 1);
      const el = document.getElementById(`ConsumerData.Assets.Vehicles[${index}].${fieldName}`);
      if (!el) return '0';
      if (el.disabled) return '0';
      if ((el.options || []).length < minOptions) return '0';
      return '1';
    }

    case 'select_vehicle_dropdown_option': {
      const index = Number(args.index);
      const fieldName = safe(args.fieldName);
      const wanted = normUpper(args.wantedText);
      const allowFirstNonEmpty = String(args.allowFirstNonEmpty || '') === '1' || args.allowFirstNonEmpty === true;
      const select = document.getElementById(`ConsumerData.Assets.Vehicles[${index}].${fieldName}`);
      if (!select || select.disabled) return 'NO_SELECT';
      let best = null;
      for (const opt of Array.from(select.options || [])) {
        const text = normUpper(opt.text);
        const value = normUpper(opt.value);
        if (!text || text === 'SELECT ONE') continue;
        if (wanted && (text === wanted || text.includes(wanted) || wanted.includes(text) || value === wanted)) { best = opt; break; }
      }
      if (!best && allowFirstNonEmpty) {
        best = Array.from(select.options || []).find((opt) => {
          const t = normUpper(opt.text);
          return t && t !== 'SELECT ONE';
        }) || null;
      }
      if (!best) return 'NO_OPTION';
      select.value = best.value;
      select.dispatchEvent(new Event('input', { bubbles: true }));
      select.dispatchEvent(new Event('change', { bubbles: true }));
      return 'OK';
    }

    case 'gather_start_quoting_status': {
      return linesOut(buildStartQuotingStatus(args));
    }

    case 'ensure_auto_start_quoting_state': {
      const ratingState = safe(args.ratingState);
      const beforeAuto = readStartQuotingAutoState(args);
      let autoMethod = beforeAuto.source || 'missing';
      let autoApplied = beforeAuto.selected ? '1' : '0';
      if (!beforeAuto.selected) {
        const stableInput = document.getElementById('ConsumerReports.Auto.Product-intel#102');
        const stableTarget = getInputClickTarget(stableInput);
        if (stableTarget && clickCenterEl(stableTarget)) {
          autoApplied = '1';
          autoMethod = 'stable-associated-control';
        } else {
          const semantic = findStartQuotingAutoCandidate(findStartQuotingSection(args));
          if (semantic && clickCenterEl(semantic.target)) {
            autoApplied = '1';
            autoMethod = 'semantic-target';
          } else {
            autoMethod = semantic ? 'semantic-click-failed' : 'auto-target-missing';
          }
        }
      }
      const ratingResult = ensureStartQuotingRatingState(args, ratingState);
      const afterStatus = buildStartQuotingStatus(args);
      const ready = afterStatus.hasStartQuotingText === '1'
        && afterStatus.autoProductSelected === '1'
        && ratingStateMatches(afterStatus.ratingStateValue, afterStatus.ratingStateText, ratingState)
        && afterStatus.createQuoteButtonPresent === '1'
        && afterStatus.createQuoteButtonEnabled === '1';
      return linesOut({
        result: ready ? 'OK' : 'FAILED',
        autoApplied,
        autoMethod,
        ratingStateApplied: ratingResult.ok ? '1' : '0',
        ratingStateMethod: ratingResult.method,
        ...afterStatus
      });
    }

    case 'click_create_quotes_order_reports': {
      const btn = findCreateQuotesButton(args);
      if (!btn) return 'NO_BUTTON';
      if (btn.disabled) return 'DISABLED';
      return clickCenterEl(btn) ? 'OK' : 'CLICK_FAILED';
    }

    case 'click_start_quoting_add_product': {
      const btn = findStartQuotingAddProductLink(args);
      if (!btn) return 'NO_BUTTON';
      if (btn.disabled) return 'DISABLED';
      return clickCenterEl(btn) ? 'OK' : 'CLICK_FAILED';
    }

    case 'set_select_product_defaults': {
      const selectors = getSelectorArgs(args);
      const questionText = safe(args.currentInsuredQuestionText || 'Is the customer currently insured?');
      const answerText = safe(args.currentInsuredAnswerText || 'Yes');
      const ratingSelect = findByStableId(args.selectProductRatingStateId || selectors.selectProductRatingStateId || 'SelectProduct.RatingState');
      const productSelect = findByStableId(args.selectProductProductId || selectors.selectProductProductId || 'SelectProduct.Product');
      const productSet = setSelectValue(productSelect, safe(args.productValue || 'AUTO'), false) ? '1' : '0';
      const ratingStateSet = setSelectValue(ratingSelect, safe(args.ratingState), false) ? '1' : '0';

      let currentInsuredSet = 'SKIP';
      let currentInsuredMethod = 'not-requested';
      if (safe(args.currentInsured)) {
        const currentState = readSemanticAnswerState(questionText);
        if (currentState.selected && normUpper(currentState.value) === normUpper(args.currentInsured)) {
          currentInsuredSet = '1';
          currentInsuredMethod = 'already-selected';
        } else {
          const radioResult = setRadioByName('SelectProduct.CustomerCurrentInsured', args.currentInsured);
          currentInsuredSet = radioResult.ok ? '1' : '0';
          currentInsuredMethod = radioResult.method;
          if (!radioResult.ok) {
            const semanticTarget = findSemanticAnswerTarget(questionText, answerText);
            if (semanticTarget) {
              currentInsuredSet = clickCenterEl(semanticTarget) ? '1' : '0';
              currentInsuredMethod = 'semantic-center';
            }
          }
        }
      }

      let ownOrRentSet = 'SKIP';
      let ownOrRentMethod = 'not-requested';
      if (safe(args.ownOrRent)) {
        const ownOrRentResult = setRadioByName('SelectProduct.CustomerOwnOrRent', args.ownOrRent);
        ownOrRentSet = ownOrRentResult.ok ? '1' : '0';
        ownOrRentMethod = ownOrRentResult.method;
      }

      return linesOut({
        result: 'OK',
        productSet,
        ratingStateSet,
        currentInsuredSet,
        currentInsuredMethod,
        ownOrRentSet,
        ownOrRentMethod
      });
    }

    case 'select_product_status': {
      const selectors = getSelectorArgs(args);
      const questionText = safe(args.currentInsuredQuestionText || 'Is the customer currently insured?');
      const ratingSelect = findByStableId(args.selectProductRatingStateId || selectors.selectProductRatingStateId || 'SelectProduct.RatingState');
      const productSelect = findByStableId(args.selectProductProductId || selectors.selectProductProductId || 'SelectProduct.Product');
      const continueBtn = findByStableId(selectors.selectProductContinueId || args.selectProductContinueId || 'selectProductContinue');
      const ratingState = readSelectState(ratingSelect);
      const product = readSelectState(productSelect);
      const currentInsured = readSemanticAnswerState(questionText);
      const body = bodyText();
      const currentInsuredAlert = body.includes(lower(questionText)) && body.includes('this is required');
      return linesOut({
        ratingStateValue: ratingState.value,
        ratingStateText: ratingState.text,
        productValue: product.value,
        productText: product.text,
        currentInsuredValue: currentInsured.value,
        currentInsuredSelected: currentInsured.selected ? '1' : '0',
        currentInsuredSource: currentInsured.source,
        currentInsuredAlert: currentInsuredAlert ? '1' : '0',
        alerts: collectVisibleAlerts().join(' || '),
        continuePresent: continueBtn ? '1' : '0',
        continueEnabled: continueBtn && !continueBtn.disabled ? '1' : '0'
      });
    }

    case 'list_driver_slugs': {
      const ids = new Set();
      for (const btn of Array.from(document.querySelectorAll('button[id]')).filter(visible)) {
        const id = safe(btn.id);
        if (!id) continue;
        if (/^\d{4}-/.test(id)) continue;
        if (!/-addToQuote$/.test(id) && !/-add$/.test(id) && !/-remove$/.test(id)) continue;
        const slug = id.replace(/-(addToQuote|add|remove)$/i, '');
        if (!slug) continue;
        ids.add(slug);
      }
      return Array.from(ids).join('||');
    }

    case 'driver_is_already_added': {
      const slug = safe(args.slug);
      const editBtn = document.getElementById(slug + '-edit');
      const addBtn = document.getElementById(slug + '-addToQuote') || document.getElementById(slug + '-add');
      if (editBtn && !addBtn) return '1';
      if (editBtn) {
        const card = editBtn.closest('div');
        const text = lower((card && card.innerText) || '');
        if (text.includes('added to quote')) return '1';
      }
      return '0';
    }

    case 'vehicle_marked_added': {
      const year = normUpper(args.year);
      const make = normUpper(args.make);
      const model = normUpper(args.model);
      const cards = Array.from(document.querySelectorAll('div'));
      for (const card of cards) {
        const text = normUpper(card.innerText || card.textContent || '');
        if (!text.includes('ADDED TO QUOTE')) continue;
        if (year && !text.includes(year)) continue;
        if (make && !text.includes(make)) continue;
        if (model && !text.includes(model)) continue;
        return '1';
      }
      return '0';
    }

    case 'find_vehicle_add_button': {
      const y = normLower(args.year);
      const mk = normLower(args.make);
      const md = normLower(args.model);
      const candidates = Array.from(document.querySelectorAll('button[id]')).filter((btn) => {
        const id = safe(btn.id);
        return id.endsWith('-add') || id.endsWith('-addToQuote');
      });
      for (const btn of candidates) {
        const id = safe(btn.id);
        if (!/^\d{4}-/.test(id)) continue;
        const idNorm = normLower(id.replace(/-/g, ' '));
        if (y && !idNorm.includes(y)) continue;
        if (mk && !idNorm.includes(mk.split(' ')[0])) continue;
        if (md && !idNorm.includes(md.split(' ')[0])) continue;
        return id;
      }
      return '';
    }

    case 'any_vehicle_already_added': {
      return bodyText().includes('added to quote') ? '1' : '0';
    }

    case 'modal_exists': {
      const saveButtonId = safe(args.saveButtonId);
      return document.getElementById(saveButtonId) ? '1' : '0';
    }

    case 'fill_participant_modal': {
      const setRadioValueByName = (namePart, value) => {
        const list = Array.from(document.querySelectorAll('input[type=radio]'));
        const hit = list.find((el) => safe(el.name).includes(safe(namePart)) && lower(el.value) === lower(value));
        if (!hit) return false;
        return clickEl(hit);
      };
      const setSelect = (id, value) => {
        const el = document.getElementById(safe(id));
        if (!el || el.disabled) return false;
        if (!Array.from(el.options || []).some((opt) => safe(opt.value) === safe(value))) return false;
        el.value = safe(value);
        el.dispatchEvent(new Event('input', { bubbles: true }));
        el.dispatchEvent(new Event('change', { bubbles: true }));
        return true;
      };

      setInputValue(document.getElementById('ageFirstLicensed_ageFirstLicensed'), args.ageFirstLicensed, true);
      setInputValue(document.getElementById('emailAddress.emailAddress'), args.email, true);
      setRadioValueByName('agreement.agreementParticipant.militaryInd', args.military);
      setRadioValueByName('agreement.agreementParticipant.party.violationInd', args.violations);
      setRadioValueByName('agreement.agreementParticipant.defensiveDriverInd', args.defensiveDriving);
      setSelect('propertyOwnershipEntCd_option', args.propertyOwnership);

      const male = document.getElementById('gender_1002');
      const female = document.getElementById('gender_1001');
      if (male && female && !male.checked && !female.checked) {
        const target = document.getElementById('gender_' + safe(args.oppositeGenderValue));
        if (target) clickEl(target);
      }

      const spouseSelect = document.getElementById(safe(args.spouseSelectId));
      const marriedRadio = document.getElementById('maritalStatusEntCd_0001');
      if (spouseSelect && marriedRadio) {
        const valid = Array.from(spouseSelect.options || []).map((o) => safe(o.value)).filter((v) => v && v !== 'NewDriver');
        if (valid.length === 1) {
          clickEl(marriedRadio);
          spouseSelect.value = valid[0];
          spouseSelect.dispatchEvent(new Event('input', { bubbles: true }));
          spouseSelect.dispatchEvent(new Event('change', { bubbles: true }));
        }
      }
      return 'OK';
    }

    case 'select_remove_reason': {
      const el = document.getElementById('nonDriverReasonOthers_' + safe(args.reasonCode));
      if (!el) return 'NO_REASON';
      return clickEl(el) ? 'OK' : 'NO_REASON';
    }

    case 'fill_vehicle_modal': {
      const txt = safe((document.body && document.body.innerText) || '');
      const m = txt.match(/\b(19|20)\d{2}\b/);
      const year = m ? Number(m[0]) : 0;
      const clickId = (id) => {
        const el = document.getElementById(id);
        if (!el || el.disabled) return false;
        return clickEl(el);
      };
      clickId('garagingAddressSameAsOther-control-item-0');
      clickId('purchaseDate_false');
      if (year > Number(args.threshold || 2015))
        clickId('vehicleOwnershipCd_0007');
      return 'OK';
    }

    case 'handle_incidents': {
      const target = lower(args.reasonText).replace(/\s+/g, ' ').trim();
      let hits = 0;
      const boxes = Array.from(document.querySelectorAll('input[type=checkbox]')).filter(visible);
      for (const box of boxes) {
        const label = (box.closest('label') && box.closest('label').innerText) || box.getAttribute('aria-label') || '';
        const text = lower(label).replace(/\s+/g, ' ').trim();
        if (!text) continue;
        if (!text.includes(target)) continue;
        if (!box.checked) clickEl(box);
        hits++;
      }
      if (hits <= 0) return 'NO_REASON';
      const cont = document.getElementById(safe(args.incidentContinueId));
      if (cont && !cont.disabled) {
        clickEl(cont);
        return 'OK';
      }
      const fallback = Array.from(document.querySelectorAll('button,a')).find((el) => visible(el) && /continue/i.test(safe(el.innerText || el.textContent).trim()));
      if (fallback) {
        clickEl(fallback);
        return 'OK';
      }
      return 'NO_CONTINUE';
    }

    case 'click_by_id': {
      const el = findByStableId(args.id);
      if (!el) return 'NO';
      return clickEl(el) ? 'OK' : 'NO';
    }

    case 'click_by_text': {
      const wanted = lower(args.text);
      const tagSelector = safe(args.tagSelector || 'button,a');
      const list = Array.from(document.querySelectorAll(tagSelector)).filter(visible);
      const match = list.find((el) => lower(el.innerText || el.textContent || '').includes(wanted));
      if (!match) return 'NO';
      return clickEl(match) ? 'OK' : 'NO';
    }

    case 'scan_current_page': {
      const normalize = (value) => safe(value).replace(/\s+/g, ' ').trim();
      const escAttr = (value) => safe(value).replace(/\\/g, '\\\\').replace(/"/g, '\\"');
      const getLabel = (el) => {
        const id = safe(el.id);
        if (id) {
          const byFor = document.querySelector('label[for="' + escAttr(id) + '"]');
          if (byFor) return normalize(byFor.innerText || byFor.textContent);
        }
        const parentLabel = el.closest('label');
        if (parentLabel) return normalize(parentLabel.innerText || parentLabel.textContent);
        const row = el.closest('[class*=field],[class*=form],[class*=question],.l-grid__col,div');
        if (row) {
          const rowLabel = row.querySelector('label,.c-label,legend');
          if (rowLabel) return normalize(rowLabel.innerText || rowLabel.textContent);
        }
        return normalize(el.getAttribute('aria-label') || el.placeholder || '');
      };
      const getSelectOptions = (el) => Array.from(el.options || []).map((opt, idx) => ({
        index: idx,
        value: safe(opt.value),
        text: normalize(opt.text || opt.innerText || ''),
        isCurrent: !!opt.selected,
        disabled: !!opt.disabled
      }));
      const headingNode = document.querySelector('h1,h2,h3');
      const headings = Array.from(document.querySelectorAll('h1,h2,h3')).filter(visible).slice(0, 30).map((el) => ({
        tag: el.tagName,
        id: safe(el.id),
        text: normalize(el.innerText || el.textContent || '')
      }));
      const fields = Array.from(document.querySelectorAll('input,select,textarea')).filter(visible).map((el) => {
        const tag = el.tagName;
        const base = {
          tag,
          id: safe(el.id),
          name: safe(el.name),
          type: safe(el.type),
          label: getLabel(el),
          disabled: !!el.disabled,
          class: safe(el.className)
        };
        if (tag === 'SELECT') {
          const opts = getSelectOptions(el);
          const selectedIndex = Number(el.selectedIndex);
          let selectedText = '';
          if (selectedIndex >= 0 && selectedIndex < opts.length) selectedText = opts[selectedIndex].text;
          return Object.assign(base, {
            value: safe(el.value),
            selectedIndex,
            selectedText,
            options: opts
          });
        }
        if (tag === 'TEXTAREA')
          return Object.assign(base, { value: safe(el.value) });
        const isToggle = /^(radio|checkbox)$/i.test(safe(el.type));
        const out = Object.assign(base, { value: safe(el.value) });
        if (isToggle) out.checked = !!el.checked;
        return out;
      });
      const buttons = Array.from(document.querySelectorAll('button,a,[role=button],input[type=button],input[type=submit]')).filter(visible).map((el) => ({
        tag: el.tagName,
        id: safe(el.id),
        name: safe(el.name),
        text: normalize(el.innerText || el.textContent || el.value || ''),
        value: safe(el.value),
        class: safe(el.className),
        disabled: !!el.disabled
      }));
      const radios = fields.filter((f) => lower(f.type) === 'radio').map((f) => ({
        id: f.id, name: f.name, value: f.value, checked: !!f.checked, label: f.label
      }));
      const alerts = Array.from(document.querySelectorAll('[id^="message_"], .c-alert, .c-alert a, .c-alert__content, [role=alert], .error, .validation'))
        .filter(visible)
        .map((el) => normalize(el.innerText || el.textContent || ''))
        .filter(Boolean);
      const dialogs = Array.from(document.querySelectorAll('[role=dialog], .modal, .mesh-portal, .ReactModalPortal'))
        .filter(visible)
        .map((el) => normalize(el.innerText || el.textContent || ''))
        .filter(Boolean);
      const payload = {
        capturedAt: new Date().toISOString(),
        stepLabel: safe(args.label || ''),
        scanReason: safe(args.reason || ''),
        url: pageUrl(),
        title: safe(document.title || ''),
        heading: normalize(headingNode ? (headingNode.innerText || headingNode.textContent) : ''),
        bodySample: normalize((document.body && document.body.innerText) || '').slice(0, 2500),
        headings,
        fields,
        buttons,
        radios,
        alerts,
        modalText: dialogs.join(' || ')
      };
      return JSON.stringify(payload, null, 2);
    }

    case 'wait_condition': {
      const name = safe(args.name);
      const url = pageUrl();
      const text = bodyText();
      switch (name) {
        case 'post_prospect_submit':
          return (url.includes(safe(args.rapportContains)) || url.includes(safe(args.selectProductContains)) || isProductOverviewPage(args) || text.includes('this prospect may already exist')) ? '1' : '0';
        case 'prospect_form_ready': {
          const selectors = args.selectors || {};
          const requiredIds = [
            selectors.prospectFirstNameId,
            selectors.prospectLastNameId,
            selectors.prospectDobId,
            selectors.prospectAddressId,
            selectors.prospectCityId,
            selectors.prospectStateId,
            selectors.prospectZipId,
            selectors.beginQuotingContinueId
          ].filter(Boolean);
          return requiredIds.every((id) => {
            const el = findByStableId(id);
            return !!el && visible(el);
          }) ? '1' : '0';
        }
        case 'duplicate_to_next':
          return (isCustomerSummaryOverviewPage(args) || isGatherDataPage(args) || url.includes(safe(args.selectProductContains)) || isProductOverviewPage(args) || isSelectProductFormPage(args)) ? '1' : '0';
        case 'gather_data':
          return isGatherDataPage(args) ? '1' : '0';
        case 'on_customer_summary_overview':
          return isCustomerSummaryOverviewPage(args) ? '1' : '0';
        case 'on_product_overview':
          return isProductOverviewPage(args) ? '1' : '0';
        case 'to_select_product':
          return isSelectProductFormPage(args) ? '1' : '0';
        case 'gather_start_quoting_transition':
          return (text.includes('order consumer reports') || text.includes('drivers and vehicles') || text.includes('incidents') || url.includes(safe(args.ascProductContains))) ? '1' : '0';
        case 'vehicle_added_tile':
          return isVehicleAlreadyListedMatch(args) ? '1' : '0';
        case 'vehicle_confirmed':
          return isVehicleAlreadyListedMatch(args) ? '1' : '0';
        case 'vehicle_select_enabled': {
          const idx = Number(args.index);
          const fieldName = safe(args.fieldName);
          const minOptions = Number(args.minOptions || 1);
          const el = document.getElementById(`ConsumerData.Assets.Vehicles[${idx}].${fieldName}`);
          return (!!el && !el.disabled && (el.options || []).length >= minOptions) ? '1' : '0';
        }
        case 'on_select_product':
          return isSelectProductFormPage(args) ? '1' : '0';
        case 'select_product_to_consumer':
          return (text.includes('order consumer reports') || url.includes(safe(args.ascProductContains))) ? '1' : '0';
        case 'consumer_reports_ready':
          return (text.includes('order consumer reports') || !!document.getElementById(safe(args.consumerReportsConsentYesId))) ? '1' : '0';
        case 'drivers_or_incidents':
          return (text.includes('drivers and vehicles') || text.includes('incidents')) ? '1' : '0';
        case 'after_driver_vehicle_continue':
          return (text.includes('incidents') || !text.includes('drivers and vehicles')) ? '1' : '0';
        case 'add_asset_modal_closed':
          return document.getElementById(safe(args.addAssetSaveId)) ? '0' : '1';
        case 'continue_enabled': {
          const btn = document.getElementById(safe(args.buttonId));
          return (!!btn && !btn.disabled) ? '1' : '0';
        }
        case 'incidents_done':
          return (!text.includes('incidents')) ? '1' : '0';
        case 'quote_landing': {
          const inAsc = url.includes(safe(args.ascProductContains));
          if (!inAsc) return '1';
          if (text.includes('drivers and vehicles')) return '0';
          if (text.includes('incidents')) return '0';
          if (text.includes('order consumer reports')) return '0';
          return '1';
        }
        case 'is_duplicate':
          return text.includes(lower(args.duplicateHeading)) ? '1' : '0';
        case 'is_customer_summary_overview':
          return isCustomerSummaryOverviewPage(args) ? '1' : '0';
        case 'is_rapport':
          return isGatherDataPage(args) ? '1' : '0';
        case 'is_product_overview':
          return isProductOverviewPage(args) ? '1' : '0';
        case 'is_select_product':
          return isSelectProductFormPage(args) ? '1' : '0';
        case 'is_asc':
          return url.includes(safe(args.ascProductContains)) ? '1' : '0';
        case 'is_incidents':
          return text.includes(lower(args.incidentsHeading)) ? '1' : '0';
        default:
          return '0';
      }
    }

    default:
      return '';
  }
})()));
