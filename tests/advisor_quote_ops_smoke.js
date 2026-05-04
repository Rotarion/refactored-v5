const assert = require('assert');
const fs = require('fs');
const path = require('path');
const vm = require('vm');

class FakeOption {
  constructor({ value = '', text = '', selected = false, disabled = false } = {}) {
    this.tagName = 'OPTION';
    this.value = String(value);
    this.text = String(text);
    this.innerText = this.text;
    this.textContent = this.text;
    this.selected = !!selected;
    this.disabled = !!disabled;
    this.parentElement = null;
  }
}

class FakeElement {
  constructor(tagName, props = {}) {
    this.tagName = String(tagName || 'div').toUpperCase();
    this.id = props.id || '';
    this.name = props.name || '';
    this.type = props.type || '';
    this.className = props.className || '';
    this.role = props.role || '';
    this.disabled = !!props.disabled;
    this.hidden = !!props.hidden;
    this.readOnly = !!props.readOnly;
    this.checked = !!props.checked;
    this.placeholder = props.placeholder || '';
    this.tabIndex = props.tabIndex ?? -1;
    this.style = Object.assign({
      display: 'block',
      visibility: 'visible',
      opacity: '1',
      pointerEvents: 'auto'
    }, props.style || {});
    this.attributes = Object.assign({}, props.attributes || {});
    this.parentElement = null;
    this.children = [];
    this.form = props.form || null;
    this._text = String(props.text || '');
    this._value = String(props.value ?? '');
    this._selectedIndex = -1;
    this.dispatched = [];
    this.clickCalls = 0;
    this.clickThrows = !!props.clickThrows;
    this.onClick = typeof props.onClick === 'function' ? props.onClick : null;
    this.onDispatch = typeof props.onDispatch === 'function' ? props.onDispatch : null;
    this.focusCalls = 0;
    this.blurCalls = 0;
    this.scrollCalls = 0;
    this.options = null;

    if (this.id) this.attributes.id = this.id;
    if (this.name) this.attributes.name = this.name;
    if (this.type) this.attributes.type = this.type;
    if (this.className) this.attributes.class = this.className;
    if (this.role) this.attributes.role = this.role;

    if (Array.isArray(props.options)) {
      this.options = props.options.map((option) => {
        const created = new FakeOption(option);
        created.parentElement = this;
        return created;
      });
      const selectedIndex = this.options.findIndex((option) => option.selected);
      this.selectedIndex = selectedIndex >= 0 ? selectedIndex : 0;
      if (selectedIndex < 0 && this.options.length)
        this.options[this.selectedIndex].selected = true;
    }
  }

  appendChild(child) {
    child.parentElement = this;
    this.children.push(child);
    return child;
  }

  append(...children) {
    children.forEach((child) => this.appendChild(child));
  }

  contains(node) {
    let current = node;
    while (current) {
      if (current === this) return true;
      current = current.parentElement;
    }
    return false;
  }

  closest(selector) {
    let current = this;
    while (current) {
      if (matchesSelectorGroup(current, selector)) return current;
      current = current.parentElement;
    }
    return null;
  }

  querySelectorAll(selector) {
    return queryAllFrom(this, selector);
  }

  querySelector(selector) {
    return this.querySelectorAll(selector)[0] || null;
  }

  getBoundingClientRect() {
    if (this.hidden || this.style.display === 'none' || this.style.visibility === 'hidden')
      return { left: 0, top: 0, width: 0, height: 0 };
    return { left: 0, top: 0, width: 120, height: 24 };
  }

  getAttribute(name) {
    const key = String(name);
    if (key === 'class') return this.className || null;
    if (key === 'role') return this.role || null;
    if (key === 'type') return this.type || null;
    if (key === 'name') return this.name || null;
    if (key === 'id') return this.id || null;
    return Object.prototype.hasOwnProperty.call(this.attributes, key) ? this.attributes[key] : null;
  }

  setAttribute(name, value) {
    const key = String(name);
    const text = String(value);
    this.attributes[key] = text;
    if (key === 'class') this.className = text;
    if (key === 'role') this.role = text;
    if (key === 'type') this.type = text;
    if (key === 'name') this.name = text;
    if (key === 'id') this.id = text;
  }

  dispatchEvent(event) {
    this.dispatched.push(event.type);
    if (this.onDispatch) this.onDispatch(this, event);
    return true;
  }

  focus() {
    this.focusCalls += 1;
  }

  blur() {
    this.blurCalls += 1;
  }

  scrollIntoView() {
    this.scrollCalls += 1;
  }

  click() {
    this.clickCalls += 1;
    if (this.clickThrows)
      throw new Error('click failed');
    if (this.type === 'radio') this.checked = true;
    if (this.type === 'checkbox') this.checked = !this.checked;
    if (this.onClick) this.onClick(this);
    return true;
  }

  get innerText() {
    return [this._text, ...this.children.map((child) => child.innerText || child.textContent || '')]
      .join(' ')
      .replace(/\s+/g, ' ')
      .trim();
  }

  set innerText(value) {
    this._text = String(value ?? '');
  }

  get textContent() {
    return this.innerText;
  }

  set textContent(value) {
    this._text = String(value ?? '');
  }

  get value() {
    return this._value;
  }

  set value(nextValue) {
    this._value = String(nextValue ?? '');
    if (this.options) {
      let selectedIndex = -1;
      this.options.forEach((option, index) => {
        option.selected = String(option.value) === this._value;
        if (option.selected) selectedIndex = index;
      });
      this._selectedIndex = selectedIndex;
      if (selectedIndex >= 0)
        this._value = String(this.options[selectedIndex].value);
    }
  }

  get selectedIndex() {
    return this._selectedIndex;
  }

  set selectedIndex(index) {
    this._selectedIndex = Number(index);
    if (!this.options) return;
    this.options.forEach((option, optionIndex) => {
      option.selected = optionIndex === this._selectedIndex;
    });
    if (this._selectedIndex >= 0 && this.options[this._selectedIndex])
      this._value = String(this.options[this._selectedIndex].value);
  }
}

class FakeDocument {
  constructor(nodes = []) {
    this.body = new FakeElement('body');
    this.title = 'Advisor Quote Smoke';
    this.pointTarget = null;
    nodes.forEach((node) => this.body.appendChild(node));
  }

  getElementById(id) {
    return findById(this.body, String(id));
  }

  querySelectorAll(selector) {
    return this.body.querySelectorAll(selector);
  }

  querySelector(selector) {
    return this.querySelectorAll(selector)[0] || null;
  }

  elementFromPoint() {
    return this.pointTarget;
  }
}

class FakeEvent {
  constructor(type, options = {}) {
    this.type = type;
    Object.assign(this, options);
  }
}

function findById(root, id) {
  if (!id) return null;
  for (const child of root.children) {
    if (child.id === id) return child;
    const nested = findById(child, id);
    if (nested) return nested;
  }
  return null;
}

function queryAllFrom(root, selector) {
  const matches = [];
  const visit = (node) => {
    for (const child of node.children) {
      if (matchesSelectorGroup(child, selector))
        matches.push(child);
      visit(child);
    }
  };
  visit(root);
  return matches;
}

function matchesSelectorGroup(element, selectorGroup) {
  return String(selectorGroup)
    .split(',')
    .map((selector) => selector.trim())
    .filter(Boolean)
    .some((selector) => matchesSelector(element, selector));
}

function matchesSelector(element, selector) {
  const parts = selector.split(/\s+/).filter(Boolean);
  if (!parts.length) return false;
  let current = element;
  for (let index = parts.length - 1; index >= 0; index -= 1) {
    if (!current) return false;
    if (!matchesSimpleSelector(current, parts[index])) {
      if (index !== parts.length - 1) {
        current = current.parentElement;
        continue;
      }
      return false;
    }
    if (index === 0) return true;
    current = current.parentElement;
    while (current && !matchesSimpleSelector(current, parts[index - 1]))
      current = current.parentElement;
  }
  return true;
}

function matchesSimpleSelector(element, selector) {
  let remaining = selector.trim();
  let requireChecked = false;
  if (remaining.endsWith(':checked')) {
    requireChecked = true;
    remaining = remaining.slice(0, -8);
  }
  if (requireChecked && !element.checked) return false;

  const tagMatch = remaining.match(/^[a-zA-Z]+/);
  if (tagMatch) {
    if (element.tagName !== tagMatch[0].toUpperCase()) return false;
    remaining = remaining.slice(tagMatch[0].length);
  }

  const idMatches = remaining.match(/#([A-Za-z0-9_.:-]+)/g) || [];
  for (const token of idMatches) {
    if (element.id !== token.slice(1)) return false;
  }
  remaining = remaining.replace(/#([A-Za-z0-9_.:-]+)/g, '');

  const classMatches = remaining.match(/\.([A-Za-z0-9_-]+)/g) || [];
  for (const token of classMatches) {
    const wanted = token.slice(1);
    const classes = String(element.className || '').split(/\s+/).filter(Boolean);
    if (!classes.includes(wanted)) return false;
  }
  remaining = remaining.replace(/\.([A-Za-z0-9_-]+)/g, '');

  const attrRegex = /\[([^\]=~*$]+)([*$^]?=)?("?)(.*?)\3\]/g;
  let match;
  while ((match = attrRegex.exec(remaining))) {
    const attrName = match[1].trim();
    const operator = match[2] || '';
    const wanted = match[4];
    const actual = element.getAttribute(attrName);
    if (!operator) {
      if (actual == null) return false;
      continue;
    }
    const actualText = String(actual ?? '');
    if (operator === '=' && actualText !== wanted) return false;
    if (operator === '*=' && !actualText.includes(wanted)) return false;
    if (operator === '$=' && !actualText.endsWith(wanted)) return false;
    if (operator === '^=' && !actualText.startsWith(wanted)) return false;
  }

  return true;
}

function createInput(id, value = '', extra = {}) {
  return new FakeElement('input', Object.assign({ id, value, type: 'text' }, extra));
}

function createRadio(id, name, value, extra = {}) {
  return new FakeElement('input', Object.assign({ id, name, value, type: 'radio' }, extra));
}

function createButton(id, text, extra = {}) {
  return new FakeElement('button', Object.assign({ id, text, tabIndex: 0 }, extra));
}

function createSelect(id, options, extra = {}) {
  return new FakeElement('select', Object.assign({ id, options }, extra));
}

function parseLines(raw) {
  return String(raw)
    .replace(/\r/g, '')
    .split('\n')
    .filter(Boolean)
    .reduce((acc, line) => {
      const index = line.indexOf('=');
      if (index < 0) return acc;
      acc[line.slice(0, index)] = line.slice(index + 1);
      return acc;
    }, {});
}

const BASE_SELECTORS = {
  advisorQuotingButtonId: 'group2_Quoting_button',
  searchCreateNewProspectId: 'outOfLocationCreateNewProspectButton',
  beginQuotingContinueId: 'PrimaryApplicant-Continue-button',
  prospectFirstNameId: 'ConsumerData.People[0].Name.GivenName',
  prospectLastNameId: 'ConsumerData.People[0].Name.Surname',
  prospectDobId: 'ConsumerData.People[0].Personal.BirthDt',
  prospectGenderId: 'ConsumerData.People[0].Personal.GenderCd.SrcCd',
  prospectAddressId: 'ConsumerData.Assets.Properties[0].Addr.Addr1',
  prospectCityId: 'ConsumerData.Assets.Properties[0].Addr.City',
  prospectStateId: 'ConsumerData.Assets.Properties[0].Addr.StateProvCd.SrcCd',
  prospectZipId: 'ConsumerData.Assets.Properties[0].Addr.PostalCode',
  prospectPhoneId: 'ConsumerData.People[0].Communications.PhoneNumber',
  sidebarAddProductId: 'addProduct',
  quoteBlockAddProductId: 'quotesButton',
  createQuotesButtonId: 'consentModalTrigger',
  selectProductRatingStateId: 'SelectProduct.RatingState',
  selectProductProductId: 'SelectProduct.Product',
  selectProductContinueId: 'selectProductContinue',
  consumerReportsConsentYesId: 'orderReportsConsent-yes-btn',
  driverVehicleContinueId: 'profile-summary-submitBtn',
  participantSaveId: 'PARTICIPANT_SAVE-btn',
  removeParticipantSaveId: 'REMOVE_PARTICIPANT_SAVE-btn',
  addAssetSaveId: 'ADD_ASSET_SAVE-btn',
  confirmVehicleId: 'confirmNewVehicle',
  incidentContinueId: 'CONTINUE_OFFER-btn',
  incidentBackId: 'BACK_TO_PROFILE_SUMMARY-btn'
};

const BASE_URLS = {
  rapportContains: '/rapport',
  customerSummaryContains: '/apps/customer-summary/',
  productOverviewContains: '/apps/intel/102/overview',
  selectProductContains: '/selectProduct',
  ascProductContains: '/ASCPRODUCT/'
};

const BASE_TEXTS = {
  duplicateHeading: 'This Prospect May Already Exist',
  customerSummaryStartHereText: 'START HERE (Pre-fill included)',
  customerSummaryQuoteHistoryText: 'Quote History',
  customerSummaryAssetsDetailsText: 'Assets Details',
  productOverviewHeading: 'Select Product',
  productOverviewAutoTile: 'Auto',
  productOverviewContinueText: 'Save & Continue to Gather Data',
  selectProductCurrentInsuredQuestion: 'Is the customer currently insured?',
  selectProductAnswerYesText: 'Yes',
  driversVehiclesHeading: 'Drivers and vehicles',
  incidentsHeading: 'Incidents',
  consumerReportsHeading: 'order consumer reports',
  marriedLabel: 'Married',
  spouseSelectId: 'maritalStatusWithSpouse_spouseName'
};

const BASE_DEFAULTS = {
  ratingState: 'FL',
  currentInsured: 'YES',
  ownOrRent: 'OWN',
  consumerReportsConsent: 'yes',
  ageFirstLicensed: '16',
  gatherResidenceOwnedRentedRentValue: 'RE',
  gatherResidenceTypeApartmentValue: 'AP',
  gatherResidenceTypeSingleFamilyValue: 'SF',
  military: 'false',
  violations: 'false',
  defensiveDriving: 'false',
  propertyOwnershipOwnHome: '0001_0120',
  propertyOwnershipRent: '0002_0120',
  garagingSameAsHome: 'yes',
  recentPurchase: 'false',
  driverRemoveReasonCode: '0006',
  incidentReasonText: 'Accident caused by being hit by animal or road debris',
  vehicleFinanceYearThreshold: 2015
};

function baseArgs(extra = {}) {
  return Object.assign({
    selectors: BASE_SELECTORS,
    urls: BASE_URLS,
    texts: BASE_TEXTS,
    defaults: BASE_DEFAULTS
  }, extra);
}

function textNode(text, tagName = 'div', extra = {}) {
  return new FakeElement(tagName, Object.assign({ text }, extra));
}

function createCheckbox(id, extra = {}) {
  return new FakeElement('input', Object.assign({ id, value: extra.value ?? 'true', type: 'checkbox' }, extra));
}

let fixtureCache = null;

function loadFixtureCatalog() {
  if (!fixtureCache) {
    const fixturePath = path.join(__dirname, 'fixtures', 'advisor_quote_operator', 'sanitized_dom_scenarios.json');
    fixtureCache = JSON.parse(fs.readFileSync(fixturePath, 'utf8'));
  }
  return fixtureCache;
}

function createElementFromFixture(spec = {}) {
  const props = Object.assign({}, spec);
  if (props.class && !props.className)
    props.className = props.class;
  delete props.tag;
  delete props.children;
  const el = new FakeElement(spec.tag || 'div', props);
  for (const childSpec of spec.children || [])
    el.appendChild(createElementFromFixture(childSpec));
  return el;
}

function fixtureScenario(name) {
  const fixture = loadFixtureCatalog()[name];
  assert.ok(fixture, `missing fixture ${name}`);
  const nodes = [];
  if (fixture.bodyText)
    nodes.push(textNode(fixture.bodyText));
  for (const nodeSpec of fixture.nodes || [])
    nodes.push(createElementFromFixture(nodeSpec));
  return {
    doc: new FakeDocument(nodes),
    href: fixture.href || 'https://advisorpro.allstate.com/#/apps/intel/102/start',
    fixture
  };
}

function assertKeyBlock(raw, requiredKeys) {
  const parsed = parseLines(raw);
  for (const key of requiredKeys)
    assert.ok(Object.prototype.hasOwnProperty.call(parsed, key), `missing key ${key} in ${raw}`);
  return parsed;
}

function pageDoc(text, nodes = []) {
  return new FakeDocument([textNode(text), ...nodes]);
}

function customerSummaryDoc() {
  return pageDoc('START HERE (Pre-fill included) Quote History Assets Details Add Product');
}

function customerSummaryDocWithAnchors(anchorText) {
  return pageDoc(`START HERE (Pre-fill included) ${anchorText} Add Product`);
}

function customerSummaryStartHereClickDoc({ includeStart = true, includeAddProduct = true, startText = 'START HERE (Pre-fill included)' } = {}) {
  const nodes = [];
  if (includeStart)
    nodes.push(new FakeElement('a', { id: 'sidebar-start-here', text: startText, className: 'sidebar-link', attributes: { href: '#' } }));
  if (includeAddProduct)
    nodes.push(createButton('sidebar-add-product', 'Add Product'));
  if (includeStart)
    nodes.push(createButton('main-start-here', startText, { className: 'primary-action' }));
  nodes.push(textNode('Quote History Assets Details Contact Information'));
  return new FakeDocument(nodes);
}

function productOverviewDoc(extraNodes = []) {
  return pageDoc('Select Product Auto Save & Continue to Gather Data', extraNodes);
}

function productOverviewLiveTileGridDoc({ selected = false, brokenClick = false, broadDirectSeed = false } = {}) {
  const grid = new FakeElement('div', {
    className: 'product-grid',
    text: broadDirectSeed ? 'Auto Home Renters PUP Condo Motorcycle ORV Boat Motorhome Landlords ManufacturedHome' : ''
  });
  const labels = ['Home', 'Renters', 'PUP', 'Condo', 'Motorcycle', 'ORV', 'Boat', 'Motorhome', 'Landlords', 'ManufacturedHome'];
  const autoTile = new FakeElement('div', {
    className: selected ? 'product-card is-selected' : 'product-card',
    tabIndex: 0,
    onClick: (tile) => {
      if (!brokenClick)
        tile.className = 'product-card is-selected';
    }
  });
  autoTile.appendChild(textNode('Auto', 'span'));
  grid.appendChild(autoTile);
  labels.forEach((label) => {
    const tile = new FakeElement('div', { className: 'product-card', tabIndex: 0 });
    tile.appendChild(textNode(label, 'span'));
    grid.appendChild(tile);
  });
  return {
    doc: productOverviewDoc([
      grid,
      createButton('save-overview', 'Save & Continue to Gather Data'),
      createButton('extra-product-action', 'More options')
    ]),
    grid,
    autoTile
  };
}

function createProductOverviewTile({
  outerClass = 'l-grid__col l-grid__col--3',
  tileClass = 'l-tile',
  clickable = false,
  clickableClass = '',
  tileAttributes = {},
  clickableAttributes = {},
  checkedDescendant = false,
  checkmark = false,
  tileText = '',
  tileOnClick = null,
  clickableOnClick = null
} = {}) {
  const outer = new FakeElement('div', { className: outerClass });
  const tile = new FakeElement('div', { className: tileClass, text: tileText, attributes: tileAttributes, tabIndex: clickable ? -1 : 0, onClick: tileOnClick });
  if (clickable) {
    tile.appendChild(createButton('autoTileButton', 'Auto', { className: clickableClass, attributes: clickableAttributes, onClick: clickableOnClick }));
  } else {
    tile.appendChild(textNode('Auto', 'span'));
  }
  if (checkedDescendant)
    tile.appendChild(createCheckbox('autoProductInput', { checked: true }));
  if (checkmark)
    tile.appendChild(new FakeElement('span', { className: 'c-icon c-icon--checkmark', text: '✓' }));
  outer.appendChild(tile);
  return { outer, tile, clickableTarget: clickable ? tile.querySelector('button') : tile };
}

function selectProductDoc(extraNodes = []) {
  const productSelect = createSelect('SelectProduct.Product', [
    { value: '', text: 'Select One' },
    { value: 'Auto', text: 'Auto' }
  ]);
  const ratingSelect = createSelect('SelectProduct.RatingState', [
    { value: '', text: 'Select One' },
    { value: 'FL', text: 'Florida' }
  ]);
  return pageDoc('Select Product Is the customer currently insured? Yes', [
    productSelect,
    ratingSelect,
    createRadio('insuredYes', 'SelectProduct.CustomerCurrentInsured', 'YES', { checked: true }),
    createRadio('ownHome', 'SelectProduct.CustomerOwnOrRent', 'OWN', { checked: true }),
    createButton('selectProductContinue', 'Continue'),
    ...extraNodes
  ]);
}

function gatherDataDoc(extraNodes = []) {
  return pageDoc('Gather Data add car vehicle details Start Quoting Auto Create Quotes & Order Reports', [
    ...createGatherDefaultsNodes(true, true),
    createButton('quotesButton', 'Add Product'),
    createButton('consentModalTrigger', 'Create Quotes & Order Reports'),
    createCheckbox('auto-product', { name: 'autoProduct', value: 'Auto' }),
    createSelect('ratingState', [
      { value: '', text: 'Select One' },
      { value: 'FL', text: 'Florida' }
    ]),
    ...extraNodes
  ]);
}

function consumerReportsDoc(extraNodes = []) {
  return pageDoc('Order consumer reports Consent', [
    createButton('orderReportsConsent-yes-btn', 'Yes'),
    ...extraNodes
  ]);
}

function driversVehiclesDoc(extraNodes = []) {
  return pageDoc('Drivers and vehicles profile summary', [
    createButton('profile-summary-submitBtn', 'Continue'),
    ...extraNodes
  ]);
}

function ascDriverRow({ name, age, slug, added = false, add = false, remove = false }) {
  const row = new FakeElement('div', {
    className: 'driver-row',
    text: `${name} Age ${age}${added ? ' Added to quote' : ''}`
  });
  const markAdded = () => {
    row._text = `${name} Age ${age} Added to quote`;
    row.children = [];
    row.appendChild(createButton(`${slug}-edit`, 'Edit'));
  };
  const markRemoved = () => {
    row.hidden = true;
  };
  if (added)
    row.appendChild(createButton(`${slug}-edit`, 'Edit'));
  if (add)
    row.appendChild(createButton(`${slug}-addToQuote`, 'Add', { onClick: markAdded }));
  if (remove)
    row.appendChild(createButton(`${slug}-remove`, 'Remove', { onClick: markRemoved }));
  return row;
}

function ascVehicleRow({ text, slug, added = false, add = false, remove = false }) {
  const row = new FakeElement('div', {
    className: 'vehicle-row',
    text: `${text}${added ? ' CONFIRMED' : ''}`
  });
  const markAdded = () => {
    row._text = `${text} CONFIRMED`;
    row.children = [];
    row.appendChild(createButton(`${slug}-edit`, 'Edit'));
  };
  const markRemoved = () => {
    row.hidden = true;
  };
  if (added)
    row.appendChild(createButton(`${slug}-edit`, 'Edit'));
  if (add)
    row.appendChild(createButton(`${slug}-add`, 'Add', { onClick: markAdded }));
  if (remove)
    row.appendChild(createButton(`${slug}-remove`, 'Remove', { onClick: markRemoved }));
  return row;
}

function ascDriversVehiclesDoc({ marital = 'Single', spouseOptions = [], drivers = [], vehicles = [], saveDisabled = false } = {}) {
  const maritalName = 'agreement.agreementParticipant.party.maritalStatusEntCd';
  const spouseSelect = createSelect('maritalStatusWithSpouse_spouseName', [
    { value: '', text: 'Select One', selected: true },
    ...spouseOptions
  ], { name: 'agreement.agreementParticipant.party.spouse.id' });
  return pageDoc("Drivers and vehicles Let's get some more details Add drivers Add vehicles Save and Continue", [
    createRadio('maritalStatusEntCd_0002', maritalName, 'Single', { checked: marital === 'Single' }),
    createRadio('maritalStatusEntCd_0001', maritalName, 'Married', { checked: marital === 'Married' }),
    spouseSelect,
    createSelect('propertyOwnershipEntCd_option', [{ value: '0001_0120', text: 'Own Home', selected: true }]),
    createInput('ageFirstLicensed_ageFirstLicensed', '16'),
    createInput('emailAddress.emailAddress', 'test.driver@example.com', { type: 'email' }),
    ...drivers,
    ...vehicles,
    createButton('profile-summary-submitBtn', 'Save and Continue', { disabled: saveDisabled })
  ]);
}

function incidentsDoc(extraNodes = []) {
  return pageDoc('Incidents Accident caused by being hit by animal or road debris', [
    createButton('CONTINUE_OFFER-btn', 'Continue'),
    ...extraNodes
  ]);
}

function quoteLandingDoc(extraNodes = []) {
  return pageDoc('Personalized quote details coverages your quote', extraNodes);
}

function duplicateDoc(nodes = []) {
  return pageDoc('This Prospect May Already Exist possible duplicate prospect', nodes);
}

function createGatherDefaultsNodes(includeEmail = true, includeHomeType = true) {
  const nodes = [
    createInput('ConsumerData.People[0].Driver.AgeFirstLicensed', ''),
    createSelect('ConsumerData.People[0].ResidenceOwnedRentedCd.SrcCd', [
      { value: '', text: 'Select One' },
      { value: 'RE', text: 'Rent' },
      { value: 'OWN', text: 'Own' }
    ])
  ];
  if (includeEmail)
    nodes.push(createInput('ConsumerData.People[0].Communications.EmailAddr', ''));
  if (includeHomeType) {
    nodes.push(createSelect('ConsumerData.People[0].ResidenceTypeCd.SrcCd', [
      { value: '', text: 'Select One' },
      { value: 'AP', text: 'Apartment' },
      { value: 'SF', text: 'Single Family' }
    ]));
  }
  return nodes;
}

function createOperatorContext(document, href = 'https://advisorpro.allstate.com/#/apps/intel/102/rapport') {
  const state = { copied: '' };
  const context = {
    console,
    copy: (value) => {
      state.copied = String(value);
    },
    document,
    location: { href },
    getComputedStyle: (element) => element.style,
    Event: FakeEvent,
    KeyboardEvent: FakeEvent,
    MouseEvent: FakeEvent,
    PointerEvent: FakeEvent,
    CSS: { escape: (value) => String(value) },
    String,
    Array,
    Set,
    Map,
    RegExp,
    Date,
    Number,
    Boolean,
    Object,
    JSON,
    Math
  };
  context.globalThis = context;
  context.window = context;
  return { context, state };
}

function runOperatorInContext(op, args, operatorContext) {
  const sourcePath = path.join(__dirname, '..', 'assets', 'js', 'advisor_quote', 'ops_result.js');
  const template = fs.readFileSync(sourcePath, 'utf8');
  const script = template
    .replace('@@OP@@', JSON.stringify(op))
    .replace('@@ARGS@@', JSON.stringify(args || {}));
  operatorContext.state.copied = '';
  vm.runInNewContext(script, operatorContext.context, { timeout: 1000 });
  return operatorContext.state.copied;
}

function runOperator(op, args, document, href = 'https://advisorpro.allstate.com/#/apps/intel/102/rapport') {
  return runOperatorInContext(op, args, createOperatorContext(document, href));
}

function testClickHelperDoesNotDoubleSubmit() {
  const form = {
    requestSubmitCalls: 0,
    requestSubmit() {
      this.requestSubmitCalls += 1;
    }
  };
  const button = createButton('submitBtn', 'Continue', { form });
  const doc = new FakeDocument([button]);
  const result = runOperator('click_by_id', { id: 'submitBtn' }, doc);
  assert.strictEqual(result, 'OK');
  assert.strictEqual(button.clickCalls, 1);
  assert.strictEqual(form.requestSubmitCalls, 0);
}

function createGatherDefaultsDocument(includeEmail = true, includeHomeType = true) {
  const nodes = [
    createInput('ConsumerData.People[0].Driver.AgeFirstLicensed', ''),
    createSelect('ConsumerData.People[0].ResidenceOwnedRentedCd.SrcCd', [
      { value: '', text: 'Select One' },
      { value: 'RENT', text: 'Rent' }
    ])
  ];
  if (includeEmail)
    nodes.push(createInput('ConsumerData.People[0].Communications.EmailAddr', ''));
  if (includeHomeType) {
    nodes.push(createSelect('ConsumerData.People[0].ResidenceTypeCd.SrcCd', [
      { value: '', text: 'Select One' },
      { value: 'SF', text: 'Single Family' }
    ]));
  }
  return new FakeDocument(nodes);
}

function testResultCalculation() {
  const okDoc = createGatherDefaultsDocument(true, true);
  const ok = parseLines(runOperator('fill_gather_defaults', {
    ageValue: '16',
    emailValue: 'test@example.com',
    ownershipValue: 'RENT',
    homeTypeValue: 'SF'
  }, okDoc));
  assert.strictEqual(ok.result, 'OK');

  const partialDoc = createGatherDefaultsDocument(false, true);
  const partial = parseLines(runOperator('fill_gather_defaults', {
    ageValue: '16',
    emailValue: 'test@example.com',
    ownershipValue: 'RENT',
    homeTypeValue: 'SF'
  }, partialDoc));
  assert.strictEqual(partial.result, 'PARTIAL');
  assert.strictEqual(partial.emailApplied, '0');

  const failedDoc = createGatherDefaultsDocument(true, false);
  const failed = parseLines(runOperator('fill_gather_defaults', {
    ageValue: '16',
    emailValue: '',
    ownershipValue: 'RENT',
    homeTypeValue: 'SF'
  }, failedDoc));
  assert.strictEqual(failed.result, 'FAILED');
  assert.strictEqual(failed.homeTypeApplied, '0');
}

function createVehicleCard(text, confirmId) {
  const card = new FakeElement('div', { className: 'vehicle-card', text });
  if (confirmId) {
    card.appendChild(createButton(confirmId, 'Confirm'));
    card.appendChild(createButton(`${confirmId}-remove`, 'Remove'));
  }
  return card;
}

function testVehicleMatching() {
  const teslaCard = createVehicleCard('2022 Tesla Model 3 Long Range 5YJ3E1EB5NF123456', 'confirm-tesla');
  const teslaDoc = new FakeDocument([teslaCard]);
  const confirmed = parseLines(runOperator('confirm_potential_vehicle', {
    year: '2022',
    make: 'Tesla',
    model: 'Model 3',
    vin: '5YJ3E1EB5NF123456'
  }, teslaDoc));
  assert.strictEqual(confirmed.result, 'CONFIRMED');

  const addDoc = new FakeDocument([
    createButton('2023-ford-f150-add', 'Add'),
    createButton('2023-ford-escape-add', 'Add')
  ]);
  const addButton = runOperator('find_vehicle_add_button', {
    year: '2023',
    make: 'Ford',
    model: 'F-150'
  }, addDoc);
  assert.strictEqual(addButton, '2023-ford-f150-add');

  const ambiguousDoc = new FakeDocument([
    createVehicleCard('2022 Tesla Model 3 Long Range', 'confirm-a'),
    createVehicleCard('2022 Tesla Model 3 Performance', 'confirm-b')
  ]);
  const ambiguous = parseLines(runOperator('confirm_potential_vehicle', {
    year: '2022',
    make: 'Tesla',
    model: 'Model 3'
  }, ambiguousDoc));
  assert.strictEqual(ambiguous.result, 'AMBIGUOUS');
}

function testDuplicateScoringRejectsWeakMatch() {
  const row = new FakeElement('div', { className: 'sfmOption', text: 'Jane Smith 123 Main St Miami FL 33101' });
  const radio = createRadio('dup-1', 'duplicate', 'existing');
  row.appendChild(radio);
  const createNew = createButton('create-new', 'Create New Prospect');
  const doc = new FakeDocument([row, createNew]);
  const result = parseLines(runOperator('handle_duplicate_prospect', {
    firstName: 'John',
    lastName: 'Smith',
    street: '123 Main St',
    zip: '33101',
    dob: '',
    phone: '',
    email: ''
  }, doc, 'https://advisorpro.allstate.com/#/duplicate'));
  assert.strictEqual(result.result, 'CREATE_NEW');
}

function testWrapperContracts() {
  assert.strictEqual(runOperator('unknown_contract_op', {}, new FakeDocument()), '');

  const badDocument = {
    title: 'Broken Document',
    body: new FakeElement('body', { text: 'broken' }),
    getElementById() {
      throw new Error('boom');
    },
    querySelectorAll() {
      return [];
    },
    querySelector() {
      return null;
    },
    elementFromPoint() {
      return null;
    }
  };
  const error = assertKeyBlock(runOperator('click_by_id', { id: 'x' }, badDocument), ['result', 'op', 'message', 'url']);
  assert.strictEqual(error.result, 'ERROR');
  assert.strictEqual(error.op, 'click_by_id');
  assert.match(error.message, /boom/);
}

function testResidentRunnerContracts() {
  const missing = assertKeyBlock(runOperator('resident_runner_command', {
    command: 'status',
    expectedBuildHash: 'hash-a'
  }, new FakeDocument()), [
    'result', 'running', 'stopRequested', 'version', 'buildHash', 'url', 'routeFamily', 'detectedState', 'eventCount'
  ]);
  assert.strictEqual(missing.result, 'MISSING');

  const safeButton = createButton('runner-safe-button', 'Do Not Click');
  const runnerDoc = pageDoc('Gather Data Vehicles Start Quoting', [safeButton]);
  const runnerContext = createOperatorContext(runnerDoc, 'https://advisorpro.allstate.com/#/apps/intel/102/rapport');
  const bootstrapArgs = baseArgs({
    command: 'bootstrap',
    version: 'test-v1',
    buildHash: 'hash-a',
    maxEventCount: '10'
  });
  const bootstrap = assertKeyBlock(runOperatorInContext('resident_runner_command', bootstrapArgs, runnerContext), [
    'result', 'runnerId', 'version', 'buildHash', 'url', 'state', 'eventSeq', 'message'
  ]);
  assert.strictEqual(bootstrap.result, 'OK');
  assert.strictEqual(bootstrap.version, 'test-v1');
  assert.strictEqual(bootstrap.buildHash, 'hash-a');
  assert.ok(runnerContext.context.__advisorRunner);

  const secondBootstrap = assertKeyBlock(runOperatorInContext('resident_runner_command', bootstrapArgs, runnerContext), [
    'result', 'runnerId', 'version', 'buildHash', 'url', 'state', 'eventSeq', 'message'
  ]);
  assert.strictEqual(secondBootstrap.result, 'ALREADY_BOOTSTRAPPED');
  assert.strictEqual(secondBootstrap.runnerId, bootstrap.runnerId);

  const status = assertKeyBlock(runOperatorInContext('resident_runner_command', baseArgs({
    command: 'status',
    expectedBuildHash: 'hash-a'
  }), runnerContext), [
    'result', 'running', 'stopRequested', 'version', 'buildHash', 'url', 'routeFamily', 'detectedState', 'eventSeq', 'eventCount'
  ]);
  assert.strictEqual(status.result, 'OK');
  assert.strictEqual(status.routeFamily, 'INTEL_102');
  assert.strictEqual(status.detectedState, 'RAPPORT');

  const stale = assertKeyBlock(runOperatorInContext('resident_runner_command', baseArgs({
    command: 'status',
    expectedBuildHash: 'hash-b'
  }), runnerContext), ['result', 'buildHash', 'routeFamily', 'detectedState']);
  assert.strictEqual(stale.result, 'STALE_BUILD');
  assert.strictEqual(stale.buildHash, 'hash-a');

  const stopped = assertKeyBlock(runOperatorInContext('resident_runner_command', baseArgs({
    command: 'stop',
    reason: 'smoke-stop'
  }), runnerContext), ['result', 'stopRequested', 'running', 'reason']);
  assert.strictEqual(stopped.result, 'OK');
  assert.strictEqual(stopped.stopRequested, '1');

  const reset = assertKeyBlock(runOperatorInContext('resident_runner_command', baseArgs({
    command: 'reset',
    clearEvents: '0',
    reason: 'smoke-reset'
  }), runnerContext), ['result', 'eventCount', 'stopRequested', 'running']);
  assert.strictEqual(reset.result, 'OK');
  assert.strictEqual(reset.stopRequested, '0');

  const events = assertKeyBlock(runOperatorInContext('resident_runner_command', baseArgs({
    command: 'getEvents',
    sinceSeq: '0',
    limit: '5'
  }), runnerContext), ['result', 'eventCount', 'truncated', 'eventsJson']);
  assert.strictEqual(events.result, 'OK');
  assert.strictEqual(events.truncated, '0');
  assert.ok(Array.isArray(JSON.parse(events.eventsJson)));

  const maxSteps = assertKeyBlock(runOperatorInContext('resident_runner_command', baseArgs({
    command: 'runUntilBlocked',
    readOnly: '1',
    maxSteps: '2',
    maxMs: '10000'
  }), runnerContext), [
    'result', 'blockedReason', 'steps', 'elapsedMs', 'url', 'routeFamily', 'detectedState', 'lastStatusOp', 'manualRequired', 'eventSeq'
  ]);
  assert.strictEqual(maxSteps.result, 'MAX_STEPS');
  assert.strictEqual(maxSteps.steps, '2');
  assert.strictEqual(safeButton.clickCalls, 0);

  const timeout = assertKeyBlock(runOperatorInContext('resident_runner_command', baseArgs({
    command: 'runUntilBlocked',
    readOnly: '1',
    maxSteps: '5',
    maxMs: '0'
  }), runnerContext), ['result', 'blockedReason', 'steps']);
  assert.strictEqual(timeout.result, 'TIMEOUT');
  assert.strictEqual(timeout.steps, '0');

  const refused = assertKeyBlock(runOperatorInContext('resident_runner_command', baseArgs({
    command: 'runUntilBlocked',
    readOnly: '0',
    maxSteps: '1'
  }), runnerContext), ['result', 'blockedReason', 'mutatingRequestRefused', 'manualRequired']);
  assert.strictEqual(refused.result, 'BLOCKED');
  assert.strictEqual(refused.mutatingRequestRefused, '1');

  runnerContext.context.document = pageDoc('Drivers and vehicles Add drivers Add vehicles', [
    createButton('profile-summary-submitBtn', 'Save')
  ]);
  runnerContext.context.location.href = 'https://advisorpro.allstate.com/#/apps/ASCPRODUCT/112/';
  const afterHashRoute = assertKeyBlock(runOperatorInContext('resident_runner_command', baseArgs({
    command: 'status',
    expectedBuildHash: 'hash-a'
  }), runnerContext), ['result', 'routeFamily', 'detectedState']);
  assert.strictEqual(afterHashRoute.result, 'OK');
  assert.strictEqual(afterHashRoute.routeFamily, 'ASCPRODUCT');
  assert.strictEqual(afterHashRoute.detectedState, 'ASC_PRODUCT');

  runnerContext.context.location.href = 'https://example.invalid/';
  runnerContext.context.document = pageDoc('Unknown page');
  const unknownRoute = assertKeyBlock(runOperatorInContext('resident_runner_command', baseArgs({
    command: 'runUntilBlocked',
    readOnly: '1',
    maxSteps: '5',
    maxMs: '10000'
  }), runnerContext), ['result', 'blockedReason', 'routeFamily', 'detectedState', 'manualRequired']);
  assert.strictEqual(unknownRoute.result, 'BLOCKED');
  assert.strictEqual(unknownRoute.blockedReason, 'unknown-route');
  assert.strictEqual(unknownRoute.routeFamily, 'UNKNOWN');
  assert.strictEqual(unknownRoute.manualRequired, '1');

  const freshContextStatus = assertKeyBlock(runOperator('resident_runner_command', {
    command: 'status'
  }, new FakeDocument()), ['result', 'eventCount']);
  assert.strictEqual(freshContextStatus.result, 'MISSING');
}

function testStateDetectionContract() {
  const cases = [
    ['CUSTOMER_SUMMARY_OVERVIEW', customerSummaryDoc(), 'https://advisorpro.allstate.com/#/apps/customer-summary/123/overview'],
    ['RAPPORT', gatherDataDoc(), 'https://advisorpro.allstate.com/#/apps/intel/102/rapport'],
    ['PRODUCT_OVERVIEW', productOverviewDoc(), 'https://advisorpro.allstate.com/#/apps/intel/102/overview'],
    ['SELECT_PRODUCT', selectProductDoc(), 'https://advisorpro.allstate.com/#/apps/intel/102/selectProduct'],
    ['DUPLICATE', duplicateDoc(), 'https://advisorpro.allstate.com/#/duplicate'],
    ['INCIDENTS', incidentsDoc(), 'https://advisorpro.allstate.com/#/apps/ASCPRODUCT/110/incidents'],
    ['ASC_PRODUCT', consumerReportsDoc(), 'https://advisorpro.allstate.com/#/apps/ASCPRODUCT/110/consumer'],
    ['ADVISOR_HOME', new FakeDocument([createButton('group2_Quoting_button', 'Quoting')]), 'https://advisorpro.allstate.com/#/home'],
    ['GATEWAY', pageDoc('Allstate Advisor Pro gateway'), 'https://gateway.local/'],
    ['NO_CONTEXT', new FakeDocument(), 'https://example.invalid/']
  ];

  for (const [expected, doc, href] of cases) {
    const actual = runOperator('detect_state', baseArgs(), doc, href);
    assert.strictEqual(actual, expected, `detect_state expected ${expected}`);
  }
}

function testCustomerSummaryOverviewStatusContract() {
  const requiredKeys = [
    'result', 'runtimeState', 'confidence', 'urlMatched', 'overviewMatched',
    'startHereMatched', 'quoteHistoryMatched', 'assetsDetailsMatched',
    'summaryAnchorMatched', 'startHereCount', 'evidence', 'missing', 'url'
  ];
  const href = 'https://advisorpro.allstate.com/#/apps/customer-summary/104/overview';

  const quoteHistory = assertKeyBlock(runOperator(
    'customer_summary_overview_status',
    baseArgs(),
    customerSummaryDocWithAnchors('Quote History'),
    href
  ), requiredKeys);
  assert.strictEqual(quoteHistory.result, 'DETECTED');
  assert.strictEqual(quoteHistory.runtimeState, 'CUSTOMER_SUMMARY_OVERVIEW');
  assert.strictEqual(quoteHistory.confidence, 'high');
  assert.strictEqual(quoteHistory.urlMatched, '1');
  assert.strictEqual(quoteHistory.startHereMatched, '1');
  assert.strictEqual(quoteHistory.quoteHistoryMatched, '1');
  assert.strictEqual(quoteHistory.summaryAnchorMatched, '1');
  assert.strictEqual(quoteHistory.startHereCount, '1');

  const assetsDetails = assertKeyBlock(runOperator(
    'customer_summary_overview_status',
    baseArgs(),
    customerSummaryDocWithAnchors('Assets Details'),
    href
  ), requiredKeys);
  assert.strictEqual(assetsDetails.result, 'DETECTED');
  assert.strictEqual(assetsDetails.runtimeState, 'CUSTOMER_SUMMARY_OVERVIEW');
  assert.strictEqual(assetsDetails.confidence, 'high');
  assert.strictEqual(assetsDetails.assetsDetailsMatched, '1');
  assert.strictEqual(assetsDetails.summaryAnchorMatched, '1');

  const medium = assertKeyBlock(runOperator(
    'customer_summary_overview_status',
    baseArgs(),
    pageDoc('START HERE (Pre-fill included) Add Product'),
    href
  ), requiredKeys);
  assert.strictEqual(medium.result, 'PARTIAL');
  assert.strictEqual(medium.runtimeState, 'CUSTOMER_SUMMARY_OVERVIEW');
  assert.strictEqual(medium.confidence, 'medium');
  assert.strictEqual(medium.urlMatched, '1');
  assert.strictEqual(medium.startHereMatched, '1');
  assert.strictEqual(medium.summaryAnchorMatched, '0');
  assert.strictEqual(runOperator('detect_state', baseArgs(), pageDoc('START HERE (Pre-fill included) Add Product'), href), 'CUSTOMER_SUMMARY_OVERVIEW');

  const notDetected = assertKeyBlock(runOperator(
    'customer_summary_overview_status',
    baseArgs(),
    customerSummaryDoc(),
    'https://advisorpro.allstate.com/#/apps/intel/102/overview'
  ), requiredKeys);
  assert.strictEqual(notDetected.result, 'NOT_DETECTED');
  assert.strictEqual(notDetected.runtimeState, '');
  assert.strictEqual(notDetected.confidence, 'none');
  assert.strictEqual(notDetected.urlMatched, '0');

  assert.strictEqual(runOperator('detect_state', baseArgs(), customerSummaryDoc(), href), 'CUSTOMER_SUMMARY_OVERVIEW');
  assert.strictEqual(runOperator('wait_condition', baseArgs({ name: 'is_customer_summary_overview' }), customerSummaryDoc(), href), '1');
  assert.strictEqual(runOperator('wait_condition', baseArgs({ name: 'post_prospect_submit' }), customerSummaryDoc(), href), '1');
}

function testCustomerSummaryStartHereClickContract() {
  const href = 'https://advisorpro.allstate.com/#/apps/customer-summary/104/overview';
  const requiredKeys = ['result', 'clicked', 'targetText', 'targetTag', 'targetClass', 'urlBefore', 'evidence'];

  const twoStartDoc = customerSummaryStartHereClickDoc();
  const clicked = assertKeyBlock(runOperator('click_customer_summary_start_here', baseArgs(), twoStartDoc, href), requiredKeys);
  assert.strictEqual(clicked.result, 'OK');
  assert.strictEqual(clicked.clicked, '1');
  assert.strictEqual(clicked.targetTag, 'BUTTON');
  assert.strictEqual(twoStartDoc.getElementById('main-start-here').clickCalls, 1);
  assert.strictEqual(twoStartDoc.getElementById('sidebar-add-product').clickCalls, 0);

  const decoyDoc = customerSummaryStartHereClickDoc({ includeStart: true, includeAddProduct: true, startText: 'START HERE' });
  const decoy = assertKeyBlock(runOperator('click_customer_summary_start_here', baseArgs(), decoyDoc, href), requiredKeys);
  assert.strictEqual(decoy.result, 'OK');
  assert.strictEqual(decoy.clicked, '1');
  assert.strictEqual(decoy.targetText, 'START HERE');
  assert.strictEqual(decoyDoc.getElementById('sidebar-add-product').clickCalls, 0);

  const missing = assertKeyBlock(runOperator('click_customer_summary_start_here', baseArgs(), customerSummaryStartHereClickDoc({ includeStart: false }), href), requiredKeys);
  assert.strictEqual(missing.result, 'NO_START_HERE');
  assert.strictEqual(missing.clicked, '0');

  const wrongPage = assertKeyBlock(runOperator(
    'click_customer_summary_start_here',
    baseArgs(),
    customerSummaryStartHereClickDoc(),
    'https://advisorpro.allstate.com/#/apps/intel/102/overview'
  ), requiredKeys);
  assert.strictEqual(wrongPage.result, 'NO_CUSTOMER_SUMMARY');
  assert.strictEqual(wrongPage.clicked, '0');
}

function assertWaitCondition(name, truthyDoc, truthyHref, falseyDoc = new FakeDocument(), falseyHref = 'https://example.invalid/') {
  assert.strictEqual(runOperator('wait_condition', baseArgs({ name }), truthyDoc, truthyHref), '1', `${name} should be 1`);
  assert.strictEqual(runOperator('wait_condition', baseArgs({ name }), falseyDoc, falseyHref), '0', `${name} should be 0`);
}

function runWaitFixture(name, fixtureName, extraArgs = {}) {
  const scenario = fixtureScenario(fixtureName);
  return runOperator('wait_condition', baseArgs(Object.assign({ name }, extraArgs)), scenario.doc, scenario.href);
}

function testWaitConditionContract() {
  assertWaitCondition('gather_data', gatherDataDoc(), 'https://advisorpro.allstate.com/#/apps/intel/102/rapport');
  assertWaitCondition('on_product_overview', productOverviewDoc(), 'https://advisorpro.allstate.com/#/apps/intel/102/overview');
  assertWaitCondition('to_select_product', selectProductDoc(), 'https://advisorpro.allstate.com/#/apps/intel/102/selectProduct');
  assertWaitCondition('gather_start_quoting_transition', consumerReportsDoc(), 'https://advisorpro.allstate.com/#/apps/ASCPRODUCT/110/consumer');

  const enabledVehicleSelect = new FakeDocument([
    createSelect('ConsumerData.Assets.Vehicles[0].Manufacturer', [
      { value: '', text: 'Select One' },
      { value: 'FORD', text: 'Ford' }
    ])
  ]);
  assert.strictEqual(runOperator('wait_condition', baseArgs({ name: 'vehicle_select_enabled', index: 0, fieldName: 'Manufacturer' }), enabledVehicleSelect), '1');
  assert.strictEqual(runOperator('wait_condition', baseArgs({ name: 'vehicle_select_enabled', index: 0, fieldName: 'Manufacturer' }), new FakeDocument()), '0');

  assertWaitCondition('on_select_product', selectProductDoc(), 'https://advisorpro.allstate.com/#/apps/intel/102/selectProduct');
  assertWaitCondition('select_product_to_consumer', consumerReportsDoc(), 'https://advisorpro.allstate.com/#/apps/ASCPRODUCT/110/consumer');
  assertWaitCondition('consumer_reports_ready', consumerReportsDoc(), 'https://advisorpro.allstate.com/#/apps/ASCPRODUCT/110/consumer');
  assertWaitCondition('drivers_or_incidents', driversVehiclesDoc(), 'https://advisorpro.allstate.com/#/apps/ASCPRODUCT/110/profile');
  assertWaitCondition('after_driver_vehicle_continue', incidentsDoc(), 'https://advisorpro.allstate.com/#/apps/ASCPRODUCT/110/incidents');

  assert.strictEqual(runOperator('wait_condition', baseArgs({ name: 'add_asset_modal_closed', addAssetSaveId: 'ADD_ASSET_SAVE-btn' }), new FakeDocument()), '1');
  assert.strictEqual(runOperator('wait_condition', baseArgs({ name: 'add_asset_modal_closed', addAssetSaveId: 'ADD_ASSET_SAVE-btn' }), new FakeDocument([createButton('ADD_ASSET_SAVE-btn', 'Save')])), '0');

  assert.strictEqual(runOperator('wait_condition', baseArgs({ name: 'continue_enabled', buttonId: 'profile-summary-submitBtn' }), new FakeDocument([createButton('profile-summary-submitBtn', 'Continue')])), '1');
  assert.strictEqual(runOperator('wait_condition', baseArgs({ name: 'continue_enabled', buttonId: 'profile-summary-submitBtn' }), new FakeDocument([createButton('profile-summary-submitBtn', 'Continue', { disabled: true })])), '0');

  assertWaitCondition('incidents_done', quoteLandingDoc(), 'https://advisorpro.allstate.com/#/apps/ASCPRODUCT/110/quote');
  assertWaitCondition('quote_landing', quoteLandingDoc(), 'https://advisorpro.allstate.com/#/apps/ASCPRODUCT/110/quote');
  assertWaitCondition('is_duplicate', duplicateDoc(), 'https://advisorpro.allstate.com/#/duplicate');
  assertWaitCondition('is_rapport', gatherDataDoc(), 'https://advisorpro.allstate.com/#/apps/intel/102/rapport');
  assertWaitCondition('is_select_product', selectProductDoc(), 'https://advisorpro.allstate.com/#/apps/intel/102/selectProduct');
  assertWaitCondition('is_asc', consumerReportsDoc(), 'https://advisorpro.allstate.com/#/apps/ASCPRODUCT/110/consumer');
  assertWaitCondition('is_incidents', incidentsDoc(), 'https://advisorpro.allstate.com/#/apps/ASCPRODUCT/110/incidents');
}

function testRemainingWaitConditionBranches() {
  assert.strictEqual(runWaitFixture('post_prospect_submit', 'duplicate-page-after-prospect-submit', {
    rapportContains: BASE_URLS.rapportContains,
    selectProductContains: BASE_URLS.selectProductContains
  }), '1');
  assert.strictEqual(runWaitFixture('post_prospect_submit', 'customer-summary-overview', {
    customerSummaryContains: BASE_URLS.customerSummaryContains,
    rapportContains: BASE_URLS.rapportContains,
    selectProductContains: BASE_URLS.selectProductContains
  }), '1');
  assert.strictEqual(runOperator('wait_condition', baseArgs({
    name: 'post_prospect_submit',
    rapportContains: BASE_URLS.rapportContains,
    selectProductContains: BASE_URLS.selectProductContains
  }), new FakeDocument(), 'https://example.invalid/'), '0');

  assert.strictEqual(runWaitFixture('prospect_form_ready', 'create-prospect-form-ready'), '1');
  assert.strictEqual(runOperator('wait_condition', baseArgs({ name: 'prospect_form_ready' }), new FakeDocument([
    createInput('ConsumerData.People[0].Name.GivenName', 'Alex')
  ]), 'https://advisorpro.allstate.com/#/apps/intel/102/start'), '0');

  assert.strictEqual(runWaitFixture('duplicate_to_next', 'customer-summary-overview', {
    customerSummaryContains: BASE_URLS.customerSummaryContains,
    rapportContains: BASE_URLS.rapportContains,
    selectProductContains: BASE_URLS.selectProductContains
  }), '1');
  assert.strictEqual(runWaitFixture('duplicate_to_next', 'duplicate-page-after-prospect-submit', {
    customerSummaryContains: BASE_URLS.customerSummaryContains,
    rapportContains: BASE_URLS.rapportContains,
    selectProductContains: BASE_URLS.selectProductContains
  }), '0');

  assert.strictEqual(runWaitFixture('on_customer_summary_overview', 'customer-summary-overview'), '1');
  assert.strictEqual(runWaitFixture('on_customer_summary_overview', 'product-overview'), '0');

  const vehicleArgs = { year: '2022', make: 'Tesla', model: 'Model 3' };
  assert.strictEqual(runWaitFixture('vehicle_added_tile', 'gather-data-vehicle-tile-added', vehicleArgs), '1');
  assert.strictEqual(runWaitFixture('vehicle_added_tile', 'potential-vehicle-card-with-confirm', vehicleArgs), '0');

  assert.strictEqual(runWaitFixture('vehicle_confirmed', 'confirmed-potential-vehicle-card', vehicleArgs), '1');
  assert.strictEqual(runWaitFixture('vehicle_confirmed', 'potential-vehicle-card-with-confirm', vehicleArgs), '0');

  assert.strictEqual(runWaitFixture('is_customer_summary_overview', 'customer-summary-overview'), '1');
  assert.strictEqual(runWaitFixture('is_customer_summary_overview', 'product-overview'), '0');

  assert.strictEqual(runWaitFixture('is_product_overview', 'product-overview'), '1');
  assert.strictEqual(runWaitFixture('is_product_overview', 'customer-summary-overview'), '0');
}

function createProspectFormDoc() {
  return new FakeDocument([
    createInput('ConsumerData.People[0].Name.GivenName', 'John'),
    createInput('ConsumerData.People[0].Name.Surname', 'Smith'),
    createInput('ConsumerData.People[0].Personal.BirthDt', '01/01/1980'),
    createSelect('ConsumerData.People[0].Personal.GenderCd.SrcCd', [
      { value: 'M', text: 'Male', selected: true }
    ]),
    createInput('ConsumerData.Assets.Properties[0].Addr.Addr1', '123 Main St'),
    createInput('ConsumerData.Assets.Properties[0].Addr.City', 'Miami'),
    createSelect('ConsumerData.Assets.Properties[0].Addr.StateProvCd.SrcCd', [
      { value: 'FL', text: 'Florida', selected: true }
    ]),
    createInput('ConsumerData.Assets.Properties[0].Addr.PostalCode', '33101'),
    createInput('ConsumerData.People[0].Communications.PhoneNumber', '5555550100'),
    createButton('PrimaryApplicant-Continue-button', 'Continue')
  ]);
}

function testReturnShapeContracts() {
  assertKeyBlock(runOperator('prospect_form_status', { selectors: BASE_SELECTORS }, createProspectFormDoc()), [
    'ready', 'firstName', 'lastName', 'dob', 'gender', 'address', 'city', 'state', 'zip', 'phone', 'submitPresent', 'submitEnabled', 'errors'
  ]);

  const filledGatherDoc = gatherDataDoc();
  const filledGather = assertKeyBlock(runOperator('fill_gather_defaults', {
    ageValue: '16',
    emailValue: 'test@example.com',
    ownershipValue: 'RE',
    homeTypeValue: 'AP'
  }, filledGatherDoc), ['result', 'ageApplied', 'emailApplied', 'ownershipApplied', 'homeTypeApplied']);
  assert.strictEqual(filledGather.result, 'OK');

  assertKeyBlock(runOperator('gather_defaults_status', {}, filledGatherDoc), [
    'ageFirstLicensed', 'email', 'ownershipTypeValue', 'homeTypeValue', 'licenseStateValue', 'alerts'
  ]);

  assertKeyBlock(runOperator('gather_start_quoting_status', { selectors: BASE_SELECTORS }, gatherDataDoc()), [
    'hasStartQuotingText', 'startQuotingSectionPresent', 'autoProductPresent', 'autoProductSelected', 'autoProductSource', 'autoCheckboxId', 'ratingStatePresent', 'ratingStateValue', 'createQuoteButtonPresent', 'createQuoteButtonEnabled', 'addProductLinkPresent', 'createQuotesPresent', 'createQuotesEnabled', 'addProductPresent', 'evidence', 'missing'
  ]);

  const startState = assertKeyBlock(runOperator('ensure_auto_start_quoting_state', baseArgs({ ratingState: 'FL' }), gatherDataDoc()), ['result']);
  assert.ok(['OK', 'FAILED'].includes(startState.result));

  const selectDoc = selectProductDoc();
  const selectDefaults = assertKeyBlock(runOperator('set_select_product_defaults', baseArgs({
    ratingState: 'FL',
    productValue: 'Auto',
    currentInsured: 'YES',
    ownOrRent: 'OWN'
  }), selectDoc), ['result', 'productSet', 'ratingStateSet', 'currentInsuredSet', 'ownOrRentSet']);
  assert.strictEqual(selectDefaults.result, 'OK');

  assertKeyBlock(runOperator('select_product_status', baseArgs(), selectDoc), [
    'productValue', 'ratingStateValue', 'currentInsuredValue', 'ownOrRentValue', 'continuePresent', 'continueEnabled'
  ]);

  const participant = assertKeyBlock(runOperator('fill_participant_modal', baseArgs({
    ageFirstLicensed: '16',
    email: 'driver@example.com',
    military: 'false',
    violations: 'false',
    defensiveDriving: 'false',
    propertyOwnership: '0001_0120',
    spouseSelectId: 'maritalStatusWithSpouse_spouseName',
    spouseValue: '',
    expectedGender: 'M',
    oppositeGenderValue: 'F'
  }), createParticipantModalDoc()), ['result', 'ageFirstLicensedSet', 'emailSet', 'militarySet', 'violationsSet', 'propertyOwnershipSet']);
  assert.strictEqual(participant.result, 'OK');

  const vehicleModal = assertKeyBlock(runOperator('fill_vehicle_modal', { threshold: 2015 }, createVehicleModalDoc()), [
    'result', 'garagingAddressSameAsOtherClicked', 'purchaseDateFalseClicked', 'ownershipClicked', 'detectedYear'
  ]);
  assert.strictEqual(vehicleModal.result, 'OK');

  const scanRaw = runOperator('scan_current_page', { label: 'SMOKE', reason: 'contract' }, new FakeDocument([
    textNode('Customer heading', 'h1'),
    createInput('firstName', 'John'),
    createButton('continueBtn', 'Continue')
  ]));
  const scan = JSON.parse(scanRaw);
  assert.strictEqual(scan.stepLabel, 'SMOKE');
  assert.strictEqual(scan.scanReason, 'contract');
  assert.ok(Array.isArray(scan.fields));
  assert.ok(Array.isArray(scan.buttons));
}

function testGenericOpsContract() {
  const button = createButton('clickMe', 'Continue');
  assert.strictEqual(runOperator('click_by_id', { id: 'clickMe' }, new FakeDocument([button])), 'OK');
  assert.strictEqual(runOperator('click_by_id', { id: 'missing' }, new FakeDocument()), 'NO');
  assert.strictEqual(runOperator('click_by_text', { text: 'Continue', tagSelector: 'button' }, new FakeDocument([createButton('continue', 'Continue')])), 'OK');
  assert.strictEqual(runOperator('click_by_text', { text: 'Missing', tagSelector: 'button' }, new FakeDocument([createButton('continue', 'Continue')])), 'NO');

  assert.strictEqual(runOperator('focus_prospect_first_input', { selectors: BASE_SELECTORS }, createProspectFormDoc()), '1');
  assert.strictEqual(runOperator('focus_prospect_first_input', { selectors: BASE_SELECTORS }, new FakeDocument()), '0');

  assert.strictEqual(runOperator('modal_exists', { saveButtonId: 'SAVE-btn' }, new FakeDocument([createButton('SAVE-btn', 'Save')])), '1');
  assert.strictEqual(runOperator('modal_exists', { saveButtonId: 'SAVE-btn' }, new FakeDocument()), '0');

  assert.strictEqual(runOperator('select_remove_reason', { reasonCode: '0006' }, new FakeDocument([createRadio('nonDriverReasonOthers_0006', 'reason', '0006')])), 'OK');
  assert.strictEqual(runOperator('select_remove_reason', { reasonCode: '0006' }, new FakeDocument()), 'NO_REASON');

  assert.strictEqual(runOperator('handle_incidents', { reasonText: BASE_DEFAULTS.incidentReasonText, incidentContinueId: 'CONTINUE_OFFER-btn' }, createIncidentActionDoc(true, true)), 'OK');
  assert.strictEqual(runOperator('handle_incidents', { reasonText: BASE_DEFAULTS.incidentReasonText, incidentContinueId: 'CONTINUE_OFFER-btn' }, createIncidentActionDoc(false, true)), 'NO_REASON');
  assert.strictEqual(runOperator('handle_incidents', { reasonText: BASE_DEFAULTS.incidentReasonText, incidentContinueId: 'CONTINUE_OFFER-btn' }, createIncidentActionDoc(true, false)), 'NO_CONTINUE');

  assert.strictEqual(runOperator('click_create_quotes_order_reports', { selectors: BASE_SELECTORS }, gatherDataDoc()), 'OK');
  assert.strictEqual(runOperator('click_create_quotes_order_reports', { selectors: BASE_SELECTORS }, new FakeDocument()), 'NO_BUTTON');
  assert.strictEqual(runOperator('click_create_quotes_order_reports', { selectors: BASE_SELECTORS }, new FakeDocument([createButton('consentModalTrigger', 'Create Quotes', { disabled: true })])), 'DISABLED');
  assert.strictEqual(runOperator('click_create_quotes_order_reports', { selectors: BASE_SELECTORS }, new FakeDocument([createButton('consentModalTrigger', 'Create Quotes', { clickThrows: true })])), 'CLICK_FAILED');

  assert.strictEqual(runOperator('click_start_quoting_add_product', { selectors: BASE_SELECTORS }, gatherDataDoc()), 'OK');
  assert.strictEqual(runOperator('click_start_quoting_add_product', { selectors: BASE_SELECTORS }, new FakeDocument()), 'NO_BUTTON');
  assert.strictEqual(runOperator('click_start_quoting_add_product', { selectors: BASE_SELECTORS }, new FakeDocument([createButton('quotesButton', 'Add Product', { disabled: true })])), 'DISABLED');
  assert.strictEqual(runOperator('click_start_quoting_add_product', { selectors: BASE_SELECTORS }, new FakeDocument([createButton('quotesButton', 'Add Product', { clickThrows: true })])), 'CLICK_FAILED');

  const clickTile = createProductOverviewTile();
  assert.strictEqual(runOperator('click_product_overview_tile', baseArgs(), productOverviewDoc([clickTile.outer]), 'https://advisorpro.allstate.com/#/apps/intel/102/overview'), 'OK');
  assert.strictEqual(clickTile.tile.clickCalls, 1);
  const clickButtonTile = createProductOverviewTile({ clickable: true });
  assert.strictEqual(runOperator('click_product_overview_tile', baseArgs(), productOverviewDoc([clickButtonTile.outer]), 'https://advisorpro.allstate.com/#/apps/intel/102/overview'), 'OK');
  assert.strictEqual(clickButtonTile.clickableTarget.clickCalls, 1);
  const clickToSelectTile = createProductOverviewTile({
    tileOnClick: (tile) => {
      tile.className = `${tile.className} l-tile--selected`;
    }
  });
  const clickToSelectDoc = productOverviewDoc([clickToSelectTile.outer]);
  assert.strictEqual(runOperator('click_product_overview_tile', baseArgs(), clickToSelectDoc, 'https://advisorpro.allstate.com/#/apps/intel/102/overview'), 'OK');
  assert.strictEqual(clickToSelectTile.tile.clickCalls, 1);
  const clickToSelectStatus = assertKeyBlock(runOperator('product_overview_tile_status', baseArgs(), clickToSelectDoc, 'https://advisorpro.allstate.com/#/apps/intel/102/overview'), ['result', 'selected']);
  assert.strictEqual(clickToSelectStatus.result, 'SELECTED');
  assert.strictEqual(clickToSelectStatus.selected, '1');
  const ensureSelectedTile = createProductOverviewTile({
    tileOnClick: (tile) => {
      tile.className = `${tile.className} l-tile--selected`;
    }
  });
  const ensureSelectedStatus = assertKeyBlock(runOperator('ensure_product_overview_tile_selected', baseArgs(), productOverviewDoc([ensureSelectedTile.outer]), 'https://advisorpro.allstate.com/#/apps/intel/102/overview'), [
    'result', 'present', 'selectedBefore', 'selectedAfter', 'clicked', 'selectedEvidence', 'failedFields'
  ]);
  assert.strictEqual(ensureSelectedStatus.result, 'CLICKED_SELECTED');
  assert.strictEqual(ensureSelectedStatus.selectedBefore, '0');
  assert.strictEqual(ensureSelectedStatus.selectedAfter, '1');
  assert.strictEqual(ensureSelectedStatus.clicked, '1');
  assert.strictEqual(ensureSelectedTile.tile.clickCalls, 1);
  const ensureVerifyFailTile = createProductOverviewTile();
  const ensureVerifyFailStatus = assertKeyBlock(runOperator('ensure_product_overview_tile_selected', baseArgs(), productOverviewDoc([ensureVerifyFailTile.outer]), 'https://advisorpro.allstate.com/#/apps/intel/102/overview'), [
    'result', 'present', 'selectedBefore', 'selectedAfter', 'clicked', 'failedFields'
  ]);
  assert.strictEqual(ensureVerifyFailStatus.result, 'VERIFY_FAILED');
  assert.strictEqual(ensureVerifyFailStatus.selectedAfter, '0');
  assert.strictEqual(ensureVerifyFailStatus.clicked, '1');
  const selectedClickSkippedTile = createProductOverviewTile({ tileClass: 'l-tile l-tile--selected' });
  assert.strictEqual(runOperator('click_product_overview_tile', baseArgs(), productOverviewDoc([selectedClickSkippedTile.outer]), 'https://advisorpro.allstate.com/#/apps/intel/102/overview'), 'OK');
  assert.strictEqual(selectedClickSkippedTile.tile.clickCalls, 0);
  const ensureAlreadySelectedTile = createProductOverviewTile({ tileClass: 'l-tile l-tile--selected' });
  const ensureAlreadySelectedStatus = assertKeyBlock(runOperator('ensure_product_overview_tile_selected', baseArgs(), productOverviewDoc([ensureAlreadySelectedTile.outer]), 'https://advisorpro.allstate.com/#/apps/intel/102/overview'), [
    'result', 'selectedBefore', 'selectedAfter', 'clicked'
  ]);
  assert.strictEqual(ensureAlreadySelectedStatus.result, 'SELECTED');
  assert.strictEqual(ensureAlreadySelectedStatus.clicked, '0');
  assert.strictEqual(ensureAlreadySelectedTile.tile.clickCalls, 0);
  const selectedToggleRiskTile = createProductOverviewTile({
    tileClass: 'l-tile l-tile--selected',
    tileOnClick: (tile) => {
      tile.className = 'l-tile';
    }
  });
  const selectedToggleRiskDoc = productOverviewDoc([selectedToggleRiskTile.outer]);
  assert.strictEqual(runOperator('click_product_overview_tile', baseArgs(), selectedToggleRiskDoc, 'https://advisorpro.allstate.com/#/apps/intel/102/overview'), 'OK');
  assert.strictEqual(selectedToggleRiskTile.tile.clickCalls, 0);
  const selectedToggleRiskStatus = assertKeyBlock(runOperator('product_overview_tile_status', baseArgs(), selectedToggleRiskDoc, 'https://advisorpro.allstate.com/#/apps/intel/102/overview'), ['result', 'selected']);
  assert.strictEqual(selectedToggleRiskStatus.result, 'SELECTED');
  assert.strictEqual(selectedToggleRiskStatus.selected, '1');
  assert.strictEqual(runOperator('click_product_overview_tile', baseArgs(), productOverviewDoc(), 'https://advisorpro.allstate.com/#/apps/intel/102/overview'), 'NO_TILE');
  assert.strictEqual(runOperator('click_product_overview_tile', baseArgs(), new FakeDocument([createButton('autoTile', 'Auto')]), 'https://example.invalid/'), 'NOT_OVERVIEW');
  const failingClickTile = createProductOverviewTile({ clickable: true });
  failingClickTile.clickableTarget.clickThrows = true;
  assert.strictEqual(runOperator('click_product_overview_tile', baseArgs(), productOverviewDoc([failingClickTile.outer]), 'https://advisorpro.allstate.com/#/apps/intel/102/overview'), 'CLICK_FAILED');

  const selectedClassTile = createProductOverviewTile({ tileClass: 'l-tile l-tile--selected' });
  const selectedOverviewStatus = assertKeyBlock(runOperator('product_overview_tile_status', baseArgs(), productOverviewDoc([
    selectedClassTile.outer
  ]), 'https://advisorpro.allstate.com/#/apps/intel/102/overview'), ['result', 'present', 'selected', 'productText', 'tileText', 'method', 'selectedEvidence', 'tileContainerClass', 'clickableClass', 'selectedClassSource']);
  assert.strictEqual(selectedOverviewStatus.result, 'SELECTED');
  assert.strictEqual(selectedOverviewStatus.present, '1');
  assert.strictEqual(selectedOverviewStatus.selected, '1');
  assert.strictEqual(selectedOverviewStatus.selectedEvidence, 'target-class');
  assert.match(selectedOverviewStatus.tileContainerClass, /l-tile--selected/);
  assert.match(selectedOverviewStatus.selectedClassSource, /l-tile--selected/);
  const ancestorTile = createProductOverviewTile({ tileClass: 'product-card is-selected' });
  const ancestorSelectedOverviewStatus = assertKeyBlock(runOperator('product_overview_tile_status', baseArgs(), productOverviewDoc([
    ancestorTile.outer
  ]), 'https://advisorpro.allstate.com/#/apps/intel/102/overview'), ['result', 'present', 'selected', 'selectedEvidence', 'targetClass']);
  assert.strictEqual(ancestorSelectedOverviewStatus.result, 'SELECTED');
  assert.strictEqual(ancestorSelectedOverviewStatus.selected, '1');
  assert.strictEqual(ancestorSelectedOverviewStatus.selectedEvidence, 'target-class');
  assert.match(ancestorSelectedOverviewStatus.targetClass, /is-selected/);
  const ariaTile = createProductOverviewTile({ clickable: true, clickableAttributes: { 'aria-pressed': 'true' } });
  const ariaSelectedOverviewStatus = assertKeyBlock(runOperator('product_overview_tile_status', baseArgs(), productOverviewDoc([
    ariaTile.outer
  ]), 'https://advisorpro.allstate.com/#/apps/intel/102/overview'), ['result', 'present', 'selected', 'selectedEvidence', 'targetAriaPressed', 'selectedAriaSource']);
  assert.strictEqual(ariaSelectedOverviewStatus.result, 'SELECTED');
  assert.strictEqual(ariaSelectedOverviewStatus.selected, '1');
  assert.strictEqual(ariaSelectedOverviewStatus.selectedEvidence, 'target-aria-pressed');
  assert.strictEqual(ariaSelectedOverviewStatus.targetAriaPressed, 'true');
  assert.match(ariaSelectedOverviewStatus.selectedAriaSource, /button/);
  const checkedDescendantTile = createProductOverviewTile({ checkedDescendant: true });
  const checkedDescendantStatus = assertKeyBlock(runOperator('product_overview_tile_status', baseArgs(), productOverviewDoc([
    checkedDescendantTile.outer
  ]), 'https://advisorpro.allstate.com/#/apps/intel/102/overview'), ['result', 'present', 'selected', 'selectedEvidence', 'checkedDescendant']);
  assert.strictEqual(checkedDescendantStatus.result, 'SELECTED');
  assert.strictEqual(checkedDescendantStatus.selected, '1');
  assert.strictEqual(checkedDescendantStatus.selectedEvidence, 'target-checked-descendant');
  assert.strictEqual(checkedDescendantStatus.checkedDescendant, '1');
  const checkmarkTile = createProductOverviewTile({ checkmark: true });
  const checkmarkStatus = assertKeyBlock(runOperator('product_overview_tile_status', baseArgs(), productOverviewDoc([
    checkmarkTile.outer
  ]), 'https://advisorpro.allstate.com/#/apps/intel/102/overview'), ['result', 'present', 'selected', 'selectedEvidence', 'checkmarkEvidence']);
  assert.strictEqual(checkmarkStatus.result, 'SELECTED');
  assert.strictEqual(checkmarkStatus.selected, '1');
  assert.strictEqual(checkmarkStatus.selectedEvidence, 'tile-container-checkmark');
  assert.match(checkmarkStatus.checkmarkEvidence, /checkmark/);
  const unrelatedCheckmark = new FakeElement('div', { className: 'c-icon c-icon--checkmark', text: '✓' });
  const unselectedTileWithOutsideCheckmark = createProductOverviewTile();
  const outsideCheckmarkStatus = assertKeyBlock(runOperator('product_overview_tile_status', baseArgs(), productOverviewDoc([
    unselectedTileWithOutsideCheckmark.outer,
    unrelatedCheckmark
  ]), 'https://advisorpro.allstate.com/#/apps/intel/102/overview'), ['result', 'selected', 'checkmarkEvidence']);
  assert.strictEqual(outsideCheckmarkStatus.result, 'FOUND');
  assert.strictEqual(outsideCheckmarkStatus.selected, '0');
  assert.strictEqual(outsideCheckmarkStatus.checkmarkEvidence, '');
  const unselectedTile = createProductOverviewTile();
  const unselectedOverviewStatus = assertKeyBlock(runOperator('product_overview_tile_status', baseArgs(), productOverviewDoc([
    unselectedTile.outer
  ]), 'https://advisorpro.allstate.com/#/apps/intel/102/overview'), ['result', 'present', 'selected', 'productText', 'tileText', 'method', 'selectedEvidence', 'tileContainerClass']);
  assert.strictEqual(unselectedOverviewStatus.result, 'FOUND');
  assert.strictEqual(unselectedOverviewStatus.present, '1');
  assert.strictEqual(unselectedOverviewStatus.selected, '0');
  assert.strictEqual(unselectedOverviewStatus.selectedEvidence, '');
  assert.match(unselectedOverviewStatus.tileContainerClass, /l-tile/);
  const saveEnabledUnselectedStatus = assertKeyBlock(runOperator('product_overview_tile_status', baseArgs(), productOverviewDoc([
    createButton('saveOverview', 'Save & Continue to Gather Data'),
    createProductOverviewTile().outer
  ]), 'https://advisorpro.allstate.com/#/apps/intel/102/overview'), ['result', 'present', 'selected', 'selectedEvidence', 'resolverMethod', 'tileProductLabelCount', 'clickTargetTag']);
  assert.strictEqual(saveEnabledUnselectedStatus.result, 'FOUND');
  assert.strictEqual(saveEnabledUnselectedStatus.selected, '0');
  assert.strictEqual(saveEnabledUnselectedStatus.selectedEvidence, '');
  assert.strictEqual(saveEnabledUnselectedStatus.resolverMethod, 'a3-text-seed-tile-card-target');

  const liveTileGrid = productOverviewLiveTileGridDoc();
  const liveTileGridStatus = assertKeyBlock(runOperator('product_overview_tile_status', baseArgs(), liveTileGrid.doc, 'https://advisorpro.allstate.com/#/apps/intel/102/overview'), [
    'result', 'present', 'selected', 'resolverMethod', 'textSeedText', 'tileContainerClass', 'tileProductLabelCount', 'clickTargetTag', 'clickTargetClass'
  ]);
  assert.strictEqual(liveTileGridStatus.result, 'FOUND');
  assert.strictEqual(liveTileGridStatus.selected, '0');
  assert.strictEqual(liveTileGridStatus.textSeedText, 'Auto');
  assert.strictEqual(liveTileGridStatus.tileProductLabelCount, '1');
  assert.match(liveTileGridStatus.tileContainerClass, /product-card/);
  const liveTileEnsure = assertKeyBlock(runOperator('ensure_product_overview_tile_selected', baseArgs(), liveTileGrid.doc, 'https://advisorpro.allstate.com/#/apps/intel/102/overview'), [
    'result', 'selectedBefore', 'selectedAfter', 'clicked', 'resolverMethod', 'tileProductLabelCount', 'clickTargetTag', 'clickAttemptCount'
  ]);
  assert.strictEqual(liveTileEnsure.result, 'CLICKED_SELECTED');
  assert.strictEqual(liveTileEnsure.selectedBefore, '0');
  assert.strictEqual(liveTileEnsure.selectedAfter, '1');
  assert.strictEqual(liveTileEnsure.clicked, '1');
  assert.strictEqual(liveTileEnsure.clickAttemptCount, '1');
  assert.strictEqual(liveTileGrid.autoTile.clickCalls, 1);
  assert.strictEqual(liveTileGrid.doc.getElementById('save-overview').clickCalls, 0);

  const alreadySelectedLiveTileGrid = productOverviewLiveTileGridDoc({ selected: true });
  const alreadySelectedLiveEnsure = assertKeyBlock(runOperator('ensure_product_overview_tile_selected', baseArgs(), alreadySelectedLiveTileGrid.doc, 'https://advisorpro.allstate.com/#/apps/intel/102/overview'), [
    'result', 'selectedBefore', 'selectedAfter', 'clicked'
  ]);
  assert.strictEqual(alreadySelectedLiveEnsure.result, 'SELECTED');
  assert.strictEqual(alreadySelectedLiveEnsure.clicked, '0');
  assert.strictEqual(alreadySelectedLiveTileGrid.autoTile.clickCalls, 0);

  const broadDirectGrid = productOverviewLiveTileGridDoc({ broadDirectSeed: true });
  broadDirectGrid.autoTile.className = '';
  const broadDirectStatus = assertKeyBlock(runOperator('product_overview_tile_status', baseArgs(), broadDirectGrid.doc, 'https://advisorpro.allstate.com/#/apps/intel/102/overview'), [
    'result', 'present', 'selected', 'rejectedBroadContainer', 'tileProductLabelCount', 'textSeedText'
  ]);
  assert.strictEqual(broadDirectStatus.result, 'FOUND');
  assert.strictEqual(broadDirectStatus.present, '1');
  assert.strictEqual(broadDirectStatus.rejectedBroadContainer, '1');
  assert.strictEqual(broadDirectStatus.tileProductLabelCount, '1');
  assert.notStrictEqual(broadDirectStatus.tileProductLabelCount, '11');

  const brokenLiveTileGrid = productOverviewLiveTileGridDoc({ brokenClick: true });
  const brokenLiveEnsure = assertKeyBlock(runOperator('ensure_product_overview_tile_selected', baseArgs(), brokenLiveTileGrid.doc, 'https://advisorpro.allstate.com/#/apps/intel/102/overview'), [
    'result', 'selectedBefore', 'selectedAfter', 'clicked', 'failedFields'
  ]);
  assert.strictEqual(brokenLiveEnsure.result, 'VERIFY_FAILED');
  assert.strictEqual(brokenLiveEnsure.clicked, '1');
  assert.strictEqual(brokenLiveEnsure.selectedAfter, '0');
  const missingOverviewStatus = assertKeyBlock(runOperator('product_overview_tile_status', baseArgs(), productOverviewDoc(), 'https://advisorpro.allstate.com/#/apps/intel/102/overview'), ['result', 'present', 'selected']);
  assert.strictEqual(missingOverviewStatus.result, 'NO_TILE');
  assert.strictEqual(missingOverviewStatus.present, '0');
  const wrongPageOverviewStatus = assertKeyBlock(runOperator('product_overview_tile_status', baseArgs(), new FakeDocument(), 'https://example.invalid/'), ['result', 'present', 'selected']);
  assert.strictEqual(wrongPageOverviewStatus.result, 'NOT_OVERVIEW');

  const selectedFixture = fixtureScenario('product-overview-auto-selected');
  const selectedFixtureStatus = assertKeyBlock(runOperator('product_overview_tile_status', baseArgs(), selectedFixture.doc, selectedFixture.href), ['result', 'present', 'selected']);
  assert.strictEqual(selectedFixtureStatus.result, 'SELECTED');
  assert.strictEqual(selectedFixtureStatus.selected, '1');
  const unselectedFixture = fixtureScenario('product-overview-auto-unselected');
  const unselectedFixtureStatus = assertKeyBlock(runOperator('product_overview_tile_status', baseArgs(), unselectedFixture.doc, unselectedFixture.href), ['result', 'present', 'selected']);
  assert.strictEqual(unselectedFixtureStatus.result, 'FOUND');
  assert.strictEqual(unselectedFixtureStatus.selected, '0');
  const saveEnabledUnselectedFixture = fixtureScenario('product-overview-auto-unselected-save-enabled');
  const saveEnabledUnselectedFixtureStatus = assertKeyBlock(runOperator('product_overview_tile_status', baseArgs(), saveEnabledUnselectedFixture.doc, saveEnabledUnselectedFixture.href), ['result', 'present', 'selected', 'selectedEvidence']);
  assert.strictEqual(saveEnabledUnselectedFixtureStatus.result, 'FOUND');
  assert.strictEqual(saveEnabledUnselectedFixtureStatus.selected, '0');
  assert.strictEqual(saveEnabledUnselectedFixtureStatus.selectedEvidence, '');
  const liveNonButtonFixture = fixtureScenario('product-overview-live-auto-nonbutton');
  const liveNonButtonFixtureStatus = assertKeyBlock(runOperator('product_overview_tile_status', baseArgs(), liveNonButtonFixture.doc, liveNonButtonFixture.href), [
    'result', 'present', 'selected', 'resolverMethod', 'tileContainerClass', 'tileProductLabelCount', 'clickTargetTag'
  ]);
  assert.strictEqual(liveNonButtonFixtureStatus.result, 'FOUND');
  assert.strictEqual(liveNonButtonFixtureStatus.selected, '0');
  assert.match(liveNonButtonFixtureStatus.tileContainerClass, /product-card/);
  assert.strictEqual(liveNonButtonFixtureStatus.tileProductLabelCount, '1');
  const liveNonButtonSelectedFixture = fixtureScenario('product-overview-live-auto-nonbutton-selected');
  const liveNonButtonSelectedFixtureStatus = assertKeyBlock(runOperator('product_overview_tile_status', baseArgs(), liveNonButtonSelectedFixture.doc, liveNonButtonSelectedFixture.href), [
    'result', 'present', 'selected', 'selectedEvidence'
  ]);
  assert.strictEqual(liveNonButtonSelectedFixtureStatus.result, 'SELECTED');
  assert.strictEqual(liveNonButtonSelectedFixtureStatus.selected, '1');
  const missingFixture = fixtureScenario('product-overview-auto-missing');
  const missingFixtureStatus = assertKeyBlock(runOperator('product_overview_tile_status', baseArgs(), missingFixture.doc, missingFixture.href), ['result', 'present', 'selected']);
  assert.strictEqual(missingFixtureStatus.result, 'NO_TILE');
  const wrongPageFixture = fixtureScenario('product-overview-wrong-page');
  const wrongPageFixtureStatus = assertKeyBlock(runOperator('product_overview_tile_status', baseArgs(), wrongPageFixture.doc, wrongPageFixture.href), ['result', 'present', 'selected']);
  assert.strictEqual(wrongPageFixtureStatus.result, 'NOT_OVERVIEW');
}

function createVehicleInputRow(index, yearValue = '') {
  return [
    createSelect(`ConsumerData.Assets.Vehicles[${index}].VehTypeCd`, [
      { value: '', text: 'Select One' },
      { value: 'CAR_TRUCK', text: 'Car or Truck' }
    ]),
    createInput(`ConsumerData.Assets.Vehicles[${index}].ModelYear`, yearValue),
    createSelect(`ConsumerData.Assets.Vehicles[${index}].Manufacturer`, [
      { value: '', text: 'Select One' },
      { value: 'FORD', text: 'Ford' },
      { value: 'HONDA', text: 'Honda' },
      { value: 'CHEVROLET', text: 'Chevrolet' }
    ]),
    createSelect(`ConsumerData.Assets.Vehicles[${index}].Model`, [
      { value: '', text: 'Select One' },
      { value: 'PILOT', text: 'Pilot' },
      { value: 'F150', text: 'F-150' }
    ]),
    createSelect(`ConsumerData.Assets.Vehicles[${index}].SubModel`, [
      { value: '', text: 'Select One' },
      { value: 'EXL', text: 'EX-L AWD' },
      { value: 'TOURING', text: 'Touring' }
    ])
  ];
}

function createVehicleSelectYearRow(index) {
  return [
    createSelect(`ConsumerData.Assets.Vehicles[${index}].ModelYear`, [
      { value: '', text: 'Select One' },
      { value: '2020', text: '2020' }
    ]),
    createSelect(`ConsumerData.Assets.Vehicles[${index}].Manufacturer`, [
      { value: '', text: 'Select One' },
      { value: 'HONDA', text: 'Honda' }
    ])
  ];
}

function appendVehicleInputRow(doc, index, yearValue = '') {
  for (const node of createVehicleInputRow(index, yearValue))
    doc.body.appendChild(node);
}

function appendStaleVehicleRow(doc, {
  index = 5,
  year = '',
  vin = '',
  make = '',
  model = '',
  subModel = '',
  modelOptions = null,
  cancelCloses = true,
  includeCancel = true,
  includeAdd = true
} = {}) {
  const row = new FakeElement('div', { className: 'add-vehicle-row', text: 'Add Car or Truck INCOMPLETE Car/Truck Vehicle Type Year VIN Manufacturer Model Sub-Model' });
  const hideRow = () => {
    const hide = (node) => {
      node.hidden = true;
      node.children.forEach(hide);
    };
    hide(row);
  };
  const nodes = [
    createSelect(`ConsumerData.Assets.Vehicles[${index}].VehTypeCd`, [
      { value: 'CAR_TRUCK', text: 'Car/Truck', selected: true }
    ]),
    createInput(`ConsumerData.Assets.Vehicles[${index}].ModelYear`, year),
    createInput(`ConsumerData.Assets.Vehicles[${index}].VehIdentificationNumber`, vin),
    createSelect(`ConsumerData.Assets.Vehicles[${index}].Manufacturer`, [
      { value: '', text: 'Select One', selected: !make },
      { value: 'NISSAN', text: 'Nissan', selected: make === 'NISSAN' },
      { value: 'HONDA', text: 'Honda', selected: make === 'HONDA' },
      { value: 'HYUNDAI', text: 'Hyundai', selected: make === 'HYUNDAI' }
    ], { disabled: !make }),
    createSelect(`ConsumerData.Assets.Vehicles[${index}].Model`, modelOptions || [
      { value: '', text: 'Select One', selected: !model },
      { value: 'CUBE', text: 'CUBE', selected: model === 'CUBE' }
    ], { disabled: !make }),
    createSelect(`ConsumerData.Assets.Vehicles[${index}].SubModel`, [
      { value: '', text: 'Select One', selected: !subModel },
      { value: 'BASE', text: 'Base', selected: subModel === 'BASE' }
    ], { disabled: !model })
  ];
  nodes.forEach((node) => row.appendChild(node));
  if (includeAdd)
    row.appendChild(createButton('confirmNewVehicle', 'Add'));
  if (includeCancel)
    row.appendChild(createButton(`cancelVehicle-${index}`, 'Cancel', { onClick: cancelCloses ? hideRow : null }));
  doc.body.appendChild(row);
  if (make) nodes[3].value = make;
  if (model) nodes[4].value = model;
  if (subModel) nodes[5].value = subModel;
  return row;
}

function createVehicleCascadeRow(index, { enableOnEvent = true, manufacturerReady = false, readOnlyYear = false } = {}) {
  const manufacturer = createSelect(`ConsumerData.Assets.Vehicles[${index}].Manufacturer`, manufacturerReady ? [
    { value: '', text: 'Select One' },
    { value: 'HONDA', text: 'Honda' }
  ] : [], { disabled: !manufacturerReady });
  const yearInput = createInput(`ConsumerData.Assets.Vehicles[${index}].ModelYear`, '', {
    readOnly: readOnlyYear,
    onDispatch: (el, event) => {
      if (!enableOnEvent) return;
      if (String(el.value) !== '2019') return;
      if (!['input', 'change', 'blur', 'focusout'].includes(event.type)) return;
      manufacturer.disabled = false;
      manufacturer.options = [
        new FakeOption({ value: '', text: 'Select One' }),
        new FakeOption({ value: 'HONDA', text: 'Honda' })
      ];
      manufacturer.options.forEach((option) => { option.parentElement = manufacturer; });
      manufacturer.selectedIndex = 0;
    }
  });
  return [
    createSelect(`ConsumerData.Assets.Vehicles[${index}].VehTypeCd`, [
      { value: '10', text: 'Car/Truck', selected: true }
    ]),
    yearInput,
    manufacturer,
    createSelect(`ConsumerData.Assets.Vehicles[${index}].Model`, [], { disabled: true }),
    createSelect(`ConsumerData.Assets.Vehicles[${index}].SubModel`, [], { disabled: true })
  ];
}

function createCompleteVehicleRow(index) {
  const nodes = createVehicleInputRow(index, '2019');
  const manufacturer = nodes.find((node) => node.id.endsWith('.Manufacturer'));
  const model = nodes.find((node) => node.id.endsWith('.Model'));
  const subModel = nodes.find((node) => node.id.endsWith('.SubModel'));
  manufacturer.value = 'HONDA';
  model.value = 'PILOT';
  subModel.value = 'EXL';
  return nodes;
}

function startQuotingCheckboxDoc({ checked = false, labelChecks = true, clickThrows = false } = {}) {
  const checkbox = createCheckbox('ConsumerReports.Auto.Product-intel#102', {
    name: 'ConsumerReports.Auto.Product',
    value: 'Auto',
    checked,
    clickThrows
  });
  const label = new FakeElement('label', {
    text: 'Auto',
    attributes: { for: 'ConsumerReports.Auto.Product-intel#102' },
    onClick: () => {
      if (labelChecks) checkbox.checked = true;
    }
  });
  return pageDoc('Gather Data Start Quoting Auto Add Product', [checkbox, label]);
}

function confirmedVehicleCardDoc({ text = '2019 Honda PILOT 5FNYF6H55KB000001 Edit Remove CONFIRMED', includeStartQuoting = false } = {}) {
  const card = new FakeElement('div', { className: 'vehicle-card confirmed-vehicle', text });
  card.appendChild(createButton('confirmed-edit', 'Edit'));
  card.appendChild(createButton('confirmed-remove', 'Remove'));
  const section = new FakeElement('section', { text: 'Cars and Trucks CONFIRMED VEHICLES' });
  section.appendChild(card);
  const nodes = [section];
  if (includeStartQuoting)
    nodes.push(...startQuotingCheckboxDoc().body.children);
  return pageDoc('Gather Data Cars and Trucks CONFIRMED VEHICLES Start Quoting', nodes);
}

function confirmedVehicleCardsDoc(cards = []) {
  const section = new FakeElement('section', { text: 'Cars and Trucks CONFIRMED VEHICLES' });
  cards.forEach((text, index) => {
    const card = new FakeElement('div', { className: 'vehicle-card confirmed-vehicle', text });
    card.appendChild(createButton(`confirmed-edit-${index}`, 'Edit'));
    card.appendChild(createButton(`confirmed-remove-${index}`, 'Remove'));
    section.appendChild(card);
  });
  return pageDoc('Gather Data Cars and Trucks CONFIRMED VEHICLES', [section]);
}

function broadPotentialVehicleContainerDoc() {
  const section = new FakeElement('section', {
    className: 'vehicle-section',
    text: 'Cars and Trucks CONFIRMED VEHICLES 2019 Honda PILOT Edit Remove CONFIRMED POTENTIAL VEHICLES 2019 Toyota PRIUS Confirm Remove 2017 Dodge trucks DURANGO Confirm Remove 2012 Ford FUSION Confirm Remove 2019 Honda PILOT Confirm Remove Add Car or Truck'
  });
  section.appendChild(createButton('confirm-prius', 'Confirm'));
  section.appendChild(createButton('confirm-durango', 'Confirm'));
  section.appendChild(createButton('confirm-fusion', 'Confirm'));
  section.appendChild(createButton('confirm-pilot', 'Confirm'));
  return { doc: pageDoc('Gather Data', [section]), section };
}

function startQuotingScopedAddProductDoc() {
  const sidebar = createButton('addProduct', 'Add Product');
  const scoped = createButton('start-add-product', 'Add product');
  const section = new FakeElement('section', { text: 'Start Quoting Auto Add product' });
  section.appendChild(createCheckbox('ConsumerReports.Auto.Product-intel#102', {
    name: 'ConsumerReports.Auto.Product',
    checked: true
  }));
  section.appendChild(scoped);
  return { doc: pageDoc('Gather Data', [sidebar, section]), sidebar, scoped };
}

function createVehicleEditModalDoc({
  vin = '',
  selectedValue = '',
  updateDisabled = false,
  options = [
    { value: '', text: 'Select One' },
    { value: 'BASE', text: '|SEDAN|GAS|FWD|04Cyl|4Dr' },
    { value: 'LE', text: 'LE |SEDAN|GAS|FWD|04Cyl|4Dr' },
    { value: 'SE', text: 'SE |SEDAN|GAS|FWD|04Cyl|4Dr' }
  ]
} = {}) {
  const subModel = createSelect('CommonComponent.Vehicle[0].SubModel', options);
  if (selectedValue)
    subModel.value = selectedValue;
  const updateButton = createButton('submitButtonVehicleComponent_0', 'Update', { disabled: updateDisabled });
  const nodes = [
    textNode('Gather Data Cars and Trucks Edit Vehicle Sub-Model is required'),
    createSelect('CommonComponent.Vehicle[0].VehTypeCd', [{ value: '10', text: 'Car/Truck', selected: true }]),
    createInput('CommonComponent.Vehicle[0].ModelYear', '2019'),
    createInput('CommonComponent.Vehicle[0].VIN', vin),
    createSelect('CommonComponent.Vehicle[0].Manufacturer', [{ value: 'TOYOTA', text: 'TOYOTA', selected: true }]),
    createSelect('CommonComponent.Vehicle[0].Model', [{ value: 'COROLLA', text: 'COROLLA', selected: true }]),
    subModel,
    updateButton
  ];
  return { doc: pageDoc('Gather Data Cars and Trucks Edit Vehicle Sub-Model Update', nodes), subModel, updateButton };
}

function testVehicleContracts() {
  const addedVehicleDoc = new FakeDocument([textNode('2022 Tesla Model 3 Added to quote')]);
  assert.strictEqual(runOperator('vehicle_already_listed', { year: '2022', make: 'Tesla', model: 'Model 3' }, addedVehicleDoc), '1');
  assert.strictEqual(runOperator('vehicle_already_listed', { year: '2022', make: 'Tesla', model: 'Model 3' }, new FakeDocument()), '0');

  assert.strictEqual(assertKeyBlock(runOperator('confirm_potential_vehicle', { year: '2022', make: 'Tesla', model: 'Model 3' }, new FakeDocument()), ['result']).result, 'NO_MATCH');
  assert.strictEqual(assertKeyBlock(runOperator('confirm_potential_vehicle', { year: '2022', make: 'Tesla', model: 'Model 3' }, new FakeDocument([
    createVehicleCard('2022 Tesla Model 3 Long Range', 'confirm-a'),
    createVehicleCard('2022 Tesla Model 3 Performance', 'confirm-b')
  ])), ['result']).result, 'AMBIGUOUS');
  assert.strictEqual(assertKeyBlock(runOperator('confirm_potential_vehicle', { year: '2022', make: 'Tesla', model: 'Model 3' }, new FakeDocument([
    createVehicleCard('2022 Tesla Model 3 Long Range', 'confirm-one')
  ])), ['result']).result, 'CONFIRMED');
  assert.strictEqual(assertKeyBlock(runOperator('confirm_potential_vehicle', { year: '2022', make: 'Tesla', model: 'Model 3' }, new FakeDocument([
    createVehicleCard('2022 Tesla Model 3 Long Range', 'confirm-bad')
  ].map((card) => {
    card.querySelector('button').clickThrows = true;
    return card;
  }))), ['result']).result, 'CLICK_FAILED');
  const broadPotential = broadPotentialVehicleContainerDoc();
  const broadPotentialStatus = assertKeyBlock(runOperator('confirm_potential_vehicle', {
    year: '2019',
    make: 'Honda',
    model: 'Pilot'
  }, broadPotential.doc), ['result', 'candidateScope', 'rejectedReason', 'confirmButtonCount', 'vehicleTitleCount', 'confirmClicked']);
  assert.notStrictEqual(broadPotentialStatus.result, 'CONFIRMED');
  assert.strictEqual(broadPotentialStatus.rejectedReason, 'broad-container');
  assert.strictEqual(broadPotentialStatus.confirmClicked, '0');
  assert.strictEqual(broadPotential.section.children.reduce((sum, child) => sum + child.clickCalls, 0), 0);
  const singlePotentialConfirm = createVehicleCard('POTENTIAL VEHICLES 2019 Honda Pilot Confirm Remove', 'confirm-pilot');
  const singlePotentialStatus = assertKeyBlock(runOperator('confirm_potential_vehicle', {
    year: '2019',
    make: 'Honda',
    model: 'Pilot'
  }, new FakeDocument([singlePotentialConfirm])), ['result', 'candidateScope', 'confirmClicked', 'matchedCardText']);
  assert.strictEqual(singlePotentialStatus.result, 'CONFIRMED');
  assert.strictEqual(singlePotentialStatus.candidateScope, 'single-card');
  assert.strictEqual(singlePotentialStatus.confirmClicked, '1');
  const wrongPotentialStatus = assertKeyBlock(runOperator('confirm_potential_vehicle', {
    year: '2019',
    make: 'Honda',
    model: 'Pilot'
  }, new FakeDocument([
    createVehicleCard('POTENTIAL VEHICLES 2019 Toyota Prius Confirm Remove', 'confirm-prius')
  ])), ['result', 'confirmClicked']);
  assert.strictEqual(wrongPotentialStatus.result, 'NO_MATCH');
  assert.strictEqual(wrongPotentialStatus.confirmClicked, '0');
  const missingYearStatus = assertKeyBlock(runOperator('confirm_potential_vehicle', {
    year: '',
    make: 'Toyota',
    model: 'Prius Prime'
  }, new FakeDocument([
    createVehicleCard('POTENTIAL VEHICLES 2019 Toyota Prius Prime Confirm Remove', 'confirm-prime')
  ])), ['result', 'rejectedReason', 'confirmClicked']);
  assert.strictEqual(missingYearStatus.result, 'SKIP_MISSING_YEAR');
  assert.strictEqual(missingYearStatus.rejectedReason, 'lead-vehicle-year-missing');
  assert.strictEqual(missingYearStatus.confirmClicked, '0');

  const blankRowDoc = new FakeDocument(createVehicleInputRow(0, ''));
  assert.strictEqual(runOperator('prepare_vehicle_row', { year: '2024' }, blankRowDoc), '0');
  assert.strictEqual(blankRowDoc.getElementById('ConsumerData.Assets.Vehicles[0].ModelYear').value, '2024');
  assert.strictEqual(blankRowDoc.getElementById('ConsumerData.Assets.Vehicles[0].VehTypeCd').value, 'CAR_TRUCK');
  const existingPartialDoc = new FakeDocument(createVehicleInputRow(0, '2024'));
  assert.strictEqual(runOperator('prepare_vehicle_row', { year: '2024' }, existingPartialDoc), '0');
  assert.strictEqual(runOperator('prepare_vehicle_row', { year: '2024' }, new FakeDocument()), '-1');
  let addRowDoc;
  const addCarButton = createButton('add-car-or-truck', 'Add Car or Truck', {
    onClick: () => appendVehicleInputRow(addRowDoc, 0, '')
  });
  addRowDoc = new FakeDocument([addCarButton]);
  assert.strictEqual(runOperator('prepare_vehicle_row', { year: '2024' }, addRowDoc), '0');
  assert.strictEqual(addCarButton.clickCalls, 1);
  assert.strictEqual(addRowDoc.getElementById('ConsumerData.Assets.Vehicles[0].ModelYear').value, '2024');
  const wrongYearDoc = new FakeDocument(createVehicleSelectYearRow(0));
  assert.strictEqual(runOperator('prepare_vehicle_row', { year: '2024' }, wrongYearDoc), '-1');
  const rowStatus = assertKeyBlock(runOperator('gather_vehicle_row_status', { index: 0 }, blankRowDoc), ['result', 'rowIndex', 'hasYear', 'hasManufacturer', 'yearValue', 'manufacturerOptions', 'addButtonPresent']);
  assert.strictEqual(rowStatus.result, 'READY');
  assert.strictEqual(rowStatus.rowIndex, '0');
  assert.strictEqual(rowStatus.hasYear, '1');
  assert.strictEqual(rowStatus.hasManufacturer, '1');
  assert.strictEqual(rowStatus.yearValue, '2024');
  assert.match(rowStatus.manufacturerOptions, /Honda/);
  assert.strictEqual(assertKeyBlock(runOperator('gather_vehicle_row_status', {}, new FakeDocument([createButton('add-car-or-truck', 'Add Car or Truck')])), ['result', 'addButtonPresent']).result, 'NO_ROW');

  const cascadeDoc = new FakeDocument(createVehicleCascadeRow(0));
  const cascadeStatus = assertKeyBlock(runOperator('set_vehicle_year_and_wait_manufacturer', { index: 0, year: '2019', timeoutMs: 250, pollMs: 25 }, cascadeDoc), ['result', 'yearValue', 'yearVerified', 'manufacturerEnabled', 'manufacturerOptionCount', 'method', 'eventsFired', 'attempts', 'failedFields']);
  assert.strictEqual(cascadeStatus.result, 'OK');
  assert.strictEqual(cascadeStatus.yearValue, '2019');
  assert.strictEqual(cascadeStatus.yearVerified, '1');
  assert.strictEqual(cascadeStatus.manufacturerEnabled, '1');
  assert.strictEqual(cascadeStatus.manufacturerOptionCount, '1');
  assert.match(cascadeStatus.eventsFired, /input/);
  assert.match(cascadeStatus.eventsFired, /change/);
  assert.strictEqual(cascadeDoc.getElementById('ConsumerData.Assets.Vehicles[0].ModelYear').value, '2019');
  const cascadeFailDoc = new FakeDocument(createVehicleCascadeRow(0, { enableOnEvent: false }));
  const cascadeFailStatus = assertKeyBlock(runOperator('set_vehicle_year_and_wait_manufacturer', { index: 0, year: '2019', timeoutMs: 80, pollMs: 25 }, cascadeFailDoc), ['result', 'yearVerified', 'manufacturerEnabled', 'manufacturerOptionCount', 'failedFields']);
  assert.strictEqual(cascadeFailStatus.result, 'FAILED');
  assert.strictEqual(cascadeFailStatus.yearVerified, '1');
  assert.strictEqual(cascadeFailStatus.manufacturerEnabled, '0');
  assert.strictEqual(cascadeFailStatus.manufacturerOptionCount, '0');
  assert.match(cascadeFailStatus.failedFields, /manufacturer/);
  const cascadeBadYearDoc = new FakeDocument(createVehicleCascadeRow(0, { readOnlyYear: true }));
  const cascadeBadYearStatus = assertKeyBlock(runOperator('set_vehicle_year_and_wait_manufacturer', { index: 0, year: '2019', timeoutMs: 80 }, cascadeBadYearDoc), ['result', 'yearVerified', 'failedFields']);
  assert.strictEqual(cascadeBadYearStatus.result, 'FAILED');
  assert.strictEqual(cascadeBadYearStatus.yearVerified, '0');
  assert.match(cascadeBadYearStatus.failedFields, /year/);
  const cascadeReadyDoc = new FakeDocument(createVehicleCascadeRow(0, { manufacturerReady: true }));
  const cascadeReadyStatus = assertKeyBlock(runOperator('set_vehicle_year_and_wait_manufacturer', { index: 0, year: '2019', timeoutMs: 80 }, cascadeReadyDoc), ['result', 'manufacturerEnabled', 'manufacturerOptionCount', 'method']);
  assert.strictEqual(cascadeReadyStatus.result, 'OK');
  assert.strictEqual(cascadeReadyStatus.manufacturerEnabled, '1');
  assert.strictEqual(cascadeReadyStatus.manufacturerOptionCount, '1');
  assert.ok(['already-ready', 'focus|clear|blur-focusout|retry-controlled-input'].includes(cascadeReadyStatus.method));

  const vehicleAddedStatus = assertKeyBlock(runOperator('gather_vehicle_add_status', { year: '2019', make: 'Honda', model: 'Pilot' }, confirmedVehicleCardDoc()), [
    'result', 'vehicleMatched', 'confirmedVehicleMatched', 'confirmedStatusMatched', 'yearMatched', 'makeMatched', 'modelMatched', 'matchedText', 'warningStillPresent', 'method'
  ]);
  assert.strictEqual(vehicleAddedStatus.result, 'ADDED');
  assert.strictEqual(vehicleAddedStatus.method, 'confirmed-vehicle-card');
  assert.strictEqual(vehicleAddedStatus.vehicleMatched, '1');
  assert.strictEqual(vehicleAddedStatus.confirmedVehicleMatched, '1');
  assert.strictEqual(vehicleAddedStatus.confirmedStatusMatched, '1');
  assert.strictEqual(vehicleAddedStatus.yearMatched, '1');
  assert.strictEqual(vehicleAddedStatus.makeMatched, '1');
  assert.strictEqual(vehicleAddedStatus.modelMatched, '1');
  assert.match(vehicleAddedStatus.matchedText, /2019 Honda PILOT/);
  const catalogHighlanderAddedStatus = assertKeyBlock(runOperator('gather_vehicle_add_status', {
    year: '2019',
    make: 'Toyota',
    model: 'Highlander',
    allowedMakeLabels: 'TOYOTA|TOY. TRUCKS',
    strictModelMatch: '1'
  }, confirmedVehicleCardDoc({
    text: '2019 Toy. trucks HIGHLANDER 5TDKZRFH6KS554658 Edit Remove CONFIRMED'
  })), ['result', 'confirmedVehicleMatched', 'makeMatched', 'modelMatched', 'method']);
  assert.strictEqual(catalogHighlanderAddedStatus.result, 'ADDED');
  assert.strictEqual(catalogHighlanderAddedStatus.confirmedVehicleMatched, '1');
  assert.strictEqual(catalogHighlanderAddedStatus.makeMatched, '1');
  assert.strictEqual(catalogHighlanderAddedStatus.modelMatched, '1');
  assert.strictEqual(catalogHighlanderAddedStatus.method, 'confirmed-vehicle-card');
  const catalogCorollaAddedStatus = assertKeyBlock(runOperator('gather_vehicle_add_status', {
    year: '2019',
    make: 'Toyota',
    model: 'Corolla',
    allowedMakeLabels: 'TOYOTA',
    strictModelMatch: '1'
  }, confirmedVehicleCardDoc({
    text: '2019 Toyota COROLLA 2T1BURHE4KC199094 Edit Remove CONFIRMED'
  })), ['result', 'confirmedVehicleMatched', 'makeMatched', 'modelMatched']);
  assert.strictEqual(catalogCorollaAddedStatus.result, 'ADDED');
  assert.strictEqual(catalogCorollaAddedStatus.confirmedVehicleMatched, '1');
  assert.strictEqual(catalogCorollaAddedStatus.makeMatched, '1');
  assert.strictEqual(catalogCorollaAddedStatus.modelMatched, '1');
  const crvConfirmedStatus = assertKeyBlock(runOperator('gather_vehicle_add_status', {
    year: '2019',
    make: 'Honda',
    model: 'CRV',
    allowedMakeLabels: 'HONDA',
    strictModelMatch: '1'
  }, confirmedVehicleCardDoc({
    text: '2019 Honda CR-V FAKECRV1*******01 Edit Remove CONFIRMED'
  })), ['result', 'confirmedVehicleMatched', 'confirmedStatusMatched', 'yearMatched', 'makeMatched', 'modelMatched', 'expectedModelKey']);
  assert.strictEqual(crvConfirmedStatus.result, 'ADDED');
  assert.strictEqual(crvConfirmedStatus.confirmedVehicleMatched, '1');
  assert.strictEqual(crvConfirmedStatus.confirmedStatusMatched, '1');
  assert.strictEqual(crvConfirmedStatus.yearMatched, '1');
  assert.strictEqual(crvConfirmedStatus.makeMatched, '1');
  assert.strictEqual(crvConfirmedStatus.modelMatched, '1');
  assert.strictEqual(crvConfirmedStatus.expectedModelKey, 'CRV');
  const crvCardWithoutHyphenStatus = assertKeyBlock(runOperator('gather_vehicle_add_status', {
    year: '2019',
    make: 'Honda',
    model: 'CR-V',
    allowedMakeLabels: 'HONDA',
    strictModelMatch: '1'
  }, confirmedVehicleCardDoc({
    text: '2019 Honda CRV FAKECRV1*******01 Edit Remove CONFIRMED'
  })), ['result', 'modelMatched']);
  assert.strictEqual(crvCardWithoutHyphenStatus.result, 'ADDED');
  assert.strictEqual(crvCardWithoutHyphenStatus.modelMatched, '1');
  const crvSpaceVariantStatus = assertKeyBlock(runOperator('gather_vehicle_add_status', {
    year: '2019',
    make: 'Honda',
    model: 'CR V',
    allowedMakeLabels: 'HONDA',
    strictModelMatch: '1'
  }, confirmedVehicleCardDoc({
    text: '2019 Honda CR-V FAKECRV1*******01 Edit Remove CONFIRMED'
  })), ['result', 'modelMatched']);
  assert.strictEqual(crvSpaceVariantStatus.result, 'ADDED');
  assert.strictEqual(crvSpaceVariantStatus.modelMatched, '1');
  const hrvPositiveStatus = assertKeyBlock(runOperator('gather_vehicle_add_status', {
    year: '2019',
    make: 'Honda',
    model: 'HRV',
    allowedMakeLabels: 'HONDA',
    strictModelMatch: '1'
  }, confirmedVehicleCardDoc({
    text: '2019 Honda HR-V FAKEHRV1*******02 Edit Remove CONFIRMED'
  })), ['result', 'modelMatched']);
  assert.strictEqual(hrvPositiveStatus.result, 'ADDED');
  assert.strictEqual(hrvPositiveStatus.modelMatched, '1');
  const crvDoesNotMatchHrvStatus = assertKeyBlock(runOperator('gather_vehicle_add_status', {
    year: '2019',
    make: 'Honda',
    model: 'CRV',
    allowedMakeLabels: 'HONDA',
    strictModelMatch: '1'
  }, confirmedVehicleCardDoc({
    text: '2019 Honda HR-V FAKEHRV1*******02 Edit Remove CONFIRMED'
  })), ['result', 'vehicleMatched', 'confirmedVehicleMatched', 'modelMatched']);
  assert.notStrictEqual(crvDoesNotMatchHrvStatus.result, 'ADDED');
  assert.strictEqual(crvDoesNotMatchHrvStatus.confirmedVehicleMatched, '0');
  const fordF250Status = assertKeyBlock(runOperator('gather_vehicle_add_status', {
    year: '2021',
    make: 'Ford',
    model: 'F 250',
    allowedMakeLabels: 'FORD|FORD TRUCKS',
    strictModelMatch: '1'
  }, confirmedVehicleCardDoc({
    text: '2021 Ford Trucks F-250 FAKEF250*******03 Edit Remove CONFIRMED'
  })), ['result', 'modelMatched']);
  assert.strictEqual(fordF250Status.result, 'ADDED');
  assert.strictEqual(fordF250Status.modelMatched, '1');
  const duplicateAddRowDoc = confirmedVehicleCardDoc({
    text: '2019 Honda CR-V FAKECRV1*******01 Edit Remove CONFIRMED'
  });
  appendVehicleInputRow(duplicateAddRowDoc, 5, '2019');
  duplicateAddRowDoc.getElementById('ConsumerData.Assets.Vehicles[5].Manufacturer').value = 'HONDA';
  const duplicateAddRowStatus = assertKeyBlock(runOperator('gather_vehicle_add_status', {
    year: '2019',
    make: 'Honda',
    model: 'CRV',
    allowedMakeLabels: 'HONDA',
    strictModelMatch: '1'
  }, duplicateAddRowDoc), ['result', 'confirmedVehicleMatched', 'rowIncomplete', 'duplicateAddRowOpenForConfirmedVehicle', 'duplicateAddRowDetails']);
  assert.strictEqual(duplicateAddRowStatus.result, 'ADDED');
  assert.strictEqual(duplicateAddRowStatus.confirmedVehicleMatched, '1');
  assert.strictEqual(duplicateAddRowStatus.rowIncomplete, '1');
  assert.strictEqual(duplicateAddRowStatus.duplicateAddRowOpenForConfirmedVehicle, '1');
  assert.match(duplicateAddRowStatus.duplicateAddRowDetails, /model=/);
  const crvFixture = fixtureScenario('gather-confirmed-honda-crv');
  const crvFixtureStatus = assertKeyBlock(runOperator('gather_vehicle_add_status', {
    year: '2019',
    make: 'Honda',
    model: 'CRV',
    allowedMakeLabels: 'HONDA',
    strictModelMatch: '1'
  }, crvFixture.doc, crvFixture.href), ['result', 'confirmedVehicleMatched', 'modelMatched']);
  assert.strictEqual(crvFixtureStatus.result, 'ADDED');
  assert.strictEqual(crvFixtureStatus.confirmedVehicleMatched, '1');
  assert.strictEqual(crvFixtureStatus.modelMatched, '1');
  const duplicateFixture = fixtureScenario('gather-confirmed-honda-crv-with-duplicate-add-row');
  const duplicateFixtureStatus = assertKeyBlock(runOperator('gather_vehicle_add_status', {
    year: '2019',
    make: 'Honda',
    model: 'CRV',
    allowedMakeLabels: 'HONDA',
    strictModelMatch: '1'
  }, duplicateFixture.doc, duplicateFixture.href), ['result', 'duplicateAddRowOpenForConfirmedVehicle']);
  assert.strictEqual(duplicateFixtureStatus.result, 'ADDED');
  assert.strictEqual(duplicateFixtureStatus.duplicateAddRowOpenForConfirmedVehicle, '1');
  const partialNissanStatus = assertKeyBlock(runOperator('gather_vehicle_add_status', {
    year: '2010',
    make: 'Nissan',
    model: '',
    allowedMakeLabels: 'NISSAN',
    partialYearMakeMode: '1'
  }, confirmedVehicleCardDoc({
    text: '2010 Nissan CUBE FAKECUBE*******03 Edit Remove CONFIRMED'
  })), ['result', 'partialPromoted', 'promotedModel', 'confirmedVehicleMatched', 'yearMatched', 'makeMatched', 'modelMatched', 'vinEvidence', 'method']);
  assert.strictEqual(partialNissanStatus.result, 'ADDED');
  assert.strictEqual(partialNissanStatus.partialPromoted, '1');
  assert.strictEqual(partialNissanStatus.promotedModel, 'CUBE');
  assert.strictEqual(partialNissanStatus.confirmedVehicleMatched, '1');
  assert.strictEqual(partialNissanStatus.modelMatched, '1');
  assert.strictEqual(partialNissanStatus.vinEvidence, '1');
  assert.strictEqual(partialNissanStatus.method, 'partial-confirmed-card');
  const partialNissanFixture = fixtureScenario('gather-partial-confirmed-nissan-cube');
  const partialNissanFixtureStatus = assertKeyBlock(runOperator('gather_vehicle_add_status', {
    year: '2010',
    make: 'Nissan',
    model: '',
    allowedMakeLabels: 'NISSAN',
    partialYearMakeMode: '1'
  }, partialNissanFixture.doc, partialNissanFixture.href), ['result', 'partialPromoted', 'promotedModel']);
  assert.strictEqual(partialNissanFixtureStatus.result, 'ADDED');
  assert.strictEqual(partialNissanFixtureStatus.partialPromoted, '1');
  assert.strictEqual(partialNissanFixtureStatus.promotedModel, 'CUBE');
  const partialAmbiguousStatus = assertKeyBlock(runOperator('gather_vehicle_add_status', {
    year: '2010',
    make: 'Nissan',
    model: '',
    allowedMakeLabels: 'NISSAN',
    partialYearMakeMode: '1'
  }, confirmedVehicleCardsDoc([
    '2010 Nissan CUBE FAKECUBE*******03 Edit Remove CONFIRMED',
    '2010 Nissan ALTIMA FAKEALTI*******04 Edit Remove CONFIRMED'
  ])), ['result', 'partialPromoted', 'candidateCount', 'failedFields']);
  assert.strictEqual(partialAmbiguousStatus.result, 'AMBIGUOUS');
  assert.strictEqual(partialAmbiguousStatus.partialPromoted, '0');
  assert.strictEqual(partialAmbiguousStatus.failedFields, 'partialVehicleAmbiguous');
  const partialNoVinStatus = assertKeyBlock(runOperator('gather_vehicle_add_status', {
    year: '2010',
    make: 'Nissan',
    model: '',
    allowedMakeLabels: 'NISSAN',
    partialYearMakeMode: '1'
  }, confirmedVehicleCardDoc({
    text: '2010 Nissan CUBE Edit Remove CONFIRMED'
  })), ['result', 'partialPromoted', 'promotedModel', 'vinEvidence', 'failedFields']);
  assert.strictEqual(partialNoVinStatus.result, 'MISSING');
  assert.strictEqual(partialNoVinStatus.partialPromoted, '0');
  assert.strictEqual(partialNoVinStatus.promotedModel, 'CUBE');
  assert.strictEqual(partialNoVinStatus.vinEvidence, '0');
  assert.strictEqual(partialNoVinStatus.failedFields, 'partialVehicleNoVin');
  const partialWrongYearStatus = assertKeyBlock(runOperator('gather_vehicle_add_status', {
    year: '2010',
    make: 'Nissan',
    model: '',
    allowedMakeLabels: 'NISSAN',
    partialYearMakeMode: '1'
  }, confirmedVehicleCardDoc({
    text: '2011 Nissan CUBE FAKECUBE*******03 Edit Remove CONFIRMED'
  })), ['result', 'partialPromoted', 'candidateCount']);
  assert.strictEqual(partialWrongYearStatus.result, 'MISSING');
  assert.strictEqual(partialWrongYearStatus.partialPromoted, '0');
  assert.strictEqual(partialWrongYearStatus.candidateCount, '0');
  const partialWrongMakeStatus = assertKeyBlock(runOperator('gather_vehicle_add_status', {
    year: '2010',
    make: 'Nissan',
    model: '',
    allowedMakeLabels: 'NISSAN',
    partialYearMakeMode: '1'
  }, confirmedVehicleCardDoc({
    text: '2010 Honda CR-V FAKECRV1*******01 Edit Remove CONFIRMED'
  })), ['result', 'partialPromoted', 'candidateCount']);
  assert.strictEqual(partialWrongMakeStatus.result, 'MISSING');
  assert.strictEqual(partialWrongMakeStatus.partialPromoted, '0');
  assert.strictEqual(partialWrongMakeStatus.candidateCount, '0');
  const broadDropdownUnsafeFixture = fixtureScenario('gather-partial-nissan-broad-dropdown-unsafe');
  const broadDropdownUnsafeStatus = assertKeyBlock(runOperator('gather_vehicle_add_status', {
    year: '2010',
    make: 'Nissan',
    model: '',
    allowedMakeLabels: 'NISSAN',
    partialYearMakeMode: '1'
  }, broadDropdownUnsafeFixture.doc, broadDropdownUnsafeFixture.href), ['result', 'partialPromoted', 'rowIncomplete', 'method']);
  assert.strictEqual(broadDropdownUnsafeStatus.result, 'MISSING');
  assert.strictEqual(broadDropdownUnsafeStatus.partialPromoted, '0');
  assert.strictEqual(broadDropdownUnsafeStatus.rowIncomplete, '1');
  assert.strictEqual(broadDropdownUnsafeFixture.doc.getElementById('ConsumerData.Assets.Vehicles[5].Model').value, '');
  const partialDuplicateFixture = fixtureScenario('gather-partial-confirmed-nissan-cube-with-duplicate-add-row');
  const partialDuplicateStatus = assertKeyBlock(runOperator('gather_vehicle_add_status', {
    year: '2010',
    make: 'Nissan',
    model: '',
    allowedMakeLabels: 'NISSAN',
    partialYearMakeMode: '1'
  }, partialDuplicateFixture.doc, partialDuplicateFixture.href), ['result', 'partialPromoted', 'duplicateAddRowOpenForConfirmedVehicle']);
  assert.strictEqual(partialDuplicateStatus.result, 'ADDED');
  assert.strictEqual(partialDuplicateStatus.partialPromoted, '1');
  assert.strictEqual(partialDuplicateStatus.duplicateAddRowOpenForConfirmedVehicle, '1');
  const staleAllConfirmedDoc = confirmedVehicleCardsDoc([
    '2010 Nissan CUBE FAKECUBE*******03 Edit Remove CONFIRMED',
    '2013 Hyundai SONATA FAKEHYUN*******02 Edit Remove CONFIRMED',
    '2019 Honda CR-V FAKECRV1*******01 Edit Remove CONFIRMED'
  ]);
  const staleRow = appendStaleVehicleRow(staleAllConfirmedDoc);
  const staleStatus = assertKeyBlock(runOperator('gather_stale_add_vehicle_row_status', {
    allExpectedVehiclesSatisfied: '1'
  }, staleAllConfirmedDoc), ['result', 'rowIncomplete', 'cancelButtonScoped', 'safeToCancel', 'reason']);
  assert.strictEqual(staleStatus.result, 'FOUND');
  assert.strictEqual(staleStatus.rowIncomplete, '1');
  assert.strictEqual(staleStatus.cancelButtonScoped, '1');
  assert.strictEqual(staleStatus.safeToCancel, '1');
  const staleConfirmedGuard = assertKeyBlock(runOperator('gather_confirmed_vehicles_status', {
    expectedVehicles: [
      { year: '2010', make: 'Nissan', model: 'CUBE', allowedMakeLabels: 'NISSAN', strictModelMatch: '1' },
      { year: '2013', make: 'Hyundai', model: 'SONATA', allowedMakeLabels: 'HYUNDAI', strictModelMatch: '1' },
      { year: '2019', make: 'Honda', model: 'CRV', allowedMakeLabels: 'HONDA', strictModelMatch: '1' }
    ]
  }, staleAllConfirmedDoc), ['result', 'matchedExpectedCount', 'unexpectedCount']);
  assert.strictEqual(staleConfirmedGuard.result, 'OK');
  assert.strictEqual(staleConfirmedGuard.matchedExpectedCount, '3');
  assert.strictEqual(staleConfirmedGuard.unexpectedCount, '0');
  const cancelStatus = assertKeyBlock(runOperator('cancel_stale_add_vehicle_row', {
    allExpectedVehiclesSatisfied: '1'
  }, staleAllConfirmedDoc), ['result', 'clicked', 'afterRowPresent']);
  assert.strictEqual(cancelStatus.result, 'CANCELLED');
  assert.strictEqual(cancelStatus.clicked, '1');
  assert.strictEqual(cancelStatus.afterRowPresent, '0');
  assert.strictEqual(staleRow.hidden, true);
  const staleFilledDuplicateDoc = confirmedVehicleCardsDoc([
    '2010 Nissan CUBE FAKECUBE*******03 Edit Remove CONFIRMED',
    '2013 Hyundai SONATA FAKEHYUN*******02 Edit Remove CONFIRMED',
    '2019 Honda CR-V FAKECRV1*******01 Edit Remove CONFIRMED'
  ]);
  appendStaleVehicleRow(staleFilledDuplicateDoc, {
    year: '2010',
    make: 'NISSAN',
    modelOptions: [
      { value: '', text: 'Select One', selected: true },
      { value: '370Z', text: '370Z' },
      { value: 'ALTIMA', text: 'ALTIMA' },
      { value: 'CUBE', text: 'CUBE' }
    ]
  });
  const staleFilledStatus = assertKeyBlock(runOperator('gather_stale_add_vehicle_row_status', {
    allExpectedVehiclesSatisfied: '1'
  }, staleFilledDuplicateDoc), ['result', 'safeToCancel', 'yearValue', 'manufacturerValue', 'modelValue']);
  assert.strictEqual(staleFilledStatus.result, 'FOUND');
  assert.strictEqual(staleFilledStatus.safeToCancel, '1');
  assert.strictEqual(staleFilledStatus.yearValue, '2010');
  assert.strictEqual(staleFilledStatus.manufacturerValue, 'NISSAN');
  assert.strictEqual(staleFilledStatus.modelValue, '');
  const staleUnsafeDoc = confirmedVehicleCardsDoc([
    '2019 Honda CR-V FAKECRV1*******01 Edit Remove CONFIRMED'
  ]);
  appendStaleVehicleRow(staleUnsafeDoc);
  const staleUnsafeStatus = assertKeyBlock(runOperator('gather_stale_add_vehicle_row_status', {
    allExpectedVehiclesSatisfied: '0'
  }, staleUnsafeDoc), ['result', 'safeToCancel', 'reason']);
  assert.strictEqual(staleUnsafeStatus.result, 'UNSAFE');
  assert.strictEqual(staleUnsafeStatus.safeToCancel, '0');
  assert.strictEqual(staleUnsafeStatus.reason, 'expected-vehicles-not-satisfied');
  const staleDecoyDoc = confirmedVehicleCardsDoc([
    '2010 Nissan CUBE FAKECUBE*******03 Edit Remove CONFIRMED'
  ]);
  const confirmedEditButton = staleDecoyDoc.getElementById('confirmed-edit-0');
  const confirmedRemoveButton = staleDecoyDoc.getElementById('confirmed-remove-0');
  const potentialCard = new FakeElement('div', { className: 'vehicle-card potential-vehicle', text: 'POTENTIAL VEHICLES 2010 Nissan CUBE Confirm Remove' });
  const potentialConfirm = createButton('potential-confirm', 'Confirm');
  const potentialRemove = createButton('potential-remove', 'Remove');
  potentialCard.appendChild(potentialConfirm);
  potentialCard.appendChild(potentialRemove);
  staleDecoyDoc.body.appendChild(potentialCard);
  appendStaleVehicleRow(staleDecoyDoc);
  const staleDecoyCancel = assertKeyBlock(runOperator('cancel_stale_add_vehicle_row', {
    allExpectedVehiclesSatisfied: '1'
  }, staleDecoyDoc), ['result', 'clicked']);
  assert.strictEqual(staleDecoyCancel.result, 'CANCELLED');
  assert.strictEqual(staleDecoyCancel.clicked, '1');
  assert.strictEqual(confirmedEditButton.clickCalls, 0);
  assert.strictEqual(confirmedRemoveButton.clickCalls, 0);
  assert.strictEqual(potentialConfirm.clickCalls, 0);
  assert.strictEqual(potentialRemove.clickCalls, 0);
  const staleBroadDropdownDoc = confirmedVehicleCardsDoc([
    '2010 Nissan CUBE FAKECUBE*******03 Edit Remove CONFIRMED'
  ]);
  appendStaleVehicleRow(staleBroadDropdownDoc, {
    year: '2010',
    make: 'NISSAN',
    modelOptions: [
      { value: '', text: 'Select One', selected: true },
      { value: '370Z', text: '370Z' },
      { value: 'ALTIMA', text: 'ALTIMA' },
      { value: 'CUBE', text: 'CUBE' },
      { value: 'FRONTIER', text: 'FRONTIER' }
    ]
  });
  const broadModel = staleBroadDropdownDoc.getElementById('ConsumerData.Assets.Vehicles[5].Model');
  const staleBroadStatus = assertKeyBlock(runOperator('gather_stale_add_vehicle_row_status', {
    allExpectedVehiclesSatisfied: '1'
  }, staleBroadDropdownDoc), ['result', 'safeToCancel']);
  assert.strictEqual(staleBroadStatus.result, 'FOUND');
  assert.strictEqual(staleBroadStatus.safeToCancel, '1');
  assert.strictEqual(broadModel.value, '');
  const staleVerifyFailedDoc = confirmedVehicleCardsDoc([
    '2010 Nissan CUBE FAKECUBE*******03 Edit Remove CONFIRMED'
  ]);
  appendStaleVehicleRow(staleVerifyFailedDoc, { cancelCloses: false });
  const staleVerifyFailed = assertKeyBlock(runOperator('cancel_stale_add_vehicle_row', {
    allExpectedVehiclesSatisfied: '1'
  }, staleVerifyFailedDoc), ['result', 'clicked', 'afterRowPresent', 'failedFields']);
  assert.strictEqual(staleVerifyFailed.result, 'VERIFY_FAILED');
  assert.strictEqual(staleVerifyFailed.clicked, '1');
  assert.strictEqual(staleVerifyFailed.afterRowPresent, '1');
  assert.strictEqual(staleVerifyFailed.failedFields, 'staleRowStillPresent');
  const potentialVehicleStatus = assertKeyBlock(runOperator('gather_vehicle_add_status', { year: '2019', make: 'Honda', model: 'Pilot' }, new FakeDocument([
    textNode('POTENTIAL VEHICLES'),
    new FakeElement('div', { className: 'vehicle-card', text: '2019 Honda PILOT Confirm Remove' })
  ])), ['result', 'vehicleMatched', 'confirmedVehicleMatched', 'method']);
  assert.notStrictEqual(potentialVehicleStatus.result, 'ADDED');
  assert.strictEqual(potentialVehicleStatus.confirmedVehicleMatched, '0');
  const differentConfirmedVehicleStatus = assertKeyBlock(runOperator('gather_vehicle_add_status', { year: '2019', make: 'Honda', model: 'Pilot' }, confirmedVehicleCardDoc({
    text: '2020 Honda CR-V 5J6RW2H80LL000001 Edit Remove CONFIRMED'
  })), ['result', 'vehicleMatched', 'confirmedVehicleMatched']);
  assert.notStrictEqual(differentConfirmedVehicleStatus.result, 'ADDED');
  assert.strictEqual(differentConfirmedVehicleStatus.vehicleMatched, '0');
  const confirmedWithStartQuotingStatus = assertKeyBlock(runOperator('gather_vehicle_add_status', { year: '2019', make: 'Honda', model: 'Pilot' }, confirmedVehicleCardDoc({
    includeStartQuoting: true
  })), ['result', 'method', 'confirmedVehicleMatched']);
  assert.strictEqual(confirmedWithStartQuotingStatus.result, 'ADDED');
  const unexpectedConfirmedStatus = assertKeyBlock(runOperator('gather_confirmed_vehicles_status', {
    expectedVehiclesText: '2019|Honda|Pilot|'
  }, confirmedVehicleCardsDoc([
    '2019 Honda PILOT 5FNYF6H55KB000001 Edit Remove CONFIRMED',
    '2017 Dodge trucks DURANGO Edit Remove CONFIRMED'
  ])), ['result', 'confirmedCount', 'expectedCount', 'matchedExpectedCount', 'unexpectedCount', 'unexpectedVehicles']);
  assert.strictEqual(unexpectedConfirmedStatus.result, 'UNEXPECTED');
  assert.strictEqual(unexpectedConfirmedStatus.unexpectedCount, '1');
  assert.match(unexpectedConfirmedStatus.unexpectedVehicles, /Dodge/);
  const expectedConfirmedStatus = assertKeyBlock(runOperator('gather_confirmed_vehicles_status', {
    expectedVehiclesText: '2019|Honda|Pilot|'
  }, confirmedVehicleCardsDoc([
    '2019 Honda PILOT 5FNYF6H55KB000001 Edit Remove CONFIRMED'
  ])), ['result', 'confirmedCount', 'matchedExpectedCount', 'unexpectedCount']);
  assert.strictEqual(expectedConfirmedStatus.result, 'OK');
  assert.strictEqual(expectedConfirmedStatus.matchedExpectedCount, '1');
  assert.strictEqual(expectedConfirmedStatus.unexpectedCount, '0');
  const catalogConfirmedStatus = assertKeyBlock(runOperator('gather_confirmed_vehicles_status', {
    expectedVehicles: [
      {
        year: '2019',
        make: 'Toyota',
        model: 'Corolla',
        allowedMakeLabels: 'TOYOTA',
        strictModelMatch: '1'
      },
      {
        year: '2019',
        make: 'Toyota',
        model: 'Highlander',
        allowedMakeLabels: 'TOYOTA|TOY. TRUCKS',
        strictModelMatch: '1'
      }
    ]
  }, confirmedVehicleCardsDoc([
    '2019 Toyota COROLLA 2T1BURHE4KC199094 Edit Remove CONFIRMED',
    '2019 Toy. trucks HIGHLANDER 5TDKZRFH6KS554658 Edit Remove CONFIRMED'
  ])), ['result', 'confirmedCount', 'expectedCount', 'matchedExpectedCount', 'unexpectedCount', 'unexpectedVehicles']);
  assert.strictEqual(catalogConfirmedStatus.result, 'OK');
  assert.strictEqual(catalogConfirmedStatus.expectedCount, '2');
  assert.strictEqual(catalogConfirmedStatus.matchedExpectedCount, '2');
  assert.strictEqual(catalogConfirmedStatus.unexpectedCount, '0');
  const priusPrimeMismatchStatus = assertKeyBlock(runOperator('gather_confirmed_vehicles_status', {
    expectedVehicles: [
      {
        year: '2019',
        make: 'Toyota',
        model: 'Prius',
        allowedMakeLabels: 'TOYOTA',
        strictModelMatch: '1'
      }
    ]
  }, confirmedVehicleCardsDoc([
    '2019 Toyota Prius Prime JTDKARFP0K3000001 Edit Remove CONFIRMED'
  ])), ['result', 'matchedExpectedCount', 'unexpectedCount', 'unexpectedVehicles', 'missingExpectedVehicles']);
  assert.strictEqual(priusPrimeMismatchStatus.result, 'UNEXPECTED');
  assert.strictEqual(priusPrimeMismatchStatus.matchedExpectedCount, '0');
  assert.strictEqual(priusPrimeMismatchStatus.unexpectedCount, '1');
  assert.match(priusPrimeMismatchStatus.unexpectedVehicles, /Prius Prime/);
  assert.match(priusPrimeMismatchStatus.missingExpectedVehicles, /Prius/);
  const transitConnectMismatchStatus = assertKeyBlock(runOperator('gather_confirmed_vehicles_status', {
    expectedVehicles: [
      {
        year: '2020',
        make: 'Ford',
        model: 'Transit',
        allowedMakeLabels: 'FORD|FORD VANS',
        strictModelMatch: '1'
      }
    ]
  }, confirmedVehicleCardsDoc([
    '2020 Ford Vans Transit Connect FAKEVAN1*******04 Edit Remove CONFIRMED'
  ])), ['result', 'matchedExpectedCount', 'unexpectedCount', 'missingExpectedVehicles']);
  assert.strictEqual(transitConnectMismatchStatus.result, 'UNEXPECTED');
  assert.strictEqual(transitConnectMismatchStatus.matchedExpectedCount, '0');
  assert.strictEqual(transitConnectMismatchStatus.unexpectedCount, '1');
  assert.match(transitConnectMismatchStatus.missingExpectedVehicles, /Transit/);
  const unresolvedConfirmedStatus = assertKeyBlock(runOperator('gather_confirmed_vehicles_status', {
    expectedVehiclesText: '|Toyota|Prius Prime|'
  }, new FakeDocument()), ['result', 'expectedCount', 'unresolvedLeadVehicles']);
  assert.strictEqual(unresolvedConfirmedStatus.expectedCount, '0');
  assert.match(unresolvedConfirmedStatus.unresolvedLeadVehicles, /Toyota Prius Prime/);
  const vehicleInProgressStatus = assertKeyBlock(runOperator('gather_vehicle_add_status', { year: '2019', make: 'Honda', model: 'Pilot' }, new FakeDocument([
    textNode('Auto originally asked for. Please Confirm or Add at least 1 car or truck.'),
    createButton('add-car-or-truck', 'Add Car or Truck')
  ])), ['result', 'rowGone', 'warningStillPresent']);
  assert.strictEqual(vehicleInProgressStatus.result, 'IN_PROGRESS');
  assert.strictEqual(vehicleInProgressStatus.rowGone, '1');
  assert.strictEqual(vehicleInProgressStatus.warningStillPresent, '1');
  const vehicleReadyRowStatus = assertKeyBlock(runOperator('gather_vehicle_add_status', { year: '2019', make: 'Honda', model: 'Pilot', index: 0 }, new FakeDocument(createCompleteVehicleRow(0))), ['result', 'rowOpen', 'rowComplete']);
  assert.strictEqual(vehicleReadyRowStatus.result, 'READY_ROW');
  assert.strictEqual(vehicleReadyRowStatus.rowComplete, '1');
  const vehicleFailedStatus = assertKeyBlock(runOperator('gather_vehicle_add_status', { year: '2019', make: 'Honda', model: 'Pilot' }, new FakeDocument([
    new FakeElement('div', { className: 'validation-error', text: 'This is required' })
  ])), ['result', 'alerts', 'method']);
  assert.strictEqual(vehicleFailedStatus.result, 'FAILED');
  assert.match(vehicleFailedStatus.alerts, /required/);

  const editStatusDoc = createVehicleEditModalDoc();
  const editStatus = assertKeyBlock(runOperator('gather_vehicle_edit_status', {}, editStatusDoc.doc), [
    'result', 'subModelPresent', 'subModelText', 'subModelOptionCount', 'updateButtonPresent', 'updateButtonEnabled', 'evidence'
  ]);
  assert.strictEqual(editStatus.result, 'SUBMODEL_REQUIRED');
  assert.strictEqual(editStatus.subModelPresent, '1');
  assert.strictEqual(editStatus.updateButtonPresent, '1');

  const firstValidEdit = createVehicleEditModalDoc();
  const firstValid = assertKeyBlock(runOperator('handle_vehicle_edit_modal', {
    year: '2019',
    make: 'Toyota',
    model: 'Corolla'
  }, firstValidEdit.doc), [
    'result', 'subModelSelectedValue', 'subModelSelectedText', 'subModelSelectionMethod', 'updateClicked'
  ]);
  assert.strictEqual(firstValid.result, 'UPDATED');
  assert.strictEqual(firstValid.subModelSelectionMethod, 'first-valid');
  assert.strictEqual(firstValid.subModelSelectedValue, 'BASE');
  assert.strictEqual(firstValidEdit.subModel.value, 'BASE');
  assert.strictEqual(firstValidEdit.updateButton.clickCalls, 1);

  const vinPatternEdit = createVehicleEditModalDoc({
    vin: '2T1BURHE4KC199094',
    options: [
      { value: '', text: 'Select One' },
      { value: 'BASE', text: '|SEDAN|GAS|FWD|04Cyl|4Dr|2T1BURHE*K' },
      { value: 'LE', text: 'LE |SEDAN|GAS|FWD|04Cyl|4Dr|2T1BURHE*K' }
    ]
  });
  const vinPattern = assertKeyBlock(runOperator('handle_vehicle_edit_modal', {
    year: '2019',
    make: 'Toyota',
    model: 'Corolla',
    vin: '2T1BURHE4KC199094'
  }, vinPatternEdit.doc), [
    'result', 'subModelSelectedValue', 'subModelSelectionMethod', 'updateClicked'
  ]);
  assert.strictEqual(vinPattern.result, 'UPDATED');
  assert.strictEqual(vinPattern.subModelSelectionMethod, 'vin-pattern');
  assert.strictEqual(vinPattern.subModelSelectedValue, 'BASE');
  assert.strictEqual(vinPatternEdit.updateButton.clickCalls, 1);

  const trimEdit = createVehicleEditModalDoc({
    options: [
      { value: '', text: 'Select One' },
      { value: 'BASE', text: '|SEDAN|GAS|FWD|04Cyl|4Dr' },
      { value: 'LE', text: 'LE |SEDAN|GAS|FWD|04Cyl|4Dr' },
      { value: 'SE', text: 'SE |SEDAN|GAS|FWD|04Cyl|4Dr' }
    ]
  });
  const trimMatch = assertKeyBlock(runOperator('handle_vehicle_edit_modal', {
    year: '2019',
    make: 'Toyota',
    model: 'Corolla',
    trimHint: 'LE'
  }, trimEdit.doc), ['result', 'subModelSelectedValue', 'subModelSelectionMethod']);
  assert.strictEqual(trimMatch.result, 'UPDATED');
  assert.strictEqual(trimMatch.subModelSelectionMethod, 'trim-match');
  assert.strictEqual(trimMatch.subModelSelectedValue, 'LE');

  const noOptionsEdit = createVehicleEditModalDoc({ options: [{ value: '', text: 'Select One' }] });
  const noOptions = assertKeyBlock(runOperator('handle_vehicle_edit_modal', {
    year: '2019',
    make: 'Toyota',
    model: 'Corolla'
  }, noOptionsEdit.doc), ['result', 'subModelOptionCount', 'updateClicked', 'failedFields']);
  assert.strictEqual(noOptions.result, 'NO_SUBMODEL_OPTIONS');
  assert.strictEqual(noOptions.subModelOptionCount, '0');
  assert.strictEqual(noOptions.updateClicked, '0');

  const updateDisabledEdit = createVehicleEditModalDoc({ updateDisabled: true });
  const updateDisabled = assertKeyBlock(runOperator('handle_vehicle_edit_modal', {
    year: '2019',
    make: 'Toyota',
    model: 'Corolla'
  }, updateDisabledEdit.doc), ['result', 'subModelSelectedValue', 'updateButtonEnabled', 'updateClicked', 'failedFields']);
  assert.strictEqual(updateDisabled.result, 'FAILED');
  assert.strictEqual(updateDisabled.subModelSelectedValue, 'BASE');
  assert.strictEqual(updateDisabled.updateButtonEnabled, '0');
  assert.strictEqual(updateDisabled.updateClicked, '0');
  assert.ok(updateDisabled.failedFields.includes('updateButton'));

  const noModal = assertKeyBlock(runOperator('handle_vehicle_edit_modal', {}, new FakeDocument()), ['result', 'updateClicked', 'failedFields']);
  assert.strictEqual(noModal.result, 'NO_MODAL');
  assert.strictEqual(noModal.updateClicked, '0');

  assert.strictEqual(runOperator('wait_vehicle_select_enabled', { index: 0, fieldName: 'Manufacturer' }, new FakeDocument(createVehicleInputRow(0, ''))), '1');
  assert.strictEqual(runOperator('wait_vehicle_select_enabled', { index: 0, fieldName: 'Manufacturer' }, new FakeDocument()), '0');
  const makeDoc = new FakeDocument(createVehicleInputRow(0, ''));
  assert.strictEqual(runOperator('select_vehicle_dropdown_option', { index: 0, fieldName: 'Manufacturer', wantedText: 'Honda' }, makeDoc), 'OK');
  assert.strictEqual(makeDoc.getElementById('ConsumerData.Assets.Vehicles[0].Manufacturer').value, 'HONDA');
  const aliasDoc = new FakeDocument(createVehicleInputRow(0, ''));
  assert.strictEqual(runOperator('select_vehicle_dropdown_option', { index: 0, fieldName: 'Manufacturer', wantedText: 'Chevy' }, aliasDoc), 'OK');
  assert.strictEqual(aliasDoc.getElementById('ConsumerData.Assets.Vehicles[0].Manufacturer').value, 'CHEVROLET');
  assert.strictEqual(runOperator('select_vehicle_dropdown_option', { index: 0, fieldName: 'Manufacturer', wantedText: 'FORD' }, new FakeDocument()), 'NO_SELECT');
  assert.strictEqual(runOperator('select_vehicle_dropdown_option', { index: 0, fieldName: 'Manufacturer', wantedText: 'TESLA' }, new FakeDocument(createVehicleInputRow(0, ''))), 'NO_OPTION');
  assert.strictEqual(runOperator('select_vehicle_dropdown_option', { index: 0, fieldName: 'ModelYear', wantedText: '2024' }, new FakeDocument(createVehicleSelectYearRow(0))), 'NO_OPTION');
  const subModelDoc = new FakeDocument(createVehicleInputRow(0, ''));
  assert.strictEqual(runOperator('select_vehicle_dropdown_option', { index: 0, fieldName: 'SubModel', wantedText: '', allowFirstNonEmpty: true }, subModelDoc), 'OK');
  assert.strictEqual(subModelDoc.getElementById('ConsumerData.Assets.Vehicles[0].SubModel').value, 'EXL');

  assert.strictEqual(runOperator('vehicle_marked_added', { year: '2022', make: 'Tesla', model: 'Model 3' }, addedVehicleDoc), '1');
  assert.strictEqual(runOperator('vehicle_marked_added', { year: '2022', make: 'Tesla', model: 'Model 3' }, new FakeDocument()), '0');
  assert.strictEqual(runOperator('find_vehicle_add_button', { year: '2023', make: 'Ford', model: 'F-150' }, new FakeDocument([createButton('2023-ford-f150-add', 'Add')])), '2023-ford-f150-add');
  assert.strictEqual(runOperator('find_vehicle_add_button', { year: '2023', make: 'Ford', model: 'F-150' }, new FakeDocument()), '');
  assert.strictEqual(runOperator('find_vehicle_add_button', { year: '2023', make: 'Ford', model: 'F-150' }, new FakeDocument([
    createButton('2023-ford-f150-add', 'Add'),
    createButton('2023-ford-f150-addToQuote', 'Add')
  ])), 'AMBIGUOUS');
  assert.strictEqual(runOperator('any_vehicle_already_added', {}, addedVehicleDoc), '1');
  assert.strictEqual(runOperator('any_vehicle_already_added', {}, new FakeDocument()), '0');

  const autoLabelDoc = startQuotingCheckboxDoc();
  const autoLabelStatus = assertKeyBlock(runOperator('ensure_start_quoting_auto_checkbox', {}, autoLabelDoc), ['result', 'autoPresent', 'autoCheckedBefore', 'autoCheckedAfter', 'clicked', 'directSetUsed', 'method', 'failedFields']);
  assert.strictEqual(autoLabelStatus.result, 'OK');
  assert.strictEqual(autoLabelStatus.autoCheckedBefore, '0');
  assert.strictEqual(autoLabelStatus.autoCheckedAfter, '1');
  assert.strictEqual(autoLabelStatus.clicked, '1');
  assert.strictEqual(autoLabelStatus.directSetUsed, '0');
  assert.ok(['stable-checkbox-label', 'stable-checkbox-input'].includes(autoLabelStatus.method));
  const autoDirectDoc = startQuotingCheckboxDoc({ labelChecks: false, clickThrows: true });
  const autoDirectStatus = assertKeyBlock(runOperator('ensure_start_quoting_auto_checkbox', {}, autoDirectDoc), ['result', 'autoCheckedAfter', 'clicked', 'directSetUsed', 'method']);
  assert.strictEqual(autoDirectStatus.result, 'OK');
  assert.strictEqual(autoDirectStatus.autoCheckedAfter, '1');
  assert.strictEqual(autoDirectStatus.directSetUsed, '1');
  assert.match(autoDirectStatus.method, /direct/);
  const autoMissingStatus = assertKeyBlock(runOperator('ensure_start_quoting_auto_checkbox', {}, new FakeDocument()), ['result', 'autoPresent', 'autoCheckedAfter', 'clicked', 'directSetUsed', 'method']);
  assert.strictEqual(autoMissingStatus.result, 'FAILED');
  assert.strictEqual(autoMissingStatus.autoPresent, '0');
  assert.strictEqual(autoMissingStatus.clicked, '0');

  const scopedAdd = startQuotingScopedAddProductDoc();
  assert.strictEqual(runOperator('click_start_quoting_add_product', { selectors: BASE_SELECTORS }, scopedAdd.doc), 'OK');
  assert.strictEqual(scopedAdd.scoped.clickCalls, 1);
  assert.strictEqual(scopedAdd.sidebar.clickCalls, 0);

  const selectProductSubnav = new FakeElement('a', { text: 'SELECT PRODUCT', className: 'c-sub-nav__item dd-privacy-allow' });
  const addProductDecoy = createButton('addProduct', 'Add Product', { className: 'c-sidebar-item' });
  const rapportSubnavDoc = pageDoc('Gather Data SELECT PRODUCT Add Product', [addProductDecoy, selectProductSubnav]);
  const subnavStatus = assertKeyBlock(runOperator('click_product_overview_subnav_from_rapport', baseArgs(), rapportSubnavDoc), [
    'result', 'clicked', 'targetText', 'targetClass', 'targetTag', 'urlBefore', 'evidence'
  ]);
  assert.strictEqual(subnavStatus.result, 'OK');
  assert.strictEqual(subnavStatus.clicked, '1');
  assert.strictEqual(selectProductSubnav.clickCalls, 1);
  assert.strictEqual(addProductDecoy.clickCalls, 0);
  assert.match(subnavStatus.targetClass, /c-sub-nav__item/);
  const addProductOnlyStatus = assertKeyBlock(runOperator('click_product_overview_subnav_from_rapport', baseArgs(), pageDoc('Gather Data Add Product', [
    createButton('addProduct', 'Add Product', { className: 'c-sidebar-item' })
  ])), ['result', 'clicked', 'evidence']);
  assert.strictEqual(addProductOnlyStatus.result, 'NO_LINK');
  assert.strictEqual(addProductOnlyStatus.clicked, '0');
  const wrongPageSubnavStatus = assertKeyBlock(runOperator('click_product_overview_subnav_from_rapport', baseArgs(), pageDoc('Select Product SELECT PRODUCT', [
    new FakeElement('a', { text: 'SELECT PRODUCT', className: 'c-sub-nav__item' })
  ]), 'https://advisorpro.allstate.com/#/apps/intel/102/overview'), ['result', 'clicked']);
  assert.strictEqual(wrongPageSubnavStatus.result, 'WRONG_PAGE');
  const subnavFixture = fixtureScenario('rapport-select-product-subnav-with-add-product-decoy');
  const subnavFixtureStatus = assertKeyBlock(runOperator('click_product_overview_subnav_from_rapport', baseArgs(), subnavFixture.doc, subnavFixture.href), ['result', 'clicked', 'targetText']);
  assert.strictEqual(subnavFixtureStatus.result, 'OK');
  assert.strictEqual(subnavFixtureStatus.targetText, 'SELECT PRODUCT');
  const addProductOnlyFixture = fixtureScenario('rapport-only-sidebar-add-product');
  const addProductOnlyFixtureStatus = assertKeyBlock(runOperator('click_product_overview_subnav_from_rapport', baseArgs(), addProductOnlyFixture.doc, addProductOnlyFixture.href), ['result', 'clicked']);
  assert.strictEqual(addProductOnlyFixtureStatus.result, 'NO_LINK');
}

function duplicateRow(text, id = 'dup-radio') {
  const row = new FakeElement('div', { className: 'sfmOption', text });
  row.appendChild(createRadio(id, 'duplicate', id));
  return row;
}

function duplicateContinueButton() {
  return createButton('duplicate-continue', 'Continue with Selected');
}

function duplicateLiveShapeMovedAddressDoc({ enableContinueOnRadio = true, includeCreateNewRadio = true, includeContinue = true } = {}) {
  const nodes = [];
  const continueButton = includeContinue
    ? createButton('duplicate-continue', 'Continue with Selected', { disabled: true })
    : null;
  const enableContinue = () => {
    if (enableContinueOnRadio && continueButton)
      continueButton.disabled = false;
  };
  nodes.push(createRadio('existing-sfm', 'sfmOption', '1', { onClick: enableContinue }));
  if (includeCreateNewRadio)
    nodes.push(createRadio('create-new-sfm', 'sfmOption', '0', { onClick: enableContinue }));
  if (continueButton)
    nodes.push(continueButton);
  nodes.push(createButton('PrimaryApplicant-Continue-button', 'Create New Prospect'));
  return pageDoc(
    'Begin Quoting Create New Prospect This Prospect May Already Exist Use EXISTING profile found FIRST LAST STREET CITY STATE ZIP DOB STATUS John Smith 456 Old Rd Orlando FL 32801 01/01/1980 Prospect Create NEW profile using data you entered FIRST LAST STREET CITY STATE ZIP DOB STATUS John Smith 123 Main St Miami FL 33101 01/01/1980 Continue with Selected',
    nodes
  );
}

function addressVerificationFixture({
  entered = '4635 NW 44th Tamarac FL 33319',
  suggestions = [],
  enableContinueOnRadio = true
} = {}) {
  const continueButton = createButton('address-continue', 'Continue with Selected', { disabled: true });
  const enableContinue = () => {
    if (enableContinueOnRadio)
      continueButton.disabled = false;
  };
  const rows = [];
  const enteredRow = new FakeElement('div', { className: 'sna-option', text: `You Entered ${entered}` });
  enteredRow.appendChild(createRadio('sna-entered', 'snaOption', '0', { onClick: enableContinue, onDispatch: enableContinue }));
  rows.push(enteredRow);
  suggestions.forEach((suggestion, index) => {
    const value = String(index + 1);
    const row = new FakeElement('div', { className: 'sna-option', text: `${index === 0 ? 'Did You Mean?' : ''} ${suggestion}` });
    row.appendChild(createRadio(`sna-suggestion-${value}`, 'snaOption', value, { onClick: enableContinue, onDispatch: enableContinue }));
    rows.push(row);
  });
  const lowerCreateNew = createButton('PrimaryApplicant-Continue-button', 'Create New Prospect');
  const doc = pageDoc(
    `Begin Quoting Create New Prospect Address Verification You Entered ${entered} Did You Mean? ${suggestions.join(' ')} Continue with Selected`,
    [...rows, continueButton, lowerCreateNew]
  );
  return { doc, continueButton, lowerCreateNew };
}

function addressVerificationArgs(extra = {}) {
  return Object.assign({
    street: '4635 NW 44th Ct',
    city: 'Tamarac',
    state: 'FL',
    zip: '33319',
    unit: ''
  }, extra);
}

function duplicateArgs(extra = {}) {
  return Object.assign({
    firstName: 'John',
    lastName: 'Smith',
    street: '123 Main St',
    city: 'Miami',
    state: 'FL',
    zip: '33101',
    dob: '',
    phone: '',
    email: ''
  }, extra);
}

function testAddressVerificationContracts() {
  const statusFixture = addressVerificationFixture({
    suggestions: [
      '4635 NW 44th St Tamarac, FL 33319-3675',
      '4635 NW 44th Ct Tamarac, FL 33319-3612'
    ]
  });
  const status = assertKeyBlock(runOperator('address_verification_status', {}, statusFixture.doc, 'https://advisorpro.allstate.com/#/apps/intel/102/start'), [
    'result', 'modalPresent', 'radioCount', 'continuePresent', 'continueEnabled', 'enteredText', 'suggestionCount', 'suggestions'
  ]);
  assert.strictEqual(status.result, 'FOUND');
  assert.strictEqual(status.radioCount, '3');
  assert.strictEqual(status.continuePresent, '1');
  assert.strictEqual(status.suggestionCount, '2');

  const secondSuggestion = assertKeyBlock(runOperator('handle_address_verification', addressVerificationArgs(), statusFixture.doc, 'https://advisorpro.allstate.com/#/apps/intel/102/start'), [
    'result', 'method', 'selectedValue', 'selectedText', 'radioSelected', 'continueButtonEnabledAfter', 'continueClicked', 'matchScore', 'matchedBy'
  ]);
  assert.strictEqual(secondSuggestion.result, 'SELECTED');
  assert.strictEqual(secondSuggestion.selectedValue, '2');
  assert.ok(secondSuggestion.selectedText.includes('44th Ct'));
  assert.strictEqual(secondSuggestion.radioSelected, '1');
  assert.strictEqual(secondSuggestion.continueClicked, '1');
  assert.strictEqual(statusFixture.lowerCreateNew.clickCalls, 0);

  const firstSuggestionFixture = addressVerificationFixture({
    suggestions: [
      '4635 NW 44th Ct Tamarac, FL 33319-3612',
      '4635 NW 44th St Tamarac, FL 33319-3675'
    ]
  });
  const firstSuggestion = assertKeyBlock(runOperator('handle_address_verification', addressVerificationArgs(), firstSuggestionFixture.doc, 'https://advisorpro.allstate.com/#/apps/intel/102/start'), [
    'result', 'selectedValue', 'continueClicked'
  ]);
  assert.strictEqual(firstSuggestion.result, 'SELECTED');
  assert.strictEqual(firstSuggestion.selectedValue, '1');
  assert.strictEqual(firstSuggestion.continueClicked, '1');

  const zip4Fixture = addressVerificationFixture({
    entered: '4635 NW 44th Ct Tamarac FL 33319',
    suggestions: ['4635 NW 44th Ct Tamarac, FL 33319-3612']
  });
  const zip4 = assertKeyBlock(runOperator('handle_address_verification', addressVerificationArgs(), zip4Fixture.doc, 'https://advisorpro.allstate.com/#/apps/intel/102/start'), [
    'result', 'method', 'selectedValue', 'matchedBy'
  ]);
  assert.strictEqual(zip4.result, 'SELECTED');
  assert.strictEqual(zip4.selectedValue, '1');
  assert.ok(zip4.matchedBy.includes('zip4'));

  const enteredFixture = addressVerificationFixture({
    entered: '4635 NW 44th Ct Tamarac FL 33319',
    suggestions: ['4635 NW 44th St Tamarac, FL 33319-3675']
  });
  const entered = assertKeyBlock(runOperator('handle_address_verification', addressVerificationArgs(), enteredFixture.doc, 'https://advisorpro.allstate.com/#/apps/intel/102/start'), [
    'result', 'method', 'selectedValue', 'continueClicked'
  ]);
  assert.strictEqual(entered.result, 'SELECTED');
  assert.strictEqual(entered.selectedValue, '0');
  assert.strictEqual(entered.continueClicked, '1');

  const ambiguousFixture = addressVerificationFixture({
    suggestions: [
      '4635 NW 44th St Tamarac, FL 33319-3675',
      '4635 NW 44th Ct Tamarac, FL 33319-3612'
    ]
  });
  const ambiguous = assertKeyBlock(runOperator('handle_address_verification', addressVerificationArgs({ street: '4635 NW 44th' }), ambiguousFixture.doc, 'https://advisorpro.allstate.com/#/apps/intel/102/start'), [
    'result', 'method', 'continueClicked', 'failedFields'
  ]);
  assert.strictEqual(ambiguous.result, 'AMBIGUOUS');
  assert.strictEqual(ambiguous.continueClicked, '0');
  assert.ok(ambiguous.failedFields.includes('ambiguousAddress'));

  const noSafeFixture = addressVerificationFixture({
    suggestions: ['4635 NW 44th St Tamarac, FL 33319-3675']
  });
  const noSafe = assertKeyBlock(runOperator('handle_address_verification', addressVerificationArgs(), noSafeFixture.doc, 'https://advisorpro.allstate.com/#/apps/intel/102/start'), [
    'result', 'method', 'continueClicked', 'failedFields'
  ]);
  assert.strictEqual(noSafe.result, 'FAILED');
  assert.strictEqual(noSafe.continueClicked, '0');

  const disabledFixture = addressVerificationFixture({
    suggestions: ['4635 NW 44th Ct Tamarac, FL 33319-3612'],
    enableContinueOnRadio: false
  });
  const disabled = assertKeyBlock(runOperator('handle_address_verification', addressVerificationArgs(), disabledFixture.doc, 'https://advisorpro.allstate.com/#/apps/intel/102/start'), [
    'result', 'method', 'radioSelected', 'continueButtonEnabledAfter', 'continueClicked', 'failedFields'
  ]);
  assert.strictEqual(disabled.result, 'FAILED');
  assert.strictEqual(disabled.method, 'address-radio-continue-disabled');
  assert.strictEqual(disabled.radioSelected, '1');
  assert.strictEqual(disabled.continueButtonEnabledAfter, '0');
  assert.strictEqual(disabled.continueClicked, '0');
  assert.ok(disabled.failedFields.includes('continueWithSelected'));
}

function testDuplicateContracts() {
  const createNew = assertKeyBlock(runOperator('handle_duplicate_prospect', duplicateArgs(), duplicateDoc([
    duplicateRow('Jane Smith 123 Main St Miami FL 33101', 'weak'),
    createButton('create-new', 'Create New Prospect')
  ]), 'https://advisorpro.allstate.com/#/duplicate'), ['result']);
  assert.strictEqual(createNew.result, 'CREATE_NEW');

  const selected = assertKeyBlock(runOperator('handle_duplicate_prospect', duplicateArgs(), duplicateDoc([
    duplicateRow('John Smith 123 Main St Miami FL 33101', 'strong'),
    createButton('continue', 'Continue')
  ]), 'https://advisorpro.allstate.com/#/duplicate'), ['result']);
  assert.strictEqual(selected.result, 'SELECT_EXISTING');

  const ambiguous = assertKeyBlock(runOperator('handle_duplicate_prospect', duplicateArgs(), duplicateDoc([
    duplicateRow('John Smith 123 Main St Miami FL 33101', 'strong-a'),
    duplicateRow('John Smith 123 Main Street Miami FL 33101', 'strong-b')
  ]), 'https://advisorpro.allstate.com/#/duplicate'), ['result']);
  assert.strictEqual(ambiguous.result, 'AMBIGUOUS_DUPLICATE');

  const failed = assertKeyBlock(runOperator('handle_duplicate_prospect', duplicateArgs(), duplicateDoc([
    duplicateRow('Unrelated Person 999 Other Rd 99999', 'miss')
  ]), 'https://advisorpro.allstate.com/#/duplicate'), ['result']);
  assert.strictEqual(failed.result, 'FAILED');

  const fallback = assertKeyBlock(runOperator('handle_duplicate_prospect', duplicateArgs(), duplicateDoc([
    createButton('continue', 'Continue')
  ]), 'https://advisorpro.allstate.com/#/duplicate'), ['result']);
  assert.strictEqual(fallback.result, 'FALLBACK_CONTINUE');
}

function testDuplicateMovedAddressContracts() {
  const movedExisting = duplicateRow('Use EXISTING profile found FIRST LAST STREET CITY STATE ZIP DOB STATUS John Smith 456 Old Rd Orlando FL 32801 01/01/1980 Prospect', 'existing-old-address');
  const movedCreateNew = duplicateRow('Create NEW profile using data you entered FIRST LAST STREET CITY STATE ZIP DOB STATUS John Smith 123 Main St Miami FL 33101 01/01/1980', 'create-new-entered-address');
  const moved = assertKeyBlock(runOperator('handle_duplicate_prospect', duplicateArgs({ dob: '01/01/1980' }), duplicateDoc([
    movedExisting,
    movedCreateNew,
    duplicateContinueButton()
  ]), 'https://advisorpro.allstate.com/#/duplicate'), ['result', 'method', 'addressDecision', 'existingAddressMatch', 'newProfileOptionFound', 'continueClicked']);
  assert.strictEqual(moved.result, 'CREATE_NEW');
  assert.strictEqual(moved.method, 'create-new-radio');
  assert.strictEqual(moved.addressDecision, 'moved-address-create-new');
  assert.strictEqual(moved.existingAddressMatch, '0');
  assert.strictEqual(moved.newProfileOptionFound, '1');
  assert.strictEqual(moved.continueClicked, '1');

  const sameAddressExisting = duplicateRow('Use EXISTING profile found FIRST LAST STREET CITY STATE ZIP DOB STATUS John Smith 123 Main St Miami FL 33101 01/01/1980 Prospect', 'existing-same-address');
  const sameAddressCreateNew = duplicateRow('Create NEW profile using data you entered FIRST LAST STREET CITY STATE ZIP DOB STATUS John Smith 123 Main St Miami FL 33101 01/01/1980', 'create-new-same-address');
  const same = assertKeyBlock(runOperator('handle_duplicate_prospect', duplicateArgs({ dob: '01/01/1980' }), duplicateDoc([
    sameAddressExisting,
    sameAddressCreateNew,
    duplicateContinueButton()
  ]), 'https://advisorpro.allstate.com/#/duplicate'), ['result', 'method', 'addressDecision', 'existingAddressMatch']);
  assert.strictEqual(same.result, 'SELECT_EXISTING');
  assert.strictEqual(same.method, 'select-existing-radio');
  assert.strictEqual(same.addressDecision, 'same-address-existing');
  assert.strictEqual(same.existingAddressMatch, '1');

  const ambiguous = assertKeyBlock(runOperator('handle_duplicate_prospect', duplicateArgs({ dob: '01/01/1980' }), duplicateDoc([
    duplicateRow('Use EXISTING profile found John Smith 123 Main St Miami FL 33101 01/01/1980 Prospect', 'same-a'),
    duplicateRow('Use EXISTING profile found John Smith 123 Main Street Miami FL 33101 01/01/1980 Prospect', 'same-b'),
    duplicateRow('Create NEW profile using data you entered John Smith 123 Main St Miami FL 33101 01/01/1980', 'create-new-ambiguous')
  ]), 'https://advisorpro.allstate.com/#/duplicate'), ['result', 'method', 'addressDecision']);
  assert.strictEqual(ambiguous.result, 'AMBIGUOUS_DUPLICATE');
  assert.strictEqual(ambiguous.addressDecision, 'same-address-ambiguous');

  const missingCreateNew = assertKeyBlock(runOperator('handle_duplicate_prospect', duplicateArgs({ dob: '01/01/1980' }), duplicateDoc([
    duplicateRow('Use EXISTING profile found John Smith 456 Old Rd Orlando FL 32801 01/01/1980 Prospect', 'existing-no-create'),
    duplicateContinueButton()
  ]), 'https://advisorpro.allstate.com/#/duplicate'), ['result', 'method', 'addressDecision', 'newProfileOptionFound']);
  assert.strictEqual(missingCreateNew.result, 'FAILED');
  assert.strictEqual(missingCreateNew.method, 'moved-address-create-new-option-missing');
  assert.strictEqual(missingCreateNew.newProfileOptionFound, '0');

  const weakCreateNew = assertKeyBlock(runOperator('handle_duplicate_prospect', duplicateArgs({ dob: '', phone: '', email: '' }), duplicateDoc([
    duplicateRow('Use EXISTING profile found John Smith 456 Old Rd Orlando FL 32801 Prospect', 'weak-existing-old'),
    duplicateRow('Create NEW profile using data you entered John Smith 123 Main St Miami FL 33101', 'weak-create-new'),
    duplicateContinueButton()
  ]), 'https://advisorpro.allstate.com/#/duplicate'), ['result', 'method', 'addressDecision']);
  assert.strictEqual(weakCreateNew.result, 'CREATE_NEW');
  assert.strictEqual(weakCreateNew.method, 'create-new-radio');

  const liveShape = assertKeyBlock(runOperator('handle_duplicate_prospect', duplicateArgs({ dob: '01/01/1980' }), duplicateLiveShapeMovedAddressDoc(), 'https://advisorpro.allstate.com/#/apps/intel/102/start'), [
    'result', 'method', 'addressDecision', 'newProfileOptionFound', 'radioValue', 'radioSelected', 'continueButtonPresent', 'continueButtonEnabled', 'continueClicked'
  ]);
  assert.strictEqual(liveShape.result, 'CREATE_NEW');
  assert.strictEqual(liveShape.method, 'create-new-radio');
  assert.strictEqual(liveShape.addressDecision, 'moved-address-create-new');
  assert.strictEqual(liveShape.newProfileOptionFound, '1');
  assert.strictEqual(liveShape.radioValue, '0');
  assert.strictEqual(liveShape.radioSelected, '1');
  assert.strictEqual(liveShape.continueButtonPresent, '1');
  assert.strictEqual(liveShape.continueButtonEnabled, '1');
  assert.strictEqual(liveShape.continueClicked, '1');

  const continueDisabled = assertKeyBlock(runOperator('handle_duplicate_prospect', duplicateArgs({ dob: '01/01/1980' }), duplicateLiveShapeMovedAddressDoc({ enableContinueOnRadio: false }), 'https://advisorpro.allstate.com/#/apps/intel/102/start'), [
    'result', 'method', 'newProfileOptionFound', 'radioValue', 'radioSelected', 'continueButtonPresent', 'continueButtonEnabled', 'continueClicked', 'failedFields'
  ]);
  assert.strictEqual(continueDisabled.result, 'FAILED');
  assert.strictEqual(continueDisabled.method, 'create-new-radio-continue-disabled');
  assert.strictEqual(continueDisabled.radioValue, '0');
  assert.strictEqual(continueDisabled.radioSelected, '1');
  assert.strictEqual(continueDisabled.continueButtonEnabled, '0');
  assert.strictEqual(continueDisabled.continueClicked, '0');
  assert.ok(continueDisabled.failedFields.includes('continueWithSelected'));

  const noRadio = assertKeyBlock(runOperator('handle_duplicate_prospect', duplicateArgs({ dob: '01/01/1980' }), duplicateLiveShapeMovedAddressDoc({ includeCreateNewRadio: false }), 'https://advisorpro.allstate.com/#/apps/intel/102/start'), [
    'result', 'method', 'newProfileOptionFound', 'failedFields'
  ]);
  assert.strictEqual(noRadio.result, 'FAILED');
  assert.strictEqual(noRadio.method, 'create-new-radio-target-missing');
  assert.strictEqual(noRadio.newProfileOptionFound, '1');
  assert.ok(noRadio.failedFields.includes('createNewRadio'));

  const lowerFallback = assertKeyBlock(runOperator('handle_duplicate_prospect', duplicateArgs(), duplicateDoc([
    createButton('PrimaryApplicant-Continue-button', 'Create New Prospect')
  ]), 'https://advisorpro.allstate.com/#/duplicate'), ['result', 'method', 'newProfileOptionFound', 'continueClicked']);
  assert.strictEqual(lowerFallback.result, 'CREATE_NEW');
  assert.strictEqual(lowerFallback.method, 'create-new-button');
  assert.strictEqual(lowerFallback.newProfileOptionFound, '0');
  assert.strictEqual(lowerFallback.continueClicked, '0');
}

function createParticipantModalDoc() {
  return new FakeDocument([
    createInput('ageFirstLicensed_ageFirstLicensed', ''),
    createInput('emailAddress.emailAddress', ''),
    createRadio('militaryFalse', 'agreement.agreementParticipant.militaryInd', 'false'),
    createRadio('violationsFalse', 'agreement.agreementParticipant.party.violationInd', 'false'),
    createRadio('defensiveFalse', 'agreement.agreementParticipant.defensiveDriverInd', 'false'),
    createSelect('propertyOwnershipEntCd_option', [
      { value: '', text: 'Select One' },
      { value: '0001_0120', text: 'Own home' }
    ]),
    createRadio('gender_1002', 'gender', 'M', { checked: true }),
    createRadio('gender_1001', 'gender', 'F'),
    createSelect('maritalStatusWithSpouse_spouseName', [
      { value: '', text: 'Select One' }
    ]),
    createRadio('maritalStatusEntCd_0001', 'marital', 'Married'),
    createButton('PARTICIPANT_SAVE-btn', 'Save')
  ]);
}

function createVehicleModalDoc() {
  return pageDoc('2022 Tesla Model 3 vehicle details', [
    createRadio('garagingAddressSameAsOther-control-item-0', 'garaging', 'yes'),
    createRadio('purchaseDate_false', 'purchaseDate', 'false'),
    createRadio('vehicleOwnershipCd_0007', 'ownership', 'finance'),
    createButton('ADD_ASSET_SAVE-btn', 'Save')
  ]);
}

function createIncidentActionDoc(hasReason, hasContinue) {
  const nodes = [];
  if (hasReason) {
    const label = new FakeElement('label', { text: BASE_DEFAULTS.incidentReasonText });
    label.appendChild(createCheckbox('incidentReason', { value: 'reason' }));
    nodes.push(label);
  }
  if (hasContinue)
    nodes.push(createButton('CONTINUE_OFFER-btn', 'Continue'));
  return new FakeDocument(nodes);
}

function testAscReconciliationContracts() {
  const ascHref = 'https://advisorpro.allstate.com/#/apps/ASCPRODUCT/112/';
  const singleDoc = ascDriversVehiclesDoc({
    marital: 'Married',
    spouseOptions: [
      { value: 'driver-a', text: 'Test Older Driver' },
      { value: 'driver-b', text: 'Test Near Candidate' }
    ],
    drivers: [
      ascDriverRow({ name: 'Test Primary Driver', age: 40, slug: 'test-primary-driver', add: true }),
      ascDriverRow({ name: 'Test Older Driver', age: 66, slug: 'test-older-driver', remove: true }),
      ascDriverRow({ name: 'Test Near Candidate', age: 37, slug: 'test-near-candidate', remove: true })
    ]
  });
  const singleStatus = assertKeyBlock(runOperator('asc_participant_detail_status', baseArgs(), singleDoc, ascHref), [
    'result', 'ascProductRouteId', 'spouseDropdownPresent', 'saveButtonPresent'
  ]);
  assert.strictEqual(singleStatus.result, 'FOUND');
  assert.strictEqual(singleStatus.ascProductRouteId, '112');
  const singleResolved = assertKeyBlock(runOperator('asc_resolve_participant_marital_and_spouse', {
    leadMaritalStatus: 'Single',
    primaryName: 'Test Primary Driver',
    maxSpouseAgeDifference: '14'
  }, singleDoc, ascHref), ['result', 'selectedMaritalStatus', 'spouseSelectionMethod', 'selectedSpouseValue']);
  assert.ok(['SINGLE_CONFIRMED', 'SINGLE_SET'].includes(singleResolved.result));
  assert.strictEqual(singleResolved.spouseSelectionMethod, 'skipped-lead-single');
  assert.strictEqual(singleResolved.selectedSpouseValue, '');

  const marriedDoc = ascDriversVehiclesDoc({
    marital: 'Single',
    spouseOptions: [
      { value: 'driver-a', text: 'Test Older Driver' },
      { value: 'driver-b', text: 'Test Near Candidate' }
    ],
    drivers: [
      ascDriverRow({ name: 'Test Primary Driver', age: 40, slug: 'test-primary-driver', added: true }),
      ascDriverRow({ name: 'Test Older Driver', age: 66, slug: 'test-older-driver', remove: true }),
      ascDriverRow({ name: 'Test Near Candidate', age: 37, slug: 'test-near-candidate', add: true })
    ]
  });
  const marriedResolved = assertKeyBlock(runOperator('asc_resolve_participant_marital_and_spouse', {
    leadMaritalStatus: 'Married',
    primaryName: 'Test Primary Driver',
    maxSpouseAgeDifference: '14'
  }, marriedDoc, ascHref), ['result', 'selectedSpouseText', 'spouseSelectionMethod', 'selectedAgeDiff']);
  const marriedDriverDebug = parseLines(runOperator('asc_driver_rows_status', {}, marriedDoc, ascHref));
  assert.strictEqual(marriedResolved.result, 'SELECTED', JSON.stringify({ marriedResolved, marriedDriverDebug }));
  assert.strictEqual(marriedResolved.selectedSpouseText, 'Test Near Candidate');
  assert.strictEqual(marriedResolved.spouseSelectionMethod, 'age-window');

  const exactNameDoc = ascDriversVehiclesDoc({
    marital: 'Married',
    spouseOptions: [
      { value: 'driver-a', text: 'Test Exact Spouse' },
      { value: 'driver-b', text: 'Test Other Candidate' }
    ],
    drivers: [
      ascDriverRow({ name: 'Test Primary Driver', age: 40, slug: 'test-primary-driver', added: true }),
      ascDriverRow({ name: 'Test Exact Spouse', age: 66, slug: 'test-exact-spouse', add: true }),
      ascDriverRow({ name: 'Test Other Candidate', age: 37, slug: 'test-other-candidate', remove: true })
    ]
  });
  const exactName = assertKeyBlock(runOperator('asc_resolve_participant_marital_and_spouse', {
    leadMaritalStatus: 'Married',
    primaryName: 'Test Primary Driver',
    leadSpouseName: 'Test Exact Spouse'
  }, exactNameDoc, ascHref), ['result', 'selectedSpouseText', 'spouseSelectionMethod']);
  assert.strictEqual(exactName.result, 'SELECTED');
  assert.strictEqual(exactName.selectedSpouseText, 'Test Exact Spouse');
  assert.strictEqual(exactName.spouseSelectionMethod, 'name-match');

  const ambiguousDoc = ascDriversVehiclesDoc({
    marital: 'Single',
    spouseOptions: [
      { value: 'driver-a', text: 'Test Candidate One' },
      { value: 'driver-b', text: 'Test Candidate Two' }
    ],
    drivers: [
      ascDriverRow({ name: 'Test Primary Driver', age: 40, slug: 'test-primary-driver', added: true }),
      ascDriverRow({ name: 'Test Candidate One', age: 38, slug: 'test-candidate-one', add: true }),
      ascDriverRow({ name: 'Test Candidate Two', age: 37, slug: 'test-candidate-two', add: true })
    ]
  });
  const ambiguous = assertKeyBlock(runOperator('asc_resolve_participant_marital_and_spouse', {
    leadMaritalStatus: 'Married',
    primaryName: 'Test Primary Driver',
    maxSpouseAgeDifference: '14'
  }, ambiguousDoc, ascHref), ['result', 'failedFields']);
  assert.strictEqual(ambiguous.result, 'AMBIGUOUS');

  const noSafeDoc = ascDriversVehiclesDoc({
    marital: 'Single',
    spouseOptions: [{ value: 'driver-a', text: 'Test Older Driver' }],
    drivers: [
      ascDriverRow({ name: 'Test Primary Driver', age: 40, slug: 'test-primary-driver', added: true }),
      ascDriverRow({ name: 'Test Older Driver', age: 66, slug: 'test-older-driver', add: true })
    ]
  });
  const noSafe = assertKeyBlock(runOperator('asc_resolve_participant_marital_and_spouse', {
    leadMaritalStatus: 'Married',
    primaryName: 'Test Primary Driver',
    maxSpouseAgeDifference: '14'
  }, noSafeDoc, ascHref), ['result']);
  assert.strictEqual(noSafe.result, 'NO_SAFE_SPOUSE');

  let driverDoc = ascDriversVehiclesDoc({
    marital: 'Single',
    drivers: [
      ascDriverRow({ name: 'Test Primary Driver', age: 40, slug: 'test-primary-driver', add: true }),
      ascDriverRow({ name: 'Test Other Driver One', age: 66, slug: 'test-other-one', remove: true }),
      ascDriverRow({ name: 'Test Other Driver Two', age: 37, slug: 'test-other-two', remove: true })
    ]
  });
  for (let i = 0; i < 3; i += 1) {
    runOperator('asc_reconcile_driver_rows', {
      primaryName: 'Test Primary Driver',
      leadMaritalStatus: 'Single'
    }, driverDoc, ascHref);
  }
  const driverDone = assertKeyBlock(runOperator('asc_reconcile_driver_rows', {
    primaryName: 'Test Primary Driver',
    leadMaritalStatus: 'Single'
  }, driverDoc, ascHref), ['result', 'unresolvedDrivers']);
  assert.strictEqual(driverDone.result, 'OK', JSON.stringify(driverDone));
  assert.strictEqual(driverDone.unresolvedDrivers, '');

  let vehicleDoc = ascDriversVehiclesDoc({
    vehicles: [
      ascVehicleRow({ text: '2019 Honda CR-V VIN: FAKECRV1*******01', slug: 'honda-crv', add: true }),
      ascVehicleRow({ text: '2013 Hyundai Sonata VIN: FAKESONA*******02', slug: 'hyundai-sonata', add: true }),
      ascVehicleRow({ text: '2010 Nissan cube VIN: FAKECUBE*******03', slug: 'nissan-cube', add: true })
    ]
  });
  const vehicleArgs = {
    expectedVehicles: [
      { year: '2019', make: 'Honda', model: 'CR-V', allowedMakeLabels: 'HONDA', strictModelMatch: '1' },
      { year: '2013', make: 'Hyundai', model: 'Sonata', allowedMakeLabels: 'HYUNDAI', strictModelMatch: '1' }
    ],
    partialVehicles: [
      { year: '2010', make: 'Nissan', allowedMakeLabels: 'NISSAN' }
    ]
  };
  for (let i = 0; i < 3; i += 1)
    runOperator('asc_reconcile_vehicle_rows', vehicleArgs, vehicleDoc, ascHref);
  const vehicleDone = assertKeyBlock(runOperator('asc_reconcile_vehicle_rows', vehicleArgs, vehicleDoc, ascHref), [
    'result', 'promotedPartialVehicles', 'unresolvedVehicles'
  ]);
  assert.strictEqual(vehicleDone.result, 'OK');
  assert.ok(vehicleDone.promotedPartialVehicles.includes('2010 Nissan'));
  assert.strictEqual(vehicleDone.unresolvedVehicles, '');

  const partialAmbiguousDoc = ascDriversVehiclesDoc({
    vehicles: [
      ascVehicleRow({ text: '2010 Nissan cube VIN: FAKECUBE*******03', slug: 'nissan-cube', add: true }),
      ascVehicleRow({ text: '2010 Nissan Altima VIN: FAKEALTI*******04', slug: 'nissan-altima', add: true })
    ]
  });
  const partialAmbiguous = assertKeyBlock(runOperator('asc_reconcile_vehicle_rows', {
    expectedVehicles: [],
    partialVehicles: [{ year: '2010', make: 'Nissan', allowedMakeLabels: 'NISSAN' }]
  }, partialAmbiguousDoc, ascHref), ['result', 'failedFields']);
  assert.strictEqual(partialAmbiguous.result, 'AMBIGUOUS');

  const saveDisabledStatus = assertKeyBlock(runOperator('asc_vehicle_rows_status', baseArgs(), ascDriversVehiclesDoc({
    saveDisabled: true,
    vehicles: [ascVehicleRow({ text: '2019 Honda CR-V VIN: FAKECRV1*******01', slug: 'honda-crv', added: true })]
  }), ascHref), ['result', 'saveButtonEnabled']);
  assert.strictEqual(saveDisabledStatus.saveButtonEnabled, '0');
}

function testDriverAndModalContracts() {
  assert.strictEqual(runOperator('list_driver_slugs', {}, new FakeDocument([
    createButton('john-smith-addToQuote', 'Add'),
    createButton('jane-smith-remove', 'Remove'),
    createButton('2022-tesla-add', 'Add')
  ])), 'john-smith||jane-smith');

  const driverCard = new FakeElement('div', { text: 'John Smith Added to quote' });
  driverCard.appendChild(createButton('john-smith-edit', 'Edit'));
  assert.strictEqual(runOperator('driver_is_already_added', { slug: 'john-smith' }, new FakeDocument([driverCard])), '1');
  assert.strictEqual(runOperator('driver_is_already_added', { slug: 'john-smith' }, new FakeDocument([createButton('john-smith-addToQuote', 'Add')])), '0');

  assert.strictEqual(runOperator('modal_exists', { saveButtonId: 'PARTICIPANT_SAVE-btn' }, createParticipantModalDoc()), '1');
  assert.strictEqual(assertKeyBlock(runOperator('fill_participant_modal', baseArgs({
    ageFirstLicensed: '16',
    email: 'driver@example.com',
    military: 'false',
    violations: 'false',
    defensiveDriving: 'false',
    propertyOwnership: '0001_0120',
    expectedGender: 'M',
    oppositeGenderValue: 'F'
  }), createParticipantModalDoc()), ['result']).result, 'OK');
  assert.strictEqual(assertKeyBlock(runOperator('fill_vehicle_modal', { threshold: 2015 }, createVehicleModalDoc()), ['result']).result, 'OK');
}

function testHighRiskStrengthenedContracts() {
  const selectedNoContinue = assertKeyBlock(runOperator('handle_duplicate_prospect', duplicateArgs(), duplicateDoc([
    duplicateRow('John Smith 123 Main St Miami FL 33101', 'strong-no-continue')
  ]), 'https://advisorpro.allstate.com/#/duplicate'), ['result', 'method', 'candidateCount', 'rowCount']);
  assert.strictEqual(selectedNoContinue.result, 'SELECTED_NO_CONTINUE');
  assert.strictEqual(selectedNoContinue.method, 'select-existing-no-continue');

  const confirmButton = createButton('confirm-click-verify', 'Confirm');
  const confirmCard = new FakeElement('div', { className: 'vehicle-card', text: 'POTENTIAL VEHICLES 2022 Tesla Model 3 Long Range Confirm Remove' });
  confirmCard.appendChild(confirmButton);
  confirmCard.appendChild(createButton('confirm-click-verify-remove', 'Remove'));
  const confirmed = assertKeyBlock(runOperator('confirm_potential_vehicle', {
    year: '2022',
    make: 'Tesla',
    model: 'Model 3'
  }, new FakeDocument([confirmCard])), ['result', 'matches', 'cardText', 'score']);
  assert.strictEqual(confirmed.result, 'CONFIRMED');
  assert.strictEqual(confirmButton.clickCalls, 1);

  const ambiguousAdd = fixtureScenario('vehicle-add-card-ambiguity');
  assert.strictEqual(runOperator('find_vehicle_add_button', {
    year: '2023',
    make: 'Ford',
    model: 'F-150'
  }, ambiguousAdd.doc, ambiguousAdd.href), 'AMBIGUOUS');

  const participantHappy = fixtureScenario('participant-modal');
  const participantArgs = baseArgs({
    ageFirstLicensed: '16',
    email: 'driver@example.com',
    military: 'false',
    violations: 'false',
    defensiveDriving: 'false',
    propertyOwnership: '0001_0120',
    expectedGender: 'M',
    oppositeGenderValue: 'F'
  });
  const participantOk = assertKeyBlock(runOperator('fill_participant_modal', participantArgs, participantHappy.doc, participantHappy.href), [
    'result', 'method', 'ageFirstLicensedSet', 'emailSet', 'militarySet', 'violationsSet', 'defensiveDrivingSet', 'propertyOwnershipSet', 'failedFields'
  ]);
  assert.strictEqual(participantOk.result, 'OK');

  const participantPartial = fixtureScenario('participant-modal');
  participantPartial.doc.getElementById('defensiveFalse').clickThrows = true;
  const participantPartialStatus = assertKeyBlock(runOperator('fill_participant_modal', participantArgs, participantPartial.doc, participantPartial.href), [
    'result', 'method', 'defensiveDrivingSet', 'failedFields'
  ]);
  assert.strictEqual(participantPartialStatus.result, 'PARTIAL');
  assert.strictEqual(participantPartialStatus.defensiveDrivingSet, '0');

  const vehicleModal = fixtureScenario('vehicle-modal');
  const vehicleOk = assertKeyBlock(runOperator('fill_vehicle_modal', { threshold: 2015 }, vehicleModal.doc, vehicleModal.href), [
    'result', 'method', 'garagingAddressSameAsOtherClicked', 'purchaseDateFalseClicked', 'ownershipClicked', 'detectedYear', 'failedFields'
  ]);
  assert.strictEqual(vehicleOk.result, 'OK');

  const vehicleFailed = assertKeyBlock(runOperator('fill_vehicle_modal', { threshold: 2015 }, pageDoc('2022 Tesla Model 3 vehicle details')), [
    'result', 'method', 'garagingAddressSameAsOtherClicked', 'purchaseDateFalseClicked', 'ownershipClicked', 'detectedYear', 'failedFields'
  ]);
  assert.strictEqual(vehicleFailed.result, 'FAILED');

  const selectFailure = assertKeyBlock(runOperator('set_select_product_defaults', baseArgs({
    ratingState: 'FL',
    productValue: 'Auto',
    currentInsured: 'YES'
  }), new FakeDocument([
    createSelect('SelectProduct.Product', [
      { value: '', text: 'Select One' },
      { value: 'Auto', text: 'Auto' }
    ]),
    createSelect('SelectProduct.RatingState', [
      { value: '', text: 'Select One' },
      { value: 'FL', text: 'Florida' }
    ]),
    createButton('selectProductContinue', 'Continue')
  ])), ['result', 'productSet', 'ratingStateSet', 'currentInsuredSet', 'failedFields']);
  assert.strictEqual(selectFailure.result, 'FAILED');
  assert.strictEqual(selectFailure.currentInsuredSet, '0');

  const startReady = fixtureScenario('start-quoting-ready');
  const startOk = assertKeyBlock(runOperator('ensure_auto_start_quoting_state', baseArgs({ ratingState: 'FL' }), startReady.doc, startReady.href), [
    'result', 'autoApplied', 'ratingStateApplied', 'hasStartQuotingText', 'startQuotingSectionPresent', 'autoProductSelected', 'autoCheckboxId', 'ratingStatePresent', 'ratingStateValue', 'createQuoteButtonPresent', 'createQuoteButtonEnabled', 'createQuotesPresent', 'createQuotesEnabled', 'evidence', 'missing'
  ]);
  assert.strictEqual(startOk.result, 'OK');
  const startUnchecked = fixtureScenario('start-quoting-auto-unchecked');
  const startUncheckedStatus = assertKeyBlock(runOperator('ensure_start_quoting_auto_checkbox', {}, startUnchecked.doc, startUnchecked.href), [
    'result', 'autoPresent', 'autoCheckedBefore', 'autoCheckedAfter', 'clicked', 'directSetUsed'
  ]);
  assert.strictEqual(startUncheckedStatus.result, 'OK');
  assert.strictEqual(startUncheckedStatus.autoCheckedBefore, '0');
  assert.strictEqual(startUncheckedStatus.autoCheckedAfter, '1');
  const startMissing = fixtureScenario('start-quoting-section-missing');
  const startMissingStatus = assertKeyBlock(runOperator('gather_start_quoting_status', baseArgs(), startMissing.doc, startMissing.href), [
    'hasStartQuotingText', 'startQuotingSectionPresent', 'autoProductPresent', 'missing'
  ]);
  assert.strictEqual(startMissingStatus.startQuotingSectionPresent, '0');
  assert.strictEqual(startMissingStatus.autoProductPresent, '0');

  const startFailed = assertKeyBlock(runOperator('ensure_auto_start_quoting_state', baseArgs({ ratingState: 'FL' }), new FakeDocument()), [
    'result', 'autoApplied', 'ratingStateApplied', 'hasStartQuotingText', 'autoProductSelected', 'createQuoteButtonPresent'
  ]);
  assert.strictEqual(startFailed.result, 'FAILED');

  const scanFixture = fixtureScenario('scan-current-page-rich');
  const scan = JSON.parse(runOperator('scan_current_page', { label: 'FIXTURE', reason: 'shape' }, scanFixture.doc, scanFixture.href));
  for (const key of ['capturedAt', 'stepLabel', 'scanReason', 'url', 'title', 'heading', 'bodySample', 'headings', 'fields', 'buttons', 'radios', 'alerts', 'modalText'])
    assert.ok(Object.prototype.hasOwnProperty.call(scan, key), `scan missing ${key}`);
  assert.strictEqual(scan.stepLabel, 'FIXTURE');
  assert.strictEqual(scan.scanReason, 'shape');
  assert.ok(scan.bodySample.length <= 2500);
  assert.ok(Array.isArray(scan.headings));
  assert.ok(Array.isArray(scan.fields));
  assert.ok(Array.isArray(scan.buttons));
  assert.ok(Array.isArray(scan.radios));
  assert.ok(Array.isArray(scan.alerts));
}

function run() {
  testClickHelperDoesNotDoubleSubmit();
  testResultCalculation();
  testVehicleMatching();
  testDuplicateScoringRejectsWeakMatch();
  testWrapperContracts();
  testResidentRunnerContracts();
  testStateDetectionContract();
  testCustomerSummaryOverviewStatusContract();
  testCustomerSummaryStartHereClickContract();
  testWaitConditionContract();
  testRemainingWaitConditionBranches();
  testReturnShapeContracts();
  testGenericOpsContract();
  testVehicleContracts();
  testAddressVerificationContracts();
  testDuplicateContracts();
  testDuplicateMovedAddressContracts();
  testAscReconciliationContracts();
  testDriverAndModalContracts();
  testHighRiskStrengthenedContracts();
  process.stdout.write('advisor_quote_ops_smoke: PASS\n');
}

run();
