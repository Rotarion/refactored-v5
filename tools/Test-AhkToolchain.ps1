[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$wrapperPath = Join-Path $PSScriptRoot "Invoke-AhkChecked.ps1"
$logsRoot = Join-Path $repoRoot "logs"
$toolchainRoot = Join-Path $logsRoot "toolchain_checks"
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$runRoot = Join-Path $toolchainRoot $timestamp

New-Item -ItemType Directory -Force -Path $runRoot | Out-Null

function Write-Section {
    param([string]$Title)
    Write-Host ""
    Write-Host "[$Title]"
}

function Coalesce-String {
    param([AllowNull()][object]$Value)
    if ($null -eq $Value) {
        return ""
    }
    return [string]$Value
}

function ConvertTo-AhkQuotedPath {
    param([string]$Path)
    return '"' + ((Coalesce-String $Path) -replace '"', '""') + '"'
}

function Get-VersionText {
    param([string]$Path)
    try {
        $item = Get-Item -LiteralPath $Path -ErrorAction Stop
        $version = $item.VersionInfo.FileVersion
        if ([string]::IsNullOrWhiteSpace($version)) {
            $version = $item.VersionInfo.ProductVersion
        }
        return (Coalesce-String $version)
    } catch {
        return ""
    }
}

function Get-FileKind {
    param([string]$Path)
    $name = [System.IO.Path]::GetFileName($Path)
    if ($name -ieq "Ahk2Exe.exe") {
        return "compiler"
    }
    if ($name -ieq "AutoHotkeyUX.exe") {
        return "ux-launcher"
    }
    return "interpreter"
}

function Get-AhkCandidates {
    $roots = @(
        (Join-Path $env:LOCALAPPDATA "Programs\AutoHotkey"),
        (Join-Path $env:ProgramFiles "AutoHotkey"),
        (Join-Path ${env:ProgramFiles(x86)} "AutoHotkey")
    ) | Where-Object { $_ -and (Test-Path -LiteralPath $_) }

    $wantedNames = @(
        "AutoHotkey64.exe",
        "AutoHotkey32.exe",
        "AutoHotkey.exe",
        "AutoHotkeyUX.exe",
        "Ahk2Exe.exe"
    )

    $seen = @{}
    $results = @()

    foreach ($root in $roots) {
        $files = Get-ChildItem -LiteralPath $root -Recurse -File -ErrorAction SilentlyContinue |
            Where-Object { $wantedNames -contains $_.Name }

        foreach ($file in $files) {
            if ($seen.ContainsKey($file.FullName)) {
                continue
            }
            $seen[$file.FullName] = $true

            $versionText = Get-VersionText -Path $file.FullName
            $results += [pscustomobject]@{
                kind     = Get-FileKind -Path $file.FullName
                name     = $file.Name
                fullPath = $file.FullName
                version  = $versionText
            }
        }
    }

    return $results | Sort-Object kind, fullPath
}

function Get-InterpreterRank {
    param([pscustomobject]$Candidate)
    $path = $Candidate.fullPath
    $name = $Candidate.name

    if ($Candidate.kind -ne "interpreter") {
        return 999
    }
    if ($path -match '\\v2\\AutoHotkey64\.exe$') {
        return 0
    }
    if ($path -match '\\v2\.[^\\]+\\AutoHotkey64\.exe$') {
        return 1
    }
    if ($name -ieq "AutoHotkey64.exe") {
        return 2
    }
    if ($path -match '\\v2\\AutoHotkey32\.exe$') {
        return 3
    }
    if ($path -match '\\v2\.[^\\]+\\AutoHotkey32\.exe$') {
        return 4
    }
    if ($name -ieq "AutoHotkey32.exe") {
        return 5
    }
    return 10
}

function Get-VersionObject {
    param([string]$VersionText)
    try {
        return [version]($VersionText -replace '[^0-9\.].*$', '')
    } catch {
        return [version]"0.0.0.0"
    }
}

function Select-RecommendedInterpreter {
    param([object[]]$Candidates)

    $interpreters = @($Candidates | Where-Object { $_.kind -eq "interpreter" })
    if (-not $interpreters.Count) {
        return $null
    }

    return $interpreters |
        Sort-Object @{ Expression = { Get-InterpreterRank $_ } }, @{ Expression = { Get-VersionObject $_.version }; Descending = $true }, fullPath |
        Select-Object -First 1
}

function Select-RecommendedCompiler {
    param([object[]]$Candidates)
    return @($Candidates | Where-Object { $_.kind -eq "compiler" } | Select-Object -First 1)[0]
}

function Save-RunResult {
    param(
        [string]$Name,
        [object]$Result
    )

    $path = Join-Path $runRoot ($Name + ".json")
    $Result | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $path -Encoding UTF8
    return $path
}

function Invoke-Checked {
    param(
        [string]$ExePath,
        [string[]]$Arguments,
        [int]$TimeoutSeconds,
        [string]$Label
    )

    return & $wrapperPath -ExePath $ExePath -Arguments $Arguments -TimeoutSeconds $TimeoutSeconds -WorkingDirectory $repoRoot -Label $Label
}

function New-ValidateSmokeScript {
    param(
        [string]$ScriptPath,
        [string]$SentinelPath
    )

    $content = (@(
        '#Requires AutoHotkey v2.0',
        'if (A_Args.Length && A_Args[1] = "__toolchain_validate__") {',
        ('    FileAppend("executed", ' + (ConvertTo-AhkQuotedPath $SentinelPath) + ', "UTF-8")'),
        '    ExitApp(0)',
        '}',
        'MsgBox "syntax smoke test"'
    ) -join "`r`n")
    Set-Content -LiteralPath $ScriptPath -Value $content -Encoding UTF8
}

function New-GuardWrapperScript {
    param(
        [string]$WrapperPath,
        [string]$TargetPath
    )

    $content = (@(
        'if (A_Args.Length && A_Args[1] = "__toolchain_execute_guard__")',
        '    ExitApp(0)',
        ('#Include ' + (ConvertTo-AhkQuotedPath $TargetPath)),
        'ExitApp(0)'
    ) -join "`r`n")
    Set-Content -LiteralPath $WrapperPath -Value $content -Encoding UTF8
}

function Get-CompilerSyntaxEvidence {
    $patterns = @(
        (Join-Path $env:LOCALAPPDATA 'Programs\AutoHotkey\Compiler\Ahk2Exe.ahk'),
        (Join-Path $env:LOCALAPPDATA 'Programs\AutoHotkey\Compiler\*.md'),
        (Join-Path $env:LOCALAPPDATA 'Programs\AutoHotkey\Compiler\*.txt'),
        (Join-Path $env:LOCALAPPDATA 'Programs\AutoHotkey\UX\*.json')
    )

    $foundFiles = @()
    foreach ($pattern in $patterns) {
        $foundFiles += @(Get-ChildItem $pattern -ErrorAction SilentlyContinue)
    }

    $repoHits = Get-ChildItem -Path $repoRoot -Recurse -Include *.md,*.txt,README*,*.ahk -ErrorAction SilentlyContinue |
        Select-String -Pattern 'Ahk2Exe|/Validate|/ErrorStdOut|compiler|AutoHotkey' -ErrorAction SilentlyContinue |
        Select-Object -First 40

    return [pscustomobject]@{
        localCompilerFiles = @($foundFiles | Select-Object -ExpandProperty FullName)
        repoHits           = @($repoHits | ForEach-Object { "{0}:{1}:{2}" -f $_.Path, $_.LineNumber, $_.Line.Trim() })
        verifiedCompileCli = $false
    }
}

$candidates = Get-AhkCandidates
$recommendedInterpreter = Select-RecommendedInterpreter -Candidates $candidates
$recommendedCompiler = Select-RecommendedCompiler -Candidates $candidates
$compilerEvidence = Get-CompilerSyntaxEvidence
$compilerCheck = "skipped"
$validateSupported = "unknown"
$smokeValidate = "fail"
$mainValidate = "fail"

Write-Section "DISCOVERY"
if (-not $candidates.Count) {
    Write-Host "No AutoHotkey candidates found."
} else {
    foreach ($candidate in $candidates) {
        Write-Host ("{0} | {1} | {2} | {3}" -f $candidate.kind, $candidate.version, $candidate.name, $candidate.fullPath)
    }
}

if (-not $recommendedInterpreter) {
    Write-Host ""
    Write-Host "FOUND_INTERPRETER="
    Write-Host "FOUND_COMPILER="
    Write-Host "VALIDATE_SUPPORTED=unknown"
    Write-Host "SMOKE_VALIDATE=fail"
    Write-Host "MAIN_VALIDATE=fail"
    Write-Host "COMPILER_CHECK=skipped"
    Write-Host "RECOMMENDED_AHK_EXE="
    Write-Host "RECOMMENDED_AHK2EXE="
    exit 1
}

$smokePath = Join-Path $runRoot "smoke_validate.ahk"
$smokeSentinel = Join-Path $runRoot "smoke_validate.executed.txt"
$mainPath = Join-Path $repoRoot "main.ahk"
$mainGuardWrapper = Join-Path $runRoot "main_guard_wrapper.ahk"
$smokeGuardWrapper = Join-Path $runRoot "smoke_guard_wrapper.ahk"

New-ValidateSmokeScript -ScriptPath $smokePath -SentinelPath $smokeSentinel
New-GuardWrapperScript -WrapperPath $mainGuardWrapper -TargetPath $mainPath
New-GuardWrapperScript -WrapperPath $smokeGuardWrapper -TargetPath $smokePath

if (Test-Path -LiteralPath $smokeSentinel) {
    Remove-Item -LiteralPath $smokeSentinel -Force
}

$validateProbe = Invoke-Checked -ExePath $recommendedInterpreter.fullPath -Arguments @('/ErrorStdOut', '/Validate', $smokePath, '__toolchain_validate__') -TimeoutSeconds 5 -Label 'validate-smoke-probe'
$validateProbePath = Save-RunResult -Name "validate-smoke-probe" -Result $validateProbe

$probeOutput = ((Coalesce-String $validateProbe.stdout) + "`n" + (Coalesce-String $validateProbe.stderr))

if ($validateProbe.timedOut) {
    $validateSupported = "unknown"
    $smokeValidate = "timeout"
} elseif (Test-Path -LiteralPath $smokeSentinel) {
    $validateSupported = "false"
} elseif ($probeOutput -match '(?i)unknown|invalid|unrecognized|unsupported.+validate|switch.+validate') {
    $validateSupported = "false"
} elseif ($validateProbe.exitCode -eq 0) {
    $validateSupported = "true"
    $smokeValidate = "pass"
} else {
    $validateSupported = "unknown"
    $smokeValidate = "fail"
}

if ($validateSupported -eq "true") {
    $mainResult = Invoke-Checked -ExePath $recommendedInterpreter.fullPath -Arguments @('/ErrorStdOut', '/Validate', $mainPath) -TimeoutSeconds 5 -Label 'validate-main'
    $null = Save-RunResult -Name "validate-main" -Result $mainResult

    if ($mainResult.timedOut) {
        $mainValidate = "timeout"
    } elseif ($mainResult.exitCode -eq 0 -and [string]::IsNullOrWhiteSpace($mainResult.stderr)) {
        $mainValidate = "pass"
    } else {
        $mainValidate = "fail"
    }
} else {
    $smokeFallback = Invoke-Checked -ExePath $recommendedInterpreter.fullPath -Arguments @('/ErrorStdOut', $smokeGuardWrapper, '__toolchain_execute_guard__') -TimeoutSeconds 5 -Label 'fallback-smoke-load'
    $null = Save-RunResult -Name "fallback-smoke-load" -Result $smokeFallback

    if ($smokeFallback.timedOut) {
        $smokeValidate = "timeout"
    } elseif ($smokeFallback.exitCode -eq 0 -and [string]::IsNullOrWhiteSpace($smokeFallback.stderr)) {
        $smokeValidate = "pass"
    } else {
        $smokeValidate = "fail"
    }

    $mainFallback = Invoke-Checked -ExePath $recommendedInterpreter.fullPath -Arguments @('/ErrorStdOut', $mainGuardWrapper, '__toolchain_execute_guard__') -TimeoutSeconds 5 -Label 'fallback-main-load'
    $null = Save-RunResult -Name "fallback-main-load" -Result $mainFallback

    if ($mainFallback.timedOut) {
        $mainValidate = "timeout"
    } elseif ($mainFallback.exitCode -eq 0 -and [string]::IsNullOrWhiteSpace($mainFallback.stderr)) {
        $mainValidate = "pass"
    } else {
        $mainValidate = "fail"
    }
}

if ($recommendedCompiler -and $compilerEvidence.verifiedCompileCli) {
    $compilerCheck = "fail"
} else {
    $compilerCheck = "skipped"
}

$summary = [ordered]@{
    FOUND_INTERPRETER   = $recommendedInterpreter.fullPath
    FOUND_COMPILER      = if ($recommendedCompiler) { $recommendedCompiler.fullPath } else { "" }
    VALIDATE_SUPPORTED  = $validateSupported
    SMOKE_VALIDATE      = $smokeValidate
    MAIN_VALIDATE       = $mainValidate
    COMPILER_CHECK      = $compilerCheck
    RECOMMENDED_AHK_EXE = $recommendedInterpreter.fullPath
    RECOMMENDED_AHK2EXE = if ($recommendedCompiler) { $recommendedCompiler.fullPath } else { "" }
}

Write-Section "ARTIFACTS"
Write-Host ("validate-smoke-probe=" + $validateProbePath)
Write-Host ("runRoot=" + $runRoot)

Write-Section "SUMMARY"
foreach ($key in $summary.Keys) {
    Write-Host ($key + "=" + $summary[$key])
}

if ($compilerCheck -eq "skipped") {
    Write-Host "COMPILER_NOTE=compiler skipped: command syntax not verified from local docs/source"
}

Write-Section "DISCOVERY_JSON"
$candidates | ConvertTo-Json -Depth 4

Write-Section "COMPILER_EVIDENCE"
$compilerEvidence | ConvertTo-Json -Depth 4

if ($smokeValidate -ne "pass" -or $mainValidate -ne "pass") {
    exit 1
}

exit 0
