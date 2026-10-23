#!/usr/bin/env bash
set -euo pipefail

# Read without echoing or altering the key; never run this script with bash -x.
IFS= read -r -s -p "${1:-Inference} API key (hidden): " api_key
printf '\n' >&2
[[ -n "$api_key" ]] || { echo 'The key cannot be empty.' >&2; exit 1; }

# Pipe the key without a trailing newline, keeping it out of arguments and files.
# Generate the Secret locally, then create or update it in the cluster.
printf '%s' "$api_key" \
  | kubectl -n workshop-inference create secret generic inference-provider-api-key \
      --from-file=apiKey=/dev/stdin --dry-run=client -o yaml \
  | kubectl apply -f -
