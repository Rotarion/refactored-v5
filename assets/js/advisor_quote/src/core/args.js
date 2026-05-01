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
