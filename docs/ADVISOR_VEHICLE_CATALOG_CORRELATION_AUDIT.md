# Advisor Vehicle Catalog Correlation Audit

## 1. Executive summary

The current small alias approach is not strong enough for Advisor Pro vehicle reconciliation. Advisor separates some lead-facing makes into operational manufacturer buckets: Toyota SUVs/trucks appear under `TOY. TRUCKS`, Ford trucks and vans are separate from `FORD`, Chevrolet trucks/vans are `CHEVY TRUCKS` and `CHEVY VANS`, Dodge/Ram is split across five labels, and Mercedes-Benz appears as `MERCEDES-BNZ`.

The correct architecture is:

- crawler DB = source evidence
- generated compact catalog summary = domain/data layer evidence
- injected JS operator = DOM reader/clicker only
- AHK/domain logic = business ownership for make/model correlation, partial-vehicle promotion, defer/manual policy, and final reconciliation

Do not inject the full crawler DB into `assets/js/advisor_quote/ops_result.js`. The crawler rows are large, include submodel-level data, and would bloat the DevTools payload for logic that belongs in a durable domain helper. The JS operator should receive already-normalized matching intent and return page evidence.

Current source mostly respects the 102-vs-downstream separation. `AdvisorQuoteClassifyGatherVehicles()` in `workflows/advisor_quote_workflow.ahk:1824` classifies actionable and deferred vehicles. `AdvisorQuoteGetGatherConfirmedVehiclesStatusForVehicles()` at `workflows/advisor_quote_workflow.ahk:1931` passes structured expected vehicles to JS. The gap is that the expected vehicle matching is not yet catalog-aware enough to understand Advisor manufacturer buckets.

## 2. Input files and coverage

Primary files analyzed:

- `C:\Users\sflzsl7k\Downloads\advisorpro_vehicle_db_RESUME_2017_2026_v7_2026-04-29_15-14-18-388_MANIFEST.json`
- `C:\Users\sflzsl7k\Downloads\advisorpro_vehicle_db_RESUME_2017_2026_v7_2026-04-29_15-14-18-388_ROWS_CHUNK_0000.json`
- `C:\Users\sflzsl7k\Downloads\advisorpro_vehicle_db_RESUME_2017_2026_v7_2026-04-29_15-14-18-388_ROWS_CHUNK_0001.json`
- `C:\Users\sflzsl7k\Downloads\advisorpro_vehicle_db_RESUME_2017_2026_v7_2026-04-29_15-14-18-388_ROWS_CHUNK_0002.json`
- `C:\Users\sflzsl7k\Downloads\advisorpro_vehicle_db_RESUME_2017_2026_v7_2026-04-29_15-14-18-388_DIAGNOSTICS_CHUNK_0000.json`

Older v6 files were present under Downloads, but this audit treats the named v7 files above as primary input.

Coverage from manifest and rows:

| Field | Value |
|---|---:|
| runId | `2026-04-29_15-14-18-388` |
| startedAt | `2026-04-29T15:14:18.388Z` |
| finishedAt | `2026-04-29T15:28:27.880Z` |
| finalStatus | `finished` |
| manifest config `startYear` | `2017` |
| manifest config `endYear` | `2018` |
| actual row years found | `2017`, `2018` |
| total rows loaded | `12590` |
| OK rows | `12588` |
| non-OK rows | `2` |
| manufacturer labels | `110` |
| manufacturer/model pairs | `516` |
| distinct model names | `487` |
| row chunks | `3` |
| diagnostic chunks | `1` |
| warnings | `5` |
| errors | `0` |

Important correction: the filename and file base name say `2017_2026`, but the manifest contents say `startYear=2017` and `endYear=2018`, and the row data only contains 2017 and 2018. This is partial coverage, not full 2017-2026 coverage.

Diagnostics:

- 2017 `MAKE NOT FOUND` / `MODEL NOT FOUND` had no submodels.
- 2018 `MAKE NOT FOUND` / `MODEL NOT FOUND` had no submodels.
- `AVALON` submodel child load retried twice after timeout, with options present.
- `COROLLA` submodel child load retried once after timeout, with options present.

## 3. Catalog row schema

Fields found in row chunks:

- `year`
- `vehicleType`
- `manufacturer`
- `manufacturerValue`
- `manufacturerNorm`
- `model`
- `modelValue`
- `modelNorm`
- `subModel`
- `subModelValue`
- `subModelNorm`
- `trim`
- `bodyType`
- `engineOrFuel`
- `drivetrain`
- `cylinders`
- `doors`
- `vinPattern`
- `yearMakeKey`
- `yearMakeModelKey`
- `correlationKey`
- `status`
- `note`

Useful ownership:

| Field group | Use |
|---|---|
| `manufacturer`, `manufacturerNorm` | Advisor manufacturer bucket and make-family mapping |
| `model`, `modelNorm` | Advisor model spelling, model split, and normalized exact matching |
| `trim`, `bodyType`, `drivetrain` | submodel selection and trim-sensitive matches |
| `vinPattern` | VIN-aware submodel choice and future public-record promotion |
| `yearMakeKey`, `yearMakeModelKey` | compact lookup/index generation |
| `status`, `note` | crawler quality diagnostics |

For final confirmed-card reconciliation, the useful fields are year, manufacturer family, model normalization, and optional VIN/VIN suffix. For Sub-Model selection, the live dropdown option text and VIN pattern remain primary; the catalog can guide future tests but should not override live options.

## 4. Manufacturer family analysis

| Family | Advisor labels found | Year coverage | Model examples | Risk | Alias safety |
|---|---|---|---|---|---|
| Toyota | `TOYOTA`, `TOY. TRUCKS` | 2017-2018 | `COROLLA`, `PRIUS`, `SIENNA`; `HIGHLANDER`, `RAV4`, `TACOMA` | medium | Requires model context |
| Ford | `FORD`, `FORD TRUCKS`, `FORD VANS` | 2017-2018 | `FUSION`, `MUSTANG`; `F150 2WD`; `TRANSIT` | high | Requires model context |
| Chevrolet | `CHEVROLET`, `CHEVY TRUCKS`, `CHEVY VANS` | 2017-2018 | `MALIBU`; `SILV1500 4WD`; `EXPRESS G25` | high | Requires model context |
| Dodge/Ram | `DODGE`, `DODGE TRUCKS`, `DODGE VANS`, `RAM TRUCKS`, `RAM VANS` | 2017-2018 | `CHARGER`; `DURANGO`; `GRAND CARAVN`; `1500 4WD`; `PROMAST CITY` | high | Contextual only |
| Mercedes | `MERCEDES-BNZ` | 2017-2018 | `C300`, `GLE350`, `GLC300`, `SPRINTER` | low/medium | Safe make alias, model still exact |
| Honda | `HONDA` | 2017-2018 | `ACCORD`, `CR-V`, `PILOT`, `RIDGELINE` | low | Direct |
| Acura | `ACURA` | 2017-2018 | `ILX`, `MDX`, `RDX`, `TLX` | low | Direct |
| BMW | `BMW` | 2017-2018 | `X3`, `X5`, `330I`, `530I` | low | Direct |
| Hyundai | `HYUNDAI` | 2017-2018 | `ELANTRA`, `KONA`, `SANTA FE`, `TUCSON` | low | Direct |
| Mazda | `MAZDA` | 2017-2018 | `3`, `6`, `CX-3`, `CX-5`, `CX-9` | medium | Direct make, model normalization needed |
| Nissan | `NISSAN` | 2017-2018 | `ALTIMA`, `FRONTIER`, `ROGUE`, `NV1500`, `NV200` | medium | Direct make, van/truck models still under Nissan |
| Jeep | `JEEP` | 2017-2018 | `CHEROKEE`, `GRND CHEROKE`, `WRANGLER` | medium | Direct make, model spelling needs rules |
| GMC | `GMC` | 2017-2018 | `ACADIA`, `CANYON`, `SIERA15004WD`, `SAVANA G3500` | medium | Direct make, model spelling needs rules |
| Kia | `KIA` | 2017-2018 | `FORTE`, `SORENTO`, `SPORTAGE`, `SOUL` | low | Direct |
| Volkswagen | `VOLKSWAGEN` | 2017-2018 | `ATLAS`, `GOLF`, `JETTA`, `TIGUAN` | low | Direct |
| Lexus | `LEXUS` | 2017-2018 | `RX350`, `NX300`, `GX460`, `LX570` | medium | Direct make, compact model normalization |
| Infiniti | `INFINITI` | 2017-2018 | `Q50`, `QX30`, `QX60`, `QX80` | medium | Direct make, compact model normalization |

Do not collapse unrelated makes. In particular, do not make Dodge and Ram globally equivalent.

## 5. Dodge/Ram analysis

Advisor labels found:

- `DODGE`: `CHALLENGER`, `CHARGER`, `VIPER`
- `DODGE TRUCKS`: `DURANGO`, `JOURNEY`
- `DODGE VANS`: `GRAND CARAVN`
- `RAM TRUCKS`: `1500 2WD`, `1500 4WD`, `2500 2WD`, `2500 4WD`, `3500 2WD`, `3500 4WD`
- `RAM VANS`: `1500 PROMAST`, `2500 PROMAST`, `3500 PROMAST`, `PROMAST CITY`

Questions answered from catalog evidence:

- RAM 1500/2500/3500-style models are under `RAM TRUCKS`, split by 2WD/4WD.
- The 2017-2018 data does not show `Dodge Ram` as a Dodge model. A lead saying `Dodge Ram 1500` should be treated as a contextual mapping to `RAM TRUCKS` only when year/model evidence supports it.
- `Grand Caravan` appears as `GRAND CARAVN` under `DODGE VANS`.
- `Durango` and `Journey` are under `DODGE TRUCKS`.
- `Charger`, `Challenger`, and `Viper` remain under `DODGE`.
- `Dakota` does not appear in 2017-2018 v7 coverage, so any Dakota rule needs older-year catalog evidence.

Recommended Dodge/Ram rule table:

| Lead text | Recommended Advisor bucket | Confidence | Reason |
|---|---|---|---|
| `Ram 1500` | `RAM TRUCKS` | high for 2017-2018 | direct RAM truck model bucket |
| `Dodge Ram 1500` | `RAM TRUCKS` | contextual-high | likely legacy lead wording; require catalog year support |
| `Ram 2500` / `Ram 3500` | `RAM TRUCKS` | high for 2017-2018 | direct RAM truck model bucket |
| `Ram Promaster` | `RAM VANS` | high for 2017-2018 | direct RAM van bucket |
| `Dodge Charger` | `DODGE` | high | direct Dodge car model |
| `Dodge Challenger` | `DODGE` | high | direct Dodge car model |
| `Dodge Grand Caravan` | `DODGE VANS` | medium/high | catalog spells model as `GRAND CARAVN` |
| `Dodge Durango` | `DODGE TRUCKS` | high | direct Dodge Trucks model |
| `Dodge Journey` | `DODGE TRUCKS` | high | direct Dodge Trucks model |
| `Dodge Dakota` | defer/manual unless older catalog confirms | low with this data | absent from 2017-2018 v7 rows |
| `Dodge Caravan` | likely `DODGE VANS`, but require card/model evidence | medium | catalog only shows `GRAND CARAVN` |

## 6. Trucks/Vans family analysis

| Lead make | Car label | Truck/SUV label | Van label | Safe model triggers |
|---|---|---|---|---|
| Toyota | `TOYOTA` | `TOY. TRUCKS` | no separate Toyota vans label in this data | `HIGHLANDER`, `RAV4`, `4RUNNER`, `TACOMA`, `TUNDRA`, `SEQUOIA`, `C-HR`, `LAND CRUISER` |
| Ford | `FORD` | `FORD TRUCKS` | `FORD VANS` | `F150/F250/F350/F450`, `EXPLORER`, `EXPEDITION`, `ESCAPE`, `EDGE`, `ECOSPORT`, `FLEX`; `TRANSIT` for vans |
| Chevrolet | `CHEVROLET` | `CHEVY TRUCKS` | `CHEVY VANS` | `SILVERADO/SILV1500/SILV2500/SILV3500`, `TAHOE`, `SUBURBAN`, `TRAVERSE`, `EQUINOX`, `COLORADO`; `EXPRESS`, `CITY EXPRESS` for vans |
| Dodge/Ram | `DODGE` | `DODGE TRUCKS`, `RAM TRUCKS` | `DODGE VANS`, `RAM VANS` | `DURANGO`, `JOURNEY`; `RAM 1500/2500/3500`; `GRAND CARAVAN`, `PROMASTER` |

Recommended special-case table:

| Lead make/model pattern | Advisor manufacturer | Evidence | Risk |
|---|---|---|---|
| Toyota Highlander | `TOY. TRUCKS` | `HIGHLANDER` rows under `TOY. TRUCKS`, 2017-2018 | low for covered years |
| Toyota Corolla | `TOYOTA` | `COROLLA` rows under `TOYOTA`, 2017-2018 | low |
| Toyota Prius | `TOYOTA` | `PRIUS` rows under `TOYOTA`; Prime appears as trim | medium |
| Ford F-150/F150 | `FORD TRUCKS` | `F150 2WD/4WD` rows, 2017-2018 | low |
| Ford Transit | `FORD VANS` | `TRANSIT`, `TRANSIT CONN` rows | low |
| Chevy Silverado | `CHEVY TRUCKS` | `SILV1500/2500/3500` rows | medium: model abbreviation mapping |
| Chevy Express | `CHEVY VANS` | `EXPRESS G25/G35`, `CITY EXPRESS` rows | low/medium |
| Dodge Ram 1500 | `RAM TRUCKS` | RAM model rows exist, Dodge Ram wording is legacy/user-facing | medium: require year/model context |
| Mercedes-Benz any covered model | `MERCEDES-BNZ` | only Mercedes label found is `MERCEDES-BNZ` | low for make mapping |

## 7. Model normalization analysis

Needed normalization rules:

- compact punctuation/space variants for alphanumeric models: `F-150`, `F 150`, and `F150`; `F-250`, `F 250`, `F250`
- compact luxury/SUV model numbers: `RX350` vs `RX 350`, `QX60` vs `QX 60`, `GLE350` vs `GLE 350`
- preserve hyphenated named models where catalog uses hyphen: `CR-V`, `CX-3`, `CX-5`, `CX-9`
- Advisor-specific Toyota spelling: `4 RUNNER` should match `4Runner` / `4 runner`
- Advisor-specific Chevrolet abbreviation: `SILV1500` family should map to `Silverado 1500`
- Advisor-specific Dodge spelling: `GRAND CARAVN` should map to `Grand Caravan`
- preserve material trim/model words such as `Prime`; do not collapse `Prius Prime` into plain `Prius`

Do not add broad fuzzy matching that overmatches contains-only strings. Risk examples:

- `PRIUS` vs `PRIUS PRIME`
- `TRANSIT` vs `TRANSIT CONN`
- `EXPRESS` vs `CITY EXPRESS`
- `F150` vs `F250`
- `SILV1500` vs `SILV2500`

## 8. Partial vehicle policy using catalog

Definitions:

- `completeActionable`: year + make + model
- `partialYearMake`: year + make only, model missing or too vague
- `missingYear`: make/model present but year missing
- `vinOnlyOrVinDeferred`: VIN exists but year/make/model incomplete

Recommended policy:

- Complete actionable vehicles use exact year plus catalog-normalized make/model.
- Partial year+make may be promoted in 102 only when live Advisor public-record potential vehicles show exactly one same-year/same-make-family candidate with visible VIN.
- If multiple candidates exist, defer/manual.
- If no visible VIN exists, defer/manual.
- Missing-year remains deferred to ASC/109 unless future strict public-record/VIN rules are implemented there.
- VIN-only/incomplete vehicles remain deferred for future VIN-aware ASC/109 handling.

The catalog can constrain legal make/model buckets, but it must not override live page evidence. Promotion still needs a single scoped potential card, exact year, make family support, and VIN-bearing evidence.

## 9. Confirmed-card matching policy

For complete vehicles:

- exact year required
- make family match allowed only when catalog-supported
- normalized model exact match required
- VIN/VIN suffix preferred when available
- trim-sensitive model words must be respected

Examples:

- expected Toyota Highlander should match confirmed `Toy. trucks HIGHLANDER`
- expected Toyota Corolla should match confirmed `Toyota COROLLA`
- expected Toyota Prius should not match Toyota Prius Prime unless the lead explicitly includes Prime and live/card/VIN evidence supports Prime
- expected Ford F-150 should match `Ford Trucks F150 2WD` or `F150 4WD` if the visible card model family is F150
- expected Dodge Ram 1500 should match `RAM TRUCKS 1500 2WD/4WD` when year/catalog support exists
- expected Mercedes-Benz GLE350 should match `MERCEDES-BNZ GLE350`

## 10. Potential-vehicle confirmation policy

A potential public-record vehicle can be confirmed if:

- card scope is a single potential vehicle card/row
- exact year matches
- make family/crosswalk matches
- model matches when the lead has a model
- visible VIN is preferred for complete vehicles and required for partial promotion

Do not confirm:

- broad Cars and Trucks containers
- multiple candidates
- different year
- different model
- different make family
- Prius vs Prius Prime mismatch
- Dodge vs Ram mismatch unless the catalog crosswalk supports that year/model case

This preserves the existing broad-container rejection and prevents catalog aliases from becoming a new way to confirm unrelated public-record vehicles.

## 11. Proposed compact runtime mapping

Generated compact artifact:

`data/advisor_vehicle_catalog_summary.json`

It is about 10 KB and contains:

- source run and coverage metadata
- manufacturer family buckets
- compact model lists per Advisor manufacturer label
- model rules for common truck/van/SUV splits
- normalization cautions
- unsafe/context-required cases

The proposed runtime shape is:

```json
{
  "version": "advisor-vehicle-catalog-summary-v1",
  "coverage": { "years": [2017, 2018], "rowCount": 12590 },
  "manufacturerFamilies": {
    "toyota": {
      "advisorLabels": ["TOYOTA", "TOY. TRUCKS"],
      "requiresModelContext": true
    }
  },
  "modelRules": [
    {
      "leadMake": "ford",
      "leadModelPattern": "^f\\s*-?\\s*(150|250|350|450)\\b",
      "advisorManufacturer": "FORD TRUCKS",
      "confidence": "high"
    }
  ],
  "unsafeOrNeedsContext": []
}
```

Do not include all submodel rows in runtime. Submodel selection should still use live dropdown options and VIN pattern matching.

## 12. Runtime integration plan

Future ownership:

- domain helper: normalization, catalog loading, make-family/model correlation, compact rule lookup
- AHK workflow: business policy, lead vehicle classification, partial promotion, final decisions
- JS operator: read/click live DOM and report evidence

Integration design:

1. Add a domain-level helper that loads `data/advisor_vehicle_catalog_summary.json`.
2. Normalize lead make/model into a catalog correlation object.
3. Pass JS ops both the lead-normalized text and allowed Advisor manufacturer labels/model variants.
4. Update confirmed-card matching to accept catalog-supported make-family labels while retaining exact year and normalized model.
5. Update potential-card confirmation to require single-card scope plus catalog-supported family/model match.
6. Add partial year+make promotion only when one same-year/same-family VIN-bearing candidate exists.
7. Keep deferred/missing-year logic for ASC/109.

Do not make the JS operator parse the catalog. It should receive compact args and return page facts.

## 13. Immediate recommended next runtime patch

Recommended next patch:

Add a compact domain-level vehicle catalog correlation helper and use it only for confirmed-card make aliasing first.

Why this first:

- It directly addresses the Toyota Highlander vs `Toy. trucks HIGHLANDER` failure class.
- It is smaller and safer than partial-vehicle promotion.
- It keeps exact year and exact normalized model requirements.
- It can be covered with helper tests and JS smoke fixtures without changing add/confirm policy yet.

Patch shape:

- Add `domain/advisor_vehicle_catalog.ahk` or similar helper.
- Load/read the compact JSON summary from `data/`.
- Produce allowed Advisor manufacturer labels for a complete year/make/model vehicle.
- Pass those labels to confirmed-card reconciliation, or add a bounded JS arg for allowed manufacturer labels.
- Add tests for Toyota Highlander, Toyota Corolla, Ford F-150, Chevy Silverado, Dodge Ram 1500, Mercedes-Benz, Prius/Prius Prime mismatch.

Partial year+make promotion should be a later patch.

## 14. Tests to add later

Required tests:

- Toyota Highlander matches `Toy. trucks HIGHLANDER`
- Toyota Corolla matches `Toyota COROLLA`
- Toyota Prius does not match Toyota Prius Prime
- Toyota Prius Prime requires Prime trim/VIN/public-record evidence
- Ford F-150 maps to `FORD TRUCKS`
- Ford Transit maps to `FORD VANS`
- Chevy Silverado maps to `CHEVY TRUCKS`
- Chevy Express maps to `CHEVY VANS`
- Dodge Ram 1500 maps to `RAM TRUCKS` when catalog supports the year/model
- Dodge Charger remains `DODGE`
- Dodge Grand Caravan maps to `DODGE VANS` / `GRAND CARAVN`
- Mercedes-Benz maps to `MERCEDES-BNZ`
- Mazda partial `2021 Mazda` promotes only with one VIN-bearing candidate after future coverage exists
- ambiguous partial candidates defer

## 15. Coverage gaps and crawler next steps

Gaps:

- The v7 files only cover 2017-2018, despite the filename.
- The user examples include 2019 and newer vehicles, but this v7 data cannot prove 2019-2026 behavior.
- Common leads can include older vehicles before 2017; the provided v7 set cannot support those.
- `Dodge Dakota` requires older-year catalog evidence.
- `Mazda CX-30` is not in the 2017-2018 data; it needs 2020+ coverage.
- Prius Prime appears as `PRIUS` trim `PRIME` in 2017-2018, so model-vs-trim handling needs explicit tests.

Recommended crawler next steps:

- Run/collect full 2019-2026 coverage for current/live Advisor years.
- Keep or collect 1981-2016 coverage for older lead vehicles.
- Re-run any year ranges with non-OK/warning diagnostics if they involve high-volume makes/models.
- Generate a compact summary from all complete chunks rather than using raw rows at runtime.

## Terminal summary

Primary v7 crawler files were found in Downloads, not the repo. Manifest and rows prove coverage is 2017-2018 only. A compact summary was generated at `data/advisor_vehicle_catalog_summary.json`; no workflow or JS runtime behavior was changed.

## Implementation Note: Confirmed-Card Make Correlation

The first runtime slice from this audit has been implemented for confirmed-card evidence only.

- `domain/advisor_vehicle_catalog.ahk` owns compact make/model correlation rules derived from the summary.
- Gather Data final expected vehicles now carry optional allowed Advisor make labels into confirmed-card status ops.
- `gather_vehicle_add_status` and `gather_confirmed_vehicles_status` can use those labels when present, while keeping existing return values.
- `2019 Toyota Highlander` can match `2019 Toy. trucks HIGHLANDER`.
- Strict year/model matching remains in force; `Toyota Prius` does not match `Toyota Prius Prime`.
- Partial promotion, potential-card confirmation behavior, row dropdown behavior, and ASC/109 handling remain future work.
