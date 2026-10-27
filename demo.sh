#!/usr/bin/env bash
# Runs the whole workshop (Parts 1-4) non-interactively as a demo.
# Assumes the prework is done and `podplane local start --memory 5G` has run.
#
# Run ./demo.sh with no environment variables for usage.
set -euo pipefail

provider="${WORKSHOP_PROVIDER:-local}"
case "$provider" in
  local) default_model=mtplx-mimo-v26-qwen-9b-optimized-speed ;;
  openai) default_model=gpt-4o-mini ;;
  *) echo "Unknown WORKSHOP_PROVIDER: $provider (use local or openai)" >&2; exit 1 ;;
esac
model="${WORKSHOP_MODEL:-$default_model}"

if [[ -z "${WORKSHOP_API_KEY:-}" ]]; then
  cat >&2 <<EOF
WORKSHOP_API_KEY is not set.

Set it without echoing it or saving it in shell history, then run ./demo.sh again:

  read -rs WORKSHOP_API_KEY && export WORKSHOP_API_KEY

  WORKSHOP_API_KEY   Required. Your provider's API key. For a local server that ignores
                     keys, any non-blank value works, e.g. export WORKSHOP_API_KEY=unused
  WORKSHOP_PROVIDER  local (default): an OpenAI-compatible server on your laptop at port 8000.
                     openai: api.openai.com.
  WORKSHOP_MODEL     Upstream model ID. Defaults to mtplx-mimo-v26-qwen-9b-optimized-speed
                     for local and gpt-4o-mini for openai.

Current settings: provider=$provider model=$model
EOF
  exit 1
fi

cd "$(dirname "$0")"
step() { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }
in_sandbox() { kubectl -n workshop exec pi -- bash -lc "$1"; }

for tool in podplane kubectl helm; do
  command -v "$tool" >/dev/null || { echo "$tool is not installed; see 00-prework." >&2; exit 1; }
done
[[ "$(kubectl config current-context)" == local ]] \
  || { echo 'kubectl context is not "local"; run: kubectl config use-context local' >&2; exit 1; }

step 'Part 1: create workshop namespaces'
kubectl apply -f 01-cluster-setup/namespaces.yaml

step 'Part 2: build the Pi image and deploy the Agent Sandbox'
podplane build --docker=false -t workshop-pi:v1 ./02-agent-sandbox/image
kubectl apply -f 02-agent-sandbox/network-policy.yaml
kubectl apply -f 02-agent-sandbox/sandbox.yaml
kubectl -n workshop wait --for=condition=Ready sandbox/pi --timeout=180s
kubectl -n workshop get pods,pvc
in_sandbox '
  id; pwd; pi --version; rg --version | head -1; fd --version
  test ! -e /var/run/secrets/kubernetes.io/serviceaccount/token && echo "No default API token"
  curl --connect-timeout 1 --max-time 1 -sI https://example.com && echo "UNEXPECTED: egress allowed" \
    || echo "Egress blocked, as expected"'

step 'Part 3: store the provider key and configure Agent Router'
# create-provider-secret.sh reads the key from stdin, keeping it out of arguments and files.
printf '%s\n' "$WORKSHOP_API_KEY" | ./03-agent-router/create-provider-secret.sh
helm upgrade --install workshop-inference ./03-agent-router \
  --namespace workshop-inference \
  --values "03-agent-router/$provider.yaml" \
  --set-string model="$model"
kubectl -n workshop-inference get aigatewayroute,aiservicebackend
kubectl -n platform-agent-router wait deployment/platform-agent-router-gateway \
  --for=jsonpath='{.spec.template.metadata.annotations.aigateway\.envoyproxy\.io/extproc-config-hash}' \
  --timeout=180s
kubectl -n platform-agent-router rollout status deployment/platform-agent-router-gateway --timeout=180s
in_sandbox 'cat /home/agent/.pi/agent/models.json'

step 'Part 4: register the repository in Source Gateway and configure git in the sandbox'
kubectl apply -f 04-source-gateway/repository.yaml
kubectl -n workshop wait --for=condition=Ready gitrepositories.sourcegateway.dev/hello-world --timeout=120s
# Configure the sandbox's git so a plain `git clone` of the gateway works: trust the
# workload CA, and send the rotating projected token (read afresh each time) as a Bearer
# credential. Nothing is stored in .git/config.
# shellcheck disable=SC2016 # expanded inside the sandbox, not here
in_sandbox '
  set -e
  gw=https://sourcegateway.platform-sourcegateway.svc
  git config --global "http.$gw/.sslCAInfo" /var/run/podplane/trust/ca.crt
  git config --global "credential.$gw.helper" \
    "!f() { test \"\$1\" = get || exit 0; echo capability[]=authtype; echo authtype=Bearer; echo credential=\$(cat /var/run/sourcegateway/token); }; f"
  echo "Configured git credentials for $gw"
  printf "Unauthenticated read (expect 401): "
  curl --cacert /var/run/podplane/trust/ca.crt \
    --max-time 10 --silent --show-error --output /dev/null --write-out "%{http_code}\n" \
    "$gw/git/workshop/hello-world.git/info/refs?service=git-upload-pack"'

step "Done. Now try it yourself (Agent Router sends Pi to $provider/$model)"
cat <<'EOF'
  podplane shell -n workshop pi
  git clone https://sourcegateway.platform-sourcegateway.svc/git/workshop/hello-world.git octocat-hello-world
  cd octocat-hello-world
  git remote -v   # Source Gateway, not github.com
  pi

Then ask Pi:
  Read README and create a short NOTES.md describing what you found. Do not install packages or push.

Or ask:
  Write /workspace/hello.go to print "Hello from my sandbox", then run it with go run and show me
  the output. Use only the Go standard library; do not install any packages.

Exit Pi with Ctrl+C twice, then check its work with: git status --short && cat NOTES.md
EOF
