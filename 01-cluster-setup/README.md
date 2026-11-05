# Part 1: Cluster Setup

**Goal:** start a local agentic PaaS cluster with Podplane.

## 1. Install the CLI

> If you completed the [pre-work](../README.md#before-the-workshop) already, skip this step.

Choose one:

```sh
brew install podplane/tap/podplane
# Or, with Go installed:
go install github.com/podplane/podplane@latest
```

## 2. Start your cluster

To start a cluster and automatically configure a `local` kubeconfig context:

```sh
podplane local start --memory 5G
```

> The workshop needs 5 GiB of VM memory, more than the 4 GiB default. Pass `--memory 5G` every time you run `podplane local start`, including when resuming.

> If this is the first time running this command, and you didn't already run `podplane deps download` as part of pre-work, it will download ~2GiB of dependencies before starting a local cluster.

Starting a local cluster takes **about 1 minute 30 seconds** on a MacBook Pro M3 Max 2023. Any missing or outdated dependencies are automatically downloaded before the cluster starts, which may take additional time.

Podplane preloads cluster state. The default "seed" is `agentic`, which inlcudes Agent Sandbox, Agent Router, and Source Gateway demonstrated in this workshop.

> Homework for later: You can also use `none` for a bare cluster, the `minimal` seed for only CoreDNS and Cillium, or the `platform` seed and selectively install add-ons using `podplane install` command.

Once the cluster has started and the Podplane CLI has reported it as healthy, you can also run a few checks yourself. First ensure your kube context is correct:

```sh
kubectl config current-context
# expect: local
# fix with: kubectl config use-context local
```

If you do not have `local` available in your kubeconfig, please ask the facilitator for assistance.

Next, run a few checks:

```sh
kubectl get nodes # expect: Ready
kubectl get pods -n platform-agent-sandbox # expect: Running
kubectl get pods -n platform-agent-router # expect: Running
kubectl get pods -n platform-sourcegateway # expect: Running
kubectl get runtimeclass # expect: gvisor, runc
kubectl get storageclass # expect: platform-openebs-lvm-default
```

If any of the commands above do not return what is expected, stop here and ask the facilitator rather than deleting existing work.

If you already had a local cluster started prior to the workshop, or want to restart with a fresh cluster at any point during this workshop, you can run `local stop --rm` to stop and delete the cluster before starting a new cluster.

## 3. Create workshop namespaces

From this directory, run:

```sh
kubectl apply -f namespaces.yaml
```

This will create two namespaces:
1. `workshop` to run Agent Sandbox Pods with our `pi` agent harness. 
2. `workshop-inference` to hold inference provider configuration and keys. Its `agent-router.podplane.dev/routes: allowed` label, which only cluster admins can set, lets it attach routes to Agent Router.

Separating these makes ownership visible but does not provide isolation or restrictions.

**Checkpoint:** you have a cluster with the agentic components (Agent Sandbox, Agent Router, and Source Gateway) already running. Next, we supply a workload for them to manage.

---

← [Workshop Home](../README.md) &emsp; | &emsp; [Part 2 - Agent Sandbox](../02-agent-sandbox/) →
