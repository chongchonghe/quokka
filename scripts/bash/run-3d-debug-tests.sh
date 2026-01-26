#!/bin/bash
#
# Quick 3D Debug Test Script
# 
# This script is a simplified version of run-nightly-debug-tests.sh that only
# builds and tests the 3D configuration. Useful for quick validation.
#
# Usage: ./run-3d-debug-tests.sh
#

set -euo pipefail

# ==============================================================================
# Configuration
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_DIR="${REPO_ROOT}/debug-test-logs/3d-${TIMESTAMP}"

CMAKE_BUILD_TYPE="Debug"
NUM_BUILD_JOBS=6
CTEST_PARALLEL_JOBS=4
MAX_TIMESTEPS=2
SPACEDIM=3

# ==============================================================================
# Setup
# ==============================================================================

mkdir -p "${LOG_DIR}"
BUILD_DIR="${REPO_ROOT}/build-3d-debug"

echo "=============================================================================="
echo "Quokka 3D Debug Tests"
echo "=============================================================================="
echo "Started at: $(date)"
echo "Build directory: ${BUILD_DIR}"
echo "Log directory: ${LOG_DIR}"
echo "=============================================================================="
echo ""

# ==============================================================================
# Configure
# ==============================================================================

echo "[1/4] Configuring 3D build..."

if [ -d "${BUILD_DIR}" ]; then
	echo "  Removing existing build directory"
	rm -rf "${BUILD_DIR}"
fi

mkdir -p "${BUILD_DIR}"

if cmake \
	-S "${REPO_ROOT}" \
	-B "${BUILD_DIR}" \
	-DCMAKE_BUILD_TYPE="${CMAKE_BUILD_TYPE}" \
	-DAMReX_SPACEDIM="${SPACEDIM}" \
	-DCMAKE_EXPORT_COMPILE_COMMANDS=ON \
	> "${LOG_DIR}/cmake-config.log" 2>&1; then
	echo "  ✓ Configuration successful"
else
	echo "  ✗ Configuration failed. See ${LOG_DIR}/cmake-config.log"
	exit 1
fi

# ==============================================================================
# Build
# ==============================================================================

echo "[2/4] Building with ${NUM_BUILD_JOBS} jobs..."

if cmake --build "${BUILD_DIR}" --parallel ${NUM_BUILD_JOBS} > "${LOG_DIR}/build.log" 2>&1; then
	echo "  ✓ Build successful"
else
	echo "  ✗ Build failed. See ${LOG_DIR}/build.log"
	exit 1
fi

# ==============================================================================
# Modify input files
# ==============================================================================

echo "[3/4] Appending max_timesteps=${MAX_TIMESTEPS} to input files..."

INPUT_DIR="${REPO_ROOT}/inputs"
BACKUP_DIR="${LOG_DIR}/input-backups"
mkdir -p "${BACKUP_DIR}"

modified_count=0
while IFS= read -r -d '' input_file; do
	filename=$(basename "${input_file}")
	jobname="${filename%.in}"  # Remove .in extension
	cp "${input_file}" "${BACKUP_DIR}/${filename}"
	
	# Append overrides to end of file (these override any earlier values)
	{
		echo ""
		echo "# Temporary overrides for debug testing"
		echo "max_timesteps = ${MAX_TIMESTEPS}"
		echo "plotfile_prefix = \"${jobname}_plt\""
		echo "checkpoint_prefix = \"${jobname}_chk\""
	} >> "${input_file}"
	
	((modified_count++))
done < <(find "${INPUT_DIR}" -name "*.in" -print0)

echo "  Modified ${modified_count} input files"

# ==============================================================================
# Run tests
# ==============================================================================

echo "[4/4] Running tests..."

cd "${BUILD_DIR}"

if ctest \
	--output-on-failure \
	--parallel ${CTEST_PARALLEL_JOBS} \
	> "${LOG_DIR}/ctest.log" 2>&1; then
	echo "  ✓ All tests passed"
	test_result=0
else
	echo "  ✗ Some tests failed. See ${LOG_DIR}/ctest.log"
	test_result=1
fi

# Extract test summary
if grep -E "tests passed|test passed" "${LOG_DIR}/ctest.log" | tail -1; then
	:
fi

cd "${REPO_ROOT}"

# ==============================================================================
# Restore input files
# ==============================================================================

echo "Restoring input files..."

while IFS= read -r -d '' backup_file; do
	filename=$(basename "${backup_file}")
	original="${INPUT_DIR}/${filename}"
	if [ -f "${original}" ]; then
		cp "${backup_file}" "${original}"
	fi
done < <(find "${BACKUP_DIR}" -name "*.in" -print0)

# ==============================================================================
# Summary
# ==============================================================================

echo ""
echo "=============================================================================="
echo "Completed at: $(date)"
echo "Logs saved to: ${LOG_DIR}"
echo "=============================================================================="

exit ${test_result}
