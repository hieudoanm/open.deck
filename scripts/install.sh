#!/usr/bin/env bash
#
# install.sh — Install OpenDeck from the latest GitHub release.
#
# Installs, by default:
#   1. the `open-deck-server` binary into ~/.local/bin
#
# With --android, also downloads the debug APK for sideloading.
#
# Usage:
#   ./scripts/install.sh [--server-only | --android]
set -euo pipefail

REPO="hieudoanm/open.deck"
BASE_URL="https://github.com/${REPO}/releases/latest/download"

MODE="all"
case "${1:-}" in
    --server-only) MODE="server" ;;
    --android)     MODE="android" ;;
    "" ) ;;
    *) echo "usage: $0 [--server-only | --android]" >&2; exit 2 ;;
esac

want_server() { [ "$MODE" = "all" ] || [ "$MODE" = "server" ]; }
want_android() { [ "$MODE" = "all" ] || [ "$MODE" = "android" ]; }

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

# ---------- server ----------
install_server() {
    local os arch asset
    os="$(uname -s | tr '[:upper:]' '[:lower:]')"
    arch="$(uname -m)"
    case "$arch" in
        arm64|aarch64) arch="aarch64" ;;
        x86_64|amd64)  arch="x86_64" ;;
    esac
    case "$os/$arch" in
        darwin/aarch64) asset="open-deck-server-aarch64-apple-darwin" ;;
        darwin/x86_64)  asset="open-deck-server-x86_64-apple-darwin" ;;
        linux/x86_64)   asset="open-deck-server-x86_64-unknown-linux-gnu" ;;
        linux/aarch64)  asset="open-deck-server-aarch64-unknown-linux-gnu" ;;
        mingw*|msys*|cygwin*|windows*)
            echo "Windows: download open-deck-server-x86_64-pc-windows-msvc.exe manually" >&2
            echo "  ${BASE_URL}/open-deck-server-x86_64-pc-windows-msvc.exe" >&2
            return 1 ;;
        *)
            echo "unsupported platform: $os/$arch" >&2
            return 1 ;;
    esac

    echo "Downloading ${asset}..."
    if ! curl -fsSL "${BASE_URL}/${asset}" -o "$TMP_DIR/open-deck-server"; then
        echo "error: could not download ${BASE_URL}/${asset}" >&2
        echo "hint: no prebuilt release yet — build locally: cd server && cargo build --release" >&2
        return 1
    fi

    local bin_dir="$HOME/.local/bin"
    mkdir -p "$bin_dir"
    install -m 0755 "$TMP_DIR/open-deck-server" "$bin_dir/open-deck-server"
    echo "open-deck-server installed to ${bin_dir}/open-deck-server"

    case ":$PATH:" in
        *":$bin_dir:"*) ;;
        *) echo "note: ${bin_dir} is not on your PATH — add: export PATH=\"${bin_dir}:\$PATH\"" ;;
    esac
}

# ---------- android ----------
install_android() {
    echo "Downloading mobile-android-open-deck.apk..."
    local dest="$HOME/Downloads/mobile-android-open-deck.apk"
    mkdir -p "$HOME/Downloads"
    if ! curl -fsSL "${BASE_URL}/mobile-android-open-deck.apk" -o "$dest"; then
        echo "error: could not download ${BASE_URL}/mobile-android-open-deck.apk" >&2
        echo "hint: build locally: cd mobile/android && ./gradlew assembleDebug" >&2
        return 1
    fi
    echo "APK saved to ${dest}"
    echo "Sideload it onto your phone (adb install ${dest}, or copy + tap to install)."
}

rc=0
want_server  && install_server  || true
want_android && install_android || true
exit $rc
