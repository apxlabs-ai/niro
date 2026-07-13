#!/usr/bin/env sh
# Niro installer for macOS and Linux — works on laptops and in CI.
#
# Installs the `niro` binary. On GitHub Actions it also adds the install
# directory to $GITHUB_PATH so later steps can call `niro`; off CI it
# prints shell-rc guidance when the install dir isn't already on PATH.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/apxlabs-ai/niro/main/install.sh | sh
#
# Environment variables:
#   NIRO_VERSION       Pin an exact stable, dev, or RC tag (e.g. v0.1.0).
#   NIRO_CHANNEL       Select stable, dev, or rc. Defaults to stable.
#   NIRO_INSTALL_DIR   Override install directory. Defaults to the first
#                      writable PATH-resident directory found among:
#                      /opt/homebrew/bin (Apple Silicon Homebrew),
#                      /usr/local/bin (Intel Homebrew / common system bin).
#                      Falls back to ~/.local/bin if none qualify.

set -eu

REPO="apxlabs-ai/niro"
BIN_NAME="niro"

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

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# Parse top-level release objects without requiring jq or Python. The parser
# tracks JSON strings and object depth, so braces in authored release notes do
# not split an object. It prints the object count followed by the first usable
# prerelease tag for the requested channel; GitHub orders the releases API
# newest first.
parse_release_page() {
  awk -v channel="$1" '
    function finish_object( token, tag, published) {
      count++
      if (!match(object, /"tag_name"[[:space:]]*:[[:space:]]*"[^"]*"/)) return
      token = substr(object, RSTART, RLENGTH)
      sub(/^"tag_name"[[:space:]]*:[[:space:]]*"/, "", token)
      sub(/"$/, "", token)
      tag = token
      if (tag !~ pattern) return
      if (object !~ /"draft"[[:space:]]*:[[:space:]]*false/) return
      if (object !~ /"prerelease"[[:space:]]*:[[:space:]]*true/) return
      if (!match(object, /"published_at"[[:space:]]*:[[:space:]]*"[^"]*"/)) return
      token = substr(object, RSTART, RLENGTH)
      sub(/^"published_at"[[:space:]]*:[[:space:]]*"/, "", token)
      sub(/"$/, "", token)
      published = token
      print "C " published " " tag
    }
    BEGIN {
      number = "(0|[1-9][0-9]*)"
      pattern = "^v" number "\\." number "\\." number "-" channel "\\." number "$"
    }
    {
      line = $0 "\n"
      for (i = 1; i <= length(line); i++) {
        c = substr(line, i, 1)
        if (in_string) {
          if (depth > 0) object = object c
          if (escaped) escaped = 0
          else if (c == "\\") escaped = 1
          else if (c == "\"") in_string = 0
          continue
        }
        if (c == "\"") {
          in_string = 1
          if (depth > 0) object = object c
          continue
        }
        if (c == "{") {
          depth++
          if (depth == 1) object = "{"
          else object = object c
          continue
        }
        if (c == "}") {
          if (depth > 0) object = object c
          if (depth == 1) finish_object()
          depth--
          continue
        }
        if (depth > 0) object = object c
      }
    }
    END {
      print "N " count + 0
    }
  ' "$2"
}

fetch_release_page() {
  curl -fsSL \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    -o "$2" "$1" \
    || die "could not resolve the ${3} release channel"
}

resolve_channel() {
  CHANNEL="$1"
  PAGE_FILE="${TMP}/releases.json"
  if [ "$CHANNEL" = "stable" ]; then
    RESOLVED=$(curl -fsSLI -o /dev/null -w '%{url_effective}' \
      "https://github.com/${REPO}/releases/latest") \
      || die "could not resolve the stable release channel"
    TAG=${RESOLVED##*/}
    if ! printf '%s\n' "$TAG" \
      | grep -Eq '^v(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$'; then
      die "no published stable release found"
    fi
    printf '%s' "$TAG"
    return
  fi

  PAGE=1
  CANDIDATES="${TMP}/channel-candidates.txt"
  : > "$CANDIDATES"
  while :; do
    fetch_release_page \
      "https://api.github.com/repos/${REPO}/releases?per_page=100&page=${PAGE}" \
      "$PAGE_FILE" "$CHANNEL"
    PARSED_FILE="${TMP}/parsed-releases.txt"
    parse_release_page "$CHANNEL" "$PAGE_FILE" > "$PARSED_FILE"
    COUNT=$(awk '$1 == "N" {print $2}' "$PARSED_FILE")
    awk '$1 == "C" {print $2 " " $3}' "$PARSED_FILE" >> "$CANDIDATES"
    [ "$COUNT" -eq 100 ] || break
    PAGE=$((PAGE + 1))
  done
  TAG=$(LC_ALL=C sort -r "$CANDIDATES" | awk 'NR == 1 {print $2}')
  [ -z "$TAG" ] || { printf '%s' "$TAG"; return; }
  die "no published ${CHANNEL} prerelease found"
}

VERSION_SELECTOR="${NIRO_VERSION:-}"
CHANNEL_SELECTOR="${NIRO_CHANNEL:-}"
if [ -n "$VERSION_SELECTOR" ] && [ -n "$CHANNEL_SELECTOR" ]; then
  die "NIRO_VERSION and NIRO_CHANNEL cannot both be set"
fi

if [ -n "$VERSION_SELECTOR" ]; then
  if ! printf '%s\n' "$VERSION_SELECTOR" \
    | grep -Eq '^v(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(-(dev|rc)\.(0|[1-9][0-9]*))?$'; then
    die "NIRO_VERSION must match vX.Y.Z, vX.Y.Z-dev.N, or vX.Y.Z-rc.N"
  fi
  VERSION="$VERSION_SELECTOR"
else
  CHANNEL_SELECTOR="${CHANNEL_SELECTOR:-stable}"
  case "$CHANNEL_SELECTOR" in
    stable|dev|rc) ;;
    *) die "unknown NIRO_CHANNEL: $CHANNEL_SELECTOR (expected stable, dev, or rc)" ;;
  esac
  VERSION=$(resolve_channel "$CHANNEL_SELECTOR")
fi

printf "Resolved niro release: %s\n" "$VERSION"
ARCHIVE="niro_${OS}_${ARCH}.tar.gz"
BASE_URL="https://github.com/${REPO}/releases/download/${VERSION}"

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

printf "\nniro %s installed. Run \`niro init\` to get started.\n" "$VERSION"

# On GitHub Actions, expose the install dir to later workflow steps so
# `niro find` / `niro collect ...` resolve without a PATH edit. A no-op
# off CI (GITHUB_PATH is unset), where we print shell-rc guidance instead.
if [ -n "${GITHUB_PATH:-}" ]; then
  printf '%s\n' "$INSTALL_DIR" >> "$GITHUB_PATH" \
    || warn "could not add ${INSTALL_DIR} to the GitHub Actions PATH."
else
  case ":${PATH}:" in
    *":${INSTALL_DIR}:"*) ;;
    *)
      warn "${INSTALL_DIR} is not on PATH."
      printf "    Add to your shell rc (~/.zshrc, ~/.bashrc):\n\n"
      printf "        export PATH=\"%s:\$PATH\"\n" "$INSTALL_DIR"
      ;;
  esac
fi

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
