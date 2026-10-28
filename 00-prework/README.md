# Prework: Before You Start

There are two ways to do the prework:

1. [__Online Installation__](#1-online-installation): Download 2GiB+
2. [__Sneakernet Installation__](#2-sneakernet-installation): Copy a prepared Podplane bundle from a thumbdrive, then work offline

## 1. Online Installation

### a.) Install runtime dependencies

Mac/Linux:

- Homebrew __OR__ Go

Windows:

- Go

All:

- Qemu
- mkcert (optional)
- kubectl
- helm

### b.) Install Podplane CLI

Choose one:

```sh
# with Homebrew installed:
brew install kubectl helm qemu mkcert git-lfs
brew install podplane/tap/podplane
# or with Go installed:
# install kubectl/helm/qemu
go install github.com/podplane/podplane@latest
```

### c.) Download Podplane dependencies

This will download ~2GiB of dependencies:

```sh
podplane deps download
```

Once this is complete, you will be able to start local clusters fully offline.

## 2. Sneakernet Installation

### a.) Copy one directory, then pass on the drive

Copy the **entire directory** matching your laptop from the thumbdrive into your home directory:

| Laptop | Directory |
| --- | --- |
| Apple Silicon Mac | `podplane-macos-arm64` |
| Intel Mac (preinstall QEMU) | `podplane-macos-amd64` |
| ARM64 Linux | `podplane-linux-arm64` |
| x86-64 Linux | `podplane-linux-amd64` |

**Eject the thumbdrive and pass it to the next person now.** Everything below uses your local copy; do not wait for import or cluster startup commands before handing over the drive.

Keep the directory intact. It includes `bin/` (Podplane, kubectl, Helm and mkcert, plus QEMU except on Intel Macs), bundled runtime libraries and firmware, dependency caches and their existing manifests, and a checksummed `podplane-bundle.json`. Copying only `bin/` will not work. Windows bundles are not currently supported. Your OS must provide `ssh`; Linux also requires (for QEMU) usable KVM and permission to access `/dev/kvm`.

**Intel Macs require QEMU installed before going offline**, for example with `brew install qemu`. The Intel Mac bundle does not include QEMU; ensure `qemu-img` and `qemu-system-x86_64` are on `PATH` before the workshop.

### b.) Use the copied tools

For an Apple Silicon Mac (change the directory name for your laptop):

```sh
export PODPLANE_BUNDLE="$HOME/podplane-macos-arm64"
export PATH="$PODPLANE_BUNDLE/bin:$PATH"
podplane --version
```

Repeat those exports in each new terminal. Keep the bundle in place while using Podplane; QEMU needs its sibling libraries and firmware.

### c.) Import dependencies and start offline

Import verifies checksums and copies dependencies into Podplane's local cache, without downloading anything:

```sh
podplane deps import "$PODPLANE_BUNDLE"
```

**On macOS**, set a keyring password before starting to work around a macOS Keychain bug. Replace the placeholder with your own secret and reuse the same value in each new terminal:

```sh
export PODPLANE_KEYRING_PASS='replace-with-your-own-secret'
```

Start the cluster:

```sh
podplane local start --offline --memory 5G
```

Allow disk space for the bundle, a temporary import copy, and the installed cache, plus the VM. If import reports missing or corrupt files, copy the complete bundle again. `--offline` stops startup rather than attempting to download missing dependencies.

This prepares the local platform, not every workshop exercise: workshop source files, the workshop-specific container image, model downloads and hosted AI APIs have separate requirements. Follow the [workshop image prework](../README.md#before-the-workshop) too.

### Preparing the thumbdrive (facilitators)

On an internet-connected machine with a Podplane release that supports bundles:

```sh
podplane deps bundle /path/to/thumbdrive
```

This creates the four `podplane-<platform>` directories above. To prepare fewer platforms, use `--platforms macos-arm64,linux-amd64`. Each directory is independent. Podplane reuses verified cached dependencies, downloads missing files and upstream host tools, and assembles the bundles in its local XDG-aware cache directory before copying anything to the drive.

Staging is retained for retries and additional drives. Rerun the command with another destination to copy the same prepared bundles without downloading again. Interrupted copies resume, skipping matching files and repairing incomplete ones. Add `--cleanup` on the last successful copy to remove staging while keeping downloaded artifacts cached. Use `--refresh` and a fresh destination when you want to prepare newer versions.

The creator needs internet access; attendees do not need Go. Apple Silicon and Linux attendees do not need Homebrew or a preinstalled QEMU; Intel Mac attendees must preinstall QEMU. Use exFAT or another filesystem that supports files larger than 4 GiB. Test a copied bundle on a clean laptop before the workshop.

---

← [Workshop Home](../README.md) &emsp; | &emsp; [Part 1 - Cluster Setup](../01-cluster-setup/) →
