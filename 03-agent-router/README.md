# Part 3: Agent Router

**Goal:** configure your inference provider of choice in Agent Router, without putting its API key in your Pi agent sandbox.

You are going to configure **one** inference provider: OpenAI or an OpenAI-compatible service. OpenAI requires API access, not a chat subscription.

> Note: using Anthropic API is for homework - follow the Pi configuration changes noted in `anthropic.yaml` as a starting point.

## 1. Store the Upstream API Key

From this directory, store your provider's API key in a Kubernetes Secret:

```sh
./create-provider-secret.sh
```

The script prompts for the secret, without echoing your key or storing it in your shell history, and pipes it to `kubectl` to create or update the Secret in `workshop-inference`.

## 2. Configure the Inference Provider in Agent Router

Note: During part 2, Pi was configured with a single model alias, `podplane-workshop-example-model`. This Helm chart maps it to your chosen provider's model.

Specify your provider's values file and model below:

```sh
helm upgrade --install workshop-inference . \
  --namespace workshop-inference \
  --values openai.yaml \
  --set-string model=gpt-4o-mini
kubectl -n workshop-inference get aigatewayroute,aiservicebackend
```

**Using OpenAI-compatible local inference instead?** Use `local.yaml` and your server's model ID. It connects to your laptop at `http://host.podplane.internal:8000`; add `--set port=1234` if your server uses a different port.

```sh
helm upgrade --install workshop-inference . \
  --namespace workshop-inference \
  --values local.yaml \
  --set-string model=mtplx-mimo-v26-qwen-9b-optimized-speed
```

After deployment, run these commands to wait until Agent Router is ready to handle Pi's requests:

```sh
kubectl -n platform-agent-router wait deployment/platform-agent-router-gateway \
  --for=jsonpath='{.spec.template.metadata.annotations.aigateway\.envoyproxy\.io/extproc-config-hash}' \
  --timeout=180s && \
kubectl -n platform-agent-router rollout status deployment/platform-agent-router-gateway \
  --timeout=180s
```

Wait for both commands to succeed before starting Pi. This avoids connection errors while Agent Router is starting up.

The chart creates these resources, defined in `templates/`:

- `AIGatewayRoute` — routes Pi's model alias to the provider and overrides the upstream model name (i.e. maps `podplane-workshop-example-model` to `gpt-4o-mini`)
- `AIServiceBackend` — selects the provider's API format and references its endpoint (defined by `Backend` below).
- `Backend` — defines the upstream API hostname and port.
- `BackendTLSPolicy` — verifies the upstream server's TLS certificate and hostname; omitted when `tls=false`.
- `BackendSecurityPolicy` — wires up supplying the API key from the Secret; it does not authenticate callers.

To switch providers, repeat steps 1 and 2 with the new API key and values file, keeping the same release name so existing resources are overwritten.

## 3. Test Inference In Pi

Pi already points at Agent Router through Part 2's ConfigMap, using the `podplane` provider and dummy key `unused`. It sends OpenAI-format requests to `/v1/chat/completions`; Agent Router supplies the upstream API key and model name without translating between API formats.

```sh
podplane shell -n workshop pi
pi
```

Ask:

> Write /workspace/hello.go to print "Hello from my sandbox", then run it with go run and show me the output. Use only the Go standard library; do not install any packages.

Watch Pi use its tools, then exit Pi with Ctrl+C twice. In the sandbox shell, check the result yourself:

```sh
go run /workspace/hello.go
cat /home/agent/.pi/agent/models.json
exit # Return to your laptop's shell.
```

**Checkpoint:** the file prints the requested message, and Pi's models configuration contains only an `unused` apiKey value. Inference works through the router; the direct-internet check from Part 2 must still fail. This keeps the provider key outside agent-readable storage, but does not stop the agent sending data to its permitted model.

For failures, inspect `kubectl -n workshop-inference get aigatewayroute,aiservicebackend,backendsecuritypolicy -o yaml` and `kubectl -n workshop-inference get httproute -o yaml`. Look for rejected references or attachment conditions. A 401/403 may be a provider-key/access problem; a 404 may be a path/model mismatch; a timeout may be a network-policy or readiness problem. Do not solve these by copying the upstream key into Pi.

---

[← Previous: agent sandbox](../02-agent-sandbox/) · [Next: source gateway →](../04-source-gateway/)
