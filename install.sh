#!/bin/sh
set -eu

REPO="skillsynchq/skl-releases"
BINARY="skl"
# Legacy install-dir override honored so existing docs/scripts keep working.
INSTALL_DIR="${SKL_INSTALL_DIR:-${REPLAY_INSTALL_DIR:-$HOME/.local/bin}}"

main() {
    # An existing replay install counts: this is an upgrade, not a fresh
    # setup, so skip the interactive init at the end.
    if command -v "$BINARY" > /dev/null 2>&1 || command -v replay > /dev/null 2>&1; then
        already_installed=1
    else
        already_installed=0
    fi

    os="$(uname -s)"
    arch="$(uname -m)"

    case "$os" in
        Linux)  target_os="unknown-linux-musl" ;;
        Darwin) target_os="apple-darwin" ;;
        *)      err "Unsupported OS: $os" ;;
    esac

    case "$arch" in
        x86_64|amd64)  target_arch="x86_64" ;;
        aarch64|arm64) target_arch="aarch64" ;;
        *)             err "Unsupported architecture: $arch" ;;
    esac

    target="${target_arch}-${target_os}"

    if [ -n "${VERSION:-}" ]; then
        tag="v$VERSION"
    else
        tag="$(get_latest_tag)"
    fi

    version="${tag#v}"

    tmpdir="$(mktemp -d)"
    trap 'rm -rf "$tmpdir"' EXIT

    # Releases up to v0.16.x shipped replay-cli-v* archives containing a
    # `replay` binary; v0.17.0+ ship skl-cli-v* containing `skl`. Try the
    # new name first and fall back, so pinned old versions (and the window
    # before the first skl release) still install.
    archive_dir="skl-cli-v${version}-${target}"
    archive="${archive_dir}.tar.gz"
    if ! fetch "https://github.com/${REPO}/releases/download/${tag}/${archive}" "$tmpdir/$archive" 2>/dev/null; then
        BINARY="replay"
        archive_dir="replay-cli-v${version}-${target}"
        archive="${archive_dir}.tar.gz"
        fetch "https://github.com/${REPO}/releases/download/${tag}/${archive}" "$tmpdir/$archive" \
            || err "Could not download ${tag} for ${target}"
    fi

    echo "Installing ${BINARY} (${tag}) for ${target}"
    echo "Script source: https://github.com/${REPO}/blob/main/install.sh"
    echo ""

    tar xzf "$tmpdir/$archive" -C "$tmpdir"

    mkdir -p "$INSTALL_DIR"
    mv "$tmpdir/${archive_dir}/${BINARY}" "$INSTALL_DIR/${BINARY}"
    chmod +x "$INSTALL_DIR/${BINARY}"

    echo "Installed ${BINARY} to ${INSTALL_DIR}/${BINARY}"

    # The CLI used to be called replay. Point the old name at skl so
    # muscle memory and existing scripts keep working.
    if [ "$BINARY" = "skl" ] && [ -e "$INSTALL_DIR/replay" ] && [ ! -L "$INSTALL_DIR/replay" ]; then
        ln -sf "$INSTALL_DIR/skl" "$INSTALL_DIR/replay"
        echo "Replaced the old replay binary with a symlink to skl"
    fi

    if ! echo "$PATH" | tr ':' '\n' | grep -qx "$INSTALL_DIR"; then
        echo ""
        echo "Add ${INSTALL_DIR} to your PATH:"
        echo "  export PATH=\"${INSTALL_DIR}:\$PATH\""
    fi

    if [ "$already_installed" -eq 0 ]; then
        echo ""
        echo "Running '${BINARY} init'..."
        "${INSTALL_DIR}/${BINARY}" init
    fi
}

fetch() {
    if command -v curl > /dev/null 2>&1; then
        curl -sSfL "$1" -o "$2"
    elif command -v wget > /dev/null 2>&1; then
        wget -q "$1" -O "$2"
    else
        err "Neither curl nor wget found. Install one and try again."
    fi
}

get_latest_tag() {
    if command -v curl > /dev/null 2>&1; then
        curl -sSf "https://api.github.com/repos/${REPO}/releases/latest" \
            | grep '"tag_name"' | head -1 | sed 's/.*: "\(.*\)".*/\1/'
    elif command -v wget > /dev/null 2>&1; then
        wget -qO- "https://api.github.com/repos/${REPO}/releases/latest" \
            | grep '"tag_name"' | head -1 | sed 's/.*: "\(.*\)".*/\1/'
    else
        err "Neither curl nor wget found."
    fi
}

err() {
    echo "Error: $1" >&2
    exit 1
}

main
