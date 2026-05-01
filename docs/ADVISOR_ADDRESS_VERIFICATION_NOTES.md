# Advisor Address Verification Notes

## Live Failure Shape

Advisor Pro can keep the browser at `/apps/intel/102/start` after Create New Prospect submit and open an Address Verification choice set inside the Create New Prospect page.

Observed page evidence:

- `Address Verification`
- `You Entered`
- `Did You Mean?`
- radios named `snaOption`
- `Continue with Selected`
- the lower `Create New Prospect` form button still present

The lower Create New Prospect button is not the resolution action while `snaOption` choices are present.

## Radio Group

Address Verification uses:

- `input[name="snaOption"][value="0"]` for `You Entered`
- `input[name="snaOption"][value="1"]` for the first suggestion
- `input[name="snaOption"][value="2"]` for the second suggestion

The operator first targets by row/container text. Value/order is only a fallback after the chosen option text is known.

## Matching Rules

The resolver compares the parsed lead address to each modal option using:

- street number
- street direction
- street name
- street suffix
- city
- state
- ZIP5
- ZIP+4 as a small positive USPS-normalization signal
- unit/apartment when present

If the lead contains an explicit suffix, a different suffix is rejected. For example, `Ct` does not match `St`.

If the entered address and a suggested address represent the same base address, the suggested USPS-normalized address is preferred when it adds ZIP+4, standardized suffix/casing, or fuller postal detail.

If the lead suffix is missing or ambiguous and multiple suggestions tie, the resolver returns `AMBIGUOUS` and does not click Continue.

## Continue Targeting

After selecting the identified `snaOption` radio, the operator verifies the radio is checked, waits briefly for `Continue with Selected` to enable, and clicks only that button.

If Continue remains disabled after radio selection, the result is:

```text
result=FAILED
method=address-radio-continue-disabled
failedFields=continueWithSelected
continueClicked=0
```

## ENTRY_CREATE_FORM Handling

Address Verification is treated as an `ENTRY_CREATE_FORM` intermediate state. The workflow checks for it before refilling/resubmitting the Create New Prospect form and shortly after the primary submit.

Safe forward states after successful Address Verification are unchanged:

- `DUPLICATE`
- `CUSTOMER_SUMMARY_OVERVIEW`
- `PRODUCT_OVERVIEW`
- `RAPPORT`
- `SELECT_PRODUCT`
- `ASC_PRODUCT`
- `INCIDENTS`
