#!/bin/sh
# Adaline CLI installer for macOS and Linux.
#
#   curl -fsSL https://raw.githubusercontent.com/adaline/cli/main/install.sh | sh
#
# Downloads a standalone `adaline` binary (no Node.js required) from GitHub
# Releases, verifies its checksum, and installs it to ~/.local/bin.
#
# Environment overrides:
#   ADALINE_VERSION       version/tag to install (default: latest)
#   ADALINE_INSTALL_DIR   install directory     (default: $XDG_BIN_HOME or ~/.local/bin)
#   ADALINE_REPO          owner/repo to download from (default: adaline/cli)
#
# POSIX sh on purpose — runs under dash/ash/busybox, not just bash.
set -eu

# --- configuration ----------------------------------------------------------
REPO="${ADALINE_REPO:-adaline/cli}"
BIN_NAME="adaline"
ALIAS_NAME="adx"
# XDG_BIN_HOME is the modern spec location; ~/.local/bin is the de-facto default
# and is already on PATH in most distros' default shell profiles.
INSTALL_DIR="${ADALINE_INSTALL_DIR:-${XDG_BIN_HOME:-$HOME/.local/bin}}"

# --- pretty output (only colorize a real terminal) --------------------------
if [ -t 2 ]; then
  bold="$(printf '\033[1m')"; dim="$(printf '\033[2m')"; red="$(printf '\033[31m')"
  green="$(printf '\033[32m')"; yellow="$(printf '\033[33m')"; reset="$(printf '\033[0m')"
else
  bold=''; dim=''; red=''; green=''; yellow=''; reset=''
fi
info() { printf '%s\n' "$*" >&2; }
warn() { printf '%s%s%s\n' "$yellow" "$*" "$reset" >&2; }
err()  { printf '%serror:%s %s\n' "$red" "$reset" "$*" >&2; exit 1; }

# --- prerequisites -----------------------------------------------------------
# Prefer curl, fall back to wget — at least one ships on virtually every box.
# DL      → fetch small files (SHA256SUMS) to stdout, always silent.
# DL_OUT  → download the binary to a file; show a progress bar on a real
#           terminal so the ~25 MB transfer isn't a silent multi-second pause,
#           but stay quiet when piped/non-interactive (CI logs, `| sh`).
if command -v curl >/dev/null 2>&1; then
  DL='curl -fsSL'
  if [ -t 2 ]; then DL_OUT='curl -fL --progress-bar -o'; else DL_OUT='curl -fsSL -o'; fi
elif command -v wget >/dev/null 2>&1; then
  DL='wget -qO-'
  # --show-progress needs a non-busybox wget; fall back to fully quiet otherwise.
  if [ -t 2 ] && wget --help 2>&1 | grep -q -- '--show-progress'; then
    DL_OUT='wget -q --show-progress -O'
  else
    DL_OUT='wget -qO'
  fi
else
  err "need curl or wget installed to download the CLI"
fi

# --- detect platform ---------------------------------------------------------
os="$(uname -s)"
arch="$(uname -m)"
case "$os" in
  Darwin) os="darwin" ;;
  Linux)  os="linux" ;;
  *) err "unsupported OS '$os' — see https://github.com/$REPO/releases for available binaries" ;;
esac
case "$arch" in
  x86_64 | amd64) arch="x64" ;;
  arm64 | aarch64) arch="arm64" ;;
  *) err "unsupported architecture '$arch' — see https://github.com/$REPO/releases for available binaries" ;;
esac
asset="${BIN_NAME}-${os}-${arch}"
# We publish gzipped binaries (the embedded Bun runtime is huge but compresses
# well); download the .gz and inflate it locally.
dl_asset="${asset}.gz"

# --- resolve the download URLs ----------------------------------------------
if [ "${ADALINE_VERSION:-latest}" = "latest" ]; then
  base="https://github.com/$REPO/releases/latest/download"
  label="latest"
else
  # Accept both "1.2.3" and "cli-v1.2.3"; releases are tagged "cli-v<version>".
  tag="$ADALINE_VERSION"
  case "$tag" in cli-v*) : ;; v*) tag="cli-${tag}" ;; *) tag="cli-v${tag}" ;; esac
  base="https://github.com/$REPO/releases/download/$tag"
  label="$tag"
fi
# Optional override of the download base — used for local testing against a
# directory of pre-downloaded assets, e.g. ADALINE_DOWNLOAD_BASE="file:///tmp/x".
# Unset in normal use, so end users always hit the public GitHub release URLs.
if [ -n "${ADALINE_DOWNLOAD_BASE:-}" ]; then
  base="$ADALINE_DOWNLOAD_BASE"
fi
asset_url="$base/$dl_asset"
sums_url="$base/SHA256SUMS"

info "${bold}Installing $BIN_NAME${reset} ${dim}($os/$arch, $label)${reset}"

# --- download into a temp dir we always clean up -----------------------------
tmp="$(mktemp -d 2>/dev/null || mktemp -d -t adaline)"
trap 'rm -rf "$tmp"' EXIT INT TERM
tmp_dl="$tmp/$dl_asset"
tmp_bin="$tmp/$asset"

info "${dim}Downloading $asset_url${reset}"
# shellcheck disable=SC2086
$DL_OUT "$tmp_dl" "$asset_url" || err "download failed — is '$label' a published release for $os/$arch?"

# --- verify checksum (best-effort: skip if SHA256SUMS is absent) -------------
# We hash the downloaded .gz (what we fetched), matching the SHA256SUMS entry.
if sha_cmd="$(command -v sha256sum || command -v shasum || true)" && [ -n "$sha_cmd" ]; then
  # shellcheck disable=SC2086
  if expected="$($DL "$sums_url" 2>/dev/null | awk -v a="$dl_asset" '$2==a {print $1}')" && [ -n "$expected" ]; then
    case "$sha_cmd" in
      *shasum) actual="$(shasum -a 256 "$tmp_dl" | awk '{print $1}')" ;;
      *) actual="$(sha256sum "$tmp_dl" | awk '{print $1}')" ;;
    esac
    [ "$actual" = "$expected" ] || err "checksum mismatch for $dl_asset (expected $expected, got $actual)"
    info "${green}✓${reset} checksum verified"
  else
    warn "could not fetch checksum for $dl_asset — skipping verification"
  fi
else
  warn "no sha256 tool found — skipping checksum verification"
fi

# --- decompress --------------------------------------------------------------
if ! command -v gunzip >/dev/null 2>&1 && ! command -v gzip >/dev/null 2>&1; then
  err "failed to decompress $dl_asset — need gunzip or gzip installed"
fi
gunzip -c "$tmp_dl" > "$tmp_bin" \
  || gzip -dc "$tmp_dl" > "$tmp_bin" \
  || err "failed to decompress $dl_asset — the downloaded file may be corrupt"

# --- install -----------------------------------------------------------------
mkdir -p "$INSTALL_DIR" || err "cannot create install dir $INSTALL_DIR"
dest="$INSTALL_DIR/$BIN_NAME"
chmod +x "$tmp_bin"
# mv first (atomic on same fs); fall back to cp for cross-device temp dirs.
mv -f "$tmp_bin" "$dest" 2>/dev/null || { cp -f "$tmp_bin" "$dest" && chmod +x "$dest"; }

# macOS Gatekeeper quarantines downloaded files; strip it so the binary runs
# without a security prompt. Ignore failures (attr may be absent / not needed).
if [ "$os" = "darwin" ] && command -v xattr >/dev/null 2>&1; then
  xattr -d com.apple.quarantine "$dest" >/dev/null 2>&1 || true
fi

# Install the short `adx` alias alongside `adaline`. A relative symlink keeps the
# two in sync; fall back to a plain copy on filesystems without symlink support.
ln -sf "$BIN_NAME" "$INSTALL_DIR/$ALIAS_NAME" 2>/dev/null \
  || { cp -f "$dest" "$INSTALL_DIR/$ALIAS_NAME" && chmod +x "$INSTALL_DIR/$ALIAS_NAME"; }

installed_version="$("$dest" --version 2>/dev/null || true)"
info "${green}✓ installed $BIN_NAME ${installed_version}${reset} ${dim}-> $dest${reset}"
info "${dim}  also available as ${ALIAS_NAME}${reset}"

# --- PATH guidance -----------------------------------------------------------
case ":$PATH:" in
  *":$INSTALL_DIR:"*)
    info ""
    info "Run ${bold}$BIN_NAME --help${reset} to get started."
    ;;
  *)
    info ""
    warn "$INSTALL_DIR is not on your PATH."
    info "Add it by appending this line to your shell profile (~/.bashrc, ~/.zshrc, …):"
    info "    ${bold}export PATH=\"$INSTALL_DIR:\$PATH\"${reset}"
    info "Then restart your shell and run ${bold}$BIN_NAME --help${reset}."
    ;;
esac
