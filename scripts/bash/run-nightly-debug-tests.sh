#!/bin/bash
#
# Nightly Debug Regression Test Script
# 
# This script configures, compiles, and runs all Quokka tests in debug mode
# with max_timesteps=2 for quick validation. Logs and artifacts are organized
# by timestamp for historical tracking.
#
# Usage: 
#   ./run-nightly-debug-tests.sh [OPTIONS]
#
# Options:
#   --incremental    Keep existing build folders and do incremental builds
#   -h, --help       Show this help message
#

set -euo pipefail

# ==============================================================================
# Parse command-line arguments
# ==============================================================================

INCREMENTAL_BUILD=false

while [[ $# -gt 0 ]]; do
	case $1 in
		--incremental)
			INCREMENTAL_BUILD=true
			shift
			;;
		-h|--help)
			echo "Usage: $0 [OPTIONS]"
			echo ""
			echo "Options:"
			echo "  --incremental    Keep existing build folders and do incremental builds"
			echo "  -h, --help       Show this help message"
			echo ""
			echo "Description:"
			echo "  Runs Quokka debug tests with max_timesteps=2 for crash detection."
			echo "  By default, performs clean builds. Use --incremental for faster iteration."
			exit 0
			;;
		*)
			echo "Unknown option: $1"
			echo "Use --help for usage information"
			exit 1
			;;
	esac
done

# ==============================================================================
# Configuration
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_ROOT="${REPO_ROOT}/../nightly-debug-logs/${TIMESTAMP}"
SRC_PATH="${REPO_ROOT}/../env.rc"

source "${SRC_PATH}"

# Build configuration
CMAKE_BUILD_TYPE="Debug"
#CMAKE_GENERATOR=""  # Ninja or "" to default to "Unix Makefiles"
NUM_BUILD_JOBS=16

# Test configuration
MAX_TIMESTEPS=2
CTEST_PARALLEL_JOBS=16

# Dimensionalities to test
DIMENSIONS=(3)

# ==============================================================================
# Setup logging
# ==============================================================================

mkdir -p "${LOG_ROOT}"
MAIN_LOG="${LOG_ROOT}/nightly-test-summary.log"

# Redirect all output to both console and log file
exec > >(tee -a "${MAIN_LOG}") 2>&1

echo "=============================================================================="
echo "Quokka Nightly Debug Regression Tests"
echo "=============================================================================="
echo "Started at: $(date)"
echo "Repository: ${REPO_ROOT}"
echo "Log directory: ${LOG_ROOT}"
echo "Build type: ${CMAKE_BUILD_TYPE}"
echo "Build mode: $([ "${INCREMENTAL_BUILD}" = true ] && echo "Incremental" || echo "Clean")"
echo "Max timesteps: ${MAX_TIMESTEPS}"
echo "Dimensions to test: ${DIMENSIONS[*]}"
echo "=============================================================================="
echo ""

# ==============================================================================
# Helper functions
# ==============================================================================

# Log with timestamp
log_info() {
	echo "[$(date +%H:%M:%S)] INFO: $*"
}

log_error() {
	echo "[$(date +%H:%M:%S)] ERROR: $*" >&2
}

log_success() {
	echo "[$(date +%H:%M:%S)] SUCCESS: $*"
}

# Check if command exists
check_command() {
	if ! command -v "$1" &> /dev/null; then
		log_error "Required command '$1' not found. Please install it."
		return 1
	fi
	return 0
}

# ==============================================================================
# Validate environment
# ==============================================================================

log_info "Validating environment..."

REQUIRED_COMMANDS=(cmake git)
for cmd in "${REQUIRED_COMMANDS[@]}"; do
	if ! check_command "$cmd"; then
		log_error "Missing required command: $cmd"
		exit 1
	fi
done

# Check if we're in a git repository
if [ ! -d "${REPO_ROOT}/.git" ]; then
	log_error "Not in a git repository"
	exit 1
fi

# Record git information
{
	echo "Git branch: $(git rev-parse --abbrev-ref HEAD)"
	echo "Git commit: $(git rev-parse HEAD)"
	echo "Git status:"
	git status --short
	echo ""
} >> "${LOG_ROOT}/git-info.txt"

log_success "Environment validation complete"
echo ""

# ==============================================================================
# Build and test for each dimensionality
# ==============================================================================

# Arrays to track results
declare -A BUILD_STATUS
declare -A TEST_STATUS
declare -A TEST_COUNTS

for DIM in "${DIMENSIONS[@]}"; do
	log_info "=========================================="
	log_info "Processing ${DIM}D build"
	log_info "=========================================="
	
	BUILD_DIR="${REPO_ROOT}/build-${DIM}d-debug"
	DIM_LOG_DIR="${LOG_ROOT}/${DIM}d"
	mkdir -p "${DIM_LOG_DIR}"
	
	# --------------------------------------------------
	# Configure
	# --------------------------------------------------
	if [ "${INCREMENTAL_BUILD}" = true ] && [ -d "${BUILD_DIR}" ]; then
		log_info "Using existing build directory for incremental build: ${BUILD_DIR}"
	else
		if [ -d "${BUILD_DIR}" ]; then
			log_info "Removing existing build directory: ${BUILD_DIR}"
			rm -rf "${BUILD_DIR}"
		fi
		mkdir -p "${BUILD_DIR}"
		log_info "Configuring ${DIM}D build..."
	fi
	
	# Only run cmake configure if not doing incremental build or if build dir doesn't have CMakeCache
	if [ "${INCREMENTAL_BUILD}" = false ] || [ ! -f "${BUILD_DIR}/CMakeCache.txt" ]; then
		CMAKE_CMD="cmake \
			-S ${REPO_ROOT} \
			-B ${BUILD_DIR} \
			-DCMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE} \
			-DAMReX_SPACEDIM=${DIM} \
			-DCMAKE_EXPORT_COMPILE_COMMANDS=ON"
		
		if ${CMAKE_CMD} > "${DIM_LOG_DIR}/cmake-config.log" 2>&1; then
			log_success "Configuration complete for ${DIM}D"
			BUILD_STATUS[${DIM}]="configured"
		else
			log_error "Configuration failed for ${DIM}D. See ${DIM_LOG_DIR}/cmake-config.log"
			BUILD_STATUS[${DIM}]="config_failed"
			continue
		fi
	else
		log_info "Skipping configuration (using existing CMakeCache.txt)"
		BUILD_STATUS[${DIM}]="configured"
	fi
	
	# --------------------------------------------------
	# Compile
	# --------------------------------------------------
	log_info "Compiling ${DIM}D build with ${NUM_BUILD_JOBS} jobs..."
	
	if cmake --build "${BUILD_DIR}" --parallel ${NUM_BUILD_JOBS} > "${DIM_LOG_DIR}/cmake-build.log" 2>&1; then
		log_success "Compilation complete for ${DIM}D"
		BUILD_STATUS[${DIM}]="compiled"
	else
		log_error "Compilation failed for ${DIM}D. See ${DIM_LOG_DIR}/cmake-build.log"
		BUILD_STATUS[${DIM}]="build_failed"
		continue
	fi
	
	# --------------------------------------------------
	# Temporarily modify input files to set max_timesteps
	# --------------------------------------------------
	log_info "Appending max_timesteps=${MAX_TIMESTEPS} to input files..."
	
	# Backup and modify input files
	INPUT_DIR="${REPO_ROOT}/inputs"
	BACKUP_DIR="${DIM_LOG_DIR}/input-backups"
	mkdir -p "${BACKUP_DIR}"
	
	# Find all .in files and modify them
	modified_files=()
	while IFS= read -r -d '' input_file; do
		filename=$(basename "${input_file}")
		jobname="${filename%.in}"  # Remove .in extension
		
		# Backup original
		cp "${input_file}" "${BACKUP_DIR}/${filename}"
		
		# Append overrides to end of file (these override any earlier values)
		{
			echo ""
			echo "# Temporary overrides for debug testing"
			echo "max_timesteps = ${MAX_TIMESTEPS}"
			echo "plotfile_prefix = \"${jobname}_plt\""
			echo "checkpoint_prefix = \"${jobname}_chk\""
		} >> "${input_file}"
		
		modified_files+=("${input_file}")
	done < <(find "${INPUT_DIR}" -name "*.in" -print0)
	
	log_info "Modified ${#modified_files[@]} input files"
	
	# --------------------------------------------------
	# Run tests
	# --------------------------------------------------
	log_info "Running tests for ${DIM}D (ignoring non-zero exits, checking for crashes only)..."
	
	cd "${BUILD_DIR}"
	
	# Run tests without failing on non-zero return codes
	# We only care about crashes (segfaults, aborts), not numerical correctness
	ctest \
		--output-on-failure \
		--parallel ${CTEST_PARALLEL_JOBS} \
		--output-junit ${DIM_LOG_DIR}/test-results.xml \
		> "${DIM_LOG_DIR}/ctest-output.log" 2>&1 || true
	
	# Check for actual crashes in the output
	CRASH_PATTERNS="Segmentation fault|segfault|core dumped|Aborted|Signal:|SIGSEGV|SIGABRT|SIGBUS|SIGFPE|SIGILL"
	if grep -E "${CRASH_PATTERNS}" "${DIM_LOG_DIR}/ctest-output.log" > "${DIM_LOG_DIR}/crashes.log" 2>&1; then
		log_error "Detected crashes in ${DIM}D tests. See ${DIM_LOG_DIR}/crashes.log"
		TEST_STATUS[${DIM}]="crashed"
	else
		log_success "No crashes detected for ${DIM}D (test exits with non-zero codes are expected with max_timesteps=${MAX_TIMESTEPS})"
		TEST_STATUS[${DIM}]="completed"
	fi
	
	# --------------------------------------------------
	# Restore original input files
	# --------------------------------------------------
	log_info "Restoring original input files..."
	
	for input_file in "${modified_files[@]}"; do
		filename=$(basename "${input_file}")
		if [ -f "${BACKUP_DIR}/${filename}" ]; then
			cp "${BACKUP_DIR}/${filename}" "${input_file}"
		fi
	done
	
	log_success "Restored ${#modified_files[@]} input files"
	
	# Extract test counts from ctest output
	if [ -f "${DIM_LOG_DIR}/ctest-output.log" ]; then
		TEST_COUNTS[${DIM}]=$(grep -E "tests passed|test passed" "${DIM_LOG_DIR}/ctest-output.log" | tail -1 || echo "unknown")
	fi
	
	# Copy test artifacts
	log_info "Collecting test artifacts for ${DIM}D..."
	if [ -d "${BUILD_DIR}/Testing" ]; then
		cp -r "${BUILD_DIR}/Testing" "${DIM_LOG_DIR}/"
	fi
	
	cd "${REPO_ROOT}"
	echo ""
done

# ==============================================================================
# Generate summary report
# ==============================================================================

echo ""
echo "=============================================================================="
echo "NIGHTLY TEST SUMMARY"
echo "=============================================================================="
echo "Completed at: $(date)"
echo ""

SUMMARY_FILE="${LOG_ROOT}/summary.txt"
{
	echo "Quokka Nightly Debug Regression Test Summary"
	echo "=============================================="
	echo "Date: $(date)"
	echo "Build type: ${CMAKE_BUILD_TYPE}"
	echo "Repository: ${REPO_ROOT}"
	echo "Git commit: $(git rev-parse HEAD)"
	echo "Git branch: $(git rev-parse --abbrev-ref HEAD)"
	echo ""
	echo "Results by Dimensionality:"
	echo "--------------------------"
} > "${SUMMARY_FILE}"

OVERALL_STATUS="SUCCESS"

for DIM in "${DIMENSIONS[@]}"; do
	BUILD="${BUILD_STATUS[${DIM}]:-not_attempted}"
	TEST="${TEST_STATUS[${DIM}]:-not_run}"
	COUNT="${TEST_COUNTS[${DIM}]:-N/A}"
	
	{
		echo ""
		echo "${DIM}D Build:"
		echo "  Build status: ${BUILD}"
		echo "  Test status: ${TEST}"
		echo "  Test results: ${COUNT}"
		echo "  Logs: ${LOG_ROOT}/${DIM}d/"
	} | tee -a "${SUMMARY_FILE}"
	
	if [[ "${BUILD}" != "compiled" ]] || [[ "${TEST}" == "crashed" ]]; then
		OVERALL_STATUS="FAILED"
	fi
done

echo "" | tee -a "${SUMMARY_FILE}"
echo "Overall status: ${OVERALL_STATUS}" | tee -a "${SUMMARY_FILE}"
echo "=============================================================================="

# ==============================================================================
# Cleanup and final notes
# ==============================================================================

log_info "Test artifacts and logs saved to: ${LOG_ROOT}"
log_info "Main log file: ${MAIN_LOG}"
log_info "Summary report: ${SUMMARY_FILE}"

# Create a symlink to the latest run
LATEST_LINK="${REPO_ROOT}/nightly-logs/latest"
rm -f "${LATEST_LINK}"
ln -s "${LOG_ROOT}" "${LATEST_LINK}"
log_info "Symlink to latest run: ${LATEST_LINK}"

# Optional: Compress old logs (keep last 7 days)
log_info "Cleaning up old logs (keeping last 7 days)..."
find "${REPO_ROOT}/nightly-logs" -maxdepth 1 -type d -name "20*" -mtime +7 -exec rm -rf {} \; 2>/dev/null || true

echo ""
if [ "${OVERALL_STATUS}" = "SUCCESS" ]; then
	log_success "All tests completed successfully!"
	exit 0
else
	log_error "Some tests failed. Review logs for details."
	exit 1
fi
