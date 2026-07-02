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
RUN_BIN_NAME="run-niro"
DEBUG_BIN_NAME="niro-collect-debug-artifacts"

# ANSI colors for status prefixes. Yellow for Warning, red for Error.
# Skip coloring if stdout isn't a tty (log capture) or NO_COLOR is set
# per https://no-color.org. printf because echo -e isn't portable
# across /bin/sh implementations.
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

# OSC 8 hyperlinks render URLs as clickable in modern terminals
# (iTerm2, WezTerm, Kitty, Windows Terminal, VSCode, GNOME Terminal).
# Older terms drop the escape silently. macOS Terminal.app ignores
# OSC 8 but its own URL auto-detection still makes plain URLs
# cmd+clickable. Guarded by the same TTY/NO_COLOR check so log
# captures and explicitly-uncolored output stay clean.
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  url_link() { printf '\033]8;;%s\033\\%s\033]8;;\033\\' "$1" "$1"; }
else
  url_link() { printf '%s' "$1"; }
fi

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
  # Resolve "latest" to the concrete tag so progress and success lines
  # show what the user actually got. /releases/latest 302-redirects to
  # /releases/tag/<vX.Y.Z>; a HEAD with -w '%{url_effective}' gives us
  # the final URL without touching the rate-limited API. Best-effort:
  # if resolve fails (offline, GitHub flaky) we keep "latest" and the
  # download still works via the same redirect.
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

printf "Installing to %s/%s\n" "$INSTALL_DIR" "$BIN_NAME"
mkdir -p "$INSTALL_DIR"
mv "${TMP}/${BIN_NAME}" "${INSTALL_DIR}/${BIN_NAME}"
chmod +x "${INSTALL_DIR}/${BIN_NAME}"
for helper in "$RUN_BIN_NAME" "$DEBUG_BIN_NAME"; do
  if [ -f "${TMP}/${helper}" ]; then
    printf "Installing to %s/%s\n" "$INSTALL_DIR" "$helper"
    mv "${TMP}/${helper}" "${INSTALL_DIR}/${helper}"
    chmod +x "${INSTALL_DIR}/${helper}"
  fi
done

printf "\nniro %s installed. Run \`niro init\` to get started.\n" "$VERSION"

case ":${PATH}:" in
  *":${INSTALL_DIR}:"*) ;;
  *)
    warn "${INSTALL_DIR} is not on PATH."
    printf "    Add to your shell rc (~/.zshrc, ~/.bashrc):\n\n"
    printf "        export PATH=\"%s:\$PATH\"\n" "$INSTALL_DIR"
    ;;
esac

# niro spawns pentests inside containers, so it needs Docker, Podman,
# or nerdctl on PATH. Non-blocking — install has already succeeded.
# This is also surfaced by `niro init` and by the start_pentest tool
# when called without a runtime available; keep the wording in sync
# across those surfaces (cmd/niro-cli/main.go in niro-internal).
if ! command -v docker >/dev/null 2>&1 \
  && ! command -v podman >/dev/null 2>&1 \
  && ! command -v nerdctl >/dev/null 2>&1; then
  warn "no container runtime found. niro needs Docker, Podman, or nerdctl to run pentests."
  printf "    Docker:  %s\n" "$(url_link https://docker.com)"
  printf "    Podman:  %s\n" "$(url_link https://podman.io)"
fi
