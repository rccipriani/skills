# Toolchain provisioning

## Operations

- `check`: read-only discovery of OS, architecture, tools, versions, adv3, documentation, examples, and build prerequisites.
- `install`: create and review an installation plan; execute only after explicit authorization.
- `validate`: compile and run the neutral standard-adv3 fixture in a temporary directory.
- `repair`: diagnose a broken installation and print targeted corrective actions; do not overwrite it.

Run `scripts/tads3-toolchain.sh MODE`. The script honors `TADS3_HOME`, `TADS3_INCLUDE`, `TADS3_LIB`, `TADS3_DOC`, `TADS3_SAMPLES`, `T3MAKE`, and `FROB`.

## Source provenance

Use a verified upstream FrobTADS release or repository supplied by the user/project. Record URL, release/tag or commit, archive SHA-256, retrieval date, installation prefix, compiler versions, CMake version, and dependency versions. Do not embed a download URL unless verified from authoritative current documentation. Do not redistribute sources, binaries, manuals, or samples without reviewing their licenses.

FrobTADS 2.0's included installation documentation requires CMake, a C11/C++14 compiler, ncurses development files for the interpreter, and libcurl development files for TADS 3 networking. It supports a user prefix with `-DCMAKE_INSTALL_PREFIX=/owned/path`.

## RHEL 9 and compatible distributions

First check distribution repositories for a maintained FrobTADS/TADS package. If none is approved, the verified source-build prerequisites on the audited RHEL 9 environment were GCC/G++, CMake, Make, `ncurses-devel`, and `libcurl-devel`.

After authorization, a typical dependency command is:

```sh
sudo dnf install gcc gcc-c++ cmake make ncurses-devel libcurl-devel
```

Do not run it automatically. Build from an already verified source directory:

```sh
cmake -S /path/to/frobtads-source -B /tmp/frobtads-build \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX="$HOME/.local"
cmake --build /tmp/frobtads-build
cmake --install /tmp/frobtads-build
```

Use a dedicated user-owned prefix instead of `$HOME/.local` when isolation is preferred.

## Ubuntu and Debian

Check official distribution repositories first. For an approved source build, commonly required development packages are a C/C++ build toolchain, CMake, Make, ncurses development files, and libcurl development files. Confirm exact package names for the target release before installation; a typical Debian-family plan is:

```sh
sudo apt-get update
sudo apt-get install build-essential cmake libncurses-dev libcurl4-openssl-dev
```

Do not execute privileged commands without authorization. Use the same user-prefix CMake build shown above.

## Windows

FrobTADS 2.0's bundled documentation states that current MinGW/MSYS native builds are not supported and identifies 1.0 as the last known MinGW-buildable version. Prefer WSL2 with the Ubuntu/Debian procedure or a Linux Docker/Podman container. A native Windows TADS toolchain can be used when obtained from an authoritative TADS distribution, but paths and interpreter names differ; validate it rather than pretending FrobTADS commands apply.

## Idempotence and safety

- Never replace an existing executable or prefix silently.
- Install into a new versioned prefix when possible.
- Keep build directories separate from sources and projects.
- Compare discovered versions and hashes before proposing repair.
- Let `install` print commands by default. Execute only when the caller supplies an approved source path and installation prefix.
- Never feed unverified archives directly to a privileged installer.

## Validation contract

Validation succeeds only if it:

1. locates `t3make`;
2. resolves standard adv3 headers and libraries;
3. compiles the neutral fixture;
4. locates an interpreter, normally `frob`;
5. runs a deterministic smoke transcript;
6. confirms expected semantic markers;
7. compiles both debug and release configurations and verifies debug-only grammar is excluded from release.

Failure output should identify the missing executable/path/library or the build/runtime stage, without suggesting destructive repair.
