# Part 4: Source Gateway

**Goal:** give the Pi agent sandbox read access to one public repository through Podplane's bundled Source Gateway.

## 1. Register An Allowed Git Repository

Inspect [`repository.yaml`](repository.yaml). We use the small public [octocat/Hello-World](https://github.com/octocat/Hello-World) repository. The policy permits `git.read` only for ServiceAccount `workshop/pi`; it grants no push permission, including on a warm cache.

With a compatible bundle, from this directory:

```sh
kubectl apply -f repository.yaml
kubectl -n workshop wait --for=condition=Ready gitrepositories.sourcegateway.dev/hello-world --timeout=120s
```

Use the fully qualified resource name: Flux also has a `GitRepository` kind. If readiness fails, inspect `kubectl -n workshop get gitrepositories.sourcegateway.dev/hello-world -o yaml` for policy, credential or upstream conditions.

## 2. Clone from inside the sandbox

**Inside the sandbox**, define a helper that reads the rotating token afresh for each Git command:

```sh
podplane shell -n workshop pi
sourcegit() {
  GIT_CONFIG_COUNT=2 \
  GIT_CONFIG_KEY_0=http.https://sourcegateway.platform-sourcegateway.svc/.extraHeader \
  GIT_CONFIG_VALUE_0="Authorization: Bearer $(cat /var/run/sourcegateway/token)" \
  GIT_CONFIG_KEY_1=http.https://sourcegateway.platform-sourcegateway.svc/.sslCAInfo \
  GIT_CONFIG_VALUE_1=/var/run/podplane/trust/ca.crt \
    git "$@"
}
sourcegit clone https://sourcegateway.platform-sourcegateway.svc/git/workshop/hello-world.git
cd hello-world
git remote -v
git log -1 --oneline
cat README
```

The remote should name **Source Gateway**, not `github.com`. The header is scoped to that gateway URL, passed only to Git, and never saved in `.git/config`. Do not print the token or disable TLS verification. If you repeat the exercise, use `sourcegit fetch origin` in the existing checkout instead of cloning over it.

This demonstrates authorized access to a public upstream, **not private-credential injection**. The agent can read its short-lived gateway token, but it receives no GitHub credential and its policy permits only the named repository.

## 3. Check the boundary, then use Pi

Still inside the sandbox, try the same source **without** the token:

```sh
curl --cacert /var/run/podplane/trust/ca.crt \
  --max-time 10 --silent --show-error --output /dev/null --write-out '%{http_code}\n' \
  'https://sourcegateway.platform-sourcegateway.svc/git/workshop/hello-world.git/info/refs?service=git-upload-pack'
```

Expect **401**, even though the repository is now cached. A timeout or TLS error is not proof of authorization working. Do not test a push against somebody else's repository.

Start the same provider/model you used in Part 3, from this checkout:

```sh
pi --provider workshop --model gpt-4o-mini
# Anthropic alternative: pi --provider workshop --model claude-sonnet-4-5
```

Ask Pi to read `README` and create a short `NOTES.md` describing what it found, without installing packages or pushing. Exit Pi and inspect `git status --short` and `cat NOTES.md` yourself.

**Checkpoint:** the checkout came through an authenticated gateway, Pi can work on it, and an unauthenticated read fails. Your upstream credentials never entered the sandbox.

## Optional: use a private repository

This is a follow-on exercise, outside the eight-minute path. Today it requires an administrator to configure a named `githubUser` or `githubApp` credential and mount it in the **existing gateway**, with access restricted to the repository resource's namespace. Creating a Secret or SecretProviderBinding alone does not register that credential.

Use a disposable repository you own and a read-only, repository-limited credential. Follow [Source Gateway's deployment instructions](https://github.com/sourcegateway/sourcegateway/blob/main/docs/deployment.md), then set `spec.upstream.url` to your repository and `spec.upstream.credential` to the administrator-configured name. Keep the `workshop/pi` read-only policy. Clone through the same gateway path; never mount the upstream credential in the Sandbox. A named credential that is missing or invalid fails closed rather than falling back to anonymous access.

---

[← Previous: agent router](../03-agent-router/) · [Next: wrap-up and cleanup →](../README.md#after-the-workshop)
