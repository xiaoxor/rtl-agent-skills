#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
mkdir -p .build
: > .build/results.txt
failures=0
checks=0

report() { printf '%s\n' "$*" | tee -a .build/results.txt; }
for tool in iverilog vvp verilator timeout; do command -v "$tool" >/dev/null; done
iverilog -V > .build/iverilog-version.log 2>&1
verilator --version > .build/verilator-version.log 2>&1
head -n 1 .build/iverilog-version.log
cat .build/verilator-version.log

# Test the current Markdown template itself, rather than maintaining a copy.
awk '/^```systemverilog$/ { inside=1; code=""; next }
     /^```$/ { if (inside && code ~ /module tb_dut;/) { printf "%s", code; exit }; inside=0 }
     inside { code=code $0 "\n" }' \
    ../../testbench-craft/SKILL.md > .build/template.sv
grep -q '^module tb_dut;' .build/template.sv
grep -q '^endmodule' .build/template.sv

compile() {
    local sim=$1 name=$2 top=$3 expected_reject=$4
    shift 4
    local build=".build/$sim/$name"
    mkdir -p "$build"
    local rc=0
    if [[ $sim == iverilog ]]; then
        timeout 120 iverilog -g2012 -s "$top" -o "$build/sim.vvp" "$@" > "$build/compile.log" 2>&1 || rc=$?
        executable=(vvp "$build/sim.vvp")
    else
        timeout 120 verilator --binary --timing --build-jobs 2 \
            --top-module "$top" --Mdir "$build" -o sim "$@" > "$build/compile.log" 2>&1 || rc=$?
        executable=("$build/sim.exe")
    fi
    if ((rc != 0)); then
        checks=$((checks + 1))
        if [[ $rc != 124 && -n $expected_reject ]] && grep -Eq "$expected_reject" "$build/compile.log"; then
            report "EXPECTED compile rejection: $sim/$name (exit=$rc, $expected_reject)"
        else
            report "UNEXPECTED compile failure: $sim/$name (exit=$rc)"
            tail -n 15 "$build/compile.log"
            failures=$((failures + 1))
        fi
        return 1
    fi
    if [[ -n $expected_reject ]]; then
        report "UNEXPECTED compile support: $sim/$name; review this version's probe expectations"
        failures=$((failures + 1))
    fi
    return 0
}

run_case() {
    local sim=$1 name=$2 expected=$3 marker=$4
    shift 4
    local log=".build/$sim/$name.log" rc=0
    timeout 15 "${executable[@]}" "$@" > "$log" 2>&1 || rc=$?
    checks=$((checks + 1))
    if { [[ $expected == pass && $rc == 0 ]] ||
         [[ $expected == fail && $rc != 0 && $rc != 124 ]]; } && grep -Fq "$marker" "$log"; then
        report "EXPECTED $expected: $sim/$name (exit=$rc, $marker)"
    else
        report "UNEXPECTED result: $sim/$name (exit=$rc, wanted=$expected, marker=$marker)"
        failures=$((failures + 1))
    fi
    cat "$log"
}

for sim in iverilog verilator; do
    report "Running $sim"
    if compile "$sim" scheduling tb_scheduling '' tb_scheduling.sv; then
        run_case "$sim" scheduling pass 'PASS scheduling'
    fi
    if compile "$sim" handshake tb_handshake '' tb_handshake.sv; then
        run_case "$sim" handshake pass 'PASS handshake'
        run_case "$sim" handshake-broken-hold fail 'INPUT_HOLD' +break_hold
    fi
    if compile "$sim" template tb_dut '' .build/template.sv pipeline_dut.sv; then
        run_case "$sim" template pass 'PASS: 3 transactions checked'
        run_case "$sim" template-corrupt fail 'MISMATCH' +corrupt
        run_case "$sim" template-drop fail 'LOCAL TIMEOUT' +drop
    fi
    if compile "$sim" race tb_race '' tb_race.sv; then
        run_case "$sim" race pass 'OBSERVE race'
    fi
    if compile "$sim" nba-initial tb_nba_initial '' tb_nba_initial.sv; then
        run_case "$sim" nba-initial pass 'PASS initial NBA'
    fi
    if compile "$sim" zero-delay tb_zero_delay '' tb_zero_delay.sv; then
        run_case "$sim" zero-delay pass 'PASS zero delay'
    fi
    reject=''
    if [[ $sim == iverilog ]]; then reject='syntax error'; fi
    if compile "$sim" clocking tb_clocking "$reject" tb_clocking.sv; then
        run_case "$sim" clocking pass 'PASS clocking'
    fi
    if compile "$sim" xcheck tb_xcheck '' tb_xcheck.sv; then
        if [[ $sim == iverilog ]]; then
            run_case "$sim" xcheck fail 'UNKNOWN_REJECTED'
        else
            run_case "$sim" xcheck pass 'PASS x probe'
        fi
    fi
done
report "SUMMARY: $checks checks, $failures unexpected results"
((failures == 0))
