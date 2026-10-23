#!/bin/sh
# Refresh the vendored Linux Pi distribution, ripgrep and fd (find alternative) for both architectures.
set -eu
cd "$(dirname "$0")"

# Reuse one temporary archive and remove it on exit, including after errors.
archive=$(mktemp)
trap 'rm -f "$archive"' EXIT
# Exit on Ctrl-C or termination so the EXIT trap cleans up (128 + signal number).
trap 'exit 130' INT
trap 'exit 143' TERM

latest_tag() {
    url=$(curl -fsSL --retry 3 -o /dev/null -w '%{url_effective}' "https://github.com/$1/releases/latest")
    echo "${url##*/}"
}

echo "Resolving latest releases..."
pi_tag=$(latest_tag earendil-works/pi)
rg_tag=$(latest_tag BurntSushi/ripgrep)
fd_tag=$(latest_tag sharkdp/fd)

rm -rf amd64 arm64 pi
for arch in amd64 arm64; do
    case "$arch" in
        amd64)
            pi_arch=x64
            rg_target=x86_64-unknown-linux-musl
            fd_target=x86_64-unknown-linux-musl
            ;;
        arm64)
            pi_arch=arm64
            rg_target=aarch64-unknown-linux-gnu
            fd_target=aarch64-unknown-linux-musl
            ;;
    esac
    mkdir -p "$arch"

    echo "Downloading Pi $pi_tag for linux/$arch..."
    curl -fL --progress-bar --retry 3 -o "$archive" "https://github.com/earendil-works/pi/releases/download/$pi_tag/pi-linux-$pi_arch.tar.gz"
    tar -xzf "$archive" -C "$arch" --strip-components=1 pi/pi
    # Runtime resources are shared; omit desktop clipboard helpers and documentation.
    if [ "$arch" = amd64 ]; then
        tar -xzf "$archive" pi/package.json pi/theme pi/assets pi/export-html pi/photon_rs_bg.wasm
    fi

    echo "Downloading ripgrep $rg_tag for linux/$arch..."
    curl -fL --progress-bar --retry 3 -o "$archive" "https://github.com/BurntSushi/ripgrep/releases/download/$rg_tag/ripgrep-$rg_tag-$rg_target.tar.gz"
    tar -xzf "$archive" -C "$arch" --strip-components=1 "ripgrep-$rg_tag-$rg_target/rg"

    echo "Downloading fd $fd_tag for linux/$arch..."
    curl -fL --progress-bar --retry 3 -o "$archive" "https://github.com/sharkdp/fd/releases/download/$fd_tag/fd-$fd_tag-$fd_target.tar.gz"
    tar -xzf "$archive" -C "$arch" --strip-components=1 "fd-$fd_tag-$fd_target/fd"
done
echo "Done: Pi, ripgrep and fd updated for linux/amd64 and linux/arm64."
