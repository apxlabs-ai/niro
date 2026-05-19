#!/usr/bin/env sh
# Niro installer for macOS and Linux.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/apxlabs-ai/niro/main/install.sh | sh
#
# Environment variables:
#   NIRO_VERSION       Pin to a specific tag (e.g. v0.1.0). Defaults to latest.
#   NIRO_INSTALL_DIR   Override install directory. Defaults to ~/.local/bin.

set -eu

REPO="apxlabs-ai/niro"
BIN_NAME="niro"
INSTALL_DIR="${NIRO_INSTALL_DIR:-${HOME}/.local/bin}"

die() { printf "niro install: %s\n" "$*" >&2; exit 1; }

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
