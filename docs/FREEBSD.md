# FreeBSD Support for Kuzu

Kuzu now supports building and running on FreeBSD systems. This document describes how to build Kuzu on FreeBSD and the current state of platform support.

## Systems Using FreeBSD

FreeBSD serves as the foundation for many systems and platforms:

- **OPNsense** - Open source firewall and routing platform
- **pfSense** - Firewall and router software distribution
- **PlayStation 4 & PlayStation 5** - Gaming consoles (modified FreeBSD kernel)
- **Nintendo Switch** - Gaming console (FreeBSD-based kernel)
- **TrueNAS** - Network-attached storage operating system
- **Juniper Networks JunOS** - Router and switch operating system
- **macOS** - Incorporates FreeBSD userland utilities and network stack

Related BSD systems that may benefit from this work:
- **OpenBSD** - Security-focused BSD variant
- **NetBSD** - Highly portable BSD variant
- **DragonFly BSD** - Performance-focused BSD variant

## Supported FreeBSD Version

- FreeBSD 14.x (tested with 14.3)

## Prerequisites

Install the required packages using `pkg`:

```sh
# Update package database
sudo pkg update

# Install build dependencies
sudo pkg install -y cmake gmake pkgconf

# Optional: Install additional dependencies
sudo pkg install -y ninja  # For faster builds
sudo pkg install -y utf8proc curl openssl  # For extensions
```

## Building Kuzu

### Quick Build

Use the provided build script:

```sh
# Basic release build
./scripts/build-freebsd.sh

# Debug build with tests
./scripts/build-freebsd.sh --debug --tests

# Build with extensions
./scripts/build-freebsd.sh --extensions httpfs,json

# Build with all extensions
./scripts/build-freebsd.sh --extensions ALL
```

### Manual Build

```sh
# Set compiler (if using ports LLVM)
export CC=/usr/local/bin/clang18
export CXX=/usr/local/bin/clang++18

# Configure
cmake -S . -B build \
  -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DBUILD_TESTS=ON

# Build
cmake --build build --parallel $(sysctl -n hw.ncpu)

# Run tests
cd build && ctest --output-on-failure

# Run the shell
./build/src/kuzu_shell
```

## FreeBSD-Specific Changes

The following adjustments have been made to support FreeBSD:

1. **OS Detection**: CMake now properly detects FreeBSD as a separate platform
2. **Library Paths**: Automatically adds `/usr/local` to the CMake prefix path for ports packages
3. **Library Linking**:
   - `dlopen()` functions are in libc (no separate `libdl`)
   - Backtrace support via `libexecinfo`
4. **RPATH Configuration**: Sets proper RPATH to `/usr/local/lib` for finding shared libraries

## Known Issues and Limitations

1. **Extensions**: Not all extensions have been thoroughly tested on FreeBSD
2. **Performance**: Performance tuning specific to FreeBSD has not been done
3. **Language Bindings**: Python, Node.js, and Java bindings should work but may require additional testing

## CI/CD

FreeBSD builds are tested in CI using GitHub Actions with the `vmactions/freebsd-vm` action. The following workflows include FreeBSD support:

- `freebsd-ci-workflow.yml`: Main CI workflow for FreeBSD
- `freebsd-precompiled-bin-workflow.yml`: Builds precompiled binaries
- `multiplatform-build-test.yml`: Includes FreeBSD in multiplatform testing

## Troubleshooting

### Compiler Not Found

If you get compiler errors, ensure LLVM is installed and set the environment variables:

```sh
export CC=/usr/local/bin/clang18
export CXX=/usr/local/bin/clang++18
```

### Missing Libraries

If linking fails with missing symbols, ensure all required packages are installed:

```sh
sudo pkg install -y utf8proc
```

### Test Failures

Some tests may fail due to platform-specific differences. Report any consistent failures as issues.

## Contributing

When contributing FreeBSD-specific changes:

1. Test on FreeBSD 14.3
2. Ensure changes don't break other platforms
3. Update this documentation if adding new dependencies or changing build requirements
4. Add FreeBSD-specific CI tests for new features

## Support

FreeBSD support is community-maintained. For FreeBSD-specific issues:

1. Check this documentation first
2. Search existing GitHub issues
3. Open a new issue with the `freebsd` label
4. Include FreeBSD version, compiler version, and full error messages
