#!/bin/sh
# Refresh Pi, ripgrep, fd and the pinned nono release for both Linux architectures.
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
# Keep the workshop profile and compatibility checks tied to this release.
nono_tag=v0.80.0

rm -rf amd64 arm64 pi
for arch in amd64 arm64; do
    case "$arch" in
        amd64)
            pi_arch=x64
            rg_target=x86_64-unknown-linux-musl
            fd_target=x86_64-unknown-linux-musl
            nono_target=x86_64-unknown-linux-gnu
            nono_sha256=6da665b61999570c10dffc7da78828fe1fb7f3cac53319e505cebecaef17037f
            ;;
        arm64)
            pi_arch=arm64
            rg_target=aarch64-unknown-linux-gnu
            fd_target=aarch64-unknown-linux-musl
            nono_target=aarch64-unknown-linux-gnu
            nono_sha256=d2a24c8c37714f85c829b5586ffd81fc2acf336c95372d881ba62140884f22cb
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

    echo "Downloading nono $nono_tag for linux/$arch..."
    curl -fL --progress-bar --retry 3 -o "$archive" "https://github.com/nolabs-ai/nono/releases/download/$nono_tag/nono-$nono_tag-$nono_target.tar.gz"
    if command -v sha256sum >/dev/null 2>&1; then
        printf '%s  %s\n' "$nono_sha256" "$archive" | sha256sum -c -
    else
        printf '%s  %s\n' "$nono_sha256" "$archive" | shasum -a 256 -c -
    fi
    tar -xzf "$archive" -C "$arch" nono
done
echo "Done: Pi, ripgrep, fd and nono updated for linux/amd64 and linux/arm64."
