# Part 2: Agent Sandbox

**Goal:** schedule Pi and its tools inside an isolated workspace.

## 1. Build An Agent Harness Image

Podplane makes it easy to build your own container images, and (via [ocimage](https://github.com/podplane/ocimage)) can build some images directly without a docker daemon.

This workshop directory tree includes the necessary files to build a [Pi](https://pi.dev) agent harness image

The image contains Pi, Go, Git, curl, ripgrep (`rg`), fd, and nono 0.80.0. nono is preinstalled for Part 5; it does not wrap Pi in this part. To build it, run:

```sh
podplane build --docker=false -t workshop-pi:v1 ./image
```

When you use the `podplane build` command, it builds and stores images in its local cache, which is automatically accessible in local clusters.

In this example, the `workshop-pi:v1` tag is available as `default-registry.local/apps/workshop-pi:v1`.

> Homework: ocimage can build any image using the Docker daemon, but if a subset of Dockerfile/Containerfile syntax is used, it can build images without the Docker daemon. For example, `RUN` requires a Docker daemon, but the image we build above does not require a Docker daemon.

## 2. Deploy An Agent Sandbox

First, restrict sandbox ingress and egress:

```sh
kubectl apply -f network-policy.yaml
```

Now deploy the Agent Sandbox:

```sh
kubectl apply -f sandbox.yaml
kubectl -n workshop wait --for=condition=Ready sandbox/pi --timeout=180s
kubectl -n workshop get pods,pvc
```

This schedules a Pod:
- running on `gvisor`
- with UID 1000
- image filesystem is read-only
- 2 GiB PVC holds `/workspace`
- temporary files and Pi settings use separate writable volumes
- dedicated projected token is for Source Gateway in Part 4, not the Kubernetes API.
- no provider key is mounted.
- workload `TrustBundle` lets Git verify the gateway's certificate.
- workload certificate and private key are mounted for Part 5; ordinary Pi can read them but does not use them for inference yet.
- with Pi's `models.json` supplied via `pi-models` ConfigMap in `sandbox.yaml`

## 3. Access Pi CLI

Podplane has a helper `shell` command to easily `kubectl exec` into a Pod:

```sh
podplane shell -n workshop pi
```

Inside the Pod:

```sh
id # expect: uid=1000(agent) gid=1000(agent) groups=1000(agent)
pwd # expect: /workspace
# check Pi and it's rg/fd dependencies are installed:
pi --version
rg --version
fd --version
nono --version # installed now; enabled in Part 5
# prove no service account token exists:
test ! -e /var/run/secrets/kubernetes.io/serviceaccount/token && echo 'No default API token'
# prove egress is restricted:
curl --connect-timeout 1 --max-time 1 -I https://example.com
```

Once you've finished exploring the Pod, run Pi:

```sh
pi
```

Pi should open, but inference is not configured yet!

__Do not log in or paste a provider key here.__

Exit Pi with Ctrl+C twice, then `exit` the shell.

Part 3 will connect the Agent Router to your inference provider. Pi is already wired-up to the Agent Router instance built into the cluster, so once it is configured with an inference provider, Pi should be ready to go!

**Checkpoint:** Pi and its tool execution are running inside a gvisor-based Agent Sandbox Pod. You can shell into the Pod, and closing this shell does not delete the Pod or any files in its PVC. A replaced Pod retains the `/workspace` PVC; the home directory and Pi settings are ephemeral.

If the Pod is pending, use `kubectl -n workshop describe pod "$POD"` and inspect the PVC. If you need help or have questions, please ask the facilitator!

---

[← Previous: Cluster Setup](../01-cluster-setup/) &emsp; | &emsp; [Next: Agent Router →](../03-agent-router/)
