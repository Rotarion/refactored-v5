#Requires AutoHotkey v2.0
#SingleInstance Off

global projectRoot := A_ScriptDir
global configRoot := projectRoot "\config"
global logsRoot := projectRoot "\logs"
global assetsRoot := projectRoot "\assets"
global settingsFile := configRoot "\settings.ini"
global timingsFile := configRoot "\timings.ini"
global templatesFile := configRoot "\templates.ini"
global holidaysFile := configRoot "\holidays_2026.ini"
global batchLogFile := logsRoot "\batch_lead_log.csv"
global latestBatchOkFile := logsRoot "\latest_batch_ok_leads.txt"
global runStateFile := logsRoot "\run_state.json"
global advisorQuoteTraceFile := logsRoot "\advisor_quote_trace.log"
global advisorQuoteLastStep := ""
global advisorQuoteLastStepAt := ""
global tagSelectorJsFile := assetsRoot "\js\tag_selector.js"
global participantInputJsFile := assetsRoot "\js\participant_input_focus.js"
global legacyMonolithFile := projectRoot "\..\Final_V5.5.ahk"

global holidays := []
global batchLeadHolder := []
global running := false
global StopFlag := false
global batchResumeIndex := 1
global batchResumeMode := ""
global batchResumeRaw := ""

global agentName := ""
global agentEmail := ""
global tagSymbol := "+"
global configDays := []
global batchMinVehicles := 0
global batchMaxVehicles := 5
global dobDefaultDay := 16
global batchTabsChatToName := 0

global priceOldCar := 0
global priceOneCar := 0
global priceOneCar2020Plus := 0
global priceTwoCars := 0
global priceTwoCarsCutoff := 0
global priceTwoCars2025Plus := 0
global priceThreeCars := 0
global priceFourCars := 0
global priceFiveCars := 0
global singleCarModernYearCutoff := 2020
global twoCarsModernYearCutoff := 2020
global twoCars2025PlusYearCutoff := 2025

global SLOW_ACTIVATE_DELAY := 0
global SLOW_AFTER_MSG := 0
global SLOW_AFTER_SCHED := 0
global SLOW_AFTER_DT_PASTE := 0
global SLOW_AFTER_ENTER := 0
global BATCH_AFTER_ALTN := 0
global BATCH_AFTER_PHONE := 0
global BATCH_AFTER_TAB := 0
global BATCH_AFTER_SCHEDULE := 0
global BATCH_AFTER_ENTER := 0
global BATCH_AFTER_NAME_PICK := 0
global BATCH_AFTER_TAG_PICK := 0
global BATCH_BEFORE_TAG_PASTE := 0
global BATCH_AFTER_TAG_PASTE := 0
global BATCH_POST_PARTICIPANT_READY_STABLE := 0
global BATCH_POST_PARTICIPANT_READY_FAST := 0
global BATCH_AFTER_PARTICIPANT_TO_COMPOSER := 0
global BATCH_AFTER_TAG_COMPLETE := 0
global PROSPECT_TOOLTIP_DELAY := 0
global FORM_FIELD_DELAY := 0
global FORM_TAB_DELAY := 0
global FORM_PASTE_DELAY := 0
global FORM_PASTE_TAB_DELAY := 0
global FORM_CITY_TAB_DELAY := 0
global CRM_ACTION_FOCUS_DELAY := 0
global CRM_KEYSTEP_DELAY := 0
global CRM_SHORT_DELAY := 0
global CRM_MEDIUM_DELAY := 0
global CRM_QUOTE_SHIFT_TAB_DELAY := 0
global CRM_SAVE_HISTORY_DELAY := 0
global CRM_ADD_APPOINTMENT_DELAY := 0
global CRM_FOCUS_DATE_DELAY := 0
global CRM_FINAL_SAVE_DELAY := 0

#Include domain\lead_normalizer.ahk
#Include domain\lead_parser.ahk
#Include domain\advisor_quote_db.ahk
#Include domain\pricing_rules.ahk
#Include domain\date_rules.ahk
#Include domain\batch_rules.ahk
#Include domain\message_templates.ahk

#Include adapters\clipboard_adapter.ahk
#Include adapters\browser_focus_adapter.ahk
#Include adapters\devtools_bridge.ahk
#Include adapters\quo_adapter.ahk
#Include adapters\crm_adapter.ahk
#Include adapters\tag_selector_adapter.ahk

#Include workflows\advisor_quote_workflow.ahk

ExitApp(0)
