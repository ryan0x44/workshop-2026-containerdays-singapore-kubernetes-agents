# Part 5: Wrap Pi with nono

**Goal:** authenticate inference with the sandbox's workload certificate while keeping its private key unreadable by Pi and its tools.

This follows Part 3's OpenAI-compatible setup. nono handles the client certificate and only Agent Router has the upstream provider key.

```text
Pi + tools ── localhost HTTP + session token ──> nono
                                                 │
                                  workload mTLS  │
                                                 ▼
                                            Agent Router ──> provider
```

nono and its profile configuration are already included in the image built in Part 2.

**Runtime change:** nono needs Landlock, which gVisor does not support. This part replaces gVisor with `runc`.

Run commands from this directory on your laptop unless labelled **inside the sandbox**. Exit Pi first. Replacing the Pod preserves `/workspace` but resets Pi settings and session history in the home directory.

## 1. Configure the runc runtime

Allow `runc` in the workshop namespace, then update the Sandbox:

```sh
kubectl label namespace workshop runtime.podplane.dev/runc=allowed --overwrite
kubectl -n workshop patch sandbox pi --type=merge \
  -p '{"spec":{"podTemplate":{"spec":{"runtimeClassName":"runc"}}}}'
```

The running Pod still uses gVisor. We'll recreate it after updating Pi's configuration.

## 2. Configure Pi to use nono's proxy

Replace the ConfigMap's original `models.json` with [`models-nono.json`](models-nono.json), which points Pi at nono's local proxy:

```sh
kubectl -n workshop create configmap pi-models --from-file=models-nono.json \
  --dry-run=client -o yaml | kubectl apply -f -
```

At startup, the entrypoint links this file to `/home/agent/.pi/agent-nono/models.json`. nono sets `PI_CODING_AGENT_DIR` so Pi uses that directory.

Recreate the Pod once to apply both changes:

```sh
kubectl -n workshop delete pod pi --ignore-not-found
kubectl -n workshop wait --for=create pod/pi --timeout=180s
kubectl -n workshop wait --for=condition=Ready pod/pi --timeout=180s
kubectl -n workshop get pod pi -o jsonpath='{.spec.runtimeClassName}{"\n"}'
# expect: runc
```

Use Pi through nono from here on.

## 3. Restrict the tenant route to the workshop namespace

The listener already verifies client certificates (`VerifyIfGiven`). Envoy replaces caller-supplied `x-forwarded-client-cert` headers with the verified identity. The tenant route can match this identity without changing the listener or other routes.

Patch the `AIGatewayRoute` created in Part 3:

```sh
kubectl -n workshop-inference patch aigatewayroute workshop-inference \
  --type=json --patch-file route-identity.yaml
kubectl -n workshop-inference get aigatewayroute workshop-inference \
  -o jsonpath='{.spec.rules[0].matches}{"\n"}'
```

The route now requires **both** the model alias and a verified identity from namespace `workshop`. Any ServiceAccount there is allowed; `workshop-other` is not. Keep both checks in one match—a separate model-only match would bypass the restriction.

Without a certificate, clients can connect but cannot use this route. Reapply the patch after reinstalling or upgrading Part 3's Helm release.

Open a sandbox shell and inspect its certificate:

```sh
podplane shell -n workshop pi
nono --version
nono setup --check-only
openssl x509 -in /var/run/podplane/identity/tls.crt -noout -ext subjectAltName
```

Expect a SPIFFE URI ending in `/ns/workshop/sa/pi`.

**Inside the sandbox**, send an inference request without a certificate:

```sh
curl --cacert /var/run/podplane/trust/ca.crt --max-time 10 \
  --silent --show-error --write-out '\nHTTP %{http_code}\n' \
  -H 'Content-Type: application/json' \
  -d '{"model":"podplane-workshop-example-model","messages":[{"role":"user","content":"Hello"}]}' \
  https://platform-agent-router-gateway.platform-agent-router.svc/v1/chat/completions
```

Once the route update takes effect, expect an HTTP rejection, normally **404**. A timeout or TLS error does not prove the identity check works.

Repeat with `-H 'x-forwarded-client-cert: URI=spiffe://example.invalid/ns/workshop/sa/pi'`. This forged identity must also be rejected. Inference through nono should succeed in the next step.

## 4. Run Pi through nono

Still **inside the sandbox**:

```sh
nono run --proxy-port 18080 -- pi
```

The image sets `NONO_PROFILE=/etc/nono/pi.json`. Port 18080 matches Pi's configuration; Pi 1.4.0 cannot expand environment variables in `baseUrl`. Run one nono session at a time.

If prompted, select provider `podplane` and model `podplane-workshop-example-model`. Ask Pi:

> Write /workspace/hello-nono.go to print "Hello through nono", then run it with go run. Use only the Go standard library; do not install any packages. Also try to read /var/run/podplane/identity/tls.key and report whether access is denied. Do not print any key material.

Pi should stream responses, run the program and fail to read the key. Exit Pi with Ctrl+C twice, then check file access yourself:

```sh
nono run --proxy-port 18080 -- sh -c '
  set -eu
  printf "workspace access works\n" > /workspace/nono-check.txt
  cat /workspace/nono-check.txt
  if cat /var/run/podplane/identity/tls.key >/dev/null; then
    echo "FAIL: private key readable"; exit 1
  fi
  echo "PASS: private key unreadable"
  if cat /var/run/sourcegateway/token >/dev/null; then
    echo "FAIL: Source Gateway token readable"; exit 1
  fi
  echo "PASS: Source Gateway token unreadable"
'
```

Expect `Permission denied` and both `PASS` messages. `No such file` does not prove isolation; both files must exist outside nono.

### How requests authenticate

- **Pi → nono:** Pi sends `${ROUTER_TOKEN}` from its environment to `http://127.0.0.1:18080/router/v1`. The token is not stored in its model file.
- **nono → Agent Router:** nono replaces the token with the placeholder described below, presents the workload certificate and verifies the router's certificate. Only `POST /v1/chat/completions` is allowed.
- **Tenant route:** the request must match the model alias and carry a verified identity from `workshop`.
- **Agent Router → provider:** Part 3's configuration supplies the provider key and upstream model name.

nono 0.80.0 requires a header credential even with mTLS. `ROUTER_PLACEHOLDER=unused` satisfies that requirement; it is not a secret. The route authenticates the certificate identity, not this placeholder.

**Checkpoint:** inference works through nono, private-key reads fail, and requests without a certificate fail even with a forged identity header.

Fetch or clone outside nono before starting Pi: this profile blocks Source Gateway's token and network access.

## Limits and troubleshooting

- nono restricts Pi and its child processes. nono itself and a `podplane shell` session can still read the private key.
- Pi and its tools can use the session token to send workspace data to the allowed inference endpoint.
- Restart nono after certificate or CA rotation; it loads these files only at startup.
- `Landlock not available`: check that the Pod uses `runc`. Do not disable enforcement.
- Local proxy `401`: check `${ROUTER_TOKEN}` and `authHeader: true`.
- Route rejection: check the model alias, certificate namespace and both header matchers.
- nono `502`: check its TLS error, certificate expiry and workload CA. Keep certificate verification enabled.
- Port occupied: exit the other nono session; keep the port consistent with `models-nono.json`.
- Anthropic needs different Pi API settings and a different allowed proxy endpoint; this exercise uses OpenAI-compatible inference.

---

[← Previous: Source Gateway](../04-source-gateway/) · [Next: wrap-up and cleanup →](../README.md#after-the-workshop)
