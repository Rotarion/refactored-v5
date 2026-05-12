# Sanitized Advisor live snapshot recapture findings — 2026-05-12
This batch is a sanitized post-classifier-patch recapture. It should be committed only in sanitized form. Do not commit the raw uploaded scan JSON files.
## Summary
- `ENTRY_STANDARDIZED_ADDRESS_ALERT` is now exposed as a stable blocker on the entry/create-prospect route.
- Customer Summary / Prefill Gate is correctly classified as `CUSTOMER_SUMMARY_PREFILL_GATE` with `start_prefill` allowed.
- Product Overview is now classified as `PRODUCT_OVERVIEW`, but this particular live snapshot has URL-only evidence and no Auto tile/status evidence, so mutation remains blocked.
- RAPPORT and Select Product remain correctly classified.
- ASC Drivers/Vehicles, inline participant panel, remove-driver modal, vehicle modal, and main unresolved-row state now classify as `ASC_DRIVERS_VEHICLES` instead of falling back to `ADVISOR_OTHER`.
- No iframe evidence was present in this recapture batch.

## Snapshot table
| File | Route | Confidence | Allowed | Blockers | ASC present | ASC blocker | ASC next | Auto visible | Auto selected | SelectProduct | Rapport |
| --- | --- | ---: | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 01_entry_begin_quoting.json | ENTRY_CREATE_FORM | 0.84 | human_review_required |  | False | NOT_ASC_DRIVERS_VEHICLES |  | False | False | False | False |
| 02_entry_standardized_address_alert.json | ENTRY_CREATE_FORM | 0.78 |  | alert:ENTRY_STANDARDIZED_ADDRESS_ALERT | False | NOT_ASC_DRIVERS_VEHICLES |  | False | False | False | False |
| 03_customer_summary_prefill_gate.json | CUSTOMER_SUMMARY_PREFILL_GATE | 0.93 | start_prefill |  | False | NOT_ASC_DRIVERS_VEHICLES |  | False | False | False | False |
| 04_product_overview_grid.json | PRODUCT_OVERVIEW | 0.72 |  |  | False | NOT_ASC_DRIVERS_VEHICLES |  | False | False | False | False |
| 05_rapport.json | RAPPORT | 0.88 | inspect_rapport, confirm_vehicles |  | False | NOT_ASC_DRIVERS_VEHICLES |  | False | False | False | True |
| 06_select_product.json | SELECT_PRODUCT | 0.92 | answer_select_product |  | False | NOT_ASC_DRIVERS_VEHICLES |  | True | True | True | False |
| 07_asc_inline_participant_panel.json | ASC_DRIVERS_VEHICLES | 0.78 |  | active:ASC_INLINE_PARTICIPANT_PANEL:Let's get some more details | True | ASC_INLINE_PARTICIPANT_READY_TO_SAVE | save_inline_participant_panel | False | False | False | False |
| 08_asc_remove_driver_modal.json | ASC_DRIVERS_VEHICLES | 0.78 |  | active:ASC_REMOVE_DRIVER_MODAL:EXTRA_DRIVER_NAME | True | ASC_REMOVE_DRIVER_MODAL_OPEN |  | False | False | False | False |
| 09_asc_vehicle_modal.json | ASC_DRIVERS_VEHICLES | 0.78 |  | active:ASC_VEHICLE_MODAL:2024 Ram 3500 | True | ASC_VEHICLE_MODAL_OPEN |  | False | False | False | False |
| 10_asc_drivers_vehicles_main.json | ASC_DRIVERS_VEHICLES | 0.91 | human_review_required |  | True | ASC_DRIVERS_VEHICLES_ROWS_UNRESOLVED | review_unresolved_drivers_vehicles | False | False | False | False |

## Interpretation
The read-only classifier patch is live-verified for the previously failing route families. The remaining Product Overview issue is intentionally conservative: URL-only route evidence classifies the route, but `allowedNextActions` is empty because Auto tile/status evidence was not resolved. That should not be treated as a failure unless the production workflow still cannot select Auto using the dedicated Product Overview status/action ops.

## Recommended next step
Commit this sanitized recapture evidence, then proceed to the operator contract inventory / productization freeze task. Do not start a new mutation patch from this batch unless a real workflow trace proves one of these read-only states still routes incorrectly in production.
