#!/usr/bin/env bash
set -euo pipefail

# Run OLS setup and eval in a container with Python 3.11
# Usage: EVAL_OPENAI_API_KEY=sk-... ./scripts/container-eval-setup.sh

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
KUBECONFIG="${KUBECONFIG:-$HOME/.kube/config}"

if [ -z "${EVAL_OPENAI_API_KEY:-}" ]; then
  echo "ERROR: EVAL_OPENAI_API_KEY must be set" >&2
  echo "Usage: EVAL_OPENAI_API_KEY=sk-... $0" >&2
  exit 1
fi

echo "==> Running OLS Agentic setup in container with Python 3.11..."

podman run --rm -it \
  -v "$REPO_DIR:/workspace:Z" \
  -v "$KUBECONFIG:/root/.kube/config:Z" \
  -w /workspace \
  -e KUBECONFIG=/root/.kube/config \
  -e EVAL_OPENAI_API_KEY="$EVAL_OPENAI_API_KEY" \
  --network host \
  registry.access.redhat.com/ubi9/python-311:latest \
  bash -c '
    set -euo pipefail

    # Install oc CLI
    echo "==> Installing oc CLI..."
    curl -sL https://mirror.openshift.com/pub/openshift-v4/clients/ocp/latest/openshift-client-linux.tar.gz | \
      tar xz -C /usr/local/bin oc kubectl
    chmod +x /usr/local/bin/oc /usr/local/bin/kubectl

    # Install git (needed for pip install from git)
    echo "==> Installing git..."
    dnf install -y git-core >/dev/null

    # Setup venv
    echo "==> Setting up Python venv..."
    make setup-venv

    # Run OLS Agentic setup (will timeout waiting for ConfigMap)
    echo "==> Running initial OLS Agentic setup (will timeout)..."
    make setup-ols-agentic || true

    echo ""
    echo "==> Setup timed out as expected. Apply manual fixes now..."
    echo "Press Enter when ready to continue..."
    read -r

    # Retry setup
    echo "==> Retrying OLS Agentic setup..."
    make setup-ols-agentic

    echo ""
    echo "==> OLS Agentic is ready!"
    echo "==> You can now run: make eval-ols-agentic SCENARIO=group_metrics_issue"
  '
