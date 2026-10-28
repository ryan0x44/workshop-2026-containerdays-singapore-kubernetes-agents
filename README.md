# Agents on Kubernetes

Build a local agentic PaaS with Podplane, run [Pi](https://github.com/earendil-works/pi) in a sandbox, and give it inference and git/source access, securely handling upstream credentials.

## System Requirements

We will be running a local VM with 2 CPUs and 5GiB RAM.

Please ensure you have:

- 6GiB free memory. Ideally 16-32GiB memory machine.
- 64-bit CPU architecture, either ARM or Intel/AMD.
- 20GiB free disk space.
- Preferrably macOS or Linux, Windows *should* work.
- A terminal with Git installed.

## Before The Workshop

It's critical you do the [workshop prework to download required dependencies](./00-prework/README.md).

This will download 2GiB+ of dependencies, and should allow you to start a Podplane cluster while offline.

## Workshop Contents

There are **five** parts to this workshop. Work through them in order; each builds on the previous part. Commands run on your laptop unless labelled **inside the sandbox**.

| Part | You will… |
| --- | --- |
| [1. Cluster Setup](01-cluster-setup/) | Start a local agentic PaaS cluster with Podplane. |
| [2. Agent Sandbox](02-agent-sandbox/) | Schedule an isolated workspace and open Pi coding agent. |
| [3. Agent Router](03-agent-router/) | Connect OpenAI API-compatible inference to Pi via Agent Router. |
| [4. Source Gateway](04-source-gateway/) | Cache a public Git repository and clone it into the sandbox. |
| [5. Wrap Pi with nono](05-nono/) | Restrict Pi's process and authenticate inference with a workload client certificate. |

### Install Podplane and its tools

Install the CLI with either Homebrew:

```sh
brew install podplane/tap/podplane
```

Or [Go](https://go.dev/doc/install) (with its binary directory on your `PATH`):

```sh
go install github.com/podplane/podplane@latest
```

Install the same tools required for a Podplane local cluster:

- **kubectl** — apply Kubernetes manifests and inspect the sandbox.
- **Helm** — install charts, including the inference provider configuration in Part 3.
- **QEMU** — run the local cluster VM; include `qemu-img` and the system binary for your architecture.
- **mkcert** — generate local HTTPS certificates. Optionally run `mkcert -install` to trust them on your laptop.

This workshop also needs **Git LFS** to download the prebuilt Pi, ripgrep, fd and nono binaries stored in this repository. On macOS:

```sh
brew install kubectl helm qemu mkcert git-lfs
git lfs install
```

On Linux, follow [Podplane's installation guide](https://podplane.dev/docs/guides/installation/) and [Git LFS installation instructions](https://git-lfs.com/), then run `git lfs install` before cloning. Make sure QEMU can access KVM. If you already cloned without Git LFS, run `git lfs pull` in the repository to fetch the binaries.

**No Docker, Buildx, npm install or local build toolchain is needed:** Podplane's native ocimage builder packages prebuilt Linux binaries. Only maintainers refreshing those binaries with `image/update.sh` need `curl`, `tar` and `sha256sum` or `shasum`.

Check the tools and download Podplane's dependencies before arriving:

```sh
podplane version
kubectl version --client
helm version --short
qemu-img --version
mkcert -version
git lfs version
podplane deps download
```

### Prepare the workshop image

```sh
git clone https://github.com/ryan0x44/workshop-2026-containerdays-singapore-kubernetes-agents.git
cd workshop-2026-containerdays-singapore-kubernetes-agents
git lfs pull
podplane build --docker=false -t workshop-pi:v1 ./02-agent-sandbox/image
```

Complete this **before** the exercises: the base image is a large download. The build selects the vendored Linux arm64 binaries on Apple silicon or amd64 on x86-64. Pi's runtime resources and nono's workshop profile are included in the image. nono is pinned to `0.80.0`; `image/update.sh` verifies its release archives against pinned SHA256 checksums when maintainers refresh the binaries. Nothing is downloaded at sandbox startup.

The packaging-only Containerfile uses `golang:1.26.2-trixie`. Its Debian/glibc base supplies Go, Bash, Git, curl and CA roots; the image names UID 1000 `agent`. Pi is a standalone binary. No `RUN` steps execute, and the base uses a version tag, not an immutable digest.

The build uses Podplane's local image cache and does not need a running cluster. `podplane deps download` caches platform dependencies, **not this workshop image**. Preparing both avoids large downloads during the exercises. Use a current Podplane release with native `--docker=false` support; a rejected flag means the CLI must be upgraded, not that Docker is required.

For Part 3, bring an **OpenAI or Anthropic API key with API billing enabled**; a consumer chat subscription is not sufficient. Use a workshop-only key with a low spending limit. Do not put keys in these files or commit them to Git. The main path through Part 4 is intended to need no GitHub credential.

## What the boundaries do

Parts 2–4 give the sandbox its own persistent workspace, resource limits, a non-root process and a gVisor runtime. Network policies allow DNS, Agent Router, Source Gateway and the local inference port on the laptop. Provider keys belong to the router; Git access uses a short-lived, repository-scoped workload identity at Source Gateway.

Part 5 switches the sandbox to runc so nono can use Landlock. Pi and its descendants get restricted filesystem access and inference through nono's local proxy. The tenant's inference route requires a verified workload identity from namespace `workshop`; nono presents the certificate while its private key remains outside Pi's filesystem grants. This replaces gVisor rather than layering inside it. The shared listener and other tenants' routes are unchanged.

nono restricts Pi and its child processes. A shell opened with `podplane shell` runs outside nono’s restrictions and can read the workload private key.

Inference uses server-authenticated HTTPS before Part 5 and mTLS afterwards. Permitted inference requests can contain workspace data. The Source Gateway token is readable by ordinary Pi in Part 4, but denied by the Part 5 profile; it is never an upstream GitHub token. nono loads certificates at startup, so sessions must be restarted to pick up rotated credentials.

The local cluster still stops working when your laptop sleeps. Keeping agents independent of your laptop requires remote execution.

## After the workshop

To pause the local VM and keep the workspace:

```sh
podplane local stop
```

Resume with `podplane local start --memory 5G`. Remove the workshop resources while the cluster is running:

```sh
helm uninstall workshop-inference --namespace workshop-inference --ignore-not-found
kubectl delete -f 02-agent-sandbox/network-policy.yaml
kubectl delete namespace workshop workshop-inference
```

**Deleting the workshop namespace deletes its PVC and checkout.** Export any work first. Revoke your workshop API key at the provider. For a completely disposable cluster, `podplane local delete` removes the VM and all of its persistent data; do not use it against a cluster you want to keep.

Start with [Part 1: cluster setup →](01-cluster-setup/).
