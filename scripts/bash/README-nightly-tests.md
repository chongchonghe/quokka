# Nightly Debug Regression Tests

## Overview

This directory contains two scripts for automated debug testing:

1. **`run-nightly-debug-tests.sh`**: Comprehensive nightly regression tests for all dimensionalities (1D, 2D, 3D)
2. **`run-3d-debug-tests.sh`**: Quick 3D-only debug tests for rapid validation

Both scripts compile in debug mode with `max_timesteps=2` for fast execution and provide organized logging.

## Features

- **Multi-dimensional builds**: Automatically builds and tests 1D, 2D, and 3D configurations
- **Debug mode**: Compiles with `-DCMAKE_BUILD_TYPE=Debug` for enhanced error detection
- **Quick validation**: Temporarily sets `max_timesteps=2` in all input files for fast test execution
- **Organized logging**: All logs and artifacts are timestamped and organized by date
- **Git tracking**: Records git branch, commit, and status for reproducibility
- **Automatic cleanup**: Removes logs older than 7 days to save disk space
- **Summary reports**: Generates detailed summary of build and test results

## Usage

### Nightly Regression Tests (All Dimensions)

For comprehensive testing of 1D, 2D, and 3D builds:

```bash
cd /path/to/quokka
./scripts/bash/run-nightly-debug-tests.sh
```

**Duration**: ~30-60 minutes depending on hardware

### Quick 3D Tests

For rapid validation of 3D configuration only:

```bash
cd /path/to/quokka
./scripts/bash/run-3d-debug-tests.sh
```

**Duration**: ~10-20 minutes

### Requirements

- CMake 3.16 or newer
- Ninja build system
- Git
- All Quokka dependencies (AMReX, HDF5, etc.)

### Configuration

You can modify the following variables at the top of the script:

```bash
# Build configuration
CMAKE_BUILD_TYPE="Debug"          # Build type (Debug/Release/RelWithDebInfo)
NUM_BUILD_JOBS=6                  # Parallel build jobs
CMAKE_GENERATOR="Ninja"           # Build system (Ninja/Unix Makefiles)

# Test configuration
MAX_TIMESTEPS=2                   # Override max_timesteps in input files
CTEST_PARALLEL_JOBS=4            # Parallel test execution

# Dimensionalities to test
DIMENSIONS=(1 2 3)               # Which dimensions to build and test
```

## Output Structure

All outputs are organized in the `nightly-logs/` directory:

```
nightly-logs/
├── latest -> 20260126_143022/   # Symlink to most recent run
└── 20260126_143022/             # Timestamped run directory
    ├── nightly-test-summary.log # Main log with all output
    ├── summary.txt              # Human-readable summary
    ├── git-info.txt            # Git repository state
    ├── 1d/                     # 1D build logs and artifacts
    │   ├── cmake-config.log
    │   ├── cmake-build.log
    │   ├── ctest-output.log
    │   ├── test-results.xml
    │   ├── input-backups/      # Original input files
    │   └── Testing/            # CTest artifacts
    ├── 2d/                     # 2D build logs and artifacts
    │   └── ...
    └── 3d/                     # 3D build logs and artifacts
        └── ...
```

## How It Works

### Build Process

For each dimensionality (1D, 2D, 3D):

1. **Clean**: Removes any existing build directory
2. **Configure**: Runs CMake with debug flags and appropriate `AMReX_SPACEDIM`
3. **Compile**: Builds all targets using Ninja with parallel jobs
4. **Test**: Runs CTest with all available tests

### Test Execution

To ensure quick test completion:

1. **Backup**: Copies all `.in` files from `inputs/` directory
2. **Modify**: Temporarily sets `max_timesteps=2` in all input files
3. **Run**: Executes CTest with parallel test execution
4. **Restore**: Restores all original input files from backup

This approach ensures tests complete quickly without permanently modifying the repository.

### Error Handling

- Each stage (configure, build, test) is independent
- Failures in one dimensionality don't block others
- All errors are logged with timestamps
- Exit code indicates overall success/failure

## Exit Codes

- `0`: All builds and tests successful
- `1`: One or more builds failed or tests failed

## Integration with CI/CD

### Jenkins/GitLab CI Example

```bash
#!/bin/bash
cd $WORKSPACE
./scripts/bash/run-nightly-debug-tests.sh
```

### Cron Job Example

```bash
# Run nightly at 2 AM
0 2 * * * cd /path/to/quokka && ./scripts/bash/run-nightly-debug-tests.sh
```

### Email Notifications

To add email notifications on failure, append to the script:

```bash
if [ $? -ne 0 ]; then
    mail -s "Quokka Nightly Tests Failed" user@example.com < nightly-logs/latest/summary.txt
fi
```

## Troubleshooting

### Build Failures

Check the relevant log file:
```bash
cat nightly-logs/latest/3d/cmake-build.log
```

### Test Failures

Review CTest output:
```bash
cat nightly-logs/latest/3d/ctest-output.log
```

### Disk Space Issues

Adjust retention policy in the script:
```bash
# Keep last 14 days instead of 7
find "${REPO_ROOT}/nightly-logs" -maxdepth 1 -type d -name "20*" -mtime +14 -exec rm -rf {} \;
```

## Advanced Usage

### Test Specific Dimensionality

Modify the `DIMENSIONS` array:
```bash
DIMENSIONS=(3)  # Only test 3D
```

### Increase Max Timesteps

For more thorough testing:
```bash
MAX_TIMESTEPS=10
```

### GPU Testing

Add GPU backend configuration:
```bash
CMAKE_EXTRA_ARGS="-DAMReX_GPU_BACKEND=CUDA"
```

Then modify the CMake command in the script to include `${CMAKE_EXTRA_ARGS}`.

## Comparison with Full Regression Tests

| Feature | Nightly Debug Tests | Full Regression Tests |
|---------|-------------------|----------------------|
| Build Type | Debug | Release |
| Max Timesteps | 2 (forced) | Full (from .in files) |
| Duration | ~30-60 minutes | Several hours |
| Purpose | Quick validation | Full verification |
| Dimensionalities | 1D, 2D, 3D | 3D only (typically) |

## See Also

- `regression/quokka-tests.ini`: Full regression test configuration
- `scripts/tidy.sh`: Static analysis script
- `CLAUDE.md`: Build and test commands reference
