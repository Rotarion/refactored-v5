# Advisor Early Flow Patch Notes

Date: 2026-04-27

## Scope

This patch fixes the early Advisor Pro route:

`Advisor Home / Quoting -> Begin Quoting -> Create New Prospect -> optional Duplicate -> Prefill Gate -> Product Tile Grid -> Gather Data`

No runtime state names were renamed. No hotkeys, adapters, CRM/QUO, messaging, pricing, lead parsing, config INI, or downstream ASC/109 driver/vehicle/remove-driver/participant/insurance-history behavior were changed.

## Behavior Changed

- Prefill Gate (`CUSTOMER_SUMMARY_OVERVIEW`) now treats START HERE as a normal forward state and waits specifically for Product Tile Grid (`PRODUCT_OVERVIEW`).
- Product Tile Grid (`/intel/102/overview`) now reads Auto tile status before clicking. If Auto is already selected, it does not click the tile again; if Auto is not selected, it clicks once, reads back tile status, and only clicks Save & Continue to Gather Data after Auto is verified selected.
- A run-level marker distinguishes verified Product Tile Grid Auto selection from later Select Product Form fallback values.
- Gather Data (`RAPPORT`) refuses to use Start Quoting Add Product fallback when Product Tile Grid Auto was not verified, or when Auto is still missing after a verified Product Tile Grid path.
- Select Product Form (`/intel/102/selectProduct`) remains a fallback/alternate path after Gather Data and must verify Product Auto, Rating State, Current Insured Yes, and Own/Rent Own before Continue.
- `ascProductContains` now uses `/ASCPRODUCT/` instead of stale `/ASCPRODUCT/110/`, so live `/ASCPRODUCT/109/` routes are accepted.

## JS Contract Change

Added one read-only JS operator:

`product_overview_tile_status`

Return format is key=value lines:

- `result=SELECTED|FOUND|NO_TILE|NOT_OVERVIEW`
- `present=1|0`
- `selected=1|0`
- `productText=...`
- `tileText=...`
- `method=...`

Existing JS op names and return formats were not changed.

## Validation

- Initial `node assets/js/advisor_quote/build_operator.js --check` failed with expected drift before generation because the JS template had changed.
- `node assets/js/advisor_quote/build_operator.js` passed and generated `assets/js/advisor_quote/ops_result.js`.
- Final `node assets/js/advisor_quote/build_operator.js --check` passed.
- `node .\tests\advisor_quote_ops_smoke.js` passed using bundled Codex Node.
- `powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\Test-AhkToolchain.ps1` passed: `SMOKE_VALIDATE=pass`, `MAIN_VALIDATE=pass`, `COMPILER_CHECK=skipped`.

## Hashes

- `ops_result.js` before patch: `BB131298C3347B8916C0E47342A693CBCC7036DA3E9CE1004F8DE7E77AB8DB5F`
- `ops_result.js` after generated patch: `295A8FB2F1F8629ECF41AB9FC778F8A6B043730720FD6425A65A11E83D3C7F34`

The hash changed because this task intentionally added the read-only Product Tile Grid status op and regenerated the single injected runtime through the existing build script.

## Remaining Live Validation

- Confirm the live Product Tile Grid selected-state DOM is detected by `product_overview_tile_status` after clicking Auto.
- Confirm START HERE lands on `/intel/102/overview` consistently.
- Confirm Gather Data proceeds to Create Quotes when Product Tile Grid Auto is verified and Start Quoting Auto is present/selected.

## Patch A2: Product Tile Click And Verification

Live validation at 2026-04-27 17:31 showed Product Tile Grid remained at `/apps/intel/102/overview` after the Auto click:

- `click_product_overview_tile` returned `OK`
- `product_overview_tile_status` returned `result=FOUND`, `present=1`, `selected=0`, `method=visible-target`
- Auto and Save & Continue were still visible

Patch A2 keeps the early-flow guard intact and changes only the Product Tile Grid operator path:

- `click_product_overview_tile` now uses the existing `clickCenterEl()` strategy for the Auto tile target instead of the shallower `clickEl()` path.
- `product_overview_tile_status` still returns `SELECTED`, `FOUND`, `NO_TILE`, or `NOT_OVERVIEW`, but now checks target, ancestors, and descendants for selected evidence.
- Added diagnostic keys: `selectedEvidence`, `targetTag`, `targetId`, `targetClass`, `targetRole`, `targetAriaSelected`, `targetAriaChecked`, `targetAriaPressed`, `targetDataState`, `ancestorSummary`, `checkedDescendant`, and `selectedDescendant`.
- AHK trace logging now includes the most useful Product Tile Grid diagnostic keys when verification fails.

The workflow still fails safely at `PRODUCT_OVERVIEW` unless `selected=1` is proven.

Patch A2 validation:

- Initial `node assets/js/advisor_quote/build_operator.js --check` failed with expected drift before generation because the JS template had changed.
- `node assets/js/advisor_quote/build_operator.js` passed and generated `assets/js/advisor_quote/ops_result.js`.
- Final `node assets/js/advisor_quote/build_operator.js --check` passed.
- `node .\tests\advisor_quote_ops_smoke.js` passed using bundled Codex Node.
- `powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\Test-AhkToolchain.ps1` passed: `SMOKE_VALIDATE=pass`, `MAIN_VALIDATE=pass`, `COMPILER_CHECK=skipped`.
- Toolchain artifact: `logs\toolchain_checks\20260427_174413`.
- `ops_result.js` before Patch A2: `295A8FB2F1F8629ECF41AB9FC778F8A6B043730720FD6425A65A11E83D3C7F34`.
- `ops_result.js` after Patch A2: `57B6E1C624EB56E4A4CA7F783B2173AD86E816C68F00019E70EB6410FF788301`.

## Patch A3: Product Tile Grid Resolver And Selection Evidence

Live validation after duplicate handling reached Product Tile Grid, but Auto verification still failed:

- `click_product_overview_tile` returned `OK`
- `product_overview_tile_status` stayed `result=FOUND`, `selected=0`
- diagnostics showed `targetClass=l-grid__col l-grid__col--3`
- selected evidence stayed blank

Patch A3 keeps the Product Tile Auto guard intact and changes only Product Tile Grid resolving/status behavior:

- Product Tile Grid lookup now resolves a structured tile object with a text seed, tile/card container, clickable target, tile text, and method.
- The resolver prefers a nearby `.l-tile`, tile/card/product/choice container, or real interactive descendant over an outer `.l-grid__col`.
- `click_product_overview_tile` uses the same resolver and clicks the resolved interactive descendant or tile/card container.
- `product_overview_tile_status` uses the same resolver and reports tile-container and clickable-target diagnostics.
- Selected evidence now checks tile container, clickable target, ancestors, descendants, checked inputs, ARIA selected/checked/pressed values, selected/active/checked-style classes, `data-state`, and checkmark/icon evidence scoped inside the resolved Auto tile.

Patch A3 still does not proceed to Save & Continue unless `selected=1` is proven. It does not change duplicate handling, Customer Summary routing, Select Product fallback semantics, ASC/109 downstream behavior, hotkeys, config, CRM/QUO, messaging, pricing, or lead parsing.

Patch A3 validation:

- Initial `node assets/js/advisor_quote/build_operator.js --check` failed with expected drift before generation because the JS template changed.
- `node assets/js/advisor_quote/build_operator.js` passed and generated `assets/js/advisor_quote/ops_result.js`.
- Final `node assets/js/advisor_quote/build_operator.js --check` passed.
- `node .\tests\advisor_quote_ops_smoke.js` passed using bundled Codex Node.
- `powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\Test-AhkToolchain.ps1` passed: `SMOKE_VALIDATE=pass`, `MAIN_VALIDATE=pass`, `COMPILER_CHECK=skipped`.
- Toolchain artifact: `logs\toolchain_checks\20260429_105927`.
- `ops_result.js` before Patch A3: `1736ECA08A39EF79F2B2504BFAC23DAF06AE714B41B2C1AAD028F22D9181FA1E`.
- `ops_result.js` after Patch A3: `ED3EA7DA393BA08F5AE589F1EE301A9ABF17FF00CB4423F3EDEF5701ED4A5D10`.

## Patch B1: Customer Summary Route Status And Forward Fallback

Live validation later showed `ENTRY_CREATE_FORM` failed with raw observed state `ADVISOR_OTHER` while the browser was actually on Customer Summary / Prefill Gate at `/apps/customer-summary/<id>/overview` with START HERE, Quote History, Assets Details, and Add Product visible.

Patch B1 adds one read-only JS operator:

`customer_summary_overview_status`

Return format is key=value lines:

- `result=DETECTED|PARTIAL|NOT_DETECTED`
- `runtimeState=CUSTOMER_SUMMARY_OVERVIEW` or blank
- `confidence=high|medium|low|none`
- `urlMatched=1|0`
- `overviewMatched=1|0`
- `startHereMatched=1|0`
- `quoteHistoryMatched=1|0`
- `assetsDetailsMatched=1|0`
- `summaryAnchorMatched=1|0`
- `startHereCount=<number>`
- `evidence=...`
- `missing=...`
- `url=...`

High confidence requires:

- URL contains `/apps/customer-summary/`
- URL contains `/overview`
- START HERE is present
- Quote History or Assets Details is present

Medium confidence is customer-summary overview URL plus START HERE without Quote History or Assets Details. Medium confidence is logged and briefly polled, but it does not route forward immediately. Low confidence is customer-summary overview URL without START HERE. Non-customer-summary URL is `NOT_DETECTED`.

AHK keeps `detect_state` compatibility intact. `AdvisorQuoteStateEntryCreateForm()` and `AdvisorQuoteStateCustomerSummaryOverview()` call the status op only when raw detection is `ADVISOR_OTHER`, `UNKNOWN`, `NO_CONTEXT`, or blank. High-confidence status routes forward to `CUSTOMER_SUMMARY_OVERVIEW`; the create-form state does not click START HERE itself. START HERE remains owned by the Customer Summary state handler.

Patch B1 does not change Product Tile selected-state detection, the Product Tile Auto guard, Select Product fallback semantics, ASC/109 downstream behavior, hotkeys, config, CRM/QUO, messaging, pricing, or lead parsing.

## Patch B2: Entry Create Forwarding Through Customer Summary / Prefill Gate

Live validation showed `ENTRY_CREATE_FORM` could still fail with "Expected the Create New Prospect form" after Create New Prospect had already landed on Customer Summary / Prefill Gate (`/apps/customer-summary/<dynamicId>/overview`).

Patch B2 keeps duplicate, Address Verification, Product Tile Grid selection, Gather Data, and ASC/109 behavior unchanged, but changes the early route handoff:

- `ENTRY_CREATE_FORM` now treats high or medium Customer Summary status as forward progress and routes immediately through Customer Summary instead of failing because the Create New Prospect form is gone.
- Customer Summary status now accepts the live Prefill Gate shape when the dynamic customer-summary overview URL and START HERE are present; summary anchors still raise confidence to high.
- `click_customer_summary_start_here` clicks only a scoped START HERE control on Customer Summary / Prefill Gate and ignores Add Product.
- After START HERE, the workflow waits specifically for `PRODUCT_OVERVIEW`; Product Tile Grid Auto selection and Save & Continue verification remain owned by the existing Product Overview handler.
- Sidebar Add Product is not used as recovery.

Failure reasons now distinguish missing START HERE, failed START HERE click, Customer Summary not confirmed, and timeout from Customer Summary to Product Tile Grid.

## Patch A4: Product Tile Auto Idempotency

Live behavior showed the Auto tile can already be selected when Product Tile Grid opens. Because the tile behaves like a toggle, clicking an already-selected Auto tile can unselect it and cause later Start Quoting/Auto readiness failures.

Product Tile Grid Auto selection is now idempotent:

- `AdvisorQuoteHandleProductOverview()` reads `product_overview_tile_status` before any click.
- If `selected=1`, the workflow logs `PRODUCT_TILE_AUTO_ALREADY_SELECTED`, skips `click_product_overview_tile`, and proceeds only after carrying that selected status into the existing verification path.
- If `selected=0` and the tile is present, the workflow clicks Auto once and waits for selected-state readback.
- `click_product_overview_tile` also treats an already-selected tile as `OK` without clicking, as a defensive guard.
- Save & Continue still runs only after Auto selected state is proven, and the Product Tile Auto verified marker is still set only after Save & Continue reaches RAPPORT.

This patch does not change Customer Summary routing, Address Verification, duplicate handling, Gather Data vehicles/catalog matching, partial vehicle promotion, ASC/109, or sidebar Add Product recovery.

## Patch A5: Mandatory 102 Product Auto Gate

Live evidence showed `/apps/intel/102/overview` can enable `Save & Continue to Gather Data` even when no Product Tile Grid product is selected. Save-enabled is therefore not proof that Auto was chosen.

The automation now treats 102 Product Tile Grid as a mandatory Auto gate:

- Auto selected state is read only from scoped Auto tile/card evidence, such as tile selected class/state, ARIA selected/checked/pressed, checked input, or selected/checkmark descendants inside the Auto tile.
- Body text, saved assets, vehicle lists, URL, and Save & Continue enabled state do not count as Auto selected evidence.
- Already-selected Auto is not clicked again.
- Unselected Auto is clicked once and polled until selected.
- `Save & Continue to Gather Data` is blocked unless Auto selected state is proven before the click.

The workflow now separates three states:

- `ProductTileAutoSelectedOnOverview`: Auto was selected on `/apps/intel/102/overview`.
- `ProductOverviewSaved`: Save & Continue was clicked after the selected-state proof.
- `GatherAutoCommitted`: RAPPORT Start Quoting contains Auto and Auto is selected/checked.

Reaching RAPPORT is not treated as product commitment. If RAPPORT lacks Start Quoting Auto or shows Auto unchecked after a verified Product Overview save, the workflow performs one bounded recovery: click the top/subnav `SELECT PRODUCT`, wait for Product Tile Grid, re-ensure Auto, save again, and re-check RAPPORT Start Quoting. Sidebar Add Product remains disallowed as recovery.

## Patch A6: Product Tile Resolver Restoration

Live Product Tile Grid evidence showed Auto can appear as a non-button tile/card while the generic scan buttons only show Save & Continue and other page controls. That is expected; the resolver must not depend on Auto being a button.

Patch A6 restores the Patch A3 resolver as the single shared path for:

- `product_overview_tile_status`
- `click_product_overview_tile`
- `ensure_product_overview_tile_selected`

The shared resolver now explicitly rejects broad product/grid containers that contain multiple product labels such as Auto, Home, Renters, PUP, Condo, Motorcycle, ORV, Boat, Motorhome, Landlords, or ManufacturedHome. It starts from visible Auto text, resolves the smallest single-product tile/card container, prefers `.l-tile`/tile/card/product/choice/option containers over `.l-grid__col` or broad grids, and then uses the real interactive descendant or the tile/card center as the click target.

New diagnostics include resolver method, text seed tag/text/class, tile container text/class, product label count, broad-container rejection flag, click target tag/class/role, click attempt count, selected before/after, and tile-scoped selected evidence.

Save & Continue enabled still does not count as selected evidence, and the RAPPORT recovery path still calls the same Product Overview handler instead of a separate weaker tile click path.

## Gather Data Continuation Guard

Gather Data Add Product remains guarded. It is allowed only after:

- Product Tile Grid Auto was verified earlier in the run.
- Lead vehicle add/confirm status is complete or safely accepted.
- Start Quoting Auto is present and selected by the stable checkbox id `ConsumerReports.Auto.Product-intel#102`.

Add Product is not used as recovery for missed Product Tile Grid Auto selection.

## Confirmed Vehicle Card Verification

Live validation showed the vehicle could be visibly added under Cars and Trucks / CONFIRMED VEHICLES while the workflow still failed the previous Gather Data vehicle-add step. The verifier now treats a matching confirmed vehicle card as primary success evidence:

- exact year match
- normalized make/model match
- confirmed status text
- confirmed-card context such as CONFIRMED VEHICLES, Edit, or Remove

Potential vehicle cards and unrelated confirmed vehicles do not count. Start Quoting Add product remains allowed only after Product Tile Grid Auto verification, confirmed vehicle evidence, and Start Quoting Auto checked; the sidebar Add Product remains disallowed as recovery.

Continuation validation:

- Initial `node assets/js/advisor_quote/build_operator.js --check` failed with expected drift before generation because the JS template had changed.
- `node assets/js/advisor_quote/build_operator.js` passed and generated `assets/js/advisor_quote/ops_result.js`.
- Final `node assets/js/advisor_quote/build_operator.js --check` passed.
- `node .\tests\advisor_quote_ops_smoke.js` passed using bundled Codex Node.
- `powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\Test-AhkToolchain.ps1` passed: `SMOKE_VALIDATE=pass`, `MAIN_VALIDATE=pass`, `COMPILER_CHECK=skipped`.
- Toolchain artifact: `logs\toolchain_checks\20260429_130908`.
- `ops_result.js` before confirmed-vehicle-card patch: `62FA7C94C7ED836F02649E09E72C1D0C1D3524E01430E50D686DDEDDAC02A894`.
- `ops_result.js` after confirmed-vehicle-card patch: `DF1F473FC9B759458798611D4CE0BD7182B620A30F44B2D67C1CD62001CD49BB`.

## Address Verification During Create New Prospect

Advisor Pro can present Address Verification as an intermediate state on `/apps/intel/102/start` after Create New Prospect submit. This is still part of `ENTRY_CREATE_FORM`; it must resolve before duplicate, Customer Summary, Product Tile, Gather Data, or ASC handling.

The resolver now:

- detects Address Verification by `Address Verification`, `You Entered`, `Did You Mean?`, `snaOption` radios, and `Continue with Selected`.
- chooses the safest `snaOption` radio by matching the parsed lead address against the entered/suggested addresses.
- rejects different street suffixes when the lead has an explicit suffix.
- prefers the USPS-normalized suggestion when it is the same base address and adds ZIP+4 or standardization.
- clicks `Continue with Selected` only after the selected radio enables it.
- does not use the lower Create New Prospect button while Address Verification choices exist.

Ambiguous or unsafe suggestions fail safely with Address Verification diagnostics instead of blindly choosing the first suggestion.
