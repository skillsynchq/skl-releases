#!/bin/sh
set -eu

REPO="skillsynchq/replay-releases"
BINARY="replay"
INSTALL_DIR="${REPLAY_INSTALL_DIR:-$HOME/.local/bin}"

main() {
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
    archive="replay-cli-v${version}-${target}.tar.gz"
    url="https://github.com/${REPO}/releases/download/${tag}/${archive}"

    tmpdir="$(mktemp -d)"
    trap 'rm -rf "$tmpdir"' EXIT

    echo "Installing Replay CLI (${tag}) for ${target}"
    echo "Script source: https://github.com/${REPO}/blob/main/install.sh"
    echo ""
    echo "Downloading..."
    if command -v curl > /dev/null 2>&1; then
        curl -sSfL "$url" -o "$tmpdir/$archive"
    elif command -v wget > /dev/null 2>&1; then
        wget -q "$url" -O "$tmpdir/$archive"
    else
        err "Neither curl nor wget found. Install one and try again."
    fi

    tar xzf "$tmpdir/$archive" -C "$tmpdir"

    mkdir -p "$INSTALL_DIR"
    mv "$tmpdir/replay-cli-v${version}-${target}/${BINARY}" "$INSTALL_DIR/${BINARY}"
    chmod +x "$INSTALL_DIR/${BINARY}"

    echo "Installed ${BINARY} to ${INSTALL_DIR}/${BINARY}"

    if ! echo "$PATH" | tr ':' '\n' | grep -qx "$INSTALL_DIR"; then
        echo ""
        echo "Add ${INSTALL_DIR} to your PATH:"
        echo "  export PATH=\"${INSTALL_DIR}:\$PATH\""
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
