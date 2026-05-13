#!/bin/bash
# Test bit-for-bit reproducibility by running a problem three times and comparing outputs.
# Prerequisites: source your environment and build the executable before running.
#
# Usage: test-reproducibility.sh <problem_name> [build_path]
#
# Example:
#   test-reproducibility.sh SphericalCollapse build/gpu-3d

set -e

usage() {
    echo "Usage: $0 <problem_name> [build_path]"
    echo "  problem_name: e.g. SphericalCollapse"
    echo "  build_path:   e.g. build/gpu-3d (default: build/gpu-3d)"
    exit 1
}

[[ $# -lt 1 || $# -gt 2 ]] && usage

PROBLEM="$1"
BUILD_PATH="${2:-build/gpu-3d}"

EXE="${BUILD_PATH}/src/problems/${PROBLEM}/${PROBLEM}"
FCOMPARE="$(ls extern/amrex/Tools/Plotfile/fcompare* 2>/dev/null | head -1)"

if [[ -f "inputs/${PROBLEM}.toml" ]]; then
    INPUT="inputs/${PROBLEM}.toml"
elif [[ -f "inputs/${PROBLEM}.in" ]]; then
    INPUT="inputs/${PROBLEM}.in"
else
    echo "Error: input file not found for ${PROBLEM} in inputs/"
    exit 1
fi

[[ -x "$EXE" ]]      || { echo "Error: executable not found or not executable: $EXE"; exit 1; }
[[ -x "$FCOMPARE" ]] || { echo "Error: fcompare not found or not executable: $FCOMPARE"; exit 1; }

max_timesteps=$(awk '/^[[:space:]]*max_timesteps[[:space:]]*=/{print $3}' "$INPUT")
[[ -n "$max_timesteps" ]] || { echo "Error: could not read max_timesteps from $INPUT"; exit 1; }
echo "max_timesteps: ${max_timesteps}"

plt="plt$(printf "%05d" "${max_timesteps}")"
flag=$(date +%Y%m%d%H%M%S)
echo "flag: ${flag}"

run() {
    local n="$1"
    echo "--- Run ${n} ---"
    "$EXE" "$INPUT" >> "log.${flag}.r${n}.log"
    [[ -d "$plt" ]] || { echo "Error: plotfile ${plt} not found after run ${n}"; exit 1; }
    mv "$plt" "${plt}.${flag}.r${n}"
    echo "Output: ${plt}.${flag}.r${n}"
}

run 1
run 2
run 3

cell="Level_0/Cell_H"
r1="${plt}.${flag}.r1"
r2="${plt}.${flag}.r2"
r3="${plt}.${flag}.r3"

compare() {
    local a="$1" b="$2" label="$3"
    echo ""
    echo "=== Comparing ${label} ==="
    if diff -q "${a}/${cell}" "${b}/${cell}" > /dev/null 2>&1; then
        echo "PASS: ${label} are identical"
    else
        echo "FAIL: ${label} differ"
        "$FCOMPARE" "$a" "$b" || true
    fi
}

compare "$r1" "$r2" "run1 vs run2"
compare "$r2" "$r3" "run2 vs run3"

echo ""
if diff -q "${r1}/${cell}" "${r2}/${cell}" > /dev/null 2>&1 && \
   diff -q "${r2}/${cell}" "${r3}/${cell}" > /dev/null 2>&1; then
    echo "All three runs are identical — reproducibility confirmed."
    exit 0
else
    echo "Reproducibility check FAILED."
    exit 1
fi
