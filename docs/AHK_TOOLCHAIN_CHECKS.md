# AHK Toolchain Checks

Use the repo toolchain checker instead of running raw AutoHotkey diagnostics from the shell.

## Why `AutoHotkeyUX.exe /?` Is Banned

`AutoHotkeyUX.exe` is a UX launcher, not the recommended interpreter target for diagnostics. In this environment it has repeatedly stalled or returned no useful output, which makes automated checks unreliable.

## Why `Ahk2Exe.exe /?` Is Banned

`Ahk2Exe.exe /?` has also stalled locally and is not a safe health check. Compiler commands should only be tested after command-line syntax is verified from local source or docs, and every invocation must go through the timeout wrapper.

## Recommended Interpreter

Use the AutoHotkey v2 interpreter directly. In this repo the preferred path is:

`%LOCALAPPDATA%\Programs\AutoHotkey\v2\AutoHotkey64.exe`

The toolchain checker discovers all local candidates and prints the recommended path it selected.

## How To Run The Toolchain Check

Run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\Test-AhkToolchain.ps1
```

This script only uses the timeout-backed wrapper at `tools\Invoke-AhkChecked.ps1`.

## What The Outputs Mean

- `FOUND_INTERPRETER`: the interpreter chosen for validation
- `FOUND_COMPILER`: the compiler path if one was found locally
- `VALIDATE_SUPPORTED`: whether `/Validate` appears safe and supported
- `SMOKE_VALIDATE`: result of the smoke validation or guarded fallback
- `MAIN_VALIDATE`: result of validating or guarded-loading `main.ahk`
- `COMPILER_CHECK`: `pass`, `fail`, `skipped`, or `timeout`
- `RECOMMENDED_AHK_EXE`: interpreter path to use for future checks
- `RECOMMENDED_AHK2EXE`: compiler path if available

Per-run JSON artifacts are written under `logs\toolchain_checks`.

## What To Do On Timeout

If a check times out:

1. Do not retry the raw executable command directly.
2. Review the JSON artifact under `logs\toolchain_checks`.
3. Treat the timeout as a toolchain failure first, not as proof that the target script is bad.
4. Fix the wrapper or the guarded validation path before resuming workflow refactors.
