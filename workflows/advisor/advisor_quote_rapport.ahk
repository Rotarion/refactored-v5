; Advisor quote RAPPORT helpers.
; Extracted mechanically from workflows/advisor_quote_workflow.ahk.

AdvisorQuoteStateRapport(profile, db, attempt := 1, entryScanPath := "") {
    AdvisorQuoteSetStep("RAPPORT", "Filling Gather Data and lead vehicles.")
    state := AdvisorQuoteDetectState(db)
    if AdvisorQuoteIsStateInList(state, ["SELECT_PRODUCT", "ASC_PRODUCT", "INCIDENTS"])
        return AdvisorQuoteResultOkValue("RAPPORT", "RAPPORT", "Rapport stage already satisfied.", entryScanPath, state)

    failureReason := ""
    failureScan := ""
    if !AdvisorQuoteHandleGatherData(profile, db, &failureReason, &failureScan) {
        if (failureScan = "")
            failureScan := AdvisorQuoteScanCurrentPage("RAPPORT", "gather-data-failed")
        if (failureReason = "")
            failureReason := "Gather Data stage did not complete."
        return AdvisorQuoteResultFail("RAPPORT", "RAPPORT", failureReason, true, failureScan, AdvisorQuoteDetectState(db))
    }
    return AdvisorQuoteResultOkValue("RAPPORT", "RAPPORT", "Gather Data completed.", entryScanPath, AdvisorQuoteDetectState(db))
}

AdvisorQuoteGetGatherRapportSnapshot() {
    status := AdvisorQuoteParseKeyValueLines(AdvisorQuoteRunOp("gather_rapport_snapshot", AdvisorQuoteSnapshotArgs(), 2, 120))
    AdvisorQuoteAppendLog("GATHER_RAPPORT_SNAPSHOT", AdvisorQuoteGetLastStep(), AdvisorQuoteBuildGatherRapportSnapshotDetail(status))
    return status
}

AdvisorQuoteBuildGatherRapportSnapshotDetail(status) {
    return "result=" AdvisorQuoteStatusValue(status, "result")
        . ", routeFamily=" AdvisorQuoteStatusValue(status, "routeFamily")
        . ", activeModalType=" AdvisorQuoteStatusValue(status, "activeModalType")
        . ", activePanelType=" AdvisorQuoteStatusValue(status, "activePanelType")
        . ", saveGate=" AdvisorQuoteStatusValue(status, "saveGate")
        . ", vehicleWarningPresent=" AdvisorQuoteStatusValue(status, "vehicleWarningPresent")
        . ", confirmedVehicleCount=" AdvisorQuoteStatusValue(status, "confirmedVehicleCount")
        . ", potentialVehicleCount=" AdvisorQuoteStatusValue(status, "potentialVehicleCount")
        . ", editVehiclePanelPresent=" AdvisorQuoteStatusValue(status, "editVehiclePanelPresent")
        . ", editVehicleStatus=" AdvisorQuoteStatusValue(status, "editVehicleStatus")
        . ", editVehicleUpdatePresent=" AdvisorQuoteStatusValue(status, "editVehicleUpdatePresent")
        . ", editVehicleUpdateEnabled=" AdvisorQuoteStatusValue(status, "editVehicleUpdateEnabled")
        . ", editVehicleRequiredComplete=" AdvisorQuoteStatusValue(status, "editVehicleRequiredComplete")
        . ", staleAddRowPresent=" AdvisorQuoteStatusValue(status, "staleAddRowPresent")
        . ", startQuotingSectionPresent=" AdvisorQuoteStatusValue(status, "startQuotingSectionPresent")
        . ", createQuotesEnabled=" AdvisorQuoteStatusValue(status, "createQuotesEnabled")
        . ", blockerCode=" AdvisorQuoteStatusValue(status, "blockerCode")
        . ", nextRecommendedReadOnlyStatus=" AdvisorQuoteStatusValue(status, "nextRecommendedReadOnlyStatus")
        . ", evidence=" AdvisorQuoteStatusValue(status, "evidence")
        . ", missing=" AdvisorQuoteStatusValue(status, "missing")
}

AdvisorQuoteBuildRapportSnapshotRouteDetail(snapshot, attemptCount, routedToEditVehicle := "0", afterResult := "") {
    return "rapportSnapshotActiveModalType=" AdvisorQuoteStatusValue(snapshot, "activeModalType")
        . ", rapportSnapshotActivePanelType=" AdvisorQuoteStatusValue(snapshot, "activePanelType")
        . ", rapportSnapshotBlockerCode=" AdvisorQuoteStatusValue(snapshot, "blockerCode")
        . ", rapportSnapshotEditUpdateEnabled=" AdvisorQuoteStatusValue(snapshot, "editVehicleUpdateEnabled")
        . ", rapportSnapshotRoutedToEditVehicle=" routedToEditVehicle
        . ", rapportSnapshotAfterEditResult=" afterResult
        . ", rapportSnapshotRouteAttemptCount=" attemptCount
        . ", editVehiclePanelPresent=" AdvisorQuoteStatusValue(snapshot, "editVehiclePanelPresent")
        . ", editVehicleStatus=" AdvisorQuoteStatusValue(snapshot, "editVehicleStatus")
        . ", editVehicleYear=" AdvisorQuoteStatusValue(snapshot, "editVehicleYear")
        . ", editVehicleMake=" AdvisorQuoteStatusValue(snapshot, "editVehicleMake")
        . ", editVehicleModel=" AdvisorQuoteStatusValue(snapshot, "editVehicleModel")
}

AdvisorQuoteGatherSnapshotHasStaleAddVehicleRowBlocker(snapshot) {
    activeModalType := AdvisorQuoteStatusValue(snapshot, "activeModalType")
    activePanelType := AdvisorQuoteStatusValue(snapshot, "activePanelType")
    blockerCode := AdvisorQuoteStatusValue(snapshot, "blockerCode")
    return blockerCode = "GATHER_STALE_ADD_VEHICLE_ROW_OPEN"
        || activeModalType = "GATHER_STALE_ADD_VEHICLE_ROW"
        || activePanelType = "GATHER_STALE_ADD_VEHICLE_ROW"
}

AdvisorQuoteGatherStaleBlockerActiveScopeSafe(snapshot) {
    activeModalType := AdvisorQuoteStatusValue(snapshot, "activeModalType")
    activePanelType := AdvisorQuoteStatusValue(snapshot, "activePanelType")
    modalSafe := activeModalType = "" || activeModalType = "NONE" || activeModalType = "GATHER_STALE_ADD_VEHICLE_ROW"
    panelSafe := activePanelType = "" || activePanelType = "NONE" || activePanelType = "GATHER_STALE_ADD_VEHICLE_ROW"
    return modalSafe && panelSafe
}

AdvisorQuoteGatherStaleAddRowStatusSafeForCancel(status, snapshot, &unsafeReason := "") {
    unsafeReason := ""
    result := AdvisorQuoteStatusValue(status, "result")
    safeResult := result = "FOUND" || result = "OK" || result = "READY"
    if !safeResult {
        unsafeReason := "status-not-ready:" result
        return false
    }
    if !AdvisorQuoteGatherStaleBlockerActiveScopeSafe(snapshot) {
        unsafeReason := "unknown-active-modal-or-panel"
        return false
    }
    if (AdvisorQuoteStatusValue(snapshot, "editVehiclePanelPresent") = "1"
        || AdvisorQuoteStatusValue(snapshot, "activeModalType") = "GATHER_EDIT_VEHICLE"
        || AdvisorQuoteStatusValue(snapshot, "activePanelType") = "GATHER_EDIT_VEHICLE") {
        unsafeReason := "edit-vehicle-panel-active"
        return false
    }
    if (AdvisorQuoteStatusValue(status, "rowIncomplete") != "1") {
        unsafeReason := "row-not-incomplete"
        return false
    }
    if (StrLower(AdvisorQuoteStatusValue(status, "rowTitle")) != "add car or truck") {
        unsafeReason := "not-gather-add-car-truck-row"
        return false
    }
    if (AdvisorQuoteStatusValue(status, "cancelButtonScoped") != "1") {
        unsafeReason := "cancel-button-not-scoped"
        return false
    }
    if (AdvisorQuoteStatusValue(status, "safeToCancel") != "1") {
        unsafeReason := "operator-unsafe:" AdvisorQuoteStatusValue(status, "reason")
        return false
    }
    return true
}

AdvisorQuoteRapportSubModelPlaceholderFallbackEnabled(db) {
    if !(IsObject(db) && db.Has("defaults") && IsObject(db["defaults"]))
        return true
    if !db["defaults"].Has("rapportAllowSubModelPlaceholderFallback")
        return true
    value := Trim(String(db["defaults"]["rapportAllowSubModelPlaceholderFallback"]))
    return !(StrLower(value) = "false" || value = "0" || StrLower(value) = "no")
}

AdvisorQuoteRapportSubModelFallbackMode(db) {
    mode := ""
    if (IsObject(db) && db.Has("defaults") && IsObject(db["defaults"]) && db["defaults"].Has("rapportSubModelFallbackMode"))
        mode := Trim(String(db["defaults"]["rapportSubModelFallbackMode"]))
    return mode = "first-valid" ? mode : "first-valid"
}

AdvisorQuoteRapportModelPlaceholderFallbackEnabled(db) {
    if !(IsObject(db) && db.Has("defaults") && IsObject(db["defaults"]))
        return true
    if !db["defaults"].Has("rapportAllowModelPlaceholderFallback")
        return true
    value := Trim(String(db["defaults"]["rapportAllowModelPlaceholderFallback"]))
    return !(StrLower(value) = "false" || value = "0" || StrLower(value) = "no")
}

AdvisorQuoteRapportModelFallbackMode(db) {
    mode := ""
    if (IsObject(db) && db.Has("defaults") && IsObject(db["defaults"]) && db["defaults"].Has("rapportModelFallbackMode"))
        mode := Trim(String(db["defaults"]["rapportModelFallbackMode"]))
    return mode = "first-valid-same-make" ? mode : "first-valid-same-make"
}

AdvisorQuoteGatherStaleAddRowStatusResumeableForSubModelFallback(status, snapshot, &unsafeReason := "") {
    unsafeReason := ""
    result := AdvisorQuoteStatusValue(status, "result")
    if (result != "FOUND") {
        unsafeReason := "status-not-readable:" result
        return false
    }
    if !AdvisorQuoteGatherSnapshotHasStaleAddVehicleRowBlocker(snapshot) {
        unsafeReason := "stale-add-row-blocker-not-active"
        return false
    }
    if (AdvisorQuoteStatusValue(snapshot, "staleAddRowPresent") != "1") {
        unsafeReason := "stale-add-row-not-present"
        return false
    }
    if !AdvisorQuoteGatherStaleBlockerActiveScopeSafe(snapshot) {
        unsafeReason := "unknown-active-modal-or-panel"
        return false
    }
    if (AdvisorQuoteStatusValue(snapshot, "editVehiclePanelPresent") = "1"
        || AdvisorQuoteStatusValue(snapshot, "activeModalType") = "GATHER_EDIT_VEHICLE"
        || AdvisorQuoteStatusValue(snapshot, "activePanelType") = "GATHER_EDIT_VEHICLE") {
        unsafeReason := "edit-vehicle-panel-active"
        return false
    }
    if (AdvisorQuoteStatusValue(status, "unsafeContext") = "1") {
        unsafeReason := "confirmed-or-potential-vehicle-context"
        return false
    }
    if (AdvisorQuoteStatusValue(status, "rowIncomplete") != "1") {
        unsafeReason := "row-not-incomplete"
        return false
    }
    if !AdvisorQuoteStatusFieldPresent(status, "yearValue", "yearPresent") {
        unsafeReason := "year-missing"
        return false
    }
    if !AdvisorQuoteStatusFieldPresent(status, "manufacturerValue", "manufacturerPresent") {
        unsafeReason := "manufacturer-missing"
        return false
    }
    if !AdvisorQuoteStatusFieldPresent(status, "modelValue", "modelPresent") {
        unsafeReason := "model-missing"
        return false
    }
    if (AdvisorQuoteStatusValue(status, "subModelPresent") != "1") {
        unsafeReason := "submodel-missing"
        return false
    }
    if (AdvisorQuoteStatusValue(status, "subModelPlaceholderSelected") != "1") {
        unsafeReason := "submodel-already-selected"
        return false
    }
    if (AdvisorQuoteStatusInteger(status, "subModelOptionCount") < 1
        || AdvisorQuoteStatusValue(status, "subModelFirstValidOptionPresent") != "1") {
        unsafeReason := "submodel-no-options"
        return false
    }
    if (AdvisorQuoteStatusValue(status, "addButtonPresent") != "1") {
        unsafeReason := "add-button-missing"
        return false
    }
    if (AdvisorQuoteStatusValue(status, "addButtonEnabled") != "1") {
        unsafeReason := "add-button-disabled"
        return false
    }
    return true
}

AdvisorQuoteBuildGatherStaleVehicleRowSafetyDetail(status, snapshot) {
    return "result=" AdvisorQuoteStatusValue(status, "result")
        . ", rowIndex=" AdvisorQuoteStatusValue(status, "rowIndex")
        . ", rowTitle=" AdvisorQuoteStatusValue(status, "rowTitle")
        . ", rowIncomplete=" AdvisorQuoteStatusValue(status, "rowIncomplete")
        . ", yearPresent=" (AdvisorQuoteStatusValue(status, "yearValue") != "" ? "1" : "0")
        . ", manufacturerPresent=" (AdvisorQuoteStatusValue(status, "manufacturerValue") != "" ? "1" : "0")
        . ", modelPresent=" (AdvisorQuoteStatusValue(status, "modelValue") != "" ? "1" : "0")
        . ", subModelPresent=" AdvisorQuoteStatusValue(status, "subModelPresent")
        . ", subModelPlaceholderSelected=" AdvisorQuoteStatusValue(status, "subModelPlaceholderSelected")
        . ", subModelOptionCount=" AdvisorQuoteStatusValue(status, "subModelOptionCount")
        . ", subModelFirstValidOptionPresent=" AdvisorQuoteStatusValue(status, "subModelFirstValidOptionPresent")
        . ", addButtonPresent=" AdvisorQuoteStatusValue(status, "addButtonPresent")
        . ", addButtonEnabled=" AdvisorQuoteStatusValue(status, "addButtonEnabled")
        . ", cancelButtonPresent=" AdvisorQuoteStatusValue(status, "cancelButtonPresent")
        . ", cancelButtonScoped=" AdvisorQuoteStatusValue(status, "cancelButtonScoped")
        . ", unsafeContext=" AdvisorQuoteStatusValue(status, "unsafeContext")
        . ", safeToCancel=" AdvisorQuoteStatusValue(status, "safeToCancel")
        . ", reason=" AdvisorQuoteStatusValue(status, "reason")
        . ", activeModalType=" AdvisorQuoteStatusValue(snapshot, "activeModalType")
        . ", activePanelType=" AdvisorQuoteStatusValue(snapshot, "activePanelType")
        . ", blockerCode=" AdvisorQuoteStatusValue(snapshot, "blockerCode")
        . ", editVehiclePanelPresent=" AdvisorQuoteStatusValue(snapshot, "editVehiclePanelPresent")
        . ", staleAddRowPresent=" AdvisorQuoteStatusValue(snapshot, "staleAddRowPresent")
        . ", missing=" AdvisorQuoteStatusValue(status, "missing")
}

AdvisorQuoteBuildGatherAddRowSubModelSelectDetail(status) {
    return "result=" AdvisorQuoteStatusValue(status, "result")
        . ", selectedIndex=" AdvisorQuoteStatusValue(status, "selectedIndex")
        . ", selectedValuePresent=" AdvisorQuoteStatusValue(status, "selectedValuePresent")
        . ", selectedMode=" AdvisorQuoteStatusValue(status, "selectedMode")
        . ", optionCount=" AdvisorQuoteStatusValue(status, "optionCount")
        . ", addButtonPresent=" AdvisorQuoteStatusValue(status, "addButtonPresent")
        . ", addButtonEnabled=" AdvisorQuoteStatusValue(status, "addButtonEnabled")
}

AdvisorQuoteBuildGatherAddRowAddClickDetail(status) {
    return "result=" AdvisorQuoteStatusValue(status, "result")
        . ", rowIndex=" AdvisorQuoteStatusValue(status, "rowIndex")
        . ", clicked=" AdvisorQuoteStatusValue(status, "clicked")
        . ", addButtonPresent=" AdvisorQuoteStatusValue(status, "addButtonPresent")
        . ", addButtonEnabled=" AdvisorQuoteStatusValue(status, "addButtonEnabled")
}

AdvisorQuoteBuildGatherStaleVehicleCancelSafetyDetail(status) {
    return "result=" AdvisorQuoteStatusValue(status, "result")
        . ", rowIndex=" AdvisorQuoteStatusValue(status, "rowIndex")
        . ", clicked=" AdvisorQuoteStatusValue(status, "clicked")
        . ", afterRowPresent=" AdvisorQuoteStatusValue(status, "afterRowPresent")
        . ", failedFields=" AdvisorQuoteStatusValue(status, "failedFields")
        . ", evidence=" AdvisorQuoteStatusValue(status, "evidence")
}

AdvisorQuoteFindGatherEditVehicleForSnapshot(snapshot, actionableVehicles) {
    if !IsObject(actionableVehicles)
        return ""
    year := AdvisorQuoteStatusValue(snapshot, "editVehicleYear")
    make := AdvisorQuoteStatusValue(snapshot, "editVehicleMake")
    model := AdvisorQuoteStatusValue(snapshot, "editVehicleModel")
    if (year = "" || make = "" || model = "")
        return ""

    targetMake := AdvisorVehicleNormalizeMake(make)
    targetModelKey := AdvisorVehicleDbNormalizeModelKey(model)
    matches := []
    for _, vehicle in actionableVehicles {
        vehicleYear := IsObject(vehicle) && vehicle.Has("year") ? Trim(String(vehicle["year"])) : ""
        vehicleMake := IsObject(vehicle) && vehicle.Has("make") ? AdvisorVehicleNormalizeMake(vehicle["make"]) : ""
        vehicleModel := IsObject(vehicle) && vehicle.Has("model") ? AdvisorVehicleDbNormalizeModelKey(vehicle["model"]) : ""
        if (vehicleYear = year && vehicleMake = targetMake && vehicleModel = targetModelKey)
            matches.Push(vehicle)
    }
    return (matches.Length = 1) ? matches[1] : ""
}

AdvisorQuoteResolveGatherSnapshotBlockers(actionableVehicles, db, &failureReason := "", &failureScanPath := "") {
    failureReason := ""
    failureScanPath := ""
    staleCancelRows := Map()
    Loop 2 {
        snapshot := AdvisorQuoteGetGatherRapportSnapshot()
        activeModalType := AdvisorQuoteStatusValue(snapshot, "activeModalType")
        blockerCode := AdvisorQuoteStatusValue(snapshot, "blockerCode")
        updateEnabled := AdvisorQuoteStatusValue(snapshot, "editVehicleUpdateEnabled")
        AdvisorQuoteAppendLog(
            "RAPPORT_SNAPSHOT_GATE",
            AdvisorQuoteGetLastStep(),
            AdvisorQuoteBuildRapportSnapshotRouteDetail(snapshot, A_Index, "0")
        )

        if (AdvisorQuoteStatusValue(snapshot, "result") != "OK") {
            failureReason := "RAPPORT_SNAPSHOT_UNREADABLE: " AdvisorQuoteBuildGatherRapportSnapshotDetail(snapshot)
            failureScanPath := AdvisorQuoteScanCurrentPage("RAPPORT", "rapport-snapshot-unreadable")
            return false
        }
        if AdvisorQuoteGatherSnapshotHasStaleAddVehicleRowBlocker(snapshot) {
            if AdvisorQuoteRapportSnapshotHasPotentialVinBackedVehicle(snapshot) {
                AdvisorQuoteAppendLog(
                    "RAPPORT_STALE_ROW_DEFERRED_FOR_PUBLIC_RECORD_CONFIRMATION",
                    AdvisorQuoteGetLastStep(),
                    AdvisorQuoteBuildRapportSnapshotRouteDetail(snapshot, A_Index, "0")
                        . ", potentialVehicleCount=" AdvisorQuoteStatusValue(snapshot, "potentialVehicleCount")
                        . ", staleAddRowPresent=" AdvisorQuoteStatusValue(snapshot, "staleAddRowPresent")
                )
                return true
            }
            staleStatus := AdvisorQuoteGetGatherStaleAddVehicleRowStatus(true)
            AdvisorQuoteAppendLog(
                "RAPPORT_STALE_ADD_ROW_STATUS",
                AdvisorQuoteGetLastStep(),
                AdvisorQuoteBuildGatherStaleVehicleRowSafetyDetail(staleStatus, snapshot)
            )
            resumeUnsafeReason := ""
            if AdvisorQuoteGatherStaleAddRowStatusResumeableForSubModelFallback(staleStatus, snapshot, &resumeUnsafeReason) {
                if !AdvisorQuoteRapportSubModelPlaceholderFallbackEnabled(db) {
                    failureReason := "RAPPORT_ADD_ROW_SUBMODEL_FALLBACK_DISABLED: "
                        . AdvisorQuoteBuildGatherStaleVehicleRowSafetyDetail(staleStatus, snapshot)
                    failureScanPath := AdvisorQuoteScanCurrentPage("RAPPORT", "rapport-add-row-submodel-fallback-disabled")
                    return false
                }

                selectStatus := AdvisorQuoteSelectGatherAddRowFirstValidSubModel(true)
                AdvisorQuoteAppendLog(
                    "RAPPORT_ADD_ROW_SUBMODEL_PLACEHOLDER_SELECTED",
                    AdvisorQuoteGetLastStep(),
                    AdvisorQuoteBuildGatherAddRowSubModelSelectDetail(selectStatus)
                        . ", fallbackMode=" AdvisorQuoteRapportSubModelFallbackMode(db)
                )
                if (AdvisorQuoteStatusValue(selectStatus, "result") = "NO_OPTIONS") {
                    failureReason := "RAPPORT_ADD_ROW_SUBMODEL_NO_OPTIONS: " AdvisorQuoteBuildGatherAddRowSubModelSelectDetail(selectStatus)
                    failureScanPath := AdvisorQuoteScanCurrentPage("RAPPORT", "rapport-add-row-submodel-no-options")
                    return false
                }
                if (AdvisorQuoteStatusValue(selectStatus, "result") != "OK"
                    || AdvisorQuoteStatusValue(selectStatus, "selectedValuePresent") != "1") {
                    failureReason := "RAPPORT_ADD_ROW_SUBMODEL_SELECT_FAILED: " AdvisorQuoteBuildGatherAddRowSubModelSelectDetail(selectStatus)
                    failureScanPath := AdvisorQuoteScanCurrentPage("RAPPORT", "rapport-add-row-submodel-select-failed")
                    return false
                }

                afterSelectStatus := AdvisorQuoteGetGatherStaleAddVehicleRowStatus(true)
                AdvisorQuoteAppendLog(
                    "RAPPORT_ADD_ROW_AFTER_SUBMODEL_STATUS",
                    AdvisorQuoteGetLastStep(),
                    AdvisorQuoteBuildGatherStaleVehicleRowSafetyDetail(afterSelectStatus, snapshot)
                )
                if (AdvisorQuoteStatusValue(afterSelectStatus, "subModelPlaceholderSelected") = "1") {
                    failureReason := "RAPPORT_ADD_ROW_SUBMODEL_SELECT_FAILED: subModel remained placeholder. "
                        . AdvisorQuoteBuildGatherStaleVehicleRowSafetyDetail(afterSelectStatus, snapshot)
                    failureScanPath := AdvisorQuoteScanCurrentPage("RAPPORT", "rapport-add-row-submodel-select-verify-failed")
                    return false
                }
                if (AdvisorQuoteStatusValue(afterSelectStatus, "addButtonPresent") != "1"
                    || AdvisorQuoteStatusValue(afterSelectStatus, "addButtonEnabled") != "1") {
                    failureReason := "RAPPORT_ADD_ROW_ADD_BUTTON_DISABLED: "
                        . AdvisorQuoteBuildGatherStaleVehicleRowSafetyDetail(afterSelectStatus, snapshot)
                    failureScanPath := AdvisorQuoteScanCurrentPage("RAPPORT", "rapport-add-row-add-button-disabled")
                    return false
                }

                addStatus := AdvisorQuoteClickGatherAddRowAddButton(true)
                AdvisorQuoteAppendLog(
                    "RAPPORT_ADD_ROW_ADD_CLICKED",
                    AdvisorQuoteGetLastStep(),
                    AdvisorQuoteBuildGatherAddRowAddClickDetail(addStatus)
                )
                if (AdvisorQuoteStatusValue(addStatus, "result") != "CLICKED"
                    || AdvisorQuoteStatusValue(addStatus, "clicked") != "1") {
                    failureReason := "RAPPORT_ADD_ROW_ADD_BUTTON_DISABLED: " AdvisorQuoteBuildGatherAddRowAddClickDetail(addStatus)
                    failureScanPath := AdvisorQuoteScanCurrentPage("RAPPORT", "rapport-add-row-add-click-failed")
                    return false
                }

                afterSnapshot := AdvisorQuoteGetGatherRapportSnapshot()
                afterResult := AdvisorQuoteStatusValue(afterSnapshot, "result")
                afterEditOpen := AdvisorQuoteStatusValue(afterSnapshot, "activeModalType") = "GATHER_EDIT_VEHICLE"
                    || AdvisorQuoteStatusValue(afterSnapshot, "activePanelType") = "GATHER_EDIT_VEHICLE"
                    || AdvisorQuoteStatusValue(afterSnapshot, "editVehiclePanelPresent") = "1"
                afterRowClosed := AdvisorQuoteStatusValue(afterSnapshot, "staleAddRowPresent") != "1"
                    || !AdvisorQuoteGatherSnapshotHasStaleAddVehicleRowBlocker(afterSnapshot)
                afterCountsChanged := AdvisorQuoteStatusValue(afterSnapshot, "confirmedVehicleCount") != AdvisorQuoteStatusValue(snapshot, "confirmedVehicleCount")
                    || AdvisorQuoteStatusValue(afterSnapshot, "potentialVehicleCount") != AdvisorQuoteStatusValue(snapshot, "potentialVehicleCount")
                afterGateChanged := AdvisorQuoteStatusValue(afterSnapshot, "vehicleWarningPresent") != AdvisorQuoteStatusValue(snapshot, "vehicleWarningPresent")
                    || AdvisorQuoteStatusValue(afterSnapshot, "startQuotingSectionPresent") != AdvisorQuoteStatusValue(snapshot, "startQuotingSectionPresent")
                    || AdvisorQuoteStatusValue(afterSnapshot, "createQuotesEnabled") != AdvisorQuoteStatusValue(snapshot, "createQuotesEnabled")
                    || AdvisorQuoteStatusValue(afterSnapshot, "blockerCode") != AdvisorQuoteStatusValue(snapshot, "blockerCode")
                AdvisorQuoteAppendLog(
                    "RAPPORT_ADD_ROW_REENTERING_VALIDATION_FLOW",
                    AdvisorQuoteGetLastStep(),
                    AdvisorQuoteBuildRapportSnapshotRouteDetail(afterSnapshot, A_Index, afterEditOpen ? "1" : "0", afterResult)
                        . ", addRowClosed=" (afterRowClosed ? "1" : "0")
                        . ", countsChanged=" (afterCountsChanged ? "1" : "0")
                        . ", gateChanged=" (afterGateChanged ? "1" : "0")
                )
                if (afterResult != "OK" || !(afterRowClosed || afterEditOpen || afterCountsChanged || afterGateChanged)) {
                    failureReason := "RAPPORT_ADD_ROW_ADD_VERIFY_FAILED: " AdvisorQuoteBuildGatherRapportSnapshotDetail(afterSnapshot)
                    failureScanPath := AdvisorQuoteScanCurrentPage("RAPPORT", "rapport-add-row-add-verify-failed")
                    return false
                }
                if afterEditOpen {
                    vehicle := AdvisorQuoteFindGatherEditVehicleForSnapshot(afterSnapshot, actionableVehicles)
                    if !IsObject(vehicle) {
                        failureReason := "GATHER_EDIT_VEHICLE_NO_MATCHING_LEAD_VEHICLE: active Edit Vehicle panel could not be matched to exactly one actionable lead vehicle. " AdvisorQuoteBuildRapportSnapshotRouteDetail(afterSnapshot, A_Index, "1")
                        failureScanPath := AdvisorQuoteScanCurrentPage("RAPPORT", "gather-edit-vehicle-no-matching-lead")
                        return false
                    }
                    editFailureReason := ""
                    editFailureScanPath := ""
                    editOutcome := AdvisorQuoteCompleteVehicleEditModalIfPresent(vehicle, db, &editFailureReason, &editFailureScanPath, "snapshot-gate-after-add-row")
                    finalSnapshot := AdvisorQuoteGetGatherRapportSnapshot()
                    AdvisorQuoteAppendLog(
                        "RAPPORT_SNAPSHOT_EDIT_ROUTE_RESULT",
                        AdvisorQuoteGetLastStep(),
                        AdvisorQuoteBuildRapportSnapshotRouteDetail(afterSnapshot, A_Index, "1", AdvisorQuoteStatusValue(finalSnapshot, "result"))
                            . ", routedVehicle=" AdvisorQuoteVehicleLabel(vehicle)
                            . ", editOutcome=" editOutcome
                            . ", rapportSnapshotAfterActiveModalType=" AdvisorQuoteStatusValue(finalSnapshot, "activeModalType")
                            . ", rapportSnapshotAfterBlockerCode=" AdvisorQuoteStatusValue(finalSnapshot, "blockerCode")
                            . ", rapportSnapshotAfterEditUpdateEnabled=" AdvisorQuoteStatusValue(finalSnapshot, "editVehicleUpdateEnabled")
                    )
                    if (editOutcome = "FAILED") {
                        failureReason := editFailureReason
                        failureScanPath := editFailureScanPath
                        if (failureReason = "")
                            failureReason := "GATHER_EDIT_VEHICLE_SNAPSHOT_ROUTE_FAILED"
                        if (failureScanPath = "")
                            failureScanPath := AdvisorQuoteScanCurrentPage("RAPPORT", "gather-edit-vehicle-snapshot-route-failed")
                        return false
                    }
                }
                return true
            }

            if (resumeUnsafeReason = "submodel-no-options") {
                failureReason := "RAPPORT_ADD_ROW_SUBMODEL_NO_OPTIONS: " AdvisorQuoteBuildGatherStaleVehicleRowSafetyDetail(staleStatus, snapshot)
                failureScanPath := AdvisorQuoteScanCurrentPage("RAPPORT", "rapport-add-row-submodel-no-options")
                return false
            }
            if (resumeUnsafeReason = "add-button-disabled") {
                failureReason := "RAPPORT_ADD_ROW_ADD_BUTTON_DISABLED: " AdvisorQuoteBuildGatherStaleVehicleRowSafetyDetail(staleStatus, snapshot)
                failureScanPath := AdvisorQuoteScanCurrentPage("RAPPORT", "rapport-add-row-add-button-disabled")
                return false
            }

            cancelUnsafeReason := ""
            rowEmptyForCancel := AdvisorQuoteStatusValue(staleStatus, "yearValue") = ""
                && AdvisorQuoteStatusValue(staleStatus, "vinValue") = ""
                && AdvisorQuoteStatusValue(staleStatus, "manufacturerValue") = ""
                && AdvisorQuoteStatusValue(staleStatus, "modelValue") = ""
                && AdvisorQuoteStatusValue(staleStatus, "subModelValue") = ""
            if !(rowEmptyForCancel && AdvisorQuoteGatherStaleAddRowStatusSafeForCancel(staleStatus, snapshot, &cancelUnsafeReason)) {
                failureReason := "RAPPORT_STALE_ADD_ROW_UNSAFE: " resumeUnsafeReason
                    . ". " AdvisorQuoteBuildGatherStaleVehicleRowSafetyDetail(staleStatus, snapshot)
                failureScanPath := AdvisorQuoteScanCurrentPage("RAPPORT", "rapport-stale-add-row-unsafe")
                return false
            }

            staleCancelKey := AdvisorQuoteStatusValue(staleStatus, "rowIndex")
            if (staleCancelKey != "" && staleCancelRows.Has(staleCancelKey)) {
                failureReason := "RAPPORT_STALE_ADD_ROW_CANCEL_LOOP_GUARD: repeated rowIndex=" staleCancelKey
                failureScanPath := AdvisorQuoteScanCurrentPage("RAPPORT", "rapport-stale-add-row-cancel-loop-guard")
                return false
            }
            if (staleCancelKey != "")
                staleCancelRows[staleCancelKey] := true
            cancelStatus := AdvisorQuoteCancelStaleAddVehicleRow(true)
            AdvisorQuoteAppendLog(
                "RAPPORT_STALE_ADD_ROW_CANCEL",
                AdvisorQuoteGetLastStep(),
                AdvisorQuoteBuildGatherStaleVehicleCancelSafetyDetail(cancelStatus)
            )
            if (AdvisorQuoteStatusValue(cancelStatus, "result") != "CANCELLED") {
                failureReason := "RAPPORT_STALE_ADD_ROW_CANCEL_FAILED: "
                    . AdvisorQuoteBuildGatherStaleVehicleCancelSafetyDetail(cancelStatus)
                failureScanPath := AdvisorQuoteScanCurrentPage("RAPPORT", "rapport-stale-add-row-cancel-failed")
                return false
            }

            afterSnapshot := AdvisorQuoteGetGatherRapportSnapshot()
            afterResult := AdvisorQuoteStatusValue(afterSnapshot, "result")
            AdvisorQuoteAppendLog(
                "RAPPORT_STALE_ADD_ROW_CANCEL_VERIFY",
                AdvisorQuoteGetLastStep(),
                AdvisorQuoteBuildRapportSnapshotRouteDetail(afterSnapshot, A_Index, "0", afterResult)
                    . ", staleAddRowPresent=" AdvisorQuoteStatusValue(afterSnapshot, "staleAddRowPresent")
            )
            if (afterResult != "OK") {
                failureReason := "RAPPORT_STALE_ADD_ROW_CANCEL_VERIFY_UNREADABLE: "
                    . AdvisorQuoteBuildGatherRapportSnapshotDetail(afterSnapshot)
                failureScanPath := AdvisorQuoteScanCurrentPage("RAPPORT", "rapport-stale-add-row-cancel-verify-unreadable")
                return false
            }
            if (AdvisorQuoteStatusValue(afterSnapshot, "staleAddRowPresent") = "1"
                && AdvisorQuoteGatherSnapshotHasStaleAddVehicleRowBlocker(afterSnapshot)) {
                failureReason := "RAPPORT_STALE_ADD_ROW_CANCEL_VERIFY_FAILED: "
                    . AdvisorQuoteBuildGatherRapportSnapshotDetail(afterSnapshot)
                failureScanPath := AdvisorQuoteScanCurrentPage("RAPPORT", "rapport-stale-add-row-cancel-verify-failed")
                return false
            }
            AdvisorQuoteAppendLog(
                "RAPPORT_STALE_ADD_ROW_CANCELLED",
                AdvisorQuoteGetLastStep(),
                "attemptCount=" A_Index
                    . ", afterActiveModalType=" AdvisorQuoteStatusValue(afterSnapshot, "activeModalType")
                    . ", afterActivePanelType=" AdvisorQuoteStatusValue(afterSnapshot, "activePanelType")
                    . ", afterBlockerCode=" AdvisorQuoteStatusValue(afterSnapshot, "blockerCode")
                    . ", afterStaleAddRowPresent=" AdvisorQuoteStatusValue(afterSnapshot, "staleAddRowPresent")
            )
            return true
        }
        if (activeModalType = "" || activeModalType = "NONE")
            return true

        if (activeModalType != "GATHER_EDIT_VEHICLE") {
            failureReason := "RAPPORT_ACTIVE_BLOCKER_UNHANDLED: activeModalType=" activeModalType ", blockerCode=" blockerCode
            failureScanPath := AdvisorQuoteScanCurrentPage("RAPPORT", "rapport-active-blocker-unhandled")
            AdvisorQuoteAppendLog(
                "RAPPORT_SNAPSHOT_BLOCKER_UNHANDLED",
                AdvisorQuoteGetLastStep(),
                AdvisorQuoteBuildRapportSnapshotRouteDetail(snapshot, A_Index, "0")
            )
            return false
        }

        vehicle := AdvisorQuoteFindGatherEditVehicleForSnapshot(snapshot, actionableVehicles)
        if !IsObject(vehicle) {
            failureReason := "GATHER_EDIT_VEHICLE_NO_MATCHING_LEAD_VEHICLE: active Edit Vehicle panel could not be matched to exactly one actionable lead vehicle. " AdvisorQuoteBuildRapportSnapshotRouteDetail(snapshot, A_Index, "0")
            failureScanPath := AdvisorQuoteScanCurrentPage("RAPPORT", "gather-edit-vehicle-no-matching-lead")
            return false
        }

        editFailureReason := ""
        editFailureScanPath := ""
        editOutcome := AdvisorQuoteCompleteVehicleEditModalIfPresent(vehicle, db, &editFailureReason, &editFailureScanPath, "snapshot-gate")
        afterSnapshot := AdvisorQuoteGetGatherRapportSnapshot()
        afterActiveModalType := AdvisorQuoteStatusValue(afterSnapshot, "activeModalType")
        afterResult := AdvisorQuoteStatusValue(afterSnapshot, "result")
        AdvisorQuoteAppendLog(
            "RAPPORT_SNAPSHOT_EDIT_ROUTE_RESULT",
            AdvisorQuoteGetLastStep(),
            AdvisorQuoteBuildRapportSnapshotRouteDetail(snapshot, A_Index, "1", afterResult)
                . ", routedVehicle=" AdvisorQuoteVehicleLabel(vehicle)
                . ", editOutcome=" editOutcome
                . ", rapportSnapshotAfterActiveModalType=" afterActiveModalType
                . ", rapportSnapshotAfterBlockerCode=" AdvisorQuoteStatusValue(afterSnapshot, "blockerCode")
                . ", rapportSnapshotAfterEditUpdateEnabled=" AdvisorQuoteStatusValue(afterSnapshot, "editVehicleUpdateEnabled")
        )

        if (editOutcome = "FAILED") {
            failureReason := editFailureReason
            failureScanPath := editFailureScanPath
            if (failureReason = "")
                failureReason := "GATHER_EDIT_VEHICLE_SNAPSHOT_ROUTE_FAILED"
            if (failureScanPath = "")
                failureScanPath := AdvisorQuoteScanCurrentPage("RAPPORT", "gather-edit-vehicle-snapshot-route-failed")
            return false
        }
        if (afterResult = "OK" && afterActiveModalType != "GATHER_EDIT_VEHICLE" && AdvisorQuoteStatusValue(afterSnapshot, "editVehiclePanelPresent") != "1")
            return true
        if !SafeSleep(db["timeouts"]["pollMs"]) {
            failureReason := "GATHER_EDIT_VEHICLE_SNAPSHOT_ROUTE_WAIT_FAILED"
            return false
        }
    }

    failureReason := "GATHER_EDIT_VEHICLE_SNAPSHOT_ROUTE_GUARD: Edit Vehicle panel remained active after two snapshot-routed attempts."
    failureScanPath := AdvisorQuoteScanCurrentPage("RAPPORT", "gather-edit-vehicle-snapshot-route-guard")
    return false
}

AdvisorQuoteHandleGatherData(profile, db, &failureReason := "", &failureScanPath := "") {
    global advisorQuoteProductOverviewAutoPending, advisorQuoteProductOverviewAutoVerified, advisorQuoteGatherAutoCommitted
    failureReason := ""
    failureScanPath := ""

    AdvisorQuoteSetStep("GATHER_DATA", "Waiting for GATHER DATA page.")
    waitArgs := Map("rapportContains", db["urls"]["rapportContains"])
    if !AdvisorQuoteWaitForCondition("gather_data", db["timeouts"]["transitionMs"], db["timeouts"]["pollMs"], waitArgs) {
        failureReason := "Gather Data page did not become ready."
        return false
    }

    if !AdvisorQuoteFillGatherDefaults(profile, db, &failureReason) {
        failureScanPath := AdvisorQuoteScanCurrentPage("RAPPORT", "gather-defaults-failed")
        return false
    }

    vehiclePolicy := AdvisorQuoteClassifyGatherVehicles(profile)
    AdvisorQuoteLogGatherVehiclePolicy(vehiclePolicy)
    actionableVehicles := vehiclePolicy["actionableVehicles"]
    partialYearMakeVehicles := vehiclePolicy["partialYearMakeVehicles"]
    rapportLedger := AdvisorQuoteRapportVehicleLedgerCreate(profile, db)

    if !AdvisorQuoteResolveGatherSnapshotBlockers(actionableVehicles, db, &failureReason, &failureScanPath)
        return false

    if (rapportLedger["rateableCount"] = 0) {
        failureReason := "NO_RATEABLE_VEHICLES"
        AdvisorQuoteAppendLog(
            "RAPPORT_NO_RATEABLE_VEHICLES",
            AdvisorQuoteGetLastStep(),
            "ledger=" AdvisorQuoteRapportVehicleLedgerSummary(rapportLedger)
                . ", vehicleCount=" rapportLedger["items"].Length
        )
        failureScanPath := AdvisorQuoteScanCurrentPage("RAPPORT", "no-actionable-lead-vehicle")
        return false
    }

    vehicleSatisfiedCount := 0
    satisfiedVehicles := []
    promotedPartialVehicles := []
    dbAddedVehicles := []
    deferredRapportVehicles := []
    deferredCompleteVehicles := []
    deferredUnknownVehicles := []
    deferredPartialVehicles := []
    staleDuplicateRowSeen := false
    staleDuplicateRowDetails := ""
    rapportVehicleMode := AdvisorQuoteRapportVehicleMode(db)
    vehicleModeAllowsAddComplete := AdvisorQuoteRapportVehicleModeAllowsAddComplete(rapportVehicleMode)
    AdvisorQuoteAppendLog(
        "RAPPORT_VEHICLE_MODE",
        AdvisorQuoteGetLastStep(),
        "rapportVehicleMode=" rapportVehicleMode
            . ", vehicleModeAllowsAddComplete=" (vehicleModeAllowsAddComplete ? "1" : "0")
    )
    for _, vehicle in actionableVehicles {
        if StopRequested() {
            failureReason := "Stopped manually."
            return false
        }

        AdvisorQuoteSetStep("GATHER_DATA_VEHICLE_CHECK", "Checking vehicle: " vehicle["displayKey"])
        AdvisorQuoteAppendLog(
            "VEHICLE_NORMALIZED",
            AdvisorQuoteGetLastStep(),
            "displayKey=" vehicle["displayKey"]
                . ", year=" vehicle["year"]
                . ", make=" vehicle["make"]
                . ", model=" vehicle["model"]
                . ", trimHint=" vehicle["trimHint"]
        )

        resolvedVehicle := AdvisorVehicleDbResolveLeadVehicle(vehicle["year"], vehicle["make"], vehicle["model"], vehicle.Has("vin") ? vehicle["vin"] : "")
        AdvisorQuoteAppendLog("VEHICLE_DB_RESOLVER", AdvisorQuoteGetLastStep(), AdvisorQuoteBuildVehicleDbResolveDetail(resolvedVehicle, vehicle))
        resolveResult := AdvisorQuoteVehicleDbResolveResult(resolvedVehicle)
        if (resolveResult = "AMBIGUOUS") {
            AdvisorQuoteAppendLog(
                "VEHICLE_DB_CARD_MATCH_AMBIGUOUS",
                AdvisorQuoteGetLastStep(),
                "vehicle=" vehicle["displayKey"] ", " AdvisorQuoteBuildVehicleDbResolveDetail(resolvedVehicle, vehicle)
            )
        } else if (resolveResult != "RESOLVED") {
            AdvisorQuoteAppendLog(
                "VEHICLE_DB_CARD_MATCH_NOT_RESOLVED",
                AdvisorQuoteGetLastStep(),
                "vehicle=" vehicle["displayKey"] ", " AdvisorQuoteBuildVehicleDbResolveDetail(resolvedVehicle, vehicle)
            )
        }

        preflightStatus := AdvisorQuoteGetGatherVehicleAddStatus(vehicle)
        alreadyConfirmed := AdvisorQuoteGatherVehicleStatusAlreadyConfirmed(preflightStatus)
        AdvisorQuoteLogGatherVehicleAddStatus(preflightStatus, "VEHICLE_PREFLIGHT_STATUS", vehicle)
        AdvisorQuoteAppendLog(
            "VEHICLE_PREFLIGHT_DECISION",
            AdvisorQuoteGetLastStep(),
            "vehicle=" vehicle["displayKey"]
                . ", vehiclePreflightStatus=" AdvisorQuoteStatusValue(preflightStatus, "result")
                . ", alreadyConfirmed=" (alreadyConfirmed ? "1" : "0")
                . ", confirmedVehicleMatched=" AdvisorQuoteStatusValue(preflightStatus, "confirmedVehicleMatched")
                . ", confirmedStatusMatched=" AdvisorQuoteStatusValue(preflightStatus, "confirmedStatusMatched")
                . ", matchedText=" AdvisorQuoteStatusValue(preflightStatus, "matchedText")
                . ", skippedBecauseAlreadyConfirmed=" (alreadyConfirmed ? "1" : "0")
        )
        if alreadyConfirmed {
            if AdvisorQuoteGatherVehicleDuplicateAddRowOpen(preflightStatus) {
                staleDuplicateRowSeen := true
                staleDuplicateRowDetails := AdvisorQuoteStatusValue(preflightStatus, "duplicateAddRowDetails")
                AdvisorQuoteAppendLog(
                    "DUPLICATE_ADD_ROW_OPEN_FOR_CONFIRMED_VEHICLE_DEFERRED",
                    AdvisorQuoteGetLastStep(),
                    "vehicle=" vehicle["displayKey"]
                        . ", matchedText=" AdvisorQuoteStatusValue(preflightStatus, "matchedText")
                        . ", duplicateAddRowDetails=" AdvisorQuoteStatusValue(preflightStatus, "duplicateAddRowDetails")
                        . ", cleanupDeferredUntilFinalConfirmedReconciliation=1"
                )
            }
            vehicleSatisfiedCount += 1
            satisfiedVehicles.Push(vehicle)
            AdvisorQuoteRapportVehicleLedgerSetStatus(rapportLedger, vehicle, "CONFIRMED_EXACT", "matched-confirmed-card")
            AdvisorQuoteAppendLog(
                "VEHICLE_ALREADY_CONFIRMED",
                AdvisorQuoteGetLastStep(),
                "vehicle=" vehicle["displayKey"]
                    . ", vehicleSatisfiedCount=" vehicleSatisfiedCount
                    . ", actionableVehicleCount=" actionableVehicles.Length
                    . ", matchedText=" AdvisorQuoteStatusValue(preflightStatus, "matchedText")
            )
            continue
        }

        editOutcome := AdvisorQuoteCompleteVehicleEditModalIfPresent(vehicle, db, &failureReason, &failureScanPath, "preflight")
        if (editOutcome = "CONFIRMED") {
            vehicleSatisfiedCount += 1
            satisfiedVehicles.Push(vehicle)
            AdvisorQuoteRapportVehicleLedgerSetStatus(rapportLedger, vehicle, "CONFIRMED_EXACT", "edit-panel-update")
            continue
        }
        if (editOutcome = "FAILED")
            return false

        legacyListed := AdvisorQuoteVehicleAlreadyListed(vehicle)
        if legacyListed {
            AdvisorQuoteAppendLog(
                "VEHICLE_LEGACY_LISTED_NOT_CONFIRMED",
                AdvisorQuoteGetLastStep(),
                "vehicle=" vehicle["displayKey"] ", alreadyConfirmed=0, actionWillContinue=1"
            )
        }

        if !AdvisorQuoteRapportVehicleLedgerRecordAction(rapportLedger, vehicle, "confirm_potential_vehicle", &failureReason) {
            failureScanPath := AdvisorQuoteScanCurrentPage("RAPPORT", "rapport-vehicle-ledger-loop-guard")
            return false
        }
        confirmOutcome := AdvisorQuoteConfirmPotentialVehicle(vehicle, db, &failureReason, &failureScanPath)
        if (confirmOutcome = "CONFIRMED") {
            vehicleSatisfiedCount += 1
            satisfiedVehicles.Push(vehicle)
            AdvisorQuoteRapportVehicleLedgerSetStatus(rapportLedger, vehicle, "CONFIRMED_POTENTIAL_MATCH", "potential-card")
            continue
        }
        if (confirmOutcome = "FAILED")
            return false
        if (confirmOutcome = "AMBIGUOUS") {
            deferredRapportVehicles.Push(vehicle)
            deferredCompleteVehicles.Push(vehicle)
            AdvisorQuoteRapportVehicleLedgerSetStatus(rapportLedger, vehicle, "DEFERRED_AMBIGUOUS", "potential-card")
            AdvisorQuoteAppendLog(
                "VEHICLE_DEFERRED_AMBIGUOUS_DB_CARD_MATCH",
                AdvisorQuoteGetLastStep(),
                "vehicle=" vehicle["displayKey"] ", source=potential-card"
            )
            continue
        }

        if (resolveResult = "AMBIGUOUS") {
            deferredRapportVehicles.Push(vehicle)
            deferredCompleteVehicles.Push(vehicle)
            AdvisorQuoteRapportVehicleLedgerSetStatus(rapportLedger, vehicle, "DEFERRED_AMBIGUOUS", "db-resolver")
            AdvisorQuoteAppendLog(
                "VEHICLE_DEFERRED_AMBIGUOUS_DB_CARD_MATCH",
                AdvisorQuoteGetLastStep(),
                "vehicle=" vehicle["displayKey"] ", source=db-resolver"
            )
            continue
        }

        if (vehicleModeAllowsAddComplete && resolveResult = "RESOLVED") {
            if !AdvisorQuoteRapportVehicleLedgerRecordAction(rapportLedger, vehicle, "add_db_resolved_vehicle", &failureReason) {
                failureScanPath := AdvisorQuoteScanCurrentPage("RAPPORT", "rapport-vehicle-ledger-loop-guard")
                return false
            }
            addOutcome := AdvisorQuoteAddCompleteDbResolvedVehicle(vehicle, resolvedVehicle, db, &failureReason, &failureScanPath)
            if (addOutcome = "ADDED") {
                vehicleSatisfiedCount += 1
                satisfiedVehicles.Push(vehicle)
                dbAddedVehicles.Push(vehicle)
                AdvisorQuoteRapportVehicleLedgerSetStatus(rapportLedger, vehicle, "ADDED_DB_RESOLVED", "db-resolved-model")
                continue
            }
            if (addOutcome = "FAILED")
                return false
            deferredRapportVehicles.Push(vehicle)
            deferredCompleteVehicles.Push(vehicle)
            AdvisorQuoteRapportVehicleLedgerSetStatus(rapportLedger, vehicle, "SCRAP_MODEL_UNAVAILABLE", "db-add-deferred")
            continue
        }

        if !AdvisorQuoteRapportVehicleLedgerRecordAction(rapportLedger, vehicle, "add_exact_model_vehicle", &failureReason) {
            failureScanPath := AdvisorQuoteScanCurrentPage("RAPPORT", "rapport-vehicle-ledger-loop-guard")
            return false
        }
        if AdvisorQuoteAddVehicleInGatherData(vehicle, db) {
            vehicleSatisfiedCount += 1
            satisfiedVehicles.Push(vehicle)
            AdvisorQuoteRapportVehicleLedgerSetStatus(rapportLedger, vehicle, "ADDED_SUBMODEL_PLACEHOLDER", "EXACT_MODEL")
            continue
        }

        deferredRapportVehicles.Push(vehicle)
        deferredCompleteVehicles.Push(vehicle)
        AdvisorQuoteRapportVehicleLedgerSetStatus(rapportLedger, vehicle, "SCRAP_MODEL_UNAVAILABLE", "exact-model-add-failed")
        AdvisorQuoteAppendLog(
            "VEHICLE_DEFERRED_NO_DB_CARD_MATCH",
            AdvisorQuoteGetLastStep(),
            "vehicle=" vehicle["displayKey"] ", source=exact-model-add, rapportVehicleMode=" rapportVehicleMode
        )
    }

    for _, partialVehicle in partialYearMakeVehicles {
        if StopRequested() {
            failureReason := "Stopped manually."
            return false
        }

        AdvisorQuoteSetStep("GATHER_DATA_PARTIAL_VEHICLE_CHECK", "Checking partial vehicle: " partialVehicle["displayKey"])
        partialStatus := AdvisorQuoteGetGatherPartialVehicleConfirmedStatus(partialVehicle)
        AdvisorQuoteLogGatherVehicleAddStatus(partialStatus, "VEHICLE_PARTIAL_PREFLIGHT_STATUS", partialVehicle)

        if AdvisorQuoteGatherVehiclePartialStatusPromoted(partialStatus) {
            promotedVehicle := AdvisorQuoteBuildGatherPromotedPartialVehicle(partialVehicle, partialStatus)
            if AdvisorQuoteGatherVehicleDuplicateAddRowOpen(partialStatus) {
                staleDuplicateRowSeen := true
                staleDuplicateRowDetails := AdvisorQuoteStatusValue(partialStatus, "duplicateAddRowDetails")
                AdvisorQuoteAppendLog(
                    "DUPLICATE_ADD_ROW_OPEN_FOR_PROMOTED_CONFIRMED_VEHICLE_DEFERRED",
                    AdvisorQuoteGetLastStep(),
                    "vehicle=" partialVehicle["displayKey"]
                        . ", promotedVehicle=" AdvisorQuoteVehicleLabel(promotedVehicle)
                        . ", promotedVehicleText=" AdvisorQuoteStatusValue(partialStatus, "promotedVehicleText")
                        . ", duplicateAddRowDetails=" AdvisorQuoteStatusValue(partialStatus, "duplicateAddRowDetails")
                        . ", cleanupDeferredUntilFinalConfirmedReconciliation=1"
                )
            }
            vehicleSatisfiedCount += 1
            promotedPartialVehicles.Push(promotedVehicle)
            satisfiedVehicles.Push(promotedVehicle)
            AdvisorQuoteRapportVehicleLedgerSetStatus(rapportLedger, partialVehicle, "CONFIRMED_EXACT", "partial-promoted-confirmed-card")
            AdvisorQuoteAppendLog(
                "VEHICLE_PARTIAL_ALREADY_CONFIRMED",
                AdvisorQuoteGetLastStep(),
                "partialVehicle=" partialVehicle["displayKey"]
                    . ", promotedVehicle=" AdvisorQuoteVehicleLabel(promotedVehicle)
                    . ", promotedModel=" AdvisorQuoteStatusValue(partialStatus, "promotedModel")
                    . ", promotedVinEvidence=" AdvisorQuoteStatusValue(partialStatus, "promotedVinEvidence")
                    . ", promotionSource=" AdvisorQuoteStatusValue(partialStatus, "promotionSource")
                    . ", matchedText=" AdvisorQuoteStatusValue(partialStatus, "matchedText")
            )
            continue
        }

        result := AdvisorQuoteStatusValue(partialStatus, "result")
        if (result = "AMBIGUOUS") {
            deferredPartialVehicles.Push(partialVehicle)
            AdvisorQuoteRapportVehicleLedgerSetStatus(rapportLedger, partialVehicle, "DEFERRED_AMBIGUOUS", "partial-card")
            AdvisorQuoteAppendLog(
                "VEHICLE_DEFERRED_AMBIGUOUS_DB_CARD_MATCH",
                AdvisorQuoteGetLastStep(),
                "partialVehicle=" partialVehicle["displayKey"]
                    . ", result=" result
                    . ", candidateCount=" AdvisorQuoteStatusValue(partialStatus, "candidateCount")
                    . ", candidateTexts=" AdvisorQuoteStatusValue(partialStatus, "candidateTexts")
            )
            continue
        }

        if AdvisorQuoteRapportModelPlaceholderFallbackEnabled(db) {
            if !AdvisorQuoteRapportVehicleLedgerRecordAction(rapportLedger, partialVehicle, "add_model_placeholder_vehicle", &failureReason) {
                failureScanPath := AdvisorQuoteScanCurrentPage("RAPPORT", "rapport-vehicle-ledger-loop-guard")
                return false
            }
            addedPlaceholderVehicle := ""
            placeholderOutcome := AdvisorQuoteAddPartialYearMakeVehicleWithModelFallback(partialVehicle, db, &addedPlaceholderVehicle, &failureReason, &failureScanPath)
            switch placeholderOutcome {
                case "ADDED":
                    vehicleSatisfiedCount += 1
                    satisfiedVehicles.Push(addedPlaceholderVehicle)
                    AdvisorQuoteAppendLog(
                        "RAPPORT_MODEL_PLACEHOLDER_TO_REACH_ASC",
                        AdvisorQuoteGetLastStep(),
                        "partialVehicle=" partialVehicle["displayKey"]
                            . ", addedVehicle=" AdvisorQuoteVehicleLabel(addedPlaceholderVehicle)
                            . ", exactModelMatchClaimed=0"
                    )
                    AdvisorQuoteRapportVehicleLedgerSetStatus(rapportLedger, partialVehicle, "ADDED_MODEL_PLACEHOLDER", "MODEL_PLACEHOLDER_FALLBACK")
                    continue
                case "SCRAP_MAKE_UNAVAILABLE":
                    deferredPartialVehicles.Push(partialVehicle)
                    AdvisorQuoteRapportVehicleLedgerSetStatus(rapportLedger, partialVehicle, "SCRAP_MAKE_UNAVAILABLE", "make-option-not-found")
                    continue
                case "SCRAP_MODEL_UNAVAILABLE":
                    deferredPartialVehicles.Push(partialVehicle)
                    AdvisorQuoteRapportVehicleLedgerSetStatus(rapportLedger, partialVehicle, "SCRAP_MODEL_UNAVAILABLE", "model-option-not-found")
                    continue
                case "FAILED_UNSAFE":
                    deferredPartialVehicles.Push(partialVehicle)
                    AdvisorQuoteRapportVehicleLedgerSetStatus(rapportLedger, partialVehicle, "FAILED_UNSAFE", "model-placeholder-add-failed")
                    continue
            }
        }

        deferredPartialVehicles.Push(partialVehicle)
        AdvisorQuoteRapportVehicleLedgerSetStatus(rapportLedger, partialVehicle, "SCRAP_MODEL_UNAVAILABLE", "model-placeholder-disabled")
        AdvisorQuoteAppendLog(
            "VEHICLE_PARTIAL_DEFERRED",
            AdvisorQuoteGetLastStep(),
            "partialVehicle=" partialVehicle["displayKey"]
                . ", result=" result
                . ", failedFields=" AdvisorQuoteStatusValue(partialStatus, "failedFields")
                . ", candidateCount=" AdvisorQuoteStatusValue(partialStatus, "candidateCount")
                . ", candidateTexts=" AdvisorQuoteStatusValue(partialStatus, "candidateTexts")
        )
    }

    if (vehicleSatisfiedCount = 0) {
        failureReason := "NO_RATEABLE_VEHICLES"
        AdvisorQuoteAppendLog(
            "RAPPORT_NO_RATEABLE_VEHICLES",
            AdvisorQuoteGetLastStep(),
            "ledger=" AdvisorQuoteRapportVehicleLedgerSummary(rapportLedger)
                . ", deferredCompleteVehicles=" AdvisorQuoteVehicleListSummary(deferredCompleteVehicles)
                . ", deferredUnknownVehicles=" AdvisorQuoteVehicleListSummary(deferredUnknownVehicles)
                . ", deferredPartialVehicles=" AdvisorQuoteVehicleListSummary(deferredPartialVehicles)
        )
        failureScanPath := AdvisorQuoteScanCurrentPage("RAPPORT", "no-safe-rapport-vehicle-match")
        return false
    }

    if !AdvisorQuoteRapportVehicleLedgerAllRateableTerminal(rapportLedger) {
        failureReason := "RAPPORT_VEHICLE_LEDGER_INCOMPLETE: " AdvisorQuoteRapportVehicleLedgerSummary(rapportLedger)
        failureScanPath := AdvisorQuoteScanCurrentPage("RAPPORT", "rapport-vehicle-ledger-incomplete")
        return false
    }

    expectedVehiclesForGuardList := AdvisorQuoteBuildGatherFinalExpectedVehicles(satisfiedVehicles, [])
    expectedVehicleArgsForFinalGuard := AdvisorQuoteBuildExpectedVehiclesArgList(expectedVehiclesForGuardList)
    expectedVehicleCountForFinalGuard := expectedVehicleArgsForFinalGuard.Length
    promotedPartialExpectedCount := AdvisorQuoteCountExpectedArgsMatchingVehicles(expectedVehicleArgsForFinalGuard, promotedPartialVehicles)
    expectedVehiclesForFinalGuard := AdvisorQuoteVehicleListSummary(expectedVehiclesForGuardList)
    missingPromotedPartialExpectedVehicles := AdvisorQuoteExpectedArgsMissingVehiclesSummary(expectedVehicleArgsForFinalGuard, promotedPartialVehicles)
    if (promotedPartialVehicles.Length > 0 && missingPromotedPartialExpectedVehicles != "") {
        failureReason := "PROMOTED_PARTIAL_DROPPED_FROM_EXPECTED_LIST: " missingPromotedPartialExpectedVehicles
        AdvisorQuoteAppendLog(
            "PROMOTED_PARTIAL_DROPPED_FROM_EXPECTED_LIST",
            AdvisorQuoteGetLastStep(),
            "completeExpectedCount=" actionableVehicles.Length
            . ", promotedPartialExpectedCount=" promotedPartialExpectedCount
            . ", promotedPartialVehicleCount=" promotedPartialVehicles.Length
            . ", dbAddedVehicleCount=" dbAddedVehicles.Length
            . ", dbAddedVehicles=" AdvisorQuoteVehicleListSummary(dbAddedVehicles)
            . ", finalExpectedCount=" expectedVehicleCountForFinalGuard
            . ", finalExpectedVehicles=" expectedVehiclesForFinalGuard
            . ", missingPromotedPartialExpectedVehicles=" missingPromotedPartialExpectedVehicles
        )
        failureScanPath := AdvisorQuoteScanCurrentPage("RAPPORT", "promoted-partial-dropped-from-expected-list")
        return false
    }
    AdvisorQuoteAppendLog(
        "GATHER_CONFIRMED_VEHICLES_ARGS",
        AdvisorQuoteGetLastStep(),
        "actionableVehicleCount=" actionableVehicles.Length
            . ", actionableVehicles=" AdvisorQuoteVehicleListSummary(actionableVehicles)
            . ", completeExpectedCount=" expectedVehiclesForGuardList.Length
            . ", promotedPartialVehicleCount=" promotedPartialVehicles.Length
            . ", promotedPartialExpectedCount=" promotedPartialExpectedCount
            . ", promotedPartialVehicles=" AdvisorQuoteVehicleListSummary(promotedPartialVehicles)
            . ", dbAddedVehicleCount=" dbAddedVehicles.Length
            . ", dbAddedVehicles=" AdvisorQuoteVehicleListSummary(dbAddedVehicles)
            . ", deferredRapportVehicleCount=" deferredRapportVehicles.Length
            . ", deferredRapportVehicles=" AdvisorQuoteVehicleListSummary(deferredRapportVehicles)
            . ", deferredCompleteVehicleCount=" deferredCompleteVehicles.Length
            . ", deferredCompleteVehicles=" AdvisorQuoteVehicleListSummary(deferredCompleteVehicles)
            . ", deferredUnknownVehicleCount=" deferredUnknownVehicles.Length
            . ", deferredUnknownVehicles=" AdvisorQuoteVehicleListSummary(deferredUnknownVehicles)
            . ", deferredPartialVehicleCount=" deferredPartialVehicles.Length
            . ", deferredPartialVehicles=" AdvisorQuoteVehicleListSummary(deferredPartialVehicles)
            . ", expectedVehicleCountForFinalGuard=" expectedVehicleCountForFinalGuard
            . ", expectedVehiclesForFinalGuard=" expectedVehiclesForFinalGuard
            . ", finalExpectedCount=" expectedVehicleCountForFinalGuard
            . ", finalExpectedVehicles=" expectedVehiclesForFinalGuard
            . ", ignoredMissingYearVehicleCount=" vehiclePolicy["ignoredMissingYearVehicles"].Length
            . ", ignoredMissingYearVehicles=" AdvisorQuoteVehicleListSummary(vehiclePolicy["ignoredMissingYearVehicles"])
            . ", deferredVinVehicleCount=" vehiclePolicy["deferredVinVehicles"].Length
            . ", deferredVinVehicles=" AdvisorQuoteVehicleListSummary(vehiclePolicy["deferredVinVehicles"])
            . ", vehicleSatisfiedCount=" vehicleSatisfiedCount
            . ", satisfiedVehicles=" AdvisorQuoteVehicleListSummary(satisfiedVehicles)
            . ", confirmedGuardArgsSummary=" expectedVehiclesForFinalGuard
    )
    confirmedStatus := AdvisorQuoteGetGatherConfirmedVehiclesStatusForVehicles(expectedVehiclesForGuardList)
    AdvisorQuoteAppendLog("GATHER_CONFIRMED_VEHICLES_STATUS", AdvisorQuoteGetLastStep(), AdvisorQuoteBuildGatherConfirmedVehiclesStatusDetail(confirmedStatus))
    AdvisorQuoteAppendLog(
        "GATHER_VEHICLE_RECONCILIATION",
        AdvisorQuoteGetLastStep(),
        "vehicleSatisfiedCount=" vehicleSatisfiedCount
            . ", actionableVehicleCount=" actionableVehicles.Length
            . ", completeExpectedCount=" expectedVehiclesForGuardList.Length
            . ", promotedPartialVehicleCount=" promotedPartialVehicles.Length
            . ", promotedPartialExpectedCount=" promotedPartialExpectedCount
            . ", promotedPartialVehicles=" AdvisorQuoteVehicleListSummary(promotedPartialVehicles)
            . ", dbAddedVehicleCount=" dbAddedVehicles.Length
            . ", dbAddedVehicles=" AdvisorQuoteVehicleListSummary(dbAddedVehicles)
            . ", deferredRapportVehicleCount=" deferredRapportVehicles.Length
            . ", deferredRapportVehicles=" AdvisorQuoteVehicleListSummary(deferredRapportVehicles)
            . ", deferredCompleteVehicleCount=" deferredCompleteVehicles.Length
            . ", deferredCompleteVehicles=" AdvisorQuoteVehicleListSummary(deferredCompleteVehicles)
            . ", deferredUnknownVehicleCount=" deferredUnknownVehicles.Length
            . ", deferredUnknownVehicles=" AdvisorQuoteVehicleListSummary(deferredUnknownVehicles)
            . ", deferredPartialVehicleCount=" deferredPartialVehicles.Length
            . ", deferredPartialVehicles=" AdvisorQuoteVehicleListSummary(deferredPartialVehicles)
            . ", expectedVehicleCountForFinalGuard=" expectedVehicleCountForFinalGuard
            . ", expectedVehiclesForFinalGuard=" expectedVehiclesForFinalGuard
            . ", finalExpectedCount=" expectedVehicleCountForFinalGuard
            . ", finalExpectedVehicles=" expectedVehiclesForFinalGuard
            . ", satisfiedVehicles=" AdvisorQuoteVehicleListSummary(satisfiedVehicles)
            . ", ignoredMissingYearVehicleCount=" vehiclePolicy["ignoredMissingYearVehicles"].Length
            . ", ignoredMissingYearVehicles=" AdvisorQuoteVehicleListSummary(vehiclePolicy["ignoredMissingYearVehicles"])
            . ", deferredVinVehicleCount=" vehiclePolicy["deferredVinVehicles"].Length
            . ", deferredVinVehicles=" AdvisorQuoteVehicleListSummary(vehiclePolicy["deferredVinVehicles"])
            . ", missingExpectedVehicles=" AdvisorQuoteStatusValue(confirmedStatus, "missingExpectedVehicles")
            . ", unexpectedVehicles=" AdvisorQuoteStatusValue(confirmedStatus, "unexpectedVehicles")
            . ", matchedVehicles=" AdvisorQuoteStatusValue(confirmedStatus, "matchedVehicles")
            . ", unresolvedLeadVehicles=" AdvisorQuoteStatusValue(confirmedStatus, "unresolvedLeadVehicles")
    )
    if !AdvisorQuoteGatherConfirmedVehiclesSafe(confirmedStatus, profile, &failureReason) {
        failureScanPath := AdvisorQuoteScanCurrentPage("RAPPORT", "confirmed-vehicles-unsafe")
        return false
    }

    if !AdvisorQuoteCleanupStaleGatherVehicleRowIfSafe(expectedVehiclesForGuardList, staleDuplicateRowSeen, staleDuplicateRowDetails, vehicleSatisfiedCount, &failureReason, &failureScanPath)
        return false

    finalRapportSnapshot := AdvisorQuoteGetGatherRapportSnapshot()
    if (AdvisorQuoteStatusValue(finalRapportSnapshot, "staleAddRowPresent") = "1") {
        if (vehicleSatisfiedCount > 0 && AdvisorQuoteStatusValue(finalRapportSnapshot, "startQuotingSectionPresent") = "1") {
            AdvisorQuoteAppendLog(
                "RAPPORT_STALE_ROW_DEFERRED_WITH_CONFIRMED_VEHICLE",
                AdvisorQuoteGetLastStep(),
                "confirmedOrAddedVehicleCount=" vehicleSatisfiedCount
                    . ", staleAddRowPresent=" AdvisorQuoteStatusValue(finalRapportSnapshot, "staleAddRowPresent")
                    . ", startQuotingSectionPresent=" AdvisorQuoteStatusValue(finalRapportSnapshot, "startQuotingSectionPresent")
                    . ", createQuotesEnabled=" AdvisorQuoteStatusValue(finalRapportSnapshot, "createQuotesEnabled")
                    . ", blockerCode=" AdvisorQuoteStatusValue(finalRapportSnapshot, "blockerCode")
            )
        } else {
            failureReason := "RAPPORT_UNSAFE_ADD_ROW_REMAINS_BEFORE_START_QUOTING: " AdvisorQuoteBuildGatherRapportSnapshotDetail(finalRapportSnapshot)
            failureScanPath := AdvisorQuoteScanCurrentPage("RAPPORT", "rapport-unsafe-add-row-before-start-quoting")
            return false
        }
    }
    if (AdvisorQuoteStatusValue(finalRapportSnapshot, "vehicleWarningPresent") = "1"
        && AdvisorQuoteStatusValue(finalRapportSnapshot, "createQuotesEnabled") != "1") {
        if (vehicleSatisfiedCount > 0 && AdvisorQuoteStatusValue(finalRapportSnapshot, "startQuotingSectionPresent") = "1") {
            AdvisorQuoteAppendLog(
                "RAPPORT_VEHICLE_WARNING_DEFERRED_WITH_CONFIRMED_VEHICLE",
                AdvisorQuoteGetLastStep(),
                "confirmedOrAddedVehicleCount=" vehicleSatisfiedCount
                    . ", vehicleWarningText=" AdvisorQuoteStatusValue(finalRapportSnapshot, "vehicleWarningText")
                    . ", potentialVehicleCount=" AdvisorQuoteStatusValue(finalRapportSnapshot, "potentialVehicleCount")
                    . ", startQuotingSectionPresent=" AdvisorQuoteStatusValue(finalRapportSnapshot, "startQuotingSectionPresent")
                    . ", createQuotesEnabled=" AdvisorQuoteStatusValue(finalRapportSnapshot, "createQuotesEnabled")
            )
        } else {
            failureReason := "RAPPORT_VEHICLE_WARNING_BLOCKS_START_QUOTING: " AdvisorQuoteBuildGatherRapportSnapshotDetail(finalRapportSnapshot)
            failureScanPath := AdvisorQuoteScanCurrentPage("RAPPORT", "rapport-vehicle-warning-before-start-quoting")
            return false
        }
    }
    if !AdvisorQuoteRapportVehicleLedgerStartQuotingAllowed(
        rapportLedger,
        vehicleSatisfiedCount,
        AdvisorQuoteStatusValue(finalRapportSnapshot, "staleAddRowPresent"),
        AdvisorQuoteStatusValue(finalRapportSnapshot, "vehicleWarningPresent"),
        AdvisorQuoteStatusValue(finalRapportSnapshot, "createQuotesEnabled")
    ) {
        failureReason := "RAPPORT_VEHICLE_LEDGER_START_QUOTING_BLOCKED: " AdvisorQuoteRapportVehicleLedgerSummary(rapportLedger)
        failureScanPath := AdvisorQuoteScanCurrentPage("RAPPORT", "rapport-vehicle-ledger-start-quoting-blocked")
        return false
    }

    AdvisorQuoteAppendLog(
        "RAPPORT_VEHICLE_LEDGER_DONE",
        AdvisorQuoteGetLastStep(),
        "ledger=" AdvisorQuoteRapportVehicleLedgerSummary(rapportLedger)
            . ", satisfiedCount=" AdvisorQuoteRapportVehicleLedgerSatisfiedCount(rapportLedger)
            . ", confirmedOrAddedVehicleCount=" vehicleSatisfiedCount
            . ", staleAddRowPresent=" AdvisorQuoteStatusValue(finalRapportSnapshot, "staleAddRowPresent")
            . ", vehicleWarningPresent=" AdvisorQuoteStatusValue(finalRapportSnapshot, "vehicleWarningPresent")
            . ", createQuotesEnabled=" AdvisorQuoteStatusValue(finalRapportSnapshot, "createQuotesEnabled")
            . ", startQuotingAllowed=1"
    )

    startQuotingStatus := AdvisorQuoteGetGatherStartQuotingStatus(db)
    AdvisorQuoteAppendLog("GATHER_START_QUOTING_STATUS", AdvisorQuoteGetLastStep(), AdvisorQuoteBuildGatherStartQuotingStatusDetail(startQuotingStatus))

    startQuotingReason := ""
    startQuotingReady := AdvisorQuoteGatherStartQuotingStatusValid(startQuotingStatus, db, &startQuotingReason)
    startQuotingCheckboxEnsureAttempted := false
    if !startQuotingReady {
        if (advisorQuoteProductOverviewAutoPending && !AdvisorQuoteGatherStartQuotingAutoSelected(startQuotingStatus)) {
            advisorQuoteGatherAutoCommitted := false
            AdvisorQuoteAppendLog(
                "PRODUCT_OVERVIEW_AUTO_NOT_COMMITTED",
                AdvisorQuoteGetLastStep(),
                "GatherAutoCommitted=0, " AdvisorQuoteBuildGatherStartQuotingStatusDetail(startQuotingStatus)
            )
        }

        if (AdvisorQuoteStatusValue(startQuotingStatus, "hasStartQuotingText") = "1") {
            startQuotingCheckboxEnsureAttempted := true
            checkboxStatus := AdvisorQuoteEnsureStartQuotingAutoCheckbox()
            AdvisorQuoteAppendLog("GATHER_START_QUOTING_AUTO_CHECKBOX", AdvisorQuoteGetLastStep(), AdvisorQuoteBuildStartQuotingAutoCheckboxDetail(checkboxStatus))

            applyStatus := AdvisorQuoteEnsureAutoStartQuotingState(db)
            AdvisorQuoteAppendLog("GATHER_START_QUOTING_AUTO_SET", AdvisorQuoteGetLastStep(), AdvisorQuoteBuildGatherStartQuotingApplyDetail(applyStatus))

            startQuotingStatus := AdvisorQuoteGetGatherStartQuotingStatus(db)
            AdvisorQuoteAppendLog("GATHER_START_QUOTING_STATUS", AdvisorQuoteGetLastStep(), AdvisorQuoteBuildGatherStartQuotingStatusDetail(startQuotingStatus))
            startQuotingReady := AdvisorQuoteGatherStartQuotingStatusValid(startQuotingStatus, db, &startQuotingReason)
        }
    }

    if (!startQuotingReady && AdvisorQuoteCanRunScopedStartQuotingAddProductHandoff(startQuotingStatus, db, advisorQuoteProductOverviewAutoVerified, &startQuotingReason)) {
        handoffPath := startQuotingCheckboxEnsureAttempted ? "checkbox-then-add-product" : "scoped-add-product"
        handoffStatus := Map()
        handoffReason := ""
        if !AdvisorQuoteRunScopedStartQuotingAddProductHandoff(db, startQuotingStatus, handoffPath, &handoffStatus, &handoffReason, &failureReason, &failureScanPath)
            return false
        startQuotingStatus := handoffStatus
        startQuotingReason := handoffReason
        startQuotingReady := AdvisorQuoteGatherStartQuotingStatusValid(startQuotingStatus, db, &startQuotingReason)
    }

    if (!startQuotingReady && advisorQuoteProductOverviewAutoVerified && AdvisorQuoteGatherNeedsProductTileRecovery(startQuotingStatus)) {
        recoveryScanPath := ""
        if AdvisorQuoteRecoverProductTileAutoFromRapport(db, startQuotingStatus, startQuotingReason, &failureReason, &recoveryScanPath) {
            startQuotingStatus := AdvisorQuoteGetGatherStartQuotingStatus(db)
            AdvisorQuoteAppendLog(
                "GATHER_START_QUOTING_STATUS",
                AdvisorQuoteGetLastStep(),
                "phase=after-product-tile-recovery, " AdvisorQuoteBuildGatherStartQuotingStatusDetail(startQuotingStatus)
            )
            startQuotingReady := AdvisorQuoteGatherStartQuotingStatusValid(startQuotingStatus, db, &startQuotingReason)
        } else {
            failureScanPath := recoveryScanPath
            return false
        }
    }

    if startQuotingReady {
        advisorQuoteProductOverviewAutoPending := false
        advisorQuoteGatherAutoCommitted := true
        AdvisorQuoteAppendLog("GATHER_START_QUOTING_READY", AdvisorQuoteGetLastStep(), "GatherAutoCommitted=1, " AdvisorQuoteBuildGatherStartQuotingStatusDetail(startQuotingStatus))
        AdvisorQuoteAppendLog(
            "GATHER_START_QUOTING_HANDOFF",
            AdvisorQuoteGetLastStep(),
            "startQuotingHandoffPath=create-quotes-enabled"
                . ", startQuotingCreateQuotesEnabledBefore=" (AdvisorQuoteStartQuotingCreateQuotesEnabled(startQuotingStatus) ? "1" : "0")
                . ", startQuotingScopedAddProductPresent=" (AdvisorQuoteStartQuotingScopedAddProductPresent(startQuotingStatus) ? "1" : "0")
                . ", startQuotingScopedAddProductClicked=0"
        )

        clickResult := AdvisorQuoteClickCreateQuotesOrderReports(db)
        AdvisorQuoteAppendLog("GATHER_START_QUOTING_CREATE_QUOTES_CLICK", AdvisorQuoteGetLastStep(), "result=" clickResult)
        if (clickResult != "OK") {
            if (clickResult = "DISABLED" && advisorQuoteProductOverviewAutoVerified) {
                retryStatus := AdvisorQuoteGetGatherStartQuotingStatus(db)
                AdvisorQuoteAppendLog(
                    "GATHER_START_QUOTING_STATUS",
                    AdvisorQuoteGetLastStep(),
                    "phase=create-quotes-disabled-retry, " AdvisorQuoteBuildGatherStartQuotingStatusDetail(retryStatus)
                )
                retryReason := ""
                if AdvisorQuoteCanRunScopedStartQuotingAddProductHandoff(retryStatus, db, advisorQuoteProductOverviewAutoVerified, &retryReason) {
                    if !AdvisorQuoteRunScopedStartQuotingAddProductHandoff(db, retryStatus, "scoped-add-product", &startQuotingStatus, &startQuotingReason, &failureReason, &failureScanPath)
                        return false
                    clickResult := AdvisorQuoteClickCreateQuotesOrderReports(db)
                    AdvisorQuoteAppendLog("GATHER_START_QUOTING_CREATE_QUOTES_CLICK", AdvisorQuoteGetLastStep(), "phase=after-scoped-add-product, result=" clickResult)
                    if (clickResult = "OK") {
                        waitArgs := Map("ascProductContains", db["urls"]["ascProductContains"])
                        if !AdvisorQuoteWaitForCondition("gather_start_quoting_transition", db["timeouts"]["transitionMs"], db["timeouts"]["pollMs"], waitArgs) {
                            failureReason := "Create Quotes & Order Reports did not transition to Consumer Reports or a later quote state."
                            failureScanPath := AdvisorQuoteScanCurrentPage("RAPPORT", "create-quotes-transition-timeout")
                            return false
                        }
                        return true
                    }
                }
            }
            if (clickResult = "NO_BUTTON")
                failureReason := "Create Quotes & Order Reports button was not found on Gather Data."
            else if (clickResult = "DISABLED")
                failureReason := "Create Quotes & Order Reports is still disabled on Gather Data."
            else
                failureReason := "Create Quotes & Order Reports could not be clicked on Gather Data."
            failureScanPath := AdvisorQuoteScanCurrentPage("RAPPORT", "create-quotes-click-failed")
            return false
        }

        waitArgs := Map("ascProductContains", db["urls"]["ascProductContains"])
        if !AdvisorQuoteWaitForCondition("gather_start_quoting_transition", db["timeouts"]["transitionMs"], db["timeouts"]["pollMs"], waitArgs) {
            failureReason := "Create Quotes & Order Reports did not transition to Consumer Reports or a later quote state."
            failureScanPath := AdvisorQuoteScanCurrentPage("RAPPORT", "create-quotes-transition-timeout")
            return false
        }
        return true
    }

    notReadyScan := AdvisorQuoteScanCurrentPage("RAPPORT", "gather-start-quoting-not-ready")
    AdvisorQuoteAppendLog(
        "GATHER_START_QUOTING_NOT_READY",
        AdvisorQuoteGetLastStep(),
        "reason=" startQuotingReason . ", status=" AdvisorQuoteBuildGatherStartQuotingStatusDetail(startQuotingStatus) . ", scan=" notReadyScan
    )

    if AdvisorQuoteIsOnSelectProductPage(db) {
        AdvisorQuoteAppendLog("SELECT_PRODUCT_FALLBACK_USED", AdvisorQuoteGetLastStep(), "reason=already-on-select-product")
        return true
    }

    if !advisorQuoteProductOverviewAutoVerified {
        failureReason := "PRODUCT_OVERVIEW_AUTO_NOT_VERIFIED: Gather Data reached without verified Product Tile Grid Auto selection; refusing Add Product fallback."
        failureScanPath := notReadyScan
        AdvisorQuoteAppendLog(
            "PRODUCT_OVERVIEW_AUTO_NOT_VERIFIED",
            AdvisorQuoteGetLastStep(),
            "reason=" startQuotingReason . ", status=" AdvisorQuoteBuildGatherStartQuotingStatusDetail(startQuotingStatus) . ", scan=" notReadyScan
        )
        return false
    }

    if !AdvisorQuoteGatherStartQuotingAutoSelected(startQuotingStatus) {
        failureReason := "START_QUOTING_AUTO_MISSING_AFTER_PRODUCT_OVERVIEW: Auto was verified on Product Tile Grid but is not selected in Gather Data Start Quoting; refusing Add Product fallback."
        failureScanPath := notReadyScan
        AdvisorQuoteAppendLog(
            "START_QUOTING_AUTO_MISSING_AFTER_PRODUCT_OVERVIEW",
            AdvisorQuoteGetLastStep(),
            "reason=" startQuotingReason . ", status=" AdvisorQuoteBuildGatherStartQuotingStatusDetail(startQuotingStatus) . ", scan=" notReadyScan
        )
        advisorQuoteProductOverviewAutoPending := false
        return false
    }

    failureReason := AdvisorQuoteStartQuotingFailureCode(startQuotingStatus, startQuotingReason)
    failureScanPath := notReadyScan
    AdvisorQuoteAppendLog(
        "GATHER_START_QUOTING_INVALID_AFTER_PRODUCT_OVERVIEW",
        AdvisorQuoteGetLastStep(),
        "reason=" startQuotingReason . ", failureReason=" failureReason . ", addProductFallbackRefusedReason=product-tile-auto-gate, status=" AdvisorQuoteBuildGatherStartQuotingStatusDetail(startQuotingStatus) . ", scan=" notReadyScan
    )
    return false
}

AdvisorQuoteFillGatherDefaults(profile, db, &failureReason := "") {
    failureReason := ""
    person := (IsObject(profile) && profile.Has("person")) ? profile["person"] : Map()
    emailValue := person.Has("email") ? Trim(String(person["email"])) : ""
    ageValue := String(db["defaults"]["ageFirstLicensed"])
    ownershipValue := String(db["defaults"]["gatherResidenceOwnedRentedRentValue"])
    homeTypeValue := AdvisorQuoteInferGatherHomeType(profile, db)

    args := Map(
        "emailValue", emailValue,
        "ageValue", ageValue,
        "ownershipValue", ownershipValue,
        "homeTypeValue", homeTypeValue
    )
    applyStatus := AdvisorQuoteParseKeyValueLines(AdvisorQuoteRunOp("fill_gather_defaults", args))
    applyResult := AdvisorQuoteStatusValue(applyStatus, "result")
    if (applyResult = "FAILED" || applyResult = "ERROR" || applyResult = "") {
        failureReason := "Could not apply Gather Data defaults via the Advisor page."
        return false
    }

    AdvisorQuoteAppendLog(
        "GATHER_DEFAULTS_APPLIED",
        AdvisorQuoteGetLastStep(),
        "ageValue=" ageValue
            . ", emailPresent=" ((emailValue != "") ? "1" : "0")
            . ", ownershipValue=" ownershipValue
            . ", homeTypeValue=" homeTypeValue
            . ", result=" applyResult
            . ", ageApplied=" AdvisorQuoteStatusValue(applyStatus, "ageApplied")
            . ", emailApplied=" AdvisorQuoteStatusValue(applyStatus, "emailApplied")
            . ", ownershipApplied=" AdvisorQuoteStatusValue(applyStatus, "ownershipApplied")
            . ", homeTypeApplied=" AdvisorQuoteStatusValue(applyStatus, "homeTypeApplied")
    )

    status := AdvisorQuoteGetGatherDefaultsStatus()
    AdvisorQuoteAppendLog("GATHER_DEFAULTS_STATUS", AdvisorQuoteGetLastStep(), AdvisorQuoteBuildGatherDefaultsStatusDetail(status))
    return AdvisorQuoteGatherDefaultsValid(status, ageValue, emailValue, ownershipValue, homeTypeValue, &failureReason)
}

AdvisorQuoteGetGatherDefaultsStatus() {
    return AdvisorQuoteParseKeyValueLines(AdvisorQuoteRunOp("gather_defaults_status", Map(), 2, 120))
}

AdvisorQuoteBuildGatherDefaultsStatusDetail(status) {
    return "ageFirstLicensed=" AdvisorQuoteStatusValue(status, "ageFirstLicensed")
        . ", email=" AdvisorQuoteStatusValue(status, "email")
        . ", ownershipTypeValue=" AdvisorQuoteStatusValue(status, "ownershipTypeValue")
        . ", ownershipTypeText=" AdvisorQuoteStatusValue(status, "ownershipTypeText")
        . ", homeTypeValue=" AdvisorQuoteStatusValue(status, "homeTypeValue")
        . ", homeTypeText=" AdvisorQuoteStatusValue(status, "homeTypeText")
        . ", licenseStateValue=" AdvisorQuoteStatusValue(status, "licenseStateValue")
        . ", licenseStateText=" AdvisorQuoteStatusValue(status, "licenseStateText")
        . ", alerts=" AdvisorQuoteStatusValue(status, "alerts")
}

AdvisorQuoteGatherDefaultsValid(status, ageValue, emailValue, ownershipValue, homeTypeValue, &failureReason := "") {
    failureReason := ""
    if !IsObject(status) || (status.Count = 0) {
        failureReason := "Gather Data defaults status could not be read back from the page."
        return false
    }

    actualAge := Trim(AdvisorQuoteStatusValue(status, "ageFirstLicensed"))
    if (ageValue != "" && actualAge != ageValue) {
        failureReason := "Age First Licensed default did not stick. Expected " ageValue ", found " actualAge "."
        return false
    }

    actualEmail := Trim(AdvisorQuoteStatusValue(status, "email"))
    if (Trim(String(emailValue)) != "" && StrLower(actualEmail) != StrLower(Trim(String(emailValue)))) {
        failureReason := "Gather Data email default did not stick."
        return false
    }

    if !AdvisorQuoteStatusOptionMatches(
        AdvisorQuoteStatusValue(status, "ownershipTypeValue"),
        AdvisorQuoteStatusValue(status, "ownershipTypeText"),
        ownershipValue,
        "Rent"
    ) {
        failureReason := "Gather Data ownership type default did not stick."
        return false
    }

    if !AdvisorQuoteStatusOptionMatches(
        AdvisorQuoteStatusValue(status, "homeTypeValue"),
        AdvisorQuoteStatusValue(status, "homeTypeText"),
        homeTypeValue,
        AdvisorQuoteGatherHomeTypeLabel(homeTypeValue)
    ) {
        failureReason := "Gather Data home type default did not stick."
        return false
    }

    return true
}

AdvisorQuoteGetGatherStartQuotingStatus(db) {
    args := Map("selectors", db["selectors"])
    return AdvisorQuoteParseKeyValueLines(AdvisorQuoteRunOp("gather_start_quoting_status", args, 2, 120))
}

AdvisorQuoteBuildGatherStartQuotingStatusDetail(status) {
    return "hasStartQuotingText=" AdvisorQuoteStatusValue(status, "hasStartQuotingText")
        . ", startQuotingSectionPresent=" AdvisorQuoteStatusValue(status, "startQuotingSectionPresent")
        . ", autoProductPresent=" AdvisorQuoteStatusValue(status, "autoProductPresent")
        . ", autoProductChecked=" AdvisorQuoteStatusValue(status, "autoProductChecked")
        . ", autoProductSelected=" AdvisorQuoteStatusValue(status, "autoProductSelected")
        . ", autoProductSource=" AdvisorQuoteStatusValue(status, "autoProductSource")
        . ", autoCheckboxId=" AdvisorQuoteStatusValue(status, "autoCheckboxId")
        . ", ratingStatePresent=" AdvisorQuoteStatusValue(status, "ratingStatePresent")
        . ", ratingStateValue=" AdvisorQuoteStatusValue(status, "ratingStateValue")
        . ", ratingStateText=" AdvisorQuoteStatusValue(status, "ratingStateText")
        . ", ratingStateSource=" AdvisorQuoteStatusValue(status, "ratingStateSource")
        . ", createQuoteButtonPresent=" AdvisorQuoteStatusValue(status, "createQuoteButtonPresent")
        . ", createQuoteButtonEnabled=" AdvisorQuoteStatusValue(status, "createQuoteButtonEnabled")
        . ", addProductLinkPresent=" AdvisorQuoteStatusValue(status, "addProductLinkPresent")
        . ", createQuotesPresent=" AdvisorQuoteStatusValue(status, "createQuotesPresent")
        . ", createQuotesEnabled=" AdvisorQuoteStatusValue(status, "createQuotesEnabled")
        . ", addProductPresent=" AdvisorQuoteStatusValue(status, "addProductPresent")
        . ", evidence=" AdvisorQuoteStatusValue(status, "evidence")
        . ", missing=" AdvisorQuoteStatusValue(status, "missing")
        . ", alerts=" AdvisorQuoteStatusValue(status, "alerts")
}

AdvisorQuoteBuildGatherStartQuotingApplyDetail(status) {
    return "result=" AdvisorQuoteStatusValue(status, "result")
        . ", autoApplied=" AdvisorQuoteStatusValue(status, "autoApplied")
        . ", autoMethod=" AdvisorQuoteStatusValue(status, "autoMethod")
        . ", ratingStateApplied=" AdvisorQuoteStatusValue(status, "ratingStateApplied")
        . ", ratingStateMethod=" AdvisorQuoteStatusValue(status, "ratingStateMethod")
        . ", " . AdvisorQuoteBuildGatherStartQuotingStatusDetail(status)
}

AdvisorQuoteGatherStartQuotingAutoSelected(status) {
    return (
        AdvisorQuoteStatusValue(status, "autoProductChecked") = "1"
        || AdvisorQuoteStatusValue(status, "autoProductSelected") = "1"
    )
}

AdvisorQuoteStartQuotingCreateQuotesPresent(status) {
    return AdvisorQuoteStatusValue(status, "createQuoteButtonPresent") = "1"
        || AdvisorQuoteStatusValue(status, "createQuotesPresent") = "1"
}

AdvisorQuoteStartQuotingCreateQuotesEnabled(status) {
    return AdvisorQuoteStatusValue(status, "createQuoteButtonEnabled") = "1"
        || AdvisorQuoteStatusValue(status, "createQuotesEnabled") = "1"
}

AdvisorQuoteStartQuotingScopedAddProductPresent(status) {
    return AdvisorQuoteStatusValue(status, "addProductLinkPresent") = "1"
        || AdvisorQuoteStatusValue(status, "addProductPresent") = "1"
        || AdvisorQuoteStatusValue(status, "startQuotingAddProductPresent") = "1"
}

AdvisorQuoteGatherStartQuotingCoreReady(status, db, &failureReason := "") {
    failureReason := ""
    if !IsObject(status) || (status.Count = 0) {
        failureReason := "Gather Data Start Quoting status could not be read back from the page."
        return false
    }
    if (AdvisorQuoteStatusValue(status, "hasStartQuotingText") != "1" || AdvisorQuoteStatusValue(status, "startQuotingSectionPresent") = "0") {
        failureReason := "Start Quoting block is not visible on Gather Data."
        return false
    }
    if (AdvisorQuoteStatusValue(status, "autoProductPresent") != "1") {
        failureReason := "Auto is not present in the Start Quoting block."
        return false
    }
    if !AdvisorQuoteGatherStartQuotingAutoSelected(status) {
        failureReason := "Auto is not selected in the Start Quoting block."
        return false
    }
    if !AdvisorQuoteStatusOptionMatches(
        AdvisorQuoteStatusValue(status, "ratingStateValue"),
        AdvisorQuoteStatusValue(status, "ratingStateText"),
        db["defaults"]["ratingState"],
        db["defaults"]["ratingState"]
    ) {
        failureReason := "Start Quoting Rating State is not " db["defaults"]["ratingState"] "."
        return false
    }
    if !AdvisorQuoteStartQuotingCreateQuotesPresent(status) {
        failureReason := "Create Quotes & Order Reports is not present on Gather Data."
        return false
    }
    return true
}

AdvisorQuoteGatherStartQuotingReadyForScopedAddProductHandoff(status, db, &failureReason := "") {
    if !AdvisorQuoteGatherStartQuotingCoreReady(status, db, &failureReason)
        return false
    if AdvisorQuoteStartQuotingCreateQuotesEnabled(status) {
        failureReason := "Create Quotes & Order Reports is already enabled."
        return false
    }
    if !AdvisorQuoteStartQuotingScopedAddProductPresent(status) {
        failureReason := "Scoped Start Quoting Add product link is not present."
        return false
    }
    failureReason := "START_QUOTING_NEEDS_SCOPED_ADD_PRODUCT"
    return true
}

AdvisorQuoteCanRunScopedStartQuotingAddProductHandoff(status, db, productOverviewAutoVerified, &failureReason := "") {
    if !productOverviewAutoVerified {
        failureReason := "PRODUCT_OVERVIEW_AUTO_NOT_VERIFIED"
        return false
    }
    return AdvisorQuoteGatherStartQuotingReadyForScopedAddProductHandoff(status, db, &failureReason)
}

AdvisorQuoteGatherNeedsProductTileRecovery(status) {
    if !IsObject(status) || (status.Count = 0)
        return true
    if (AdvisorQuoteStatusValue(status, "hasStartQuotingText") != "1")
        return true
    if (AdvisorQuoteStatusValue(status, "startQuotingSectionPresent") = "0")
        return true
    if (AdvisorQuoteStatusValue(status, "autoProductPresent") != "1")
        return true
    return !AdvisorQuoteGatherStartQuotingAutoSelected(status)
}

AdvisorQuoteStartQuotingFailureCode(status, failureReason := "") {
    if !IsObject(status) || (status.Count = 0)
        return "START_QUOTING_SECTION_MISSING_OR_NOT_RENDERED: Gather Data Start Quoting status could not be read."
    if (AdvisorQuoteStatusValue(status, "hasStartQuotingText") != "1" || AdvisorQuoteStatusValue(status, "startQuotingSectionPresent") = "0")
        return "START_QUOTING_SECTION_MISSING_OR_NOT_RENDERED: " failureReason
    if (AdvisorQuoteStatusValue(status, "autoProductPresent") != "1")
        return "START_QUOTING_AUTO_NOT_PRESENT: " failureReason
    if !AdvisorQuoteGatherStartQuotingAutoSelected(status)
        return "START_QUOTING_AUTO_NOT_CHECKED: " failureReason
    if (AdvisorQuoteStatusValue(status, "ratingStatePresent") != "1")
        return "START_QUOTING_RATING_STATE_INVALID: " failureReason
    if !AdvisorQuoteStartQuotingCreateQuotesPresent(status) || !AdvisorQuoteStartQuotingCreateQuotesEnabled(status)
        return "START_QUOTING_CREATE_QUOTES_DISABLED: " failureReason
    return "START_QUOTING_RATING_STATE_INVALID: " failureReason
}

AdvisorQuoteGatherStartQuotingStatusValid(status, db, &failureReason := "") {
    if !AdvisorQuoteGatherStartQuotingCoreReady(status, db, &failureReason)
        return false
    if !AdvisorQuoteStartQuotingCreateQuotesEnabled(status) {
        failureReason := "Create Quotes & Order Reports is still disabled on Gather Data."
        return false
    }
    return true
}

AdvisorQuoteInferGatherHomeType(profile, db) {
    apartmentValue := String(db["defaults"]["gatherResidenceTypeApartmentValue"])
    singleFamilyValue := String(db["defaults"]["gatherResidenceTypeSingleFamilyValue"])
    residence := (IsObject(profile) && profile.Has("residence")) ? profile["residence"] : Map()
    if (IsObject(residence) && residence.Has("hasUnit") && residence["hasUnit"])
        return apartmentValue

    address := (IsObject(profile) && profile.Has("address")) ? profile["address"] : Map()
    fields := (IsObject(profile) && profile.Has("fields")) ? profile["fields"] : Map()
    parts := []
    if IsObject(address) {
        if address.Has("street")
            parts.Push(String(address["street"]))
        if address.Has("aptSuite")
            parts.Push(String(address["aptSuite"]))
    }
    if IsObject(fields) {
        if fields.Has("ADDRESS_1")
            parts.Push(String(fields["ADDRESS_1"]))
        if fields.Has("APT_SUITE")
            parts.Push(String(fields["APT_SUITE"]))
    }
    if (IsObject(profile) && profile.Has("rawRow"))
        parts.Push(String(profile["rawRow"]))
    if (IsObject(profile) && profile.Has("raw"))
        parts.Push(String(profile["raw"]))

    combined := StrLower(JoinArray(parts, " | "))
    if RegExMatch(combined, "(?:^|\b)(apt|apartment|unit|ste|suite|lot|room)\b")
        return apartmentValue
    if RegExMatch(combined, "#\s*[A-Za-z0-9]")
        return apartmentValue
    return singleFamilyValue
}

AdvisorQuoteGatherHomeTypeLabel(homeTypeValue) {
    normalized := AdvisorNormalizeLooseToken(homeTypeValue)
    if (normalized = "AP")
        return "Apartment"
    if (normalized = "SF")
        return "Single Family"
    return homeTypeValue
}

AdvisorQuoteStatusOptionMatches(actualValue, actualText, expectedValue, expectedText := "") {
    wantedValue := AdvisorNormalizeLooseToken(expectedValue)
    wantedText := AdvisorNormalizeLooseToken(expectedText)
    valueNorm := AdvisorNormalizeLooseToken(actualValue)
    textNorm := AdvisorNormalizeLooseToken(actualText)
    if (wantedValue != "" && valueNorm = wantedValue)
        return true
    if (wantedText != "" && textNorm != "" && InStr(textNorm, wantedText))
        return true
    return false
}

AdvisorQuoteProfileFullName(profile) {
    person := (IsObject(profile) && profile.Has("person")) ? profile["person"] : Map()
    fullName := person.Has("fullName") ? Trim(String(person["fullName"])) : ""
    if (fullName = "")
        fullName := Trim(String((person.Has("firstName") ? person["firstName"] : "") . " " . (person.Has("lastName") ? person["lastName"] : "")))
    return fullName
}

AdvisorQuoteLeadMaritalStatus(profile) {
    raw := (IsObject(profile) && profile.Has("raw")) ? String(profile["raw"]) : ""
    fields := (IsObject(profile) && profile.Has("fields")) ? profile["fields"] : Map()
    if (IsObject(fields) && fields.Has("MARITAL_STATUS")) {
        normalizedField := AdvisorQuoteNormalizeMaritalStatus(fields["MARITAL_STATUS"])
        if (normalizedField != "")
            return normalizedField
    }
    if RegExMatch(raw, "i)\bMarital\s+Status\s*:\s*(Single|Married|Divorced|Widowed|Separated)\b", &m)
        return AdvisorQuoteNormalizeMaritalStatus(m[1])
    return ""
}

AdvisorQuoteNormalizeMaritalStatus(value) {
    text := AdvisorNormalizeLooseToken(value)
    if InStr(text, "SINGLE")
        return "Single"
    if InStr(text, "MARRIED")
        return "Married"
    if InStr(text, "DIVORCED")
        return "Divorced"
    if InStr(text, "WIDOW")
        return "Widowed"
    if InStr(text, "SEPARATED")
        return "Separated"
    return ""
}

AdvisorQuoteLeadSpouseName(profile) {
    raw := (IsObject(profile) && profile.Has("raw")) ? String(profile["raw"]) : ""
    if RegExMatch(raw, "i)\b(?:Spouse|Spouse\s+Name)\s*:\s*([^\r\n]+)", &m)
        return Trim(String(m[1]))
    return ""
}

AdvisorQuoteExpectedDriverNamesText(profile, selectedSpouseName := "") {
    names := []
    primary := AdvisorQuoteProfileFullName(profile)
    if (primary != "")
        names.Push(primary)
    if (Trim(String(selectedSpouseName)) != "")
        names.Push(Trim(String(selectedSpouseName)))
    return JoinArray(names, "||")
}

