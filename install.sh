#!/bin/bash

set -euo pipefail
shopt -s inherit_errexit

BACK_END_GIT_URL="https://github.com/projectM-visualizer/projectm.git"
FRONT_END_GIT_URL="https://github.com/projectM-visualizer/frontend-sdl-cpp.git"
PRESETS_GIT_URL="https://github.com/projectM-visualizer/presets-cream-of-the-crop.git"

WORK_DIR=""
BUILD_TYPE="Release"
BACK_END_GIT_TAG="v4.1.7"
FRONT_END_GIT_TAG="2.0.0-pre1"
PREFIX=""
WITH_PRESETS="false"
KEEP_WORK_DIR="false"

function log_banner() {
  local title="$1"
  printf '\n╔══════════════════════════════════════════════╗\n' >&2
  printf '║ %-44s ║\n' "${title}" >&2
  printf '╚══════════════════════════════════════════════╝\n\n' >&2
}

function show_help() {
  printf 'Usage: %s [OPTIONS]\n' "$0"
  printf '\n'
  printf '  -t | --build-type <BUILD_TYPE>   Build type (default:%s)\n' "${BUILD_TYPE}"
  printf '  -b | --back-end-git-tag <TAG>    Back-end projectM git tag (default: %s, see available tags in %s)\n' "${BACK_END_GIT_TAG}" "${BACK_END_GIT_URL}"
  printf '  -f | --front-end-git-tag <TAG>   Front-end sdl-cpp git tag (default: %s, see available tags in %s)\n' "${FRONT_END_GIT_TAG}" "${FRONT_END_GIT_URL}"
  printf '  -P | --with-presets              Install the presets pack from %s (optional)\n' "${PRESETS_GIT_URL}"
  printf '  -d | --debug                     Keep the temporary work directory for debugging\n'
  printf '  -p | --prefix <PREFIX>           Installation prefix\n'
  printf '  -h | --help                      Show this help message\n'
}

function parse_args() {
  log_banner "parse_args"
  local parsed_options
  parsed_options="$(
    getopt \
      -o 't:b:f:Pp:d:h' \
      -l 'build-type:,back-end-git-tag:,front-end-git-tag:,with-presets,prefix:,debug,help' \
      -- "$@"
  )" || {
    show_help >&2
    return 1
  }
  eval set -- "${parsed_options}"

  while true; do
    case "$1" in
    -t | --build-type)
      BUILD_TYPE="$2"
      shift 2
      ;;
    -b | --back-end-git-tag)
      BACK_END_GIT_TAG="$2"
      shift 2
      ;;
    -f | --front-end-git-tag)
      FRONT_END_GIT_TAG="$2"
      shift 2
      ;;
    -P | --with-presets)
      WITH_PRESETS="true"
      shift
      ;;
    -d | --debug)
      KEEP_WORK_DIR="true"
      shift
      ;;
    -p | --prefix)
      PREFIX="$(realpath -m "$2")"
      shift 2
      ;;
    -h | --help)
      show_help
      exit 0
      ;;
    --)
      shift
      break
      ;;
    *)
      show_help >&2
      return 1
      ;;
    esac
  done

  if [[ -z "${PREFIX}" || "$#" -ne 0 ]]; then
    show_help >&2
    return 1
  fi
}

function create_work_dir() {
  log_banner "create_work_dir"
  WORK_DIR="$(mktemp -d)"
  printf 'Work dir: %s\n' "${WORK_DIR}" >&2
}

function remove_work_dir() {
  log_banner "remove_work_dir"
  printf 'Removing work dir: %s\n' "${WORK_DIR}" >&2
  rm -fr "${WORK_DIR}"
}

function print_args_summary() {
  log_banner "print_args_summary"
  printf '%s\n' "Building projectM with the following configuration:" >&2
  printf 'Build type          %s\n' "${BUILD_TYPE}" >&2
  printf 'Back-end git tag    %s\n' "${BACK_END_GIT_TAG}" >&2
  printf 'Front-end git tag   %s\n' "${FRONT_END_GIT_TAG}" >&2
  printf 'With presets?       %s\n' "${WITH_PRESETS}" >&2
  printf 'Keep work dir?      %s\n' "${KEEP_WORK_DIR}" >&2
  printf 'Install prefix      %s\n' "${PREFIX}" >&2
}

function clone_repo() {
  log_banner "clone_repo"
  printf 'module=%s tag=%s\n' "$1" "$3" >&2
  local module="$1"
  local git_url="$2"
  local tag="$3"

  local repo_dir="${WORK_DIR}/repo/${module}"
  rm -fr "${repo_dir}"
  git clone "${git_url}" "${repo_dir}" >&2
  git -C "${repo_dir}" fetch --all --tags >&2
  git -C "${repo_dir}" submodule update --init --recursive >&2
  git -C "${repo_dir}" checkout -B "release/${tag}" "${tag}" >&2

  echo "${repo_dir}"
}

function build() {
  log_banner "build"
  printf 'module=%s\n' "$1" >&2
  local module="$1"
  local repo_dir="$2"
  shift 2
  local cmake_args=("$@")

  local build_dir="${WORK_DIR}/build/${module}"
  rm -fr "${build_dir}"
  mkdir -p "${build_dir}"

  cmake \
    -S "${repo_dir}" \
    -B "${build_dir}" \
    -DCMAKE_BUILD_TYPE="${BUILD_TYPE}" \
    "${cmake_args[@]}" >&2

  cmake --build "${build_dir}" --parallel 2 >&2

  echo "${build_dir}"
}

function install() {
  log_banner "install"
  printf 'module=%s\n' "$1" >&2
  local module="$1"
  local build_dir="$2"

  local install_dir
  install_dir="${PREFIX}/projectM/${module}"
  cmake --install "${build_dir}" --prefix "${install_dir}" >&2
  echo "${install_dir}"
}

function build_and_install() {
  log_banner "build_and_install"
  printf 'module=%s tag=%s\n' "$1" "$3" >&2
  local module="$1"
  local git_url="$2"
  local git_tag="$3"
  shift 3
  local cmake_args=("$@")

  local repo_dir
  repo_dir="$(clone_repo "${module}" "${git_url}" "${git_tag}")"

  local build_dir
  build_dir="$(build "${module}" "${repo_dir}" "${cmake_args[@]}")"

  install "${module}" "${build_dir}"
}

function clone_presets() {
  log_banner "clone_presets"
  printf 'target=%s\n' "${PREFIX}/projectM/presets" >&2
  local git_url="$1"
  local target_dir="${PREFIX}/projectM/presets"
  local temporary_dir="${WORK_DIR}/presets"

  rm -rf "${temporary_dir}"
  mkdir -p "$(dirname "${target_dir}")"
  git clone "${git_url}" "${temporary_dir}" >&2
  rm -rf "${target_dir}"
  mv "${temporary_dir}" "${target_dir}"

  echo "${target_dir}"
}

function main() {
  log_banner "main: starting install"
  parse_args "$@"
  print_args_summary
  create_work_dir
  if [[ "${KEEP_WORK_DIR}" == "false" ]]; then
    trap 'remove_work_dir' EXIT
  else
    printf 'Keeping temporary work dir for debugging: %s\n' "${WORK_DIR}" >&2
  fi

  local back_end_install_dir
  back_end_install_dir="$(
    build_and_install \
      "backend" \
      "${BACK_END_GIT_URL}" \
      "${BACK_END_GIT_TAG}" \
      -DENABLE_SDL_UI=ON \
      -DENABLE_PLAYLIST=ON \
      -DBUILD_SHARED_LIBS=ON
  )"

  local front_end_install_dir
  front_end_install_dir="$(
    build_and_install \
      "frontend" \
      "${FRONT_END_GIT_URL}" \
      "${FRONT_END_GIT_TAG}" \
      -DCMAKE_PREFIX_PATH="${back_end_install_dir}" \
      -DCMAKE_INSTALL_RPATH="${back_end_install_dir}/lib"
  )"

  local presets_dir
  if [[ "${WITH_PRESETS}" == "true" ]]; then
    presets_dir="$(clone_presets "${PRESETS_GIT_URL}")"
  fi

  log_banner "main: install complete"
  printf '\nInstalaltion summary\n'
  printf '====================\n'
  printf 'Backend:  %s\n' "${back_end_install_dir}"
  printf 'Frontend: %s\n' "${front_end_install_dir}"
  [[ -n "${presets_dir:-}" ]] && printf 'Presets:  %s\n' "${presets_dir}"

  local command
  command="${front_end_install_dir}/bin/projectMSDL --listAudioDevices --audioDevice=-1 --shuffleEnabled=0 --beatSensitivity=1.5"

  printf '\nExample usage\n'
  printf '=============\n'
  if [[ -n "${presets_dir:-}" ]]; then
    printf '%s --presetPath=%s\n' "${command}" "${presets_dir}"
  else
    printf '%s\n' "${command}"
  fi

  if [[ "${KEEP_WORK_DIR}" == "true" ]]; then
    printf '\nDebug note: temporary work dir preserved at %s\n' "${WORK_DIR}"
  fi
}

main "$@"
