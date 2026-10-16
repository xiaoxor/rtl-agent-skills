#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
buildRoot=.build/vcs
mkdir -p "$buildRoot"
: > "$buildRoot/results.txt"
failures=0
checks=0

report() { printf '%s\n' "$*" | tee -a "$buildRoot/results.txt"; }
for tool in vcs timeout; do
    command -v "$tool" >/dev/null || { echo "missing tool: $tool" >&2; exit 1; }
done
vcs -ID > "$buildRoot/version.log" 2>&1
grep -m1 'Compiler version' "$buildRoot/version.log" | tee -a "$buildRoot/results.txt"

template=../../testbench-craft/templates/portable-valid-result.sv
grep -q '^module tb_dut;' "$template"
grep -q '^endmodule' "$template"

# Expectations: pass requires exit 0, the PASS marker, and no Fatal.
# fatal requires the case marker and a "Fatal:" line, and must not print PASS.
# Measured on VCS W-2024.09-SP1: $fatal printed Fatal: and ended the run, but
# simv still exited 0, so the exit code is recorded, not required, for fails.
run_case() {
    local name=$1 expect=$2 marker=$3 top=$4 plusarg=$5
    shift 5
    local build="$buildRoot/$name" rc=0
    mkdir -p "$build"
    local root sources=() f
    root=$(pwd)
    for f in "$@"; do
        [[ $f == /* ]] || f="$root/$f"
        sources+=("$f")
    done
    (cd "$build" && timeout 120 vcs -full64 -sverilog -top "$top" -o simv \
        "${sources[@]}") > "$build/compile.log" 2>&1 || rc=$?
    checks=$((checks + 1))
    if ((rc != 0)); then
        report "UNEXPECTED compile failure: vcs/$name (exit=$rc)"
        tail -n 15 "$build/compile.log"
        failures=$((failures + 1))
        return
    fi
    local log="$build/runtime.log"
    rc=0
    (cd "$build" && timeout 15 ./simv -no_save ${plusarg:+$plusarg}) > "$log" 2>&1 || rc=$?
    local has_marker=no has_fatal=no has_pass=no
    grep -Fq -- "$marker" "$log" && has_marker=yes
    grep -Eq 'FATAL|^Fatal:|\$fatal' "$log" && has_fatal=yes
    grep -Fq 'PASS' "$log" && has_pass=yes
    local valid=no
    if [[ $expect == pass && $rc == 0 && $has_marker == yes && $has_fatal == no ]]; then
        valid=yes
    elif [[ $expect == fatal && $rc != 124 && $has_marker == yes &&
            $has_fatal == yes && $has_pass == no ]]; then
        valid=yes
    fi
    if [[ $valid == yes ]]; then
        report "EXPECTED $expect: vcs/$name (simv exit=$rc; $marker)"
        if [[ $name == race ]]; then
            grep -F 'OBSERVE race' "$log" | tee -a "$buildRoot/results.txt"
        fi
    else
        report "UNEXPECTED result: vcs/$name (exit=$rc; wanted=$expect;" \
"marker=$marker fatal=$has_fatal pass=$has_pass)"
        tail -n 25 "$log"
        failures=$((failures + 1))
    fi
}

run_case scheduling pass 'PASS scheduling' tb_scheduling '' tb_scheduling.sv
run_case handshake pass 'PASS handshake' tb_handshake '' tb_handshake.sv
run_case handshake-broken-hold fatal 'INPUT_HOLD:' tb_handshake '+break_hold' tb_handshake.sv
run_case template pass 'PASS: 3 transactions checked' tb_dut '' \
    "$template" pipeline_dut.sv
run_case template-corrupt fatal 'MISMATCH:' tb_dut '+corrupt' \
    "$template" pipeline_dut.sv
run_case template-drop fatal 'LOCAL TIMEOUT:' tb_dut '+drop' \
    "$template" pipeline_dut.sv
run_case race pass 'OBSERVE race' tb_race '' tb_race.sv
run_case nba-initial pass 'PASS initial NBA' tb_nba_initial '' tb_nba_initial.sv
run_case zero-delay pass 'PASS zero delay' tb_zero_delay '' tb_zero_delay.sv
run_case clocking pass 'PASS clocking' tb_clocking '' tb_clocking.sv
run_case xcheck fatal 'UNKNOWN_REJECTED:' tb_xcheck '' tb_xcheck.sv

report "SUMMARY: $checks checks, $failures unexpected results"
((failures == 0))
