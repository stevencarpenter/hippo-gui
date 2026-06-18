#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GUI_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
PLIST_PATH="${1:-}"

usage() {
  echo "Usage: $0 /path/to/Info.plist" >&2
}

fail() {
  echo "$*" >&2
  exit 1
}

if [ -z "${PLIST_PATH}" ]; then
  usage
  exit 64
fi

if [ ! -f "${PLIST_PATH}" ]; then
  fail "Info.plist not found at ${PLIST_PATH}"
fi

resolve_marketing_version() {
  if [ -n "${HIPPO_MARKETING_VERSION:-}" ]; then
    printf '%s\n' "${HIPPO_MARKETING_VERSION}"
    return
  fi

  VERSION_FILE="${GUI_DIR}/VERSION"
  if [ -f "${VERSION_FILE}" ]; then
    tr -d '[:space:]' < "${VERSION_FILE}"
  fi
}

resolve_build_number() {
  if [ -n "${HIPPO_BUILD_NUMBER:-}" ]; then
    printf '%s\n' "${HIPPO_BUILD_NUMBER}"
    return
  fi

  if [ -n "${BUILD_NUMBER:-}" ]; then
    printf '%s\n' "${BUILD_NUMBER}"
    return
  fi

  if git -C "${GUI_DIR}" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    git -C "${GUI_DIR}" rev-list --count HEAD
    return
  fi

  printf '1\n'
}

set_plist_key() {
  local key="$1"
  local type="$2"
  local value="$3"

  if /usr/libexec/PlistBuddy -c "Print :${key}" "${PLIST_PATH}" >/dev/null 2>&1; then
    /usr/libexec/PlistBuddy -c "Set :${key} ${value}" "${PLIST_PATH}" >/dev/null
  else
    /usr/libexec/PlistBuddy -c "Add :${key} ${type} ${value}" "${PLIST_PATH}" >/dev/null
  fi
}

MARKETING_VERSION="$(resolve_marketing_version)"
BUILD_VERSION="$(resolve_build_number)"

if [ -z "${MARKETING_VERSION}" ]; then
  fail "Failed to resolve marketing version from HIPPO_MARKETING_VERSION or ${GUI_DIR}/VERSION"
fi

if [[ ! "${MARKETING_VERSION}" =~ ^[0-9]+(\.[0-9]+){1,2}$ ]]; then
  fail "Marketing version '${MARKETING_VERSION}' must be numeric dotted version like 0.11.0"
fi

if [[ ! "${BUILD_VERSION}" =~ ^[0-9]+$ ]]; then
  fail "Build number '${BUILD_VERSION}' must be numeric"
fi

set_plist_key CFBundleShortVersionString string "${MARKETING_VERSION}"
set_plist_key CFBundleVersion string "${BUILD_VERSION}"

echo "Stamped ${PLIST_PATH} with version ${MARKETING_VERSION} (${BUILD_VERSION})"