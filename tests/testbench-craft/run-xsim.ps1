$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$templateSource = Join-Path $repo 'testbench-craft\templates\portable-valid-result.sv'
$buildRoot = Join-Path $PSScriptRoot '.build\xsim'
$tools = @{}
foreach ($name in 'xvlog', 'xelab', 'xsim') {
    $tools[$name] = (Get-Command $name -ErrorAction Stop).Source
}
New-Item -ItemType Directory -Path $buildRoot -Force | Out-Null
$versionLog = Join-Path $buildRoot 'version.log'
& $tools.xsim --version *> $versionLog
if ($LASTEXITCODE -ne 0) { throw "xsim --version failed; see $versionLog" }
Get-Content $versionLog

if (-not (Test-Path -LiteralPath $templateSource -PathType Leaf)) {
    throw "Could not find testbench template: $templateSource"
}

$cases = @(
    @{ Name='scheduling'; Top='tb_scheduling'; Files=@('tb_scheduling.sv'); Expect='pass'; Marker='PASS scheduling' },
    @{ Name='handshake'; Top='tb_handshake'; Files=@('tb_handshake.sv'); Expect='pass'; Marker='PASS handshake' },
    @{ Name='handshake-broken-hold'; Top='tb_handshake'; Files=@('tb_handshake.sv'); PlusArg='break_hold'; Expect='fatal'; Marker='INPUT_HOLD:' },
    @{ Name='template'; Top='tb_dut'; Files=@($templateSource,(Join-Path $PSScriptRoot 'pipeline_dut.sv')); Expect='pass'; Marker='PASS: 3 transactions checked' },
    @{ Name='template-corrupt'; Top='tb_dut'; Files=@($templateSource,(Join-Path $PSScriptRoot 'pipeline_dut.sv')); PlusArg='corrupt'; Expect='fatal'; Marker='MISMATCH:' },
    @{ Name='template-drop'; Top='tb_dut'; Files=@($templateSource,(Join-Path $PSScriptRoot 'pipeline_dut.sv')); PlusArg='drop'; Expect='fatal'; Marker='LOCAL TIMEOUT:' },
    @{ Name='race'; Top='tb_race'; Files=@('tb_race.sv'); Expect='pass'; Marker='OBSERVE race' },
    @{ Name='nba-initial'; Top='tb_nba_initial'; Files=@('tb_nba_initial.sv'); Expect='pass'; Marker='PASS initial NBA' },
    @{ Name='zero-delay'; Top='tb_zero_delay'; Files=@('tb_zero_delay.sv'); Expect='pass'; Marker='PASS zero delay' },
    @{ Name='clocking'; Top='tb_clocking'; Files=@('tb_clocking.sv'); Expect='pass'; Marker='PASS clocking' },
    @{ Name='xcheck'; Top='tb_xcheck'; Files=@('tb_xcheck.sv'); Expect='fatal'; Marker='UNKNOWN_REJECTED:' }
)

$summary = [System.Collections.Generic.List[string]]::new()
$failures = 0
foreach ($case in $cases) {
    $build = Join-Path $buildRoot $case.Name
    New-Item -ItemType Directory -Path $build -Force | Out-Null
    $sources = @($case.Files | ForEach-Object {
        if ([System.IO.Path]::IsPathRooted($_)) { $_ } else { Join-Path $PSScriptRoot $_ }
    })

    Push-Location $build
    try {
        & $tools.xvlog --sv --work work @sources *> compile.log
        $compileExit = $LASTEXITCODE
        if ($compileExit -eq 0) {
            $snapshot = "$($case.Name)_snapshot"
            & $tools.xelab --debug off -s $snapshot "work.$($case.Top)" *> elaborate.log
            $elaborateExit = $LASTEXITCODE
        } else {
            $elaborateExit = -1
        }
        if ($compileExit -eq 0 -and $elaborateExit -eq 0) {
            $runArgs = @($snapshot, '--runall')
            if ($case.PlusArg) { $runArgs += @('--testplusarg', $case.PlusArg) }
            & $tools.xsim @runArgs *> runtime.log
            $runExit = $LASTEXITCODE
            $log = Get-Content runtime.log -Raw
            $hasMarker = $log.Contains($case.Marker)
            $hasFatal = $log -match '(?m)^Fatal:'
            $hasPass = $log.Contains('PASS')
            $valid = if ($case.Expect -eq 'pass') {
                $runExit -eq 0 -and $hasMarker -and -not $hasFatal
            } else {
                $hasFatal -and $hasMarker -and -not $hasPass
            }
            if ($valid) {
                $line = "EXPECTED $($case.Expect): $($case.Name) (xsim exit=$runExit; $($case.Marker))"
                Write-Host $line
                $summary.Add($line)
                if ($case.Name -eq 'race') {
                    foreach ($match in [regex]::Matches($log, 'OBSERVE race reverse=\d+ current=\d+ old=\d+')) {
                        Write-Host $match.Value
                        $summary.Add($match.Value)
                    }
                }
            } else {
                $line = "UNEXPECTED result: $($case.Name) (xsim exit=$runExit; wanted=$($case.Expect); $($case.Marker))"
                Write-Host $line
                Get-Content runtime.log -Tail 25
                $summary.Add($line)
                $failures++
            }
        } else {
            $phase = if ($compileExit -ne 0) { 'xvlog' } else { 'xelab' }
            $line = "UNEXPECTED $phase failure: $($case.Name) (xvlog=$compileExit; xelab=$elaborateExit)"
            Write-Host $line
            Get-Content compile.log -Tail 20
            if ($elaborateExit -ne 0 -and (Test-Path elaborate.log)) { Get-Content elaborate.log -Tail 20 }
            $summary.Add($line)
            $failures++
        }
    } finally {
        Pop-Location
    }
}
$summary.Add("SUMMARY: $($cases.Count) checks, $failures unexpected results")
$summary | Tee-Object -FilePath (Join-Path $buildRoot 'results.txt')
if ($failures -ne 0) { exit 1 }
