# projectM installer

This repository contains a helper script that builds and installs the projectM backend, the SDL frontend, and optionally the presets pack from their upstream git repositories.

The script is designed to clone the requested source trees at specific tags, configure them with CMake, compile them in a temporary work directory, install them under a common prefix, and print a ready-to-run example command for the frontend.

## What the script does

When you run `install.sh`, it performs the following steps:

1. Parses command-line options.
2. Creates a temporary build directory.
3. Clones the projectM backend repository and checks out the configured tag.
4. Builds the backend with CMake using the selected build type.
5. Installs the backend under `<prefix>/projectM/backend`
6. Clones the SDL frontend repository and checks out the configured tag.
7. Builds the frontend with the backend install path added to CMake search paths.
8. Installs the frontend under `<prefix>/projectM/frontend`
9. Optionally clones the presets repository into `<prefix>/projectM/presets`
10. Prints an installation summary and an example launch command for the frontend.

This script is useful when you want a repeatable local installation of the projectM stack without manually running each build step by hand.

## Default behavior

By default, the script installs:

- projectM backend tag: `v4.1.7`
- SDL frontend tag: `2.0.0-pre1`
- build type: `Release`
- no presets repository installed
- temporary work directory removed on success

## Requirements

The script expects an environment with the standard build tools installed, such as:

- `bash`
- `git`
- `cmake`
- `make` or another CMake-supported generator
- a C/C++ toolchain (gcc/clang, etc.)
- the dependencies required by the projectM backend and frontend builds

## Usage

Run the script from the repository root or any directory that can access the script:

```bash
./install.sh --prefix /opt/projectM
```

The `--prefix` option is required. The script validates this before running the installation.

## Command-line options

```text
Usage: ./install.sh [OPTIONS]

  -t | --build-type <BUILD_TYPE>   Build type (default: Release)
  -b | --back-end-git-tag <TAG>    Back-end projectM git tag (default: v4.1.7)
  -f | --front-end-git-tag <TAG>   Front-end sdl-cpp git tag (default: 2.0.0-pre1)
  -P | --with-presets              Clone and install the presets pack
  -d | --debug                     Keep the temporary work directory for debugging
  -p | --prefix <PREFIX>           Installation prefix; required
  -h | --help                      Show help and exit
```

### Option details

- `-t, --build-type`
  Selects the CMake build type, typically `Debug`, `Release`, or `RelWithDebInfo`.

- `-b, --back-end-git-tag`
  Checks out a specific git tag or ref for the projectM backend repository.

- `-f, --front-end-git-tag`
  Checks out a specific git tag or ref for the SDL frontend repository.

- `-P, --with-presets`
  Downloads the presets repository and installs it under the configured prefix. This adds the preset path used by the generated example launch command.

- `-d, --debug`
  Keeps the temporary build directory rather than deleting it after installation. This is helpful when diagnosing build issues.

- `-p, --prefix`
  Sets the installation root. The script uses this value as the top-level directory under which the backend, frontend, and presets are installed.

- `-h, --help`
  Displays the usage message and exits without installing anything.

## Examples

### Basic installation including presets

```bash
./install.sh --prefix $HOME/software --with-presets
```

### Install a specific backend version

```bash
./install.sh --prefix $HOME/software --back-end-git-tag v4.1.6
```

### Keep the temporary working directory for debugging

```bash
./install.sh --prefix /tmp/projectM --debug
```

## Installed layout

The script installs the pieces under the prefix like this:

```text
<prefix>/projectM/
├── backend/
├── frontend/
└── presets/   # only when --with-presets is used
```

The final output from the script includes a sample command similar to:

```bash
<prefix>/projectM/frontend/bin/projectMSDL --listAudioDevices --audioDevice=-1 --shuffleEnabled=0 --beatSensitivity=1.5 --presetPath=<prefix>/projectM/presets
```
