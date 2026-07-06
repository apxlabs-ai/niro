#!/usr/bin/env sh
# Niro CI installer for macOS and Linux.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/apxlabs-ai/niro/main/install-ci.sh | sh
#
# Environment variables:
#   NIRO_VERSION       Pin to a specific tag (e.g. v0.1.0). Defaults to latest.
#   NIRO_INSTALL_DIR   Override install root. Defaults to ~/.niro.

set -eu

REPO="apxlabs-ai/niro"
BIN_NAME="niro"
CI_BIN_NAME="niro-ci"

if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  C_WARN=$(printf '\033[1;33m')
  C_ERR=$(printf '\033[1;31m')
  C_RESET=$(printf '\033[0m')
else
  C_WARN=""
  C_ERR=""
  C_RESET=""
fi

die() { printf "%sError:%s %s\n" "$C_ERR" "$C_RESET" "$*" >&2; exit 1; }
warn() { printf "\n%sWarning:%s %s\n" "$C_WARN" "$C_RESET" "$*"; }

if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  url_link() { printf '\033]8;;%s\033\\%s\033]8;;\033\\' "$1" "$1"; }
else
  url_link() { printf '%s' "$1"; }
fi

INSTALL_ROOT="${NIRO_INSTALL_DIR:-${HOME}/.niro}"
BIN_DIR="${INSTALL_ROOT}/bin"
CI_SCRIPT_DIR="${INSTALL_ROOT}/scripts/ci"
CI_PROVIDER_DIR="${CI_SCRIPT_DIR}/providers"

OS=$(uname -s | tr '[:upper:]' '[:lower:]')
case "$OS" in
  darwin|linux) ;;
  *) die "unsupported OS: $OS (use install.ps1 on Windows)" ;;
esac

ARCH=$(uname -m)
case "$ARCH" in
  x86_64|amd64) ARCH=amd64 ;;
  arm64|aarch64) ARCH=arm64 ;;
  *) die "unsupported architecture: $ARCH" ;;
esac

VERSION="${NIRO_VERSION:-latest}"
ARCHIVE="niro_${OS}_${ARCH}.tar.gz"
if [ "$VERSION" = "latest" ]; then
  RESOLVED=$(curl -fsSLI -o /dev/null -w '%{url_effective}' \
    "https://github.com/${REPO}/releases/latest" 2>/dev/null) || RESOLVED=""
  case "$RESOLVED" in
    */releases/tag/*) VERSION=$(printf '%s' "$RESOLVED" | sed 's|.*/||') ;;
  esac
  BASE_URL="https://github.com/${REPO}/releases/latest/download"
else
  BASE_URL="https://github.com/${REPO}/releases/download/${VERSION}"
fi

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

printf "Downloading niro %s (%s/%s)\n" "$VERSION" "$OS" "$ARCH"
curl -fsSL -o "${TMP}/${ARCHIVE}" "${BASE_URL}/${ARCHIVE}" \
  || die "download failed: ${BASE_URL}/${ARCHIVE}"

printf "Verifying checksum\n"
curl -fsSL -o "${TMP}/checksums.txt" "${BASE_URL}/checksums.txt" \
  || die "checksums.txt download failed"
( cd "$TMP" && grep " ${ARCHIVE}\$" checksums.txt | shasum -a 256 -c - >/dev/null ) \
  || die "checksum verification failed"

tar -xzf "${TMP}/${ARCHIVE}" -C "$TMP"

mkdir -p "$BIN_DIR" "$CI_SCRIPT_DIR" "$CI_PROVIDER_DIR"
[ -f "${TMP}/${BIN_NAME}" ] || die "release archive missing required file: $BIN_NAME"

printf "Installing to %s/%s\n" "$BIN_DIR" "$BIN_NAME"
mv "${TMP}/${BIN_NAME}" "${BIN_DIR}/${BIN_NAME}"
chmod +x "${BIN_DIR}/${BIN_NAME}"

# CI scripts and settings come from the published repo (raw main), not the
# release archive: they are plain text iterated independently of the binary, so
# publishing the public repo ships a change without a new release. Same origin
# and trust as this installer itself. Override the ref with NIRO_CI_REF.
RAW_BASE="https://raw.githubusercontent.com/${REPO}/${NIRO_CI_REF:-main}"
printf "Fetching CI scripts from %s\n" "${NIRO_CI_REF:-main}"
fetch_ci() {
  curl -fsSL -o "$2" "${RAW_BASE}/$1" || die "download failed: ${RAW_BASE}/$1"
  if [ "${3:-}" = "x" ]; then chmod +x "$2"; fi
}
fetch_ci scripts/ci/niro-ci.sh                     "${BIN_DIR}/${CI_BIN_NAME}"             x
fetch_ci scripts/ci/lib.sh                         "${CI_SCRIPT_DIR}/lib.sh"
fetch_ci scripts/ci/collect-knowledge.sh           "${CI_SCRIPT_DIR}/collect-knowledge"   x
fetch_ci scripts/ci/collect-debug-logs.sh          "${CI_SCRIPT_DIR}/collect-debug-logs"  x
fetch_ci scripts/ci/providers/generic.sh           "${CI_PROVIDER_DIR}/generic.sh"
fetch_ci scripts/ci/providers/github-actions.sh    "${CI_PROVIDER_DIR}/github-actions.sh"
fetch_ci scripts/ci/providers/claude.settings.json "${CI_PROVIDER_DIR}/claude.settings.json"

printf "\nniro %s CI tools installed. Run \`niro-ci find\` or \`niro-ci fix\` from CI.\n" "$VERSION"

if [ -n "${GITHUB_PATH:-}" ]; then
  printf "%s\n" "$BIN_DIR" >> "$GITHUB_PATH" \
    || warn "could not add ${BIN_DIR} to GitHub Actions PATH."
fi

case ":${PATH}:" in
  *":${BIN_DIR}:"*) ;;
  *)
    if [ -z "${GITHUB_PATH:-}" ]; then
      warn "${BIN_DIR} is not on PATH."
      printf "    Add to your shell rc (~/.zshrc, ~/.bashrc):\n\n"
      printf "        export PATH=\"%s:\$PATH\"\n" "$BIN_DIR"
    fi
    ;;
esac

if ! command -v docker >/dev/null 2>&1 \
  && ! command -v podman >/dev/null 2>&1 \
  && ! command -v nerdctl >/dev/null 2>&1; then
  warn "no container runtime found. niro needs Docker, Podman, or nerdctl to run pentests."
  printf "    Docker:  %s\n" "$(url_link https://docker.com)"
  printf "    Podman:  %s\n" "$(url_link https://podman.io)"
fi
