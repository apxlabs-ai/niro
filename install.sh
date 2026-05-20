#!/usr/bin/env sh
# Niro installer for macOS and Linux.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/apxlabs-ai/niro/main/install.sh | sh
#
# Environment variables:
#   NIRO_VERSION       Pin to a specific tag (e.g. v0.1.0). Defaults to latest.
#   NIRO_INSTALL_DIR   Override install directory. Defaults to the first
#                      writable PATH-resident directory found among:
#                      /opt/homebrew/bin (Apple Silicon Homebrew),
#                      /usr/local/bin (Intel Homebrew / common system bin).
#                      Falls back to ~/.local/bin if none qualify.

set -eu

REPO="apxlabs-ai/niro"
BIN_NAME="niro"

die() { printf "niro install: %s\n" "$*" >&2; exit 1; }

# Pick an install directory that's already on PATH and user-writable so the
# user doesn't have to edit their shell rc. Try in priority order; fall back
# to ~/.local/bin (universal, but not on macOS's default PATH).
pick_install_dir() {
  if [ -n "${NIRO_INSTALL_DIR:-}" ]; then
    printf "%s" "$NIRO_INSTALL_DIR"
    return
  fi
  for d in /opt/homebrew/bin /usr/local/bin; do
    if [ -d "$d" ] && [ -w "$d" ] && printf ":%s:" "$PATH" | grep -q ":$d:"; then
      printf "%s" "$d"
      return
    fi
  done
  printf "%s" "${HOME}/.local/bin"
}

INSTALL_DIR=$(pick_install_dir)

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
  BASE_URL="https://github.com/${REPO}/releases/latest/download"
else
  BASE_URL="https://github.com/${REPO}/releases/download/${VERSION}"
fi

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

printf "Downloading %s\n" "$ARCHIVE"
curl -fsSL -o "${TMP}/${ARCHIVE}" "${BASE_URL}/${ARCHIVE}" \
  || die "download failed: ${BASE_URL}/${ARCHIVE}"

printf "Verifying checksum\n"
curl -fsSL -o "${TMP}/checksums.txt" "${BASE_URL}/checksums.txt" \
  || die "checksums.txt download failed"
( cd "$TMP" && grep " ${ARCHIVE}\$" checksums.txt | shasum -a 256 -c - >/dev/null ) \
  || die "checksum verification failed"

printf "Extracting\n"
tar -xzf "${TMP}/${ARCHIVE}" -C "$TMP" "$BIN_NAME"

mkdir -p "$INSTALL_DIR"
mv "${TMP}/${BIN_NAME}" "${INSTALL_DIR}/${BIN_NAME}"
chmod +x "${INSTALL_DIR}/${BIN_NAME}"

printf "\nInstalled %s (%s) to %s/%s\n" "$BIN_NAME" "$VERSION" "$INSTALL_DIR" "$BIN_NAME"

case ":${PATH}:" in
  *":${INSTALL_DIR}:"*) ;;
  *)
    printf "\nNote: %s is not on your PATH.\n" "$INSTALL_DIR"
    printf "Add this line to your shell rc (~/.zshrc, ~/.bashrc):\n\n"
    printf "  export PATH=\"%s:\$PATH\"\n" "$INSTALL_DIR"
    ;;
esac

# Heads-up: niro spawns pentests inside containers, so it needs Docker,
# Podman, or nerdctl on PATH. Non-blocking — install has already
# succeeded — but flag the gap so the user sees the same canonical
# message that `niro init` prints as a "Heads up:" line and that
# `start_pentest` returns inline to the coding agent when called
# without a runtime available. One string across all four surfaces.
if ! command -v docker >/dev/null 2>&1 \
  && ! command -v podman >/dev/null 2>&1 \
  && ! command -v nerdctl >/dev/null 2>&1; then
  printf "\nHeads up: niro needs Docker (or Podman / nerdctl) installed locally to run pentests. Install Docker from https://docker.com or Podman from https://podman.io.\n"
fi
