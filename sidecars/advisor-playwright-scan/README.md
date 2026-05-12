# Advisor Playwright Scan Sidecar

This is the first TypeScript/Playwright sidecar skeleton for scan-only Advisor Pro state reads.

It launches a dedicated Microsoft Edge persistent profile and then only waits for and reads Advisor page state. It does not integrate with AHK and it does not replace the existing Advisor workflow.

## Safety Boundary

- Launches Edge with a dedicated profile directory.
- Does not call Playwright click, fill, press, type, submit, screenshot, or navigation APIs after browser launch.
- Does not call `page.goto`.
- Does not create quotes, save, confirm, remove, or continue.
- Evaluates only allowlisted read-only Advisor operator ops.
- Writes raw scan output under ignored `logs/` paths by default.

Allowlisted ops:

- `advisor_state_snapshot`
- `advisor_active_modal_status`
- `gather_rapport_snapshot`
- `asc_drivers_vehicles_snapshot`
- `scan_current_page`

## Setup

Install dependencies inside this sidecar folder when network access is available:

```powershell
cd .\sidecars\advisor-playwright-scan
npm install
npm run build
```

## Run

```powershell
cd .\sidecars\advisor-playwright-scan
npm run build
node .\dist\index.js --initial-url https://advisorpro.allstate.com/
```

Defaults:

- Edge profile: `logs/playwright-edge-advisor-profile`
- Output: `logs/playwright_ts_advisor_scan_latest.json`
- Target URL token: `advisorpro.allstate.com`

The sidecar opens Edge to the initial URL through the browser launch command. After that it only waits for a matching page and evaluates read-only state readers.
