copy(String((() => {
  const op = @@OP@@;
  const args = @@ARGS@@ || {};
  try {

  const safe = (v) => String(v ?? '');
  const compact = (v, max = 240) => safe(v).replace(/\r?\n+/g, ' ').replace(/\s+/g, ' ').trim().slice(0, max);
  const lower = (v) => safe(v).toLowerCase();
  const normUpper = (v) => safe(v).toUpperCase().replace(/[^A-Z0-9 ]/g, ' ').replace(/\s+/g, ' ').trim();
  const normLower = (v) => safe(v).toLowerCase().replace(/[^a-z0-9 ]/g, ' ').replace(/\s+/g, ' ').trim();
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
    if (!el || !visible(el) || isDisabledLike(el) || el.readOnly) return false;
    const current = safe(el.value).trim();
    if (onlyIfBlank && current !== '') return true;
    try { el.focus(); } catch {}
    if (!setNativeValue(el, value)) return false;
    fireFieldEvents(el);
    return true;
  };
  const setSelectValue = (el, value, onlyIfBlank = false) => {
    if (!el || !visible(el) || isDisabledLike(el)) return false;
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
  const normalizeDigits = (value) => safe(value).replace(/\D/g, '');
  const normalizePhoneKey = (value) => {
    const digits = normalizeDigits(value);
    return digits.length > 10 ? digits.slice(-10) : digits;
  };
  const normalizeDobKey = (value) => normalizeDigits(value);
  const normalizeEmailKey = (value) => lower(value).trim();
  const normalizeAddressText = (value) => normUpper(value)
    .replace(/\b(APT|APARTMENT|UNIT|STE|SUITE)\b/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
  const includesText = (haystack, expected) => {
    const needle = lower(expected);
    return !!needle && haystack.includes(needle);
  };
  const matchesNormalizedValue = (actual, wanted) => {
    const actualNorm = normUpper(actual);
    const wantedNorm = normUpper(wanted);
    return !!wantedNorm && (actualNorm === wantedNorm || actualNorm.includes(wantedNorm));
  };
  const exactNormalizedValue = (actual, wanted) => {
    const actualNorm = normUpper(actual);
    const wantedNorm = normUpper(wanted);
    return !!wantedNorm && actualNorm === wantedNorm;
  };
  const linesOut = (pairs = {}) => Object.entries(pairs).map(([k, v]) => `${k}=${safe(v)}`).join('\n');
  const isSuccessValue = (v, allowSkip = false) => {
    const raw = safe(v).toUpperCase();
    return v === true || raw === '1' || raw === 'OK' || (allowSkip && raw === 'SKIP');
  };
  const normalizeCheck = (check) => {
    if (typeof check === 'boolean')
      return { name: '', ok: check, allowSkip: false };
    if (!check || typeof check !== 'object')
      return { name: '', ok: false, allowSkip: false };
    return {
      name: safe(check.name),
      ok: ('ok' in check) ? !!check.ok : isSuccessValue(check.value, !!check.allowSkip),
      allowSkip: !!check.allowSkip,
      value: check.value
    };
  };
  const resultFromChecks = (requiredChecks = [], optionalChecks = []) => {
    const required = requiredChecks.map(normalizeCheck);
    const optional = optionalChecks.map(normalizeCheck);
    if (!required.every((check) => check.ok))
      return 'FAILED';
    return optional.every((check) => check.ok) ? 'OK' : 'PARTIAL';
  };
  const failedCheckNames = (checks = []) => checks
    .map(normalizeCheck)
    .filter((check) => !check.ok && check.name)
    .map((check) => check.name);
  const formatLineResult = (fields = {}, opName = op) => {
    const out = { ...fields };
    if (Array.isArray(out.failedFields))
      out.failedFields = out.failedFields.join(',');
    const result = safe(out.result).toUpperCase();
    if (result === 'FAILED' || result === 'PARTIAL' || result === 'ERROR') {
      if (!('op' in out)) out.op = opName;
      if (!('method' in out)) out.method = '';
      if (!('alerts' in out)) out.alerts = collectVisibleAlerts().join(' || ');
      if (!('url' in out)) out.url = pageUrl();
      out.failedFields = compact(out.failedFields || '', 240);
      out.alerts = compact(out.alerts || '', 240);
      out.url = compact(out.url || '', 240);
      out.method = compact(out.method || '', 240);
    }
    return linesOut(out);
  };
  const lineResult = (fields = {}) => formatLineResult(fields, op);
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
  const isDuplicatePage = (source = {}) => {
    const texts = getTextArgs(source);
    return includesText(bodyText(), texts.duplicateHeading || 'This Prospect May Already Exist');
  };
  const countIncludesText = (haystack, needle) => {
    const have = lower(haystack);
    const wanted = lower(needle);
    if (!wanted) return 0;
    let count = 0;
    let index = have.indexOf(wanted);
    while (index >= 0) {
      count += 1;
      index = have.indexOf(wanted, index + wanted.length);
    }
    return count;
  };
  const customerSummaryStartHereTextMatches = (value, expectedText) => {
    const normalized = normUpper(value);
    if (!normalized.includes('START HERE')) return false;
    const expected = normUpper(expectedText);
    if (expected && normalized.includes(expected)) return true;
    return /\bPRE\b.*\bFILL\b/.test(normalized) || normalized === 'START HERE';
  };
  const customerSummaryActionText = (el) => compact(getText(el) || safe(el && el.value), 240);
  const customerSummaryOverviewStatus = (source = {}) => {
    const url = pageUrl();
    const text = bodyText();
    const normalizedBody = normUpper(text);
    const urls = getUrlArgs(source);
    const texts = getTextArgs(source);
    const customerSummaryContains = urls.customerSummaryContains || '/apps/customer-summary/';
    const startHereText = texts.customerSummaryStartHereText || 'START HERE (Pre-fill included)';
    const quoteHistoryText = texts.customerSummaryQuoteHistoryText || 'Quote History';
    const assetsDetailsText = texts.customerSummaryAssetsDetailsText || 'Assets Details';
    const extraAnchorTexts = ['Contact Information', 'Family Members', 'Net Worth'];
    const urlMatched = !!customerSummaryContains && url.includes(customerSummaryContains);
    const overviewMatched = url.includes('/overview');
    const startHereMatched = includesText(text, startHereText) || customerSummaryStartHereTextMatches(text, startHereText);
    const quoteHistoryMatched = includesText(text, quoteHistoryText);
    const assetsDetailsMatched = includesText(text, assetsDetailsText);
    const extraAnchorMatched = extraAnchorTexts.some((anchor) => normalizedBody.includes(normUpper(anchor)));
    const summaryAnchorMatched = quoteHistoryMatched || assetsDetailsMatched || extraAnchorMatched;
    const interactiveStartHereCount = Array.from(document.querySelectorAll('button,a,[role=button],input[type=button],input[type=submit],[tabindex]'))
      .filter(visible)
      .filter((node) => customerSummaryStartHereTextMatches(customerSummaryActionText(node), startHereText))
      .length;
    const startHereCount = Math.max(countIncludesText(text, startHereText), interactiveStartHereCount);
    const routeMatched = urlMatched && overviewMatched;
    const evidence = [];
    const missing = [];
    if (urlMatched) evidence.push('url:/apps/customer-summary/');
    else missing.push('url:/apps/customer-summary/');
    if (overviewMatched) evidence.push('url:/overview');
    else missing.push('url:/overview');
    if (startHereMatched) evidence.push('text:START HERE');
    else missing.push('text:START HERE');
    if (quoteHistoryMatched) evidence.push('text:Quote History');
    if (assetsDetailsMatched) evidence.push('text:Assets Details');
    if (extraAnchorMatched) evidence.push('text:summary-anchor-extra');
    if (!summaryAnchorMatched) missing.push('text:Quote History|Assets Details|Contact Information|Family Members|Net Worth');

    let result = 'NOT_DETECTED';
    let confidence = 'none';
    let runtimeState = '';
    if (routeMatched && startHereMatched && summaryAnchorMatched) {
      result = 'DETECTED';
      confidence = 'high';
      runtimeState = 'CUSTOMER_SUMMARY_OVERVIEW';
    } else if (routeMatched && startHereMatched) {
      result = 'PARTIAL';
      confidence = 'medium';
      runtimeState = 'CUSTOMER_SUMMARY_OVERVIEW';
    } else if (routeMatched) {
      result = 'PARTIAL';
      confidence = 'low';
    }

    return {
      result,
      runtimeState,
      confidence,
      urlMatched: urlMatched ? '1' : '0',
      overviewMatched: overviewMatched ? '1' : '0',
      startHereMatched: startHereMatched ? '1' : '0',
      quoteHistoryMatched: quoteHistoryMatched ? '1' : '0',
      assetsDetailsMatched: assetsDetailsMatched ? '1' : '0',
      summaryAnchorMatched: summaryAnchorMatched ? '1' : '0',
      startHereCount: String(startHereCount),
      evidence: compact(evidence.join('|'), 240),
      missing: compact(missing.join('|'), 240),
      url: compact(url, 240)
    };
  };
  const isCustomerSummaryOverviewPage = (source = {}) => {
    const status = customerSummaryOverviewStatus(source);
    return status.urlMatched === '1'
      && status.overviewMatched === '1'
      && status.startHereMatched === '1'
      && (status.confidence === 'high' || status.confidence === 'medium');
  };
  const findCustomerSummaryStartHereTarget = (source = {}) => {
    const status = customerSummaryOverviewStatus(source);
    if (status.urlMatched !== '1' || status.overviewMatched !== '1')
      return { status, target: null, reason: 'no-customer-summary' };
    const startHereText = (getTextArgs(source).customerSummaryStartHereText || 'START HERE (Pre-fill included)');
    const candidates = Array.from(document.querySelectorAll('button,a,[role=button],input[type=button],input[type=submit],[tabindex]'))
      .filter(visible)
      .filter((node) => !isDisabledLike(node))
      .map((node) => {
        const textValue = customerSummaryActionText(node);
        return { node, text: textValue, normalized: normUpper(textValue) };
      })
      .filter(({ text, normalized }) => customerSummaryStartHereTextMatches(text, startHereText)
        && !normalized.includes('ADD PRODUCT'));
    if (!candidates.length) return { status, target: null, reason: 'no-start-here' };
    const score = ({ node, normalized }) => {
      const tag = safe(node.tagName).toUpperCase();
      let value = 0;
      if (tag === 'BUTTON' || tag === 'INPUT') value += 40;
      if ((node.getAttribute && lower(node.getAttribute('role'))) === 'button') value += 30;
      if (tag === 'A') value += 20;
      if (/\bPRE\b.*\bFILL\b/.test(normalized)) value += 10;
      if (normalized === normUpper(startHereText)) value += 5;
      return value;
    };
    candidates.sort((a, b) => score(b) - score(a));
    return { status, target: candidates[0].node, reason: 'matched-start-here' };
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
    const urlLower = lower(url);
    const text = bodyText();
    const urls = getUrlArgs(source);
    const texts = getTextArgs(source);
    const selectors = getSelectorArgs(source);
    const hasFormControls = hasStableVisible(selectors.selectProductProductId || 'SelectProduct.Product')
      || hasStableVisible(selectors.selectProductRatingStateId || 'SelectProduct.RatingState')
      || hasStableVisible(selectors.selectProductContinueId || 'selectProductContinue')
      || hasStableVisible('SelectProduct.Product')
      || hasStableVisible('SelectProduct.RatingState')
      || hasStableVisible('selectProductContinue');
    const configuredNeedle = lower(urls.selectProductContains || '');
    const byUrl = urlLower.includes('/selectproduct') || (!!configuredNeedle && urlLower.includes(configuredNeedle));
    const byText = includesText(text, texts.productOverviewHeading || 'Select Product') && hasFormControls;
    return !isProductOverviewPage(source) && (byUrl || byText);
  };
  const isConsumerReportsPage = (source = {}) => {
    const url = pageUrl();
    const text = bodyText();
    const urls = getUrlArgs(source);
    const byUrl = !!urls.ascProductContains && url.includes(urls.ascProductContains);
    const yesBtn = findByStableId(source.consumerReportsConsentYesId || 'orderReportsConsent-yes-btn');
    return byUrl && (includesText(text, 'order consumer reports') || !!yesBtn);
  };
  const hasDriverVehicleAnchors = () => hasStableVisible('profile-summary-submitBtn')
    || Array.from(document.querySelectorAll('button[id$="-add"],button[id$="-addToQuote"],button[id$="-remove"]')).some((el) => visible(el));
  const isDriversAndVehiclesPage = (source = {}) => {
    const url = pageUrl();
    const text = bodyText();
    const urls = getUrlArgs(source);
    const byUrl = !!urls.ascProductContains && url.includes(urls.ascProductContains);
    return byUrl && includesText(text, 'drivers and vehicles') && hasDriverVehicleAnchors();
  };
  const isIncidentsPage = (source = {}) => {
    const url = pageUrl();
    const text = bodyText();
    const urls = getUrlArgs(source);
    const texts = getTextArgs(source);
    const byUrl = !!urls.ascProductContains && url.includes(urls.ascProductContains);
    return byUrl
      && includesText(text, texts.incidentsHeading || 'Incidents')
      && (hasStableVisible('CONTINUE_OFFER-btn') || includesText(text, 'animal or road debris'));
  };
  const hasQuoteLandingAnchor = (text) => {
    const value = lower(text);
    return value.includes('coverages')
      || value.includes('personalized quote')
      || value.includes('quote details')
      || value.includes('your quote');
  };
  const isQuoteLandingPage = (source = {}) => {
    const url = pageUrl();
    const text = bodyText();
    const urls = getUrlArgs(source);
    const byUrl = !!urls.ascProductContains && url.includes(urls.ascProductContains);
    if (!byUrl) return false;
    if (isConsumerReportsPage(source) || isDriversAndVehiclesPage(source) || isIncidentsPage(source))
      return false;
    return hasQuoteLandingAnchor(text);
  };
  const isAscProductPage = (source = {}) => {
    const url = pageUrl();
    const text = bodyText();
    const urls = getUrlArgs(source);
    const byUrl = !!urls.ascProductContains && url.includes(urls.ascProductContains);
    return byUrl && (
      isConsumerReportsPage(source)
      || isDriversAndVehiclesPage(source)
      || isIncidentsPage(source)
      || hasQuoteLandingAnchor(text)
    );
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
  const isOverviewTileLike = (node) => {
    if (!node || !visible(node)) return false;
    const cls = lower(node.className || '');
    const role = lower(node.getAttribute && node.getAttribute('role'));
    return /\bl-tile\b|tile|card|product|choice|option|selectable/.test(cls)
      || role === 'button'
      || role === 'radio'
      || role === 'option';
  };
  const isOverviewGridColumnOnly = (node) => {
    const cls = lower(node && node.className || '');
    return /\bl-grid__col\b/.test(cls) && !/\bl-tile\b|tile|card|product|choice|option|selectable/.test(cls);
  };
  const isOverviewInteractive = (node) => {
    if (!node || !visible(node)) return false;
    const tag = safe(node.tagName);
    const role = lower(node.getAttribute && node.getAttribute('role'));
    const tabIndex = Number(node.tabIndex);
    return tag === 'BUTTON'
      || tag === 'A'
      || tag === 'LABEL'
      || role === 'button'
      || role === 'radio'
      || role === 'option'
      || tabIndex >= 0;
  };
  const overviewProductLabelPatterns = [
    { label: 'auto', re: /\bauto\b/i },
    { label: 'home', re: /\bhome\b/i },
    { label: 'renters', re: /\brenters\b/i },
    { label: 'pup', re: /\bpup\b/i },
    { label: 'condo', re: /\bcondo\b/i },
    { label: 'motorcycle', re: /\bmotorcycle\b/i },
    { label: 'orv', re: /\borv\b/i },
    { label: 'boat', re: /\bboat\b/i },
    { label: 'motorhome', re: /\bmotor\s*home\b/i },
    { label: 'landlords', re: /\blandlords?\b/i },
    { label: 'manufacturedhome', re: /\bmanufactured\s*home\b/i }
  ];
  const overviewProductLabelCount = (text) => {
    const value = safe(text);
    if (!value) return 0;
    return overviewProductLabelPatterns.reduce((count, entry) => count + (entry.re.test(value) ? 1 : 0), 0);
  };
  const overviewIsBroadProductContainer = (node, wantedText) => {
    if (!node) return false;
    const text = getText(node);
    if (!text || !normLower(text).includes(normLower(wantedText))) return false;
    return overviewProductLabelCount(text) > 1;
  };
  const overviewTileCandidateRank = (node) => {
    const cls = lower(node && node.className || '');
    const role = lower(node && node.getAttribute && node.getAttribute('role'));
    if (/\bl-tile\b|c-tile|product-card|product-tile/.test(cls)) return 0;
    if (/tile|card|product|choice|option|selectable/.test(cls)) return 1;
    if (role === 'button' || role === 'radio' || role === 'option') return 2;
    if (isOverviewInteractive(node)) return 3;
    return 4;
  };
  const overviewTextMatchesProduct = (text, wantedText) => {
    const textNorm = normLower(text);
    const wanted = normLower(wantedText);
    if (!wanted) return false;
    if (overviewProductLabelCount(text) > 1) return false;
    return textNorm === wanted || (textNorm.startsWith(wanted) && textNorm.length <= 80);
  };
  const findOverviewTileContainerFromSeed = (seed, wantedText) => {
    let best = null;
    let rejectedBroadContainer = false;
    const consider = (node) => {
      if (!node || !visible(node)) return false;
      const text = getText(node);
      if (text && !normLower(text).includes(normLower(wantedText))) return false;
      if (isOverviewGridColumnOnly(node)) return false;
      if (overviewIsBroadProductContainer(node, wantedText)) {
        rejectedBroadContainer = true;
        return false;
      }
      if (isOverviewTileLike(node)) {
        best = node;
        return /\bl-tile\b/.test(lower(node.className || ''));
      }
      return false;
    };
    for (let depth = 0, current = seed; depth < 8 && current; depth++, current = current.parentElement) {
      if (consider(current))
        return { container: best, rejectedBroadContainer };
    }
    if (seed && seed.querySelector) {
      const descendantTile = Array.from(seed.querySelectorAll('.l-tile,.c-tile,.product-card,.product-tile,[role=button],[role=radio],[role=option]'))
        .filter((node) => visible(node) && normLower(getText(node)).includes(normLower(wantedText)))
        .filter((node) => !isOverviewGridColumnOnly(node))
        .filter((node) => {
          const broad = overviewIsBroadProductContainer(node, wantedText);
          if (broad) rejectedBroadContainer = true;
          return !broad;
        })
        .sort((a, b) => overviewTileCandidateRank(a) - overviewTileCandidateRank(b) || getText(a).length - getText(b).length)[0] || null;
      if (descendantTile) return { container: descendantTile, rejectedBroadContainer };
    }
    if (!best && seed && !overviewIsBroadProductContainer(seed, wantedText) && !isOverviewGridColumnOnly(seed))
      best = seed;
    return { container: best, rejectedBroadContainer };
  };
  const findOverviewClickableTarget = (tileContainer, seed, wantedText) => {
    const candidates = [];
    if (isOverviewInteractive(tileContainer)) candidates.push(tileContainer);
    if (tileContainer && tileContainer.querySelectorAll) {
      candidates.push(...Array.from(tileContainer.querySelectorAll('button,a,label,[role=button],[role=radio],[role=option],[tabindex]'))
        .filter(visible)
        .filter((node) => {
          const text = getText(node);
          return !text || overviewTextMatchesProduct(text, wantedText) || normLower(text).includes(normLower(wantedText));
        }));
    }
    if (isOverviewInteractive(seed)) candidates.push(seed);
    const picked = candidates.find((node) => node && !isDisabledLike(node)) || null;
    return picked || tileContainer || seed;
  };
  const findOverviewProductTile = (wantedText) => {
    const wanted = normLower(wantedText);
    if (!wanted) return null;
    const seeds = Array.from(document.querySelectorAll('button,a,[role=button],[role=radio],[role=option],label,[tabindex],div,span,h1,h2,h3,h4,h5,p,li'))
      .filter(visible)
      .map((node) => ({ node, text: getText(node) }))
      .filter(({ text }) => overviewTextMatchesProduct(text, wantedText))
      .filter(({ text }) => {
        const textNorm = normLower(text);
        return !textNorm.includes('add product')
          && !textNorm.includes('start quote')
          && !textNorm.includes('create quotes')
          && !textNorm.includes('order reports');
      })
      .sort((a, b) => a.text.length - b.text.length);
    for (const { node: seed, text } of seeds) {
      const resolved = findOverviewTileContainerFromSeed(seed, wantedText);
      const tileContainer = resolved.container;
      if (!tileContainer || isOverviewGridColumnOnly(tileContainer)) continue;
      const clickableTarget = findOverviewClickableTarget(tileContainer, seed, wantedText);
      return {
        textNode: seed,
        tileContainer,
        clickableTarget,
        tileText: compact(getText(tileContainer) || text, 160),
        tileContainerText: compact(getText(tileContainer) || text, 240),
        tileProductLabelCount: String(overviewProductLabelCount(getText(tileContainer))),
        rejectedBroadContainer: resolved.rejectedBroadContainer ? '1' : '0',
        method: clickableTarget && clickableTarget !== tileContainer ? 'interactive-descendant' : 'tile-container',
        resolverMethod: 'a3-text-seed-tile-card-target',
        textSeedTag: safe(seed.tagName),
        textSeedText: compact(text, 120),
        textSeedClass: compact(safe(seed.className), 160)
      };
    }
    return null;
  };
  const findOverviewProductTileTarget = (wantedText) => {
    const tile = findOverviewProductTile(wantedText);
    return tile ? (tile.clickableTarget || tile.tileContainer || tile.textNode) : null;
  };
  const summarizeOverviewTileNode = (node) => {
    if (!node) return '';
    const tag = safe(node.tagName).toLowerCase();
    const id = safe(node.id);
    const role = safe(node.getAttribute && node.getAttribute('role'));
    const cls = compact(safe(node.className), 80);
    return [tag, id ? `#${id}` : '', role ? `[role=${role}]` : '', cls ? `.${cls.replace(/\s+/g, '.')}` : ''].join('');
  };
  const overviewSelectedClassRe = /(^|[\s_-])((is|c|l-tile|c-tile)-)?(selected|active|checked|chosen|current|pressed|on)([\s_-]|$)|--selected|--active|--checked/i;
  const overviewStateSelectedRe = /(^|[\s_-])(selected|active|checked|chosen|current|pressed|on|true)([\s_-]|$)/i;
  const overviewTileSelectionEvidence = (tile, productText) => {
    const target = tile && (tile.clickableTarget || tile.tileContainer || tile.textNode);
    const tileContainer = tile && (tile.tileContainer || target);
    const wanted = normLower(productText);
    const nodes = [];
    const addNode = (node, depth, source) => {
      if (!node || !visible(node)) return;
      if (nodes.some((entry) => entry.node === node)) return;
      const text = compact(getText(node), 360);
      if (source === 'target' || source === 'tile' || (text && text.length <= 420 && (!wanted || normLower(text).includes(wanted))))
        nodes.push({ node, depth, source });
    };
    addNode(target, 0, 'target');
    addNode(tileContainer, 0, 'tile');
    for (let depth = 1, current = tileContainer && tileContainer.parentElement; depth < 6 && current; depth++, current = current.parentElement) {
      addNode(current, depth, 'ancestor');
    }
    const hasSelectedClass = (node) => overviewSelectedClassRe.test(safe(node.className || ''));
    const hasSelectedState = (node) => overviewStateSelectedRe.test(safe(node.getAttribute && node.getAttribute('data-state')));
    let checkedDescendant = '';
    let selectedDescendant = '';
    let checkmarkEvidence = '';
    const ancestorSummary = () => nodes.filter(({ source }) => source === 'ancestor').map(({ node: item }) => summarizeOverviewTileNode(item)).filter(Boolean).join(' > ');
    for (const { node, depth, source } of nodes) {
      const prefix = source === 'target' ? 'target' : (source === 'tile' ? 'tile-container' : `ancestor-${depth}`);
      if (/^(INPUT|OPTION)$/i.test(safe(node.tagName)) && 'checked' in node && node.checked)
        return { selected: true, evidence: `${prefix}-checked`, selectedClassSource: '', selectedAriaSource: '', selectedDataStateSource: '', checkedDescendant: checkedDescendant ? '1' : '0', selectedDescendant: selectedDescendant ? '1' : '0', checkmarkEvidence, ancestorSummary: ancestorSummary() };
      if (safe(node.getAttribute && node.getAttribute('aria-selected')) === 'true')
        return { selected: true, evidence: `${prefix}-aria-selected`, selectedClassSource: '', selectedAriaSource: summarizeOverviewTileNode(node), selectedDataStateSource: '', checkedDescendant: checkedDescendant ? '1' : '0', selectedDescendant: selectedDescendant ? '1' : '0', checkmarkEvidence, ancestorSummary: ancestorSummary() };
      if (safe(node.getAttribute && node.getAttribute('aria-checked')) === 'true')
        return { selected: true, evidence: `${prefix}-aria-checked`, selectedClassSource: '', selectedAriaSource: summarizeOverviewTileNode(node), selectedDataStateSource: '', checkedDescendant: checkedDescendant ? '1' : '0', selectedDescendant: selectedDescendant ? '1' : '0', checkmarkEvidence, ancestorSummary: ancestorSummary() };
      if (safe(node.getAttribute && node.getAttribute('aria-pressed')) === 'true')
        return { selected: true, evidence: `${prefix}-aria-pressed`, selectedClassSource: '', selectedAriaSource: summarizeOverviewTileNode(node), selectedDataStateSource: '', checkedDescendant: checkedDescendant ? '1' : '0', selectedDescendant: selectedDescendant ? '1' : '0', checkmarkEvidence, ancestorSummary: ancestorSummary() };
      if (hasSelectedClass(node))
        return { selected: true, evidence: `${prefix}-class`, selectedClassSource: summarizeOverviewTileNode(node), selectedAriaSource: '', selectedDataStateSource: '', checkedDescendant: checkedDescendant ? '1' : '0', selectedDescendant: selectedDescendant ? '1' : '0', checkmarkEvidence, ancestorSummary: ancestorSummary() };
      if (hasSelectedState(node))
        return { selected: true, evidence: `${prefix}-data-state`, selectedClassSource: '', selectedAriaSource: '', selectedDataStateSource: summarizeOverviewTileNode(node), checkedDescendant: checkedDescendant ? '1' : '0', selectedDescendant: selectedDescendant ? '1' : '0', checkmarkEvidence, ancestorSummary: ancestorSummary() };
      const checked = node.querySelector && node.querySelector('input:checked');
      if (checked) {
        checkedDescendant = summarizeOverviewTileNode(checked) || 'input:checked';
        return { selected: true, evidence: `${prefix}-checked-descendant`, selectedClassSource: '', selectedAriaSource: '', selectedDataStateSource: '', checkedDescendant: '1', selectedDescendant: selectedDescendant ? '1' : '0', checkmarkEvidence, ancestorSummary: ancestorSummary() };
      }
      const selectedNode = node.querySelector && Array.from(node.querySelectorAll('[aria-selected="true"],[aria-checked="true"],[aria-pressed="true"],[class],[data-state]')).find((candidate) => {
        if (safe(candidate.getAttribute && candidate.getAttribute('aria-selected')) === 'true') return true;
        if (safe(candidate.getAttribute && candidate.getAttribute('aria-checked')) === 'true') return true;
        if (safe(candidate.getAttribute && candidate.getAttribute('aria-pressed')) === 'true') return true;
        if (hasSelectedClass(candidate)) return true;
        if (hasSelectedState(candidate)) return true;
        return false;
      });
      if (selectedNode) {
        selectedDescendant = summarizeOverviewTileNode(selectedNode) || 'selected-descendant';
        const selectedByClass = hasSelectedClass(selectedNode);
        const selectedByState = hasSelectedState(selectedNode);
        return { selected: true, evidence: `${prefix}-selected-descendant`, selectedClassSource: selectedByClass ? summarizeOverviewTileNode(selectedNode) : '', selectedAriaSource: selectedByClass || selectedByState ? '' : summarizeOverviewTileNode(selectedNode), selectedDataStateSource: selectedByState ? summarizeOverviewTileNode(selectedNode) : '', checkedDescendant: checkedDescendant ? '1' : '0', selectedDescendant: '1', checkmarkEvidence, ancestorSummary: ancestorSummary() };
      }
    }
    if (tileContainer && tileContainer.querySelectorAll) {
      const checkmark = Array.from(tileContainer.querySelectorAll('[class*="check"],[class*="tick"],[class*="selected"],svg,i,span'))
        .filter(visible)
        .find((node) => {
          const text = lower(getText(node));
          const cls = lower(node.className || '');
          const label = lower(node.getAttribute && (node.getAttribute('aria-label') || node.getAttribute('title')));
          return /✓|check|checkmark|tick|selected/.test(text)
            || /check|checkmark|tick|selected/.test(cls)
            || /check|checkmark|tick|selected/.test(label);
        });
      if (checkmark) {
        checkmarkEvidence = summarizeOverviewTileNode(checkmark) || 'checkmark';
        return { selected: true, evidence: 'tile-container-checkmark', selectedClassSource: '', selectedAriaSource: '', selectedDataStateSource: '', checkedDescendant: checkedDescendant ? '1' : '0', selectedDescendant: selectedDescendant ? '1' : '0', checkmarkEvidence, ancestorSummary: ancestorSummary() };
      }
    }
    return { selected: false, evidence: '', selectedClassSource: '', selectedAriaSource: '', selectedDataStateSource: '', checkedDescendant: checkedDescendant ? '1' : '0', selectedDescendant: selectedDescendant ? '1' : '0', checkmarkEvidence, ancestorSummary: ancestorSummary() };
  };
  const overviewTileEmptyState = (result, productText, method) => ({
    result,
    present: '0',
    selected: '0',
    productText,
    tileText: '',
    method,
    selectedEvidence: '',
    targetTag: '',
    targetId: '',
    targetClass: '',
    targetRole: '',
    targetAriaSelected: '',
    targetAriaChecked: '',
    targetAriaPressed: '',
    targetDataState: '',
    tileContainerTag: '',
    tileContainerId: '',
    tileContainerClass: '',
    clickableTag: '',
    clickableId: '',
    clickableClass: '',
    clickableRole: '',
    selectedClassSource: '',
    selectedAriaSource: '',
    selectedDataStateSource: '',
    ancestorSummary: '',
    checkedDescendant: '0',
    selectedDescendant: '0',
    checkmarkEvidence: '',
    resolverMethod: method,
    textSeedTag: '',
    textSeedText: '',
    textSeedClass: '',
    tileContainerText: '',
    tileProductLabelCount: '0',
    rejectedBroadContainer: '0',
    clickTargetTag: '',
    clickTargetClass: '',
    clickTargetRole: '',
    clickAttemptCount: '0',
    selectedBefore: '0',
    selectedAfter: '0',
    elementFromPointTag: '',
    elementFromPointClass: ''
  });
  const readOverviewProductTileState = (source = {}) => {
    const productText = safe(source.productText || (getTextArgs(source).productOverviewAutoTile || 'Auto'));
    if (!isProductOverviewPage(source))
      return overviewTileEmptyState('NOT_OVERVIEW', productText, 'not-overview');
    const tile = findOverviewProductTile(productText);
    if (!tile)
      return overviewTileEmptyState('NO_TILE', productText, 'not-found');
    const target = tile.clickableTarget || tile.tileContainer || tile.textNode;
    const tileContainer = tile.tileContainer || target;
    const clickable = tile.clickableTarget || target;
    const rect = clickable && clickable.getBoundingClientRect ? clickable.getBoundingClientRect() : null;
    const fromPoint = rect ? document.elementFromPoint(rect.left + (rect.width / 2), rect.top + (rect.height / 2)) : null;
    const evidence = overviewTileSelectionEvidence(tile, productText);
    const selected = evidence.selected ? '1' : '0';
    return {
      result: selected === '1' ? 'SELECTED' : 'FOUND',
      present: '1',
      selected,
      productText,
      tileText: tile.tileText,
      method: tile.method,
      selectedEvidence: evidence.evidence,
      targetTag: safe(target.tagName),
      targetId: safe(target.id),
      targetClass: compact(safe(target.className), 160),
      targetRole: safe(target.getAttribute && target.getAttribute('role')),
      targetAriaSelected: safe(target.getAttribute && target.getAttribute('aria-selected')),
      targetAriaChecked: safe(target.getAttribute && target.getAttribute('aria-checked')),
      targetAriaPressed: safe(target.getAttribute && target.getAttribute('aria-pressed')),
      targetDataState: safe(target.getAttribute && target.getAttribute('data-state')),
      tileContainerTag: safe(tileContainer.tagName),
      tileContainerId: safe(tileContainer.id),
      tileContainerClass: compact(safe(tileContainer.className), 160),
      clickableTag: safe(clickable.tagName),
      clickableId: safe(clickable.id),
      clickableClass: compact(safe(clickable.className), 160),
      clickableRole: safe(clickable.getAttribute && clickable.getAttribute('role')),
      selectedClassSource: compact(evidence.selectedClassSource, 160),
      selectedAriaSource: compact(evidence.selectedAriaSource, 160),
      selectedDataStateSource: compact(evidence.selectedDataStateSource, 160),
      ancestorSummary: compact(evidence.ancestorSummary, 240),
      checkedDescendant: evidence.checkedDescendant,
      selectedDescendant: evidence.selectedDescendant,
      checkmarkEvidence: compact(evidence.checkmarkEvidence, 160),
      resolverMethod: tile.resolverMethod,
      textSeedTag: tile.textSeedTag,
      textSeedText: tile.textSeedText,
      textSeedClass: tile.textSeedClass,
      tileContainerText: tile.tileContainerText,
      tileProductLabelCount: tile.tileProductLabelCount,
      rejectedBroadContainer: tile.rejectedBroadContainer,
      clickTargetTag: safe(clickable.tagName),
      clickTargetClass: compact(safe(clickable.className), 160),
      clickTargetRole: safe(clickable.getAttribute && clickable.getAttribute('role')),
      clickAttemptCount: '0',
      selectedBefore: selected,
      selectedAfter: selected,
      elementFromPointTag: safe(fromPoint && fromPoint.tagName),
      elementFromPointClass: compact(safe(fromPoint && fromPoint.className), 160)
    };
  };
  const ensureOverviewProductTileSelected = (source = {}) => {
    const productText = safe(source.productText || (getTextArgs(source).productOverviewAutoTile || 'Auto'));
    const before = readOverviewProductTileState(source);
    const base = (result, extra = {}) => ({
      result,
      present: before.present || '0',
      selectedBefore: before.selected || '0',
      selectedAfter: before.selected || '0',
      clicked: '0',
      productText,
      tileText: before.tileText || '',
      selectedEvidence: before.selectedEvidence || '',
      targetTag: before.targetTag || '',
      targetClass: before.targetClass || '',
      tileContainerClass: before.tileContainerClass || '',
      resolverMethod: before.resolverMethod || '',
      textSeedTag: before.textSeedTag || '',
      textSeedText: before.textSeedText || '',
      textSeedClass: before.textSeedClass || '',
      tileContainerText: before.tileContainerText || '',
      tileProductLabelCount: before.tileProductLabelCount || '0',
      rejectedBroadContainer: before.rejectedBroadContainer || '0',
      clickTargetTag: before.clickTargetTag || before.clickableTag || '',
      clickTargetClass: before.clickTargetClass || before.clickableClass || '',
      clickTargetRole: before.clickTargetRole || before.clickableRole || '',
      clickAttemptCount: '0',
      method: before.method || '',
      failedFields: '',
      evidence: compact(before.selectedEvidence || before.method || before.result || '', 240),
      ...extra
    });
    if (before.result === 'NOT_OVERVIEW')
      return base('NOT_OVERVIEW', { failedFields: 'overview', evidence: 'not-product-overview' });
    if (before.present !== '1')
      return base('NO_TILE', { failedFields: 'autoTile', evidence: before.result || 'no-auto-tile' });
    if (before.selected === '1')
      return base('SELECTED');
    const tile = findOverviewProductTile(productText);
    const target = tile && (tile.clickableTarget || tile.tileContainer || tile.textNode);
    if (!target)
      return base('NO_TILE', { failedFields: 'autoTile', evidence: 'no-click-target' });
    const clicked = clickCenterEl(target);
    if (!clicked)
      return base('CLICK_FAILED', {
        clicked: '0',
        failedFields: 'click',
        targetTag: safe(target.tagName),
        targetClass: compact(safe(target.className), 160),
        clickTargetTag: safe(target.tagName),
        clickTargetClass: compact(safe(target.className), 160),
        clickTargetRole: safe(target.getAttribute && target.getAttribute('role')),
        clickAttemptCount: '1',
        evidence: 'click-failed'
      });
    const after = readOverviewProductTileState(source);
    const selectedAfter = after.selected || '0';
    return base(selectedAfter === '1' ? 'CLICKED_SELECTED' : 'VERIFY_FAILED', {
      present: after.present || before.present || '0',
      selectedAfter,
      clicked: '1',
      tileText: after.tileText || before.tileText || '',
      selectedEvidence: after.selectedEvidence || '',
      targetTag: after.targetTag || safe(target.tagName),
      targetClass: after.targetClass || compact(safe(target.className), 160),
      tileContainerClass: after.tileContainerClass || before.tileContainerClass || '',
      resolverMethod: after.resolverMethod || before.resolverMethod || '',
      textSeedTag: after.textSeedTag || before.textSeedTag || '',
      textSeedText: after.textSeedText || before.textSeedText || '',
      textSeedClass: after.textSeedClass || before.textSeedClass || '',
      tileContainerText: after.tileContainerText || before.tileContainerText || '',
      tileProductLabelCount: after.tileProductLabelCount || before.tileProductLabelCount || '0',
      rejectedBroadContainer: (before.rejectedBroadContainer === '1' || after.rejectedBroadContainer === '1') ? '1' : '0',
      clickTargetTag: after.clickTargetTag || safe(target.tagName),
      clickTargetClass: after.clickTargetClass || compact(safe(target.className), 160),
      clickTargetRole: after.clickTargetRole || safe(target.getAttribute && target.getAttribute('role')),
      clickAttemptCount: '1',
      method: `${before.method || 'tile'}|click`,
      failedFields: selectedAfter === '1' ? '' : 'selected',
      evidence: compact(after.selectedEvidence || after.result || 'post-click-unselected', 240)
    });
  };
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
    if (!el || !visible(el) || isDisabledLike(el)) return false;
    try { el.scrollIntoView({ block: 'center', inline: 'center' }); } catch {}
    const rect = el.getBoundingClientRect();
    const x = rect.left + (rect.width / 2);
    const y = rect.top + (rect.height / 2);
    const fromPoint = document.elementFromPoint(x, y);
    const target = findClickableTarget(fromPoint && visible(fromPoint) ? fromPoint : el);
    return clickEl(target || el, { preClickSequence: !!target && target !== el });
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
    const clicked = clickCenterEl(target);
    const verified = !!match.checked || isSelectedNode(match) || isSelectedNode(target);
    return {
      ok: clicked && verified,
      method: target === match ? 'radio-input' : 'radio-associated-control'
    };
  };
  const findQuestionContainers = (questionText, root = document) => {
    const wanted = normLower(questionText);
    if (!wanted) return [];
    const scope = root && root.querySelectorAll ? root : document;
    const seedNodes = Array.from(scope.querySelectorAll('legend,label,.c-label,p,span,div,h1,h2,h3,h4,h5,h6'));
    if (scope !== document && visible(scope) && normLower(getText(scope)).includes(wanted))
      seedNodes.unshift(scope);
    const seeds = seedNodes
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
  const semanticAnswerCandidates = (questionText, answerText, root = document) => {
    const containers = findQuestionContainers(questionText, root);
    const wantedAnswer = normUpper(answerText);
    const out = [];
    const seenTargets = new Set();
    for (const container of containers) {
      const radios = Array.from(container.querySelectorAll('input[type=radio]'));
      for (const radio of radios) {
        const labelText = readInputLabel(radio) || safe(radio.value);
        if (!answerTextMatches(labelText, answerText)) continue;
        const target = getInputClickTarget(radio);
        if (!target) continue;
        if (seenTargets.has(target)) continue;
        seenTargets.add(target);
        out.push({ node: radio, target, value: wantedAnswer, source: 'radio' });
      }
      const nodes = Array.from(container.querySelectorAll('button,a,[role=button],[role=radio],label,span,div'))
        .filter((node) => visible(node) && node !== container)
        .map((node) => ({ node, text: getText(node) || safe(node.getAttribute && node.getAttribute('aria-label')) || safe(node.value) }))
        .filter(({ text }) => text && !isCompoundYesNoText(text) && text.length <= Math.max(20, safe(answerText).length + 8) && answerTextMatches(text, answerText))
        .sort((a, b) => a.text.length - b.text.length);
      for (const candidate of nodes) {
        const target = findClickableTarget(candidate.node);
        if (!target) continue;
        if (seenTargets.has(target)) continue;
        seenTargets.add(target);
        out.push({ node: candidate.node, target, value: wantedAnswer, source: safe(candidate.node.getAttribute && candidate.node.getAttribute('role')) || 'semantic' });
      }
    }
    return out;
  };
  const findSemanticAnswerTarget = (questionText, answerText, root = document) => {
    const candidates = semanticAnswerCandidates(questionText, answerText, root);
    return candidates.length ? candidates[0].target : null;
  };
  const findUniqueSemanticAnswerTarget = (questionText, answerText, root = document) => {
    const candidates = semanticAnswerCandidates(questionText, answerText, root);
    if (candidates.length !== 1)
      return { ok: false, method: candidates.length ? 'ambiguous-semantic-target' : 'semantic-target-missing', count: String(candidates.length), target: null };
    return { ok: true, method: candidates[0].source || 'semantic-target', count: '1', target: candidates[0].target };
  };
  const readSemanticAnswerState = (questionText, root = document) => {
    const values = ['YES', 'NO'];
    const containers = findQuestionContainers(questionText, root);
    const selected = [];
    let controlCount = 0;
    for (const container of containers) {
      const radios = Array.from(container.querySelectorAll('input[type=radio]'));
      for (const radio of radios) {
        const labelText = normUpper(readInputLabel(radio) || radio.value);
        const value = values.find((wanted) => answerTextMatches(labelText, wanted));
        if (!value) continue;
        controlCount += 1;
        if (radio.checked) selected.push({ value, source: 'radio' });
      }
      const nodes = Array.from(container.querySelectorAll('button,a,[role=button],[role=radio],label,span,div'))
        .filter((node) => visible(node) && node !== container);
      for (const node of nodes) {
        const text = getText(node) || safe(node.getAttribute && node.getAttribute('aria-label')) || safe(node.value);
        if (isCompoundYesNoText(text)) continue;
        const value = values.find((wanted) => answerTextMatches(text, wanted));
        if (!value) continue;
        controlCount += 1;
        if (isSelectedNode(node)) selected.push({ value, source: safe(node.getAttribute && node.getAttribute('role')) || 'semantic' });
      }
    }
    const uniqueSelected = Array.from(new Set(selected.map((item) => item.value)));
    if (uniqueSelected.length === 1) {
      const hit = selected.find((item) => item.value === uniqueSelected[0]) || {};
      return { value: uniqueSelected[0], selected: true, source: hit.source || 'semantic', controlCount: String(controlCount), ambiguous: false };
    }
    if (uniqueSelected.length > 1)
      return { value: uniqueSelected.join('|'), selected: true, source: 'ambiguous', controlCount: String(controlCount), ambiguous: true };
    return { value: '', selected: false, source: containers.length ? 'question-found' : '', controlCount: String(controlCount), ambiguous: false };
  };
  const normalizeYesNoValue = (value) => {
    const text = normUpper(value);
    if (/\b(NO|N|FALSE|0)\b/.test(text) || /_FALSE\b|\bFALSE_/.test(text)) return 'NO';
    if (/\b(YES|Y|TRUE|1)\b/.test(text) || /_TRUE\b|\bTRUE_/.test(text)) return 'YES';
    return '';
  };
  const scopedRadioGroupControls = (root, nameRe) => {
    const scope = root && root.querySelectorAll ? root : document;
    return Array.from(scope.querySelectorAll('input[type=radio],input[type=checkbox]'))
      .filter(visible)
      .filter((el) => nameRe.test(`${safe(el.name)} ${safe(el.id)}`));
  };
  const readScopedYesNoGroupState = (root, nameRe) => {
    const controls = scopedRadioGroupControls(root, nameRe);
    const selected = controls.find((el) => el.checked || isSelectedNode(el));
    if (!selected)
      return { value: '', selected: false, source: controls.length ? 'radio-name' : '', controlCount: String(controls.length), label: '' };
    const value = normalizeYesNoValue(`${safe(selected.value)} ${readInputLabel(selected)} ${safe(selected.id)} ${safe(selected.name)}`);
    return {
      value,
      selected: !!value,
      source: 'radio-name',
      controlCount: String(controls.length),
      label: readInputLabel(selected)
    };
  };
  const selectScopedYesNoByName = (root, nameRe, wantedValue) => {
    const wanted = normUpper(wantedValue);
    const controls = scopedRadioGroupControls(root, nameRe);
    const candidates = controls.filter((el) => normalizeYesNoValue(`${safe(el.value)} ${readInputLabel(el)} ${safe(el.id)} ${safe(el.name)}`) === wanted);
    if (candidates.length !== 1)
      return { ok: false, method: candidates.length ? 'ambiguous-radio-target' : (controls.length ? 'radio-answer-missing' : 'radio-group-missing'), count: String(candidates.length) };
    const target = getInputClickTarget(candidates[0]) || candidates[0];
    const clicked = clickCenterEl(target);
    const state = readScopedYesNoGroupState(root, nameRe);
    return {
      ok: clicked && state.value === wanted,
      method: clicked ? 'radio-click' : 'radio-click-failed',
      count: '1',
      state
    };
  };
  const answerValueMatches = (actual, wanted) => {
    const actualNorm = normUpper(actual);
    const wantedNorm = normUpper(wanted);
    return !!wantedNorm && (actualNorm === wantedNorm || actualNorm.includes(wantedNorm) || wantedNorm.includes(actualNorm));
  };
  const readRadioGroupStateByName = (namePart) => {
    const radios = Array.from(document.querySelectorAll('input[type=radio]'))
      .filter((el) => safe(el.name).includes(safe(namePart)));
    for (const radio of radios) {
      if (!radio.checked) continue;
      return {
        value: safe(radio.value),
        label: readInputLabel(radio),
        selected: true,
        source: 'radio-name'
      };
    }
    return { value: '', label: '', selected: false, source: radios.length ? 'radio-name' : '' };
  };
  const normalizeVehicleText = (value) => normUpper(value)
    .replace(/\bF[\s-]+(\d{3,4})\b/g, 'F$1')
    .replace(/\bMODEL[\s-]+(\d)\b/g, 'MODEL $1');
  const normalizeVehicleVin = (value) => normUpper(value).replace(/[^A-Z0-9]/g, '');
  const parseVehicleListArg = (value) => {
    if (Array.isArray(value)) return value.map((item) => safe(item).trim()).filter(Boolean);
    return safe(value)
      .split(/[|,;]/)
      .map((item) => item.trim())
      .filter(Boolean);
  };
  const normalizeVehicleModelKey = (value) => normalizeVehicleText(value)
    .replace(/\bCR\s+V\b/g, 'CRV')
    .replace(/\bHR\s+V\b/g, 'HRV')
    .replace(/\bCX\s+30\b/g, 'CX30')
    .replace(/\bGLE\s+350\b/g, 'GLE350')
    .replace(/\b4\s+RUNNER\b/g, '4RUNNER')
    .replace(/\bGRAND\s+CARAVN\b/g, 'GRAND CARAVAN')
    .replace(/\bSILV\s*(1500|2500|3500)\b/g, 'SILVERADO $1')
    .replace(/\bF\s+(150|250|350|450)\b/g, 'F$1')
    .replace(/[^A-Z0-9]/g, '');
  const vehicleTokenRegex = (token) => new RegExp(`(^|[^A-Z0-9])${token.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}([^A-Z0-9]|$)`);
  const vehicleCompactModelRegex = (key) => {
    if (/^(CR|HR)V$/.test(key))
      return new RegExp(`(^|[^A-Z0-9])${key.slice(0, 1)}[\\s-]*R[\\s-]*V([^A-Z0-9]|$)`);
    if (/^CX\d{2}$/.test(key))
      return new RegExp(`(^|[^A-Z0-9])C[\\s-]*X[\\s-]*${key.slice(2)}([^A-Z0-9]|$)`);
    if (/^QX\d{2}$/.test(key))
      return new RegExp(`(^|[^A-Z0-9])Q[\\s-]*X[\\s-]*${key.slice(2)}([^A-Z0-9]|$)`);
    if (/^GLE\d{3}$/.test(key))
      return new RegExp(`(^|[^A-Z0-9])GLE[\\s-]*${key.slice(3)}([^A-Z0-9]|$)`);
    if (/^F\d{3,4}$/.test(key))
      return new RegExp(`(^|[^A-Z0-9])F[\\s-]*${key.slice(1)}([^A-Z0-9]|$)`);
    if (key === '4RUNNER')
      return /(^|[^A-Z0-9])4[\s-]*RUNNER([^A-Z0-9]|$)/;
    return null;
  };
  const vehicleMakeMatches = (haystack, match) => {
    const labels = (match.allowedMakeLabels || []).map(normalizeVehicleText).filter(Boolean);
    if (labels.length)
      return labels.some((label) => vehicleTokenRegex(label).test(haystack));
    return !!match.make && haystack.includes(match.make);
  };
  const vehicleStrictModelMatches = (haystack, expectedModel) => {
    const model = normalizeVehicleText(expectedModel);
    const key = normalizeVehicleModelKey(expectedModel);
    if (!model || !key) return false;
    return vehicleStrictModelKeyMatches(haystack, key, model);
  };
  const vehicleStrictModelKeyMatches = (haystack, key, model = '') => {
    key = safe(key).replace(/[^A-Z0-9]/g, '');
    model = normalizeVehicleText(model);
    if (!key) return false;
    const haystackKey = normalizeVehicleModelKey(haystack);
    if (key === 'PRIUS' && /(^|[^A-Z0-9])PRIUS\s+PRIME([^A-Z0-9]|$)/.test(haystack)) return false;
    if (key === 'PRIUSPRIME')
      return /(^|[^A-Z0-9])PRIUS\s+PRIME([^A-Z0-9]|$)/.test(haystack);
    if (key === 'TRANSIT' && /(^|[^A-Z0-9])TRANSIT\s+(CONN|CONNECT)([^A-Z0-9]|$)/.test(haystack)) return false;
    if (key === 'EXPRESS' && /(^|[^A-Z0-9])CITY\s+EXPRESS([^A-Z0-9]|$)/.test(haystack)) return false;
    if (/^SILVERADO(1500|2500|3500)$/.test(key)) {
      const series = key.match(/(1500|2500|3500)$/)[1];
      return haystackKey.includes(`SILVERADO${series}`);
    }
    if (key === 'GRANDCARAVAN')
      return haystackKey.includes('GRANDCARAVAN');
    const compactRegex = vehicleCompactModelRegex(key);
    if (compactRegex) return compactRegex.test(haystack);
    if (model) return vehicleTokenRegex(model).test(haystack);
    return haystackKey.includes(key);
  };
  const vehicleModelMatches = (haystack, match) => {
    const keys = (match.normalizedModelKeys || []).map((value) => safe(value).replace(/[^A-Z0-9]/g, '')).filter(Boolean);
    const aliases = (match.modelAliases || []).map(normalizeVehicleText).filter(Boolean);
    if (match.strictModelMatch) {
      for (const key of keys) {
        const alias = aliases.find((value) => normalizeVehicleModelKey(value) === key) || '';
        if (vehicleStrictModelKeyMatches(haystack, key, alias)) return true;
      }
      if (match.model && vehicleStrictModelMatches(haystack, match.model)) return true;
      return aliases.some((alias) => vehicleStrictModelMatches(haystack, alias));
    }
    if (match.model && haystack.includes(match.model)) return true;
    return aliases.some((alias) => haystack.includes(alias));
  };
  const getVehicleMatchArgs = (source = {}) => {
    const vin = normalizeVehicleVin(source.vin);
    const vinSuffix = normalizeVehicleVin(source.vinSuffix || (vin ? vin.slice(-6) : ''));
    const modelAliases = parseVehicleListArg(source.modelAliases).map(normalizeVehicleText).filter(Boolean);
    const normalizedModelKeys = parseVehicleListArg(source.normalizedModelKeys)
      .map((value) => normalizeVehicleModelKey(value) || safe(value).toUpperCase().replace(/[^A-Z0-9]/g, ''))
      .filter(Boolean);
    return {
      year: safe(source.year).trim(),
      make: normalizeVehicleText(source.make),
      model: normalizeVehicleText(source.model),
      trim: normalizeVehicleText(source.trim || source.trimHint),
      vin,
      vinSuffix,
      allowedMakeLabels: parseVehicleListArg(source.allowedMakeLabels || source.makeAliases || source.advisorMakeLabels),
      modelAliases,
      normalizedModelKeys,
      strictModelMatch: safe(source.strictModelMatch) === '1' || source.strictModelMatch === true
    };
  };
  const vehicleYearDelta = (cardText, expectedYear) => {
    const wanted = Number(safe(expectedYear).trim());
    if (!wanted) return null;
    const years = (safe(cardText).match(/\b(?:19|20)\d{2}\b/g) || [])
      .map((value) => Number(value))
      .filter(Boolean);
    if (!years.length) return null;
    return years
      .map((year) => year - wanted)
      .sort((a, b) => Math.abs(a) - Math.abs(b))[0];
  };
  const vehicleModelFamilyRelated = (haystack, match) => {
    const key = normalizeVehicleModelKey(match.model || (match.modelAliases || [])[0] || '');
    const haystackKey = normalizeVehicleModelKey(haystack);
    if (!key || !haystackKey) return false;
    if (/^F\d{3,4}/.test(key) && /FSERIES|F150|F250|F350|F450/.test(haystackKey)) return true;
    if (key.startsWith('WRANGLER') && haystackKey.includes('WRANGLER')) return true;
    if (key.startsWith('SILVERADO') && haystackKey.includes('SILVERADO')) return true;
    if (key.startsWith('RAM') && haystackKey.includes('RAM')) return true;
    if (key.startsWith('TRANSIT') && haystackKey.includes('TRANSIT')) return true;
    return false;
  };
  const scoreVehicleCandidate = (cardText, source = {}) => {
    const match = getVehicleMatchArgs(source);
    const haystack = normalizeVehicleText(cardText);
    const yearDelta = vehicleYearDelta(cardText, match.year);
    const yearMatch = !!match.year && yearDelta === 0;
    const makeMatch = vehicleMakeMatches(haystack, match);
    const modelMatch = vehicleModelMatches(haystack, match);
    const trimMatch = !!match.trim && haystack.includes(match.trim);
    const vinMatch = !!match.vin && haystack.includes(match.vin);
    const vinSuffixMatch = !vinMatch && !!match.vinSuffix && haystack.includes(match.vinSuffix);
    const vinEvidence = vehicleVinEvidenceText(cardText);
    const visibleVinBacked = !!vinEvidence;
    const vinBacked = !!(vinMatch || vinSuffixMatch);
    const modelFamilyRelated = vehicleModelFamilyRelated(haystack, match);
    const exactFullVinMatch = !!(match.vin && vinMatch);
    const exactYearMakeVinMatch = !!(yearMatch && makeMatch && vinBacked);
    const yearWindowVinMatch = !!(match.year && yearDelta !== null && Math.abs(yearDelta) <= 2
      && makeMatch && vinSuffixMatch);
    const modelMissingOrUnsafe = !match.model && !(match.modelAliases || []).length && !(match.normalizedModelKeys || []).length;
    const visiblePublicRecordMatch = !!(yearMatch && makeMatch && visibleVinBacked && modelMissingOrUnsafe && !exactFullVinMatch);
    let score = 0;
    if (yearMatch) score += 40;
    if (makeMatch) score += 30;
    if (modelMatch) score += 30;
    if (trimMatch) score += 10;
    if (vinBacked) score += 50;
    if (exactFullVinMatch) score = Math.max(score, 160);
    if (yearWindowVinMatch) score = Math.max(score, 130);
    if (visiblePublicRecordMatch) score = Math.max(score, 120);
    let matchPolicy = '';
    if (exactFullVinMatch) matchPolicy = 'EXACT_FULL_VIN_ACCEPTED';
    else if (yearWindowVinMatch) matchPolicy = 'VIN_SUFFIX_YEAR_WINDOW_ACCEPTED';
    else if (visiblePublicRecordMatch) matchPolicy = 'VIN_VISIBLE_PUBLIC_RECORD_ACCEPTED';
    return {
      score,
      threshold: 90,
      yearMatch,
      yearDelta: yearDelta === null ? '' : String(yearDelta),
      exactFullVinMatch,
      exactYearMakeVinMatch,
      yearWindowVinMatch,
      visiblePublicRecordMatch,
      publicVinEvidence: vinEvidence,
      matchPolicy,
      makeMatch,
      modelMatch,
      modelFamilyRelated,
      trimMatch,
      vinMatch,
      vinSuffixMatch
    };
  };
  const vehicleVinEvidenceText = (text) => {
    const tokens = safe(text).toUpperCase().match(/[A-HJ-NPR-Z0-9*]{8,20}/g) || [];
    return tokens.find((token) => /[A-Z]/.test(token) && /\d/.test(token) && (token.length === 17 || token.includes('*'))) || '';
  };
  const partialVehicleModelTextFromCard = (cardText, match) => {
    const text = normalizeVehicleText(cardText);
    const labels = (match.allowedMakeLabels || []).concat([match.make]).map(normalizeVehicleText).filter(Boolean);
    const year = safe(match.year).trim().replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
    if (!year || !labels.length) return '';
    for (const label of labels) {
      const escapedLabel = label.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
      const regex = new RegExp(`\\b${year}\\b[\\s\\S]{0,120}?\\b${escapedLabel}\\b\\s+([A-Z0-9][A-Z0-9\\s./*-]{0,100})`, 'i');
      const m = text.match(regex);
      if (!m) continue;
      let model = safe(m[1]);
      model = model.replace(/\bVIN\b[\s\S]*$/i, '');
      model = model.replace(/\b[A-HJ-NPR-Z0-9*]{8,20}\b[\s\S]*$/i, '');
      model = model.replace(/\b(?:EDIT|REMOVE|CONFIRMED|ADDED|TO|QUOTE)\b[\s\S]*$/i, '');
      model = model.replace(/\s+/g, ' ').trim();
      if (model) return model;
    }
    return '';
  };
  const pickVehicleCard = (seed) => {
    let fallback = null;
    for (let depth = 0, current = seed; depth < 8 && current; depth++, current = current.parentElement) {
      if (!visible(current)) continue;
      const text = getText(current);
      if (!text || text.length < 20 || text.length > 500) continue;
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
  const findVehicleMatchCandidates = (source = {}) => {
    const seeds = Array.from(document.querySelectorAll('h3,button,a,div,span'))
      .filter(visible);
    const candidates = [];
    const seen = new Set();
    for (const seed of seeds) {
      const card = pickVehicleCard(seed);
      if (!card) continue;
      const cardText = getText(card);
      const key = lower(cardText);
      if (!key || seen.has(key)) continue;
      const details = scoreVehicleCandidate(cardText, source);
      if (details.score < details.threshold) continue;
      seen.add(key);
      candidates.push({ card, cardText, details });
    }
    candidates.sort((a, b) => b.details.score - a.details.score || a.cardText.length - b.cardText.length);
    return candidates;
  };
  const findVehicleMatchCards = (source = {}) => findVehicleMatchCandidates(source).map((candidate) => candidate.card);
  const vehicleCandidatesAreAmbiguous = (candidates = []) => {
    if (candidates.length < 2) return false;
    return (candidates[0].details.score - candidates[1].details.score) <= 10;
  };
  const findCardButtonByText = (card, text) => Array.from((card && card.querySelectorAll('button,a,[role=button]')) || [])
    .find((node) => visible(node) && answerTextMatches(getText(node), text));
  const vehicleTitleCount = (text) => {
    const matches = normalizeVehicleText(text).match(/\b(?:19|20)\d{2}\b\s+[A-Z][A-Z0-9./-]*(?:\s+[A-Z][A-Z0-9./-]*){0,5}/g) || [];
    const distinct = new Set(matches.map((value) => value.replace(/\s+/g, ' ').trim()).filter(Boolean));
    return distinct.size;
  };
  const potentialVehicleCandidateScope = (candidate) => {
    const card = candidate && candidate.card;
    const cardText = getText(card);
    const text = normLower(cardText);
    const confirmButtons = Array.from((card && card.querySelectorAll('button,a,[role=button]')) || [])
      .filter((node) => visible(node) && answerTextMatches(getText(node), 'Confirm'));
    const removeButtons = Array.from((card && card.querySelectorAll('button,a,[role=button]')) || [])
      .filter((node) => visible(node) && answerTextMatches(getText(node), 'Remove'));
    const titleCount = vehicleTitleCount(cardText);
    const details = (candidate && candidate.details) || {};
    const vinBackedPublicRecordAccepted = !!(details.exactFullVinMatch || details.yearWindowVinMatch || details.visiblePublicRecordMatch);
    if (!safe(details.yearMatch) && !vinBackedPublicRecordAccepted)
      return { ok: false, candidateScope: 'rejected', rejectedReason: 'year-mismatch', confirmButtonCount: confirmButtons.length, vehicleTitleCount: titleCount };
    if (!safe(details.makeMatch) && !vinBackedPublicRecordAccepted)
      return { ok: false, candidateScope: 'rejected', rejectedReason: 'make-mismatch', confirmButtonCount: confirmButtons.length, vehicleTitleCount: titleCount };
    if (!safe(details.modelMatch) && !safe(details.exactYearMakeVinMatch) && !vinBackedPublicRecordAccepted)
      return { ok: false, candidateScope: 'rejected', rejectedReason: 'model-mismatch', confirmButtonCount: confirmButtons.length, vehicleTitleCount: titleCount };
    if (text.includes('confirmed vehicles') && text.includes('potential vehicles'))
      return { ok: false, candidateScope: 'broad-section', rejectedReason: 'broad-container', confirmButtonCount: confirmButtons.length, vehicleTitleCount: titleCount };
    if (confirmButtons.length !== 1)
      return { ok: false, candidateScope: confirmButtons.length > 1 ? 'broad-section' : 'rejected', rejectedReason: confirmButtons.length > 1 ? 'multiple-confirm-buttons' : 'confirm-button-missing', confirmButtonCount: confirmButtons.length, vehicleTitleCount: titleCount };
    if (titleCount > 1)
      return { ok: false, candidateScope: 'broad-section', rejectedReason: 'multiple-vehicle-titles', confirmButtonCount: confirmButtons.length, vehicleTitleCount: titleCount };
    if (text.includes('add car or truck'))
      return { ok: false, candidateScope: 'broad-section', rejectedReason: 'add-vehicle-container', confirmButtonCount: confirmButtons.length, vehicleTitleCount: titleCount };
    if (!text.includes('potential vehicles') && removeButtons.length < 1)
      return { ok: false, candidateScope: 'rejected', rejectedReason: 'not-potential-card', confirmButtonCount: confirmButtons.length, vehicleTitleCount: titleCount };
    return { ok: true, candidateScope: 'single-card', rejectedReason: '', confirmButtonCount: confirmButtons.length, vehicleTitleCount: titleCount, confirmBtn: confirmButtons[0] };
  };
  const parseExpectedVehicles = (source = {}) => {
    const raw = Array.isArray(source.expectedVehicles) ? source.expectedVehicles : [];
    const fromString = safe(source.expectedVehiclesText)
      .split('||')
      .map((item) => item.trim())
      .filter(Boolean)
      .map((item) => {
        const parts = item.split('|');
        return { year: parts[0] || '', make: parts[1] || '', model: parts[2] || '', vin: parts[3] || '' };
      });
    return raw.concat(fromString)
      .map((vehicle) => ({
        year: safe(vehicle && vehicle.year).trim(),
        make: safe(vehicle && vehicle.make).trim(),
        model: safe(vehicle && vehicle.model).trim(),
        vin: safe(vehicle && vehicle.vin).trim(),
        vinSuffix: safe(vehicle && vehicle.vinSuffix).trim(),
        allowedMakeLabels: vehicle && (vehicle.allowedMakeLabels || vehicle.makeAliases || vehicle.advisorMakeLabels) || '',
        strictModelMatch: vehicle && vehicle.strictModelMatch
      }))
      .filter((vehicle) => vehicle.year || vehicle.make || vehicle.model || vehicle.vin || vehicle.vinSuffix);
  };
  const vehicleLabel = (vehicle) => [vehicle.year, vehicle.make, vehicle.model].filter(Boolean).join(' ').trim();
  const confirmedVehicleCandidates = () => {
    const nodes = Array.from(document.querySelectorAll('div,section,article,li,tr,fieldset'))
      .filter(visible);
    const seen = new Set();
    const candidates = [];
    for (const node of nodes) {
      const text = getText(node);
      const lowerText = normLower(text);
      const classText = normLower(safe(node.className));
      if (!lowerText.includes('confirmed')) continue;
      if (!/\b(?:19|20)\d{2}\b/.test(text)) continue;
      const titleCount = vehicleTitleCount(text);
      const hasAction = Array.from(node.querySelectorAll('button,a,[role=button]'))
        .some((action) => visible(action) && (answerTextMatches(getText(action), 'Edit') || answerTextMatches(getText(action), 'Remove')));
      const hasCardClass = /\b(?:vehicle-card|confirmed-vehicle)\b/.test(classText);
      const hasActionText = /\bedit\b/.test(lowerText) && /\bremove\b/.test(lowerText);
      if (lowerText.includes('confirmed vehicles') && !hasCardClass)
        continue;
      if (lowerText.includes('potential vehicles') || titleCount > 1 || (!hasCardClass && !hasAction && !hasActionText))
        continue;
      const key = lower(text);
      if (!key || seen.has(key)) continue;
      seen.add(key);
      candidates.push({ card: node, cardText: text });
    }
    const narrowed = [];
    for (const candidate of candidates.sort((a, b) => a.cardText.length - b.cardText.length)) {
      const candidateKey = lower(candidate.cardText);
      if (narrowed.some((existing) => candidateKey.includes(lower(existing.cardText))))
        continue;
      narrowed.push(candidate);
    }
    return narrowed;
  };
  const gatherConfirmedVehiclesStatus = (source = {}) => {
    const expectedAll = parseExpectedVehicles(source);
    const expected = expectedAll.filter((vehicle) => safe(vehicle.year).trim() !== '');
    const unresolved = expectedAll.filter((vehicle) => safe(vehicle.year).trim() === '');
    const cards = confirmedVehicleCandidates();
    const matchedLabels = [];
    const missingLabels = [];
    const matchedCardIndexes = new Set();
    expected.forEach((vehicle) => {
      const matchedIndex = cards.findIndex((candidate, index) => !matchedCardIndexes.has(index) && scoreVehicleCandidate(candidate.cardText, vehicle).score >= 90);
      if (matchedIndex >= 0) {
        matchedCardIndexes.add(matchedIndex);
        matchedLabels.push(vehicleLabel(vehicle));
      } else {
        missingLabels.push(vehicleLabel(vehicle));
      }
    });
    const unexpected = cards
      .filter((_, index) => !matchedCardIndexes.has(index))
      .map((candidate) => compact(candidate.cardText, 120));
    const result = unexpected.length ? 'UNEXPECTED' : (cards.length ? 'OK' : 'NONE');
    return linesOut({
      result,
      confirmedCount: String(cards.length),
      expectedCount: String(expected.length),
      matchedExpectedCount: String(matchedLabels.length),
      unexpectedCount: String(unexpected.length),
      unexpectedVehicles: unexpected.join(' || '),
      matchedVehicles: matchedLabels.join(' || '),
      missingExpectedVehicles: missingLabels.join(' || '),
      unresolvedLeadVehicles: unresolved.map(vehicleLabel).join(' || '),
      method: 'confirmed-vehicle-cards'
    });
  };
  const ascProductRouteId = () => {
    const match = pageUrl().match(/\/apps\/ASCPRODUCT\/([^/?#]+)/i);
    return match ? safe(match[1]) : '';
  };
  const isAscProductRoute = () => ascProductRouteId() !== '';
  const ascDriversVehiclesTextEvidence = () => {
    const text = bodyText();
    const normalized = normLower(text);
    const evidence = [];
    if (normalized.includes('drivers and vehicles')) evidence.push('text:Drivers and vehicles');
    if (normalized.includes("let's get some more details") || normalized.includes('lets get some more details')) evidence.push('text:more-details');
    if (normalized.includes('add drivers')) evidence.push('text:Add drivers');
    if (normalized.includes('add vehicles')) evidence.push('text:Add vehicles');
    if (normalized.includes('save and continue')) evidence.push('text:Save and Continue');
    if (normalized.includes('consumer reports')) evidence.push('text:Consumer Reports');
    if (normalized.includes('coverages')) evidence.push('text:Coverages');
    return evidence;
  };
  const findAscPageSaveContinueButton = () => document.getElementById('profile-summary-submitBtn')
    || Array.from(document.querySelectorAll('button,input[type=button],input[type=submit],[role=button]'))
      .filter(visible)
      .find((node) => answerTextMatches(getText(node) || node.value, 'Save and Continue')) || null;
  const findAscInlineParticipantSaveButton = () => {
    const exact = document.getElementById('PARTICIPANT_SAVE-btn');
    if (exact && visible(exact)) return exact;
    return Array.from(document.querySelectorAll('button,input[type=button],input[type=submit],[role=button]'))
      .filter(visible)
      .find((node) => {
        const text = normLower(getText(node) || node.value || node.getAttribute('aria-label') || '');
        if (text !== 'save') return false;
        const context = normLower(getText(node.closest('section,div,form,[role="dialog"]') || node.parentElement) || bodyText());
        return context.includes("let's get some more details") || context.includes('lets get some more details') || context.includes('participant');
      }) || null;
  };
  const findAscSaveButton = findAscPageSaveContinueButton;
  const findAscSpouseSelect = () => document.getElementById('maritalStatusWithSpouse_spouseName')
    || document.querySelector('select[name="agreement.agreementParticipant.party.spouse.id"]')
    || Array.from(document.querySelectorAll('select')).find((select) => /spouse/i.test(`${safe(select.id)} ${safe(select.name)}`)) || null;
  const findAscMaritalControls = () => {
    const radios = Array.from(document.querySelectorAll('input[type=radio]'))
      .filter((radio) => /marital/i.test(`${safe(radio.id)} ${safe(radio.name)}`));
    const selects = Array.from(document.querySelectorAll('select'))
      .filter((select) => /marital/i.test(`${safe(select.id)} ${safe(select.name)}`));
    return { radios, selects };
  };
  const maritalCandidateText = (node) => normUpper(`${safe(node && node.id)} ${safe(node && node.name)} ${safe(node && node.value)} ${readInputLabel(node)}`);
  const maritalWantedMatches = (text, wanted) => {
    const normalized = normUpper(wanted);
    if (normalized === 'SINGLE')
      return /\bSINGLE\b|\bUNMARRIED\b|0002/.test(text);
    if (normalized === 'MARRIED')
      return /\bMARRIED\b|0001/.test(text);
    return normalized && text.includes(normalized);
  };
  const readAscMaritalStatus = () => {
    const controls = findAscMaritalControls();
    for (const radio of controls.radios) {
      if (!radio.checked) continue;
      const text = maritalCandidateText(radio);
      if (maritalWantedMatches(text, 'Single')) return { value: safe(radio.value), text: 'Single', source: 'radio' };
      if (maritalWantedMatches(text, 'Married')) return { value: safe(radio.value), text: 'Married', source: 'radio' };
      return { value: safe(radio.value), text: readInputLabel(radio), source: 'radio' };
    }
    for (const select of controls.selects) {
      const state = readSelectState(select);
      if (state.value || state.text) return { value: state.value, text: state.text, source: 'select' };
    }
    return { value: '', text: '', source: controls.radios.length || controls.selects.length ? 'present' : '' };
  };
  const setAscMaritalStatus = (wanted) => {
    const controls = findAscMaritalControls();
    const wantedText = normUpper(wanted);
    const current = readAscMaritalStatus();
    if (maritalWantedMatches(normUpper(`${current.value} ${current.text}`), wantedText))
      return { ok: true, method: 'already-selected', state: readAscMaritalStatus() };
    for (const radio of controls.radios) {
      if (!maritalWantedMatches(maritalCandidateText(radio), wantedText)) continue;
      const target = getInputClickTarget(radio) || radio;
      const clicked = clickCenterEl(target);
      if (clicked) {
        controls.radios.filter((candidate) => safe(candidate.name) === safe(radio.name)).forEach((candidate) => {
          candidate.checked = candidate === radio;
        });
        radio.dispatchEvent(new Event('input', { bubbles: true }));
        radio.dispatchEvent(new Event('change', { bubbles: true }));
      }
      const next = readAscMaritalStatus();
      return { ok: clicked && maritalWantedMatches(normUpper(`${next.value} ${next.text}`), wantedText), method: clicked ? 'radio-click' : 'radio-click-failed', state: next };
    }
    for (const select of controls.selects) {
      const option = Array.from(select.options || []).find((opt) => maritalWantedMatches(normUpper(`${safe(opt.value)} ${safe(opt.text || opt.innerText)}`), wantedText));
      if (!option) continue;
      const applied = setSelectValue(select, option.value, false);
      const next = readAscMaritalStatus();
      return { ok: applied && maritalWantedMatches(normUpper(`${next.value} ${next.text}`), wantedText), method: applied ? 'select' : 'select-failed', state: next };
    }
    return { ok: false, method: controls.radios.length || controls.selects.length ? 'no-option-match' : 'marital-control-missing', state: current };
  };
  const radioGroupHasControl = (nameRe) => Array.from(document.querySelectorAll('input[type=radio],input[type=checkbox],input'))
    .filter(visible)
    .filter((el) => nameRe.test(`${safe(el.name)} ${safe(el.id)}`));
  const radioGroupAlreadySelected = (controls) => controls.some((el) => el.checked || isSelectedNode(el));
  const ascParticipantDetailStatus = (source = {}) => {
    const evidence = ascDriversVehiclesTextEvidence();
    const missing = [];
    if (isAscProductRoute()) evidence.push('url:/apps/ASCPRODUCT/');
    else missing.push('url:/apps/ASCPRODUCT/');
    const text = bodyText();
    const panelPresent = /let'?s get some more details|participant|driver details|more details/i.test(text) || !!document.getElementById('PARTICIPANT_SAVE-btn');
    const saveButton = findAscInlineParticipantSaveButton();
    const panelRoot = findAscInlineParticipantPanelRoot() || (panelPresent ? document : null);
    const panelReadiness = readAscNonDriverParticipantPanelReadiness(panelRoot);
    const movingViolationsState = panelReadiness.moving;
    const pageSaveButton = findAscPageSaveContinueButton();
    if (saveButton) evidence.push(`inline-button:${safe(saveButton.id || 'save')}`);
    else if (panelPresent) missing.push('button:inline-save');
    if (pageSaveButton) evidence.push(`page-button:${safe(pageSaveButton.id || 'save-and-continue')}`);
    const spouseSelect = findAscSpouseSelect();
    const spouseState = spouseSelect ? readSelectState(spouseSelect) : { value: '', text: '' };
    const spouseOptions = spouseSelect ? Array.from(spouseSelect.options || []).map((opt) => compact(`${safe(opt.value)}:${safe(opt.text || opt.innerText)}`, 90)).join('||') : '';
    const marital = readAscMaritalStatus();
    const maritalControls = findAscMaritalControls();
    const ownershipEl = document.getElementById('propertyOwnershipEntCd_option') || document.querySelector('select[id*="propertyOwnership"],select[name*="propertyOwnership"]');
    const ownership = readSelectState(ownershipEl);
    const ageFirstLicensed = document.getElementById('ageFirstLicensed_ageFirstLicensed') || document.querySelector('input[id*="AgeFirstLicensed"],input[name*="AgeFirstLicensed"],input[id*="ageFirstLicensed"],input[name*="ageFirstLicensed"]');
    const dob = document.querySelector('input[id*="Birth"],input[name*="Birth"],input[id*="DOB"],input[name*="DOB"]');
    const email = document.getElementById('emailAddress.emailAddress') || document.querySelector('input[type=email],input[id*="Email"],input[name*="Email"],input[id*="email"],input[name*="email"]');
    const phone = document.querySelector('input[type=tel],input[id*="Phone"],input[name*="Phone"],input[id*="phone"],input[name*="phone"]');
    const licenseNumber = document.querySelector('input[id*="LicenseNumber"],input[name*="LicenseNumber"],input[id*="licenseNumber"],input[name*="licenseNumber"]');
    const licenseState = document.querySelector('select[id*="LicenseState"],select[name*="LicenseState"],select[id*="licenseState"],select[name*="licenseState"]');
    const genderControls = radioGroupHasControl(/gender/i);
    const violationControls = radioGroupHasControl(/violation/i);
    const defensiveControls = radioGroupHasControl(/defensive/i);
    const missingRequired = [];
    if (panelPresent && ageFirstLicensed && !safe(ageFirstLicensed.value).trim()) missingRequired.push('ageFirstLicensed');
    if (panelPresent && ownershipEl && !safe(ownership.value || ownership.text).trim()) missingRequired.push('propertyOwnership');
    if (panelPresent && genderControls.length && !radioGroupAlreadySelected(genderControls)) missingRequired.push('gender');
    if (panelPresent && (maritalControls.radios.length || maritalControls.selects.length) && !safe(marital.value || marital.text).trim()) missingRequired.push('marital');
    if (panelPresent && movingViolationsState.requiredMissing === '1') missingRequired.push('movingViolations');
    if (panelPresent && saveButton && isDisabledLike(saveButton) && !missingRequired.length) missingRequired.push('saveDisabledUnknownRequired');
    const optionalMissing = [];
    if (movingViolationsState.questionPresent !== '1' && !violationControls.length) optionalMissing.push('movingViolations');
    if (!defensiveControls.length) optionalMissing.push('defensiveDriving');
    const driverRows = collectAscDriverRows();
    const primary = driverRows[0] || {};
    let result = 'NOT_FOUND';
    if (isAscProductRoute() && (panelPresent || evidence.length >= 2 || saveButton || driverRows.length)) result = 'FOUND';
    const saveEnabled = !!(saveButton && !isDisabledLike(saveButton));
    const pageSaveEnabled = !!(pageSaveButton && !isDisabledLike(pageSaveButton));
    const blockerCode = panelPresent && saveEnabled && movingViolationsState.requiredMissing === '1'
      ? 'ASC_PARTICIPANT_MOVING_VIOLATIONS_REQUIRED'
      : (panelPresent && saveEnabled
      ? 'ASC_INLINE_PARTICIPANT_READY_TO_SAVE'
      : (panelPresent && saveButton && isDisabledLike(saveButton) ? 'ASC_INLINE_PARTICIPANT_SAVE_DISABLED' : ''));
    if (result === 'FOUND' && blockerCode === 'ASC_INLINE_PARTICIPANT_SAVE_DISABLED' && missingRequired.length) result = 'ASC_INLINE_PARTICIPANT_SAVE_DISABLED';
    return {
      result,
      ascProductRouteId: ascProductRouteId(),
      panelPresent: panelPresent ? '1' : '0',
      primaryName: compact(primary.name || '', 0),
      primaryAge: primary.age || '',
      participantNameMasked: primary.name ? '[REDACTED]' : '',
      savePresent: saveButton ? '1' : '0',
      saveEnabled: saveEnabled ? '1' : '0',
      saveButtonPresent: saveButton ? '1' : '0',
      saveButtonEnabled: saveEnabled ? '1' : '0',
      saveButtonId: safe(saveButton && saveButton.id),
      inlineParticipantSavePresent: saveButton ? '1' : '0',
      inlineParticipantSaveEnabled: saveEnabled ? '1' : '0',
      pageSaveContinuePresent: pageSaveButton ? '1' : '0',
      pageSaveContinueEnabled: pageSaveEnabled ? '1' : '0',
      pageSaveContinueButtonId: safe(pageSaveButton && pageSaveButton.id),
      blockerCode,
      nextAction: (blockerCode === 'ASC_INLINE_PARTICIPANT_READY_TO_SAVE' || blockerCode === 'ASC_PARTICIPANT_MOVING_VIOLATIONS_REQUIRED') ? 'save_inline_participant_panel' : '',
      genderQuestionPresent: genderControls.length ? '1' : '0',
      genderControlPresent: genderControls.length ? '1' : '0',
      genderAlreadySelected: radioGroupAlreadySelected(genderControls) ? '1' : '0',
      maritalQuestionPresent: (maritalControls.radios.length || maritalControls.selects.length) ? '1' : '0',
      maritalControlPresent: (maritalControls.radios.length || maritalControls.selects.length) ? '1' : '0',
      maritalAlreadySelected: safe(marital.value || marital.text).trim() ? '1' : '0',
      maritalStatusPresent: (maritalControls.radios.length || maritalControls.selects.length) ? '1' : '0',
      maritalStatusSelected: compact(marital.text || '', 80),
      maritalStatusValue: compact(marital.value || '', 80),
      spouseDropdownPresent: spouseSelect ? '1' : '0',
      spouseDropdownValue: compact(spouseState.value || '', 80),
      spouseDropdownText: compact(spouseState.text || '', 120),
      spouseOptionCount: spouseSelect ? String((spouseSelect.options || []).length) : '0',
      spouseOptions: compact(spouseOptions, 240),
      ownershipQuestionPresent: ownershipEl ? '1' : '0',
      ownershipSelected: safe(ownership.value || ownership.text).trim() ? '1' : '0',
      propertyOwnershipValue: compact(ownership.value || '', 80),
      propertyOwnershipText: compact(ownership.text || '', 120),
      dobPresent: dob ? '1' : '0',
      ageFirstLicensedPresent: ageFirstLicensed ? '1' : '0',
      ageFirstLicensedFilled: ageFirstLicensed && safe(ageFirstLicensed.value).trim() ? '1' : '0',
      ageFirstLicensedValue: compact(ageFirstLicensed ? ageFirstLicensed.value : '', 80),
      movingViolationsQuestionPresent: movingViolationsState.questionPresent,
      movingViolationsControlPresent: (violationControls.length || movingViolationsState.controlPresent === '1') ? '1' : '0',
      movingViolationsAlreadySelected: movingViolationsState.selected === '1' || radioGroupAlreadySelected(violationControls) ? '1' : '0',
      movingViolationsSelectedValue: movingViolationsState.selectedValue,
      movingViolationsSelectionSource: movingViolationsState.selectedSource,
      movingViolationsRequiredMissing: movingViolationsState.requiredMissing,
      movingViolationsDefaultApplied: '0',
      movingViolationsWarningPresent: movingViolationsState.warningPresent,
      movingViolationsAmbiguous: movingViolationsState.ambiguous,
      requiredMissingWarningPresent: panelReadiness.requiredWarningPresent,
      panelReadyToSave: panelReadiness.readyToSave,
      defensiveDrivingQuestionPresent: defensiveControls.length ? '1' : '0',
      defensiveDrivingControlPresent: defensiveControls.length ? '1' : '0',
      defensiveDrivingAlreadySelected: radioGroupAlreadySelected(defensiveControls) ? '1' : '0',
      licenseNumberPresent: licenseNumber ? '1' : '0',
      licenseStatePresent: licenseState ? '1' : '0',
      emailPresent: email ? '1' : '0',
      phonePresent: phone ? '1' : '0',
      missingRequiredControls: missingRequired.join('|'),
      optionalMissingControls: optionalMissing.join('|'),
      evidence: compact(evidence.join('|'), 240),
      missing: compact(missing.concat(missingRequired).join('|'), 240)
    };
  };
  const normalizePersonName = (value) => normUpper(value)
    .replace(/\bAGE\s+\d+\b/g, ' ')
    .replace(/\b(ADD|REMOVE|EDIT|ADDED|QUOTE|TO|DO|YOU|WANT|DRIVER|SPOUSE)\b/g, ' ')
    .replace(/[^A-Z0-9 ]/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
  const truthyArg = (value) => /^(1|true|yes|y)$/i.test(safe(value).trim());
  const personNameTokens = (value) => normalizePersonName(value).split(/\s+/).filter(Boolean);
  const personNameMatches = (actual, expected) => {
    const a = normalizePersonName(actual);
    const e = normalizePersonName(expected);
    return !!a && !!e && (a === e || a.includes(e) || e.includes(a));
  };
  const personNameStrongMatches = (actual, expected) => {
    const a = normalizePersonName(actual);
    const e = normalizePersonName(expected);
    if (!a || !e) return false;
    if (a === e) return true;
    const aTokens = personNameTokens(a);
    const eTokens = personNameTokens(e);
    if (aTokens.length < 2 || eTokens.length < 2) return false;
    if (a.includes(e) || e.includes(a)) return true;
    return aTokens[0] === eTokens[0] && aTokens[aTokens.length - 1] === eTokens[eTokens.length - 1];
  };
  const parseAgeFromText = (text) => {
    const match = safe(text).match(/\bAge\s*(\d{1,3})\b/i);
    return match ? match[1] : '';
  };
  const parseAgeNearPersonName = (name) => {
    const value = safe(name).trim();
    if (!value) return '';
    const escaped = value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&').replace(/\s+/g, '\\s+');
    const match = bodyText().match(new RegExp(`${escaped}\\s+Age\\s*(\\d{1,3})`, 'i'));
    return match ? match[1] : '';
  };
  const inferDriverName = (text, slug = '') => {
    const byAge = safe(text).match(/([A-Z][A-Za-z0-9 .'-]{2,80}?)\s+Age\s*\d{1,3}/);
    if (byAge) return byAge[1].trim();
    const cleaned = normalizePersonName(text);
    if (cleaned) return cleaned.split(/\s+/).slice(0, 5).join(' ');
    return safe(slug).replace(/-/g, ' ').replace(/\b\w/g, (ch) => ch.toUpperCase());
  };
  const pickAscRowForAction = (button) => {
    let fallback = button && button.parentElement;
    for (let depth = 0, current = button; depth < 7 && current; depth += 1, current = current.parentElement) {
      if (!visible(current)) continue;
      const text = getText(current);
      if (!text || text.length > 700) continue;
      if (!fallback && text.length >= 5) fallback = current;
      const idClass = normLower(`${safe(current.id)} ${safe(current.className)}`);
      if (current !== button && /(row|card|driver|participant|vehicle|asset|profile|summary|item)/.test(idClass))
        return current;
      const actionCount = Array.from(current.querySelectorAll('button,a,[role=button]')).filter(visible).length;
      if (current !== button && actionCount <= 3 && text.length >= 5)
        fallback = current;
    }
    return fallback;
  };
  const collectAscDriverRows = () => {
    const buttons = Array.from(document.querySelectorAll('button[id],a[id],[role=button][id]'))
      .filter(visible)
      .filter((btn) => /-(addToQuote|add|remove|edit)$/i.test(safe(btn.id)) && !/\bvehicle|asset|car|truck/i.test(`${safe(btn.id)} ${getText(btn)}`));
    const seenRows = new Set();
    const rows = [];
    for (const btn of buttons) {
      const row = pickAscRowForAction(btn);
      if (!row || !visible(row) || seenRows.has(row)) continue;
      const text = getText(row);
      if (!text || /\b(?:19|20)\d{2}\b/.test(text) || normLower(text).includes('vin:')) continue;
      seenRows.add(row);
      const rowButtons = Array.from(row.querySelectorAll('button[id],a[id],[role=button][id]')).filter(visible);
      const addButton = rowButtons.find((node) => /-(addToQuote|add)$/i.test(safe(node.id))) || null;
      const removeButton = rowButtons.find((node) => /-remove$/i.test(safe(node.id))) || null;
      const editButton = rowButtons.find((node) => /-edit$/i.test(safe(node.id))) || null;
      const slugSource = safe((addButton || removeButton || editButton || {}).id).replace(/-(addToQuote|add|remove|edit)$/i, '');
      const lowerText = normLower(text);
      const nonDriverResolved = /\b(?:non[-\s]?driver|removed|not\s+added|excluded)\b/.test(lowerText);
      rows.push({
        row,
        text,
        name: inferDriverName(text, slugSource),
        age: parseAgeFromText(text),
        slug: slugSource,
        addButton,
        removeButton,
        editButton,
        added: (!!editButton && !addButton) || lowerText.includes('added to quote') || lowerText.includes('added driver'),
        nonDriverResolved,
        unresolved: !nonDriverResolved && (!!addButton || !!removeButton)
      });
    }
    return rows.sort((a, b) => a.text.length - b.text.length);
  };
  const ascDriverRowsStatus = () => {
    const rows = collectAscDriverRows();
    const unresolved = rows.filter((row) => row.unresolved && !row.added);
    const added = rows.filter((row) => row.added);
    const removed = rows.filter((row) => row.nonDriverResolved || normLower(row.text).includes('removed'));
    const saveButton = findAscSaveButton();
    const evidence = [];
    if (rows.length) evidence.push('driver-rows');
    if (saveButton) evidence.push('save-button');
    if (removed.length) evidence.push('ASC_DRIVER_ROW_NON_DRIVER_RESOLVED');
    return {
      result: rows.length ? 'FOUND' : 'NONE',
      driverCount: String(rows.length),
      unresolvedDriverCount: String(unresolved.length),
      addedDriverCount: String(added.length),
      removedDriverCount: String(removed.length),
      driverSummaries: compact(rows.map((row) => `${row.name}|age=${row.age}|added=${row.added ? 1 : 0}|nonDriver=${row.nonDriverResolved ? 1 : 0}|unresolved=${row.unresolved ? 1 : 0}|add=${row.addButton ? 1 : 0}|remove=${row.removeButton ? 1 : 0}|addButtonId=${safe(row.addButton && row.addButton.id)}|removeButtonId=${safe(row.removeButton && row.removeButton.id)}`).join('||'), 620),
      saveButtonEnabled: saveButton && !isDisabledLike(saveButton) ? '1' : '0',
      evidence: compact(evidence.join('|'), 240),
      missing: rows.length ? '' : 'driver-rows'
    };
  };
  const parsePersonListArg = (value) => {
    if (Array.isArray(value)) return value.map((item) => safe(item).trim()).filter(Boolean);
    return safe(value).split(/[|,;]/).map((item) => item.trim()).filter(Boolean);
  };
  const ascReconcileDriverRows = (source = {}) => {
    const rows = collectAscDriverRows();
    if (!rows.length) return lineResult({ result: 'OK', method: 'no-driver-rows', primaryAction: 'none', spouseAction: 'none', removedDrivers: '', unresolvedDrivers: '', addClickedCount: '0', removeClickedCount: '0', failedFields: '', evidence: 'no-driver-rows' });
    const leadMarital = normUpper(source.leadMaritalStatus);
    const selectedSpouseName = safe(source.selectedSpouseName);
    const expectedNames = parsePersonListArg(source.expectedDriverNames);
    if (safe(source.primaryName)) expectedNames.unshift(safe(source.primaryName));
    if (selectedSpouseName) expectedNames.push(selectedSpouseName);
    const expectedUnique = [];
    expectedNames.forEach((name) => {
      if (name && !expectedUnique.some((existing) => personNameMatches(existing, name))) expectedUnique.push(name);
    });
    const isExpected = (row) => expectedUnique.some((name) => personNameMatches(row.name || row.text, name));
    let primaryAction = 'none';
    let spouseAction = 'none';
    let removedDrivers = [];
    let unresolvedDrivers = [];
    let addClickedCount = 0;
    let removeClickedCount = 0;
    for (const row of rows) {
      if (!isExpected(row)) continue;
      if (row.added) continue;
      if (row.nonDriverResolved) {
        unresolvedDrivers.push(row.name);
        continue;
      }
      if (row.addButton) {
        const clicked = clickCenterEl(row.addButton);
        addClickedCount = clicked ? 1 : 0;
        primaryAction = personNameMatches(row.name, source.primaryName) ? (clicked ? 'add-clicked' : 'add-click-failed') : 'none';
        spouseAction = selectedSpouseName && personNameMatches(row.name, selectedSpouseName) ? (clicked ? 'add-clicked' : 'add-click-failed') : 'none';
        return lineResult({
          result: clicked ? 'PARTIAL' : 'FAILED',
          method: 'expected-driver-add',
          primaryAction,
          spouseAction,
          removedDrivers: '',
          unresolvedDrivers: compact(row.name, 120),
          addClickedCount: String(addClickedCount),
          removeClickedCount: '0',
          failedFields: clicked ? '' : 'driverAdd',
          evidence: compact(row.text, 180)
        });
      }
      unresolvedDrivers.push(row.name);
    }
    for (const row of rows) {
      if (isExpected(row)) continue;
      if (row.nonDriverResolved) continue;
      if (row.removeButton) {
        const clicked = clickCenterEl(row.removeButton);
        removeClickedCount = clicked ? 1 : 0;
        if (clicked) removedDrivers.push(row.name);
        return lineResult({
          result: clicked ? 'PARTIAL' : 'FAILED',
          method: 'unexpected-driver-remove',
          primaryAction,
          spouseAction,
          removedDrivers: removedDrivers.join('||'),
          unresolvedDrivers: compact(row.name, 120),
          addClickedCount: '0',
          removeClickedCount: String(removeClickedCount),
          failedFields: clicked ? '' : 'driverRemove',
          evidence: compact(row.text, 180)
        });
      }
      if (!row.added && row.addButton)
        unresolvedDrivers.push(row.name);
      if (row.added)
        unresolvedDrivers.push(row.name);
    }
    const result = unresolvedDrivers.length ? 'FAILED' : 'OK';
    return lineResult({
      result,
      method: 'driver-row-reconciliation',
      primaryAction,
      spouseAction,
      removedDrivers: removedDrivers.join('||'),
      unresolvedDrivers: unresolvedDrivers.join('||'),
      addClickedCount: '0',
      removeClickedCount: '0',
      failedFields: unresolvedDrivers.length ? 'drivers' : '',
      evidence: compact(rows.map((row) => row.name).join('||'), 240)
    });
  };
  const nonPlaceholderOption = (opt) => {
    const text = safe(opt && (opt.text || opt.innerText));
    const value = safe(opt && opt.value);
    return !!opt
      && !opt.disabled
      && !!value
      && value !== 'NewDriver'
      && !/select one|choose|add another person/i.test(text);
  };
  const spouseDriverQuestionText = 'Will your spouse be a driver on your policy';
  const findAscSpouseDriverYesRadio = () => {
    const radios = Array.from(document.querySelectorAll('input[type=radio]'));
    return radios.find((radio) => {
      const context = `${safe(radio.id)} ${safe(radio.name)} ${safe(radio.value)} ${readInputLabel(radio)} ${getText(radio.closest('div,fieldset,section') || radio.parentElement)}`;
      const label = readInputLabel(radio);
      const value = normUpper(radio.value);
      const yesAnswer = answerTextMatches(label, 'Yes') || answerTextMatches(safe(radio.value), 'Yes') || value === 'TRUE' || value === '1';
      return /spouse/i.test(context) && /driver/i.test(context) && yesAnswer;
    }) || null;
  };
  const setAscSpouseDriverYes = () => {
    const before = readSemanticAnswerState(spouseDriverQuestionText);
    const radio = findAscSpouseDriverYesRadio();
    if (!radio && !before.source)
      return { present: '0', selected: 'SKIP', method: 'question-not-shown' };
    if ((radio && radio.checked) || (before.selected && before.value === 'YES'))
      return { present: '1', selected: '1', method: 'already-selected' };
    let clicked = false;
    if (radio) {
      const target = getInputClickTarget(radio) || radio;
      clicked = clickCenterEl(target);
      if (clicked) {
        Array.from(document.querySelectorAll('input[type=radio]'))
          .filter((candidate) => safe(candidate.name) === safe(radio.name))
          .forEach((candidate) => { candidate.checked = candidate === radio; });
        radio.dispatchEvent(new Event('input', { bubbles: true }));
        radio.dispatchEvent(new Event('change', { bubbles: true }));
      }
    } else {
      const target = findSemanticAnswerTarget(spouseDriverQuestionText, 'Yes');
      clicked = !!target && clickCenterEl(target);
    }
    const after = readSemanticAnswerState(spouseDriverQuestionText);
    const verified = (radio && radio.checked) || (after.selected && after.value === 'YES');
    return { present: '1', selected: verified ? '1' : '0', method: clicked ? 'selected-yes' : 'yes-target-missing' };
  };
  const ascResolveParticipantMaritalAndSpouse = (source = {}) => {
    if (!isAscProductRoute()) {
      return lineResult({ result: 'ERROR', method: 'wrong-page', selectedMaritalStatus: '', selectedSpouseText: '', selectedSpouseValue: '', selectedAgeDiff: '', candidateCount: '0', spouseCandidateCount: '0', spouseCandidateWithinWindowCount: '0', spouseOverrideApplied: '0', spouseOverrideReason: '', spouseCandidateSelectedText: '', spouseCandidateSelectedAge: '', spouseDriverQuestionPresent: '0', spouseDriverYesSelected: '0', candidates: '', rejectedCandidates: '', spouseSelectionMethod: '', failedFields: 'ascProductRoute', evidence: '' });
    }
    const leadMarital = normUpper(source.leadMaritalStatus);
    const leadSpouseName = safe(source.selectedSpouseName || source.leadSpouseName);
    const maxAgeDiff = Number(source.maxSpouseAgeDifference || 14);
    const overrideEnabled = truthyArg(source.ascSpouseOverrideSingleEnabled);
    const leadSingleOrUnknown = leadMarital === 'SINGLE' || leadMarital === '';
    const forceMarriedSpouseSelection = truthyArg(source.forceMarriedSpouseSelection) || !!leadSpouseName;
    const driverRows = collectAscDriverRows();
    const primaryRow = driverRows.find((row) => personNameStrongMatches(row.name, source.primaryName)) || driverRows.find((row) => personNameMatches(row.name, source.primaryName));
    const primaryAge = Number(source.primaryAge || (primaryRow && primaryRow.age) || (driverRows[0] && driverRows[0].age) || 0);
    const candidateRows = driverRows.filter((row) => {
      if (!row || !row.name) return false;
      if (primaryRow && row === primaryRow) return false;
      if (source.primaryName && personNameStrongMatches(row.name, source.primaryName)) return false;
      return true;
    });
    const rowCandidates = candidateRows.map((row) => {
      const age = Number(row.age || 0);
      return {
        row,
        text: row.name,
        age,
        ageDiff: primaryAge && age ? Math.abs(primaryAge - age) : 999
      };
    });
    const inWindowRows = rowCandidates.filter((candidate) => primaryAge && candidate.age && candidate.ageDiff <= maxAgeDiff);
    const candidateSummary = compact(rowCandidates.map((c) => `${c.text}:age=${c.age || ''}:ageDiff=${c.ageDiff === 999 ? '' : c.ageDiff}`).join('||'), 240);
    if (!forceMarriedSpouseSelection && overrideEnabled && leadSingleOrUnknown && !inWindowRows.length) {
      const single = setAscMaritalStatus('Single');
      const spouseSelect = findAscSpouseSelect();
      const spouseState = spouseSelect ? readSelectState(spouseSelect) : { value: '', text: '' };
      return lineResult({
        result: single.method === 'already-selected' ? 'SINGLE_CONFIRMED' : (single.ok ? 'SINGLE_SET' : 'FAILED'),
        method: single.method,
        selectedMaritalStatus: single.state.text || 'Single',
        selectedSpouseText: spouseState.text,
        selectedSpouseValue: spouseState.value,
        selectedAgeDiff: '',
        candidateCount: String(rowCandidates.length),
        spouseCandidateCount: String(rowCandidates.length),
        spouseCandidateWithinWindowCount: '0',
        spouseOverrideApplied: '0',
        spouseOverrideReason: 'no-qualifying-spouse-candidate',
        spouseCandidateSelectedText: '',
        spouseCandidateSelectedAge: '',
        spouseDriverQuestionPresent: '0',
        spouseDriverYesSelected: 'SKIP',
        candidates: candidateSummary,
        rejectedCandidates: 'outside-age-window-or-missing-age',
        spouseSelectionMethod: 'override-no-candidate',
        failedFields: single.ok ? '' : 'maritalStatus',
        evidence: 'ASC_PARTICIPANT_SPOUSE_OVERRIDE_NO_CANDIDATE'
      });
    }
    if (!forceMarriedSpouseSelection && overrideEnabled && leadSingleOrUnknown && inWindowRows.length > 1) {
      return lineResult({ result: 'AMBIGUOUS', method: 'spouse-age-ambiguous', selectedMaritalStatus: readAscMaritalStatus().text, selectedSpouseText: '', selectedSpouseValue: '', selectedAgeDiff: '', candidateCount: String(rowCandidates.length), spouseCandidateCount: String(rowCandidates.length), spouseCandidateWithinWindowCount: String(inWindowRows.length), spouseOverrideApplied: '0', spouseOverrideReason: 'multiple-candidates-within-age-window', spouseCandidateSelectedText: '', spouseCandidateSelectedAge: '', spouseDriverQuestionPresent: '0', spouseDriverYesSelected: '0', candidates: compact(inWindowRows.map((c) => `${c.text}:ageDiff=${c.ageDiff}`).join('||'), 240), rejectedCandidates: '', spouseSelectionMethod: 'age-window', failedFields: 'spouse', evidence: '' });
    }
    if (leadMarital === 'SINGLE' && !overrideEnabled && !forceMarriedSpouseSelection) {
      const single = setAscMaritalStatus('Single');
      const spouseSelect = findAscSpouseSelect();
      const spouseState = spouseSelect ? readSelectState(spouseSelect) : { value: '', text: '' };
      return lineResult({
        result: single.method === 'already-selected' ? 'SINGLE_CONFIRMED' : (single.ok ? 'SINGLE_SET' : 'FAILED'),
        method: single.method,
        selectedMaritalStatus: single.state.text || 'Single',
        selectedSpouseText: spouseState.text,
        selectedSpouseValue: spouseState.value,
        selectedAgeDiff: '',
        candidateCount: spouseSelect ? String(Math.max(0, (spouseSelect.options || []).length - 1)) : '0',
        spouseCandidateCount: String(rowCandidates.length),
        spouseCandidateWithinWindowCount: String(inWindowRows.length),
        spouseOverrideApplied: '0',
        spouseOverrideReason: 'override-disabled',
        spouseCandidateSelectedText: '',
        spouseCandidateSelectedAge: '',
        spouseDriverQuestionPresent: '0',
        spouseDriverYesSelected: 'SKIP',
        candidates: '',
        rejectedCandidates: spouseSelect ? 'skipped-lead-single' : '',
        spouseSelectionMethod: 'skipped-lead-single',
        failedFields: single.ok ? '' : 'maritalStatus',
        evidence: 'ASC_PARTICIPANT_LEAD_SINGLE_SPOUSE_SKIPPED'
      });
    }
    if (leadMarital !== 'MARRIED' && !leadSpouseName && !(overrideEnabled && leadSingleOrUnknown)) {
      const current = readAscMaritalStatus();
      return lineResult({
        result: 'NO_DROPDOWN',
        method: 'marital-status-not-requested',
        selectedMaritalStatus: current.text,
        selectedSpouseText: '',
        selectedSpouseValue: '',
        selectedAgeDiff: '',
        candidateCount: '0',
        spouseCandidateCount: String(rowCandidates.length),
        spouseCandidateWithinWindowCount: String(inWindowRows.length),
        spouseOverrideApplied: '0',
        spouseOverrideReason: '',
        spouseCandidateSelectedText: '',
        spouseCandidateSelectedAge: '',
        spouseDriverQuestionPresent: '0',
        spouseDriverYesSelected: 'SKIP',
        candidates: '',
        rejectedCandidates: '',
        spouseSelectionMethod: 'not-requested',
        failedFields: '',
        evidence: 'lead-marital-status-missing'
      });
    }
    const married = setAscMaritalStatus('Married');
    if (!married.ok)
      return lineResult({ result: 'FAILED', method: married.method, selectedMaritalStatus: married.state.text, selectedSpouseText: '', selectedSpouseValue: '', selectedAgeDiff: '', candidateCount: '0', spouseCandidateCount: String(rowCandidates.length), spouseCandidateWithinWindowCount: String(inWindowRows.length), spouseOverrideApplied: '0', spouseOverrideReason: '', spouseCandidateSelectedText: '', spouseCandidateSelectedAge: '', spouseDriverQuestionPresent: '0', spouseDriverYesSelected: '0', candidates: '', rejectedCandidates: '', spouseSelectionMethod: '', failedFields: 'maritalStatus', evidence: '' });
    const spouseSelect = findAscSpouseSelect();
    if (!spouseSelect)
      return lineResult({ result: 'NO_DROPDOWN', method: 'married-no-spouse-dropdown', selectedMaritalStatus: married.state.text || 'Married', selectedSpouseText: '', selectedSpouseValue: '', selectedAgeDiff: '', candidateCount: '0', spouseCandidateCount: String(rowCandidates.length), spouseCandidateWithinWindowCount: String(inWindowRows.length), spouseOverrideApplied: '0', spouseOverrideReason: '', spouseCandidateSelectedText: '', spouseCandidateSelectedAge: '', spouseDriverQuestionPresent: '0', spouseDriverYesSelected: '0', candidates: candidateSummary, rejectedCandidates: '', spouseSelectionMethod: '', failedFields: 'spouseDropdown', evidence: '' });
    const options = Array.from(spouseSelect.options || [])
      .filter(nonPlaceholderOption)
      .map((opt) => {
        const text = safe(opt.text || opt.innerText);
        const row = driverRows.find((driver) => personNameStrongMatches(driver.name, text));
        const age = Number((row && row.age) || parseAgeFromText(text) || parseAgeNearPersonName(text) || 0);
        return { opt, text, value: safe(opt.value), age, ageDiff: primaryAge && age ? Math.abs(primaryAge - age) : 999 };
      });
    let picked = null;
    let method = '';
    if (leadSpouseName) {
      const matches = options.filter((candidate) => personNameStrongMatches(candidate.text, leadSpouseName));
      if (matches.length === 1) {
        picked = matches[0];
        method = source.selectedSpouseName ? 'policy-selected-name-match' : 'name-match';
      } else if (matches.length > 1) {
        return lineResult({ result: 'AMBIGUOUS', method: 'spouse-name-ambiguous', selectedMaritalStatus: 'Married', selectedSpouseText: '', selectedSpouseValue: '', selectedAgeDiff: '', candidateCount: String(options.length), spouseCandidateCount: String(rowCandidates.length), spouseCandidateWithinWindowCount: String(inWindowRows.length), spouseOverrideApplied: '0', spouseOverrideReason: 'multiple-dropdown-name-matches', spouseCandidateSelectedText: '', spouseCandidateSelectedAge: '', spouseDriverQuestionPresent: '0', spouseDriverYesSelected: '0', candidates: compact(options.map((c) => c.text).join('||'), 240), rejectedCandidates: '', spouseSelectionMethod: 'name-match', failedFields: 'spouse', evidence: '' });
      }
      if (!picked)
        return lineResult({ result: 'FAILED', method: 'spouse-dropdown-option-not-found', selectedMaritalStatus: 'Married', selectedSpouseText: '', selectedSpouseValue: '', selectedAgeDiff: '', candidateCount: String(options.length), spouseCandidateCount: String(rowCandidates.length), spouseCandidateWithinWindowCount: String(inWindowRows.length), spouseOverrideApplied: '0', spouseOverrideReason: 'ASC_SPOUSE_DROPDOWN_OPTION_NOT_FOUND', spouseCandidateSelectedText: leadSpouseName, spouseCandidateSelectedAge: '', spouseDriverQuestionPresent: '0', spouseDriverYesSelected: '0', candidates: compact(options.map((c) => c.text).join('||'), 240), rejectedCandidates: '', spouseSelectionMethod: 'name-match', failedFields: 'spouseDropdown', evidence: 'ASC_SPOUSE_DROPDOWN_OPTION_NOT_FOUND' });
    }
    if (!picked && overrideEnabled && leadSingleOrUnknown && inWindowRows.length === 1) {
      const rowCandidate = inWindowRows[0];
      const matches = options.filter((candidate) => personNameStrongMatches(candidate.text, rowCandidate.text));
      if (!matches.length)
        return lineResult({ result: 'FAILED', method: 'spouse-dropdown-option-not-found', selectedMaritalStatus: 'Married', selectedSpouseText: '', selectedSpouseValue: '', selectedAgeDiff: String(rowCandidate.ageDiff), candidateCount: String(options.length), spouseCandidateCount: String(rowCandidates.length), spouseCandidateWithinWindowCount: '1', spouseOverrideApplied: '0', spouseOverrideReason: 'ASC_SPOUSE_DROPDOWN_OPTION_NOT_FOUND', spouseCandidateSelectedText: rowCandidate.text, spouseCandidateSelectedAge: String(rowCandidate.age || ''), spouseDriverQuestionPresent: '0', spouseDriverYesSelected: '0', candidates: compact(options.map((c) => c.text).join('||'), 240), rejectedCandidates: '', spouseSelectionMethod: 'age-window', failedFields: 'spouseDropdown', evidence: 'ASC_SPOUSE_DROPDOWN_OPTION_NOT_FOUND' });
    }
    if (!picked) {
      const inWindow = options.filter((candidate) => candidate.ageDiff <= maxAgeDiff && rowCandidates.some((rowCandidate) => rowCandidate.age && personNameStrongMatches(candidate.text, rowCandidate.text)));
      if (inWindow.length === 1) {
        picked = inWindow[0];
        method = 'age-window';
      } else if (inWindow.length > 1) {
        return lineResult({ result: 'AMBIGUOUS', method: 'spouse-age-ambiguous', selectedMaritalStatus: 'Married', selectedSpouseText: '', selectedSpouseValue: '', selectedAgeDiff: '', candidateCount: String(options.length), spouseCandidateCount: String(rowCandidates.length), spouseCandidateWithinWindowCount: String(inWindow.length), spouseOverrideApplied: '0', spouseOverrideReason: 'multiple-candidates-within-age-window', spouseCandidateSelectedText: '', spouseCandidateSelectedAge: '', spouseDriverQuestionPresent: '0', spouseDriverYesSelected: '0', candidates: compact(inWindow.map((c) => `${c.text}:ageDiff=${c.ageDiff}`).join('||'), 240), rejectedCandidates: '', spouseSelectionMethod: 'age-window', failedFields: 'spouse', evidence: '' });
      }
    }
    if (!picked)
      return lineResult({ result: 'NO_SAFE_SPOUSE', method: 'no-safe-spouse', selectedMaritalStatus: 'Married', selectedSpouseText: '', selectedSpouseValue: '', selectedAgeDiff: '', candidateCount: String(options.length), spouseCandidateCount: String(rowCandidates.length), spouseCandidateWithinWindowCount: String(inWindowRows.length), spouseOverrideApplied: '0', spouseOverrideReason: '', spouseCandidateSelectedText: '', spouseCandidateSelectedAge: '', spouseDriverQuestionPresent: '0', spouseDriverYesSelected: '0', candidates: compact(options.map((c) => `${c.text}:ageDiff=${c.ageDiff === 999 ? '' : c.ageDiff}`).join('||'), 240), rejectedCandidates: 'outside-age-window', spouseSelectionMethod: '', failedFields: 'spouse', evidence: '' });
    const already = safe(spouseSelect.value) === picked.value;
    const applied = already || setSelectValue(spouseSelect, picked.value, false);
    const after = readSelectState(spouseSelect);
    const spouseDriver = applied ? setAscSpouseDriverYes() : { present: '0', selected: '0', method: 'spouse-not-selected' };
    const spouseDriverOk = spouseDriver.present !== '1' || spouseDriver.selected === '1';
    const selectedOk = applied && safe(spouseSelect.value) === picked.value && spouseDriverOk;
    const pickedRow = rowCandidates.find((rowCandidate) => personNameStrongMatches(rowCandidate.text, picked.text)) || {};
    const overrideApplied = overrideEnabled && leadSingleOrUnknown ? '1' : '0';
    return lineResult({
      result: selectedOk ? (already ? 'ALREADY_SELECTED' : 'SELECTED') : 'FAILED',
      method,
      selectedMaritalStatus: 'Married',
      selectedSpouseText: after.text,
      selectedSpouseValue: after.value,
      selectedAgeDiff: String(picked.ageDiff === 999 ? '' : picked.ageDiff),
      candidateCount: String(options.length),
      spouseCandidateCount: String(rowCandidates.length),
      spouseCandidateWithinWindowCount: String(inWindowRows.length),
      spouseOverrideApplied: overrideApplied,
      spouseOverrideReason: overrideApplied === '1' ? 'unique-advisor-candidate-within-age-window' : '',
      spouseCandidateSelectedText: after.text,
      spouseCandidateSelectedAge: String(picked.age || pickedRow.age || ''),
      spouseDriverQuestionPresent: spouseDriver.present,
      spouseDriverYesSelected: spouseDriver.selected,
      candidates: compact(options.map((c) => `${c.text}:ageDiff=${c.ageDiff === 999 ? '' : c.ageDiff}`).join('||'), 240),
      rejectedCandidates: '',
      spouseSelectionMethod: method,
      failedFields: selectedOk ? '' : (applied ? 'spouseDriver' : 'spouse'),
      evidence: 'spouse-selected'
    });
  };
  const parseAscPartialVehicles = (source = {}) => {
    const raw = Array.isArray(source.partialVehicles) ? source.partialVehicles : [];
    return raw.map((vehicle) => ({
      year: safe(vehicle && vehicle.year).trim(),
      make: safe(vehicle && vehicle.make).trim(),
      model: '',
      vin: safe(vehicle && vehicle.vin).trim(),
      vinSuffix: safe(vehicle && vehicle.vinSuffix).trim(),
      allowedMakeLabels: vehicle && (vehicle.allowedMakeLabels || vehicle.makeAliases || vehicle.advisorMakeLabels) || ''
    })).filter((vehicle) => vehicle.year && vehicle.make);
  };
  const hasVehicleVinEvidenceText = (text) => /\bVIN\b\s*[:#]?\s*[A-Z0-9*]{6,}/i.test(text) || /\b[A-HJ-NPR-Z0-9*]{8,17}\b/i.test(text);
  const ascLeadModelLooksGenericOrTrim = (vehicle) => {
    const model = normalizeVehicleText(vehicle && vehicle.model);
    if (!model) return true;
    if (/DIESEL|ENGINE|MOTOR|TURBO|HYBRID|ELECTRIC|PLUGIN|PHEV|EV|V6|V8|V10|4X4|4WD|AWD|FWD|RWD|CREW|CAB|LIMITED|SPORT|TOURING|BASE|PREMIUM|LUXURY|PLATINUM|XL|XLT|LT|LS|LTZ|SLT|SE|SEL|LE|XLE|EX|LX|TRD|HD/.test(model))
      return true;
    const key = normalizeVehicleModelKey(model);
    return key.length <= 2 || /^(UNKNOWN|OTHER|TRUCK|CAR|SUV|SEDAN|COUPE|VAN|PICKUP)$/.test(key);
  };
  const collectAscVehicleRows = () => {
    const nodes = Array.from(document.querySelectorAll('div,section,article,li,tr,fieldset'))
      .filter(visible)
      .filter((node) => {
        const text = getText(node);
        if (!/\b(?:19|20)\d{2}\b/.test(text)) return false;
        if (text.length > 800) return false;
        if (vehicleTitleCount(text) > 1) return false;
        return true;
      });
    const seen = new Set();
    const rows = [];
    for (const node of nodes.sort((a, b) => getText(a).length - getText(b).length)) {
      const text = getText(node);
      const key = normLower(text);
      if (!key || seen.has(key)) continue;
      if (rows.some((row) => key.includes(normLower(row.text)))) continue;
      seen.add(key);
      const buttons = Array.from(node.querySelectorAll('button[id],a[id],[role=button][id],button,a,[role=button]')).filter(visible);
      const addButton = buttons.find((btn) => /-(addToQuote|add)$/i.test(safe(btn.id)) || answerTextMatches(getText(btn), 'Add')) || null;
      const removeButton = buttons.find((btn) => /-remove$/i.test(safe(btn.id)) || answerTextMatches(getText(btn), 'Remove')) || null;
      const editButton = buttons.find((btn) => /-edit$/i.test(safe(btn.id)) || answerTextMatches(getText(btn), 'Edit')) || null;
      const lowerText = normLower(text);
      rows.push({
        row: node,
        text,
        addButton,
        removeButton,
        editButton,
        added: lowerText.includes('added to quote') || lowerText.includes('confirmed') || (!!editButton && !addButton),
        unresolved: !!addButton || !!removeButton,
        vinEvidence: hasVehicleVinEvidenceText(text)
      });
    }
    return rows;
  };
  const vehiclePartialModelText = (rowText, partial) => {
    const text = normalizeVehicleText(rowText);
    const labels = parseVehicleListArg(partial.allowedMakeLabels).concat([partial.make]).map(normalizeVehicleText).filter(Boolean);
    let best = '';
    for (const label of labels) {
      const escaped = label.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
      const regex = new RegExp(`\\b${partial.year}\\b[\\s\\S]*?\\b${escaped}\\b\\s+([A-Z0-9][A-Z0-9\\s-]{0,80})`, 'i');
      const match = text.match(regex);
      if (!match) continue;
      let model = safe(match[1])
        .replace(/\bVIN\b[\s\S]*$/i, '')
        .replace(/\b(ADD|REMOVE|EDIT|CONFIRMED|ADDED|TO|QUOTE)\b[\s\S]*$/i, '')
        .replace(/\s+/g, ' ')
        .trim();
      if (model) {
        best = model;
        break;
      }
    }
    return best;
  };
  const ascPartialVehicleMatches = (row, partial) => {
    const details = scoreVehicleCandidate(row.text, { ...partial, model: '', strictModelMatch: false });
    const modelText = vehiclePartialModelText(row.text, partial);
    return {
      ok: details.yearMatch && details.makeMatch && !!modelText && row.vinEvidence,
      yearMatch: details.yearMatch,
      makeMatch: details.makeMatch,
      modelText,
      vinEvidence: row.vinEvidence
    };
  };
  const ascVehicleRowsStatus = () => {
    const rows = collectAscVehicleRows();
    const added = rows.filter((row) => row.added);
    const unresolved = rows.filter((row) => row.unresolved && !row.added);
    const removed = rows.filter((row) => normLower(row.text).includes('removed'));
    const saveButton = findAscSaveButton();
    return {
      result: rows.length ? 'FOUND' : 'NONE',
      vehicleCount: String(rows.length),
      unresolvedVehicleCount: String(unresolved.length),
      addedVehicleCount: String(added.length),
      removedVehicleCount: String(removed.length),
      confirmedOrAddedVehicleCount: String(added.length),
      vehicleSummaries: compact(rows.map((row) => `${compact(row.text, 90)}|added=${row.added ? 1 : 0}|vin=${row.vinEvidence ? 1 : 0}|add=${row.addButton ? 1 : 0}|remove=${row.removeButton ? 1 : 0}|addButtonId=${safe(row.addButton && row.addButton.id)}|removeButtonId=${safe(row.removeButton && row.removeButton.id)}`).join('||'), 640),
      saveButtonEnabled: saveButton && !isDisabledLike(saveButton) ? '1' : '0',
      evidence: rows.length ? 'vehicle-rows' : '',
      missing: rows.length ? '' : 'vehicle-rows'
    };
  };
  const ascReconcileVehicleRows = (source = {}) => {
    const rows = collectAscVehicleRows();
    const complete = parseExpectedVehicles(source).filter((vehicle) => vehicle.year && vehicle.make && vehicle.model);
    const partials = parseAscPartialVehicles(source);
    const matchedRowIndexes = new Set();
    const addedVehicles = [];
    const promotedPartialVehicles = [];
    const deferredPartialVehicles = [];
    const missingComplete = [];
    const ascVehicleCandidate = (row, index, vehicle) => {
      const details = scoreVehicleCandidate(row.text, vehicle);
      const yearDelta = details.yearDelta === '' ? 999 : Number(details.yearDelta);
      const absYearDelta = Math.abs(yearDelta);
      const vinEvidence = !!row.vinEvidence || !!details.publicVinEvidence || !!details.vinMatch || !!details.vinSuffixMatch;
      let method = '';
      let rank = 0;
      if (details.yearMatch && details.makeMatch && details.modelMatch) {
        method = 'ASC_LEDGER_VEHICLE_MATCH_EXACT_YMM';
        rank = 400;
      } else if (details.makeMatch && details.modelMatch && absYearDelta <= 2) {
        method = 'ASC_LEDGER_VEHICLE_MATCH_YEAR_TOLERANCE';
        rank = 300 - absYearDelta;
      } else if (details.yearMatch && details.makeMatch && !details.modelMatch && vinEvidence && ascLeadModelLooksGenericOrTrim(vehicle)) {
        method = 'ASC_LEDGER_VEHICLE_MATCH_VIN_BACKED_MODEL_CORRECTION';
        rank = 220;
      }
      if (!method) return null;
      return {
        row,
        index,
        vehicle,
        details,
        method,
        rank: rank + (vinEvidence ? 20 : 0),
        vinEvidence,
        yearDelta,
        absYearDelta
      };
    };
    const chooseAscVehicleCandidate = (candidates) => {
      if (!candidates.length) return { candidate: null, ambiguous: false, candidates: [] };
      const sorted = candidates.slice().sort((a, b) => {
        if (b.rank !== a.rank) return b.rank - a.rank;
        if (a.absYearDelta !== b.absYearDelta) return a.absYearDelta - b.absYearDelta;
        if (a.vinEvidence !== b.vinEvidence) return a.vinEvidence ? -1 : 1;
        return a.row.text.length - b.row.text.length;
      });
      const top = sorted[0];
      const tied = sorted.filter((candidate) => candidate.rank === top.rank && candidate.absYearDelta === top.absYearDelta && candidate.vinEvidence === top.vinEvidence);
      return { candidate: top, ambiguous: tied.length > 1, candidates: tied };
    };
    for (const vehicle of complete) {
      const candidates = rows
        .map((row, index) => matchedRowIndexes.has(index) ? null : ascVehicleCandidate(row, index, vehicle))
        .filter(Boolean);
      const picked = chooseAscVehicleCandidate(candidates);
      if (picked.ambiguous) {
        return lineResult({
          result: 'AMBIGUOUS',
          method: 'ASC_LEDGER_VEHICLE_MATCH_AMBIGUOUS',
          addedVehicles: '',
          removedVehicles: '',
          promotedPartialVehicles: '',
          deferredPartialVehicles: '',
          confirmedVehicleCount: String(rows.filter((candidate) => candidate.added).length),
          unresolvedVehicles: compact(picked.candidates.map((candidate) => candidate.row.text).join('||'), 240),
          failedFields: 'vehicleMatch',
          evidence: vehicleLabel(vehicle)
        });
      }
      if (!picked.candidate) {
        missingComplete.push(vehicleLabel(vehicle));
        continue;
      }
      const candidate = picked.candidate;
      matchedRowIndexes.add(candidate.index);
      const row = candidate.row;
      if (!row.added && row.addButton) {
        const clicked = clickCenterEl(row.addButton);
        if (clicked) addedVehicles.push(vehicleLabel(vehicle));
        return lineResult({
          result: clicked ? 'PARTIAL' : 'FAILED',
          method: candidate.method,
          addedVehicles: addedVehicles.join('||'),
          removedVehicles: '',
          promotedPartialVehicles: '',
          deferredPartialVehicles: '',
          confirmedVehicleCount: String(rows.filter((candidate) => candidate.added).length),
          unresolvedVehicles: vehicleLabel(vehicle),
          failedFields: clicked ? '' : 'vehicleAdd',
          evidence: compact(`${row.text}|yearDelta=${candidate.yearDelta}|vin=${candidate.vinEvidence ? 1 : 0}|modelMatch=${candidate.details.modelMatch ? 1 : 0}`, 220)
        });
      }
    }
    if (missingComplete.length) {
      return lineResult({
        result: 'FAILED',
        method: 'complete-vehicle-missing',
        addedVehicles: '',
        removedVehicles: '',
        promotedPartialVehicles: '',
        deferredPartialVehicles: '',
        confirmedVehicleCount: String(rows.filter((candidate) => candidate.added).length),
        unresolvedVehicles: missingComplete.join('||'),
        failedFields: 'completeVehicles',
        evidence: compact(rows.map((row) => row.text).join('||'), 240)
      });
    }
    for (const partial of partials) {
      const candidates = rows
        .map((row, index) => ({ row, index, match: ascPartialVehicleMatches(row, partial) }))
        .filter((candidate) => candidate.match.ok);
      if (candidates.length === 1) {
        const candidate = candidates[0];
        matchedRowIndexes.add(candidate.index);
        const promotedLabel = `${partial.year} ${partial.make} ${candidate.match.modelText}`;
        if (!candidate.row.added && candidate.row.addButton) {
          const clicked = clickCenterEl(candidate.row.addButton);
          if (clicked) promotedPartialVehicles.push(promotedLabel);
          return lineResult({
            result: clicked ? 'PARTIAL' : 'FAILED',
            method: 'partial-vehicle-unique-vin-add',
            addedVehicles: '',
            removedVehicles: '',
            promotedPartialVehicles: promotedPartialVehicles.join('||'),
            deferredPartialVehicles: '',
            confirmedVehicleCount: String(rows.filter((row) => row.added).length),
            unresolvedVehicles: promotedLabel,
            failedFields: clicked ? '' : 'partialVehicleAdd',
            evidence: compact(candidate.row.text, 180)
          });
        }
        promotedPartialVehicles.push(promotedLabel);
      } else if (candidates.length > 1) {
        deferredPartialVehicles.push(`${partial.year} ${partial.make}`);
        return lineResult({
          result: 'AMBIGUOUS',
          method: 'partial-vehicle-multiple-candidates',
          addedVehicles: '',
          removedVehicles: '',
          promotedPartialVehicles: '',
          deferredPartialVehicles: deferredPartialVehicles.join('||'),
          confirmedVehicleCount: String(rows.filter((row) => row.added).length),
          unresolvedVehicles: compact(candidates.map((candidate) => candidate.row.text).join('||'), 240),
          failedFields: 'partialVehicles',
          evidence: ''
        });
      } else {
        deferredPartialVehicles.push(`${partial.year} ${partial.make}`);
      }
    }
    const satisfiedCount = rows.filter((row, index) => matchedRowIndexes.has(index) && row.added).length + promotedPartialVehicles.length;
    return lineResult({
      result: deferredPartialVehicles.length ? 'PARTIAL' : 'OK',
      method: 'vehicle-row-reconciliation',
      addedVehicles: '',
      removedVehicles: '',
      promotedPartialVehicles: promotedPartialVehicles.join('||'),
      deferredPartialVehicles: deferredPartialVehicles.join('||'),
      confirmedVehicleCount: String(Math.max(satisfiedCount, rows.filter((row) => row.added).length)),
      unresolvedVehicles: deferredPartialVehicles.join('||'),
      failedFields: '',
      evidence: compact(rows.map((row) => row.text).join('||'), 240)
    });
  };
  const summarizeVehicleCandidate = (candidate) => compact(candidate && candidate.cardText, 140);
  const isVehicleAlreadyListedMatch = (source = {}) => {
    const listed = findVehicleMatchCandidates(source).filter((candidate) => {
      const text = lower(candidate.cardText);
      if (!text) return false;
      if (text.includes('added to quote') || text.includes(' confirmed')) return true;
      return !findCardButtonByText(candidate.card, 'Confirm');
    });
    if (!listed.length || vehicleCandidatesAreAmbiguous(listed))
      return false;
    return true;
  };
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
  const setKnownCheckboxChecked = (input) => {
    if (!input || isDisabledLike(input)) return false;
    try { input.checked = true; } catch {}
    try { input.dispatchEvent(new Event('input', { bubbles: true })); } catch {}
    try { input.dispatchEvent(new Event('change', { bubbles: true })); } catch {}
    return input.checked === true;
  };
  const ensureStartQuotingAutoCheckbox = () => {
    const input = document.getElementById('ConsumerReports.Auto.Product-intel#102');
    const before = !!(input && input.checked);
    let method = 'missing';
    let clicked = false;
    let directSetUsed = false;
    if (!input) {
      return lineResult({
        result: 'FAILED',
        autoPresent: '0',
        autoCheckedBefore: '0',
        autoCheckedAfter: '0',
        clicked: '0',
        directSetUsed: '0',
        method,
        failedFields: ['auto'],
        alerts: collectVisibleAlerts().join(' || ')
      });
    }
    if (before) {
      return linesOut({
        result: 'OK',
        autoPresent: '1',
        autoCheckedBefore: '1',
        autoCheckedAfter: '1',
        clicked: '0',
        directSetUsed: '0',
        method: 'stable-checkbox-already',
        failedFields: '',
        alerts: collectVisibleAlerts().join(' || ')
      });
    }
    const target = getInputClickTarget(input);
    if (target && clickCenterEl(target)) {
      clicked = true;
      method = target === input ? 'stable-checkbox-input' : 'stable-checkbox-label';
    }
    let after = input.checked === true;
    if (!after) {
      directSetUsed = true;
      method = method === 'missing' ? 'stable-checkbox-direct' : `${method}|stable-checkbox-direct`;
      after = setKnownCheckboxChecked(input);
    }
    return lineResult({
      result: after ? 'OK' : 'FAILED',
      autoPresent: '1',
      autoCheckedBefore: before ? '1' : '0',
      autoCheckedAfter: after ? '1' : '0',
      clicked: clicked ? '1' : '0',
      directSetUsed: directSetUsed ? '1' : '0',
      method,
      failedFields: after ? '' : 'auto',
      alerts: collectVisibleAlerts().join(' || ')
    });
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
    const section = findStartQuotingSection(source);
    if (!section) return null;
    const stable = document.getElementById(selectors.quoteBlockAddProductId || 'quotesButton');
    if (stable && visible(stable) && section.contains(stable))
      return stable;
    return Array.from(section.querySelectorAll('button,a,[role=button]'))
      .filter(visible)
      .find((node) => startsWithTextToken(getText(node), 'Add product')) || null;
  };
  const buildStartQuotingStatus = (source = {}) => {
    const section = findStartQuotingSection(source);
    const autoState = readStartQuotingAutoState(source);
    const ratingState = readStartQuotingRatingState(source);
    const createBtn = findCreateQuotesButton(source);
    const addProductLink = findStartQuotingAddProductLink(source);
    const stableAuto = document.getElementById('ConsumerReports.Auto.Product-intel#102');
    const hasStartQuotingText = !!section || bodyText().includes('start quoting');
    const ratingStatePresent = !!(ratingState.value || ratingState.text || ratingState.source);
    const missing = [];
    if (!hasStartQuotingText) missing.push('startQuotingText');
    if (!section) missing.push('startQuotingSection');
    if (!autoState.present) missing.push('autoProduct');
    if (!ratingStatePresent) missing.push('ratingState');
    if (!createBtn) missing.push('createQuotes');
    const evidence = [
      section ? 'start-quoting-section' : '',
      autoState.source ? `auto:${autoState.source}` : '',
      ratingState.source ? `rating:${ratingState.source}` : '',
      createBtn ? 'create-quotes' : '',
      addProductLink ? 'add-product' : ''
    ].filter(Boolean).join('|');
    return {
      hasStartQuotingText: hasStartQuotingText ? '1' : '0',
      startQuotingSectionPresent: section ? '1' : '0',
      autoProductPresent: autoState.present ? '1' : '0',
      autoProductChecked: autoState.selected ? '1' : '0',
      autoProductSelected: autoState.selected ? '1' : '0',
      autoProductSource: autoState.source,
      autoCheckboxId: stableAuto ? safe(stableAuto.id) : '',
      ratingStatePresent: ratingStatePresent ? '1' : '0',
      ratingStateValue: ratingState.value,
      ratingStateText: ratingState.text,
      ratingStateSource: ratingState.source,
      createQuoteButtonPresent: createBtn ? '1' : '0',
      createQuoteButtonEnabled: createBtn && !createBtn.disabled ? '1' : '0',
      addProductLinkPresent: addProductLink ? '1' : '0',
      createQuotesPresent: createBtn ? '1' : '0',
      createQuotesEnabled: createBtn && !createBtn.disabled ? '1' : '0',
      addProductPresent: addProductLink ? '1' : '0',
      evidence: compact(evidence, 240),
      missing: missing.join('|'),
      alerts: collectVisibleAlerts().join(' || ')
    };
  };
  const findProductOverviewSubnavTargetFromRapport = (source = {}) => {
    const urls = getUrlArgs(source);
    const url = pageUrl();
    const text = bodyText();
    const onRapport = (!!urls.rapportContains && url.includes(urls.rapportContains))
      || (url.includes('/apps/intel/102/') && includesText(text, 'gather data'));
    if (!onRapport) return { target: null, reason: 'wrong-page' };
    const candidates = Array.from(document.querySelectorAll('button,a,[role=button],[tabindex]'))
      .filter(visible)
      .filter((node) => !isDisabledLike(node))
      .map((node) => ({ node, text: compact(getText(node), 80), cls: safe(node.className), id: safe(node.id) }))
      .filter(({ text: itemText, id }) => {
        const upper = normUpper(itemText);
        return upper === 'SELECT PRODUCT'
          && upper !== 'ADD PRODUCT'
          && !upper.includes('ADD PRODUCT')
          && lower(id) !== 'addproduct';
      });
    if (!candidates.length) return { target: null, reason: 'no-select-product' };
    candidates.sort((a, b) => {
      const aClass = lower(a.cls);
      const bClass = lower(b.cls);
      const aScore = (aClass.includes('c-sub-nav__item') ? 50 : 0) + (safe(a.node.tagName) === 'A' ? 10 : 0);
      const bScore = (bClass.includes('c-sub-nav__item') ? 50 : 0) + (safe(b.node.tagName) === 'A' ? 10 : 0);
      return bScore - aScore;
    });
    return { target: candidates[0].node, reason: 'select-product-subnav' };
  };
  const clickProductOverviewSubnavFromRapport = (source = {}) => {
    const match = findProductOverviewSubnavTargetFromRapport(source);
    if (match.reason === 'wrong-page') {
      return linesOut({
        result: 'WRONG_PAGE',
        clicked: '0',
        targetText: '',
        targetClass: '',
        targetTag: '',
        urlBefore: compact(pageUrl(), 240),
        evidence: 'not-rapport'
      });
    }
    const target = match.target;
    if (!target) {
      return linesOut({
        result: 'NO_LINK',
        clicked: '0',
        targetText: '',
        targetClass: '',
        targetTag: '',
        urlBefore: compact(pageUrl(), 240),
        evidence: match.reason || 'no-select-product'
      });
    }
    const clicked = clickCenterEl(target);
    return linesOut({
      result: clicked ? 'OK' : 'CLICK_FAILED',
      clicked: clicked ? '1' : '0',
      targetText: compact(getText(target), 120),
      targetClass: compact(safe(target.className), 160),
      targetTag: safe(target.tagName),
      urlBefore: compact(pageUrl(), 240),
      evidence: match.reason || 'select-product-subnav'
    });
  };
  const selectProductRouteFamily = (source = {}) => isSelectProductFormPage(source) ? 'intel-select-product' : 'unknown';
  const findEffectiveDateInput = () => findByStableId('SelectProduct.EffectiveDate')
    || document.querySelector('input[id*="EffectiveDate"],input[name*="EffectiveDate"],input[placeholder*="Effective" i],input[aria-label*="Effective" i]');
  const isSelectProductPlaceholderText = (text) => /^(select\s+one|select|choose|please\s+select|-+|none)$/i.test(safe(text).trim());
  const findCurrentAddressSelect = () => {
    const stable = document.getElementById('SelectProduct.CurrentAddress');
    if (stable && /^SELECT$/i.test(safe(stable.tagName))) return stable;
    return Array.from(document.querySelectorAll('select'))
      .filter(visible)
      .find((el) => safe(el.id) === 'SelectProduct.CurrentAddress' || safe(el.name) === 'SelectProduct.CurrentAddress' || /CurrentAddress/i.test(`${safe(el.id)} ${safe(el.name)}`)) || null;
  };
  const findCurrentAddressControls = () => Array.from(document.querySelectorAll('input[type=radio],input[type=checkbox],button,[role=button],label'))
    .filter(visible)
    .filter((el) => /current[^a-z0-9]*address|same[^a-z0-9]*address|use[^a-z0-9]*this[^a-z0-9]*address/i.test(`${safe(el.id)} ${safe(el.name)} ${safe(el.value)} ${readInputLabel(el)} ${getText(el)}`));
  const readCurrentAddressState = () => {
    const select = findCurrentAddressSelect();
    if (select && visible(select)) {
      const state = readSelectState(select);
      const selectedIndex = Number.isFinite(Number(select.selectedIndex)) ? Number(select.selectedIndex) : -1;
      const text = safe(state.text).trim();
      const value = safe(state.value).trim();
      const selectedTextValid = !!text && !isSelectProductPlaceholderText(text);
      const selected = selectedTextValid || (!!value && selectedTextValid);
      return {
        present: true,
        selected,
        safeUnique: false,
        controls: [select],
        source: 'stable-select',
        value,
        text,
        selectedIndex: String(selectedIndex)
      };
    }
    const controls = findCurrentAddressControls();
    const selected = controls.some((el) => isSelectedNode(el) || el.checked || /selected|checked|active/i.test(`${safe(el.className)} ${safe(el.getAttribute && el.getAttribute('aria-checked'))}`));
    return {
      present: controls.length > 0,
      selected,
      safeUnique: controls.length === 1,
      controls,
      source: controls.length ? 'semantic-control' : '',
      value: selected ? compact(controls.map((el) => safe(el.value)).filter(Boolean).join('|'), 120) : '',
      text: selected ? compact(controls.map((el) => readInputLabel(el) || getText(el)).filter(Boolean).join('|'), 180) : '',
      selectedIndex: ''
    };
  };
  const findSelectProductContinueButton = (source = {}) => {
    const selectors = getSelectorArgs(source);
    return findByStableId(selectors.selectProductContinueId || source.selectProductContinueId || 'selectProductContinue')
      || Array.from(document.querySelectorAll('button,a,input[type=button],input[type=submit]'))
        .filter(visible)
        .find((el) => /continue/i.test(safe(el.innerText || el.textContent || el.value)));
  };
  const selectProductControlSelected = (node) => {
    if (!node) return false;
    if (/^(INPUT|OPTION)$/i.test(safe(node.tagName)) && 'checked' in node && node.checked) return true;
    if (safe(node.getAttribute && node.getAttribute('aria-checked')) === 'true') return true;
    if (safe(node.getAttribute && node.getAttribute('aria-pressed')) === 'true') return true;
    if (safe(node.getAttribute && node.getAttribute('aria-selected')) === 'true') return true;
    if (/\b(selected|active|checked|current|chosen|pressed)\b/i.test(safe(node.className))) return true;
    if (/^(selected|active|checked|on|true)$/i.test(safe(node.getAttribute && node.getAttribute('data-state')))) return true;
    const checkedDescendant = node.querySelector && node.querySelector('input:checked,[aria-checked="true"],[aria-selected="true"],[aria-pressed="true"]');
    return !!checkedDescendant;
  };
  const readSelectProductChoiceState = (questionText, choices, namePattern) => {
    const namedRadios = Array.from(document.querySelectorAll('input[type=radio],input'))
      .filter((el) => namePattern.test(`${safe(el.name)} ${safe(el.id)}`));
    const questionContainers = findQuestionContainers(questionText);
    const controls = {};
    for (const choice of choices) {
      controls[choice.key] = namedRadios.find((el) => {
        const evidence = `${safe(el.value)} ${readInputLabel(el)} ${safe(el.id)}`;
        return answerValueMatches(evidence, choice.value) || answerTextMatches(evidence, choice.text);
      }) || null;
    }
    let detectionMethod = namedRadios.length ? 'name-radio' : '';
    let controlType = namedRadios.length ? 'radio' : '';
    for (const container of questionContainers) {
      const nodes = Array.from(container.querySelectorAll('input[type=radio],button,a,[role=button],[role=radio],label,span,div'))
        .filter((node) => visible(node) && node !== container)
        .map((node) => ({ node, text: getText(node) || safe(node.value) || safe(node.getAttribute && node.getAttribute('aria-label')) }))
        .filter(({ text }) => text && text.length <= 40);
      for (const choice of choices) {
        if (controls[choice.key])
          continue;
        const found = nodes.find(({ text }) => answerTextMatches(text, choice.text));
        if (found)
          controls[choice.key] = found.node;
      }
      if (choices.some((choice) => controls[choice.key])) {
        if (!detectionMethod) detectionMethod = 'question-scoped-semantic';
        if (!controlType) controlType = choices.some((choice) => controls[choice.key] && /INPUT/i.test(safe(controls[choice.key].tagName))) ? 'radio' : 'custom';
        break;
      }
    }
    const body = bodyText();
    const questionPresent = body.includes(lower(questionText)) || namedRadios.length > 0 || questionContainers.length > 0;
    let selectedChoice = null;
    for (const choice of choices) {
      if (selectProductControlSelected(controls[choice.key])) {
        selectedChoice = choice;
        break;
      }
    }
    const alertRequired = body.includes(lower(questionText)) && body.includes('this is required');
    const required = questionPresent && (alertRequired || true);
    return {
      questionPresent,
      controls,
      answered: !!selectedChoice,
      value: selectedChoice ? selectedChoice.value : '',
      label: selectedChoice ? selectedChoice.text : '',
      required,
      controlType: controlType || (questionPresent ? 'text' : ''),
      detectionMethod: detectionMethod || (questionPresent ? 'question-text' : ''),
      alertRequired
    };
  };
  const readSelectProductInsuredState = (questionText) => {
    const state = readSelectProductChoiceState(questionText, [
      { key: 'yes', value: 'YES', text: 'Yes' },
      { key: 'no', value: 'NO', text: 'No' }
    ], /CustomerCurrentInsured|currentInsured|currentlyInsured/i);
    return {
      ...state,
      yesControl: state.controls.yes || null,
      noControl: state.controls.no || null,
      yesPresent: !!state.controls.yes,
      noPresent: !!state.controls.no,
      yesSelected: selectProductControlSelected(state.controls.yes),
      noSelected: selectProductControlSelected(state.controls.no)
    };
  };
  const readSelectProductOwnRentState = (questionText) => {
    const state = readSelectProductChoiceState(questionText, [
      { key: 'own', value: 'OWN', text: 'Own' },
      { key: 'rent', value: 'RENT', text: 'Rent' }
    ], /CustomerOwnOrRent|ownOrRent|ownRent|rentOwn/i);
    return {
      ...state,
      ownControl: state.controls.own || null,
      rentControl: state.controls.rent || null,
      ownPresent: !!state.controls.own,
      rentPresent: !!state.controls.rent,
      ownSelected: selectProductControlSelected(state.controls.own),
      rentSelected: selectProductControlSelected(state.controls.rent)
    };
  };
  const selectProductOwnRentAnswerText = (value) => {
    const normalized = normUpper(value);
    if (normalized === 'OWN' || normalized === 'OWNER' || normalized === 'OWNED') return 'Own';
    if (normalized === 'RENT' || normalized === 'RENTER' || normalized === 'RENTED') return 'Rent';
    return safe(value || 'Own');
  };
  const selectProductMissingCode = (field) => {
    switch (field) {
      case 'ratingState':
      case 'ratingStateSelected':
        return 'SELECT_PRODUCT_MISSING_RATING_STATE';
      case 'product':
      case 'autoProduct':
        return 'SELECT_PRODUCT_MISSING_PRODUCT';
      case 'effectiveDate':
        return 'SELECT_PRODUCT_MISSING_EFFECTIVE_DATE';
      case 'currentAddress':
        return 'SELECT_PRODUCT_MISSING_CURRENT_ADDRESS';
      case 'currentlyInsured':
        return 'SELECT_PRODUCT_MISSING_CURRENTLY_INSURED';
      case 'ownRent':
        return 'SELECT_PRODUCT_MISSING_OWN_RENT';
      case 'continue':
        return 'SELECT_PRODUCT_MISSING_CONTINUE';
      case 'continueEnabled':
        return 'SELECT_PRODUCT_CONTINUE_DISABLED';
      default:
        return `SELECT_PRODUCT_MISSING_${normUpper(field || 'FIELD')}`;
    }
  };
  const selectProductCoreMissing = (status) => {
    const missing = [];
    if (status.ratingStatePresent !== '1') missing.push(selectProductMissingCode('ratingState'));
    else if (status.ratingStateSelected !== '1') missing.push(selectProductMissingCode('ratingStateSelected'));
    if (status.productPresent !== '1') missing.push(selectProductMissingCode('product'));
    else if (status.autoSelected !== '1') missing.push(selectProductMissingCode('autoProduct'));
    if (status.effectiveDatePresent !== '1' || status.effectiveDateFilled !== '1') missing.push(selectProductMissingCode('effectiveDate'));
    if (status.currentAddressPresent !== '1' || status.currentAddressSelected !== '1') missing.push(selectProductMissingCode('currentAddress'));
    if (status.insuredQuestionPresent === '1' && status.insuredQuestionRequired === '1' && status.insuredQuestionAnswered !== '1') missing.push(selectProductMissingCode('currentlyInsured'));
    if (status.ownRentQuestionPresent === '1' && status.ownRentQuestionRequired === '1' && status.ownOrRentSelected !== '1') missing.push(selectProductMissingCode('ownRent'));
    if (status.continuePresent !== '1') missing.push(selectProductMissingCode('continue'));
    else if (status.continueEnabled !== '1') missing.push(selectProductMissingCode('continueEnabled'));
    return missing;
  };
  const selectProductCustomControlAmbiguous = (status) => (
    status.insuredQuestionPresent === '1'
    && status.insuredQuestionRequired === '1'
    && status.insuredQuestionAnswered !== '1'
  ) ? '1' : '0';
  const buildSelectProductStatus = (source = {}) => {
    const selectors = getSelectorArgs(source);
    const questionText = safe(source.currentInsuredQuestionText || 'Is the customer currently insured?');
    const ratingSelect = findByStableId(source.selectProductRatingStateId || selectors.selectProductRatingStateId || 'SelectProduct.RatingState');
    const productSelect = findByStableId(source.selectProductProductId || selectors.selectProductProductId || 'SelectProduct.Product');
    const continueBtn = findSelectProductContinueButton(source);
    const ratingState = readSelectState(ratingSelect);
    const product = readSelectState(productSelect);
    const insuredState = readSelectProductInsuredState(questionText);
    const currentInsured = { value: insuredState.value, selected: insuredState.answered, source: insuredState.detectionMethod };
    const currentInsuredAlert = insuredState.alertRequired;
    const ownRentQuestionText = safe(source.ownRentQuestionText || 'Does the customer own or rent?');
    const ownOrRentState = readSelectProductOwnRentState(ownRentQuestionText);
    const effectiveDate = findEffectiveDateInput();
    const currentAddress = readCurrentAddressState();
    const status = {
      result: 'SELECT_PRODUCT_REQUIRED_FIELDS_MISSING',
      routeFamily: selectProductRouteFamily(source),
      ratingStatePresent: ratingSelect ? '1' : '0',
      ratingStateSelected: ratingState.value || ratingState.text ? '1' : '0',
      ratingStateValue: ratingState.value,
      ratingStateText: ratingState.text,
      productPresent: productSelect ? '1' : '0',
      productSelected: product.value || product.text ? '1' : '0',
      productValue: product.value,
      productText: product.text,
      autoSelected: (matchesNormalizedValue(product.value, 'AUTO') || matchesNormalizedValue(product.text, 'AUTO')) ? '1' : '0',
      effectiveDatePresent: effectiveDate ? '1' : '0',
      effectiveDateFilled: effectiveDate && safe(effectiveDate.value).trim() ? '1' : '0',
      currentAddressPresent: currentAddress.present ? '1' : '0',
      currentAddressSelected: currentAddress.selected ? '1' : '0',
      currentAddressValue: currentAddress.value || '',
      currentAddressText: currentAddress.text || '',
      currentAddressSource: currentAddress.source || '',
      currentAddressSelectedIndex: currentAddress.selectedIndex || '',
      insuredQuestionPresent: insuredState.questionPresent ? '1' : '0',
      insuredYesPresent: insuredState.yesPresent ? '1' : '0',
      insuredNoPresent: insuredState.noPresent ? '1' : '0',
      insuredYesSelected: insuredState.yesSelected ? '1' : '0',
      insuredNoSelected: insuredState.noSelected ? '1' : '0',
      insuredQuestionAnswered: insuredState.answered ? '1' : '0',
      insuredQuestionRequired: insuredState.required ? '1' : '0',
      insuredControlType: insuredState.controlType,
      insuredDetectionMethod: insuredState.detectionMethod,
      currentInsuredValue: currentInsured.value,
      currentInsuredSelected: currentInsured.selected ? '1' : '0',
      currentInsuredSource: currentInsured.source,
      currentInsuredAlert: currentInsuredAlert ? '1' : '0',
      ownRentQuestionPresent: ownOrRentState.questionPresent ? '1' : '0',
      ownRentQuestionRequired: ownOrRentState.required ? '1' : '0',
      ownRentOwnPresent: ownOrRentState.ownPresent ? '1' : '0',
      ownRentRentPresent: ownOrRentState.rentPresent ? '1' : '0',
      ownRentOwnSelected: ownOrRentState.ownSelected ? '1' : '0',
      ownRentRentSelected: ownOrRentState.rentSelected ? '1' : '0',
      ownOrRentValue: ownOrRentState.label || ownOrRentState.value,
      ownOrRentSelected: ownOrRentState.answered ? '1' : '0',
      ownOrRentSource: ownOrRentState.detectionMethod,
      alerts: collectVisibleAlerts().join(' || '),
      continuePresent: continueBtn ? '1' : '0',
      continueEnabled: continueBtn && !isDisabledLike(continueBtn) ? '1' : '0',
      missing: ''
    };
    const missing = selectProductCoreMissing(status);
    status.missing = missing.join('|');
    status.coreReady = missing.length ? '0' : '1';
    status.customControlAmbiguous = selectProductCustomControlAmbiguous(status);
    status.readinessTrace = status.coreReady === '1' && status.continueEnabled === '1'
      ? 'SELECT_PRODUCT_CONTINUE_ENABLED_CORE_READY'
      : '';
    if (status.routeFamily !== 'intel-select-product') status.result = 'NOT_SELECT_PRODUCT';
    else if (status.continuePresent === '1' && status.continueEnabled !== '1') status.result = 'SELECT_PRODUCT_CONTINUE_DISABLED';
    else if (missing.length) status.result = missing[0] || 'SELECT_PRODUCT_CORE_REQUIRED_FIELDS_MISSING';
    else status.result = 'READY';
    return status;
  };
  const extractStreetNumber = (value) => ((normalizeAddressText(value).match(/^\d+/) || [])[0]) || '';
  const hasWholeNormalizedToken = (haystack, token) => {
    const text = normalizeAddressText(haystack);
    const wanted = normalizeAddressText(token);
    return !!wanted && new RegExp(`(^|\\s)${wanted}(\\s|$)`).test(text);
  };
  const buildDuplicateCandidate = (radio, source = {}) => {
    const container = radio.closest('.sfmOption,.l-tile,[role=row],div') || radio.parentElement;
    const containerIsBody = container && safe(container.tagName) === 'BODY';
    const summaryText = containerIsBody ? '' : (getText(container) || getText(radio.parentElement));
    const text = normalizeAddressText(summaryText);
    if (!text) return null;
    const firstName = normalizeAddressText(source.firstName);
    const lastName = normalizeAddressText(source.lastName);
    const street = normalizeAddressText(source.street);
    const city = normalizeAddressText(source.city);
    const state = normalizeAddressText(source.state);
    const zip = normalizeAddressText(source.zip);
    const streetNumber = extractStreetNumber(source.street);
    const dob = normalizeDobKey(source.dob);
    const phone = normalizePhoneKey(source.phone);
    const email = normalizeEmailKey(source.email);
    const firstNameMatch = !!firstName && hasWholeNormalizedToken(text, firstName);
    const lastNameMatch = !!lastName && hasWholeNormalizedToken(text, lastName);
    const streetTokens = street.split(' ')
      .filter((token) => token && token !== streetNumber && !/^(N|S|E|W|NE|NW|SE|SW|ST|STREET|AVE|AVENUE|RD|ROAD|DR|DRIVE|LN|LANE|BLVD|BOULEVARD|CT|COURT|PL|PLACE|PKWY|PARKWAY|WAY|CIR|CIRCLE|TER|TERRACE)$/i.test(token));
    const streetNameMatch = streetTokens.length
      ? streetTokens.every((token) => hasWholeNormalizedToken(text, token))
      : (!!street && text.includes(street));
    const addressMatch = (!!street || !!zip || !!city || !!state)
      && (!streetNumber || hasWholeNormalizedToken(text, streetNumber))
      && (!street || streetNameMatch)
      && (!zip || text.includes(zip))
      && (!city || text.includes(city))
      && (!state || hasWholeNormalizedToken(text, state));
    const dobMatch = !!dob && normalizeDobKey(summaryText).includes(dob);
    const phoneMatch = !!phone && normalizePhoneKey(summaryText).includes(phone);
    const emailMatch = !!email && normalizeEmailKey(summaryText).includes(email);
    const sameNamedPerson = firstNameMatch && lastNameMatch;
    const optionType = /CREATE\s+NEW\s+PROFILE|CREATE\s+NEW\s+profile|USING\s+DATA\s+YOU\s+ENTERED/i.test(summaryText)
      ? 'create-new-profile'
      : (/EXISTING\s+PROFILE|EXISTING\s+profile/i.test(summaryText) ? 'existing-profile' : 'unknown');
    const strongAddressIdentity = sameNamedPerson && addressMatch;
    const strongIdentity = sameNamedPerson && (addressMatch || dobMatch || phoneMatch || emailMatch);
    let score = 0;
    if (strongAddressIdentity) score += 100;
    if (dobMatch) score += 90;
    if (phoneMatch) score += 90;
    if (emailMatch) score += 90;
    if (addressMatch) score += 20;
    if (lastNameMatch) score += 10;
    if (firstNameMatch) score += 10;
    return {
      radio,
      container,
      summary: compact(summaryText, 140),
      score,
      strongIdentity,
      sameNamedPerson,
      optionType,
      firstNameMatch,
      lastNameMatch,
      addressMatch,
      dobMatch,
      phoneMatch,
      emailMatch
    };
  };
  const duplicateCandidatesAreAmbiguous = (candidates = []) => {
    if (candidates.length < 2) return false;
    return (candidates[0].score - candidates[1].score) <= 15;
  };
  const findDuplicateContinueButton = () => Array.from(document.querySelectorAll('button,a,input[type=button],input[type=submit]'))
    .filter(visible)
    .find((el) => /continue|use existing|use selected/i.test(safe(el.innerText || el.textContent || el.value).trim())) || null;
  const findCreateNewProspectButton = () => Array.from(document.querySelectorAll('button,a,input[type=button],input[type=submit]'))
    .filter(visible)
    .find((el) => {
      const text = normUpper(safe(el.innerText || el.textContent || el.value).trim());
      return text.includes('CREATE NEW PROSPECT') || text.includes('CREATE NEW') || text.includes('NEW PROSPECT');
    }) || null;
  const duplicateOptionCandidate = (radio, optionType, summary = '') => {
    if (!radio) return null;
    const container = radio.closest('.sfmOption,.l-tile,[role=row],div') || radio.parentElement || radio;
    return {
      radio,
      container,
      summary: compact(summary || getText(container) || getText(radio.parentElement) || '', 140),
      optionType,
      score: 0,
      strongIdentity: false,
      sameNamedPerson: false,
      firstNameMatch: false,
      lastNameMatch: false,
      addressMatch: false,
      dobMatch: false,
      phoneMatch: false,
      emailMatch: false
    };
  };
  const duplicatePageHasCreateNewProfileText = () => includesText(bodyText(), 'Create NEW profile using data you entered');
  const duplicatePageHasExistingProfileText = () => includesText(bodyText(), 'Use EXISTING profile found');
  const findCreateNewDuplicateOption = (allCandidates = [], radios = []) => {
    const byRowText = allCandidates.find((candidate) => candidate.optionType === 'create-new-profile');
    if (byRowText) return byRowText;
    const sfmRadios = radios.filter((radio) => safe(radio.name) === 'sfmOption');
    if (sfmRadios.length === 2 && duplicatePageHasExistingProfileText() && duplicatePageHasCreateNewProfileText()) {
      const valueZero = sfmRadios.find((radio) => safe(radio.value) === '0');
      return duplicateOptionCandidate(valueZero || sfmRadios[1], 'create-new-profile', 'Create NEW profile using data you entered');
    }
    return null;
  };
  const setDuplicateRadioChecked = (radio) => {
    if (!radio || isDisabledLike(radio)) return false;
    try {
      Array.from(document.querySelectorAll('input[type=radio]')).forEach((other) => {
        if (other !== radio && safe(other.name) === safe(radio.name))
          other.checked = false;
      });
    } catch {}
    try { radio.checked = true; } catch {}
    try { radio.dispatchEvent(new Event('input', { bubbles: true })); } catch {}
    try { radio.dispatchEvent(new Event('change', { bubbles: true })); } catch {}
    return radio.checked === true;
  };
  const selectDuplicateRadio = (candidate) => {
    if (!candidate || !candidate.radio) return { selected: false, radioSelected: false };
    const target = getInputClickTarget(candidate.radio) || candidate.radio;
    let clicked = clickCenterEl(target);
    if (!(candidate.radio.checked || isSelectedNode(candidate.radio) || isSelectedNode(candidate.container)))
      clicked = clickCenterEl(candidate.radio) || clicked;
    if (!(candidate.radio.checked || isSelectedNode(candidate.radio) || isSelectedNode(candidate.container)))
      setDuplicateRadioChecked(candidate.radio);
    const radioSelected = candidate.radio.checked === true;
    return {
      clicked,
      selected: radioSelected || isSelectedNode(candidate.radio) || isSelectedNode(candidate.container),
      radioSelected
    };
  };
  const readDuplicateContinueState = () => {
    const button = findDuplicateContinueButton();
    return {
      button,
      present: button ? '1' : '0',
      enabled: button && !isDisabledLike(button) ? '1' : '0'
    };
  };
  const waitForDuplicateContinueEnabled = (timeoutMs = 700) => {
    const start = Date.now();
    let state = readDuplicateContinueState();
    while (state.present === '1' && state.enabled !== '1' && (Date.now() - start) < timeoutMs)
      state = readDuplicateContinueState();
    return state;
  };
  const selectDuplicateRadioAndContinue = (candidate, method, extra = {}) => {
    const selection = selectDuplicateRadio(candidate);
    const radioValue = candidate && candidate.radio ? safe(candidate.radio.value) : '';
    const selected = selection.selected;
    if (!selected) {
      return lineResult(Object.assign({
        result: 'FAILED',
        method: method === 'create-new-radio' ? 'create-new-radio-target-missing' : `${method}-click-failed`,
        candidateCount: '1',
        rowCount: '1',
        candidateSummaries: candidate.summary,
        radioValue,
        radioSelected: selection.radioSelected ? '1' : '0',
        failedFields: ['duplicateSelection']
      }, extra));
    }
    const continueState = waitForDuplicateContinueEnabled();
    if (continueState.button && continueState.enabled === '1' && clickCenterEl(continueState.button)) {
      return lineResult(Object.assign({
        result: method === 'select-existing-radio' ? 'SELECT_EXISTING' : 'CREATE_NEW',
        method,
        candidateSummaries: candidate.summary,
        radioValue,
        radioSelected: '1',
        continueButtonPresent: continueState.present,
        continueButtonEnabled: continueState.enabled,
        continueClicked: '1'
      }, extra));
    }
    if (method === 'select-existing-radio') {
      return lineResult(Object.assign({
        result: 'SELECTED_NO_CONTINUE',
        method: 'select-existing-no-continue',
        candidateSummaries: candidate.summary,
        radioValue,
        radioSelected: '1',
        continueButtonPresent: continueState.present,
        continueButtonEnabled: continueState.enabled,
        continueClicked: '0'
      }, extra));
    }
    return lineResult(Object.assign({
      result: 'FAILED',
      method: 'create-new-radio-continue-disabled',
      candidateSummaries: candidate.summary,
      radioValue,
      radioSelected: '1',
      continueButtonPresent: continueState.present,
      continueButtonEnabled: continueState.enabled,
      continueClicked: '0',
      failedFields: ['continueWithSelected']
    }, extra));
  };

  const addressVerificationRawText = () => safe(document.body ? (document.body.innerText || document.body.textContent) : '').replace(/\s+/g, ' ').trim();
  const addressVerificationEvidence = () => {
    const text = addressVerificationRawText();
    const radios = Array.from(document.querySelectorAll('input[name="snaOption"]')).filter(visible);
    const continueButton = findAddressVerificationContinueButton();
    return {
      hasHeading: /Address Verification/i.test(text),
      hasEntered: /You Entered/i.test(text),
      hasSuggestions: /Did You Mean/i.test(text),
      radioCount: radios.length,
      continueButton,
      found: /Address Verification/i.test(text) && /You Entered/i.test(text) && /Did You Mean/i.test(text) && radios.length > 0 && !!continueButton
    };
  };
  const isAddressVerificationPage = () => addressVerificationEvidence().found;
  const findAddressVerificationContinueButton = () => Array.from(document.querySelectorAll('button,input,a,[role=button]'))
    .filter(visible)
    .find((el) => includesText(lower(el.innerText || el.textContent || el.value || el.getAttribute('aria-label')), 'Continue with Selected')) || null;
  const addressVerificationFallbackText = () => {
    const text = addressVerificationRawText();
    const enteredMatch = text.match(/You Entered\s+(.+?)\s+Did You Mean\??/i);
    const suggestionMatch = text.match(/Did You Mean\??\s+(.+?)\s+Continue with Selected/i);
    const suggestionChunk = suggestionMatch ? suggestionMatch[1] : '';
    const suggestions = [];
    const addressPattern = /\d{1,6}\s+.*?\b[A-Z]{2}\s+\d{5}(?:-\d{4})?/gi;
    let match;
    while ((match = addressPattern.exec(suggestionChunk)) !== null) {
      const suggestion = safe(match[0]).replace(/\s+/g, ' ').trim();
      if (suggestion) suggestions.push(suggestion);
    }
    return {
      entered: enteredMatch ? safe(enteredMatch[1]).replace(/\s+/g, ' ').trim() : '',
      suggestions
    };
  };
  const cleanAddressVerificationOptionText = (text) => safe(text)
    .replace(/\bAddress Verification\b/ig, ' ')
    .replace(/\bYou Entered\b/ig, ' ')
    .replace(/\bDid You Mean\??\b/ig, ' ')
    .replace(/\bContinue with Selected\b/ig, ' ')
    .replace(/\s+/g, ' ')
    .trim();
  const addressVerificationOptionContainer = (radio) => {
    if (!radio) return null;
    const candidates = [];
    let cur = radio.parentElement;
    for (let depth = 0; cur && depth < 5; depth += 1, cur = cur.parentElement)
      candidates.push(cur);
    const scored = candidates.map((el) => {
      const text = safe(el && (el.innerText || el.textContent));
      const broad = /Address Verification/i.test(text) && /You Entered/i.test(text) && /Did You Mean/i.test(text);
      return {
        el,
        text,
        score: (text ? 10 : 0) - (broad ? 100 : 0) - Math.max(0, text.length - 220)
      };
    }).filter((item) => item.el && item.text);
    scored.sort((a, b) => b.score - a.score);
    return (scored[0] && scored[0].score > -50) ? scored[0].el : (getInputClickTarget(radio) || radio.parentElement || radio);
  };
  const collectAddressVerificationOptions = () => {
    const radios = Array.from(document.querySelectorAll('input[name="snaOption"]')).filter(visible);
    const fallback = addressVerificationFallbackText();
    const seenTexts = new Map();
    const initial = radios.map((radio, index) => {
      const container = addressVerificationOptionContainer(radio);
      const value = safe(radio.value);
      const numeric = Number(value);
      const kind = value === '0' || index === 0 ? 'entered' : 'suggestion';
      const rawText = safe(container && (container.innerText || container.textContent));
      const broad = /Address Verification/i.test(rawText) && /You Entered/i.test(rawText) && /Did You Mean/i.test(rawText);
      let text = broad ? '' : cleanAddressVerificationOptionText(rawText);
      if (!text) {
        if (kind === 'entered') text = fallback.entered;
        else text = fallback.suggestions[Math.max(0, Number.isFinite(numeric) ? numeric - 1 : index - 1)] || fallback.suggestions[index - 1] || '';
      }
      return { radio, container, index, value, kind, text: safe(text).replace(/\s+/g, ' ').trim() };
    });
    for (const option of initial) {
      const key = option.text.toLowerCase();
      seenTexts.set(key, (seenTexts.get(key) || 0) + 1);
    }
    return initial.map((option) => {
      if (option.text && seenTexts.get(option.text.toLowerCase()) === 1) return option;
      if (option.kind === 'entered' && fallback.entered) option.text = fallback.entered;
      if (option.kind === 'suggestion') {
        const numeric = Number(option.value);
        option.text = fallback.suggestions[Math.max(0, Number.isFinite(numeric) ? numeric - 1 : option.index - 1)] || fallback.suggestions[option.index - 1] || option.text;
      }
      return option;
    });
  };
  const addressSuffixMap = {
    STREET: 'ST', ST: 'ST',
    COURT: 'CT', CT: 'CT',
    AVENUE: 'AVE', AVE: 'AVE', AV: 'AVE',
    DRIVE: 'DR', DR: 'DR',
    ROAD: 'RD', RD: 'RD',
    TERRACE: 'TER', TER: 'TER',
    BOULEVARD: 'BLVD', BLVD: 'BLVD',
    WAY: 'WAY',
    PLACE: 'PL', PL: 'PL',
    PARKWAY: 'PKWY', PKWY: 'PKWY',
    LANE: 'LN', LN: 'LN',
    CIRCLE: 'CIR', CIR: 'CIR',
    HIGHWAY: 'HWY', HWY: 'HWY'
  };
  const addressDirections = new Set(['N', 'S', 'E', 'W', 'NE', 'NW', 'SE', 'SW']);
  const addressStateTokens = new Set('AL AK AZ AR CA CO CT DE FL GA HI IA ID IL IN KS KY LA MA MD ME MI MN MO MS MT NC ND NE NH NJ NM NV NY OH OK OR PA RI SC SD TN TX UT VA VT WA WI WV WY DC'.split(' '));
  const normalizeAddressWord = (word) => safe(word).toUpperCase().replace(/[^A-Z0-9#]/g, '');
  const parseAddressForVerification = (raw, fallback = {}) => {
    const text = safe(raw);
    const norm = normUpper(text);
    const tokens = norm.split(/\s+/).map(normalizeAddressWord).filter(Boolean);
    const zipMatch = text.match(/\b(\d{5})(?:-(\d{4}))?\b/) || norm.match(/\b(\d{5})(?:\s+(\d{4}))?\b/);
    const numberIndex = tokens.findIndex((token) => /^\d{1,6}$/.test(token));
    const number = numberIndex >= 0 ? tokens[numberIndex] : '';
    let cursor = numberIndex >= 0 ? numberIndex + 1 : 0;
    const direction = addressDirections.has(tokens[cursor]) ? tokens[cursor++] : '';
    let suffixIndex = -1;
    for (let i = cursor; i < tokens.length; i += 1) {
      if (addressSuffixMap[tokens[i]]) {
        suffixIndex = i;
        break;
      }
      if (addressStateTokens.has(tokens[i]) || /^\d{5}/.test(tokens[i])) break;
    }
    const streetNameTokens = suffixIndex >= 0 ? tokens.slice(cursor, suffixIndex) : tokens.slice(cursor, cursor + 1);
    const suffix = suffixIndex >= 0 ? addressSuffixMap[tokens[suffixIndex]] : '';
    let unit = safe(fallback.unit || fallback.aptSuite || '');
    const unitIndex = tokens.findIndex((token) => ['APT', 'APARTMENT', 'UNIT', 'STE', 'SUITE', '#'].includes(token));
    if (unitIndex >= 0 && tokens[unitIndex + 1]) unit = tokens[unitIndex + 1];
    return {
      raw: text,
      norm,
      number,
      direction,
      streetName: streetNameTokens.join(' '),
      suffix,
      city: normUpper(fallback.city || ''),
      state: normUpper(fallback.state || ''),
      zip5: zipMatch ? zipMatch[1] : safe(fallback.zip || '').match(/\d{5}/)?.[0] || '',
      zip4: zipMatch ? safe(zipMatch[2]) : '',
      unit: normalizeAddressWord(unit)
    };
  };
  const buildLeadAddressForVerification = (args) => {
    const street = safe(args.street || args.addressLine || args.address || args.ADDRESS_1);
    const unit = safe(args.unit || args.aptSuite || args.apartment || args.APT_SUITE);
    const city = safe(args.city || args.CITY);
    const state = safe(args.state || args.STATE);
    const zip = safe(args.zip || args.ZIP);
    return parseAddressForVerification([street, unit, city, state, zip].filter(Boolean).join(' '), { unit, city, state, zip });
  };
  const optionHasLeadText = (optionNorm, value) => {
    const wanted = normUpper(value);
    return !wanted || optionNorm.includes(wanted);
  };
  const scoreAddressVerificationOption = (option, lead) => {
    const parts = parseAddressForVerification(option.text);
    const optionNorm = normUpper(option.text);
    let score = 0;
    const matchedBy = [];
    const reject = (reason) => ({ option, parts, safe: false, rejectedReason: reason, score: -999, matchedBy: [reason].join(',') });
    if (lead.number && parts.number !== lead.number) return reject('streetNumberMismatch');
    if (lead.streetName && parts.streetName !== lead.streetName) return reject('streetNameMismatch');
    if (lead.suffix && parts.suffix && parts.suffix !== lead.suffix) return reject('suffixMismatch');
    if (lead.zip5 && parts.zip5 && parts.zip5 !== lead.zip5) return reject('zipMismatch');
    if (lead.number && parts.number === lead.number) { score += 40; matchedBy.push('streetNumber'); }
    if (lead.streetName && parts.streetName === lead.streetName) { score += 40; matchedBy.push('streetName'); }
    if (lead.direction && parts.direction === lead.direction) { score += 10; matchedBy.push('direction'); }
    if (lead.suffix && parts.suffix === lead.suffix) { score += 35; matchedBy.push('suffix'); }
    if (lead.suffix && !parts.suffix) { score -= 35; matchedBy.push('missingSuffix'); }
    if (optionHasLeadText(optionNorm, lead.city)) { score += 15; matchedBy.push('city'); }
    else if (lead.city) return reject('cityMismatch');
    if (optionHasLeadText(optionNorm, lead.state)) { score += 15; matchedBy.push('state'); }
    else if (lead.state) return reject('stateMismatch');
    if (lead.zip5 && parts.zip5 === lead.zip5) { score += 15; matchedBy.push('zip5'); }
    if (option.kind === 'suggestion' && parts.zip4 && (!lead.zip5 || parts.zip5 === lead.zip5)) { score += 4; matchedBy.push('zip4'); }
    if (option.kind === 'suggestion') { score += 3; matchedBy.push('suggestedStandardized'); }
    let unitDroppedOrNotShown = '0';
    if (lead.unit) {
      if (parts.unit && parts.unit === lead.unit) { score += 12; matchedBy.push('unit'); }
      else if (parts.unit && parts.unit !== lead.unit) return reject('unitMismatch');
      else { unitDroppedOrNotShown = '1'; matchedBy.push('unitDroppedOrNotShown'); }
    }
    const suffixOk = !lead.suffix || parts.suffix === lead.suffix;
    const safeMatch = !!(lead.number && parts.number === lead.number && lead.streetName && parts.streetName === lead.streetName && suffixOk
      && optionHasLeadText(optionNorm, lead.city) && optionHasLeadText(optionNorm, lead.state)
      && (!lead.zip5 || !parts.zip5 || parts.zip5 === lead.zip5));
    return {
      option,
      parts,
      safe: safeMatch,
      score,
      matchedBy: matchedBy.join(','),
      unitDroppedOrNotShown,
      rejectedReason: safeMatch ? '' : 'insufficientMatch'
    };
  };
  const chooseAddressVerificationOption = (args) => {
    const options = collectAddressVerificationOptions().filter((option) => option.radio);
    const lead = buildLeadAddressForVerification(args);
    const scored = options.map((option) => scoreAddressVerificationOption(option, lead));
    const safeSuggestions = scored.filter((item) => item.safe && item.option.kind === 'suggestion').sort((a, b) => b.score - a.score);
    const safeEntered = scored.filter((item) => item.safe && item.option.kind === 'entered').sort((a, b) => b.score - a.score);
    const safePool = safeSuggestions.length ? safeSuggestions : safeEntered;
    if (!safePool.length) {
      return {
        result: 'FAILED',
        method: 'address-match-no-safe-option',
        options,
        scored,
        selected: null,
        failedFields: ['addressMatch']
      };
    }
    const top = safePool[0];
    const tied = safePool.filter((item) => item.score === top.score);
    if (tied.length > 1) {
      return {
        result: 'AMBIGUOUS',
        method: 'address-match-ambiguous',
        options,
        scored,
        selected: top,
        failedFields: ['ambiguousAddress']
      };
    }
    return {
      result: 'SELECTED',
      method: top.option.kind === 'suggestion' ? 'suggested-address-radio' : 'you-entered-radio',
      options,
      scored,
      selected: top,
      failedFields: []
    };
  };
  const setAddressVerificationRadioChecked = (radio) => {
    if (!radio || isDisabledLike(radio)) return false;
    try {
      Array.from(document.querySelectorAll('input[name="snaOption"]')).forEach((other) => {
        if (other !== radio) other.checked = false;
      });
    } catch {}
    try { radio.checked = true; } catch {}
    try { radio.dispatchEvent(new Event('input', { bubbles: true })); } catch {}
    try { radio.dispatchEvent(new Event('change', { bubbles: true })); } catch {}
    return radio.checked === true;
  };
  const selectAddressVerificationRadio = (option) => {
    if (!option || !option.radio) return { selected: false, radioSelected: false };
    const clickTarget = option.container || getInputClickTarget(option.radio) || option.radio;
    let clicked = clickCenterEl(clickTarget);
    if (!option.radio.checked) clicked = clickCenterEl(option.radio) || clicked;
    if (!option.radio.checked) setAddressVerificationRadioChecked(option.radio);
    return {
      clicked,
      selected: option.radio.checked === true || isSelectedNode(option.container),
      radioSelected: option.radio.checked === true
    };
  };
  const readAddressVerificationContinueState = () => {
    const button = findAddressVerificationContinueButton();
    return {
      button,
      present: button ? '1' : '0',
      enabled: button && !isDisabledLike(button) ? '1' : '0'
    };
  };
  const waitForAddressVerificationContinueEnabled = (timeoutMs = 700) => {
    const start = Date.now();
    let state = readAddressVerificationContinueState();
    while (state.present === '1' && state.enabled !== '1' && (Date.now() - start) < timeoutMs)
      state = readAddressVerificationContinueState();
    return state;
  };
  const addressVerificationStatusFields = () => {
    const evidence = addressVerificationEvidence();
    const options = collectAddressVerificationOptions();
    const entered = (options.find((option) => option.kind === 'entered') || {}).text || '';
    const suggestions = options.filter((option) => option.kind === 'suggestion').map((option) => `${option.value}:${option.text}`).join(' || ');
    const selected = options.find((option) => option.radio && option.radio.checked);
    const missing = [];
    if (!evidence.hasHeading) missing.push('heading');
    if (!evidence.hasEntered) missing.push('youEntered');
    if (!evidence.hasSuggestions) missing.push('didYouMean');
    if (!evidence.radioCount) missing.push('snaOption');
    if (!evidence.continueButton) missing.push('continueWithSelected');
    return {
      result: evidence.found ? 'FOUND' : 'NOT_FOUND',
      modalPresent: evidence.found ? '1' : '0',
      radioCount: String(evidence.radioCount),
      continuePresent: evidence.continueButton ? '1' : '0',
      continueEnabled: evidence.continueButton && !isDisabledLike(evidence.continueButton) ? '1' : '0',
      enteredText: entered,
      suggestionCount: String(options.filter((option) => option.kind === 'suggestion').length),
      suggestions,
      selectedValue: selected ? safe(selected.value) : '',
      evidence: [evidence.hasHeading ? 'heading' : '', evidence.hasEntered ? 'youEntered' : '', evidence.hasSuggestions ? 'didYouMean' : '', evidence.radioCount ? 'snaOption' : '', evidence.continueButton ? 'continueWithSelected' : ''].filter(Boolean).join(','),
      missing,
      url: pageUrl()
    };
  };
  const vehicleFieldId = (index, fieldName) => `ConsumerData.Assets.Vehicles[${index}].${fieldName}`;
  const vehicleField = (index, fieldName) => document.getElementById(vehicleFieldId(index, fieldName));
  const vehicleRowIndexes = () => {
    const ids = new Set();
    for (const el of document.querySelectorAll('input[id],select[id]')) {
      if (!safe(el.id).includes('ConsumerData.Assets.Vehicles[')) continue;
      const m = safe(el.id).match(/ConsumerData\.Assets\.Vehicles\[(\d+)\]/);
      if (m) ids.add(Number(m[1]));
    }
    return Array.from(ids).sort((a, b) => a - b);
  };
  const readVehicleRow = (index) => {
    const vehicleType = vehicleField(index, 'VehTypeCd');
    const year = vehicleField(index, 'ModelYear');
    const vin = vehicleField(index, 'VehIdentificationNumber');
    const manufacturer = vehicleField(index, 'Manufacturer');
    const model = vehicleField(index, 'Model');
    const subModel = vehicleField(index, 'SubModel');
    return { vehicleType, year, vin, manufacturer, model, subModel };
  };
  const vehicleFieldValue = (el) => safe(el && el.value).trim();
  const vehicleFieldTextValue = (el) => {
    const value = vehicleFieldValue(el);
    if (el && el.tagName === 'SELECT') {
      const selected = Array.from(el.options || []).find((opt) => opt.selected) || (el.options && el.selectedIndex >= 0 ? el.options[el.selectedIndex] : null);
      return [value, vehicleOptionText(selected)].filter(Boolean).join(' ').trim();
    }
    return value;
  };
  const vehicleFieldReady = (el) => !!(el && visible(el) && !isDisabledLike(el) && !el.readOnly);
  const vehicleRowComplete = (row) => !!(
    vehicleFieldValue(row.year)
    && vehicleFieldValue(row.manufacturer)
    && vehicleFieldValue(row.model)
    && vehicleFieldValue(row.subModel)
  );
  const findUsableVehicleRowIndex = (wantedYear = '') => {
    const indexes = vehicleRowIndexes();
    const wanted = safe(wantedYear).trim();
    let fallback = -1;
    for (const idx of indexes) {
      const row = readVehicleRow(idx);
      if (!vehicleFieldReady(row.year)) continue;
      if (vehicleRowComplete(row)) continue;
      const rowYear = vehicleFieldValue(row.year);
      if (!rowYear || (wanted && rowYear === wanted)) return idx;
      if (fallback < 0) fallback = idx;
    }
    return fallback;
  };
  const vehicleOptionText = (opt) => safe(opt && (opt.text || opt.innerText || opt.textContent || opt.value)).trim();
  const vehicleOptionValue = (opt) => safe(opt && opt.value).trim();
  const validVehicleOption = (opt) => {
    if (!opt || opt.disabled) return false;
    const text = normUpper(vehicleOptionText(opt));
    const value = normUpper(vehicleOptionValue(opt));
    if (!text && !value) return false;
    return !['SELECT', 'SELECT ONE', 'PLEASE SELECT', 'CHOOSE', 'CHOOSE ONE'].includes(text);
  };
  const gatherAddRowSubModelPlaceholderTexts = new Set(['', 'SELECT', 'SELECT ONE', 'PLEASE SELECT', 'CHOOSE', 'CHOOSE ONE', 'UNKNOWN', 'NOT FOUND', 'OTHER', 'MAKE NOT FOUND']);
  const gatherAddRowSubModelOptionValid = (opt, index = -1) => {
    if (!opt || opt.disabled || index === 0) return false;
    const text = normUpper(vehicleOptionText(opt));
    const value = normUpper(vehicleOptionValue(opt));
    if (!text && !value) return false;
    return !gatherAddRowSubModelPlaceholderTexts.has(text) && !gatherAddRowSubModelPlaceholderTexts.has(value);
  };
  const gatherAddRowSubModelPlaceholderSelected = (select) => {
    if (!select) return true;
    const selected = Array.from(select.options || []).find((opt) => opt.selected) || (select.options && select.selectedIndex >= 0 ? select.options[select.selectedIndex] : null);
    const text = normUpper(vehicleOptionText(selected));
    const value = normUpper(vehicleOptionValue(selected) || vehicleFieldValue(select));
    return gatherAddRowSubModelPlaceholderTexts.has(text) || gatherAddRowSubModelPlaceholderTexts.has(value);
  };
  const gatherAddRowSubModelValidOptions = (select) => Array.from((select && select.options) || [])
    .map((option, index) => ({ option, index }))
    .filter((entry) => gatherAddRowSubModelOptionValid(entry.option, entry.index));
  const firstValidNonPlaceholderVehicleOption = (select) => gatherAddRowSubModelValidOptions(select)[0] || null;
  const vehicleOptionSummary = (select, max = 12) => Array.from((select && select.options) || [])
    .filter(validVehicleOption)
    .slice(0, max)
    .map((opt) => compact(vehicleOptionText(opt), 40))
    .join('|');
  const vehicleRowMatchesExpectedContext = (row, match) => {
    if (!row || !match) return false;
    const rowYear = normalizeDigits(vehicleFieldValue(row.year));
    if (match.year && rowYear && rowYear !== normalizeDigits(match.year)) return false;
    const rowMake = normalizeVehicleText(vehicleFieldTextValue(row.manufacturer));
    if (match.make && rowMake && !vehicleMakeMatches(rowMake, match)) return false;
    const rowModel = vehicleFieldTextValue(row.model);
    if (rowModel && !/select one/i.test(rowModel) && match.model) {
      const modelMatches = match.strictModelMatch
        ? vehicleModelMatches(normalizeVehicleText(rowModel), match)
        : normalizeVehicleText(rowModel).includes(match.model);
      if (!modelMatches) return false;
    }
    return true;
  };
  const vehicleRowDetails = (row) => {
    if (!row) return '';
    return compact([
      `year=${vehicleFieldValue(row.year)}`,
      `vin=${vehicleFieldValue(row.vin)}`,
      `make=${vehicleFieldValue(row.manufacturer)}`,
      `model=${vehicleFieldValue(row.model)}`,
      `subModel=${vehicleFieldValue(row.subModel)}`
    ].join(','), 160);
  };
  const vehicleRowControls = (row) => row ? [row.vehicleType, row.year, row.vin, row.manufacturer, row.model, row.subModel].filter(Boolean) : [];
  const findVehicleRowContainer = (row) => {
    const controls = vehicleRowControls(row);
    const seed = row && (row.year || row.vehicleType || row.manufacturer || row.model || row.subModel || row.vin);
    if (!seed) return null;
    let fallback = null;
    for (let depth = 0, current = seed.parentElement; depth < 8 && current; depth++, current = current.parentElement) {
      if (!visible(current)) continue;
      if (!controls.every((control) => current.contains(control))) continue;
      const text = normLower(getText(current));
      const actions = Array.from(current.querySelectorAll('button,a,[role=button],input[type=button],input[type=submit]')).filter(visible);
      const hasCancel = actions.some((action) => answerTextMatches([getText(action), safe(action.value)].join(' '), 'Cancel'));
      const hasAdd = actions.some((action) => answerTextMatches([getText(action), safe(action.value)].join(' '), 'Add'));
      const looksLikeAddRow = text.includes('add car or truck') || text.includes('vehicle type') || hasAdd || controls.length >= 4;
      const broadVehicleSection = text.includes('confirmed vehicles') || text.includes('potential vehicles') || text.includes('start quoting');
      if (looksLikeAddRow && hasCancel) return current;
      if (looksLikeAddRow && !broadVehicleSection) {
        if (!fallback) fallback = current;
      }
    }
    return fallback;
  };
  const rowScopedButton = (container, wantedText) => {
    const wanted = safe(wantedText);
    const buttons = Array.from((container && container.querySelectorAll('button,a,[role=button],input[type=button],input[type=submit]')) || [])
      .filter((button) => visible(button) && !isDisabledLike(button))
      .filter((button) => answerTextMatches([getText(button), safe(button.value), safe(button.getAttribute('aria-label'))].join(' '), wanted));
    return buttons.length === 1 ? buttons[0] : null;
  };
  const rowScopedButtonState = (container, wantedText) => {
    const wanted = safe(wantedText);
    const buttons = Array.from((container && container.querySelectorAll('button,a,[role=button],input[type=button],input[type=submit]')) || [])
      .filter(visible)
      .filter((button) => answerTextMatches([getText(button), safe(button.value), safe(button.getAttribute('aria-label'))].join(' '), wanted));
    const enabled = buttons.filter((button) => !isDisabledLike(button));
    return {
      present: buttons.length === 1,
      enabled: enabled.length === 1,
      target: enabled.length === 1 ? enabled[0] : null
    };
  };
  const gatherVehicleAddRowState = (source = {}, matchArgs = {}) => {
    const rowIndexArg = safe(source.index).trim();
    const rowIndex = rowIndexArg !== '' && !Number.isNaN(Number(rowIndexArg)) ? Number(rowIndexArg) : findUsableVehicleRowIndex(source.year);
    const indexes = vehicleRowIndexes();
    const hasAnyRow = indexes.length > 0;
    const row = rowIndex >= 0 ? readVehicleRow(rowIndex) : null;
    const rowOpen = !!(row && (row.year || row.vin || row.manufacturer || row.model || row.subModel));
    const rowComplete = !!(row && vehicleFieldValue(row.year) && vehicleFieldValue(row.manufacturer) && vehicleFieldValue(row.model) && vehicleFieldValue(row.subModel));
    const rowIncomplete = rowOpen && !rowComplete;
    const rowGone = !rowOpen && !hasAnyRow;
    const rowMatchesExpectedContext = rowIncomplete && vehicleRowMatchesExpectedContext(row, matchArgs);
    return { rowIndex, row, hasAnyRow, rowOpen, rowComplete, rowIncomplete, rowGone, rowMatchesExpectedContext };
  };
  const findStaleAddVehicleRow = (source = {}) => {
    const allExpectedSatisfied = safe(source.allExpectedVehiclesSatisfied) === '1' || source.allExpectedVehiclesSatisfied === true;
    const indexes = vehicleRowIndexes();
    const candidates = [];
    for (const idx of indexes) {
      const row = readVehicleRow(idx);
      if (!vehicleRowControls(row).some((control) => control && visible(control))) continue;
      const state = gatherVehicleAddRowState({ index: String(idx) }, {});
      if (!state.rowOpen) continue;
      const container = findVehicleRowContainer(row);
      const rowText = compact(getText(container), 220);
      const lowerText = normLower(getText(container));
      const cancelButton = rowScopedButton(container, 'Cancel');
      const addButtonState = rowScopedButtonState(container, 'Add');
      const addButton = addButtonState.target;
      const vinValue = vehicleFieldValue(row.vin);
      const modelValue = vehicleFieldValue(row.model);
      const subModelValue = vehicleFieldValue(row.subModel);
      const subModelSelected = Array.from((row.subModel && row.subModel.options) || []).find((opt) => opt.selected) || null;
      const subModelValidOptions = gatherAddRowSubModelValidOptions(row.subModel);
      const unsafeContext = lowerText.includes('confirmed vehicles')
        || lowerText.includes('potential vehicles')
        || lowerText.includes('unknown vehicles')
        || lowerText.includes('motorcycle')
        || lowerText.includes('orv')
        || lowerText.includes('edit remove confirmed')
        || lowerText.includes('confirm remove');
      const rowIncomplete = state.rowIncomplete;
      const meaningfulVin = normalizeVehicleVin(vinValue).length >= 6;
      const rowLooksLikeAddCarTruck = lowerText.includes('add car or truck');
      const scopedEmptyAddCarTruckRecovery = rowLooksLikeAddCarTruck
        && rowIncomplete
        && cancelButton
        && !meaningfulVin;
      let reason = 'safe';
      if (!allExpectedSatisfied) reason = 'expected-vehicles-not-satisfied';
      else if (!rowIncomplete) reason = 'row-not-incomplete';
      else if (!container) reason = 'row-container-not-found';
      else if (unsafeContext && !scopedEmptyAddCarTruckRecovery) reason = 'unsafe-vehicle-section-context';
      else if (meaningfulVin) reason = 'vin-present';
      else if (!cancelButton) reason = 'cancel-button-not-scoped';
      const safeToCancel = reason === 'safe';
      candidates.push({
        rowIndex: idx,
        row,
        state,
        container,
        rowText,
        cancelButton,
        addButton,
        rowIncomplete,
        meaningfulVin,
        unsafeContext,
        addButtonPresent: addButtonState.present,
        addButtonEnabled: addButtonState.enabled,
        safeToCancel,
        reason,
        yearValue: vehicleFieldValue(row.year),
        vinValue,
        manufacturerValue: vehicleFieldValue(row.manufacturer),
        modelValue,
        subModelValue,
        subModelPresent: row.subModel && visible(row.subModel) ? '1' : '0',
        subModelText: vehicleOptionText(subModelSelected),
        subModelPlaceholderSelected: gatherAddRowSubModelPlaceholderSelected(row.subModel) ? '1' : '0',
        subModelOptionCount: String(subModelValidOptions.length),
        subModelFirstValidOptionPresent: subModelValidOptions.length ? '1' : '0',
        rowTitle: lowerText.includes('add car or truck') ? 'Add Car or Truck' : ''
      });
    }
    const incomplete = candidates.filter((candidate) => candidate.rowIncomplete);
    const safeCandidate = incomplete.find((candidate) => candidate.safeToCancel);
    return safeCandidate || incomplete[0] || candidates[0] || null;
  };
  const staleAddVehicleRowStatus = (source = {}) => {
    try {
      const candidate = findStaleAddVehicleRow(source);
      if (!candidate) {
        return {
          result: 'NONE',
          rowIndex: '',
          rowTitle: '',
          rowIncomplete: '0',
          yearValue: '',
          vinValue: '',
          manufacturerValue: '',
          modelValue: '',
          subModelValue: '',
          subModelText: '',
          subModelPresent: '0',
          subModelPlaceholderSelected: '1',
          subModelOptionCount: '0',
          subModelFirstValidOptionPresent: '0',
          addButtonPresent: '0',
          addButtonEnabled: '0',
          unsafeContext: '0',
          cancelButtonPresent: '0',
          cancelButtonScoped: '0',
          safeToCancel: '0',
          reason: 'no-stale-row',
          evidence: '',
          missing: 'staleAddVehicleRow'
        };
      }
      return {
        result: candidate.safeToCancel ? 'FOUND' : 'UNSAFE',
        rowIndex: String(candidate.rowIndex),
        rowTitle: candidate.rowTitle,
        rowIncomplete: candidate.rowIncomplete ? '1' : '0',
        yearValue: candidate.yearValue,
        vinValue: candidate.vinValue,
        manufacturerValue: candidate.manufacturerValue,
        modelValue: candidate.modelValue,
        subModelValue: candidate.subModelValue,
        subModelText: candidate.subModelText,
        subModelPresent: candidate.subModelPresent,
        subModelPlaceholderSelected: candidate.subModelPlaceholderSelected,
        subModelOptionCount: candidate.subModelOptionCount,
        subModelFirstValidOptionPresent: candidate.subModelFirstValidOptionPresent,
        addButtonPresent: candidate.addButtonPresent ? '1' : '0',
        addButtonEnabled: candidate.addButtonEnabled ? '1' : '0',
        unsafeContext: candidate.unsafeContext ? '1' : '0',
        cancelButtonPresent: candidate.cancelButton ? '1' : '0',
        cancelButtonScoped: candidate.cancelButton ? '1' : '0',
        safeToCancel: candidate.safeToCancel ? '1' : '0',
        reason: candidate.reason,
        evidence: compact(candidate.rowText, 180),
        missing: candidate.safeToCancel ? '' : candidate.reason
      };
    } catch (err) {
      return {
        result: 'ERROR',
        rowIndex: '',
        rowTitle: '',
        rowIncomplete: '0',
        yearValue: '',
        vinValue: '',
        manufacturerValue: '',
        modelValue: '',
        subModelValue: '',
        subModelText: '',
        subModelPresent: '0',
        subModelPlaceholderSelected: '1',
        subModelOptionCount: '0',
        subModelFirstValidOptionPresent: '0',
        addButtonPresent: '0',
        addButtonEnabled: '0',
        unsafeContext: '0',
        cancelButtonPresent: '0',
        cancelButtonScoped: '0',
        safeToCancel: '0',
        reason: 'error',
        evidence: '',
        missing: compact(err && err.message, 160)
      };
    }
  };
  const selectGatherAddRowFirstValidSubModel = (source = {}) => {
    try {
      const candidate = findStaleAddVehicleRow(source);
      if (!candidate || !candidate.row || !candidate.row.subModel) {
        return linesOut({
          result: 'NO_ROW',
          selectedIndex: '',
          selectedValuePresent: '0',
          selectedMode: 'first-valid',
          optionCount: '0',
          addButtonPresent: '0',
          addButtonEnabled: '0'
        });
      }
      const options = gatherAddRowSubModelValidOptions(candidate.row.subModel);
      if (!options.length) {
        return linesOut({
          result: 'NO_OPTIONS',
          selectedIndex: '',
          selectedValuePresent: '0',
          selectedMode: 'first-valid',
          optionCount: '0',
          addButtonPresent: candidate.addButtonPresent ? '1' : '0',
          addButtonEnabled: candidate.addButtonEnabled ? '1' : '0'
        });
      }
      const choice = options[0];
      const selected = applyVehicleDropdownOption(candidate.row.subModel, choice.option);
      const valuePresent = selected && safe(candidate.row.subModel.value).trim() ? '1' : '0';
      return linesOut({
        result: selected && valuePresent === '1' ? 'OK' : 'SELECT_FAILED',
        selectedIndex: String(choice.index),
        selectedValuePresent: valuePresent,
        selectedMode: 'first-valid',
        optionCount: String(options.length),
        addButtonPresent: candidate.addButtonPresent ? '1' : '0',
        addButtonEnabled: candidate.addButtonEnabled ? '1' : '0'
      });
    } catch (err) {
      return linesOut({
        result: 'ERROR',
        selectedIndex: '',
        selectedValuePresent: '0',
        selectedMode: 'first-valid',
        optionCount: '0',
        addButtonPresent: '0',
        addButtonEnabled: '0'
      });
    }
  };
  const selectVehicleDropdownFirstValidNonPlaceholder = (source = {}) => {
    try {
      const index = Number(source.index);
      const fieldName = safe(source.fieldName);
      const select = vehicleField(index, fieldName);
      const options = gatherAddRowSubModelValidOptions(select);
      if (!select || !visible(select) || isDisabledLike(select) || select.disabled) {
        return linesOut({
          result: 'NO_SELECT',
          selectedIndex: '',
          selectedValue: '',
          selectedValuePresent: '0',
          selectedMode: 'first-valid-nonplaceholder',
          optionCount: String(options.length)
        });
      }
      if (!options.length) {
        return linesOut({
          result: 'NO_OPTIONS',
          selectedIndex: '',
          selectedValue: '',
          selectedValuePresent: '0',
          selectedMode: 'first-valid-nonplaceholder',
          optionCount: '0'
        });
      }
      const choice = firstValidNonPlaceholderVehicleOption(select);
      const selected = choice && applyVehicleDropdownOption(select, choice.option);
      const selectedValue = selected ? vehicleOptionValue(choice.option) : '';
      return linesOut({
        result: selected && selectedValue ? 'OK' : 'SELECT_FAILED',
        selectedIndex: choice ? String(choice.index) : '',
        selectedValue,
        selectedValuePresent: selectedValue ? '1' : '0',
        selectedMode: 'first-valid-nonplaceholder',
        optionCount: String(options.length)
      });
    } catch (err) {
      return linesOut({
        result: 'ERROR',
        selectedIndex: '',
        selectedValue: '',
        selectedValuePresent: '0',
        selectedMode: 'first-valid-nonplaceholder',
        optionCount: '0'
      });
    }
  };
  const clickGatherAddRowAddButton = (source = {}) => {
    try {
      const candidate = findStaleAddVehicleRow(source);
      if (!candidate) {
        return linesOut({
          result: 'NO_ROW',
          clicked: '0',
          rowIndex: '',
          addButtonPresent: '0',
          addButtonEnabled: '0'
        });
      }
      if (!candidate.addButtonPresent || !candidate.addButtonEnabled || !candidate.addButton) {
        return linesOut({
          result: 'DISABLED',
          clicked: '0',
          rowIndex: String(candidate.rowIndex),
          addButtonPresent: candidate.addButtonPresent ? '1' : '0',
          addButtonEnabled: candidate.addButtonEnabled ? '1' : '0'
        });
      }
      const clicked = clickCenterEl(candidate.addButton);
      return linesOut({
        result: clicked ? 'CLICKED' : 'CLICK_FAILED',
        clicked: clicked ? '1' : '0',
        rowIndex: String(candidate.rowIndex),
        addButtonPresent: '1',
        addButtonEnabled: '1'
      });
    } catch (err) {
      return linesOut({
        result: 'ERROR',
        clicked: '0',
        rowIndex: '',
        addButtonPresent: '0',
        addButtonEnabled: '0'
      });
    }
  };
  const cancelStaleAddVehicleRow = (source = {}) => {
    try {
      const before = findStaleAddVehicleRow(source);
      if (!before) {
        return linesOut({
          result: 'NO_STALE_ROW',
          rowIndex: '',
          clicked: '0',
          cancelButtonText: '',
          cancelButtonClass: '',
          beforeRowText: '',
          afterRowPresent: '0',
          failedFields: '',
          evidence: 'no-stale-row'
        });
      }
      if (!before.safeToCancel || !before.cancelButton) {
        return linesOut({
          result: 'UNSAFE',
          rowIndex: String(before.rowIndex),
          clicked: '0',
          cancelButtonText: before.cancelButton ? compact(getText(before.cancelButton), 80) : '',
          cancelButtonClass: before.cancelButton ? safe(before.cancelButton.className) : '',
          beforeRowText: compact(before.rowText, 180),
          afterRowPresent: '1',
          failedFields: before.reason,
          evidence: before.reason
        });
      }
      const clicked = clickCenterEl(before.cancelButton);
      if (!clicked) {
        return linesOut({
          result: 'CLICK_FAILED',
          rowIndex: String(before.rowIndex),
          clicked: '0',
          cancelButtonText: compact(getText(before.cancelButton), 80),
          cancelButtonClass: safe(before.cancelButton.className),
          beforeRowText: compact(before.rowText, 180),
          afterRowPresent: '1',
          failedFields: 'cancelButton',
          evidence: 'cancel-click-failed'
        });
      }
      const after = findStaleAddVehicleRow(source);
      const afterRowPresent = !!(after && after.rowIndex === before.rowIndex && after.state && after.state.rowOpen);
      return linesOut({
        result: afterRowPresent ? 'VERIFY_FAILED' : 'CANCELLED',
        rowIndex: String(before.rowIndex),
        clicked: '1',
        cancelButtonText: compact(getText(before.cancelButton), 80),
        cancelButtonClass: safe(before.cancelButton.className),
        beforeRowText: compact(before.rowText, 180),
        afterRowPresent: afterRowPresent ? '1' : '0',
        failedFields: afterRowPresent ? 'staleRowStillPresent' : '',
        evidence: afterRowPresent ? 'row-still-present-after-cancel' : 'row-closed'
      });
    } catch (err) {
      return linesOut({
        result: 'ERROR',
        rowIndex: '',
        clicked: '0',
        cancelButtonText: '',
        cancelButtonClass: '',
        beforeRowText: '',
        afterRowPresent: '1',
        failedFields: 'exception',
        evidence: compact(err && err.message, 160)
      });
    }
  };
  const vehicleAliasValues = (wantedText) => {
    const wanted = normUpper(wantedText);
    const groups = [
      ['CHEVROLET', 'CHEVY', 'CHEVY TRUCKS'],
      ['TOYOTA', 'TOY', 'TOYOTA TRUCKS'],
      ['FORD', 'FORD TRUCKS'],
      ['HONDA']
    ];
    for (const group of groups) {
      if (group.includes(wanted)) return new Set(group);
    }
    return new Set([wanted]);
  };
  const uniqueVehicleOptions = (matches) => {
    const out = [];
    for (const option of matches) {
      if (option && !out.includes(option)) out.push(option);
    }
    return out;
  };
  const vehicleDropdownOptionResult = (option, status = '') => ({
    option: option || null,
    status: status || (option ? 'OK' : 'NO_OPTION')
  });
  const vehicleDropdownBoolArg = (value) => /^(1|true|yes|y)$/i.test(safe(value).trim());
  const vehicleDropdownOptionIndex = (select, option) => Array.from((select && select.options) || []).indexOf(option);
  const vehicleDropdownOptionDetail = (select, option) => ({
    index: vehicleDropdownOptionIndex(select, option),
    value: vehicleOptionValue(option),
    text: vehicleOptionText(option)
  });
  const normalizedVehicleDropdownKeys = (source = {}, wantedText = '') => {
    const keys = parseVehicleListArg(source.normalizedModelKeys)
      .map((value) => normalizeVehicleModelKey(value) || safe(value).toUpperCase().replace(/[^A-Z0-9]/g, ''))
      .filter(Boolean);
    const wantedKey = normalizeVehicleModelKey(wantedText);
    if (wantedKey) keys.push(wantedKey);
    return new Set(keys);
  };
  const vehicleDropdownWantedTexts = (fieldName, wantedText, source = {}) => {
    const values = [wantedText];
    const field = safe(fieldName);
    if (field === 'Manufacturer')
      values.push(...parseVehicleListArg(source.allowedMakeLabels || source.advisorMakeLabels || source.makeAliases));
    if (field === 'Model')
      values.push(...parseVehicleListArg(source.modelAliases));
    return Array.from(new Set(values.map(normUpper).filter(Boolean)));
  };
  const vehicleSameFamilyLeadTexts = (source = {}, wantedText = '') => {
    const values = [
      source.model,
      source.canonicalModel,
      source.inputModel,
      wantedText
    ].concat(parseVehicleListArg(source.modelAliases));
    const out = [];
    const seen = new Set();
    for (const value of values) {
      const text = normalizeVehicleText(value);
      if (!text || seen.has(text)) continue;
      seen.add(text);
      out.push(text);
    }
    return out;
  };
  const vehicleSameFamilyPrefixSuffixAllowed = (suffixText, suffixKey) => {
    const text = normalizeVehicleText(suffixText);
    const key = safe(suffixKey).replace(/[^A-Z0-9]/g, '');
    if (!text && !key) return false;
    const textTokens = text.split(/\s+/).filter(Boolean);
    const allowedTokens = new Set(['2WD', '4WD', 'AWD', 'FWD', 'RWD', '2DR', '4DR', '4X2', '4X4']);
    if (textTokens.length && textTokens.every((token) => allowedTokens.has(token))) return true;
    return /^(2WD|4WD|AWD|FWD|RWD|2DR|4DR|4X2|4X4)$/.test(key);
  };
  const vehicleSameFamilyPrefixMatchesText = (rawText, source = {}, wantedText = '') => {
    const optionText = normalizeVehicleText(rawText);
    const optionKey = normalizeVehicleModelKey(rawText);
    if (!optionText && !optionKey) return false;
    for (const leadText of vehicleSameFamilyLeadTexts(source, wantedText)) {
      const leadKey = normalizeVehicleModelKey(leadText);
      if (!leadText || !leadKey) continue;
      if (optionText.startsWith(`${leadText} `)) {
        const suffixText = optionText.slice(leadText.length).trim();
        const suffixKey = optionKey.startsWith(leadKey) ? optionKey.slice(leadKey.length) : '';
        if (vehicleSameFamilyPrefixSuffixAllowed(suffixText, suffixKey)) return true;
      }
      if (optionKey.startsWith(leadKey)) {
        const suffixKey = optionKey.slice(leadKey.length);
        if (vehicleSameFamilyPrefixSuffixAllowed('', suffixKey)) return true;
      }
    }
    return false;
  };
  const vehicleSameFamilyPrefixMatchesOption = (option, source = {}, wantedText = '') =>
    vehicleSameFamilyPrefixMatchesText(vehicleOptionText(option), source, wantedText)
    || vehicleSameFamilyPrefixMatchesText(vehicleOptionValue(option), source, wantedText);
  const vehicleSameFamilyPrefixOptionResult = (select, options, fieldName, wantedText, source = {}, ambiguousOptions = []) => {
    if (safe(fieldName) !== 'Model') return null;
    if (!vehicleDropdownBoolArg(source.allowProvisionalSameFamilyGate || source.allowProvisionalSameFamily)) return null;
    const matches = uniqueVehicleOptions(options.filter((opt) => vehicleSameFamilyPrefixMatchesOption(opt, source, wantedText)));
    if (!matches.length) return null;
    const option = matches[0];
    const details = matches.map((match) => vehicleDropdownOptionDetail(select, match));
    const ambiguous = (ambiguousOptions && ambiguousOptions.length ? ambiguousOptions : matches)
      .map((match) => {
        const detail = vehicleDropdownOptionDetail(select, match);
        return `${detail.index}:${detail.text || detail.value}`;
      })
      .join('|');
    return Object.assign(vehicleDropdownOptionResult(option, 'PROVISIONAL'), {
      provisionalGateVehicle: true,
      provisionalReason: 'same-family prefix first available',
      selectedOptionIndex: String(vehicleDropdownOptionIndex(select, option)),
      selectedOptionText: vehicleOptionText(option),
      selectedOptionValue: vehicleOptionValue(option),
      ambiguousOptions: ambiguous,
      sameFamilyMatchCount: String(details.length)
    });
  };
  const findVehicleDropdownOptionResult = (select, fieldName, wantedText, allowFirstNonEmpty = false, source = {}) => {
    const options = Array.from((select && select.options) || []).filter(validVehicleOption);
    const field = safe(fieldName);
    if (!options.length) return null;
    if (field === 'ModelYear') {
      const wantedYear = normalizeDigits(wantedText);
      if (!wantedYear) return null;
      return vehicleDropdownOptionResult(options.find((opt) => normalizeDigits(vehicleOptionValue(opt)) === wantedYear)
        || options.find((opt) => normalizeDigits(vehicleOptionText(opt)) === wantedYear)
        || null);
    }
    const wantedValues = vehicleDropdownWantedTexts(field, wantedText, source);
    if (wantedValues.length) {
      if (field === 'Manufacturer' && wantedValues[0]) {
        const primaryMatches = uniqueVehicleOptions(options.filter((opt) =>
          normUpper(vehicleOptionValue(opt)) === wantedValues[0]
          || normUpper(vehicleOptionText(opt)) === wantedValues[0]
        ));
        if (primaryMatches.length === 1) return vehicleDropdownOptionResult(primaryMatches[0]);
        if (primaryMatches.length > 1) return vehicleDropdownOptionResult(null, 'AMBIGUOUS');
      }
      let matches = uniqueVehicleOptions(options.filter((opt) =>
        wantedValues.includes(normUpper(vehicleOptionValue(opt)))
        || wantedValues.includes(normUpper(vehicleOptionText(opt)))
      ));
      if (matches.length === 1) return vehicleDropdownOptionResult(matches[0]);
      if (matches.length > 1)
        return vehicleSameFamilyPrefixOptionResult(select, options, field, wantedText, source, matches)
          || vehicleDropdownOptionResult(null, 'AMBIGUOUS');
      if (field === 'Model' && (String(source.strictModelMatch || '') === '1' || source.strictModelMatch === true)) {
        const keys = normalizedVehicleDropdownKeys(source, wantedText);
        matches = uniqueVehicleOptions(options.filter((opt) => {
          const valueKey = normalizeVehicleModelKey(vehicleOptionValue(opt));
          const textKey = normalizeVehicleModelKey(vehicleOptionText(opt));
          return (valueKey && keys.has(valueKey)) || (textKey && keys.has(textKey));
        }));
        if (matches.length === 1) return vehicleDropdownOptionResult(matches[0]);
        if (matches.length > 1)
          return vehicleSameFamilyPrefixOptionResult(select, options, field, wantedText, source, matches)
            || vehicleDropdownOptionResult(null, 'AMBIGUOUS');
        const provisional = vehicleSameFamilyPrefixOptionResult(select, options, field, wantedText, source, matches);
        if (provisional) return provisional;
        return vehicleDropdownOptionResult(null, 'NO_OPTION');
      }
      const wanted = wantedValues[0];
      const aliases = vehicleAliasValues(wanted);
      matches = uniqueVehicleOptions(options.filter((opt) =>
        aliases.has(normUpper(vehicleOptionValue(opt))) || aliases.has(normUpper(vehicleOptionText(opt)))
      ));
      if (matches.length === 1) return vehicleDropdownOptionResult(matches[0]);
      if (matches.length > 1) return vehicleDropdownOptionResult(null, 'AMBIGUOUS');
      const containsMatches = options.filter((opt) => {
        const text = normUpper(vehicleOptionText(opt));
        const value = normUpper(vehicleOptionValue(opt));
        return (text && (text.includes(wanted) || wanted.includes(text)))
          || (value && (value.includes(wanted) || wanted.includes(value)));
      });
      if (containsMatches.length === 1) return vehicleDropdownOptionResult(containsMatches[0]);
      if (containsMatches.length > 1) return vehicleDropdownOptionResult(null, 'AMBIGUOUS');
    }
    const provisional = vehicleSameFamilyPrefixOptionResult(select, options, field, wantedText, source);
    if (provisional) return provisional;
    if (allowFirstNonEmpty)
      return vehicleDropdownOptionResult(options[0] || null);
    return vehicleDropdownOptionResult(null, 'NO_OPTION');
  };
  const findVehicleDropdownOption = (select, fieldName, wantedText, allowFirstNonEmpty = false, source = {}) => {
    const result = findVehicleDropdownOptionResult(select, fieldName, wantedText, allowFirstNonEmpty, source);
    return result && result.option ? result.option : null;
  };
  const applyVehicleDropdownOption = (select, option) => {
    if (!select || !option) return false;
    try { select.focus(); } catch {}
    try {
      Array.from(select.options || []).forEach((opt) => { opt.selected = opt === option; });
    } catch {}
    if (!setNativeValue(select, option.value)) {
      try { select.value = option.value; } catch {}
    }
    try { select.value = option.value; } catch {}
    fireFieldEvents(select);
    return safe(select.value) === safe(option.value);
  };
  const vehicleManufacturerState = (index) => {
    const manufacturer = vehicleField(index, 'Manufacturer');
    const options = Array.from((manufacturer && manufacturer.options) || []).filter(validVehicleOption);
    return {
      el: manufacturer,
      enabled: !!(manufacturer && visible(manufacturer) && !isDisabledLike(manufacturer)),
      optionCount: options.length,
      options: options.map((opt) => compact(vehicleOptionText(opt), 40)).join('|')
    };
  };
  const dispatchVehicleYearEvent = (el, type, events, extra = {}) => {
    try {
      const Ctor = /^key/.test(type) ? (globalThis.KeyboardEvent || Event) : Event;
      el.dispatchEvent(new Ctor(type, Object.assign({ bubbles: true, cancelable: true }, extra)));
      events.push(type);
      return true;
    } catch {
      try {
        el.dispatchEvent(new Event(type, { bubbles: true, cancelable: true }));
        events.push(type);
        return true;
      } catch {}
    }
    return false;
  };
  const setVehicleYearControlled = (input, year, attempt, manufacturer) => {
    const events = [];
    const methodParts = [];
    try { input.focus(); methodParts.push('focus'); } catch {}
    try { if (typeof input.select === 'function') input.select(); } catch {}
    if (attempt > 1) {
      setNativeValue(input, '');
      dispatchVehicleYearEvent(input, 'keydown', events, { key: 'Backspace' });
      dispatchVehicleYearEvent(input, 'input', events);
      dispatchVehicleYearEvent(input, 'keyup', events, { key: 'Backspace' });
      methodParts.push('clear');
    }
    dispatchVehicleYearEvent(input, 'keydown', events, { key: safe(year).slice(-1) || '0' });
    if (!setNativeValue(input, year)) {
      try { input.value = year; } catch {}
    }
    dispatchVehicleYearEvent(input, 'input', events);
    dispatchVehicleYearEvent(input, 'change', events);
    dispatchVehicleYearEvent(input, 'keyup', events, { key: safe(year).slice(-1) || '0' });
    if (attempt > 1) {
      dispatchVehicleYearEvent(input, 'blur', events);
      try { if (typeof input.blur === 'function') input.blur(); } catch {}
      dispatchVehicleYearEvent(input, 'focusout', events);
      methodParts.push('blur-focusout');
    }
    if (attempt > 2 && manufacturer) {
      try { manufacturer.focus(); methodParts.push('manufacturer-focus'); } catch {}
      dispatchVehicleYearEvent(manufacturer, 'focus', events);
    }
    return {
      method: methodParts.concat([attempt > 1 ? 'retry-controlled-input' : 'controlled-input']).join('|'),
      events
    };
  };
  const setVehicleYearAndWaitManufacturer = (source = {}) => {
    const index = Number(source.index);
    const year = safe(source.year).trim();
    const input = vehicleField(index, 'ModelYear');
    const manufacturer = vehicleField(index, 'Manufacturer');
    const failed = [];
    let yearVerified = '0';
    let method = '';
    let eventsFired = [];
    let attempts = 1;
    if (!input || !visible(input) || isDisabledLike(input) || input.readOnly) {
      failed.push('year');
      const state = vehicleManufacturerState(index);
      return lineResult({
        result: 'FAILED',
        index: String(source.index ?? ''),
        yearWanted: year,
        yearValue: vehicleFieldValue(input),
        yearVerified,
        manufacturerEnabled: state.enabled ? '1' : '0',
        manufacturerOptionCount: String(state.optionCount),
        manufacturerOptions: state.options,
        method: 'year-input-unavailable',
        eventsFired: '',
        attempts: '0',
        failedFields: failed,
        alerts: collectVisibleAlerts().join(' || ')
      });
    }
    const readyBefore = vehicleManufacturerState(index);
    if (readyBefore.enabled && readyBefore.optionCount > 0 && normalizeDigits(input.value) === normalizeDigits(year)) {
      return linesOut({
        result: 'OK',
        index: String(index),
        yearWanted: year,
        yearValue: vehicleFieldValue(input),
        yearVerified: '1',
        manufacturerEnabled: '1',
        manufacturerOptionCount: String(readyBefore.optionCount),
        manufacturerOptions: readyBefore.options,
        method: 'already-ready',
        eventsFired: '',
        attempts: '0',
        failedFields: '',
        alerts: collectVisibleAlerts().join(' || ')
      });
    }
    const sequence = setVehicleYearControlled(input, year, 2, manufacturer);
    method = sequence.method;
    eventsFired = sequence.events;
    yearVerified = normalizeDigits(input.value) === normalizeDigits(year) ? '1' : '0';
    if (yearVerified !== '1') {
      failed.push('year');
    }
    const finalState = vehicleManufacturerState(index);
    if (yearVerified === '1' && finalState.enabled && finalState.optionCount > 0) {
      return linesOut({
        result: 'OK',
        index: String(index),
        yearWanted: year,
        yearValue: vehicleFieldValue(input),
        yearVerified,
        manufacturerEnabled: '1',
        manufacturerOptionCount: String(finalState.optionCount),
        manufacturerOptions: finalState.options,
        method,
        eventsFired: eventsFired.join('|'),
        attempts: String(attempts),
        failedFields: '',
        alerts: collectVisibleAlerts().join(' || ')
      });
    }
    if (yearVerified === '1') failed.push('manufacturer');
    return lineResult({
      result: 'FAILED',
      index: String(Number.isNaN(index) ? safe(source.index) : index),
      yearWanted: year,
      yearValue: vehicleFieldValue(input),
      yearVerified,
      manufacturerEnabled: finalState.enabled ? '1' : '0',
      manufacturerOptionCount: String(finalState.optionCount),
      manufacturerOptions: finalState.options,
      method,
      eventsFired: eventsFired.join('|'),
      attempts: String(attempts),
      failedFields: Array.from(new Set(failed)),
      alerts: collectVisibleAlerts().join(' || ')
    });
  };
  const findGatherAddVehicleButton = () => {
    const candidates = Array.from(document.querySelectorAll('button,a,[role=button],input[type=button],input[type=submit]'))
      .filter(visible)
      .filter((el) => !isDisabledLike(el));
    const wanted = ['ADD CAR OR TRUCK', 'ADD VEHICLE', 'ADD ANOTHER VEHICLE', 'ADD CAR', 'ADD TRUCK'];
    return candidates.find((el) => {
      const text = normUpper([getText(el), safe(el.value), safe(el.getAttribute('aria-label')), safe(el.id)].join(' '));
      return wanted.some((needle) => text.includes(needle));
    }) || null;
  };
  const waitForUsableVehicleRow = (wantedYear = '', timeoutMs = 900) => {
    const start = Date.now();
    let idx = findUsableVehicleRowIndex(wantedYear);
    while (idx < 0 && (Date.now() - start) < timeoutMs)
      idx = findUsableVehicleRowIndex(wantedYear);
    return idx;
  };
  const gatherVehicleRowStatus = (source = {}) => {
    try {
      const requested = safe(source.index).trim();
      let rowIndex = requested !== '' && !Number.isNaN(Number(requested)) ? Number(requested) : findUsableVehicleRowIndex(source.year);
      if (rowIndex < 0) {
        const indexes = vehicleRowIndexes();
        rowIndex = indexes.length ? indexes[0] : -1;
      }
      const addButton = findGatherAddVehicleButton();
      if (rowIndex < 0) {
        return {
          result: addButton ? 'NO_ROW' : 'NO_ADD_BUTTON',
          rowIndex: '',
          hasVehicleType: '0',
          hasYear: '0',
          hasManufacturer: '0',
          hasModel: '0',
          hasSubModel: '0',
          vehicleTypeValue: '',
          yearValue: '',
          manufacturerValue: '',
          modelValue: '',
          subModelValue: '',
          yearOptions: '',
          manufacturerOptions: '',
          modelOptions: '',
          subModelOptions: '',
          addButtonPresent: addButton ? '1' : '0',
          addButtonText: compact(addButton ? getText(addButton) : '', 80),
          alerts: collectVisibleAlerts().join(' || ')
        };
      }
      const row = readVehicleRow(rowIndex);
      const hasYear = !!row.year && visible(row.year);
      const ready = hasYear && !isDisabledLike(row.year) && !row.year.readOnly;
      return {
        result: ready ? 'READY' : 'PARTIAL',
        rowIndex: String(rowIndex),
        hasVehicleType: row.vehicleType && visible(row.vehicleType) ? '1' : '0',
        hasYear: hasYear ? '1' : '0',
        hasManufacturer: row.manufacturer && visible(row.manufacturer) ? '1' : '0',
        hasModel: row.model && visible(row.model) ? '1' : '0',
        hasSubModel: row.subModel && visible(row.subModel) ? '1' : '0',
        vehicleTypeValue: vehicleFieldValue(row.vehicleType),
        yearValue: vehicleFieldValue(row.year),
        manufacturerValue: vehicleFieldValue(row.manufacturer),
        modelValue: vehicleFieldValue(row.model),
        subModelValue: vehicleFieldValue(row.subModel),
        yearOptions: vehicleOptionSummary(row.year),
        manufacturerOptions: vehicleOptionSummary(row.manufacturer),
        modelOptions: vehicleOptionSummary(row.model),
        subModelOptions: vehicleOptionSummary(row.subModel),
        addButtonPresent: addButton ? '1' : '0',
        addButtonText: compact(addButton ? getText(addButton) : '', 80),
        alerts: collectVisibleAlerts().join(' || ')
      };
    } catch (err) {
      return {
        result: 'ERROR',
        rowIndex: '',
        hasVehicleType: '0',
        hasYear: '0',
        hasManufacturer: '0',
        hasModel: '0',
        hasSubModel: '0',
        vehicleTypeValue: '',
        yearValue: '',
        manufacturerValue: '',
        modelValue: '',
        subModelValue: '',
        yearOptions: '',
        manufacturerOptions: '',
        modelOptions: '',
        subModelOptions: '',
        addButtonPresent: '0',
        addButtonText: '',
        alerts: compact(err && err.message, 160)
      };
    }
  };
  const gatherVehicleAddStatus = (source = {}) => {
    const matchArgs = getVehicleMatchArgs(source);
    const partialYearMakeMode = safe(source.partialYearMakeMode) === '1' || source.partialYearMakeMode === true;
    const year = normUpper(source.year);
    const rowState = gatherVehicleAddRowState(source, matchArgs);
    const addButton = findGatherAddVehicleButton();
    const text = bodyText();
    const warningStillPresent = includesText(text, 'confirm or add at least 1 car or truck') || includesText(text, 'auto originally asked for');
    const alerts = collectVisibleAlerts();
    const alertText = lower(alerts.join(' || '));
    const failedAlert = /incomplete|required|invalid|error/.test(alertText);
    const isConfirmedVehicleCandidate = (candidate) => {
      if (!candidate || !candidate.details || !candidate.details.yearMatch || !candidate.details.makeMatch || !candidate.details.modelMatch)
        return false;
      const cardText = normLower(candidate.cardText);
      if (!cardText.includes('confirmed')) return false;
      if (cardText.includes('potential vehicles') || cardText.includes('unknown vehicles')) return false;
      if (cardText.includes('confirm remove') && !cardText.includes('confirmed vehicles')) return false;
      const sectionEvidence = cardText.includes('cars and trucks') || cardText.includes('confirmed vehicles');
      const actionEvidence = cardText.includes('edit') || cardText.includes('remove');
      return sectionEvidence || actionEvidence;
    };
    const partialConfirmedDetails = (candidate) => {
      const cardText = normalizeVehicleText(candidate.cardText);
      const rawText = candidate.cardText;
      const yearMatch = !!matchArgs.year && new RegExp(`(^|\\s)${matchArgs.year}(\\s|$)`).test(cardText);
      const makeMatch = vehicleMakeMatches(cardText, matchArgs);
      const confirmedStatusMatched = normLower(rawText).includes('confirmed');
      const lowerText = normLower(rawText);
      const sectionEvidence = lowerText.includes('cars and trucks') || lowerText.includes('confirmed vehicles');
      const actionEvidence = lowerText.includes('edit') || lowerText.includes('remove');
      const contextMatched = confirmedStatusMatched
        && !lowerText.includes('potential vehicles')
        && !lowerText.includes('unknown vehicles')
        && (sectionEvidence || actionEvidence);
      const promotedModel = partialVehicleModelTextFromCard(rawText, matchArgs);
      const vinEvidenceText = vehicleVinEvidenceText(rawText);
      return {
        yearMatch,
        makeMatch,
        confirmedStatusMatched,
        contextMatched,
        modelMatch: !!promotedModel,
        promotedModel,
        vinEvidenceText,
        vinEvidence: !!vinEvidenceText
      };
    };
    if (partialYearMakeMode) {
      const partialCandidates = confirmedVehicleCandidates()
        .map((candidate) => ({ ...candidate, details: partialConfirmedDetails(candidate) }))
        .filter((candidate) => candidate.details.yearMatch && candidate.details.makeMatch && candidate.details.contextMatched)
        .sort((a, b) => a.cardText.length - b.cardText.length);
      const candidateTexts = partialCandidates
        .map((candidate) => compact(candidate.cardText, 120))
        .filter((textValue, index, list) => textValue && list.indexOf(textValue) === index)
        .slice(0, 5);
      const candidate = partialCandidates.length === 1 ? partialCandidates[0] : null;
      const duplicateAddRowOpenForConfirmedVehicle = !!(candidate && rowState.rowIncomplete && rowState.rowMatchesExpectedContext);
      let result = 'MISSING';
      let method = 'partial-confirmed-card-none';
      let failedFields = '';
      let matchedText = '';
      let promotedModel = '';
      let vinEvidenceText = '';
      let partialPromoted = false;
      if (partialCandidates.length > 1) {
        result = 'AMBIGUOUS';
        method = 'partial-confirmed-card-ambiguous';
        failedFields = 'partialVehicleAmbiguous';
      } else if (candidate) {
        matchedText = compact(candidate.cardText, 180);
        promotedModel = candidate.details.promotedModel;
        vinEvidenceText = candidate.details.vinEvidenceText;
        if (!promotedModel) {
          method = 'partial-confirmed-card-model-missing';
          failedFields = 'partialVehicleModelMissing';
        } else if (!vinEvidenceText) {
          method = 'partial-confirmed-card-no-vin';
          failedFields = 'partialVehicleNoVin';
        } else {
          result = 'ADDED';
          method = 'partial-confirmed-card';
          partialPromoted = true;
        }
      }
      return linesOut({
        result,
        vehicleMatched: partialPromoted ? '1' : '0',
        confirmedVehicleMatched: partialPromoted ? '1' : '0',
        confirmedStatusMatched: candidate && candidate.details.confirmedStatusMatched ? '1' : '0',
        yearMatched: candidate && candidate.details.yearMatch ? '1' : '0',
        makeMatched: candidate && candidate.details.makeMatch ? '1' : '0',
        modelMatched: partialPromoted ? '1' : '0',
        vinMatched: '0',
        vinEvidence: vinEvidenceText ? '1' : '0',
        partialPromoted: partialPromoted ? '1' : '0',
        promotedModel,
        promotedVehicleText: matchedText,
        promotedVinEvidence: vinEvidenceText ? '1' : '0',
        promotionSource: partialPromoted ? 'confirmed-card' : '',
        rowOpen: rowState.rowOpen ? '1' : '0',
        rowIndex: rowState.rowIndex >= 0 ? String(rowState.rowIndex) : '',
        rowComplete: rowState.rowComplete ? '1' : '0',
        rowIncomplete: rowState.rowIncomplete ? '1' : '0',
        duplicateAddRowOpenForConfirmedVehicle: duplicateAddRowOpenForConfirmedVehicle ? '1' : '0',
        duplicateAddRowDetails: duplicateAddRowOpenForConfirmedVehicle ? vehicleRowDetails(rowState.row) : '',
        rowGone: rowState.rowGone ? '1' : '0',
        addButtonPresent: addButton ? '1' : '0',
        warningStillPresent: warningStillPresent ? '1' : '0',
        expectedModelKey: '',
        matchedText,
        candidateTexts: candidateTexts.join(' || '),
        candidateCount: String(partialCandidates.length),
        failedFields,
        alerts: alerts.join(' || '),
        method
      });
    }
    const candidates = findVehicleMatchCandidates(source);
    const scoredConfirmedCandidates = confirmedVehicleCandidates()
      .map((candidate) => ({ ...candidate, details: scoreVehicleCandidate(candidate.cardText, source) }));
    const confirmedCandidates = scoredConfirmedCandidates
      .filter((candidate) => candidate.details.score >= candidate.details.threshold)
      .sort((a, b) => b.details.score - a.details.score || a.cardText.length - b.cardText.length);
    const exactConfirmedCandidates = scoredConfirmedCandidates
      .filter((candidate) => candidate.details.yearMatch && candidate.details.makeMatch && candidate.details.modelMatch)
      .sort((a, b) => b.details.score - a.details.score || a.cardText.length - b.cardText.length);
    const exactYearMakeVinCandidates = exactConfirmedCandidates.length ? [] : scoredConfirmedCandidates
      .filter((candidate) => candidate.details.exactYearMakeVinMatch)
      .sort((a, b) => b.details.score - a.details.score || a.cardText.length - b.cardText.length);
    const yearWindowVinCandidates = exactConfirmedCandidates.length || exactYearMakeVinCandidates.length ? [] : scoredConfirmedCandidates
      .filter((candidate) => candidate.details.yearWindowVinMatch)
      .sort((a, b) => b.details.score - a.details.score || a.cardText.length - b.cardText.length);
    const candidateTexts = confirmedCandidates.concat(candidates)
      .map((candidate) => compact(candidate.cardText, 120))
      .filter((textValue, index, list) => textValue && list.indexOf(textValue) === index)
      .slice(0, 5);
    const confirmed = confirmedCandidates.find(isConfirmedVehicleCandidate)
      || (exactYearMakeVinCandidates.length === 1 ? exactYearMakeVinCandidates[0] : null)
      || (yearWindowVinCandidates.length === 1 ? yearWindowVinCandidates[0] : null)
      || candidates.find(isConfirmedVehicleCandidate)
      || null;
    const matched = confirmed || candidates[0] || null;
    const matchedText = matched ? compact(matched.cardText, 180) : '';
    const matchedNorm = normUpper(matchedText);
    const yearMatched = !!matched && !!matched.details && !!matched.details.yearMatch;
    const makeMatched = !!matched && !!matched.details && !!matched.details.makeMatch;
    const modelMatched = !!matched && !!matched.details && !!matched.details.modelMatch;
    const vinMatched = !!matched && !!matched.details && (!!matched.details.vinMatch || !!matched.details.vinSuffixMatch);
    const vehicleMatched = !!matched && yearMatched && makeMatched && modelMatched;
    const confirmedVehicleMatched = !!confirmed;
    const confirmedStatusMatched = !!confirmed && normLower(confirmed.cardText).includes('confirmed');
    const exactYearMakeVinMatch = !!confirmed && !!confirmed.details && !!confirmed.details.exactYearMakeVinMatch;
    const yearWindowVinMatch = !!confirmed && !!confirmed.details && !!confirmed.details.yearWindowVinMatch;
    const duplicateAddRowOpenForConfirmedVehicle = confirmedVehicleMatched && rowState.rowIncomplete && rowState.rowMatchesExpectedContext;
    let result = 'MISSING';
    let method = 'no-vehicle-evidence';
    if (confirmedVehicleMatched) {
      result = 'ADDED';
      method = exactYearMakeVinMatch && !modelMatched ? 'vin-backed-exact-year-make' : (yearWindowVinMatch ? 'vin-backed-year-window' : 'confirmed-vehicle-card');
    } else if (vehicleMatched && /added to quote/.test(lower(matchedText)) && !findCardButtonByText(matched.card, 'Confirm')) {
      result = 'IN_PROGRESS';
      method = 'vehicle-card-added-unconfirmed';
    } else if (vehicleMatched) {
      result = 'IN_PROGRESS';
      method = 'vehicle-text-unconfirmed';
    } else if (rowState.rowComplete) {
      result = 'READY_ROW';
      method = 'row-complete';
    } else if (failedAlert) {
      result = 'FAILED';
      method = 'validation-alert';
    } else if (rowState.rowIncomplete || (rowState.rowGone && warningStillPresent)) {
      result = 'IN_PROGRESS';
      method = rowState.rowIncomplete ? 'row-incomplete' : 'row-gone-warning-present';
    } else if (rowState.rowGone && !warningStillPresent) {
      result = 'IN_PROGRESS';
      method = 'row-gone-no-vehicle-text';
    }
    return linesOut({
      result,
      vehicleMatched: vehicleMatched ? '1' : '0',
      confirmedVehicleMatched: confirmedVehicleMatched ? '1' : '0',
      confirmedStatusMatched: confirmedStatusMatched ? '1' : '0',
      yearMatched: yearMatched ? '1' : '0',
      makeMatched: makeMatched ? '1' : '0',
      modelMatched: modelMatched ? '1' : '0',
      vinMatched: (matchArgs.vin || matchArgs.vinSuffix) && vinMatched ? '1' : '0',
      exactYearMakeVinMatch: exactYearMakeVinMatch ? '1' : '0',
      yearWindowVinMatch: yearWindowVinMatch ? '1' : '0',
      vinEvidence: matchedText && vehicleVinEvidenceText(matchedText) ? '1' : '0',
      partialPromoted: '0',
      promotedModel: '',
      promotedVehicleText: '',
      promotedVinEvidence: '0',
      promotionSource: '',
      rowOpen: rowState.rowOpen ? '1' : '0',
      rowIndex: rowState.rowIndex >= 0 ? String(rowState.rowIndex) : '',
      rowComplete: rowState.rowComplete ? '1' : '0',
      rowIncomplete: rowState.rowIncomplete ? '1' : '0',
      duplicateAddRowOpenForConfirmedVehicle: duplicateAddRowOpenForConfirmedVehicle ? '1' : '0',
      duplicateAddRowDetails: duplicateAddRowOpenForConfirmedVehicle ? vehicleRowDetails(rowState.row) : '',
      rowGone: rowState.rowGone ? '1' : '0',
      addButtonPresent: addButton ? '1' : '0',
      warningStillPresent: warningStillPresent ? '1' : '0',
      expectedModelKey: normalizeVehicleModelKey(source.model),
      matchedText,
      candidateTexts: candidateTexts.join(' || '),
      candidateCount: String(candidateTexts.length),
      failedFields: '',
      alerts: alerts.join(' || '),
      method
    });
  };
  const vehicleEditField = (fieldNames = []) => {
    const names = Array.isArray(fieldNames) ? fieldNames : [fieldNames];
    for (const name of names) {
      const exact = document.getElementById(`CommonComponent.Vehicle[0].${name}`);
      if (exact && visible(exact)) return exact;
    }
    const controls = Array.from(document.querySelectorAll('input[id],select[id],textarea[id]')).filter(visible);
    for (const name of names) {
      const suffix = `.${name}`;
      const found = controls.find((el) => safe(el.id).includes('CommonComponent.Vehicle') && safe(el.id).endsWith(suffix));
      if (found) return found;
    }
    return null;
  };
  const readVehicleEditField = (el) => {
    if (!el || !visible(el)) return { value: '', text: '' };
    if (el.tagName === 'SELECT') {
      const selected = Array.from(el.options || []).find((opt) => opt.selected) || (el.options && el.selectedIndex >= 0 ? el.options[el.selectedIndex] : null);
      return {
        value: safe(el.value).trim(),
        text: vehicleOptionText(selected || { text: el.value, value: el.value })
      };
    }
    return { value: safe(el.value).trim(), text: safe(el.value).trim() };
  };
  const findVehicleEditUpdateButton = () => {
    const exact = document.getElementById('submitButtonVehicleComponent_0');
    if (exact && visible(exact)) return exact;
    return Array.from(document.querySelectorAll('button,input[type=button],input[type=submit],a,[role=button]'))
      .filter(visible)
      .find((el) => answerTextMatches(getText(el) || safe(el.value) || safe(el.getAttribute('aria-label')), 'Update')) || null;
  };
  const vehicleEditOptionSummary = (select, max = 12) => Array.from((select && select.options) || [])
    .filter(validVehicleOption)
    .slice(0, max)
    .map((opt) => compact(vehicleOptionText(opt), 80))
    .join('|');
  const readVehicleEditStatusFields = () => {
    const body = safe((document.body && (document.body.innerText || document.body.textContent)) || '');
    const bodyNorm = normUpper(body);
    const subModel = vehicleEditField('SubModel');
    const year = vehicleEditField(['ModelYear', 'Year']);
    const vin = vehicleEditField(['VIN', 'Vin', 'VehicleIdentificationNumber', 'VehIdentificationNumber']);
    const manufacturer = vehicleEditField(['Manufacturer', 'Make']);
    const model = vehicleEditField(['Model']);
    const vehicleType = vehicleEditField(['VehTypeCd', 'VehicleType']);
    const updateButton = findVehicleEditUpdateButton();
    const subModelState = readVehicleEditField(subModel);
    const validOptions = Array.from((subModel && subModel.options) || []).filter(validVehicleOption);
    const selectedOption = Array.from((subModel && subModel.options) || []).find((opt) => opt.selected) || null;
    const selectedValid = !!(selectedOption && validVehicleOption(selectedOption) && safe(subModel && subModel.value).trim());
    const modalEvidence = !!subModel || !!updateButton || bodyNorm.includes('EDIT VEHICLE');
    const requiredEvidence = bodyNorm.includes('SUB-MODEL') || bodyNorm.includes('SUB MODEL') || !!subModel;
    const yearState = readVehicleEditField(year);
    const vinState = readVehicleEditField(vin);
    const manufacturerState = readVehicleEditField(manufacturer);
    const modelState = readVehicleEditField(model);
    const yearComplete = !!(yearState.value || yearState.text);
    const manufacturerComplete = !!(manufacturerState.value || manufacturerState.text);
    const modelComplete = !!(modelState.value || modelState.text);
    const subModelComplete = !subModel || selectedValid || !!(subModelState.value && !/^select one$/i.test(subModelState.text));
    const requiredComplete = modalEvidence && yearComplete && manufacturerComplete && modelComplete && subModelComplete;
    const updateReady = requiredComplete && !!updateButton && !isDisabledLike(updateButton);
    const evidence = [
      bodyNorm.includes('EDIT VEHICLE') ? 'editVehicleText' : '',
      subModel ? 'subModelSelect' : '',
      updateButton ? 'updateButton' : '',
      requiredEvidence ? 'subModelRequiredText' : '',
      requiredComplete ? 'requiredFieldsComplete' : ''
    ].filter(Boolean).join(',');
    const missing = [];
    if (!modalEvidence) missing.push('editVehicleModal');
    if (modalEvidence && !subModel) missing.push('subModel');
    if (modalEvidence && !updateButton) missing.push('updateButton');
    let result = 'NO_MODAL';
    if (updateReady) result = 'UPDATE_REQUIRED_READY';
    else if (modalEvidence && !subModel) result = 'NO_SUBMODEL';
    else if (modalEvidence && selectedValid) result = 'SUBMODEL_SELECTED';
    else if (modalEvidence && subModel && validOptions.length > 0) result = 'SUBMODEL_REQUIRED';
    else if (modalEvidence && subModel) result = 'READY';
    return {
      result,
      vehicleText: compact([yearState.text, manufacturerState.text, modelState.text, vinState.text].filter(Boolean).join(' '), 180),
      vehicleTypeValue: readVehicleEditField(vehicleType).value,
      yearValue: yearState.value || yearState.text,
      vinValue: vinState.value || vinState.text,
      manufacturerValue: manufacturerState.value || manufacturerState.text,
      modelValue: modelState.value || modelState.text,
      subModelPresent: subModel ? '1' : '0',
      subModelValue: subModelState.value,
      subModelText: subModelState.text,
      subModelOptionCount: String(validOptions.length),
      subModelOptions: vehicleEditOptionSummary(subModel),
      updateButtonPresent: updateButton ? '1' : '0',
      updateButtonEnabled: updateButton && !isDisabledLike(updateButton) ? '1' : '0',
      requiredComplete: requiredComplete ? '1' : '0',
      alerts: collectVisibleAlerts().join(' || '),
      evidence,
      missing
    };
  };
  const advisorSnapshotRouteFamily = (source = {}) => {
    const url = pageUrl();
    if (url.includes('/apps/intel/102/rapport')) return 'INTEL_102_RAPPORT';
    if (url.includes('/apps/intel/102/overview')) return 'INTEL_102_OVERVIEW';
    if (url.includes('/apps/intel/102/selectProduct')) return 'INTEL_102_SELECT_PRODUCT';
    if (url.includes('/apps/ASCPRODUCT/')) return 'ASCPRODUCT';
    if (url.includes('/apps/customer-summary/')) return 'CUSTOMER_SUMMARY';
    if (isDuplicatePage(source)) return 'DUPLICATE';
    if (url.includes('advisorpro.allstate.com')) return 'ADVISOR';
    if (bodyText().includes('allstate advisor pro')) return 'GATEWAY';
    return 'UNKNOWN';
  };
  const snapshotBool = (value) => value ? '1' : '0';
  const firstVisibleHeadingText = (root) => {
    const base = root || document;
    const heading = Array.from(base.querySelectorAll('h1,h2,h3,h4,h5,h6,[role=heading],legend'))
      .filter(visible)
      .map((node) => compact(getText(node), 120))
      .find(Boolean);
    if (heading) return heading;
    return compact(getText(root), 120);
  };
  const findVisibleDialogRoot = () => {
    const selectors = [
      'dialog',
      '[role="dialog"]',
      '[aria-modal="true"]',
      '.modal',
      '.ReactModal__Content',
      '.c-modal'
    ];
    for (const selector of selectors) {
      const found = Array.from(document.querySelectorAll(selector))
        .filter(visible)
        .find((node) => compact(getText(node), 160));
      if (found) return found;
    }
    return null;
  };
  const findModalButton = (root, id, wantedText = '') => {
    const base = root || document;
    const exact = id ? document.getElementById(id) : null;
    if (exact && visible(exact) && (!root || root.contains(exact))) return exact;
    const wanted = wantedText || id;
    return Array.from(base.querySelectorAll('button,input[type=button],input[type=submit],a,[role=button]'))
      .filter(visible)
      .find((node) => {
        const text = getText(node) || safe(node.value) || safe(node.getAttribute('aria-label')) || safe(node.id);
        return wanted && answerTextMatches(text, wanted);
      }) || null;
  };
  const readCheckedRadioState = (root, namePattern) => {
    const base = root || document;
    const regex = namePattern && typeof namePattern.test === 'function' ? namePattern : new RegExp(safe(namePattern), 'i');
    const inputs = Array.from(base.querySelectorAll('input'));
    if (base !== document)
      inputs.push(...Array.from(document.querySelectorAll('input')).filter((input) => !inputs.includes(input)));
    const checked = inputs
      .filter((radio) => safe(radio.type).toLowerCase() === 'radio')
      .filter((radio) => regex.test(`${safe(radio.name)} ${safe(radio.id)} ${safe(radio.value)}`))
      .find((radio) => radio.checked) || null;
    if (!checked) return { selected: '0', code: '', text: '' };
    return {
      selected: '1',
      code: compact(safe(checked.value || checked.id), 80),
      text: compact(readInputLabel(checked) || safe(checked.id), 120)
    };
  };
  const advisorInlineParticipantPanelPresent = () => {
    const text = bodyText();
    const saveButton = document.getElementById('PARTICIPANT_SAVE-btn');
    const hasParticipantFields = !!(
      document.getElementById('ageFirstLicensed_ageFirstLicensed')
      || document.getElementById('emailAddress.emailAddress')
      || document.querySelector('input[id*="militaryInd"],input[name*="militaryInd"],input[id*="violationInd"],input[name*="violationInd"]')
      || /moving violations/i.test(text)
    );
    return !!(saveButton && visible(saveButton) && hasParticipantFields
      && (text.includes("let's get some more details") || text.includes('lets get some more details') || text.includes('participant')));
  };
  const advisorRemoveDriverModalRoot = () => {
    const saveButton = document.getElementById('REMOVE_PARTICIPANT_SAVE-btn');
    const dialog = saveButton ? (saveButton.closest('[role="dialog"],[aria-modal="true"],.modal,.ReactModal__Content,.c-modal') || saveButton.parentElement) : findVisibleDialogRoot();
    const root = dialog || document;
    const text = normLower(getText(root) || bodyText());
    const hasQuestion = text.includes('why do you want to remove') || text.includes('remove driver');
    const hasReason = !!root.querySelector('input[name*="nonDriver"],input[id*="nonDriver"]');
    return (saveButton && visible(saveButton) && (hasQuestion || hasReason)) ? root : null;
  };
  const advisorAscVehicleModalRoot = () => {
    const saveButton = document.getElementById('ADD_ASSET_SAVE-btn');
    const root = saveButton ? (saveButton.closest('[role="dialog"],[aria-modal="true"],.modal,.ReactModal__Content,.c-modal') || saveButton.parentElement) : null;
    const text = normLower(getText(root) || bodyText());
    return (saveButton && visible(saveButton) && (text.includes('garaging') || text.includes('vehicle') || text.includes('ownership'))) ? (root || document) : null;
  };
  const readAdvisorActiveModalStatusFields = (source = {}) => {
    try {
      const routeFamily = advisorSnapshotRouteFamily(source);
      const editStatus = readVehicleEditStatusFields();
      const editVehiclePresent = editStatus.result !== 'NO_MODAL';
      const staleStatus = staleAddVehicleRowStatus({ allExpectedVehiclesSatisfied: '1' });
      const staleAddRowPresent = !['', 'NONE', 'ERROR'].includes(safe(staleStatus.result));
      const inlineParticipantPanelPresent = advisorInlineParticipantPanelPresent();
      const removeDriverRoot = advisorRemoveDriverModalRoot();
      const vehicleModalRoot = advisorAscVehicleModalRoot();
      const addressStatus = addressVerificationStatusFields();
      const addressPresent = addressStatus.result === 'FOUND';
      const duplicatePresent = isDuplicatePage(source);
      const incidentsPresent = isIncidentsPage(source);
      const unknownRoot = findVisibleDialogRoot();
      let activeModalType = 'NONE';
      let activePanelType = 'NONE';
      let modalTitle = '';
      let modalSaveButtonId = '';
      let modalSaveButton = null;
      let modalCancelButton = null;
      let evidence = [];
      let missing = [];
      let nextRecommendedReadOnlyStatus = '';

      if (addressPresent) {
        activeModalType = 'ADDRESS_VERIFICATION';
        modalTitle = 'Address Verification';
        modalSaveButton = findAddressVerificationContinueButton();
        modalSaveButtonId = safe(modalSaveButton && modalSaveButton.id);
        evidence.push('address-verification');
        nextRecommendedReadOnlyStatus = 'address_verification_status';
      } else if (duplicatePresent) {
        activeModalType = 'DUPLICATE_PROSPECT';
        modalTitle = 'This Prospect May Already Exist';
        evidence.push('duplicate-prospect');
        nextRecommendedReadOnlyStatus = 'detect_state';
      } else if (editVehiclePresent) {
        activeModalType = 'GATHER_EDIT_VEHICLE';
        activePanelType = 'GATHER_EDIT_VEHICLE';
        modalTitle = 'Edit Vehicle';
        modalSaveButton = findVehicleEditUpdateButton();
        modalSaveButtonId = safe(modalSaveButton && modalSaveButton.id);
        modalCancelButton = findModalButton(null, '', 'Cancel');
        evidence.push(editStatus.evidence || 'edit-vehicle');
        nextRecommendedReadOnlyStatus = 'gather_vehicle_edit_status';
      } else if (staleAddRowPresent) {
        activeModalType = 'GATHER_STALE_ADD_VEHICLE_ROW';
        activePanelType = 'GATHER_STALE_ADD_VEHICLE_ROW';
        modalTitle = compact(staleStatus.rowTitle || 'Add Car or Truck', 120);
        modalCancelButton = findModalButton(null, '', 'Cancel');
        evidence.push(staleStatus.evidence || 'stale-add-row');
        nextRecommendedReadOnlyStatus = 'gather_stale_add_vehicle_row_status';
      } else if (removeDriverRoot) {
        activeModalType = 'ASC_REMOVE_DRIVER_MODAL';
        modalTitle = firstVisibleHeadingText(removeDriverRoot) || 'Remove Driver';
        modalSaveButton = document.getElementById('REMOVE_PARTICIPANT_SAVE-btn');
        modalSaveButtonId = safe(modalSaveButton && modalSaveButton.id);
        modalCancelButton = findModalButton(removeDriverRoot, 'PARTICIPANT_CANCEL-btn', 'Cancel');
        evidence.push('remove-driver-modal');
        nextRecommendedReadOnlyStatus = 'advisor_active_modal_status';
      } else if (inlineParticipantPanelPresent) {
        activeModalType = 'ASC_INLINE_PARTICIPANT_PANEL';
        activePanelType = 'ASC_INLINE_PARTICIPANT_PANEL';
        modalTitle = "Let's get some more details";
        modalSaveButton = document.getElementById('PARTICIPANT_SAVE-btn');
        modalSaveButtonId = safe(modalSaveButton && modalSaveButton.id);
        modalCancelButton = findModalButton(null, 'PARTICIPANT_CANCEL-btn', 'Cancel');
        evidence.push('inline-participant-panel');
        nextRecommendedReadOnlyStatus = 'asc_participant_detail_status';
      } else if (vehicleModalRoot) {
        activeModalType = 'ASC_VEHICLE_MODAL';
        modalTitle = firstVisibleHeadingText(vehicleModalRoot) || 'Vehicle Modal';
        modalSaveButton = document.getElementById('ADD_ASSET_SAVE-btn');
        modalSaveButtonId = safe(modalSaveButton && modalSaveButton.id);
        modalCancelButton = findModalButton(vehicleModalRoot, 'ASSET_CANCEL-btn', 'Cancel');
        evidence.push('asc-vehicle-modal');
        nextRecommendedReadOnlyStatus = 'modal_exists';
      } else if (incidentsPresent) {
        activeModalType = 'INCIDENTS';
        modalTitle = 'Incidents';
        modalSaveButton = document.getElementById('CONTINUE_OFFER-btn');
        modalSaveButtonId = safe(modalSaveButton && modalSaveButton.id);
        evidence.push('incidents');
        nextRecommendedReadOnlyStatus = 'wait_condition:is_incidents';
      } else if (unknownRoot) {
        activeModalType = 'UNKNOWN_MODAL';
        modalTitle = firstVisibleHeadingText(unknownRoot);
        modalSaveButton = findModalButton(unknownRoot, '', 'Save') || findModalButton(unknownRoot, '', 'Continue') || findModalButton(unknownRoot, '', 'Update');
        modalSaveButtonId = safe(modalSaveButton && modalSaveButton.id);
        modalCancelButton = findModalButton(unknownRoot, '', 'Cancel');
        evidence.push('unknown-modal');
        nextRecommendedReadOnlyStatus = 'scan_current_page';
      }

      if (activeModalType === 'NONE') missing.push('activeModal');
      return {
        result: 'OK',
        routeFamily,
        url: compact(pageUrl(), 240),
        activeModalType,
        activePanelType,
        saveGate: modalSaveButton ? (isDisabledLike(modalSaveButton) ? 'MODAL_SAVE_DISABLED' : 'MODAL_SAVE_ENABLED') : '',
        modalTitle: compact(modalTitle, 120),
        modalSaveButtonId,
        modalSaveButtonPresent: snapshotBool(modalSaveButton),
        modalSaveButtonEnabled: snapshotBool(modalSaveButton && !isDisabledLike(modalSaveButton)),
        modalCancelButtonPresent: snapshotBool(modalCancelButton),
        editVehiclePresent: snapshotBool(editVehiclePresent),
        inlineParticipantPanelPresent: snapshotBool(inlineParticipantPanelPresent),
        removeDriverModalPresent: snapshotBool(removeDriverRoot),
        blockerCode: activeModalType === 'NONE' ? '' : `${activeModalType}_OPEN`,
        nextRecommendedReadOnlyStatus,
        evidence: compact(evidence.filter(Boolean).join('|'), 240),
        missing: compact(missing.join('|'), 240)
      };
    } catch (err) {
      return {
        result: 'ERROR',
        routeFamily: advisorSnapshotRouteFamily(source),
        url: compact(pageUrl(), 240),
        activeModalType: '',
        activePanelType: '',
        saveGate: '',
        modalTitle: '',
        modalSaveButtonId: '',
        modalSaveButtonPresent: '0',
        modalSaveButtonEnabled: '0',
        modalCancelButtonPresent: '0',
        editVehiclePresent: '0',
        inlineParticipantPanelPresent: '0',
        removeDriverModalPresent: '0',
        blockerCode: 'SNAPSHOT_ERROR',
        nextRecommendedReadOnlyStatus: 'scan_current_page',
        evidence: '',
        missing: compact(err && err.message, 200)
      };
    }
  };
  const vehicleSnapshotCards = (mode) => {
    if (mode === 'confirmed') {
      return confirmedVehicleCandidates()
        .map((candidate) => compact(candidate.cardText, 110))
        .filter(Boolean)
        .slice(0, 8);
    }
    const nodes = Array.from(document.querySelectorAll('div,section,article,li,tr,fieldset'))
      .filter(visible);
    const cards = [];
    const seen = new Set();
    for (const node of nodes.sort((a, b) => getText(a).length - getText(b).length)) {
      const text = getText(node);
      const lowered = normLower(text);
      const hasCandidateChild = Array.from(node.querySelectorAll('div,article,li,tr,fieldset'))
        .some((child) => {
          if (!visible(child)) return false;
          const childText = getText(child);
          if (!childText || childText.length >= text.length) return false;
          const childLowered = normLower(childText);
          const childHasConfirm = Array.from(child.querySelectorAll('button,a,[role=button]'))
            .some((button) => visible(button) && answerTextMatches(getText(button), 'Confirm'));
          if (!/\b(?:19|20)\d{2}\b/.test(childText)) return false;
          if (childLowered.includes('confirmed vehicles') || childLowered.includes('confirmed')) return false;
          if (!childLowered.includes('potential') && !childHasConfirm) return false;
          return vehicleTitleCount(childText) <= 1;
        });
      if (hasCandidateChild) continue;
      const hasConfirm = Array.from(node.querySelectorAll('button,a,[role=button]'))
        .some((button) => visible(button) && answerTextMatches(getText(button), 'Confirm'));
      if (!/\b(?:19|20)\d{2}\b/.test(text)) continue;
      if (lowered.includes('confirmed vehicles') || lowered.includes('confirmed')) continue;
      if (!lowered.includes('potential') && !hasConfirm) continue;
      if (vehicleTitleCount(text) > 1) continue;
      const item = compact(text, 110);
      const key = normLower(item);
      if (!item || seen.has(key)) continue;
      seen.add(key);
      cards.push(item);
    }
    return cards.slice(0, 8);
  };
  const readGatherPeoplePropertySnapshot = () => {
    const ageInput = Array.from(document.querySelectorAll('input[id]')).find((el) => safe(el.id).endsWith('.Driver.AgeFirstLicensed')) || null;
    const emailInput = Array.from(document.querySelectorAll('input[id]')).find((el) => safe(el.id).endsWith('.Communications.EmailAddr')) || null;
    const ownershipSelect = Array.from(document.querySelectorAll('select[id]')).find((el) => safe(el.id).endsWith('.ResidenceOwnedRentedCd.SrcCd')) || null;
    const homeTypeSelect = Array.from(document.querySelectorAll('select[id]')).find((el) => safe(el.id).endsWith('.ResidenceTypeCd.SrcCd')) || null;
    const ownership = readSelectState(ownershipSelect);
    const homeType = readSelectState(homeTypeSelect);
    return {
      peopleStatus: compact(`ageFirstLicensed=${safe(ageInput && ageInput.value).trim()}|emailPresent=${emailInput ? 1 : 0}|emailValuePresent=${safe(emailInput && emailInput.value).trim() ? 1 : 0}`, 180),
      propertyStatus: compact(`ownership=${ownership.value || ownership.text}|homeType=${homeType.value || homeType.text}`, 180)
    };
  };
  const readGatherVehicleWarningText = () => {
    const alerts = collectVisibleAlerts().join(' || ');
    if (/confirm or add at least 1 car or truck|auto originally asked/i.test(alerts))
      return compact(alerts, 180);
    const rawBody = safe(document.body && (document.body.innerText || document.body.textContent));
    const line = rawBody.split(/\r?\n|(?<=\.)\s+/)
      .find((part) => /confirm or add at least 1 car or truck|auto originally asked/i.test(part));
    return compact(line || '', 180);
  };
  const readGatherRapportSnapshotFields = (source = {}) => {
    try {
      const routeOk = pageUrl().includes('/apps/intel/102/rapport') || isGatherDataPage(source);
      if (!routeOk) {
        return {
          result: 'NOT_RAPPORT',
          routeFamily: advisorSnapshotRouteFamily(source),
          url: compact(pageUrl(), 240),
          activeModalType: readAdvisorActiveModalStatusFields(source).activeModalType,
          activePanelType: '',
          saveGate: '',
          vehicleWarningPresent: '0',
          vehicleWarningText: '',
          confirmedVehicleCount: '0',
          potentialVehicleCount: '0',
          confirmedVehicles: '',
          potentialVehicles: '',
          editVehiclePanelPresent: '0',
          editVehicleStatus: '',
          editVehicleYear: '',
          editVehicleMake: '',
          editVehicleModel: '',
          editVehicleSubModel: '',
          editVehicleUpdatePresent: '0',
          editVehicleUpdateEnabled: '0',
          editVehicleRequiredComplete: '0',
          staleAddRowPresent: '0',
          startQuotingSectionPresent: '0',
          createQuotesEnabled: '0',
          peopleStatus: '',
          propertyStatus: '',
          blockerCode: 'NOT_RAPPORT',
          nextRecommendedReadOnlyStatus: 'detect_state',
          evidence: '',
          missing: 'rapport-route'
        };
      }
      const active = readAdvisorActiveModalStatusFields(source);
      const confirmedCards = vehicleSnapshotCards('confirmed');
      const potentialCards = vehicleSnapshotCards('potential');
      const editStatus = readVehicleEditStatusFields();
      const editPresent = editStatus.result !== 'NO_MODAL';
      const staleStatus = staleAddVehicleRowStatus({ allExpectedVehiclesSatisfied: '1' });
      const stalePresent = !['', 'NONE', 'ERROR'].includes(safe(staleStatus.result));
      const startStatus = buildStartQuotingStatus(source);
      const warningText = readGatherVehicleWarningText();
      const peopleProperty = readGatherPeoplePropertySnapshot();
      let blockerCode = '';
      let nextRecommendedReadOnlyStatus = '';
      if (editStatus.result === 'UPDATE_REQUIRED_READY') {
        blockerCode = 'GATHER_EDIT_VEHICLE_UPDATE_REQUIRED';
        nextRecommendedReadOnlyStatus = 'gather_vehicle_edit_status';
      } else if (editPresent) {
        blockerCode = 'GATHER_EDIT_VEHICLE_OPEN';
        nextRecommendedReadOnlyStatus = 'gather_vehicle_edit_status';
      } else if (stalePresent) {
        blockerCode = 'GATHER_STALE_ADD_VEHICLE_ROW_OPEN';
        nextRecommendedReadOnlyStatus = 'gather_stale_add_vehicle_row_status';
      } else if (warningText) {
        blockerCode = 'GATHER_VEHICLE_WARNING_PRESENT';
        nextRecommendedReadOnlyStatus = 'gather_confirmed_vehicles_status';
      } else if (startStatus.startQuotingSectionPresent === '1' && startStatus.createQuotesEnabled !== '1') {
        blockerCode = 'GATHER_CREATE_QUOTES_DISABLED';
        nextRecommendedReadOnlyStatus = 'gather_start_quoting_status';
      }
      const evidence = [
        'route:rapport',
        confirmedCards.length ? `confirmed:${confirmedCards.length}` : '',
        potentialCards.length ? `potential:${potentialCards.length}` : '',
        editPresent ? `edit:${editStatus.result}` : '',
        stalePresent ? `stale:${staleStatus.result}` : '',
        startStatus.startQuotingSectionPresent === '1' ? 'start-quoting' : '',
        warningText ? 'vehicle-warning' : ''
      ].filter(Boolean).join('|');
      return {
        result: 'OK',
        routeFamily: 'INTEL_102_RAPPORT',
        url: compact(pageUrl(), 240),
        activeModalType: active.activeModalType,
        activePanelType: active.activePanelType,
        saveGate: startStatus.createQuotesEnabled === '1' ? 'CREATE_QUOTES_ENABLED' : (startStatus.createQuotesPresent === '1' ? 'CREATE_QUOTES_DISABLED' : ''),
        vehicleWarningPresent: snapshotBool(warningText),
        vehicleWarningText: warningText,
        confirmedVehicleCount: String(confirmedCards.length),
        potentialVehicleCount: String(potentialCards.length),
        confirmedVehicles: compact(confirmedCards.join(' || '), 360),
        potentialVehicles: compact(potentialCards.join(' || '), 360),
        editVehiclePanelPresent: snapshotBool(editPresent),
        editVehicleStatus: editPresent ? editStatus.result : '',
        editVehicleYear: editStatus.yearValue || '',
        editVehicleMake: editStatus.manufacturerValue || '',
        editVehicleModel: editStatus.modelValue || '',
        editVehicleSubModel: editStatus.subModelText || editStatus.subModelValue || '',
        editVehicleUpdatePresent: editStatus.updateButtonPresent || '0',
        editVehicleUpdateEnabled: editStatus.updateButtonEnabled || '0',
        editVehicleRequiredComplete: editStatus.requiredComplete || '0',
        staleAddRowPresent: snapshotBool(stalePresent),
        startQuotingSectionPresent: startStatus.startQuotingSectionPresent || '0',
        createQuotesEnabled: startStatus.createQuotesEnabled || '0',
        peopleStatus: peopleProperty.peopleStatus,
        propertyStatus: peopleProperty.propertyStatus,
        blockerCode,
        nextRecommendedReadOnlyStatus,
        evidence: compact(evidence, 240),
        missing: compact([startStatus.missing, editPresent ? editStatus.missing : ''].filter(Boolean).join('|'), 240)
      };
    } catch (err) {
      return {
        result: 'ERROR',
        routeFamily: advisorSnapshotRouteFamily(source),
        url: compact(pageUrl(), 240),
        activeModalType: '',
        activePanelType: '',
        saveGate: '',
        vehicleWarningPresent: '0',
        vehicleWarningText: '',
        confirmedVehicleCount: '0',
        potentialVehicleCount: '0',
        confirmedVehicles: '',
        potentialVehicles: '',
        editVehiclePanelPresent: '0',
        editVehicleStatus: '',
        editVehicleYear: '',
        editVehicleMake: '',
        editVehicleModel: '',
        editVehicleSubModel: '',
        editVehicleUpdatePresent: '0',
        editVehicleUpdateEnabled: '0',
        editVehicleRequiredComplete: '0',
        staleAddRowPresent: '0',
        startQuotingSectionPresent: '0',
        createQuotesEnabled: '0',
        peopleStatus: '',
        propertyStatus: '',
        blockerCode: 'SNAPSHOT_ERROR',
        nextRecommendedReadOnlyStatus: 'scan_current_page',
        evidence: '',
        missing: compact(err && err.message, 200)
      };
    }
  };
  const readAscRemoveDriverFields = () => {
    const root = advisorRemoveDriverModalRoot();
    const reason = root ? readCheckedRadioState(root, /nonDriver/i) : { selected: '0', code: '', text: '' };
    return {
      root,
      targetName: root ? compact(firstVisibleHeadingText(root).replace(/^Remove Driver\s*/i, ''), 120) : '',
      reasonSelected: reason.selected,
      reasonCode: reason.code,
      reasonText: reason.text
    };
  };
  const findAscInlineParticipantPanelRoot = () => {
    const saveButton = findAscInlineParticipantSaveButton();
    if (!saveButton) return null;
    let current = saveButton;
    while (current && current !== document && current !== document.body) {
      const text = normLower(getText(current));
      if ((text.includes("let's get some more details") || text.includes('lets get some more details') || text.includes('participant') || text.includes('driver details'))
        && text.includes('save')
        && text.length <= 1800) {
        return current;
      }
      current = current.parentElement;
    }
    return saveButton.closest('form,section,[role="dialog"],[aria-modal="true"],.modal,.panel,.drawer,div') || saveButton.parentElement || null;
  };
  const ASC_MOVING_VIOLATIONS_QUESTION = 'Have you had any moving violations in the past five years?';
  const ascParticipantPanelRequiredWarningPresent = (root) => {
    const scope = root && root.querySelectorAll ? root : null;
    if (!scope) return false;
    const text = normLower(getText(scope));
    if (/please make a selection|make a selection|required/.test(text)) return true;
    return Array.from(scope.querySelectorAll('[role=alert],.error,.validation,.c-alert,.c-alert__content,[aria-invalid="true"]'))
      .filter(visible)
      .some((node) => /please make a selection|make a selection|required/.test(normLower(getText(node) || safe(node.getAttribute && node.getAttribute('aria-label')))));
  };
  const readAscParticipantMovingViolationsState = (root = findAscInlineParticipantPanelRoot()) => {
    const panelRoot = root && root.querySelectorAll ? root : null;
    const warningPresent = panelRoot ? ascParticipantPanelRequiredWarningPresent(panelRoot) : false;
    const namedState = panelRoot ? readScopedYesNoGroupState(panelRoot, /violation/i) : { value: '', selected: false, source: '', controlCount: '0' };
    const semanticState = panelRoot ? readSemanticAnswerState(ASC_MOVING_VIOLATIONS_QUESTION, panelRoot) : { value: '', selected: false, source: '', controlCount: '0', ambiguous: false };
    const rootText = panelRoot ? normLower(getText(panelRoot)) : '';
    const questionPresent = !!(panelRoot && (
      rootText.includes(normLower(ASC_MOVING_VIOLATIONS_QUESTION))
      || namedState.source
      || semanticState.source
    ));
    const selectedValue = namedState.value || semanticState.value || '';
    const selectedSource = namedState.value ? namedState.source : (semanticState.value ? semanticState.source : (semanticState.source || namedState.source || ''));
    const controlCount = Number(namedState.controlCount || 0) + Number(semanticState.controlCount || 0);
    const requiredMissing = !!(questionPresent && !selectedValue);
    return {
      questionPresent: questionPresent ? '1' : '0',
      controlPresent: controlCount > 0 ? '1' : '0',
      controlCount: String(controlCount),
      selected: selectedValue ? '1' : '0',
      selectedValue,
      selectedSource,
      requiredMissing: requiredMissing ? '1' : '0',
      warningPresent: warningPresent ? '1' : '0',
      ambiguous: semanticState.ambiguous ? '1' : '0',
      source: namedState.value ? 'radio-name' : (semanticState.source || namedState.source || '')
    };
  };
  const selectAscParticipantMovingViolationsNo = (root = findAscInlineParticipantPanelRoot()) => {
    const panelRoot = root && root.querySelectorAll ? root : null;
    if (!panelRoot)
      return { ok: false, method: 'participant-panel-root-missing', traceCode: 'ASC_PARTICIPANT_MOVING_VIOLATIONS_SELECTION_FAILED', before: readAscParticipantMovingViolationsState(panelRoot), after: readAscParticipantMovingViolationsState(panelRoot) };
    const before = readAscParticipantMovingViolationsState(panelRoot);
    if (before.selectedValue === 'NO')
      return { ok: true, method: 'already-selected', traceCode: 'ASC_PARTICIPANT_MOVING_VIOLATIONS_NO_SELECTED', before, after: before };
    if (before.selectedValue)
      return { ok: true, method: 'preserved-existing-selection', traceCode: 'ASC_NON_DRIVER_PARTICIPANT_PANEL_READY_TO_SAVE', before, after: before };
    const radioResult = selectScopedYesNoByName(panelRoot, /violation/i, 'NO');
    if (radioResult.ok) {
      const after = readAscParticipantMovingViolationsState(panelRoot);
      return {
        ok: after.selectedValue === 'NO',
        method: radioResult.method,
        traceCode: after.selectedValue === 'NO' ? 'ASC_PARTICIPANT_MOVING_VIOLATIONS_NO_SELECTED' : 'ASC_PARTICIPANT_MOVING_VIOLATIONS_SELECTION_FAILED',
        before,
        after
      };
    }
    if (radioResult.method === 'ambiguous-radio-target') {
      return {
        ok: false,
        method: radioResult.method,
        traceCode: 'ASC_PARTICIPANT_MOVING_VIOLATIONS_SELECTION_FAILED',
        before,
        after: readAscParticipantMovingViolationsState(panelRoot)
      };
    }
    const semanticTarget = findUniqueSemanticAnswerTarget(ASC_MOVING_VIOLATIONS_QUESTION, 'No', panelRoot);
    if (!semanticTarget.ok) {
      return {
        ok: false,
        method: semanticTarget.method,
        traceCode: 'ASC_PARTICIPANT_MOVING_VIOLATIONS_SELECTION_FAILED',
        before,
        after: readAscParticipantMovingViolationsState(panelRoot)
      };
    }
    const clicked = clickCenterEl(semanticTarget.target);
    const after = readAscParticipantMovingViolationsState(panelRoot);
    return {
      ok: clicked && after.selectedValue === 'NO',
      method: clicked ? semanticTarget.method : 'semantic-click-failed',
      traceCode: clicked && after.selectedValue === 'NO' ? 'ASC_PARTICIPANT_MOVING_VIOLATIONS_NO_SELECTED' : 'ASC_PARTICIPANT_MOVING_VIOLATIONS_SELECTION_FAILED',
      before,
      after
    };
  };
  const readAscNonDriverParticipantPanelReadiness = (root = findAscInlineParticipantPanelRoot()) => {
    const panelRoot = root && root.querySelectorAll ? root : null;
    const moving = readAscParticipantMovingViolationsState(panelRoot);
    const requiredWarning = panelRoot ? ascParticipantPanelRequiredWarningPresent(panelRoot) : false;
    const requiredMissing = moving.requiredMissing === '1' || (!!requiredWarning && moving.questionPresent !== '0' && !moving.selectedValue);
    const saveButton = findAscInlineParticipantSaveButton();
    const saveEnabled = !!(saveButton && visible(saveButton) && !isDisabledLike(saveButton));
    return {
      moving,
      requiredWarningPresent: requiredWarning ? '1' : '0',
      requiredMissing: requiredMissing ? '1' : '0',
      savePresent: saveButton ? '1' : '0',
      saveEnabled: saveEnabled ? '1' : '0',
      readyToSave: saveEnabled && !requiredMissing ? '1' : '0'
    };
  };
  const readAscActiveParticipantPanelFields = (driverRows = []) => {
    const saveButton = findAscInlineParticipantSaveButton();
    const panelPresent = advisorInlineParticipantPanelPresent();
    const savePresent = !!(saveButton && visible(saveButton));
    const saveEnabled = !!(saveButton && visible(saveButton) && !isDisabledLike(saveButton));
    if (!panelPresent) {
      return {
        activeParticipantPanelPresent: '0',
        activeParticipantRowKey: '',
        activeParticipantNameMasked: '',
        activeParticipantRowStatus: '',
        activeParticipantSavePresent: savePresent ? '1' : '0',
        activeParticipantSaveEnabled: saveEnabled ? '1' : '0',
        activeParticipantRequiredMissing: '0',
        activeParticipantMovingViolationsQuestionPresent: '0',
        activeParticipantMovingViolationsSelectedValue: '',
        activeParticipantMovingViolationsDefaultApplied: '0',
        activeParticipantPanelReadyToSave: '0',
        activeParticipantPanelAction: ''
      };
    }
    const root = findAscInlineParticipantPanelRoot() || document;
    const panelText = getText(root) || bodyText();
    const readiness = readAscNonDriverParticipantPanelReadiness(root);
    const moving = readiness.moving;
    const matches = driverRows
      .map((row, index) => ({ row, index }))
      .filter((item) => safe(item.row.name).trim() && personNameMatches(panelText, item.row.name));
    let rowStatus = 'UNKNOWN';
    let rowKey = '';
    if (matches.length === 1) {
      const row = matches[0].row;
      rowKey = `row-${matches[0].index + 1}`;
      if (row.added) rowStatus = 'ADDED';
      else if (row.nonDriverResolved) rowStatus = 'NON_DRIVER';
      else if (row.unresolved) rowStatus = 'FOUND_UNRESOLVED';
    } else if (matches.length > 1) {
      rowStatus = 'UNKNOWN';
      rowKey = 'ambiguous';
    }
    let action = 'FAIL_SAFE';
    if (rowStatus === 'NON_DRIVER' && saveEnabled && readiness.readyToSave === '1') action = 'SAVE_NON_DRIVER_PANEL';
    else if (rowStatus === 'NON_DRIVER' && saveEnabled) action = 'COMPLETE_NON_DRIVER_PANEL';
    else if (rowStatus === 'NON_DRIVER') action = 'FAIL_SAFE';
    else if (rowStatus === 'ADDED' || rowStatus === 'FOUND_UNRESOLVED') action = 'FILL_ADDED_DRIVER_PANEL';
    return {
      activeParticipantPanelPresent: '1',
      activeParticipantRowKey: rowKey,
      activeParticipantNameMasked: rowKey ? '[REDACTED]' : '',
      activeParticipantRowStatus: rowStatus,
      activeParticipantSavePresent: savePresent ? '1' : '0',
      activeParticipantSaveEnabled: saveEnabled ? '1' : '0',
      activeParticipantRequiredMissing: readiness.requiredMissing,
      activeParticipantMovingViolationsQuestionPresent: moving.questionPresent,
      activeParticipantMovingViolationsSelectedValue: moving.selectedValue,
      activeParticipantMovingViolationsDefaultApplied: '0',
      activeParticipantPanelReadyToSave: readiness.readyToSave,
      activeParticipantPanelAction: action
    };
  };
  const readAscDriversVehiclesSnapshotFields = (source = {}) => {
    try {
      const routeId = ascProductRouteId();
      const onDriversVehicles = !!routeId && (isDriversAndVehiclesPage(source) || bodyText().includes('drivers and vehicles'));
      if (!onDriversVehicles) {
        return {
          result: 'NOT_ASC_DRIVERS_VEHICLES',
          routeFamily: advisorSnapshotRouteFamily(source),
          ascProductRouteId: routeId,
          url: compact(pageUrl(), 240),
          activeModalType: readAdvisorActiveModalStatusFields(source).activeModalType,
          activePanelType: '',
          saveGate: '',
          driverCount: '0',
          unresolvedDriverCount: '0',
          addedDriverCount: '0',
          removedDriverCount: '0',
          driverSummaries: '',
          vehicleCount: '0',
          unresolvedVehicleCount: '0',
          addedVehicleCount: '0',
          removedVehicleCount: '0',
          vehicleSummaries: '',
          inlineParticipantPanelPresent: '0',
          removeDriverModalPresent: '0',
          removeDriverTargetName: '',
          removeDriverReasonSelected: '0',
          removeDriverReasonCode: '',
          driversAndVehiclesHeadingPresent: '0',
          inlineParticipantSavePresent: '0',
          inlineParticipantSaveEnabled: '0',
          inlineParticipantSaveButtonId: '',
          activeParticipantPanelPresent: '0',
          activeParticipantRowKey: '',
          activeParticipantNameMasked: '',
          activeParticipantRowStatus: '',
          activeParticipantSavePresent: '0',
          activeParticipantSaveEnabled: '0',
          activeParticipantRequiredMissing: '0',
          activeParticipantMovingViolationsQuestionPresent: '0',
          activeParticipantMovingViolationsSelectedValue: '',
          activeParticipantMovingViolationsDefaultApplied: '0',
          activeParticipantPanelReadyToSave: '0',
          activeParticipantPanelAction: '',
          pageSaveContinuePresent: '0',
          pageSaveContinueEnabled: '0',
          pageSaveContinueButtonId: '',
          mainSavePresent: '0',
          mainSaveEnabled: '0',
          blockerCode: 'NOT_ASC_DRIVERS_VEHICLES',
          blockers: 'NOT_ASC_DRIVERS_VEHICLES',
          nextRecommendedAction: '',
          nextRecommendedReadOnlyStatus: 'detect_state',
          evidence: '',
          missing: 'asc-drivers-vehicles-route'
        };
      }
      const active = readAdvisorActiveModalStatusFields(source);
      const driverStatus = ascDriverRowsStatus(source);
      const vehicleStatus = ascVehicleRowsStatus(source);
      const saveButton = findAscPageSaveContinueButton();
      const inlineSaveButton = findAscInlineParticipantSaveButton();
      const removeFields = readAscRemoveDriverFields();
      const inlinePresent = advisorInlineParticipantPanelPresent();
      const activeParticipant = readAscActiveParticipantPanelFields(collectAscDriverRows());
      const unresolvedDriverCount = Number(driverStatus.unresolvedDriverCount || 0);
      const unresolvedVehicleCount = Number(vehicleStatus.unresolvedVehicleCount || 0);
      const blockers = [];
      if (inlinePresent && activeParticipant.activeParticipantRequiredMissing === '1') blockers.push('ASC_PARTICIPANT_MOVING_VIOLATIONS_REQUIRED');
      if (inlinePresent && inlineSaveButton && !isDisabledLike(inlineSaveButton) && activeParticipant.activeParticipantPanelReadyToSave === '1') blockers.push('INLINE_PANEL_READY_TO_SAVE');
      if (inlinePresent && activeParticipant.activeParticipantRowStatus === 'NON_DRIVER') blockers.push('ASC_NON_DRIVER_PARTICIPANT_PANEL_OPEN');
      if (unresolvedDriverCount > 0) blockers.push(`UNRESOLVED_FOUND_DRIVERS:${unresolvedDriverCount}`);
      if (unresolvedVehicleCount > 0) blockers.push(`UNRESOLVED_FOUND_VEHICLES:${unresolvedVehicleCount}`);
      let activeModalType = active.activeModalType;
      let activePanelType = active.activePanelType;
      let blockerCode = '';
      let nextRecommendedAction = '';
      let nextRecommendedReadOnlyStatus = '';
      if (removeFields.root) {
        activeModalType = 'ASC_REMOVE_DRIVER_MODAL';
        blockerCode = 'ASC_REMOVE_DRIVER_MODAL_OPEN';
        nextRecommendedReadOnlyStatus = 'advisor_active_modal_status';
      } else if (inlinePresent) {
        activePanelType = 'ASC_INLINE_PARTICIPANT_PANEL';
        activeModalType = activeModalType === 'NONE' ? 'ASC_INLINE_PARTICIPANT_PANEL' : activeModalType;
        blockerCode = activeParticipant.activeParticipantRowStatus === 'NON_DRIVER'
          ? 'ASC_NON_DRIVER_PARTICIPANT_PANEL_OPEN'
          : (inlineSaveButton && !isDisabledLike(inlineSaveButton)
            ? 'ASC_INLINE_PARTICIPANT_READY_TO_SAVE'
            : 'ASC_INLINE_PARTICIPANT_SAVE_DISABLED');
        nextRecommendedAction = inlineSaveButton && !isDisabledLike(inlineSaveButton) ? 'save_inline_participant_panel' : '';
        nextRecommendedReadOnlyStatus = 'asc_participant_detail_status';
      } else if (activeModalType === 'ASC_VEHICLE_MODAL') {
        blockerCode = 'ASC_VEHICLE_MODAL_OPEN';
        nextRecommendedReadOnlyStatus = 'modal_exists';
      } else if (unresolvedDriverCount > 0 || unresolvedVehicleCount > 0) {
        blockerCode = 'ASC_DRIVERS_VEHICLES_ROWS_UNRESOLVED';
        nextRecommendedAction = unresolvedDriverCount > 0 ? 'review_unresolved_drivers_vehicles' : 'add_matched_vehicle_row';
        nextRecommendedReadOnlyStatus = unresolvedDriverCount > 0 ? 'asc_driver_rows_status' : 'asc_vehicle_rows_status';
      } else if (saveButton && isDisabledLike(saveButton)) {
        blockerCode = 'ASC_MAIN_SAVE_DISABLED';
        nextRecommendedReadOnlyStatus = 'asc_participant_detail_status';
      }
      const evidence = [
        'route:ascproduct',
        'text:drivers-and-vehicles',
        driverStatus.evidence,
        vehicleStatus.evidence,
        saveButton ? 'main-save' : '',
        active.evidence
      ].filter(Boolean).join('|');
      return {
        result: 'OK',
        routeFamily: 'ASCPRODUCT',
        ascProductRouteId: routeId,
        url: compact(pageUrl(), 240),
        activeModalType,
        activePanelType,
        saveGate: saveButton ? (isDisabledLike(saveButton) ? 'MAIN_SAVE_DISABLED' : 'MAIN_SAVE_ENABLED') : 'MAIN_SAVE_MISSING',
        driverCount: driverStatus.driverCount || '0',
        unresolvedDriverCount: driverStatus.unresolvedDriverCount || '0',
        addedDriverCount: driverStatus.addedDriverCount || '0',
        removedDriverCount: driverStatus.removedDriverCount || '0',
        driverSummaries: driverStatus.driverSummaries || '',
        vehicleCount: vehicleStatus.vehicleCount || '0',
        unresolvedVehicleCount: vehicleStatus.unresolvedVehicleCount || '0',
        addedVehicleCount: vehicleStatus.addedVehicleCount || '0',
        removedVehicleCount: vehicleStatus.removedVehicleCount || '0',
        vehicleSummaries: vehicleStatus.vehicleSummaries || '',
        inlineParticipantPanelPresent: snapshotBool(inlinePresent),
        removeDriverModalPresent: snapshotBool(removeFields.root),
        removeDriverTargetName: removeFields.targetName,
        removeDriverReasonSelected: removeFields.reasonSelected,
        removeDriverReasonCode: removeFields.reasonCode,
        driversAndVehiclesHeadingPresent: snapshotBool(bodyText().includes('drivers and vehicles')),
        inlineParticipantSavePresent: snapshotBool(inlineSaveButton),
        inlineParticipantSaveEnabled: snapshotBool(inlineSaveButton && !isDisabledLike(inlineSaveButton)),
        inlineParticipantSaveButtonId: safe(inlineSaveButton && inlineSaveButton.id),
        activeParticipantPanelPresent: activeParticipant.activeParticipantPanelPresent,
        activeParticipantRowKey: activeParticipant.activeParticipantRowKey,
        activeParticipantNameMasked: activeParticipant.activeParticipantNameMasked,
        activeParticipantRowStatus: activeParticipant.activeParticipantRowStatus,
        activeParticipantSavePresent: activeParticipant.activeParticipantSavePresent,
        activeParticipantSaveEnabled: activeParticipant.activeParticipantSaveEnabled,
        activeParticipantRequiredMissing: activeParticipant.activeParticipantRequiredMissing,
        activeParticipantMovingViolationsQuestionPresent: activeParticipant.activeParticipantMovingViolationsQuestionPresent,
        activeParticipantMovingViolationsSelectedValue: activeParticipant.activeParticipantMovingViolationsSelectedValue,
        activeParticipantMovingViolationsDefaultApplied: activeParticipant.activeParticipantMovingViolationsDefaultApplied,
        activeParticipantPanelReadyToSave: activeParticipant.activeParticipantPanelReadyToSave,
        activeParticipantPanelAction: activeParticipant.activeParticipantPanelAction,
        pageSaveContinuePresent: snapshotBool(saveButton),
        pageSaveContinueEnabled: snapshotBool(saveButton && !isDisabledLike(saveButton)),
        pageSaveContinueButtonId: safe(saveButton && saveButton.id),
        mainSavePresent: snapshotBool(saveButton),
        mainSaveEnabled: snapshotBool(saveButton && !isDisabledLike(saveButton)),
        blockerCode,
        blockers: blockers.join('|'),
        nextRecommendedAction,
        nextRecommendedReadOnlyStatus,
        evidence: compact(evidence, 240),
        missing: compact([driverStatus.missing, vehicleStatus.missing, active.missing].filter(Boolean).join('|'), 240)
      };
    } catch (err) {
      return {
        result: 'ERROR',
        routeFamily: advisorSnapshotRouteFamily(source),
        ascProductRouteId: ascProductRouteId(),
        url: compact(pageUrl(), 240),
        activeModalType: '',
        activePanelType: '',
        saveGate: '',
        driverCount: '0',
        unresolvedDriverCount: '0',
        addedDriverCount: '0',
        removedDriverCount: '0',
        driverSummaries: '',
        vehicleCount: '0',
        unresolvedVehicleCount: '0',
        addedVehicleCount: '0',
        removedVehicleCount: '0',
        vehicleSummaries: '',
        inlineParticipantPanelPresent: '0',
        removeDriverModalPresent: '0',
        removeDriverTargetName: '',
        removeDriverReasonSelected: '0',
        removeDriverReasonCode: '',
        driversAndVehiclesHeadingPresent: '0',
        inlineParticipantSavePresent: '0',
        inlineParticipantSaveEnabled: '0',
        inlineParticipantSaveButtonId: '',
        activeParticipantPanelPresent: '0',
        activeParticipantRowKey: '',
        activeParticipantNameMasked: '',
        activeParticipantRowStatus: '',
        activeParticipantSavePresent: '0',
        activeParticipantSaveEnabled: '0',
        activeParticipantRequiredMissing: '0',
        activeParticipantMovingViolationsQuestionPresent: '0',
        activeParticipantMovingViolationsSelectedValue: '',
        activeParticipantMovingViolationsDefaultApplied: '0',
        activeParticipantPanelReadyToSave: '0',
        activeParticipantPanelAction: '',
        pageSaveContinuePresent: '0',
        pageSaveContinueEnabled: '0',
        pageSaveContinueButtonId: '',
        mainSavePresent: '0',
        mainSaveEnabled: '0',
        blockerCode: 'SNAPSHOT_ERROR',
        blockers: 'SNAPSHOT_ERROR',
        nextRecommendedAction: '',
        nextRecommendedReadOnlyStatus: 'scan_current_page',
        evidence: '',
        missing: compact(err && err.message, 200)
      };
    }
  };
  const advisorStateUnique = (values) => {
    const seen = new Set();
    return values
      .map((value) => compact(value, 160))
      .filter(Boolean)
      .filter((value) => {
        const key = normLower(value);
        if (seen.has(key)) return false;
        seen.add(key);
        return true;
      });
  };
  const advisorStateActionText = (node) => compact(getText(node) || safe(node && node.value) || safe(node && node.getAttribute && node.getAttribute('aria-label')), 160);
  const advisorStateVisibleActions = () => Array.from(document.querySelectorAll('button,a,[role=button],input[type=button],input[type=submit]'))
    .filter(visible)
    .map((node) => ({
      node,
      text: advisorStateActionText(node),
      id: safe(node.id),
      disabled: isDisabledLike(node)
    }))
    .filter((entry) => entry.text || entry.id);
  const advisorStateHasActionText = (pattern) => advisorStateVisibleActions()
    .some((entry) => !entry.disabled && pattern.test(entry.text));
  const readAdvisorProductSnapshotState = (source = {}) => {
    const product = {
      autoVisible: false,
      autoSelected: false,
      saveContinueVisible: false
    };
    if (isProductOverviewPage(source)) {
      const state = readOverviewProductTileState(source);
      product.autoVisible = state.present === '1';
      product.autoSelected = state.selected === '1';
      product.saveContinueVisible = advisorStateHasActionText(/save\s*&\s*continue\s*to\s*gather\s*data/i);
      return product;
    }
    if (isSelectProductFormPage(source)) {
      const selectors = getSelectorArgs(source);
      const productSelect = findByStableId(selectors.selectProductProductId || 'SelectProduct.Product');
      const selected = readSelectState(productSelect);
      product.autoVisible = !!productSelect && Array.from(productSelect.options || [])
        .some((option) => matchesNormalizedValue(option.value, 'AUTO') || matchesNormalizedValue(option.text || option.innerText, 'Auto'));
      product.autoSelected = !!productSelect && (matchesNormalizedValue(selected.value, 'AUTO') || matchesNormalizedValue(selected.text, 'Auto'));
      product.saveContinueVisible = !!(findByStableId(selectors.selectProductContinueId || 'selectProductContinue') || advisorStateHasActionText(/^continue$/i));
    }
    return product;
  };
  const readAdvisorPrefillGateSnapshotState = (source = {}) => {
    const status = customerSummaryOverviewStatus(source);
    const target = findCustomerSummaryStartHereTarget(source).target;
    const present = status.urlMatched === '1' && (status.startHereMatched === '1' || status.summaryAnchorMatched === '1');
    return {
      present,
      startHereVisible: !!(target && visible(target))
    };
  };
  const readAdvisorIframeSnapshotState = () => {
    const frames = Array.from(document.querySelectorAll('iframe')).filter(visible);
    return {
      present: frames.length > 0,
      count: frames.length,
      hints: frames.slice(0, 5).map((frame) => compact([
        safe(frame.id),
        safe(frame.name),
        safe(frame.title),
        safe(frame.getAttribute && frame.getAttribute('src'))
      ].filter(Boolean).join(' | '), 160)).filter(Boolean)
    };
  };
  const readAdvisorRapportSnapshotState = (source = {}) => {
    const rapport = {
      present: false,
      vehicleCount: null,
      driverCount: null,
      staleAddVehicleRow: null
    };
    if (isGatherDataPage(source)) {
      const gather = readGatherRapportSnapshotFields(source);
      rapport.present = gather.result === 'OK';
      rapport.vehicleCount = Number(gather.confirmedVehicleCount || 0) + Number(gather.potentialVehicleCount || 0);
      rapport.driverCount = null;
      rapport.staleAddVehicleRow = gather.staleAddRowPresent === '1';
      return rapport;
    }
    if (isDriversAndVehiclesPage(source)) {
      const asc = readAscDriversVehiclesSnapshotFields(source);
      rapport.present = asc.result === 'OK';
      rapport.vehicleCount = Number(asc.vehicleCount || 0);
      rapport.driverCount = Number(asc.driverCount || 0);
      rapport.staleAddVehicleRow = null;
    }
    return rapport;
  };
  const readAdvisorSelectProductSnapshotState = (source = {}) => {
    const status = buildSelectProductStatus(source);
    const present = isSelectProductFormPage(source) || status.routeFamily === 'intel-select-product';
    const missingRequired = safe(status.missing).split('|').map((item) => item.trim()).filter(Boolean);
    return {
      present,
      ratingState: status.ratingStateValue || status.ratingStateText || '',
      product: status.productValue || '',
      productText: status.productText || '',
      effectiveDate: status.effectiveDateFilled === '1' ? safe((findEffectiveDateInput() || {}).value) : '',
      currentAddressPresent: status.currentAddressPresent === '1' && status.currentAddressSelected === '1',
      currentlyInsuredAnswer: status.insuredQuestionAnswered === '1' ? (status.currentInsuredValue || null) : null,
      ownRentAnswer: status.ownOrRentSelected === '1' ? (status.ownOrRentValue || null) : null,
      continueVisible: status.continuePresent === '1',
      continueEnabled: status.continueEnabled === '1',
      missingRequired
    };
  };
  const readAdvisorAscDriversVehiclesSnapshotState = (source = {}) => {
    const status = readAscDriversVehiclesSnapshotFields(source);
    const blockers = safe(status.blockers).split('|').map((item) => item.trim()).filter(Boolean);
    return {
      present: status.result === 'OK',
      routeId: status.ascProductRouteId || '',
      driversAndVehiclesHeadingPresent: status.driversAndVehiclesHeadingPresent === '1',
      inlineParticipantPanelPresent: status.inlineParticipantPanelPresent === '1',
      inlineParticipantSavePresent: status.inlineParticipantSavePresent === '1',
      inlineParticipantSaveEnabled: status.inlineParticipantSaveEnabled === '1',
      pageSaveContinuePresent: status.pageSaveContinuePresent === '1' || status.mainSavePresent === '1',
      pageSaveContinueEnabled: status.pageSaveContinueEnabled === '1' || status.mainSaveEnabled === '1',
      unresolvedDriverCount: Number(status.unresolvedDriverCount || 0),
      unresolvedVehicleCount: Number(status.unresolvedVehicleCount || 0),
      addedDriverCount: Number(status.addedDriverCount || 0),
      removedDriverCount: Number(status.removedDriverCount || 0),
      addedVehicleCount: Number(status.addedVehicleCount || 0),
      removedVehicleCount: Number(status.removedVehicleCount || 0),
      blockerCode: status.blockerCode || '',
      blockers,
      nextRecommendedAction: status.nextRecommendedAction || ''
    };
  };
  const advisorInsuranceGateKindToRoute = (kind) => {
    if (kind === 'EXTRA_INFO_INSURANCE') return 'ASC_EXTRA_INFO_INSURANCE';
    if (kind === 'CREDIT_HIT_NOT_RECEIVED') return 'ASC_CREDIT_HIT_NOT_RECEIVED';
    if (kind === 'PRIOR_INSURANCE_NOT_FOUND') return 'ASC_PRIOR_INSURANCE_NOT_FOUND';
    return '';
  };
  const advisorInsuranceGateContinueButton = () => {
    const candidates = Array.from(document.querySelectorAll('button,input[type=button],input[type=submit],[role=button]'))
      .filter(visible)
      .map((node) => ({ node, text: normLower(getText(node) || safe(node.value) || safe(node.getAttribute && node.getAttribute('aria-label'))) }))
      .filter((entry) => /\b(save and continue|continue|next)\b/i.test(entry.text));
    return (candidates.find((entry) => !isDisabledLike(entry.node)) || candidates[0] || {}).node || null;
  };
  const advisorInsuranceGateControls = () => Array.from(document.querySelectorAll('input,select,textarea'))
    .filter(visible)
    .filter((node) => !/^(hidden|button|submit|reset)$/i.test(safe(node.type)));
  const advisorInsuranceGateControlLabel = (control) => compact(readInputLabel(control) || safe(control.id || control.name), 120);
  const advisorInsuranceGateControlId = (control) => compact([safe(control.id), safe(control.name)].filter(Boolean).join('|'), 120);
  const advisorInsuranceGateControlRequired = (control) => {
    if (!control) return false;
    if (control.required) return true;
    if (safe(control.getAttribute && control.getAttribute('required')) !== '') return true;
    if (safe(control.getAttribute && control.getAttribute('aria-required')).toLowerCase() === 'true') return true;
    const label = advisorInsuranceGateControlLabel(control);
    return /\brequired\b|\*/i.test(label);
  };
  const advisorInsuranceGateControlValue = (control) => {
    if (!control) return '';
    if (/^SELECT$/i.test(safe(control.tagName))) {
      const selected = readSelectState(control);
      const value = compact(selected.text || selected.value, 80);
      return /^(select one|select|choose|please select)$/i.test(value) ? '' : value;
    }
    if (/^(radio|checkbox)$/i.test(safe(control.type))) {
      const name = safe(control.name);
      const group = name
        ? Array.from(document.querySelectorAll(`input[name="${cssEscape(name)}"]`)).filter(visible)
        : [control];
      const checked = group.find((item) => item.checked || isSelectedNode(item));
      return checked ? compact(readInputLabel(checked) || safe(checked.value || checked.id), 80) : '';
    }
    return compact(safe(control.value), 80);
  };
  const advisorInsuranceGateFindControl = (idOrName) => {
    const wanted = safe(idOrName).trim();
    if (!wanted) return { control: null, status: 'MISSING', count: 0, label: '' };
    const found = [];
    const byId = document.getElementById(wanted);
    if (byId && visible(byId)) found.push(byId);
    try {
      const selector = `input[name="${cssEscape(wanted)}"],select[name="${cssEscape(wanted)}"],textarea[name="${cssEscape(wanted)}"]`;
      for (const node of Array.from(document.querySelectorAll(selector)).filter(visible)) {
        if (!found.includes(node)) found.push(node);
      }
    } catch {}
    const controls = found.filter((node) => !/^(hidden|button|submit|reset)$/i.test(safe(node.type)));
    if (controls.length !== 1) {
      return {
        control: null,
        status: controls.length > 1 ? 'AMBIGUOUS' : 'MISSING',
        count: controls.length,
        label: wanted
      };
    }
    return {
      control: controls[0],
      status: 'OK',
      count: 1,
      label: advisorInsuranceGateControlLabel(controls[0]) || wanted
    };
  };
  const advisorInsuranceGateSelectText = (control, wantedText) => {
    if (!control || !/^SELECT$/i.test(safe(control.tagName))) return false;
    if (isDisabledLike(control)) return false;
    return setSelectValue(control, wantedText, false);
  };
  const advisorInsuranceGateSetDate = (control, wantedDate) => {
    if (!control || /^SELECT$/i.test(safe(control.tagName))) return false;
    if (isDisabledLike(control) || control.readOnly) return false;
    return setInputValue(control, wantedDate, false);
  };
  const advisorInsuranceGateContinueCandidates = () => Array.from(document.querySelectorAll('button,input[type=button],input[type=submit],[role=button]'))
    .filter(visible)
    .map((node) => ({ node, text: normLower(getText(node) || safe(node.value) || safe(node.getAttribute && node.getAttribute('aria-label'))) }))
    .filter((entry) => /\b(save and continue|continue|next)\b/i.test(entry.text));
  const advisorInsuranceGateUniqueContinueButton = () => {
    const candidates = advisorInsuranceGateContinueCandidates();
    const enabled = candidates.filter((entry) => !isDisabledLike(entry.node));
    if (enabled.length !== 1) {
      return {
        button: null,
        status: enabled.length > 1 ? 'AMBIGUOUS' : (candidates.length ? 'DISABLED' : 'MISSING'),
        visibleCount: candidates.length,
        enabledCount: enabled.length
      };
    }
    return {
      button: enabled[0].node,
      status: 'OK',
      visibleCount: candidates.length,
      enabledCount: enabled.length
    };
  };
  const advisorInsuranceGateYearEndDate = (date = new Date()) => {
    const year = date.getFullYear();
    return `12-31-${year}`;
  };
  const advisorInsuranceGateFieldsForKind = (kind) => {
    if (kind === 'EXTRA_INFO_INSURANCE') {
      return [
        { key: 'priorInsuranceCarrier', id: 'priorInsurance_insurerName', wanted: 'Other', kind: 'select' },
        { key: 'continuousCoverageLength', id: 'priorInsurance_lenTimeContinuousPriorInsuranceMonthCnt', wanted: '3+ years', kind: 'select' }
      ];
    }
    if (kind === 'PRIOR_INSURANCE_NOT_FOUND') {
      return [
        { key: 'priorInsuranceCarrier', id: 'priorInsurance_insurerName', wanted: 'Other', kind: 'select' },
        { key: 'priorInsuranceDuration', id: 'priorInsurance_lenTimePreviousInsurer', wanted: '5+ years', kind: 'select' },
        { key: 'priorInsuranceBILimits', id: 'priorInsurance_limitAmountText', wanted: 'I do not know', kind: 'select' },
        { key: 'priorInsuranceExpirationDate', id: 'contractTermExpDt', wanted: advisorInsuranceGateYearEndDate(), kind: 'date' }
      ];
    }
    return [];
  };
  const advisorInsuranceGateRequiredEvidenceControls = (kind) => {
    const fields = advisorInsuranceGateFieldsForKind(kind);
    if (kind === 'PRIOR_INSURANCE_NOT_FOUND')
      return fields.concat([{ key: 'newCoverageStartDate', id: 'transactionEffDtTime', wanted: '', kind: 'evidence' }]);
    if (kind === 'EXTRA_INFO_INSURANCE')
      return fields;
    return fields;
  };
  const advisorInsuranceGateReadbackMatches = (actual, wanted, kind) => {
    const have = safe(actual).replace(/\s+/g, ' ').trim();
    const want = safe(wanted).replace(/\s+/g, ' ').trim();
    if (!want) return !!have;
    if (kind === 'date') return have === want;
    return normUpper(have) === normUpper(want);
  };
  const advisorInsuranceGateReadbackObject = (fields) => {
    const out = {};
    for (const field of fields)
      out[field.key] = advisorInsuranceGateControlValue(field.control);
    return out;
  };
  const advisorInsuranceGateExactStatus = (expectedRoute, expectedKind) => {
    const snapshot = advisorStateSnapshot({ source: 'asc-insurance-gate-provisional' });
    const gate = snapshot.insuranceGate || {};
    return {
      snapshot,
      gate,
      ok: snapshot.route === expectedRoute
        && gate.present === true
        && gate.kind === expectedKind
        && gate.routeFamily === 'ASCPRODUCT'
    };
  };
  const advisorInsuranceGateUnsafeResult = (result, expectedRoute, expectedKind, status, extra = {}) => lineResult({
    result,
    expectedRoute,
    expectedKind,
    actualRoute: status && status.snapshot ? status.snapshot.route : '',
    actualKind: status && status.gate ? safe(status.gate.kind) : '',
    source: 'SYSTEM_DETECTED_GATE',
    requiresClientVerification: '1',
    provisionalSource: extra.provisionalSource || '',
    failedFields: extra.failedFields || '',
    missing: extra.missing || '',
    ambiguous: extra.ambiguous || '',
    evidence: extra.evidence || ''
  });
  const applyAdvisorInsuranceGateProvisionalDefaults = (expectedRoute, expectedKind, successResult, readbackFailureResult) => {
    const status = advisorInsuranceGateExactStatus(expectedRoute, expectedKind);
    if (!status.ok)
      return advisorInsuranceGateUnsafeResult('ASC_INSURANCE_GATE_UNKNOWN', expectedRoute, expectedKind, status);

    const disallowed = expectedKind === 'EXTRA_INFO_INSURANCE'
      ? ['priorInsurance_limitAmountText', 'contractTermExpDt']
      : [];
    for (const id of disallowed) {
      const found = advisorInsuranceGateFindControl(id);
      if (found.status === 'OK')
        return advisorInsuranceGateUnsafeResult('ASC_INSURANCE_GATE_UNSAFE_OR_AMBIGUOUS', expectedRoute, expectedKind, status, { failedFields: id, evidence: 'disallowed-control-present' });
    }

    const fields = advisorInsuranceGateRequiredEvidenceControls(expectedKind).map((field) => {
      const found = advisorInsuranceGateFindControl(field.id);
      return { ...field, control: found.control, controlStatus: found.status, controlCount: found.count, label: found.label };
    });
    const badControls = fields.filter((field) => field.controlStatus !== 'OK' || !field.control || isDisabledLike(field.control) || field.control.readOnly);
    if (badControls.length) {
      return advisorInsuranceGateUnsafeResult('ASC_INSURANCE_GATE_UNSAFE_OR_AMBIGUOUS', expectedRoute, expectedKind, status, {
        failedFields: badControls.map((field) => field.key).join(','),
        missing: badControls.filter((field) => field.controlStatus === 'MISSING').map((field) => field.id).join(','),
        ambiguous: badControls.filter((field) => field.controlStatus === 'AMBIGUOUS').map((field) => field.id).join(',')
      });
    }

    const targetFields = fields.filter((field) => field.kind !== 'evidence');
    const applied = [];
    for (const field of targetFields) {
      const ok = field.kind === 'date'
        ? advisorInsuranceGateSetDate(field.control, field.wanted)
        : advisorInsuranceGateSelectText(field.control, field.wanted);
      applied.push({ field, ok });
    }
    const failedApply = applied.filter((entry) => !entry.ok).map((entry) => entry.field.key);
    if (failedApply.length) {
      return advisorInsuranceGateUnsafeResult('ASC_INSURANCE_GATE_UNSAFE_OR_AMBIGUOUS', expectedRoute, expectedKind, status, {
        failedFields: failedApply.join(','),
        evidence: 'apply-failed'
      });
    }

    const readback = advisorInsuranceGateReadbackObject(targetFields);
    const mismatches = targetFields.filter((field) => !advisorInsuranceGateReadbackMatches(readback[field.key], field.wanted, field.kind));
    if (mismatches.length) {
      return lineResult({
        result: readbackFailureResult,
        expectedRoute,
        expectedKind,
        actualRoute: status.snapshot.route,
        actualKind: status.gate.kind,
        source: 'PROVISIONAL_AGENCY_DEFAULT',
        requiresClientVerification: '1',
        provisionalSource: 'PROVISIONAL_AGENCY_DEFAULT',
        provisionalFields: targetFields.map((field) => field.key).join(','),
        readback: Object.entries(readback).map(([key, value]) => `${key}:${value}`).join('|'),
        failedFields: mismatches.map((field) => field.key).join(',')
      });
    }

    const continueState = advisorInsuranceGateUniqueContinueButton();
    if (continueState.status === 'DISABLED')
      return advisorInsuranceGateUnsafeResult('ASC_INSURANCE_GATE_CONTINUE_DISABLED', expectedRoute, expectedKind, status, { provisionalSource: 'PROVISIONAL_AGENCY_DEFAULT' });
    if (continueState.status !== 'OK')
      return advisorInsuranceGateUnsafeResult('ASC_INSURANCE_GATE_UNSAFE_OR_AMBIGUOUS', expectedRoute, expectedKind, status, {
        provisionalSource: 'PROVISIONAL_AGENCY_DEFAULT',
        evidence: `continue:${continueState.status}`
      });

    const clicked = clickCenterEl(continueState.button);
    return lineResult({
      result: clicked ? successResult : 'CLICK_FAILED',
      expectedRoute,
      expectedKind,
      actualRoute: status.snapshot.route,
      actualKind: status.gate.kind,
      clicked: clicked ? '1' : '0',
      source: 'PROVISIONAL_AGENCY_DEFAULT',
      requiresClientVerification: '1',
      provisionalSource: 'PROVISIONAL_AGENCY_DEFAULT',
      provisionalFields: targetFields.map((field) => field.key).join(','),
      readback: Object.entries(readback).map(([key, value]) => `${key}:${value}`).join('|'),
      continueVisible: String(continueState.visibleCount),
      continueEnabled: String(continueState.enabledCount),
      failedFields: clicked ? '' : 'continue'
    });
  };
  const continueAdvisorCreditHitNotReceivedGate = () => {
    const status = advisorInsuranceGateExactStatus('ASC_CREDIT_HIT_NOT_RECEIVED', 'CREDIT_HIT_NOT_RECEIVED');
    if (!status.ok)
      return advisorInsuranceGateUnsafeResult('ASC_INSURANCE_GATE_UNKNOWN', 'ASC_CREDIT_HIT_NOT_RECEIVED', 'CREDIT_HIT_NOT_RECEIVED', status);
    const continueState = advisorInsuranceGateUniqueContinueButton();
    if (continueState.status === 'DISABLED')
      return advisorInsuranceGateUnsafeResult('ASC_INSURANCE_GATE_CONTINUE_DISABLED', 'ASC_CREDIT_HIT_NOT_RECEIVED', 'CREDIT_HIT_NOT_RECEIVED', status, { evidence: 'credit-hit-continue-disabled' });
    if (continueState.status !== 'OK')
      return advisorInsuranceGateUnsafeResult('ASC_INSURANCE_GATE_UNSAFE_OR_AMBIGUOUS', 'ASC_CREDIT_HIT_NOT_RECEIVED', 'CREDIT_HIT_NOT_RECEIVED', status, { evidence: `continue:${continueState.status}` });
    const clicked = clickCenterEl(continueState.button);
    return lineResult({
      result: clicked ? 'ASC_CREDIT_HIT_NOT_RECEIVED_DETECTED' : 'CLICK_FAILED',
      expectedRoute: 'ASC_CREDIT_HIT_NOT_RECEIVED',
      expectedKind: 'CREDIT_HIT_NOT_RECEIVED',
      actualRoute: status.snapshot.route,
      actualKind: status.gate.kind,
      clicked: clicked ? '1' : '0',
      source: 'SYSTEM_DETECTED_GATE',
      creditHitNotReceived: '1',
      requiresClientVerification: '1',
      filledFieldCount: '0',
      continueVisible: String(continueState.visibleCount),
      continueEnabled: String(continueState.enabledCount),
      failedFields: clicked ? '' : 'continue'
    });
  };
  const advisorInsuranceGateTextKind = () => {
    const text = bodyText();
    const headings = advisorStateVisibleHeadingTexts().join(' | ');
    const evidence = `${text} ${headings}`;
    const creditHitEvidence = /\b(credit hit not received|did not receive a credit hit|we did not receive a credit hit|credit report was not received|credit information was not received)\b/i.test(evidence);
    if (creditHitEvidence) return 'CREDIT_HIT_NOT_RECEIVED';
    const priorNotFoundEvidence = /\b(prior insurance not found|prior policy not found|could not find prior insurance|unable to find prior insurance|we did not find prior insurance|insurance history not found)\b/i.test(evidence);
    if (priorNotFoundEvidence) return 'PRIOR_INSURANCE_NOT_FOUND';
    const extraInfoInsuranceEvidence = /\b(auto insurance history|insurance history|current insurance history|prior insurance|current insurance|continuous insurance|currently insured)\b/i.test(evidence);
    if (extraInfoInsuranceEvidence) return 'EXTRA_INFO_INSURANCE';
    return '';
  };
  const advisorInsuranceGateEvidenceKind = (labels, controlNames) => {
    const evidence = `${(labels || []).join(' | ')} ${(controlNames || []).join(' | ')}`;
    const hasPriorNotFoundFields = /\b(bodily injury liability limits|policy expiration date)\b/i.test(evidence)
      || /\b(priorInsurance_limitAmountText|contractTermExpDt)\b/i.test(evidence);
    if (hasPriorNotFoundFields) return 'PRIOR_INSURANCE_NOT_FOUND';
    const hasContinuousCoverageFields = /\blength of continuous coverage\b/i.test(evidence)
      || /\bpriorInsurance_lenTimeContinuousPriorInsuranceMonthCnt\b/i.test(evidence);
    if (hasContinuousCoverageFields) return 'EXTRA_INFO_INSURANCE';
    return '';
  };
  const readAdvisorInsuranceGateSnapshotState = () => {
    const ascRoute = isAscProductRoute();
    const controls = ascRoute ? advisorInsuranceGateControls() : [];
    const labels = advisorStateUnique(controls.map(advisorInsuranceGateControlLabel));
    const controlNames = advisorStateUnique(controls.map(advisorInsuranceGateControlId));
    const textKind = ascRoute ? advisorInsuranceGateTextKind() : '';
    const evidenceKind = ascRoute ? advisorInsuranceGateEvidenceKind(labels, controlNames) : '';
    const kind = textKind === 'CREDIT_HIT_NOT_RECEIVED' ? textKind : (evidenceKind || textKind);
    const continueButton = kind ? advisorInsuranceGateContinueButton() : null;
    const currentSelectedValues = advisorStateUnique(controls.map(advisorInsuranceGateControlValue));
    const requiredControls = controls.filter(advisorInsuranceGateControlRequired);
    const missingRequiredFields = advisorStateUnique(requiredControls
      .filter((control) => !advisorInsuranceGateControlValue(control))
      .map(advisorInsuranceGateControlLabel));
    let answerState = 'UNKNOWN';
    if (controls.length) {
      const answerable = requiredControls.length ? requiredControls : controls;
      const answeredCount = answerable.filter((control) => !!advisorInsuranceGateControlValue(control)).length;
      answerState = answeredCount === answerable.length ? 'ANSWERED' : 'UNANSWERED';
    }
    const present = !!kind;
    return {
      present,
      kind,
      routeFamily: present ? 'ASCPRODUCT' : '',
      continueVisible: !!continueButton,
      continueEnabled: !!(continueButton && !isDisabledLike(continueButton)),
      fieldsPresent: controls.length > 0,
      answerState,
      requiresClientVerification: present,
      provisionalDefaultsAllowed: kind === 'EXTRA_INFO_INSURANCE' || kind === 'PRIOR_INSURANCE_NOT_FOUND',
      creditHitNotReceived: kind === 'CREDIT_HIT_NOT_RECEIVED',
      fieldLabels: labels.slice(0, 12),
      controlNames: controlNames.slice(0, 12),
      currentSelectedValues: currentSelectedValues.slice(0, 12),
      missingRequiredFields: missingRequiredFields.slice(0, 12)
    };
  };
  const advisorStateBlockers = (source = {}) => {
    const blockers = [];
    const alerts = collectVisibleAlerts().map((item) => compact(item, 180)).filter(Boolean);
    blockers.push(...alerts.map(advisorStateAlertBlocker));
    const active = readAdvisorActiveModalStatusFields(source);
    if (active.activeModalType && active.activeModalType !== 'NONE' && active.activeModalType !== 'INCIDENTS')
      blockers.push(`active:${active.activeModalType}${active.modalTitle ? ':' + active.modalTitle : ''}`);
    return advisorStateUnique(blockers).slice(0, 8);
  };
  const advisorStateAlertBlocker = (alertText) => {
    const text = compact(alertText, 180);
    const normalized = normLower(text);
    if (normalized.includes('standardized address')
      || normalized.includes('standardized address alternative city zip')
      || (normalized.includes('alternative') && normalized.includes('city') && normalized.includes('zip')))
      return 'alert:ENTRY_STANDARDIZED_ADDRESS_ALERT';
    return `alert:${text}`;
  };
  const advisorStateHeadingAnchors = () => Array.from(document.querySelectorAll('h1,h2,h3,[role=heading]'))
    .filter(visible)
    .map((node) => `heading:${compact(getText(node), 100)}`)
    .filter((value) => value !== 'heading:');
  const advisorStateVisibleHeadingTexts = () => Array.from(document.querySelectorAll('h1,h2,h3,[role=heading]'))
    .filter(visible)
    .map((node) => compact(getText(node), 120))
    .filter(Boolean);
  const advisorStateEntryStartInfo = () => {
    const url = lower(pageUrl());
    const text = bodyText();
    const actions = advisorStateVisibleActions().map((entry) => entry.text).join(' | ');
    const headings = advisorStateVisibleHeadingTexts().join(' | ');
    const visibleEvidence = `${actions} | ${headings}`;
    const startUrl = url.includes('/apps/intel/102/start');
    const duplicateEvidence = /\b(duplicate|current customer|existing customer|existing profile|view customer)\b/i.test(visibleEvidence)
      || /\b(this prospect may already exist|existing profile|current customer|existing customer|view customer)\b/i.test(text);
    const entryEvidence = /\b(begin quoting|create new prospect|current home address)\b/i.test(visibleEvidence)
      || /\b(begin quoting|create new prospect|current home address)\b/i.test(text);
    return {
      present: startUrl || (url.includes('/apps/intel/102/') && entryEvidence),
      startUrl,
      duplicateEvidence,
      entryEvidence,
      visibleEvidence: compact(visibleEvidence, 240)
    };
  };
  const advisorStateProductOverviewUrlCandidate = (source = {}) => {
    const url = lower(pageUrl());
    const urls = getUrlArgs(source);
    const configuredNeedle = lower(urls.productOverviewContains || '');
    return !isCustomerSummaryOverviewPage(source)
      && (url.includes('/apps/intel/102/overview') || (!!configuredNeedle && url.includes(configuredNeedle)));
  };
  const advisorStateConsumerReportsCandidate = (source = {}) => {
    if (!isAscProductRoute()) return false;
    const text = bodyText();
    const headings = advisorStateVisibleHeadingTexts().join(' | ');
    const selectors = getSelectorArgs(source);
    const yesBtn = findByStableId(selectors.consumerReportsConsentYesId || source.consumerReportsConsentYesId || 'orderReportsConsent-yes-btn');
    return includesText(text, 'order consumer reports')
      || /\border consumer reports\b/i.test(headings)
      || !!yesBtn;
  };
  const advisorStateAscDriversVehiclesCandidate = (ascDriversVehicles) => {
    if (ascDriversVehicles && ascDriversVehicles.present) return true;
    return isAscProductRoute() && includesText(bodyText(), 'drivers and vehicles');
  };
  const advisorStateAscPageKind = (source = {}) => {
    const url = lower(pageUrl());
    const text = bodyText();
    const headings = advisorStateVisibleHeadingTexts().join(' | ');
    if (url.includes('/purchase') || url.includes('/payment') || url.includes('/checkout')) return 'PURCHASE';
    if (url.includes('/apps/ascproduct/') && /\b(purchase|payment|bind policy|checkout)\b/i.test(headings)) return 'PURCHASE';
    const coverageUrl = url.includes('/apps/foundations/101/coverages') || url.includes('/coverages') || url.includes('/coverage');
    if ((coverageUrl && /\bcoverages?\b/i.test(text)) || isQuoteLandingPage(source)) return 'COVERAGES';
    return '';
  };
  const advisorSelectProductDefaultActionAvailable = (selectProduct) => {
    if (!selectProduct || !selectProduct.present) return false;
    if (!selectProduct.continueVisible) return false;
    const safeDefaultMissing = new Set([
      'SELECT_PRODUCT_MISSING_CURRENTLY_INSURED',
      'SELECT_PRODUCT_MISSING_OWN_RENT'
    ]);
    return (selectProduct.missingRequired || []).every((item) => safeDefaultMissing.has(item));
  };
  const advisorStateAllowedNextActions = (route, product, prefillGate, rapport, blockers, selectProduct, ascDriversVehicles, insuranceGate) => {
    if (blockers.length) return [];
    switch (route) {
      case 'CUSTOMER_SUMMARY_PREFILL_GATE':
        return prefillGate.startHereVisible ? ['start_prefill'] : [];
      case 'PRODUCT_OVERVIEW':
        if (product.autoVisible && !product.autoSelected) return ['select_auto_product'];
        if (product.autoSelected && product.saveContinueVisible) return ['continue_to_gather_data'];
        return [];
      case 'SELECT_PRODUCT':
        return advisorSelectProductDefaultActionAvailable(selectProduct) ? ['answer_select_product'] : [];
      case 'RAPPORT':
        return rapport.present ? advisorStateUnique(['inspect_rapport', rapport.vehicleCount > 0 ? 'confirm_vehicles' : '', advisorStateHasActionText(/create quotes|save\s*&\s*continue|continue/i) ? 'continue_from_rapport' : '']) : [];
      case 'CONSUMER_REPORTS':
        return ['review_consumer_reports'];
      case 'ASC_DRIVERS_VEHICLES':
        if (ascDriversVehicles && ascDriversVehicles.nextRecommendedAction === 'save_inline_participant_panel')
          return ['save_inline_participant_panel'];
        if (ascDriversVehicles && (ascDriversVehicles.unresolvedDriverCount > 0 || ascDriversVehicles.unresolvedVehicleCount > 0))
          return ['human_review_required'];
        return [];
      case 'ASC_CREDIT_HIT_NOT_RECEIVED':
        return insuranceGate && insuranceGate.continueVisible && insuranceGate.continueEnabled && insuranceGate.creditHitNotReceived ? ['continue_credit_hit_not_received_gate'] : [];
      case 'ASC_EXTRA_INFO_INSURANCE':
        return insuranceGate && insuranceGate.continueVisible && insuranceGate.continueEnabled && insuranceGate.provisionalDefaultsAllowed ? ['apply_provisional_insurance_defaults'] : [];
      case 'ASC_PRIOR_INSURANCE_NOT_FOUND':
        return insuranceGate && insuranceGate.continueVisible && insuranceGate.continueEnabled && insuranceGate.provisionalDefaultsAllowed ? ['apply_provisional_insurance_defaults'] : [];
      case 'COVERAGES':
        return ['review_coverages'];
      case 'PURCHASE':
        return ['review_purchase'];
      case 'ADVISOR_OTHER':
      case 'ENTRY_CREATE_FORM':
      case 'DUPLICATE_CURRENT_CUSTOMER':
        return ['human_review_required'];
      default:
        return [];
    }
  };
  const advisorStateSnapshot = (source = {}) => {
    const url = pageUrl();
    const text = bodyText();
    const title = compact(document.title || '', 120);
    const product = readAdvisorProductSnapshotState(source);
    const prefillGate = readAdvisorPrefillGateSnapshotState(source);
    const rapport = readAdvisorRapportSnapshotState(source);
    const selectProduct = readAdvisorSelectProductSnapshotState(source);
    const ascDriversVehicles = readAdvisorAscDriversVehiclesSnapshotState(source);
    const insuranceGate = readAdvisorInsuranceGateSnapshotState(source);
    const iframe = readAdvisorIframeSnapshotState();
    const blockers = advisorStateBlockers(source);
    const anchors = [];
    if (url) anchors.push(`url:${compact(url, 140)}`);
    if (title) anchors.push(`title:${title}`);
    anchors.push(...advisorStateHeadingAnchors());

    let route = 'UNKNOWN_UNSAFE';
    let confidence = 0.1;
    let unsafeReason = 'Low confidence: unsupported page from read-only evidence.';
    const customerStatus = customerSummaryOverviewStatus(source);
    const entryStart = advisorStateEntryStartInfo();
    const ascKind = advisorStateAscPageKind();
    const productOverviewRoute = isProductOverviewPage(source);
    const productOverviewCandidate = advisorStateProductOverviewUrlCandidate(source);
    const consumerReportsRoute = isConsumerReportsPage(source);
    const consumerReportsCandidate = advisorStateConsumerReportsCandidate(source);
    const driversVehiclesRoute = isDriversAndVehiclesPage(source);
    const driversVehiclesCandidate = advisorStateAscDriversVehiclesCandidate(ascDriversVehicles);
    const insuranceGateRoute = advisorInsuranceGateKindToRoute(insuranceGate.kind);

    if (entryStart.present) {
      route = entryStart.duplicateEvidence ? 'DUPLICATE_CURRENT_CUSTOMER' : 'ENTRY_CREATE_FORM';
      confidence = entryStart.startUrl ? 0.84 : 0.68;
      unsafeReason = entryStart.duplicateEvidence
        ? 'Advisor entry/start page has duplicate or current-customer evidence; human review is required before choosing a next action.'
        : 'Advisor entry/start page recognized; read-only snapshot cannot safely choose whether to begin quoting or create a prospect.';
      anchors.push(entryStart.startUrl ? 'url:/apps/intel/102/start' : 'url:/apps/intel/102/', entryStart.entryEvidence ? 'text:entry-start-actions' : '', entryStart.duplicateEvidence ? 'text:duplicate-current-customer' : '', entryStart.visibleEvidence);
    } else if (customerStatus.result === 'DETECTED' && prefillGate.startHereVisible) {
      route = 'CUSTOMER_SUMMARY_PREFILL_GATE';
      confidence = 0.93;
      unsafeReason = null;
      anchors.push('url:/apps/customer-summary/', 'text:START HERE', customerStatus.evidence);
    } else if (customerStatus.result === 'PARTIAL') {
      route = 'ADVISOR_OTHER';
      confidence = 0.55;
      unsafeReason = 'Customer summary evidence is incomplete; human review is required before choosing a next action.';
      anchors.push('partial:customer-summary', customerStatus.evidence);
    } else if (productOverviewRoute || productOverviewCandidate) {
      route = 'PRODUCT_OVERVIEW';
      confidence = product.autoVisible ? 0.92 : (productOverviewRoute ? 0.82 : 0.72);
      unsafeReason = product.autoVisible ? null : 'Product overview route detected, but the Auto product tile/status evidence was not resolved.';
      anchors.push('url:/apps/intel/102/overview', productOverviewRoute ? 'text:Select Product' : 'route-candidate:url-only', product.autoVisible ? 'product:Auto' : '');
    } else if (isSelectProductFormPage(source)) {
      route = 'SELECT_PRODUCT';
      confidence = selectProduct.product || selectProduct.ratingState ? 0.92 : 0.84;
      unsafeReason = selectProduct.missingRequired.length
        ? `Select Product missing required fields: ${selectProduct.missingRequired.join('|')}`
        : null;
      anchors.push('url:/selectProduct', 'heading:Select Product', 'control:SelectProduct.Product', 'control:selectProductContinue');
    } else if (isGatherDataPage(source)) {
      route = 'RAPPORT';
      confidence = 0.88;
      unsafeReason = null;
      anchors.push('url:/apps/intel/102/rapport', 'text:Gather Data', rapport.present ? 'snapshot:gather_rapport' : '');
    } else if (consumerReportsRoute || consumerReportsCandidate) {
      route = 'CONSUMER_REPORTS';
      confidence = consumerReportsRoute ? 0.86 : 0.8;
      unsafeReason = null;
      anchors.push('url:/apps/ASCPRODUCT/', 'text:order consumer reports');
    } else if (driversVehiclesRoute || driversVehiclesCandidate) {
      route = 'ASC_DRIVERS_VEHICLES';
      confidence = ascDriversVehicles.driversAndVehiclesHeadingPresent ? 0.91 : 0.82;
      unsafeReason = ascDriversVehicles.blockers.length
        ? `ASC Drivers/Vehicles blockers: ${ascDriversVehicles.blockers.join('|')}`
        : null;
      anchors.push('url:/apps/ASCPRODUCT/', 'text:Drivers and vehicles', ascDriversVehicles.inlineParticipantPanelPresent ? 'panel:inline-participant' : '', ascDriversVehicles.blockerCode ? `blocker:${ascDriversVehicles.blockerCode}` : '');
    } else if (insuranceGateRoute) {
      route = insuranceGateRoute;
      confidence = insuranceGate.fieldsPresent || insuranceGate.creditHitNotReceived ? 0.86 : 0.78;
      unsafeReason = `Known ASCPRODUCT gate ${insuranceGate.kind}; provisional workflow handling requires client verification before bind or purchase.`;
      anchors.push('url:/apps/ASCPRODUCT/', `gate:${insuranceGate.kind}`, insuranceGate.fieldsPresent ? 'controls:insurance-gate-fields' : '', insuranceGate.creditHitNotReceived ? 'status:credit-hit-not-received' : '');
    } else if (ascKind) {
      route = ascKind;
      confidence = 0.82;
      unsafeReason = null;
      anchors.push('url:/apps/ASCPRODUCT/', ascKind === 'PURCHASE' ? 'text:purchase' : 'text:coverages');
    } else if (driversVehiclesRoute || isIncidentsPage(source) || isQuoteLandingPage(source) || isAscProductPage(source)) {
      route = 'ADVISOR_OTHER';
      confidence = 0.68;
      unsafeReason = 'Advisor Pro ASC page recognized, but this snapshot does not expose a supported top-level route for it yet.';
      anchors.push('url:/apps/ASCPRODUCT/', driversVehiclesRoute ? 'text:Drivers and vehicles' : '', isIncidentsPage(source) ? 'text:Incidents' : '');
    } else if (url.includes('advisorpro.allstate.com') || text.includes('allstate advisor pro')) {
      route = 'ADVISOR_OTHER';
      confidence = 0.45;
      unsafeReason = 'Advisor Pro page recognized, but no supported workflow state was identified from read-only evidence.';
      anchors.push('advisorpro-origin');
    }

    if (blockers.length) {
      confidence = Math.min(confidence, 0.78);
      const blockerReason = `Blocking UI or alert evidence is present: ${blockers.join(' | ')}`;
      unsafeReason = unsafeReason ? `${unsafeReason} ${blockerReason}` : blockerReason;
    }

    const allowedNextActions = advisorStateAllowedNextActions(route, product, prefillGate, rapport, blockers, selectProduct, ascDriversVehicles, insuranceGate);
    if (route === 'SELECT_PRODUCT' && allowedNextActions.includes('answer_select_product'))
      unsafeReason = null;
    if ((route === 'ASC_CREDIT_HIT_NOT_RECEIVED' || route === 'ASC_EXTRA_INFO_INSURANCE' || route === 'ASC_PRIOR_INSURANCE_NOT_FOUND') && allowedNextActions.length)
      unsafeReason = null;
    if (!allowedNextActions.length && route !== 'UNKNOWN_UNSAFE' && !unsafeReason)
      unsafeReason = `Recognized ${route}, but no safe next action is clear from read-only evidence.`;

    return {
      ok: true,
      op: 'advisor_state_snapshot',
      ts: new Date().toISOString(),
      url,
      route,
      confidence: Number(confidence.toFixed(2)),
      anchors: advisorStateUnique(anchors).slice(0, 14),
      blockers,
      product,
      selectProduct,
      ascDriversVehicles,
      insuranceGate,
      prefillGate,
      rapport,
      iframe,
      allowedNextActions,
      unsafeReason
    };
  };
  const escapeRegexText = (value) => safe(value).replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  const vinPatternCompatible = (vinValue, optionText) => {
    const vin = normalizeVehicleVin(vinValue);
    if (!vin) return false;
    const optionPatternText = safe(optionText).toUpperCase().replace(/[^A-Z0-9*]/g, ' ');
    const patterns = (optionPatternText.match(/[A-Z0-9*]{6,17}/g) || [])
      .filter((token) => token.includes('*') && /\d/.test(token));
    return patterns.some((pattern) => {
      const regex = new RegExp(pattern.split('*').map(escapeRegexText).join('[A-Z0-9]*'));
      return regex.test(vin);
    });
  };
  const vehicleEditHintMatches = (optionText, hint) => {
    const wanted = normalizeVehicleText(hint);
    if (!wanted) return false;
    const optionNorm = normalizeVehicleText(optionText);
    const tokens = wanted.split(/\s+/).filter((token) => token.length > 1);
    if (!tokens.length) return false;
    return tokens.every((token) => new RegExp(`(^|[^A-Z0-9])${escapeRegexText(token)}([^A-Z0-9]|$)`).test(optionNorm));
  };
  const chooseVehicleEditSubModelOption = (select, source = {}, status = {}) => {
    const options = Array.from((select && select.options) || []).filter(validVehicleOption);
    if (!options.length) return { option: null, method: '', count: 0 };
    const vin = safe(source.vin || status.vinValue);
    if (vin) {
      const vinMatches = options.filter((opt) => vinPatternCompatible(vin, vehicleOptionText(opt)));
      if (vinMatches.length)
        return { option: vinMatches[0], method: 'vin-pattern', count: options.length };
    }
    const hints = [
      source.trim,
      source.trimHint,
      source.drivetrain,
      source.body,
      source.bodyStyle
    ].map((value) => safe(value).trim()).filter(Boolean);
    for (const hint of hints) {
      const matches = options.filter((opt) => vehicleEditHintMatches(vehicleOptionText(opt), hint));
      if (matches.length === 1)
        return { option: matches[0], method: 'trim-match', count: options.length };
    }
    return { option: options[0], method: 'first-valid', count: options.length };
  };
  const handleVehicleEditModal = (source = {}) => {
    const status = readVehicleEditStatusFields();
    if (status.result === 'NO_MODAL') {
      return lineResult({
        result: 'NO_MODAL',
        method: 'vehicle-edit-not-found',
        yearValue: status.yearValue,
        vinValue: status.vinValue,
        manufacturerValue: status.manufacturerValue,
        modelValue: status.modelValue,
        subModelSelectedValue: '',
        subModelSelectedText: '',
        subModelSelectionMethod: '',
        subModelOptionCount: status.subModelOptionCount,
        updateButtonPresent: status.updateButtonPresent,
        updateButtonEnabled: status.updateButtonEnabled,
        updateClicked: '0',
        failedFields: status.missing,
        evidence: status.evidence
      });
    }
    if (status.result === 'UPDATE_REQUIRED_READY') {
      const updateButton = findVehicleEditUpdateButton();
      const clicked = updateButton && !isDisabledLike(updateButton) && clickCenterEl(updateButton);
      return lineResult({
        result: clicked ? 'UPDATED' : 'FAILED',
        method: clicked ? 'complete-panel-update-clicked' : 'complete-panel-update-click-failed',
        yearValue: status.yearValue,
        vinValue: status.vinValue,
        manufacturerValue: status.manufacturerValue,
        modelValue: status.modelValue,
        subModelSelectedValue: status.subModelValue,
        subModelSelectedText: status.subModelText,
        subModelSelectionMethod: 'already-complete',
        subModelOptionCount: status.subModelOptionCount,
        updateButtonPresent: status.updateButtonPresent,
        updateButtonEnabled: status.updateButtonEnabled,
        updateClicked: clicked ? '1' : '0',
        failedFields: clicked ? '' : ['updateButton'],
        evidence: status.evidence
      });
    }
    const subModel = vehicleEditField('SubModel');
    if (!subModel || !visible(subModel)) {
      const updateButton = findVehicleEditUpdateButton();
      if (status.result === 'UPDATE_REQUIRED_READY' && updateButton && !isDisabledLike(updateButton)) {
        const clicked = clickCenterEl(updateButton);
        return lineResult({
          result: clicked ? 'UPDATED' : 'FAILED',
          method: clicked ? 'complete-panel-update-clicked' : 'complete-panel-update-click-failed',
          yearValue: status.yearValue,
          vinValue: status.vinValue,
          manufacturerValue: status.manufacturerValue,
          modelValue: status.modelValue,
          subModelSelectedValue: status.subModelValue,
          subModelSelectedText: status.subModelText,
          subModelSelectionMethod: 'already-complete',
          subModelOptionCount: status.subModelOptionCount,
          updateButtonPresent: status.updateButtonPresent,
          updateButtonEnabled: status.updateButtonEnabled,
          updateClicked: clicked ? '1' : '0',
          failedFields: clicked ? '' : ['updateButton'],
          evidence: status.evidence
        });
      }
      return lineResult({
        result: 'NO_ACTION_NEEDED',
        method: 'submodel-not-present',
        yearValue: status.yearValue,
        vinValue: status.vinValue,
        manufacturerValue: status.manufacturerValue,
        modelValue: status.modelValue,
        subModelSelectedValue: '',
        subModelSelectedText: '',
        subModelSelectionMethod: '',
        subModelOptionCount: status.subModelOptionCount,
        updateButtonPresent: status.updateButtonPresent,
        updateButtonEnabled: status.updateButtonEnabled,
        updateClicked: '0',
        failedFields: '',
        evidence: status.evidence
      });
    }
    const selectedOption = Array.from(subModel.options || []).find((opt) => opt.selected) || null;
    if (selectedOption && validVehicleOption(selectedOption) && safe(subModel.value).trim()) {
      const updateButton = findVehicleEditUpdateButton();
      if (status.result === 'UPDATE_REQUIRED_READY' && updateButton && !isDisabledLike(updateButton)) {
        const clicked = clickCenterEl(updateButton);
        return linesOut({
          result: clicked ? 'UPDATED' : 'FAILED',
          method: clicked ? 'complete-panel-update-clicked' : 'complete-panel-update-click-failed',
          yearValue: status.yearValue,
          vinValue: status.vinValue,
          manufacturerValue: status.manufacturerValue,
          modelValue: status.modelValue,
          subModelSelectedValue: safe(subModel.value),
          subModelSelectedText: vehicleOptionText(selectedOption),
          subModelSelectionMethod: 'already-selected',
          subModelOptionCount: status.subModelOptionCount,
          updateButtonPresent: status.updateButtonPresent,
          updateButtonEnabled: status.updateButtonEnabled,
          updateClicked: clicked ? '1' : '0',
          failedFields: clicked ? '' : ['updateButton'],
          evidence: status.evidence
        });
      }
      return linesOut({
        result: 'NO_ACTION_NEEDED',
        method: 'submodel-already-selected',
        yearValue: status.yearValue,
        vinValue: status.vinValue,
        manufacturerValue: status.manufacturerValue,
        modelValue: status.modelValue,
        subModelSelectedValue: safe(subModel.value),
        subModelSelectedText: vehicleOptionText(selectedOption),
        subModelSelectionMethod: 'already-selected',
        subModelOptionCount: status.subModelOptionCount,
        updateButtonPresent: status.updateButtonPresent,
        updateButtonEnabled: status.updateButtonEnabled,
        updateClicked: '0',
        failedFields: '',
        evidence: status.evidence
      });
    }
    const choice = chooseVehicleEditSubModelOption(subModel, source, status);
    if (!choice.option) {
      return lineResult({
        result: 'NO_SUBMODEL_OPTIONS',
        method: 'submodel-options-missing',
        yearValue: status.yearValue,
        vinValue: status.vinValue,
        manufacturerValue: status.manufacturerValue,
        modelValue: status.modelValue,
        subModelSelectedValue: '',
        subModelSelectedText: '',
        subModelSelectionMethod: '',
        subModelOptionCount: status.subModelOptionCount,
        updateButtonPresent: status.updateButtonPresent,
        updateButtonEnabled: status.updateButtonEnabled,
        updateClicked: '0',
        failedFields: ['subModel'],
        evidence: status.evidence
      });
    }
    const selected = applyVehicleDropdownOption(subModel, choice.option);
    const afterSelected = Array.from(subModel.options || []).find((opt) => opt.selected) || null;
    if (!selected || !afterSelected || !validVehicleOption(afterSelected)) {
      return lineResult({
        result: 'FAILED',
        method: 'submodel-selection-failed',
        yearValue: status.yearValue,
        vinValue: status.vinValue,
        manufacturerValue: status.manufacturerValue,
        modelValue: status.modelValue,
        subModelSelectedValue: safe(subModel.value),
        subModelSelectedText: afterSelected ? vehicleOptionText(afterSelected) : '',
        subModelSelectionMethod: choice.method,
        subModelOptionCount: String(choice.count),
        updateButtonPresent: status.updateButtonPresent,
        updateButtonEnabled: status.updateButtonEnabled,
        updateClicked: '0',
        failedFields: ['subModel'],
        evidence: status.evidence
      });
    }
    const updateButton = findVehicleEditUpdateButton();
    if (!updateButton || isDisabledLike(updateButton)) {
      return lineResult({
        result: 'FAILED',
        method: 'update-button-unavailable',
        yearValue: status.yearValue,
        vinValue: status.vinValue,
        manufacturerValue: status.manufacturerValue,
        modelValue: status.modelValue,
        subModelSelectedValue: safe(subModel.value),
        subModelSelectedText: vehicleOptionText(afterSelected),
        subModelSelectionMethod: choice.method,
        subModelOptionCount: String(choice.count),
        updateButtonPresent: updateButton ? '1' : '0',
        updateButtonEnabled: updateButton && !isDisabledLike(updateButton) ? '1' : '0',
        updateClicked: '0',
        failedFields: ['updateButton'],
        evidence: status.evidence
      });
    }
    const clicked = clickCenterEl(updateButton);
    return lineResult({
      result: clicked ? 'UPDATED' : 'FAILED',
      method: clicked ? 'submodel-selected-update-clicked' : 'update-click-failed',
      yearValue: status.yearValue,
      vinValue: status.vinValue,
      manufacturerValue: status.manufacturerValue,
      modelValue: status.modelValue,
      subModelSelectedValue: safe(subModel.value),
      subModelSelectedText: vehicleOptionText(afterSelected),
      subModelSelectionMethod: choice.method,
      subModelOptionCount: String(choice.count),
      updateButtonPresent: '1',
      updateButtonEnabled: '1',
      updateClicked: clicked ? '1' : '0',
      failedFields: clicked ? '' : ['updateButton'],
      evidence: status.evidence
    });
  };

  const detectAdvisorRuntimeState = (source = {}) => {
    const url = pageUrl();
    const text = bodyText();
    const selectors = getSelectorArgs(source);
    const isCustomerSummaryOverview = isCustomerSummaryOverviewPage(source);
    const isRapport = isGatherDataPage(source);
    const isProductOverview = isProductOverviewPage(source);
    const isSelectProductForm = isSelectProductFormPage(source);
    const isIncidents = isIncidentsPage(source);
    const isAsc = isAscProductPage(source);

    if (isCustomerSummaryOverview) return 'CUSTOMER_SUMMARY_OVERVIEW';
    if (isDuplicatePage(source)) return 'DUPLICATE';
    if (isRapport) return 'RAPPORT';
    if (isProductOverview) return 'PRODUCT_OVERVIEW';
    if (isSelectProductForm) return 'SELECT_PRODUCT';
    if (isIncidents) return 'INCIDENTS';
    if (isAsc) return 'ASC_PRODUCT';
    if (safe(selectors.searchCreateNewProspectId) && findByStableId(selectors.searchCreateNewProspectId)) return 'BEGIN_QUOTING_SEARCH';
    if (safe(selectors.beginQuotingContinueId) && findByStableId(selectors.beginQuotingContinueId)) return 'BEGIN_QUOTING_FORM';
    if (safe(selectors.advisorQuotingButtonId) && findByStableId(selectors.advisorQuotingButtonId)) return 'ADVISOR_HOME';
    if (url.includes('advisorpro.allstate.com')) return 'ADVISOR_OTHER';
    if (text.includes('allstate advisor pro')) return 'GATEWAY';
    return 'NO_CONTEXT';
  };

  const advisorRunnerHost = () => {
    if (typeof globalThis !== 'undefined') return globalThis;
    if (typeof window !== 'undefined') return window;
    return null;
  };
  const advisorRunnerNow = () => Date.now();
  const advisorRunnerClampInt = (value, fallback, min, max) => {
    const parsed = Number.parseInt(String(value ?? ''), 10);
    if (!Number.isFinite(parsed)) return fallback;
    return Math.max(min, Math.min(max, parsed));
  };
  const advisorRunnerBool = (value) => {
    const normalized = lower(value);
    return value === true || normalized === '1' || normalized === 'true' || normalized === 'yes';
  };
  const advisorRunnerRouteFamily = (state = '') => {
    const url = pageUrl();
    const stateText = safe(state);
    if (url.includes('/apps/intel/102/')) return 'INTEL_102';
    if (url.includes('/apps/ASCPRODUCT/')) return 'ASCPRODUCT';
    if (url.includes('/apps/customer-summary/')) return 'CUSTOMER_SUMMARY';
    if (stateText === 'GATEWAY' || lower(bodyText()).includes('allstate advisor pro')) return 'GATEWAY';
    if (['BEGIN_QUOTING_SEARCH', 'BEGIN_QUOTING_FORM', 'ADVISOR_HOME', 'ADVISOR_OTHER'].includes(stateText)) return 'ADVISOR_HOME';
    return 'UNKNOWN';
  };
  const advisorRunnerModalPresent = () => {
    const selectors = [
      'dialog',
      '[role="dialog"]',
      '[aria-modal="true"]',
      '.modal',
      '.ReactModal__Content'
    ];
    return selectors.some((selector) => {
      try {
        return Array.from(document.querySelectorAll(selector)).some((node) => visible(node) && compact(getText(node), 80));
      } catch {
        return false;
      }
    });
  };
  const advisorRunnerReadPage = (source = {}) => {
    const detectedState = detectAdvisorRuntimeState(source);
    return {
      url: compact(pageUrl(), 240),
      routeFamily: advisorRunnerRouteFamily(detectedState),
      detectedState,
      modalPresent: advisorRunnerModalPresent() ? '1' : '0'
    };
  };
  const advisorRunnerEventSummary = (value) => {
    if (value == null) return '';
    if (typeof value === 'string') return compact(value, 220);
    try { return compact(JSON.stringify(value), 220); } catch {}
    return compact(String(value), 220);
  };
  const advisorRunnerAllowedReadOnlyConditions = Object.freeze([
    'on_customer_summary_overview',
    'on_product_overview',
    'gather_data',
    'is_rapport',
    'is_select_product',
    'is_asc',
    'consumer_reports_ready',
    'drivers_or_incidents',
    'after_driver_vehicle_continue',
    'quote_landing',
    'incidents_done',
    'continue_enabled',
    'vehicle_select_enabled',
    'vehicle_added_tile',
    'vehicle_confirmed'
  ]);
  const advisorRunnerAllowedReadOnlyStatusOps = Object.freeze([
    'detect_state',
    'advisor_state_snapshot',
    'gather_rapport_snapshot',
    'gather_start_quoting_status',
    'gather_confirmed_vehicles_status',
    'asc_drivers_vehicles_snapshot',
    'asc_participant_detail_status',
    'asc_driver_rows_status',
    'asc_vehicle_rows_status',
    'product_overview_tile_status',
    'customer_summary_overview_status',
    'address_verification_status',
    'prospect_form_status',
    'gather_vehicle_add_status',
    'gather_vehicle_row_status',
    'gather_vehicle_edit_status'
  ]);
  const advisorRunnerDisallowedMutatingOps = Object.freeze([
    'click_product_overview_tile',
    'ensure_product_overview_tile_selected',
    'click_product_overview_subnav_from_rapport',
    'click_customer_summary_start_here',
    'handle_address_verification',
    'handle_duplicate_prospect',
    'fill_gather_defaults',
    'confirm_potential_vehicle',
    'prepare_vehicle_row',
    'set_vehicle_year_and_wait_manufacturer',
    'handle_vehicle_edit_modal',
    'ensure_start_quoting_auto_checkbox',
    'ensure_auto_start_quoting_state',
    'click_create_quotes_order_reports',
    'click_start_quoting_add_product',
    'set_select_product_defaults',
    'select_vehicle_dropdown_option',
    'select_vehicle_dropdown_first_valid_nonplaceholder',
    'asc_ensure_non_driver_participant_panel_ready',
    'fill_participant_modal',
    'select_remove_reason',
    'fill_vehicle_modal',
    'handle_incidents',
    'click_by_id',
    'click_by_text',
    'asc_resolve_participant_marital_and_spouse',
    'asc_reconcile_driver_rows',
    'asc_reconcile_vehicle_rows',
    'cancel_stale_add_vehicle_row'
  ]);
  const advisorRunnerList = (value) => {
    if (Array.isArray(value)) return value.map((item) => safe(item).trim()).filter(Boolean);
    return safe(value).split(/[|,;\s]+/).map((item) => item.trim()).filter(Boolean);
  };
  const advisorRunnerAllowedByCaller = (name, sourceValue) => {
    const names = advisorRunnerList(sourceValue);
    return !names.length || names.includes(name);
  };
  const readAdvisorWaitCondition = (source = {}) => {
    const name = safe(source.name || source.conditionName);
    const url = pageUrl();
    switch (name) {
      case 'post_prospect_submit':
        return (url.includes(safe(source.rapportContains)) || url.includes(safe(source.selectProductContains)) || isCustomerSummaryOverviewPage(source) || isProductOverviewPage(source) || isDuplicatePage(source) || isAddressVerificationPage()) ? '1' : '0';
      case 'prospect_form_ready': {
        const selectors = source.selectors || {};
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
        return (isCustomerSummaryOverviewPage(source) || isGatherDataPage(source) || url.includes(safe(source.selectProductContains)) || isProductOverviewPage(source) || isSelectProductFormPage(source)) ? '1' : '0';
      case 'gather_data':
        return isGatherDataPage(source) ? '1' : '0';
      case 'on_customer_summary_overview':
        return isCustomerSummaryOverviewPage(source) ? '1' : '0';
      case 'on_product_overview':
        return isProductOverviewPage(source) ? '1' : '0';
      case 'to_select_product':
        return isSelectProductFormPage(source) ? '1' : '0';
      case 'gather_start_quoting_transition':
        return (isConsumerReportsPage(source) || isDriversAndVehiclesPage(source) || isIncidentsPage(source) || isQuoteLandingPage(source)) ? '1' : '0';
      case 'vehicle_added_tile':
        return isVehicleAlreadyListedMatch(source) ? '1' : '0';
      case 'vehicle_confirmed':
        return isVehicleAlreadyListedMatch(source) ? '1' : '0';
      case 'vehicle_select_enabled': {
        const idx = Number(source.index);
        const fieldName = safe(source.fieldName);
        const minOptions = Number(source.minOptions || 1);
        const el = document.getElementById(`ConsumerData.Assets.Vehicles[${idx}].${fieldName}`);
        return (!!el && !el.disabled && (el.options || []).length >= minOptions) ? '1' : '0';
      }
      case 'on_select_product':
        return isSelectProductFormPage(source) ? '1' : '0';
      case 'select_product_to_consumer':
        return (isConsumerReportsPage(source) || isDriversAndVehiclesPage(source) || isIncidentsPage(source) || isQuoteLandingPage(source)) ? '1' : '0';
      case 'consumer_reports_ready':
        return isConsumerReportsPage(source) ? '1' : '0';
      case 'drivers_or_incidents':
        return (isDriversAndVehiclesPage(source) || isIncidentsPage(source)) ? '1' : '0';
      case 'after_driver_vehicle_continue':
        return (isIncidentsPage(source) || isQuoteLandingPage(source)) ? '1' : '0';
      case 'add_asset_modal_closed':
        return document.getElementById(safe(source.addAssetSaveId)) ? '0' : '1';
      case 'continue_enabled': {
        const btn = document.getElementById(safe(source.buttonId));
        return (!!btn && !btn.disabled) ? '1' : '0';
      }
      case 'incidents_done':
        return isQuoteLandingPage(source) ? '1' : '0';
      case 'quote_landing':
        return isQuoteLandingPage(source) ? '1' : '0';
      case 'is_duplicate':
        return isDuplicatePage(source) ? '1' : '0';
      case 'is_customer_summary_overview':
        return isCustomerSummaryOverviewPage(source) ? '1' : '0';
      case 'is_rapport':
        return isGatherDataPage(source) ? '1' : '0';
      case 'is_product_overview':
        return isProductOverviewPage(source) ? '1' : '0';
      case 'is_select_product':
        return isSelectProductFormPage(source) ? '1' : '0';
      case 'is_asc':
        return isAscProductPage(source) ? '1' : '0';
      case 'is_incidents':
        return isIncidentsPage(source) ? '1' : '0';
      default:
        return '0';
    }
  };
  const readProspectFormStatus = (source = {}) => {
    const selectors = source.selectors || {};
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
    const submit = findByStableId(selectors.beginQuotingContinueId || source.submitId);
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
  };
  const readAdvisorStatusOp = (opName, source = {}) => {
    switch (opName) {
      case 'detect_state':
        return detectAdvisorRuntimeState(source);
      case 'prospect_form_status':
        return readProspectFormStatus(source);
      case 'address_verification_status':
        return formatLineResult(addressVerificationStatusFields(), 'address_verification_status');
      case 'gather_rapport_snapshot':
        return linesOut(readGatherRapportSnapshotFields(source));
      case 'gather_start_quoting_status':
        return linesOut(buildStartQuotingStatus(source));
      case 'gather_confirmed_vehicles_status':
        return gatherConfirmedVehiclesStatus(source);
      case 'asc_drivers_vehicles_snapshot':
        return linesOut(readAscDriversVehiclesSnapshotFields(source));
      case 'asc_participant_detail_status':
        return linesOut(ascParticipantDetailStatus(source));
      case 'asc_driver_rows_status':
        return linesOut(ascDriverRowsStatus(source));
      case 'asc_vehicle_rows_status':
        return linesOut(ascVehicleRowsStatus(source));
      case 'product_overview_tile_status':
        return linesOut(readOverviewProductTileState(source));
      case 'customer_summary_overview_status':
        return linesOut(customerSummaryOverviewStatus(source));
      case 'gather_vehicle_add_status':
        return gatherVehicleAddStatus(source);
      case 'gather_vehicle_row_status':
        return linesOut(gatherVehicleRowStatus(source));
      case 'gather_vehicle_edit_status':
        return linesOut(readVehicleEditStatusFields());
      default:
        return '';
    }
  };
  const advisorRunnerPayloadLines = (value) => {
    const text = safe(value).replace(/\r/g, '');
    const lines = text ? text.split('\n') : [];
    const out = { payloadLineCount: String(lines.length) };
    lines.forEach((line, index) => {
      out[`payloadLine${index + 1}`] = line;
    });
    return out;
  };
  const advisorResidentOperatorReadOnlyStatusOps = Object.freeze([
    'detect_state',
    'gather_rapport_snapshot',
    'gather_confirmed_vehicles_status',
    'gather_start_quoting_status',
    'gather_vehicle_add_status',
    'gather_vehicle_row_status',
    'gather_vehicle_edit_status',
    'product_overview_tile_status',
    'customer_summary_overview_status',
    'address_verification_status',
    'prospect_form_status'
  ]);
  const advisorResidentOperatorReadOnlyWaitConditions = Object.freeze([
    'gather_data',
    'is_rapport',
    'duplicate_to_next',
    'vehicle_select_enabled'
  ]);
  const advisorResidentOperatorMutationOps = Object.freeze([
    'click_by_id',
    'click_by_text',
    'click_customer_summary_start_here',
    'click_product_overview_tile',
    'select_vehicle_dropdown_option',
    'prepare_vehicle_row',
    'confirm_potential_vehicle',
    'fill_gather_defaults',
    'fill_participant_modal'
  ]);
  const advisorResidentOperatorRegistry = () => ({
    readOnlyStatusOps: advisorResidentOperatorReadOnlyStatusOps.slice(),
    readOnlyWaitConditions: advisorResidentOperatorReadOnlyWaitConditions.slice(),
    mutationOps: advisorResidentOperatorMutationOps.slice()
  });
  const advisorResidentOperatorFailure = (operator, result, extra = {}) => {
    const page = advisorRunnerReadPage(extra.source || {});
    const payload = Object.assign({
      result,
      blockedReason: safe(extra.blockedReason || '').trim(),
      op: compact(extra.op || '', 100),
      waitConditionName: compact(extra.waitConditionName || '', 100),
      requestId: compact(extra.requestId || '', 120),
      version: operator && operator.version || '',
      buildHash: operator && operator.buildHash || '',
      installedAt: operator && operator.installedAt || '',
      url: page.url,
      routeFamily: page.routeFamily,
      detectedState: page.detectedState,
      elapsedMs: safe(extra.elapsedMs || '0'),
      mutatingRequestRefused: safe(extra.mutatingRequestRefused || '0')
    }, extra.fields || {});
    delete payload.source;
    operator.lastResult = {
      requestId: payload.requestId,
      op: payload.op,
      waitConditionName: payload.waitConditionName,
      result,
      blockedReason: payload.blockedReason,
      elapsedMs: payload.elapsedMs,
      valueLength: '0'
    };
    return linesOut(payload);
  };
  const advisorResidentOperatorStatusFields = (operator, source = {}) => {
    const page = advisorRunnerReadPage(source);
    const expectedBuildHash = safe(source.__residentExpectedBuildHash || source.expectedBuildHash).trim();
    const expectedHost = safe(source.__residentExpectedHost || source.expectedHost).trim();
    let result = 'OK';
    let blockedReason = '';
    if (expectedBuildHash && expectedBuildHash !== operator.buildHash) {
      result = 'STALE_BUILD';
      blockedReason = 'stale-build';
    } else if (expectedHost && !page.url.includes(expectedHost)) {
      result = 'WRONG_CONTEXT';
      blockedReason = 'wrong-context';
    }
    return {
      result,
      blockedReason,
      running: '0',
      stopRequested: '0',
      version: operator.version,
      buildHash: operator.buildHash,
      installedAt: operator.installedAt,
      url: page.url,
      routeFamily: page.routeFamily,
      detectedState: page.detectedState,
      lastResult: operator.lastResult && operator.lastResult.result || '',
      lastBlockedReason: operator.lastResult && operator.lastResult.blockedReason || '',
      requestCount: String(operator.requestCount || 0),
      readOnlyStatusOpCount: String(advisorResidentOperatorReadOnlyStatusOps.length),
      readOnlyWaitConditionCount: String(advisorResidentOperatorReadOnlyWaitConditions.length),
      mutationOpCount: String(advisorResidentOperatorMutationOps.length)
    };
  };
  const createAdvisorResidentOperator = (version, buildHash) => {
    const operator = {
      version,
      buildHash,
      installedAt: new Date(advisorRunnerNow()).toISOString(),
      registry: advisorResidentOperatorRegistry(),
      requestCount: 0,
      lastResult: null,
      health(source = {}) {
        return advisorResidentOperatorStatusFields(this, source);
      },
      status(source = {}) {
        return advisorResidentOperatorStatusFields(this, source);
      },
      run(opName, source = {}, requestId = '') {
        const started = advisorRunnerNow();
        const opText = safe(opName).trim();
        const args = source && typeof source === 'object' ? source : {};
        const conditionName = opText === 'wait_condition' ? safe(args.name || args.conditionName).trim() : '';
        const elapsed = () => String(Math.max(0, advisorRunnerNow() - started));
        this.requestCount += 1;

        try {
          if (!opText) {
            return advisorResidentOperatorFailure(this, 'REFUSED', {
              op: opText,
              requestId,
              source: args,
              elapsedMs: elapsed(),
              blockedReason: 'missing-op'
            });
          }

          const status = this.status(args);
          if (status.result === 'STALE_BUILD') {
            return advisorResidentOperatorFailure(this, 'STALE_BUILD', {
              op: opText,
              waitConditionName: conditionName,
              requestId,
              source: args,
              elapsedMs: elapsed(),
              blockedReason: 'stale-build'
            });
          }
          if (status.result === 'WRONG_CONTEXT') {
            return advisorResidentOperatorFailure(this, 'WRONG_CONTEXT', {
              op: opText,
              waitConditionName: conditionName,
              requestId,
              source: args,
              elapsedMs: elapsed(),
              blockedReason: 'wrong-context'
            });
          }

          if (opText === 'wait_condition') {
            if (!advisorResidentOperatorReadOnlyWaitConditions.includes(conditionName)) {
              return advisorResidentOperatorFailure(this, 'REFUSED', {
                op: opText,
                waitConditionName: conditionName,
                requestId,
                source: args,
                elapsedMs: elapsed(),
                blockedReason: 'wait-condition-not-allowed'
              });
            }
            const value = readAdvisorWaitCondition(Object.assign({}, args, { name: conditionName }));
            this.lastResult = {
              requestId: compact(requestId, 120),
              op: opText,
              waitConditionName: conditionName,
              result: 'OK',
              blockedReason: '',
              elapsedMs: elapsed(),
              valueLength: String(safe(value).length)
            };
            return value;
          }

          if (advisorResidentOperatorMutationOps.includes(opText)) {
            if (!advisorRunnerBool(args.__residentMutationEnabled || args.mutationEnabled)) {
              return advisorResidentOperatorFailure(this, 'REFUSED', {
                op: opText,
                requestId,
                source: args,
                elapsedMs: elapsed(),
                blockedReason: 'mutation-disabled',
                mutatingRequestRefused: '1'
              });
            }
            return advisorResidentOperatorFailure(this, 'REFUSED', {
              op: opText,
              requestId,
              source: args,
              elapsedMs: elapsed(),
              blockedReason: 'mutation-not-implemented',
              mutatingRequestRefused: '1'
            });
          }

          if (!advisorResidentOperatorReadOnlyStatusOps.includes(opText)) {
            return advisorResidentOperatorFailure(this, 'REFUSED', {
              op: opText,
              requestId,
              source: args,
              elapsedMs: elapsed(),
              blockedReason: 'op-not-allowed'
            });
          }

          const value = readAdvisorStatusOp(opText, args);
          if (!safe(value).trim()) {
            return advisorResidentOperatorFailure(this, 'EMPTY', {
              op: opText,
              requestId,
              source: args,
              elapsedMs: elapsed(),
              blockedReason: 'empty-result'
            });
          }
          this.lastResult = {
            requestId: compact(requestId, 120),
            op: opText,
            waitConditionName: '',
            result: 'OK',
            blockedReason: '',
            elapsedMs: elapsed(),
            valueLength: String(safe(value).length)
          };
          return value;
        } catch (err) {
          return advisorResidentOperatorFailure(this, 'ERROR', {
            op: opText,
            waitConditionName: conditionName,
            requestId,
            source: args,
            elapsedMs: elapsed(),
            blockedReason: 'js-error',
            fields: { message: compact((err && err.message) || err, 240) }
          });
        }
      }
    };
    return operator;
  };
  const advisorResidentOperatorCommand = (source = {}) => {
    const host = advisorRunnerHost();
    if (!host) {
      return linesOut({
        result: 'ERROR',
        blockedReason: 'no-global-host',
        version: '',
        buildHash: '',
        installedAt: '',
        url: compact(pageUrl(), 240),
        routeFamily: 'UNKNOWN',
        detectedState: 'NO_CONTEXT'
      });
    }
    const command = safe(source.command || source.cmd || 'bootstrap').trim() || 'bootstrap';
    const version = safe(source.version || 'phase1').trim() || 'phase1';
    const buildHash = safe(source.buildHash || 'dev').trim() || 'dev';
    const existing = host.__advisorQuoteResidentOperator || null;

    if (command === 'status' || command === 'health') {
      if (!existing || typeof existing.run !== 'function') {
        const page = advisorRunnerReadPage(source);
        return linesOut({
          result: 'MISSING',
          blockedReason: 'missing-resident-operator',
          version: '',
          buildHash: '',
          installedAt: '',
          url: page.url,
          routeFamily: page.routeFamily,
          detectedState: page.detectedState,
          requestCount: '0'
        });
      }
      return linesOut(existing.status(source));
    }

    if (command !== 'bootstrap') {
      return linesOut({
        result: 'REFUSED',
        blockedReason: 'unknown-command',
        command: compact(command, 80)
      });
    }

    if (existing && existing.version === version && existing.buildHash === buildHash && typeof existing.run === 'function') {
      const status = existing.status(source);
      return linesOut(Object.assign({}, status, {
        result: 'ALREADY_BOOTSTRAPPED',
        message: 'resident-operator-present'
      }));
    }
    if (existing && !advisorRunnerBool(source.replaceStale)) {
      const status = existing.status(source);
      return linesOut(Object.assign({}, status, {
        result: 'STALE',
        blockedReason: 'replace-stale-required',
        message: 'replaceStale-required'
      }));
    }

    const operator = createAdvisorResidentOperator(version, buildHash);
    host.__advisorQuoteResidentOperator = operator;
    const status = operator.status(source);
    return linesOut(Object.assign({}, status, {
      result: existing ? 'STALE_REPLACED' : 'OK',
      message: existing ? 'resident-operator-replaced' : 'resident-operator-created'
    }));
  };
  const createAdvisorResidentRunner = (version, buildHash, maxEventCount) => {
    const runnerId = `advisor-runner-${advisorRunnerNow()}-${Math.floor(Math.random() * 100000)}`;
    const maxEvents = advisorRunnerClampInt(maxEventCount, 200, 20, 500);
    const runner = {
      version,
      buildHash,
      runnerId,
      createdAt: new Date(advisorRunnerNow()).toISOString(),
      urlAtBootstrap: pageUrl(),
      running: false,
      stopRequested: false,
      stepCount: 0,
      eventSeq: 0,
      events: [],
      maxEventCount: maxEvents,
      lastAction: '',
      lastError: '',
      lastBlockedReason: '',
      addEvent(type, message = '', data = {}) {
        this.eventSeq += 1;
        const event = {
          seq: this.eventSeq,
          ts: new Date(advisorRunnerNow()).toISOString(),
          type: compact(type, 80),
          message: compact(message, 160),
          url: compact(pageUrl(), 240),
          data: advisorRunnerEventSummary(data)
        };
        this.events.push(event);
        while (this.events.length > this.maxEventCount)
          this.events.shift();
        return event;
      },
      readPage(source = {}) {
        return advisorRunnerReadPage(source);
      },
      status(source = {}) {
        const expectedBuildHash = safe(source.expectedBuildHash).trim();
        if (expectedBuildHash && expectedBuildHash !== this.buildHash) {
          const page = this.readPage(source);
          return {
            result: 'STALE_BUILD',
            running: this.running ? '1' : '0',
            stopRequested: this.stopRequested ? '1' : '0',
            version: this.version,
            buildHash: this.buildHash,
            url: page.url,
            routeFamily: page.routeFamily,
            detectedState: page.detectedState,
            lastBlockedReason: this.lastBlockedReason,
            eventSeq: String(this.eventSeq),
            eventCount: String(this.events.length)
          };
        }
        const expectedHost = safe(source.expectedHost).trim();
        const page = this.readPage(source);
        if (expectedHost && !page.url.includes(expectedHost)) {
          return {
            result: 'WRONG_CONTEXT',
            running: this.running ? '1' : '0',
            stopRequested: this.stopRequested ? '1' : '0',
            version: this.version,
            buildHash: this.buildHash,
            url: page.url,
            routeFamily: page.routeFamily,
            detectedState: page.detectedState,
            lastBlockedReason: this.lastBlockedReason,
            eventSeq: String(this.eventSeq),
            eventCount: String(this.events.length)
          };
        }
        return {
          result: 'OK',
          running: this.running ? '1' : '0',
          stopRequested: this.stopRequested ? '1' : '0',
          version: this.version,
          buildHash: this.buildHash,
          url: page.url,
          routeFamily: page.routeFamily,
          detectedState: page.detectedState,
          lastBlockedReason: this.lastBlockedReason,
          eventSeq: String(this.eventSeq),
          eventCount: String(this.events.length)
        };
      },
      stop(reason = '') {
        this.stopRequested = true;
        this.lastAction = 'stop';
        this.addEvent('stop', reason || 'stop-requested');
        return {
          result: 'OK',
          stopRequested: '1',
          running: this.running ? '1' : '0',
          reason: compact(reason || 'stop-requested', 160)
        };
      },
      reset(clearEvents = false, reason = '') {
        if (this.running) {
          return {
            result: 'BUSY',
            eventCount: String(this.events.length),
            stopRequested: this.stopRequested ? '1' : '0',
            running: '1'
          };
        }
        this.stopRequested = false;
        this.lastAction = '';
        this.lastError = '';
        this.lastBlockedReason = '';
        if (clearEvents) this.events = [];
        this.addEvent('reset', reason || 'reset');
        return {
          result: 'OK',
          eventCount: String(this.events.length),
          stopRequested: '0',
          running: '0'
        };
      },
      getEvents(source = {}) {
        const sinceSeq = advisorRunnerClampInt(source.sinceSeq, 0, 0, Number.MAX_SAFE_INTEGER);
        const limit = advisorRunnerClampInt(source.limit, 50, 1, 100);
        const selected = this.events.filter((event) => event.seq > sinceSeq).slice(0, limit);
        let truncated = '0';
        let eventsJson = JSON.stringify(selected);
        const maxChars = advisorRunnerClampInt(source.maxChars, 6000, 1000, 12000);
        if (eventsJson.length > maxChars) {
          truncated = '1';
          while (selected.length && JSON.stringify(selected).length > maxChars)
            selected.pop();
          eventsJson = JSON.stringify(selected);
        }
        return {
          result: 'OK',
          fromSeq: selected.length ? String(selected[0].seq) : '',
          toSeq: selected.length ? String(selected[selected.length - 1].seq) : '',
          eventCount: String(selected.length),
          truncated,
          eventsJson
        };
      },
      runUntilBlocked(source = {}) {
        if (!advisorRunnerBool(source.readOnly)) {
          this.lastBlockedReason = 'mutating-request-refused';
          this.addEvent('blocked', 'mutating-request-refused', { readOnly: source.readOnly });
          const page = this.readPage(source);
          return {
            result: 'BLOCKED',
            blockedReason: 'mutating-request-refused',
            steps: '0',
            elapsedMs: '0',
            url: page.url,
            routeFamily: page.routeFamily,
            detectedState: page.detectedState,
            lastStatusOp: 'readPage',
            manualRequired: '1',
            mutatingRequestRefused: '1',
            eventSeq: String(this.eventSeq)
          };
        }
        const expectedBuildHash = safe(source.expectedBuildHash).trim();
        if (expectedBuildHash && expectedBuildHash !== this.buildHash) {
          const page = this.readPage(source);
          this.lastBlockedReason = 'stale-build';
          this.addEvent('blocked', 'stale-build', { expectedBuildHash });
          return {
            result: 'STALE_BUILD',
            blockedReason: 'stale-build',
            steps: '0',
            elapsedMs: '0',
            url: page.url,
            routeFamily: page.routeFamily,
            detectedState: page.detectedState,
            lastStatusOp: 'readPage',
            manualRequired: '1',
            eventSeq: String(this.eventSeq)
          };
        }
        const maxSteps = advisorRunnerClampInt(source.maxSteps, 1, 1, 3);
        const maxMs = source.maxMs === undefined ? 250 : advisorRunnerClampInt(source.maxMs, 0, 0, 250);
        const started = advisorRunnerNow();
        let steps = 0;
        let page = this.readPage(source);
        this.running = true;
        this.lastAction = 'runUntilBlocked';
        this.addEvent('run-start', 'runUntilBlocked', { maxSteps, maxMs });
        try {
          if (maxMs <= 0) {
            this.lastBlockedReason = 'max-ms';
            this.addEvent('blocked', 'max-ms');
            return {
              result: 'TIMEOUT',
              blockedReason: 'max-ms',
              steps: '0',
              elapsedMs: String(Math.max(0, advisorRunnerNow() - started)),
              url: page.url,
              routeFamily: page.routeFamily,
              detectedState: page.detectedState,
              lastStatusOp: 'readPage',
              manualRequired: '0',
              eventSeq: String(this.eventSeq)
            };
          }
          while (steps < maxSteps) {
            if (this.stopRequested) {
              this.lastBlockedReason = 'stop-requested';
              this.addEvent('blocked', 'stop-requested');
              return {
                result: 'STOPPED',
                blockedReason: 'stop-requested',
                steps: String(steps),
                elapsedMs: String(Math.max(0, advisorRunnerNow() - started)),
                url: page.url,
                routeFamily: page.routeFamily,
                detectedState: page.detectedState,
                lastStatusOp: 'readPage',
                manualRequired: '1',
                eventSeq: String(this.eventSeq)
              };
            }
            if ((advisorRunnerNow() - started) >= maxMs) {
              this.lastBlockedReason = 'max-ms';
              this.addEvent('blocked', 'max-ms');
              return {
                result: 'TIMEOUT',
                blockedReason: 'max-ms',
                steps: String(steps),
                elapsedMs: String(Math.max(0, advisorRunnerNow() - started)),
                url: page.url,
                routeFamily: page.routeFamily,
                detectedState: page.detectedState,
                lastStatusOp: 'readPage',
                manualRequired: '0',
                eventSeq: String(this.eventSeq)
              };
            }
            page = this.readPage(source);
            steps += 1;
            this.stepCount += 1;
            this.addEvent('step', 'read-page', {
              routeFamily: page.routeFamily,
              detectedState: page.detectedState
            });
            if (page.routeFamily === 'UNKNOWN' || page.detectedState === 'NO_CONTEXT') {
              this.lastBlockedReason = 'unknown-route';
              this.addEvent('blocked', 'unknown-route', page);
              return {
                result: 'BLOCKED',
                blockedReason: 'unknown-route',
                steps: String(steps),
                elapsedMs: String(Math.max(0, advisorRunnerNow() - started)),
                url: page.url,
                routeFamily: page.routeFamily,
                detectedState: page.detectedState,
                lastStatusOp: 'readPage',
                manualRequired: '1',
                eventSeq: String(this.eventSeq)
              };
            }
            if (page.modalPresent === '1' && !advisorRunnerBool(source.allowModal)) {
              this.lastBlockedReason = 'unexpected-modal';
              this.addEvent('blocked', 'unexpected-modal', page);
              return {
                result: 'BLOCKED',
                blockedReason: 'unexpected-modal',
                steps: String(steps),
                elapsedMs: String(Math.max(0, advisorRunnerNow() - started)),
                url: page.url,
                routeFamily: page.routeFamily,
                detectedState: page.detectedState,
                lastStatusOp: 'readPage',
                manualRequired: '1',
                eventSeq: String(this.eventSeq)
              };
            }
          }
          this.lastBlockedReason = 'max-steps';
          this.addEvent('blocked', 'max-steps', { steps });
          return {
            result: 'MAX_STEPS',
            blockedReason: 'max-steps',
            steps: String(steps),
            elapsedMs: String(Math.max(0, advisorRunnerNow() - started)),
            url: page.url,
            routeFamily: page.routeFamily,
            detectedState: page.detectedState,
            lastStatusOp: 'readPage',
            manualRequired: '0',
            eventSeq: String(this.eventSeq)
          };
        } catch (err) {
          this.lastError = safe(err && err.message || err);
          this.lastBlockedReason = 'error';
          this.addEvent('error', this.lastError);
          page = this.readPage(source);
          return {
            result: 'ERROR',
            blockedReason: 'error',
            steps: String(steps),
            elapsedMs: String(Math.max(0, advisorRunnerNow() - started)),
            url: page.url,
            routeFamily: page.routeFamily,
            detectedState: page.detectedState,
            lastStatusOp: 'readPage',
            manualRequired: '1',
            eventSeq: String(this.eventSeq)
          };
        } finally {
          this.running = false;
        }
      },
      runReadOnlyPoll(source = {}) {
        const conditionName = safe(source.conditionName || source.name).trim();
        const statusOp = safe(source.statusOp || source.opName).trim();
        const requestedName = conditionName || statusOp;
        const started = advisorRunnerNow();
        let steps = 0;
        let lastValue = '';
        let page = this.readPage(source);
        const baseResult = (result, extra = {}) => Object.assign({
          result,
          conditionName,
          statusOp,
          matched: '0',
          steps: String(steps),
          elapsedMs: String(Math.max(0, advisorRunnerNow() - started)),
          url: page.url,
          routeFamily: page.routeFamily,
          detectedState: page.detectedState,
          lastValue: compact(lastValue, 240),
          blockedReason: '',
          eventSeq: String(this.eventSeq),
          readOnly: '1',
          mutatingRequestRefused: '0'
        }, advisorRunnerBool(source.returnPayloadLines) ? advisorRunnerPayloadLines(lastValue) : {}, extra);

        if (!advisorRunnerBool(source.readOnly)) {
          this.lastBlockedReason = 'read-only-required';
          this.addEvent('blocked', 'read-only-required', { requestedName });
          return baseResult('REFUSED', {
            blockedReason: 'read-only-required',
            readOnly: advisorRunnerBool(source.readOnly) ? '1' : '0',
            mutatingRequestRefused: '1'
          });
        }
        if (!requestedName) {
          this.lastBlockedReason = 'missing-read-only-target';
          this.addEvent('blocked', 'missing-read-only-target');
          return baseResult('REFUSED', { blockedReason: 'missing-read-only-target' });
        }
        if (advisorRunnerDisallowedMutatingOps.includes(requestedName)) {
          this.lastBlockedReason = 'mutating-op-refused';
          this.addEvent('blocked', 'mutating-op-refused', { requestedName });
          return baseResult('REFUSED', {
            blockedReason: 'mutating-op-refused',
            mutatingRequestRefused: '1'
          });
        }
        if (conditionName) {
          if (!advisorRunnerAllowedReadOnlyConditions.includes(conditionName) || !advisorRunnerAllowedByCaller(conditionName, source.allowedConditions)) {
            this.lastBlockedReason = 'condition-not-allowed';
            this.addEvent('blocked', 'condition-not-allowed', { conditionName });
            return baseResult('REFUSED', { blockedReason: 'condition-not-allowed' });
          }
        } else if (!advisorRunnerAllowedReadOnlyStatusOps.includes(statusOp) || !advisorRunnerAllowedByCaller(statusOp, source.allowedStatusOps)) {
          this.lastBlockedReason = 'status-op-not-allowed';
          this.addEvent('blocked', 'status-op-not-allowed', { statusOp });
          return baseResult('REFUSED', { blockedReason: 'status-op-not-allowed' });
        }

        const expectedBuildHash = safe(source.expectedBuildHash).trim();
        if (expectedBuildHash && expectedBuildHash !== this.buildHash) {
          this.lastBlockedReason = 'stale-build';
          this.addEvent('blocked', 'stale-build', { expectedBuildHash });
          return baseResult('STALE_BUILD', { blockedReason: 'stale-build' });
        }
        const expectedHost = safe(source.expectedHost).trim();
        if (expectedHost && !page.url.includes(expectedHost)) {
          this.lastBlockedReason = 'wrong-context';
          this.addEvent('blocked', 'wrong-context', { expectedHost, url: page.url });
          return baseResult('WRONG_CONTEXT', { blockedReason: 'wrong-context' });
        }

        const timeoutMs = source.timeoutMs === undefined ? 1 : advisorRunnerClampInt(source.timeoutMs, 0, 0, 250);
        const pollMs = 0;
        const maxSteps = advisorRunnerClampInt(source.maxSteps, 1, 1, 3);
        const requireKnownRoute = source.requireKnownRoute === undefined ? true : advisorRunnerBool(source.requireKnownRoute);

        this.running = true;
        this.lastAction = 'runReadOnlyPoll';
        this.addEvent('poll-start', 'runReadOnlyPoll', { conditionName, statusOp, timeoutMs, pollMs, maxSteps });
        try {
          if (timeoutMs <= 0) {
            this.lastBlockedReason = 'timeout';
            return baseResult('TIMEOUT', { blockedReason: 'timeout' });
          }
          while (steps < maxSteps) {
            if (this.stopRequested) {
              this.lastBlockedReason = 'stop-requested';
              this.addEvent('blocked', 'stop-requested', { conditionName, statusOp });
              return baseResult('STOPPED', { blockedReason: 'stop-requested' });
            }
            page = this.readPage(source);
            if (requireKnownRoute && (page.routeFamily === 'UNKNOWN' || page.detectedState === 'NO_CONTEXT')) {
              this.lastBlockedReason = 'unknown-route';
              this.addEvent('blocked', 'unknown-route', page);
              return baseResult('WRONG_CONTEXT', { blockedReason: 'unknown-route' });
            }
            steps += 1;
            this.stepCount += 1;
            if (conditionName) {
              lastValue = readAdvisorWaitCondition(Object.assign({}, source.conditionArgs || {}, source, { name: conditionName }));
              if (lastValue === '1') {
                this.lastBlockedReason = '';
                this.addEvent('poll-match', conditionName, { steps });
                return baseResult('OK', { matched: '1', blockedReason: '' });
              }
            } else {
              lastValue = readAdvisorStatusOp(statusOp, Object.assign({}, source.conditionArgs || {}, source));
              if (safe(lastValue).trim()) {
                this.lastBlockedReason = '';
                this.addEvent('poll-status', statusOp, { steps });
                return baseResult('OK', { matched: '1', blockedReason: '' });
              }
            }
          }
          this.lastBlockedReason = 'max-steps';
          this.addEvent('blocked', 'max-steps', { conditionName, statusOp, steps });
          return baseResult('MAX_STEPS', { blockedReason: 'max-steps' });
        } catch (err) {
          this.lastError = safe(err && err.message || err);
          this.lastBlockedReason = 'error';
          this.addEvent('error', this.lastError, { conditionName, statusOp });
          page = this.readPage(source);
          return baseResult('ERROR', { blockedReason: 'error', lastValue: compact(this.lastError, 240) });
        } finally {
          this.running = false;
        }
      },
      handleTinyCommand(source = {}) {
        const command = safe(source.command || source.cmd).trim() || 'status';
        if (command === 'bootstrap') {
          const page = this.readPage(source);
          return linesOut({
            result: 'ALREADY_BOOTSTRAPPED',
            runnerId: this.runnerId,
            version: this.version,
            buildHash: this.buildHash,
            url: page.url,
            state: page.detectedState,
            eventSeq: String(this.eventSeq),
            message: 'runner-present'
          });
        }
        if (command === 'status') return linesOut(this.status(source));
        if (command === 'stop') return linesOut(this.stop(safe(source.reason || '')));
        if (command === 'reset') return linesOut(this.reset(advisorRunnerBool(source.clearEvents), safe(source.reason || '')));
        if (command === 'getEvents') return linesOut(this.getEvents(source));
        if (command === 'runUntilBlocked') {
          return linesOut(this.runUntilBlocked(Object.assign({}, source, {
            maxSteps: String(advisorRunnerClampInt(source.maxSteps, 1, 1, 3)),
            maxMs: String(advisorRunnerClampInt(source.maxMs, 250, 0, 250))
          })));
        }
        if (command === 'runReadOnlyPoll' || command === 'readWaitConditionOnce') {
          return linesOut(this.runReadOnlyPoll(Object.assign({}, source, {
            timeoutMs: '1',
            pollMs: '0',
            maxSteps: '1'
          })));
        }
        return linesOut({
          result: 'ERROR',
          running: this.running ? '1' : '0',
          stopRequested: this.stopRequested ? '1' : '0',
          reason: `unknown-command:${compact(command, 80)}`
        });
      }
    };
    runner.addEvent('bootstrap', 'runner-created', { version, buildHash });
    return runner;
  };
  const advisorResidentRunnerCommand = (source = {}) => {
    const host = advisorRunnerHost();
    if (!host) {
      return linesOut({
        result: 'ERROR',
        runnerId: '',
        version: '',
        buildHash: '',
        url: compact(pageUrl(), 240),
        state: 'NO_CONTEXT',
        eventSeq: '',
        message: 'no-global-host'
      });
    }
    const command = safe(source.command || source.cmd).trim() || 'status';
    try {
      if (command === 'bootstrap') {
        const version = safe(source.version || 'phase1').trim() || 'phase1';
        const buildHash = safe(source.buildHash || 'dev').trim() || 'dev';
        const existing = host.__advisorRunner || null;
        const replaceStale = advisorRunnerBool(source.replaceStale);
        if (existing && existing.version === version && existing.buildHash === buildHash && typeof existing.handleTinyCommand === 'function') {
          const page = advisorRunnerReadPage(source);
          if (typeof existing.addEvent === 'function')
            existing.addEvent('bootstrap', 'already-bootstrapped');
          return linesOut({
            result: 'ALREADY_BOOTSTRAPPED',
            runnerId: existing.runnerId || '',
            version: existing.version || '',
            buildHash: existing.buildHash || '',
            url: page.url,
            state: page.detectedState,
            eventSeq: String(existing.eventSeq || 0),
            message: 'runner-present'
          });
        }
        if (existing) {
          if (existing.running) {
            const page = advisorRunnerReadPage(source);
            return linesOut({
              result: 'BUSY',
              runnerId: existing.runnerId || '',
              version: existing.version || '',
              buildHash: existing.buildHash || '',
              url: page.url,
              state: page.detectedState,
              eventSeq: String(existing.eventSeq || 0),
              message: 'stale-runner-running'
            });
          }
          if (!replaceStale) {
            const page = advisorRunnerReadPage(source);
            return linesOut({
              result: 'STALE',
              runnerId: existing.runnerId || '',
              version: existing.version || '',
              buildHash: existing.buildHash || '',
              url: page.url,
              state: page.detectedState,
              eventSeq: String(existing.eventSeq || 0),
              message: 'replaceStale-required'
            });
          }
        }
        const runner = createAdvisorResidentRunner(version, buildHash, source.maxEventCount);
        host.__advisorRunner = runner;
        const page = runner.readPage(source);
        return linesOut({
          result: existing ? 'STALE_REPLACED' : 'OK',
          runnerId: runner.runnerId,
          version: runner.version,
          buildHash: runner.buildHash,
          url: page.url,
          state: page.detectedState,
          eventSeq: String(runner.eventSeq),
          message: existing ? 'stale-runner-replaced' : 'runner-created'
        });
      }

      const runner = host.__advisorRunner || null;
      if (!runner) {
        if (command === 'status') {
          return linesOut({
            result: 'MISSING',
            running: '0',
            stopRequested: '0',
            version: '',
            buildHash: '',
            url: compact(pageUrl(), 240),
            routeFamily: advisorRunnerRouteFamily(detectAdvisorRuntimeState(source)),
            detectedState: detectAdvisorRuntimeState(source),
            lastBlockedReason: '',
            eventSeq: '',
            eventCount: '0'
          });
        }
        return linesOut({ result: 'MISSING', stopRequested: '0', running: '0', reason: safe(source.reason || '') });
      }

      if (typeof runner.handleTinyCommand === 'function')
        return runner.handleTinyCommand(source);

      if (command === 'status') return linesOut(runner.status(source));
      if (command === 'stop') return linesOut(runner.stop(safe(source.reason || '')));
      if (command === 'reset') return linesOut(runner.reset(advisorRunnerBool(source.clearEvents), safe(source.reason || '')));
      if (command === 'getEvents') return linesOut(runner.getEvents(source));
      if (command === 'runUntilBlocked') return linesOut(runner.runUntilBlocked(source));
      if (command === 'runReadOnlyPoll') return linesOut(runner.runReadOnlyPoll(source));
      return linesOut({
        result: 'ERROR',
        running: runner.running ? '1' : '0',
        stopRequested: runner.stopRequested ? '1' : '0',
        reason: `unknown-command:${compact(command, 80)}`
      });
    } catch (err) {
      const page = advisorRunnerReadPage(source);
      return linesOut({
        result: 'ERROR',
        runnerId: host.__advisorRunner && host.__advisorRunner.runnerId || '',
        version: host.__advisorRunner && host.__advisorRunner.version || '',
        buildHash: host.__advisorRunner && host.__advisorRunner.buildHash || '',
        url: page.url,
        state: page.detectedState,
        eventSeq: host.__advisorRunner && String(host.__advisorRunner.eventSeq || 0) || '',
        message: compact((err && err.message) || err, 240)
      });
    }
  };

  switch (safe(op)) {
    case 'detect_state': {
      return detectAdvisorRuntimeState(args);
    }

    case 'resident_runner_command':
      return advisorResidentRunnerCommand(args);

    case 'resident_operator_bootstrap':
    case 'resident_operator_command':
      return advisorResidentOperatorCommand(args);

    case 'click_product_overview_tile': {
      if (!isProductOverviewPage(args)) return 'NOT_OVERVIEW';
      const state = readOverviewProductTileState(args);
      if (state.result === 'NO_TILE') return 'NO_TILE';
      if (state.selected === '1') return 'OK';
      const tile = findOverviewProductTile(args.productText || 'Auto');
      if (!tile) return 'NO_TILE';
      const target = tile.clickableTarget || tile.tileContainer || tile.textNode;
      return clickCenterEl(target) ? 'OK' : 'CLICK_FAILED';
    }

    case 'product_overview_tile_status':
      return linesOut(readOverviewProductTileState(args));

    case 'ensure_product_overview_tile_selected':
      return linesOut(ensureOverviewProductTileSelected(args));

    case 'click_product_overview_subnav_from_rapport':
      return clickProductOverviewSubnavFromRapport(args);

    case 'customer_summary_overview_status':
      return linesOut(customerSummaryOverviewStatus(args));

    case 'click_customer_summary_start_here': {
      const match = findCustomerSummaryStartHereTarget(args);
      const status = match.status || {};
      const target = match.target;
      if (status.urlMatched !== '1' || status.overviewMatched !== '1') {
        return linesOut({
          result: 'NO_CUSTOMER_SUMMARY',
          clicked: '0',
          targetText: '',
          targetTag: '',
          targetClass: '',
          urlBefore: compact(pageUrl(), 240),
          evidence: compact(status.evidence || '', 240)
        });
      }
      if (!target) {
        return linesOut({
          result: 'NO_START_HERE',
          clicked: '0',
          targetText: '',
          targetTag: '',
          targetClass: '',
          urlBefore: compact(pageUrl(), 240),
          evidence: compact(status.evidence || '', 240)
        });
      }
      const clicked = clickCenterEl(target);
      return linesOut({
        result: clicked ? 'OK' : 'CLICK_FAILED',
        clicked: clicked ? '1' : '0',
        targetText: customerSummaryActionText(target),
        targetTag: safe(target.tagName),
        targetClass: compact(safe(target.className), 160),
        urlBefore: compact(pageUrl(), 240),
        evidence: compact(status.evidence || '', 240)
      });
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
      return readProspectFormStatus(args);
    }

    case 'address_verification_status':
      return lineResult(addressVerificationStatusFields());

    case 'handle_address_verification': {
      const status = addressVerificationStatusFields();
      if (status.result !== 'FOUND') {
        return lineResult({
          result: 'NOT_FOUND',
          method: 'address-verification-not-found',
          radioSelected: '0',
          continueButtonPresent: status.continuePresent,
          continueButtonEnabledBefore: status.continueEnabled,
          continueButtonEnabledAfter: status.continueEnabled,
          continueClicked: '0',
          enteredText: status.enteredText,
          suggestions: status.suggestions,
          failedFields: status.missing,
          evidence: status.evidence
        });
      }
      const choice = chooseAddressVerificationOption(args);
      const selected = choice.selected;
      const before = readAddressVerificationContinueState();
      if (choice.result !== 'SELECTED' || !selected) {
        return lineResult({
          result: choice.result,
          method: choice.method,
          selectedValue: selected ? safe(selected.option.value) : '',
          selectedText: selected ? selected.option.text : '',
          selectedIndex: selected ? String(selected.option.index) : '',
          radioSelected: '0',
          continueButtonPresent: before.present,
          continueButtonEnabledBefore: before.enabled,
          continueButtonEnabledAfter: before.enabled,
          continueClicked: '0',
          enteredText: status.enteredText,
          suggestions: status.suggestions,
          matchScore: selected ? String(selected.score) : '',
          matchedBy: selected ? selected.matchedBy : '',
          failedFields: choice.failedFields,
          evidence: status.evidence
        });
      }
      const selection = selectAddressVerificationRadio(selected.option);
      if (!selection.selected) {
        return lineResult({
          result: 'FAILED',
          method: 'address-radio-selection-failed',
          selectedValue: safe(selected.option.value),
          selectedText: selected.option.text,
          selectedIndex: String(selected.option.index),
          radioSelected: selection.radioSelected ? '1' : '0',
          continueButtonPresent: before.present,
          continueButtonEnabledBefore: before.enabled,
          continueButtonEnabledAfter: before.enabled,
          continueClicked: '0',
          enteredText: status.enteredText,
          suggestions: status.suggestions,
          matchScore: String(selected.score),
          matchedBy: selected.matchedBy,
          failedFields: ['snaOption'],
          evidence: status.evidence
        });
      }
      const after = waitForAddressVerificationContinueEnabled();
      if (after.button && after.enabled === '1' && clickCenterEl(after.button)) {
        return lineResult({
          result: 'SELECTED',
          method: choice.method,
          selectedValue: safe(selected.option.value),
          selectedText: selected.option.text,
          selectedIndex: String(selected.option.index),
          radioSelected: '1',
          continueButtonPresent: after.present,
          continueButtonEnabledBefore: before.enabled,
          continueButtonEnabledAfter: after.enabled,
          continueClicked: '1',
          enteredText: status.enteredText,
          suggestions: status.suggestions,
          matchScore: String(selected.score),
          matchedBy: selected.matchedBy,
          unitDroppedOrNotShown: selected.unitDroppedOrNotShown || '0',
          evidence: status.evidence
        });
      }
      return lineResult({
        result: 'FAILED',
        method: 'address-radio-continue-disabled',
        selectedValue: safe(selected.option.value),
        selectedText: selected.option.text,
        selectedIndex: String(selected.option.index),
        radioSelected: '1',
        continueButtonPresent: after.present,
        continueButtonEnabledBefore: before.enabled,
        continueButtonEnabledAfter: after.enabled,
        continueClicked: '0',
        enteredText: status.enteredText,
        suggestions: status.suggestions,
        matchScore: String(selected.score),
        matchedBy: selected.matchedBy,
        unitDroppedOrNotShown: selected.unitDroppedOrNotShown || '0',
        failedFields: ['continueWithSelected'],
        evidence: status.evidence
      });
    }

    case 'handle_duplicate_prospect': {
      const radios = Array.from(document.querySelectorAll('input[type=radio]')).filter(visible);
      const allCandidates = radios
        .map((radio) => buildDuplicateCandidate(radio, args))
        .filter(Boolean);
      const existingCandidates = allCandidates
        .filter((candidate) => candidate.strongIdentity && candidate.optionType !== 'create-new-profile')
        .sort((a, b) => b.score - a.score);
      const sameAddressCandidates = existingCandidates.filter((candidate) => candidate.addressMatch);
      const movedAddressCandidates = existingCandidates.filter((candidate) => !candidate.addressMatch && candidate.sameNamedPerson);
      const createNewOption = findCreateNewDuplicateOption(allCandidates, radios);
      const createNewProfileTextPresent = duplicatePageHasCreateNewProfileText();
      const candidateSummaries = existingCandidates.slice(0, 3).map((candidate) => candidate.summary).join(' || ');
      const allCandidateSummaries = allCandidates.slice(0, 4).map((candidate) => candidate.summary).join(' || ');

      if (sameAddressCandidates.length && duplicateCandidatesAreAmbiguous(sameAddressCandidates)) {
        return lineResult({
          result: 'AMBIGUOUS_DUPLICATE',
          method: 'same-address-ambiguous',
          addressDecision: 'same-address-ambiguous',
          existingAddressMatch: '1',
          newProfileOptionFound: createNewOption ? '1' : '0',
          candidateCount: String(sameAddressCandidates.length),
          rowCount: String(radios.length),
          candidateSummaries
        });
      }

      if (sameAddressCandidates.length) {
        const best = sameAddressCandidates[0];
        return selectDuplicateRadioAndContinue(best, 'select-existing-radio', {
          addressDecision: 'same-address-existing',
          existingAddressMatch: '1',
          newProfileOptionFound: createNewOption ? '1' : '0',
          candidateCount: String(sameAddressCandidates.length),
          rowCount: String(radios.length)
        });
      }

      if (movedAddressCandidates.length) {
        if (createNewOption) {
          return selectDuplicateRadioAndContinue(createNewOption, 'create-new-radio', {
            addressDecision: 'moved-address-create-new',
            existingAddressMatch: '0',
            newProfileOptionFound: '1',
            candidateCount: String(movedAddressCandidates.length),
            rowCount: String(radios.length),
            existingCandidateSummaries: candidateSummaries
          });
        }
        return lineResult({
          result: 'FAILED',
          method: createNewProfileTextPresent ? 'create-new-radio-target-missing' : 'moved-address-create-new-option-missing',
          addressDecision: 'moved-address-create-new',
          existingAddressMatch: '0',
          newProfileOptionFound: createNewProfileTextPresent ? '1' : '0',
          candidateCount: String(movedAddressCandidates.length),
          rowCount: String(radios.length),
          candidateSummaries,
          failedFields: [createNewProfileTextPresent ? 'createNewRadio' : 'newProfileOption']
        });
      }

      if (createNewOption) {
        return selectDuplicateRadioAndContinue(createNewOption, 'create-new-radio', {
          addressDecision: duplicatePageHasExistingProfileText() ? 'moved-address-create-new' : 'no-safe-existing-create-new',
          existingAddressMatch: '0',
          newProfileOptionFound: '1',
          candidateCount: String(existingCandidates.length),
          rowCount: String(radios.length),
          existingCandidateSummaries: candidateSummaries
        });
      }

      if (createNewProfileTextPresent) {
        return lineResult({
          result: 'FAILED',
          method: 'create-new-radio-target-missing',
          addressDecision: 'moved-address-create-new',
          existingAddressMatch: '0',
          newProfileOptionFound: '1',
          candidateCount: String(existingCandidates.length),
          rowCount: String(radios.length),
          candidateSummaries: allCandidateSummaries,
          failedFields: ['createNewRadio']
        });
      }

      const createNewBtn = findCreateNewProspectButton();
      if (createNewBtn && clickCenterEl(createNewBtn)) {
        return lineResult({
          result: 'CREATE_NEW',
          method: 'create-new-button',
          addressDecision: 'no-existing-match-create-new-button',
          existingAddressMatch: '0',
          newProfileOptionFound: '0',
          continueClicked: '0',
          candidateCount: String(existingCandidates.length),
          rowCount: String(radios.length),
          candidateSummaries: allCandidateSummaries
        });
      }

      const fallbackContinue = findDuplicateContinueButton();
      if (fallbackContinue && clickCenterEl(fallbackContinue)) {
        return lineResult({
          result: 'FALLBACK_CONTINUE',
          method: 'fallback-continue',
          addressDecision: 'fallback-continue',
          existingAddressMatch: '0',
          newProfileOptionFound: '0',
          candidateCount: String(existingCandidates.length),
          rowCount: String(radios.length),
          candidateSummaries: allCandidateSummaries
        });
      }

      return lineResult({
        result: 'FAILED',
        method: 'no-safe-duplicate-action',
        addressDecision: 'no-safe-action',
        existingAddressMatch: '0',
        newProfileOptionFound: '0',
        candidateCount: String(existingCandidates.length),
        rowCount: String(radios.length),
        candidateSummaries: allCandidateSummaries,
        failedFields: ['duplicateSelection']
      });
    }

    case 'fill_gather_defaults': {
      const ownershipSelect = Array.from(document.querySelectorAll('select[id]')).find((el) => safe(el.id).endsWith('.ResidenceOwnedRentedCd.SrcCd')) || null;
      const homeTypeSelect = Array.from(document.querySelectorAll('select[id]')).find((el) => safe(el.id).endsWith('.ResidenceTypeCd.SrcCd')) || null;
      const emailInput = Array.from(document.querySelectorAll('input[id]')).find((el) => safe(el.id).endsWith('.Communications.EmailAddr')) || null;
      const ageInput = Array.from(document.querySelectorAll('input[id]')).find((el) => safe(el.id).endsWith('.Driver.AgeFirstLicensed')) || null;
      const ageWanted = safe(args.ageValue).trim();
      const emailWanted = safe(args.emailValue).trim();
      const ownershipWanted = safe(args.ownershipValue).trim();
      const homeTypeWanted = safe(args.homeTypeValue).trim();

      let ageMethod = 'not-requested';
      if (ageWanted) {
        const current = safe(ageInput && ageInput.value).trim();
        if (!ageInput) ageMethod = 'age-missing';
        else if (current === ageWanted) ageMethod = 'already-set';
        else ageMethod = setInputValue(ageInput, ageWanted, false) ? 'input' : 'input-failed';
      }

      let emailMethod = 'not-requested';
      if (emailWanted) {
        const current = safe(emailInput && emailInput.value).trim();
        if (!emailInput) emailMethod = 'email-missing';
        else if (lower(current) === lower(emailWanted)) emailMethod = 'already-set';
        else emailMethod = setInputValue(emailInput, emailWanted, false) ? 'input' : 'input-failed';
      }

      let ownershipMethod = 'not-requested';
      if (ownershipWanted) {
        const current = readSelectState(ownershipSelect);
        if (!ownershipSelect) ownershipMethod = 'ownership-missing';
        else if (matchesNormalizedValue(current.value, ownershipWanted) || matchesNormalizedValue(current.text, ownershipWanted)) ownershipMethod = 'already-set';
        else ownershipMethod = setSelectValue(ownershipSelect, ownershipWanted, false) ? 'select' : 'select-failed';
      }

      let homeTypeMethod = 'not-requested';
      if (homeTypeWanted) {
        const current = readSelectState(homeTypeSelect);
        if (!homeTypeSelect) homeTypeMethod = 'home-type-missing';
        else if (matchesNormalizedValue(current.value, homeTypeWanted) || matchesNormalizedValue(current.text, homeTypeWanted)) homeTypeMethod = 'already-set';
        else homeTypeMethod = setSelectValue(homeTypeSelect, homeTypeWanted, false) ? 'select' : 'select-failed';
      }

      const ownershipState = readSelectState(ownershipSelect);
      const homeTypeState = readSelectState(homeTypeSelect);
      const ageCurrent = safe(ageInput && ageInput.value).trim();
      const emailCurrent = safe(emailInput && emailInput.value).trim();
      const ageApplied = ageWanted ? (ageCurrent === ageWanted ? '1' : '0') : 'SKIP';
      const emailApplied = emailWanted ? (lower(emailCurrent) === lower(emailWanted) ? '1' : '0') : 'SKIP';
      const ownershipApplied = ownershipWanted
        ? ((matchesNormalizedValue(ownershipState.value, ownershipWanted) || matchesNormalizedValue(ownershipState.text, ownershipWanted)) ? '1' : '0')
        : 'SKIP';
      const homeTypeApplied = homeTypeWanted
        ? ((matchesNormalizedValue(homeTypeState.value, homeTypeWanted) || matchesNormalizedValue(homeTypeState.text, homeTypeWanted)) ? '1' : '0')
        : 'SKIP';
      const requiredChecks = [
        ...(ageWanted ? [{ name: 'age', value: ageApplied }] : []),
        ...(ownershipWanted ? [{ name: 'ownership', value: ownershipApplied }] : []),
        ...(homeTypeWanted ? [{ name: 'homeType', value: homeTypeApplied }] : [])
      ];
      const optionalChecks = [
        ...(emailWanted ? [{ name: 'email', value: emailApplied }] : [])
      ];
      const result = resultFromChecks(requiredChecks, optionalChecks);
      return lineResult({
        result,
        method: `age:${ageMethod}|email:${emailMethod}|ownership:${ownershipMethod}|homeType:${homeTypeMethod}`,
        ageApplied,
        emailApplied,
        ownershipApplied,
        homeTypeApplied,
        ageCurrent,
        emailCurrent,
        ownershipCurrentValue: ownershipState.value,
        ownershipCurrentText: ownershipState.text,
        homeTypeCurrentValue: homeTypeState.value,
        homeTypeCurrentText: homeTypeState.text,
        alerts: collectVisibleAlerts().join(' || '),
        failedFields: failedCheckNames(requiredChecks.concat(optionalChecks))
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
      if (!safe(args.year).trim())
        return linesOut({
          result: 'SKIP_MISSING_YEAR',
          matches: '0',
          cardText: '',
          candidateScope: 'rejected',
          confirmButtonCount: '0',
          vehicleTitleCount: '0',
          matchedCardText: '',
          rejectedReason: 'lead-vehicle-year-missing',
          confirmClicked: '0'
        });
      const scoped = findVehicleMatchCandidates(args)
        .map((candidate) => ({ candidate, scope: potentialVehicleCandidateScope(candidate) }));
      const scopedCandidates = scoped.filter((entry) => entry.scope.ok)
        .sort((a, b) => a.candidate.cardText.length - b.candidate.cardText.length);
      const candidates = [];
      for (const entry of scopedCandidates) {
        const entryText = lower(entry.candidate.cardText);
        if (candidates.some((existing) => entryText.includes(lower(existing.candidate.cardText))))
          continue;
        candidates.push(entry);
      }
      const rejected = scoped.find((entry) => entry.scope.rejectedReason) || null;
      if (!candidates.length)
        return linesOut({
          result: 'NO_MATCH',
          matches: '0',
          cardText: '',
          candidateScope: rejected ? rejected.scope.candidateScope : 'rejected',
          confirmButtonCount: rejected ? String(rejected.scope.confirmButtonCount) : '0',
          vehicleTitleCount: rejected ? String(rejected.scope.vehicleTitleCount) : '0',
          matchedCardText: rejected ? compact(rejected.candidate.cardText, 180) : '',
          rejectedReason: rejected ? rejected.scope.rejectedReason : '',
          confirmClicked: '0'
        });
      if (vehicleCandidatesAreAmbiguous(candidates.map((entry) => entry.candidate)))
        return linesOut({
          result: 'AMBIGUOUS',
          matches: String(candidates.length),
          cards: candidates.slice(0, 3).map((entry) => summarizeVehicleCandidate(entry.candidate)).join(' || '),
          candidateScope: 'single-card',
          confirmButtonCount: '1',
          vehicleTitleCount: '1',
          rejectedReason: 'ambiguous-candidates',
          confirmClicked: '0'
        });
      const entry = candidates[0];
      const candidate = entry.candidate;
      const confirmBtn = entry.scope.confirmBtn;
      const cardText = candidate.cardText;
      if (!confirmBtn)
        return linesOut({
          result: 'NO_MATCH',
          matches: '0',
          cardText: '',
          candidateScope: 'rejected',
          confirmButtonCount: '0',
          vehicleTitleCount: String(entry.scope.vehicleTitleCount || 0),
          matchedCardText: compact(cardText, 180),
          rejectedReason: 'confirm-button-missing',
          confirmClicked: '0'
        });
      const clicked = clickCenterEl(confirmBtn);
      return linesOut({
        result: clicked ? 'CONFIRMED' : 'CLICK_FAILED',
        matches: '1',
        cardText,
        score: String(candidate.details.score),
        matchPolicy: candidate.details.matchPolicy || '',
        publicVinEvidence: candidate.details.publicVinEvidence || '',
        candidateScope: 'single-card',
        confirmButtonCount: '1',
        vehicleTitleCount: String(entry.scope.vehicleTitleCount || 1),
        matchedCardText: compact(cardText, 180),
        rejectedReason: '',
        confirmClicked: clicked ? '1' : '0'
      });
    }

    case 'prepare_vehicle_row': {
      const year = safe(args.year);
      if (!year) return '-1';
      let target = findUsableVehicleRowIndex(year);
      if (target < 0) {
        const addButton = findGatherAddVehicleButton();
        if (!addButton || !clickCenterEl(addButton)) return '-1';
        target = waitForUsableVehicleRow(year);
      }
      if (target < 0) return '-1';
      const row = readVehicleRow(target);
      const input = row.year;
      if (!input || !visible(input) || input.disabled || input.readOnly) return '-1';
      if (row.vehicleType && visible(row.vehicleType) && !isDisabledLike(row.vehicleType) && !vehicleFieldValue(row.vehicleType)) {
        const typeOption = findVehicleDropdownOption(row.vehicleType, 'VehTypeCd', 'Car or Truck', true);
        if (typeOption) applyVehicleDropdownOption(row.vehicleType, typeOption);
      }
      if (safe(input.tagName).toUpperCase() === 'SELECT') {
        const yearOption = findVehicleDropdownOption(input, 'ModelYear', year, false);
        if (!yearOption || !applyVehicleDropdownOption(input, yearOption)) return '-1';
      } else {
        try { input.focus(); } catch {}
        input.value = year;
        input.dispatchEvent(new Event('input', { bubbles: true }));
        input.dispatchEvent(new Event('change', { bubbles: true }));
      }
      if (normalizeDigits(input.value) !== normalizeDigits(year)) return '-1';
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
      const allowFirstNonEmpty = String(args.allowFirstNonEmpty || '') === '1' || args.allowFirstNonEmpty === true;
      const returnDetails = String(args.returnDetails || '') === '1' || args.returnDetails === true;
      const select = vehicleField(index, fieldName);
      if (!select || select.disabled) {
        if (returnDetails)
          return linesOut({
            result: 'NO_SELECT',
            selectedValue: '',
            selectedText: '',
            selectedOptionIndex: '',
            provisionalGateVehicle: '0',
            provisionalReason: '',
            ambiguousOptions: '',
            applied: '0'
          });
        return 'NO_SELECT';
      }
      const selected = findVehicleDropdownOptionResult(select, fieldName, args.wantedText, allowFirstNonEmpty, args);
      if (!selected || selected.status === 'NO_OPTION' || selected.status === 'AMBIGUOUS' || !selected.option) {
        const result = selected && selected.status ? selected.status : 'NO_OPTION';
        if (returnDetails)
          return linesOut({
            result,
            selectedValue: '',
            selectedText: '',
            selectedOptionIndex: '',
            provisionalGateVehicle: '0',
            provisionalReason: '',
            ambiguousOptions: selected && selected.ambiguousOptions || '',
            applied: '0'
          });
        return result;
      }
      const applied = applyVehicleDropdownOption(select, selected.option);
      const result = applied ? selected.status : 'NO_OPTION';
      if (returnDetails)
        return linesOut({
          result,
          selectedValue: applied ? vehicleOptionValue(selected.option) : '',
          selectedText: applied ? vehicleOptionText(selected.option) : '',
          selectedOptionIndex: applied ? String(vehicleDropdownOptionIndex(select, selected.option)) : '',
          provisionalGateVehicle: applied && selected.provisionalGateVehicle ? '1' : '0',
          provisionalReason: applied && selected.provisionalGateVehicle ? selected.provisionalReason : '',
          ambiguousOptions: selected.ambiguousOptions || '',
          sameFamilyMatchCount: selected.sameFamilyMatchCount || '',
          applied: applied ? '1' : '0'
        });
      return result;
    }

    case 'select_vehicle_dropdown_first_valid_nonplaceholder': {
      return selectVehicleDropdownFirstValidNonPlaceholder(args);
    }

    case 'gather_vehicle_row_status': {
      return linesOut(gatherVehicleRowStatus(args));
    }

    case 'set_vehicle_year_and_wait_manufacturer': {
      return setVehicleYearAndWaitManufacturer(args);
    }

    case 'gather_vehicle_add_status': {
      return gatherVehicleAddStatus(args);
    }

    case 'gather_stale_add_vehicle_row_status': {
      return linesOut(staleAddVehicleRowStatus(args));
    }

    case 'cancel_stale_add_vehicle_row': {
      return cancelStaleAddVehicleRow(args);
    }

    case 'select_gather_add_row_first_valid_submodel': {
      return selectGatherAddRowFirstValidSubModel(args);
    }

    case 'click_gather_add_row_add_button': {
      return clickGatherAddRowAddButton(args);
    }

    case 'gather_vehicle_edit_status': {
      return linesOut(readVehicleEditStatusFields());
    }

    case 'advisor_active_modal_status': {
      return linesOut(readAdvisorActiveModalStatusFields(args));
    }

    case 'advisor_state_snapshot': {
      return JSON.stringify(advisorStateSnapshot(args));
    }

    case 'asc_credit_hit_not_received_continue': {
      return continueAdvisorCreditHitNotReceivedGate();
    }

    case 'asc_extra_info_insurance_apply_provisional': {
      return applyAdvisorInsuranceGateProvisionalDefaults(
        'ASC_EXTRA_INFO_INSURANCE',
        'EXTRA_INFO_INSURANCE',
        'ASC_EXTRA_INFO_INSURANCE_PROVISIONAL_APPLIED',
        'ASC_EXTRA_INFO_INSURANCE_PROVISIONAL_READBACK_FAILED'
      );
    }

    case 'asc_prior_insurance_not_found_apply_provisional': {
      return applyAdvisorInsuranceGateProvisionalDefaults(
        'ASC_PRIOR_INSURANCE_NOT_FOUND',
        'PRIOR_INSURANCE_NOT_FOUND',
        'ASC_PRIOR_INSURANCE_NOT_FOUND_PROVISIONAL_APPLIED',
        'ASC_PRIOR_INSURANCE_NOT_FOUND_PROVISIONAL_READBACK_FAILED'
      );
    }

    case 'gather_rapport_snapshot': {
      return linesOut(readGatherRapportSnapshotFields(args));
    }

    case 'asc_drivers_vehicles_snapshot': {
      return linesOut(readAscDriversVehiclesSnapshotFields(args));
    }

    case 'handle_vehicle_edit_modal': {
      return handleVehicleEditModal(args);
    }

    case 'gather_confirmed_vehicles_status': {
      return gatherConfirmedVehiclesStatus(args);
    }

    case 'asc_participant_detail_status': {
      return linesOut(ascParticipantDetailStatus(args));
    }

    case 'asc_resolve_participant_marital_and_spouse': {
      return ascResolveParticipantMaritalAndSpouse(args);
    }

    case 'asc_driver_rows_status': {
      return linesOut(ascDriverRowsStatus(args));
    }

    case 'asc_reconcile_driver_rows': {
      return ascReconcileDriverRows(args);
    }

    case 'asc_vehicle_rows_status': {
      return linesOut(ascVehicleRowsStatus(args));
    }

    case 'asc_reconcile_vehicle_rows': {
      return ascReconcileVehicleRows(args);
    }

    case 'gather_start_quoting_status': {
      return linesOut(buildStartQuotingStatus(args));
    }

    case 'ensure_start_quoting_auto_checkbox': {
      return ensureStartQuotingAutoCheckbox(args);
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
      const status = buildStartQuotingStatus(args);
      if (status.startQuotingSectionPresent !== '1') return 'NO_BUTTON';
      if (status.autoProductPresent !== '1' || status.autoProductSelected !== '1') return 'AUTO_NOT_SELECTED';
      const btn = findStartQuotingAddProductLink(args);
      if (!btn) return 'NO_BUTTON';
      if (btn.disabled) return 'DISABLED';
      return clickCenterEl(btn) ? 'OK' : 'CLICK_FAILED';
    }

    case 'set_select_product_defaults':
    case 'ensure_select_product_defaults': {
      const selectors = getSelectorArgs(args);
      const questionText = safe(args.currentInsuredQuestionText || 'Is the customer currently insured?');
      const answerText = safe(args.currentInsuredAnswerText || args.currentInsured || 'Yes');
      const ratingSelect = findByStableId(args.selectProductRatingStateId || selectors.selectProductRatingStateId || 'SelectProduct.RatingState');
      const productSelect = findByStableId(args.selectProductProductId || selectors.selectProductProductId || 'SelectProduct.Product');
      const effectiveDate = findEffectiveDateInput();
      const productWanted = safe(args.productValue || 'AUTO');
      const ratingStateWanted = safe(args.ratingState);

      let productMethod = 'product-missing';
      if (productSelect) {
        const current = readSelectState(productSelect);
        if (matchesNormalizedValue(current.value, productWanted) || matchesNormalizedValue(current.text, productWanted)) productMethod = 'already-selected';
        else if (!current.value || /select\s+one|choose|please select/i.test(current.text)) productMethod = setSelectValue(productSelect, productWanted, false) ? 'stable-select' : 'select-failed';
        else productMethod = 'preserved-existing';
      }

      let ratingStateMethod = 'rating-state-missing';
      if (ratingSelect) {
        const current = readSelectState(ratingSelect);
        if (ratingStateMatches(current.value, current.text, ratingStateWanted)) ratingStateMethod = 'already-selected';
        else if (!current.value || /select\s+one|choose|please select/i.test(current.text)) ratingStateMethod = setSelectValue(ratingSelect, ratingStateWanted, false) ? 'stable-select' : 'select-failed';
        else ratingStateMethod = 'preserved-existing';
      }

      let effectiveDateSet = 'SKIP';
      let effectiveDateMethod = 'not-present';
      const effectiveDateValue = safe(args.effectiveDate || args.selectProductEffectiveDate || '');
      if (effectiveDate) {
        if (safe(effectiveDate.value).trim()) { effectiveDateSet = '1'; effectiveDateMethod = 'already-filled'; }
        else if (effectiveDateValue) { effectiveDateMethod = setInputValue(effectiveDate, effectiveDateValue, false) ? 'input' : 'input-failed'; effectiveDateSet = safe(effectiveDate.value).trim() ? '1' : '0'; }
        else { effectiveDateSet = '0'; effectiveDateMethod = 'empty-no-default'; }
      }

      let currentAddressSet = 'SKIP';
      let currentAddressMethod = 'not-present';
      const currentAddress = readCurrentAddressState();
      if (currentAddress.present) {
        if (currentAddress.selected) { currentAddressSet = '1'; currentAddressMethod = 'already-selected'; }
        else if (currentAddress.safeUnique) { const target = getInputClickTarget(currentAddress.controls[0]) || currentAddress.controls[0]; currentAddressMethod = clickCenterEl(target) ? 'unique-current-address' : 'current-address-click-failed'; currentAddressSet = readCurrentAddressState().selected ? '1' : '0'; }
        else { currentAddressSet = '0'; currentAddressMethod = 'ambiguous-current-address'; }
      }

      let currentInsuredSet = 'SKIP';
      let currentInsuredMethod = 'not-requested';
      const beforeStatus = buildSelectProductStatus(args);
      if (safe(args.currentInsured) && beforeStatus.insuredQuestionRequired === '1' && beforeStatus.insuredQuestionAnswered !== '1') {
        const radioResult = setRadioByName('SelectProduct.CustomerCurrentInsured', args.currentInsured);
        currentInsuredSet = radioResult.ok ? '1' : '0';
        currentInsuredMethod = radioResult.method;
        if (!radioResult.ok) {
          const semanticTarget = findSemanticAnswerTarget(questionText, answerText);
          if (semanticTarget) { currentInsuredSet = clickCenterEl(semanticTarget) ? '1' : '0'; currentInsuredMethod = 'semantic-center'; }
        }
      } else if (beforeStatus.insuredQuestionAnswered === '1') {
        currentInsuredSet = '1';
        currentInsuredMethod = 'already-selected';
      }

      let ownOrRentSet = 'SKIP';
      let ownOrRentMethod = 'not-requested';
      if (safe(args.ownOrRent)) {
        const ownRentQuestionText = safe(args.ownRentQuestionText || 'Does the customer own or rent?');
        const ownOrRentState = readSelectProductOwnRentState(ownRentQuestionText);
        if (ownOrRentState.answered) { ownOrRentSet = '1'; ownOrRentMethod = 'already-selected'; }
        else {
          const ownOrRentResult = setRadioByName('SelectProduct.CustomerOwnOrRent', args.ownOrRent);
          ownOrRentSet = ownOrRentResult.ok ? '1' : '0';
          ownOrRentMethod = ownOrRentResult.method;
          if (!ownOrRentResult.ok) {
            const answerText = safe(args.ownRentAnswerText || selectProductOwnRentAnswerText(args.ownOrRent));
            const answerKey = normUpper(args.ownOrRent).startsWith('RENT') ? 'rentControl' : 'ownControl';
            const scopedTarget = ownOrRentState[answerKey] ? (findClickableTarget(ownOrRentState[answerKey]) || ownOrRentState[answerKey]) : null;
            const semanticTarget = scopedTarget || findSemanticAnswerTarget(ownRentQuestionText, answerText);
            if (semanticTarget) { ownOrRentSet = clickCenterEl(semanticTarget) ? '1' : '0'; ownOrRentMethod = scopedTarget ? 'question-scoped-semantic' : 'semantic-center'; }
          }
        }
      }

      const afterStatus = buildSelectProductStatus(args);
      const productSet = afterStatus.autoSelected;
      const ratingStateSet = ratingStateMatches(afterStatus.ratingStateValue, afterStatus.ratingStateText, ratingStateWanted) ? '1' : afterStatus.ratingStateSelected;
      const result = afterStatus.result === 'READY' ? 'OK' : afterStatus.result;
      return lineResult({
        result,
        method: `product:${productMethod}|ratingState:${ratingStateMethod}|effectiveDate:${effectiveDateMethod}|currentAddress:${currentAddressMethod}|currentInsured:${currentInsuredMethod}|ownOrRent:${ownOrRentMethod}`,
        productSet,
        productMethod,
        ratingStateSet,
        ratingStateMethod,
        effectiveDateSet,
        effectiveDateMethod,
        currentAddressSet,
        currentAddressMethod,
        currentInsuredSet,
        currentInsuredMethod,
        ownOrRentSet,
        ownOrRentMethod,
        ...afterStatus,
        result,
        failedFields: afterStatus.missing
      });
    }

    case 'click_select_product_continue': {
      const status = buildSelectProductStatus(args);
      const continueBtn = findSelectProductContinueButton(args);
      if (status.result !== 'READY') return lineResult({ ...status, result: status.result === 'NOT_SELECT_PRODUCT' ? 'SELECT_PRODUCT_FALLBACK_NOT_READY' : status.result, clicked: '0', continueEnabled: status.continueEnabled, missing: status.missing });
      if (!continueBtn) return lineResult({ result: 'SELECT_PRODUCT_MISSING_CONTINUE', clicked: '0', continueEnabled: '0', missing: 'SELECT_PRODUCT_MISSING_CONTINUE' });
      if (isDisabledLike(continueBtn)) return lineResult({ result: 'SELECT_PRODUCT_CONTINUE_DISABLED', clicked: '0', continueEnabled: '0', missing: 'SELECT_PRODUCT_CONTINUE_DISABLED' });
      const clicked = clickCenterEl(continueBtn);
      return lineResult({
        ...status,
        result: clicked ? 'OK' : 'CLICK_FAILED',
        clicked: clicked ? '1' : '0',
        continueEnabled: '1',
        missing: '',
        readinessTrace: 'SELECT_PRODUCT_CLICK_CONTINUE_READY',
        targetText: compact(getText(continueBtn), 80)
      });
    }

    case 'select_product_status': {
      return linesOut(buildSelectProductStatus(args));
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
      const candidates = Array.from(document.querySelectorAll('button[id]')).filter((btn) => {
        const id = safe(btn.id);
        return id.endsWith('-add') || id.endsWith('-addToQuote');
      });
      const scored = candidates
        .filter(visible)
        .map((btn) => {
          const contextText = [
            safe(btn.id).replace(/-/g, ' '),
            getText(btn),
            getText(btn.parentElement),
            getText(btn.closest('div'))
          ].join(' ');
          return { btn, details: scoreVehicleCandidate(contextText, args) };
        })
        .filter(({ details }) => details.score >= details.threshold)
        .sort((a, b) => b.details.score - a.details.score);
      if (!scored.length)
        return '';
      if (vehicleCandidatesAreAmbiguous(scored.map((entry) => ({ details: entry.details }))))
        return 'AMBIGUOUS';
      return safe(scored[0].btn.id);
    }

    case 'any_vehicle_already_added': {
      return bodyText().includes('added to quote') ? '1' : '0';
    }

    case 'modal_exists': {
      const saveButtonId = safe(args.saveButtonId);
      return document.getElementById(saveButtonId) ? '1' : '0';
    }

    case 'asc_ensure_non_driver_participant_panel_ready': {
      const root = findAscInlineParticipantPanelRoot();
      const before = readAscNonDriverParticipantPanelReadiness(root);
      if (!root) {
        return lineResult({
          result: 'ASC_PARTICIPANT_MOVING_VIOLATIONS_SELECTION_FAILED',
          method: 'participant-panel-root-missing',
          traceCode: 'ASC_PARTICIPANT_MOVING_VIOLATIONS_SELECTION_FAILED',
          panelPresent: '0',
          savePresent: before.savePresent,
          saveEnabled: before.saveEnabled,
          activeParticipantRequiredMissing: '1',
          movingViolationsQuestionPresent: before.moving.questionPresent,
          movingViolationsSelectedValue: before.moving.selectedValue,
          movingViolationsDefaultApplied: '0',
          requiresClientVerification: '1',
          source: safe(args.source || 'PROVISIONAL_WORKFLOW_DEFAULT'),
          failedFields: 'participantPanel'
        });
      }
      let selection = { ok: true, method: 'not-needed', traceCode: 'ASC_NON_DRIVER_PARTICIPANT_PANEL_READY_TO_SAVE', before: before.moving, after: before.moving };
      let defaultApplied = '0';
      if (before.moving.requiredMissing === '1') {
        selection = selectAscParticipantMovingViolationsNo(root);
        defaultApplied = selection.ok && selection.after && selection.after.selectedValue === 'NO' && selection.before && !selection.before.selectedValue ? '1' : '0';
      }
      const after = readAscNonDriverParticipantPanelReadiness(root);
      const ready = after.readyToSave === '1';
      const result = ready
        ? 'ASC_NON_DRIVER_PARTICIPANT_PANEL_READY_TO_SAVE'
        : (selection.traceCode === 'ASC_PARTICIPANT_MOVING_VIOLATIONS_SELECTION_FAILED'
          ? 'ASC_PARTICIPANT_MOVING_VIOLATIONS_SELECTION_FAILED'
          : 'ASC_PARTICIPANT_MOVING_VIOLATIONS_REQUIRED');
      return lineResult({
        result,
        method: selection.method,
        traceCode: ready ? (defaultApplied === '1' ? 'ASC_PARTICIPANT_MOVING_VIOLATIONS_NO_SELECTED' : 'ASC_NON_DRIVER_PARTICIPANT_PANEL_READY_TO_SAVE') : selection.traceCode,
        initialTraceCode: before.moving.requiredMissing === '1' ? 'ASC_PARTICIPANT_MOVING_VIOLATIONS_REQUIRED' : '',
        panelPresent: '1',
        savePresent: after.savePresent,
        saveEnabled: after.saveEnabled,
        activeParticipantRequiredMissing: after.requiredMissing,
        activeParticipantPanelReadyToSave: after.readyToSave,
        movingViolationsQuestionPresent: after.moving.questionPresent,
        movingViolationsControlPresent: after.moving.controlPresent,
        movingViolationsWarningPresent: after.moving.warningPresent,
        movingViolationsSelectedValue: after.moving.selectedValue,
        movingViolationsSelectionSource: after.moving.selectedSource,
        movingViolationsDefaultApplied: defaultApplied,
        requiresClientVerification: defaultApplied === '1' ? '1' : '0',
        source: safe(args.source || 'PROVISIONAL_WORKFLOW_DEFAULT'),
        failedFields: ready ? '' : 'movingViolations'
      });
    }

    case 'fill_participant_modal': {
      const setSelect = (id, value) => {
        const el = document.getElementById(safe(id));
        if (!value) return { applied: 'SKIP', method: 'not-requested' };
        if (!el || isDisabledLike(el)) return { applied: '0', method: 'select-missing' };
        const current = readSelectState(el);
        if (matchesNormalizedValue(current.value, value) || matchesNormalizedValue(current.text, value))
          return { applied: '1', method: 'already-selected' };
        const applied = setSelectValue(el, value, false);
        const next = readSelectState(el);
        return {
          applied: (applied && (matchesNormalizedValue(next.value, value) || matchesNormalizedValue(next.text, value))) ? '1' : '0',
          method: applied ? 'select' : 'select-failed'
        };
      };
      const setDefaultInput = (id, value, onlyIfBlank = false, exact = false) => {
        const wanted = safe(value).trim();
        if (!wanted) return { applied: 'SKIP', method: 'not-requested' };
        const el = document.getElementById(safe(id));
        if (!el || isDisabledLike(el) || el.readOnly) return { applied: '0', method: 'input-missing' };
        const before = safe(el.value).trim();
        let method = 'already-set';
        if (onlyIfBlank && before !== '') {
          method = 'preserved-nonblank';
        } else if (before !== wanted) {
          method = setInputValue(el, wanted, false) ? 'input' : 'input-failed';
        }
        const after = safe(el.value).trim();
        const applied = exact ? (after === wanted ? '1' : '0') : (after !== '' ? '1' : '0');
        return { applied, method };
      };

      const age = setDefaultInput('ageFirstLicensed_ageFirstLicensed', args.ageFirstLicensed, true, true);
      const email = setDefaultInput('emailAddress.emailAddress', args.email, true, false);
      const military = safe(args.military)
        ? (() => {
            const result = setRadioByName('agreement.agreementParticipant.militaryInd', args.military);
            return (result.method === 'no-radio-match')
              ? { applied: 'SKIP', method: 'question-not-shown' }
              : { applied: result.ok ? '1' : '0', method: result.method };
          })()
        : { applied: 'SKIP', method: 'not-requested' };
      const violations = safe(args.violations)
        ? (() => {
            const result = setRadioByName('agreement.agreementParticipant.party.violationInd', args.violations);
            if (result.method !== 'no-radio-match')
              return { applied: result.ok ? '1' : '0', method: result.method };
            if (normalizeYesNoValue(args.violations) !== 'NO')
              return { applied: 'SKIP', method: 'question-not-shown' };
            const root = findAscInlineParticipantPanelRoot();
            const state = readAscParticipantMovingViolationsState(root);
            if (state.questionPresent !== '1')
              return { applied: 'SKIP', method: 'question-not-shown' };
            const scoped = selectAscParticipantMovingViolationsNo(root);
            return { applied: scoped.ok ? '1' : '0', method: scoped.method };
          })()
        : { applied: 'SKIP', method: 'not-requested' };
      let defensiveDriving = { applied: 'SKIP', method: 'not-requested' };
      if (safe(args.defensiveDriving)) {
        const result = setRadioByName('agreement.agreementParticipant.defensiveDriverInd', args.defensiveDriving);
        defensiveDriving = (result.method === 'no-radio-match')
          ? { applied: 'SKIP', method: 'question-not-shown' }
          : { applied: result.ok ? '1' : '0', method: result.method };
      }
      const propertyOwnership = setSelect('propertyOwnershipEntCd_option', args.propertyOwnership);

      const male = document.getElementById('gender_1002');
      const female = document.getElementById('gender_1001');
      let genderFallback = { applied: 'SKIP', method: 'not-needed' };
      if (male && female && !male.checked && !female.checked) {
        const target = document.getElementById('gender_' + safe(args.oppositeGenderValue));
        if (!target) {
          genderFallback = { applied: '0', method: 'gender-target-missing' };
        } else {
          const clickTarget = getInputClickTarget(target) || target;
          const applied = clickCenterEl(clickTarget) && (target.checked || isSelectedNode(target) || isSelectedNode(clickTarget));
          genderFallback = { applied: applied ? '1' : '0', method: applied ? 'gender-fallback' : 'gender-click-failed' };
        }
      }

      const spouseSelect = document.getElementById(safe(args.spouseSelectId));
      const marriedRadio = document.getElementById('maritalStatusEntCd_0001');
      const leadMaritalStatus = normUpper(args.leadMaritalStatus);
      let spouseSelection = { applied: 'SKIP', method: 'not-needed' };
      if (safe(args.leadMaritalStatus) || safe(args.leadSpouseName) || truthyArg(args.ascSpouseOverrideSingleEnabled)) {
        const rawSpouse = ascResolveParticipantMaritalAndSpouse(args);
        const spouseStatus = String(rawSpouse || '').split(/\n/).reduce((acc, line) => {
          const index = line.indexOf('=');
          if (index >= 0) acc[line.slice(0, index)] = line.slice(index + 1);
          return acc;
        }, {});
        const okResults = ['SINGLE_CONFIRMED', 'SINGLE_SET', 'SELECTED', 'ALREADY_SELECTED', 'NO_DROPDOWN'];
        spouseSelection = {
          applied: okResults.includes(safe(spouseStatus.result)) ? '1' : '0',
          method: safe(spouseStatus.spouseSelectionMethod || spouseStatus.method || 'policy-resolver')
        };
      } else if (spouseSelect && marriedRadio) {
        const valid = Array.from(spouseSelect.options || []).filter(nonPlaceholderOption).map((o) => safe(o.value));
        if (leadMaritalStatus === 'SINGLE') {
          spouseSelection = { applied: 'SKIP', method: 'skipped-lead-single' };
        } else if (valid.length === 1) {
          const marriedTarget = getInputClickTarget(marriedRadio) || marriedRadio;
          const marriedApplied = clickCenterEl(marriedTarget) && (marriedRadio.checked || isSelectedNode(marriedRadio) || isSelectedNode(marriedTarget));
          const spouseApplied = marriedApplied && setSelectValue(spouseSelect, valid[0], false) && safe(spouseSelect.value) === safe(valid[0]);
          spouseSelection = { applied: spouseApplied ? '1' : '0', method: spouseApplied ? 'unique-spouse' : 'unique-spouse-failed' };
        }
      }
      const requiredChecks = [
        ...(safe(args.ageFirstLicensed) ? [{ name: 'ageFirstLicensed', value: age.applied }] : []),
        ...(safe(args.email) ? [{ name: 'email', value: email.applied }] : []),
        ...(military.applied !== 'SKIP' ? [{ name: 'military', value: military.applied }] : []),
        ...(violations.applied !== 'SKIP' ? [{ name: 'violations', value: violations.applied }] : []),
        ...(safe(args.propertyOwnership) ? [{ name: 'propertyOwnership', value: propertyOwnership.applied }] : []),
        ...(genderFallback.applied !== 'SKIP' ? [{ name: 'genderFallback', value: genderFallback.applied }] : []),
        ...(spouseSelection.applied !== 'SKIP' ? [{ name: 'spouseSelection', value: spouseSelection.applied }] : [])
      ];
      const optionalChecks = [
        ...(safe(args.defensiveDriving) ? [{ name: 'defensiveDriving', value: defensiveDriving.applied, allowSkip: true }] : [])
      ];
      let result = resultFromChecks(requiredChecks, optionalChecks);
      const postFillStatus = ascParticipantDetailStatus(args);
      if (postFillStatus.result === 'ASC_INLINE_PARTICIPANT_SAVE_DISABLED')
        result = 'ASC_INLINE_PARTICIPANT_SAVE_DISABLED';
      return lineResult({
        result,
        method: [
          `age:${age.method}`,
          `email:${email.method}`,
          `military:${military.method}`,
          `violations:${violations.method}`,
          `defensiveDriving:${defensiveDriving.method}`,
          `propertyOwnership:${propertyOwnership.method}`,
          `genderFallback:${genderFallback.method}`,
          `spouse:${spouseSelection.method}`
        ].join('|'),
        ageFirstLicensedSet: age.applied,
        emailSet: email.applied,
        militarySet: military.applied,
        violationsSet: violations.applied,
        defensiveDrivingSet: defensiveDriving.applied,
        propertyOwnershipSet: propertyOwnership.applied,
        genderFallbackSet: genderFallback.applied,
        spouseSelectionSet: spouseSelection.applied,
        failedFields: failedCheckNames(requiredChecks.concat(optionalChecks))
      });
    }

    case 'select_remove_reason': {
      const reasonCode = safe(args.reasonCode || '0006');
      const root = advisorRemoveDriverModalRoot() || document;
      const candidates = Array.from(root.querySelectorAll('input[type=radio],input'))
        .filter((input) => /nonDriver/i.test(`${safe(input.id)} ${safe(input.name)}`));
      const el = document.getElementById('nonDriverReasonOthers_' + reasonCode)
        || candidates.find((input) => safe(input.value) === reasonCode || safe(input.id).endsWith('_' + reasonCode))
        || candidates.find((input) => answerTextMatches(readInputLabel(input), safe(args.reasonText || 'This driver has their own car insurance')));
      if (!el) {
        return linesOut({
          result: 'NO_REASON',
          reasonCode,
          reasonSelected: '0',
          clicked: '0',
          method: 'reason-missing',
          failedFields: 'removeReason'
        });
      }
      let clicked = false;
      let method = el.checked ? 'already-selected' : '';
      if (!el.checked) {
        const target = getInputClickTarget(el) || el;
        clicked = clickCenterEl(target);
        if (!el.checked) {
          try { el.checked = true; } catch {}
          try { el.dispatchEvent(new Event('input', { bubbles: true })); } catch {}
          try { el.dispatchEvent(new Event('change', { bubbles: true })); } catch {}
          method = clicked ? 'click|direct-check' : 'direct-check';
        } else {
          method = clicked ? 'click' : 'click-target-selected';
        }
      }
      const selected = !!el.checked || readCheckedRadioState(root, /nonDriver/i).code === reasonCode;
      return linesOut({
        result: selected ? 'OK' : 'SELECT_FAILED',
        reasonCode,
        reasonSelected: selected ? '1' : '0',
        clicked: clicked ? '1' : '0',
        method,
        failedFields: selected ? '' : 'removeReason'
      });
    }

    case 'fill_vehicle_modal': {
      const txt = safe((document.body && document.body.innerText) || '');
      const suppliedYear = Number(safe(args.vehicleYear || args.year || '').match(/\b(19|20)\d{2}\b/)?.[0] || 0);
      const m = txt.match(/\b(19|20)\d{2}\b/);
      const year = m ? Number(m[0]) : 0;
      const detectedYear = suppliedYear || year;
      const clickId = (id) => {
        const el = document.getElementById(id);
        if (!el || !visible(el) || isDisabledLike(el)) return { applied: '0', method: 'missing' };
        if (el.checked) return { applied: '1', method: 'already-selected' };
        const target = getInputClickTarget(el) || el;
        const clicked = clickCenterEl(target);
        const verified = !!el.checked || isSelectedNode(el) || isSelectedNode(target);
        return { applied: clicked && verified ? '1' : '0', method: clicked ? 'click' : 'click-failed' };
      };
      const ownershipIdForKind = (kind) => kind === 'finance' ? 'vehicleOwnershipCd_0007' : 'vehicleOwnershipCd_0001';
      const ownershipLabelMatches = (node, kind) => {
        const label = normLower(`${safe(node && node.id)} ${safe(node && node.name)} ${safe(node && node.value)} ${readInputLabel(node)} ${getText((node && node.closest && node.closest('label,.radio,.option,.field,div')) || null)}`);
        if (kind === 'finance') return /\bfinanc(?:e|ed|ing)\b/.test(label);
        return /\bown(?:ed|ership)?\b/.test(label) && !/\bunknown\b/.test(label);
      };
      const findOwnershipCandidates = (kind) => {
        const explicit = document.getElementById(ownershipIdForKind(kind));
        const explicitVisible = explicit && visible(explicit) ? [explicit] : [];
        if (explicitVisible.length) return explicitVisible;
        return Array.from(document.querySelectorAll('input[type=radio],button,[role=radio],[role=button]'))
          .filter(visible)
          .filter((node) => /ownership/i.test(`${safe(node.id)} ${safe(node.name)} ${getText((node.closest && node.closest('fieldset,section,div')) || node)}`))
          .filter((node) => ownershipLabelMatches(node, kind));
      };
      const selectOwnership = (kind) => {
        if (!kind) return { applied: '0', method: 'year-missing', traceCode: 'ASC_VEHICLE_MODAL_OWNERSHIP_READBACK_FAILED', readback: '0', currentText: '', currentValue: '' };
        const candidates = findOwnershipCandidates(kind);
        if (candidates.length !== 1) {
          return {
            applied: '0',
            method: candidates.length ? 'ambiguous' : 'missing',
            traceCode: 'ASC_VEHICLE_MODAL_OWNERSHIP_READBACK_FAILED',
            readback: '0',
            currentText: compact(candidates.map((node) => readInputLabel(node) || safe(node.id)).join('||'), 180),
            currentValue: compact(candidates.map((node) => safe(node.value || node.id)).join('||'), 180)
          };
        }
        const el = candidates[0];
        if (isDisabledLike(el)) {
          return { applied: '0', method: 'disabled', traceCode: 'ASC_VEHICLE_MODAL_OWNERSHIP_READBACK_FAILED', readback: '0', currentText: compact(readInputLabel(el) || safe(el.id), 120), currentValue: safe(el.value || el.id) };
        }
        const target = getInputClickTarget(el) || el;
        const clicked = el.checked || clickCenterEl(target);
        const selected = !!el.checked || isSelectedNode(el) || isSelectedNode(target);
        if (!selected) {
          try { el.checked = true; } catch {}
          try { el.dispatchEvent(new Event('input', { bubbles: true })); } catch {}
          try { el.dispatchEvent(new Event('change', { bubbles: true })); } catch {}
        }
        const readback = !!el.checked || isSelectedNode(el) || isSelectedNode(target);
        return {
          applied: readback ? '1' : '0',
          method: readback ? (clicked ? 'click' : 'direct-check') : 'readback-failed',
          traceCode: readback
            ? (kind === 'finance' ? 'ASC_VEHICLE_MODAL_OWNERSHIP_FINANCE_SELECTED' : 'ASC_VEHICLE_MODAL_OWNERSHIP_OWN_SELECTED')
            : 'ASC_VEHICLE_MODAL_OWNERSHIP_READBACK_FAILED',
          readback: readback ? '1' : '0',
          currentText: compact(readInputLabel(el) || safe(el.id), 120),
          currentValue: safe(el.value || el.id)
        };
      };
      const garaging = clickId('garagingAddressSameAsOther-control-item-0');
      const purchaseDate = clickId('purchaseDate_false');
      const threshold = Number(args.threshold || 2015);
      const ownershipExpected = detectedYear
        ? (detectedYear > threshold ? 'finance' : 'own')
        : '';
      const ownership = selectOwnership(ownershipExpected);
      const requiredChecks = [
        { name: 'garagingAddressSameAsOther', value: garaging.applied },
        { name: 'purchaseDateFalse', value: purchaseDate.applied },
        { name: 'vehicleYear', value: detectedYear ? '1' : '0' },
        { name: 'ownership', value: ownership.applied }
      ];
      const result = resultFromChecks(requiredChecks, []);
      return lineResult({
        result,
        method: `garaging:${garaging.method}|purchaseDate:${purchaseDate.method}|ownership:${ownership.method}`,
        garagingAddressSameAsOtherClicked: garaging.applied,
        purchaseDateFalseClicked: purchaseDate.applied,
        ownershipClicked: ownership.applied,
        ownershipExpected,
        ownershipReadback: ownership.readback,
        ownershipCurrentText: ownership.currentText,
        ownershipCurrentValue: ownership.currentValue,
        ownershipTraceCode: ownership.traceCode,
        detectedYear: String(detectedYear),
        failedFields: failedCheckNames(requiredChecks)
      });
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
      const radioLikeControls = Array.from(document.querySelectorAll('[role=radio],[aria-checked],button,[role=button],label'))
        .filter(visible)
        .map((el) => {
          const text = normalize(el.innerText || el.textContent || el.value || el.getAttribute('aria-label') || '');
          const context = normalize((el.closest && el.closest('fieldset,section,div,label')) ? (el.closest('fieldset,section,div,label').innerText || el.closest('fieldset,section,div,label').textContent || '') : text);
          return {
            tag: el.tagName,
            id: safe(el.id),
            name: safe(el.name),
            role: safe(el.getAttribute && el.getAttribute('role')),
            text,
            value: safe(el.value),
            ariaChecked: safe(el.getAttribute && el.getAttribute('aria-checked')),
            ariaPressed: safe(el.getAttribute && el.getAttribute('aria-pressed')),
            selected: isSelectedNode(el),
            class: safe(el.className),
            context: context.slice(0, 220)
          };
        })
        .filter((entry) => /\b(yes|no)\b/i.test(entry.text) || /moving violations|violation/i.test(entry.context) || entry.role === 'radio');
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
        radioLikeControls,
        alerts,
        modalText: dialogs.join(' || ')
      };
      return JSON.stringify(payload, null, 2);
    }

    case 'wait_condition': {
      return readAdvisorWaitCondition(args);
    }

    default:
      return '';
  }
  } catch (error) {
    const clean = (value, max = 320) => String(value ?? '').replace(/\r?\n+/g, ' ').replace(/\s+/g, ' ').trim().slice(0, max);
    return [
      'result=ERROR',
      `op=${clean(op, 80)}`,
      `message=${clean((error && error.message) || error, 280)}`,
      `stack=${clean((error && error.stack) || '', 600)}`,
      `url=${clean((globalThis.location && location.href) || '', 240)}`
    ].join('\n');
  }
})()));
