[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ExePath,

    [string[]]$Arguments = @(),

    [int]$TimeoutSeconds = 5,

    [string]$WorkingDirectory = (Get-Location).Path,

    [string]$Label = "ahk-check"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Coalesce-String {
    param([AllowNull()][object]$Value)
    if ($null -eq $Value) {
        return ""
    }
    return [string]$Value
}

function ConvertTo-CommandLine {
    param([string[]]$Items)

    $quoted = foreach ($item in @($Items)) {
        $text = Coalesce-String $item
        if ($text -eq "") {
            '""'
            continue
        }
        if ($text -notmatch '[\s"]') {
            $text
            continue
        }
        '"' + ($text -replace '(\\*)"', '$1$1\"') + '"'
    }

    return ($quoted -join " ")
}

function Stop-ProcessTree {
    param(
        [Parameter(Mandatory = $true)]
        [int]$ProcessId
    )

    try {
        $children = Get-CimInstance Win32_Process -Filter "ParentProcessId = $ProcessId" -ErrorAction Stop
        foreach ($child in $children) {
            Stop-ProcessTree -ProcessId ([int]$child.ProcessId)
        }
    } catch {
    }

    try {
        Stop-Process -Id $ProcessId -Force -ErrorAction Stop
    } catch {
    }
}

function New-CheckedResult {
    param(
        [string]$Status,
        [bool]$TimedOut,
        [Nullable[int]]$ExitCode,
        [string]$StdOut,
        [string]$StdErr,
        [int]$DurationMs,
        [string]$ErrorMessage = ""
    )

    return [pscustomobject]@{
        label            = $Label
        exePath          = $ExePath
        arguments        = @($Arguments)
        workingDirectory = $WorkingDirectory
        timeoutSeconds   = $TimeoutSeconds
        timedOut         = $TimedOut
        status           = $Status
        exitCode         = $ExitCode
        durationMs       = $DurationMs
        stdout           = Coalesce-String $StdOut
        stderr           = Coalesce-String $StdErr
        errorMessage     = Coalesce-String $ErrorMessage
    }
}

$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

if ([string]::IsNullOrWhiteSpace($ExePath)) {
    $stopwatch.Stop()
    return New-CheckedResult -Status "invalid-input" -TimedOut $false -ExitCode $null -StdOut "" -StdErr "" -DurationMs ([int]$stopwatch.ElapsedMilliseconds) -ErrorMessage "ExePath was empty."
}

if (-not (Test-Path -LiteralPath $ExePath)) {
    $stopwatch.Stop()
    return New-CheckedResult -Status "missing-exe" -TimedOut $false -ExitCode $null -StdOut "" -StdErr "" -DurationMs ([int]$stopwatch.ElapsedMilliseconds) -ErrorMessage "Executable not found."
}

if (-not (Test-Path -LiteralPath $WorkingDirectory)) {
    $stopwatch.Stop()
    return New-CheckedResult -Status "missing-working-directory" -TimedOut $false -ExitCode $null -StdOut "" -StdErr "" -DurationMs ([int]$stopwatch.ElapsedMilliseconds) -ErrorMessage "Working directory not found."
}

$psi = [System.Diagnostics.ProcessStartInfo]::new()
$psi.FileName = $ExePath
$psi.Arguments = ConvertTo-CommandLine -Items $Arguments
$psi.WorkingDirectory = $WorkingDirectory
$psi.UseShellExecute = $false
$psi.CreateNoWindow = $true
$psi.RedirectStandardOutput = $true
$psi.RedirectStandardError = $true

$process = [System.Diagnostics.Process]::new()
$process.StartInfo = $psi

try {
    [void]$process.Start()
} catch {
    $stopwatch.Stop()
    return New-CheckedResult -Status "start-failed" -TimedOut $false -ExitCode $null -StdOut "" -StdErr "" -DurationMs ([int]$stopwatch.ElapsedMilliseconds) -ErrorMessage $_.Exception.Message
}

$stdoutTask = $process.StandardOutput.ReadToEndAsync()
$stderrTask = $process.StandardError.ReadToEndAsync()
$timeoutMs = [Math]::Max(1000, $TimeoutSeconds * 1000)
$timedOut = -not $process.WaitForExit($timeoutMs)

if ($timedOut) {
    Stop-ProcessTree -ProcessId $process.Id
    try {
        $null = $process.WaitForExit(1000)
    } catch {
    }
}

try {
    [void][System.Threading.Tasks.Task]::WaitAll(@($stdoutTask, $stderrTask), 1500)
} catch {
}

$stdout = if ($stdoutTask.IsCompleted) { $stdoutTask.Result } else { "" }
$stderr = if ($stderrTask.IsCompleted) { $stderrTask.Result } else { "" }
$exitCode = $null

if ($process.HasExited) {
    $exitCode = $process.ExitCode
}

$stopwatch.Stop()

if ($timedOut) {
    return New-CheckedResult -Status "timeout" -TimedOut $true -ExitCode $exitCode -StdOut $stdout -StdErr $stderr -DurationMs ([int]$stopwatch.ElapsedMilliseconds)
}

return New-CheckedResult -Status "exited" -TimedOut $false -ExitCode $exitCode -StdOut $stdout -StdErr $stderr -DurationMs ([int]$stopwatch.ElapsedMilliseconds)
