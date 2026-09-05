<#
.SYNOPSIS
Verifies the Windows background-lifecycle contract of a built desktop binary.

.DESCRIPTION
Phase 0 Task 0.2 requires evidence that closing the window keeps exactly one
background process alive and that a second launch never becomes a second Vault
writer. Those two properties are scriptable, so they are asserted here rather
than left to a witnessed manual check.

The script only ever stops processes it started itself from the given
executable path. It performs no installation and changes no system setting.

Not covered here, and still manual: tray menu rendering, Windows Hello, and the
same contract under an installed MSIX identity.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)] [ValidateNotNullOrEmpty()] [string] $Executable,
    [ValidateNotNullOrEmpty()] [string] $WindowTitle = 'Lokalite Windows Hello Prototype',
    [int] $WindowTimeoutSeconds = 30,
    [int] $SettleTimeoutSeconds = 20,
    # The window handle exists before the webview finishes initializing. Driving
    # the window during startup is not the contract under test, so the first
    # instance is given time to finish coming up.
    [int] $StartupSettleSeconds = 5
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

Add-Type -Namespace LokaliteQa -Name Win32 -MemberDefinition @'
[DllImport("user32.dll", SetLastError = true)]
public static extern bool PostMessage(IntPtr hWnd, uint Msg, IntPtr wParam, IntPtr lParam);

[DllImport("user32.dll")]
public static extern bool IsWindowVisible(IntPtr hWnd);

// className and windowName are IntPtr so they can be passed as a real NULL,
// which is what makes FindWindowExW enumerate every top-level window.
[DllImport("user32.dll", CharSet = CharSet.Unicode)]
public static extern IntPtr FindWindowExW(IntPtr parent, IntPtr childAfter, IntPtr className, IntPtr windowName);

[DllImport("user32.dll")]
public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint processId);

[DllImport("user32.dll", CharSet = CharSet.Unicode)]
public static extern int GetWindowTextW(IntPtr hWnd, System.Text.StringBuilder text, int count);
'@

$WM_CLOSE = 0x0010

$resolved = (Resolve-Path -LiteralPath $Executable).Path
$processName = [System.IO.Path]::GetFileNameWithoutExtension($resolved)

function Get-Instances {
    # Only processes launched from this exact image count as instances.
    $candidates = @(Get-Process -Name $processName -ErrorAction SilentlyContinue)
    return @($candidates | Where-Object {
        try { $_.Path -eq $resolved } catch { $false }
    })
}

# The desktop window is located by its title rather than through
# Process.MainWindowHandle. Single-instance support owns its own top-level helper
# window that Windows reports as visible, so .NET names that one the main window
# once the real one is hidden. Closing the helper would break the very mechanism
# under test.
function Find-DesktopWindow([int] $ProcessId) {
    $buffer = New-Object System.Text.StringBuilder 512
    $handle = [IntPtr]::Zero

    while ($true) {
        $handle = [LokaliteQa.Win32]::FindWindowExW([IntPtr]::Zero, $handle, [IntPtr]::Zero, [IntPtr]::Zero)
        if ($handle -eq [IntPtr]::Zero) { return [IntPtr]::Zero }

        $owner = [uint32] 0
        $null = [LokaliteQa.Win32]::GetWindowThreadProcessId($handle, [ref] $owner)
        if ($owner -ne $ProcessId) { continue }

        $null = $buffer.Clear()
        $null = [LokaliteQa.Win32]::GetWindowTextW($handle, $buffer, $buffer.Capacity)
        if ($buffer.ToString() -eq $WindowTitle) { return $handle }
    }
}

function Wait-ForDesktopWindow([int] $ProcessId, [int] $TimeoutSeconds) {
    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    while ((Get-Date) -lt $deadline) {
        $handle = Find-DesktopWindow -ProcessId $ProcessId
        if ($handle -ne [IntPtr]::Zero) { return $handle }
        Start-Sleep -Milliseconds 250
    }
    throw "No window titled '$WindowTitle' appeared within $TimeoutSeconds seconds."
}

function Test-WindowVisible([IntPtr] $Handle) {
    return [LokaliteQa.Win32]::IsWindowVisible($Handle)
}

# Every assertion is "eventually true": launches and window transitions are
# asynchronous, so a fixed sleep would make the checks flaky rather than strict.
function Wait-ForCondition([scriptblock] $Condition) {
    $deadline = (Get-Date).AddSeconds($SettleTimeoutSeconds)
    while ((Get-Date) -lt $deadline) {
        if (& $Condition) { return $true }
        Start-Sleep -Milliseconds 250
    }
    return [bool] (& $Condition)
}

function Write-Trace([string] $Stage) {
    $visible = 'n/a'
    if ($null -ne (Get-Variable -Name desktopWindow -Scope Script -ErrorAction SilentlyContinue)) {
        $visible = [LokaliteQa.Win32]::IsWindowVisible($script:desktopWindow)
    }
    Write-Verbose "$Stage pids=$((@(Get-Instances) | Select-Object -Expand Id) -join ',') visible=$visible"
}

$started = @()
$results = [System.Collections.Generic.List[object]]::new()

function Add-Result([string] $Check, [bool] $Passed, [string] $Detail) {
    $results.Add([pscustomobject]@{ Check = $Check; Passed = $Passed; Detail = $Detail })
    if (-not $Passed) { throw "$Check failed: $Detail" }
}

try {
    if (@(Get-Instances).Count -ne 0) {
        throw "An instance of $processName is already running. Close it before running lifecycle QA."
    }

    $first = Start-Process -FilePath $resolved -PassThru
    $started += $first.Id
    $desktopWindow = Wait-ForDesktopWindow -ProcessId $first.Id -TimeoutSeconds $WindowTimeoutSeconds
    Start-Sleep -Seconds $StartupSettleSeconds
    Add-Result 'FirstLaunchStartsExactlyOneInstance' (@(Get-Instances).Count -eq 1) "pid $($first.Id)"

    # A second launch must be absorbed by the running instance.
    $second = Start-Process -FilePath $resolved -PassThru
    $started += $second.Id
    Write-Trace "launched second ($($second.Id))"
    $null = Wait-ForCondition { @(Get-Instances).Count -eq 1 }
    Write-Trace 'second absorbed'

    $instances = @(Get-Instances)
    Add-Result 'SecondLaunchLeavesOneInstance' ($instances.Count -eq 1) "instances $($instances.Count)"
    Add-Result 'SurvivingInstanceIsTheOriginal' ($instances[0].Id -eq $first.Id) "surviving pid $($instances[0].Id), original $($first.Id)"
    Add-Result 'SecondLaunchProcessExited' ($null -eq (Get-Process -Id $second.Id -ErrorAction SilentlyContinue)) "pid $($second.Id)"

    # Closing the window must hide it and keep the background process alive.
    $null = [LokaliteQa.Win32]::PostMessage($desktopWindow, $WM_CLOSE, [IntPtr]::Zero, [IntPtr]::Zero)
    $null = Wait-ForCondition { -not (Test-WindowVisible $desktopWindow) }

    Write-Trace 'after close'
    Add-Result 'CloseHidesTheWindow' (-not (Test-WindowVisible $desktopWindow)) 'desktop window hidden'
    Add-Result 'CloseKeepsTheProcessAlive' (@(Get-Instances).Count -eq 1) 'process survived WM_CLOSE'

    # A launch while hidden must still be absorbed, not start a new broker.
    Write-Trace 'before third'
    $third = Start-Process -FilePath $resolved -PassThru
    $started += $third.Id
    Write-Trace "launched third ($($third.Id))"
    $null = Wait-ForCondition { (@(Get-Instances).Count -eq 1) -and (Test-WindowVisible $desktopWindow) }
    Write-Trace 'third settled'

    $instances = @(Get-Instances)
    Add-Result 'LaunchWhileHiddenLeavesOneInstance' ($instances.Count -eq 1) "instances $($instances.Count), third pid $($third.Id)"
    Add-Result 'LaunchWhileHiddenRestoresTheWindow' (Test-WindowVisible $desktopWindow) 'same window shown again'

    $results
    Write-Warning 'Tray menu behavior, Windows Hello, and installed-MSIX identity remain manual checks.'
}
finally {
    foreach ($processId in $started) {
        $process = Get-Process -Id $processId -ErrorAction SilentlyContinue
        if ($null -ne $process) { Stop-Process -Id $processId -Force -ErrorAction SilentlyContinue }
    }
}
