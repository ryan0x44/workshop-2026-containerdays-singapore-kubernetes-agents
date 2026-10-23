# Prework: Before You Start

There are two ways to do the prework:

1. [__Online Installation__](#1-online-installation): Download 2GiB+
2. (Coming soon) [__Sneakernet Installation__](#2-sneakernet-installation): If in-person with a thumbdrive

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

### a.) Copy all files for your architecture

The thumbdrive should have a set of directories such as:

```
macos-arm64/
macos-amd64/
linux-arm64/
linux-amd64/
windows-arm64/
windows-amd64/
workshop/
```

Please copy the appropriate macos/linux/windows directory for your architecture.

Each of the macos/linux/windows directories should contain a set of binaries:

```
qemu-img
qemu-system-aarch64 | qemu-system-x86_64
podplane
kubectl
helm
mkcert
```

Below we will assume you copied files into `~/workshop/linux-arm64`.

### b.) Export workshop binaries on your terminal PATH

Doing this will put these binaries first.

If you do not want a particular binary, simply move or delete the binary file.

```sh
export PATH="$HOME/workshop/linux-arm64:$PATH"
```

To test this worked, run:

```sh
podplane --version
```

### c.) Download Podplane dependencies

This will download ~2GiB of dependencies:

```sh
podplane deps download
```

Once this is complete, you will be able to start local clusters fully offline.

---

← [Workshop Home](../README.md) &emsp; | &emsp; [Part 1 - Cluster Setup](../01-cluster-setup/) →
