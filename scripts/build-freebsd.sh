#!/bin/sh
# Build script for FreeBSD
# This script sets up the environment and builds Kuzu on FreeBSD

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "${GREEN}Kuzu FreeBSD Build Script${NC}"
echo "=============================="

# Check if running on FreeBSD
if [ "$(uname -s)" != "FreeBSD" ]; then
    echo "${RED}Error: This script is designed for FreeBSD only${NC}"
    exit 1
fi

# Parse command line arguments
BUILD_TYPE="Release"
BUILD_DIR="build"
ENABLE_TESTS=false
ENABLE_EXTENSIONS=""
JOBS=$(sysctl -n hw.ncpu)

usage() {
    echo "Usage: $0 [options]"
    echo "Options:"
    echo "  -d, --debug          Build in Debug mode (default: Release)"
    echo "  -t, --tests          Enable building tests"
    echo "  -e, --extensions     Comma-separated list of extensions to build (default: none, use 'ALL' for all)"
    echo "  -j, --jobs N         Number of parallel jobs (default: $(sysctl -n hw.ncpu))"
    echo "  -c, --clean          Clean build directory before building"
    echo "  -h, --help           Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                                    # Basic release build"
    echo "  $0 --debug --tests                    # Debug build with tests"
    echo "  $0 --extensions httpfs,json           # Build with specific extensions"
    echo "  $0 --extensions ALL                   # Build with all extensions"
}

while [ $# -gt 0 ]; do
    case "$1" in
        -d|--debug)
            BUILD_TYPE="Debug"
            shift
            ;;
        -t|--tests)
            ENABLE_TESTS=true
            shift
            ;;
        -e|--extensions)
            ENABLE_EXTENSIONS="$2"
            shift 2
            ;;
        -j|--jobs)
            JOBS="$2"
            shift 2
            ;;
        -c|--clean)
            echo "${YELLOW}Cleaning build directory...${NC}"
            rm -rf "${BUILD_DIR}"
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "${RED}Unknown option: $1${NC}"
            usage
            exit 1
            ;;
    esac
done

# Check for required packages
echo "${YELLOW}Checking dependencies...${NC}"

check_package() {
    if ! pkg info "$1" >/dev/null 2>&1; then
        echo "${RED}Missing package: $1${NC}"
        echo "Please install with: sudo pkg install $1"
        return 1
    fi
    return 0
}

MISSING_DEPS=false
check_package cmake || MISSING_DEPS=true
check_package ninja || MISSING_DEPS=true
check_package pkgconf || MISSING_DEPS=true
check_package libexecinfo || MISSING_DEPS=true

# Check for compiler
if pkg info llvm18 >/dev/null 2>&1; then
    export CC=/usr/local/bin/clang18
    export CXX=/usr/local/bin/clang++18
    echo "${GREEN}Using LLVM 18 from ports${NC}"
elif pkg info llvm17 >/dev/null 2>&1; then
    export CC=/usr/local/bin/clang17
    export CXX=/usr/local/bin/clang++17
    echo "${GREEN}Using LLVM 17 from ports${NC}"
elif [ -x /usr/bin/clang ]; then
    export CC=/usr/bin/clang
    export CXX=/usr/bin/clang++
    echo "${GREEN}Using base system Clang${NC}"
else
    echo "${RED}No suitable C++ compiler found${NC}"
    echo "Please install LLVM: sudo pkg install llvm18"
    MISSING_DEPS=true
fi

if [ "$MISSING_DEPS" = true ]; then
    echo "${RED}Missing dependencies. Please install them and try again.${NC}"
    exit 1
fi

# Configure CMake arguments
CMAKE_ARGS="-G Ninja"
CMAKE_ARGS="${CMAKE_ARGS} -DCMAKE_BUILD_TYPE=${BUILD_TYPE}"
CMAKE_ARGS="${CMAKE_ARGS} -DCMAKE_C_COMPILER=${CC}"
CMAKE_ARGS="${CMAKE_ARGS} -DCMAKE_CXX_COMPILER=${CXX}"

if [ "$ENABLE_TESTS" = true ]; then
    CMAKE_ARGS="${CMAKE_ARGS} -DBUILD_TESTS=ON"
fi

if [ -n "$ENABLE_EXTENSIONS" ]; then
    CMAKE_ARGS="${CMAKE_ARGS} -DBUILD_EXTENSIONS=${ENABLE_EXTENSIONS}"
fi

# Runtime checks for debug builds
if [ "$BUILD_TYPE" = "Debug" ]; then
    CMAKE_ARGS="${CMAKE_ARGS} -DENABLE_RUNTIME_CHECKS=ON"
fi

# Create build directory
mkdir -p "${BUILD_DIR}"

# Configure
echo "${YELLOW}Configuring build...${NC}"
echo "Build type: ${BUILD_TYPE}"
echo "Build directory: ${BUILD_DIR}"
echo "Parallel jobs: ${JOBS}"
if [ -n "$ENABLE_EXTENSIONS" ]; then
    echo "Extensions: ${ENABLE_EXTENSIONS}"
fi

cmake -S . -B "${BUILD_DIR}" ${CMAKE_ARGS}

# Build
echo "${YELLOW}Building Kuzu...${NC}"
cmake --build "${BUILD_DIR}" --parallel "${JOBS}"

echo "${GREEN}Build completed successfully!${NC}"
echo ""
echo "Binary location: ${BUILD_DIR}/src/kuzu_shell"
echo ""
echo "To run the shell:"
echo "  ${BUILD_DIR}/src/kuzu_shell"
echo ""

if [ "$ENABLE_TESTS" = true ]; then
    echo "To run tests:"
    echo "  cd ${BUILD_DIR} && ctest --output-on-failure"
    echo ""
fi

# Quick sanity check
if [ -x "${BUILD_DIR}/src/kuzu_shell" ]; then
    echo "${YELLOW}Running version check...${NC}"
    "${BUILD_DIR}/src/kuzu_shell" --version
else
    echo "${RED}Warning: kuzu_shell binary not found or not executable${NC}"
fi
