#!/usr/bin/env bash
#
# install-local.sh — Build OpenDeck from this checkout and install it.
#
# Unlike install.sh (which downloads the latest release), this script always
# installs the binaries produced by the local working tree, making it suitable
# for development and testing local changes.
#
# Usage:
#   ./scripts/install-local.sh [--server-only | --android]
#   INSTALL_DIR=/usr/local/bin ./scripts/install-local.sh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INSTALL_DIR="${INSTALL_DIR:-$HOME/.local/bin}"

MODE="all"
case "${1:-}" in
    --server-only) MODE="server" ;;
    --android)     MODE="android" ;;
    "" ) ;;
    *) echo "usage: $0 [--server-only | --android]" >&2; exit 2 ;;
esac

want_server() { [ "$MODE" = "all" ] || [ "$MODE" = "server" ]; }
want_android() { [ "$MODE" = "all" ] || [ "$MODE" = "android" ]; }

# ---------- server ----------
install_server() {
    if ! command -v cargo >/dev/null 2>&1; then
        echo "error: cargo not found; install the Rust toolchain from https://rustup.rs" >&2
        exit 1
    fi

    echo "Building open-deck-server (release)..."
    cargo build --release --manifest-path "$REPO_ROOT/server/Cargo.toml"

    local bin="$REPO_ROOT/server/target/release/open-deck-server"
    if [[ ! -x "$bin" ]]; then
        echo "error: build finished but $bin is missing" >&2
        exit 1
    fi

    mkdir -p "$INSTALL_DIR"
    if [ -w "$INSTALL_DIR" ]; then
        install -m 0755 "$bin" "$INSTALL_DIR/open-deck-server"
    elif command -v sudo >/dev/null 2>&1; then
        sudo install -m 0755 "$bin" "$INSTALL_DIR/open-deck-server"
    else
        echo "error: $INSTALL_DIR is not writable; set INSTALL_DIR to a writable directory" >&2
        exit 1
    fi
    echo "open-deck-server installed to $INSTALL_DIR/open-deck-server"

    case ":$PATH:" in
        *":$INSTALL_DIR:"*) ;;
        *) echo "note: $INSTALL_DIR is not on your PATH — add: export PATH=\"$INSTALL_DIR:\$PATH\"" ;;
    esac
}

# ---------- android ----------
install_android() {
    local gradlew="$REPO_ROOT/mobile/android/gradlew"
    if [[ ! -x "$gradlew" ]]; then
        echo "error: $gradlew not found or not executable" >&2
        exit 1
    fi
    if ! command -v java >/dev/null 2>&1; then
        echo "error: java not found; install JDK 17+" >&2
        exit 1
    fi

    echo "Building OpenDeck Android APK (debug)..."
    (cd "$REPO_ROOT/mobile/android" && ./gradlew assembleDebug)

    local apk="$REPO_ROOT/mobile/android/app/build/outputs/apk/debug/app-debug.apk"
    if [[ ! -f "$apk" ]]; then
        echo "error: build finished but $apk is missing" >&2
        exit 1
    fi

    local dest="$HOME/Downloads/mobile-android-open-deck.apk"
    mkdir -p "$HOME/Downloads"
    cp "$apk" "$dest"
    echo "APK copied to ${dest}"
    echo "Sideload it onto your phone (adb install ${dest}, or copy + tap to install)."
}

rc=0
want_server  && install_server  || true
want_android && install_android || true
exit $rc
