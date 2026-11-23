#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="openshift-lightspeed"

echo "==> Creating lightspeed-agentic-configuration ConfigMap..."
cat <<'EOF' | oc apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: lightspeed-agentic-configuration
  namespace: openshift-lightspeed
data:
  sandbox-pod-spec: |
    {
      "serviceAccountName": "lightspeed-agentic-sandbox",
      "containers": [{
        "name": "sandbox",
        "image": "registry.redhat.io/openshift-lightspeed/lightspeed-agentic-sandbox-rhel9@sha256:1ae2197fcde6357fc1b49b0799e9107196ca32cfa727c1cadd3dc9815bb1c9c5",
        "resources": {
          "requests": {"memory": "512Mi", "cpu": "200m"},
          "limits": {"memory": "2Gi", "cpu": "2000m"}
        }
      }]
    }
EOF

echo "==> Creating ApprovalPolicy for auto-approval..."
cat <<'EOF' | oc apply -f -
apiVersion: agentic.openshift.io/v1alpha1
kind: ApprovalPolicy
metadata:
  name: cluster
spec:
  stages:
    - name: Analysis
      approval: Automatic
    - name: Execution
      approval: Automatic
    - name: Verification
      approval: Automatic
    - name: Escalation
      approval: Automatic
  maxConcurrentRuns: 10
EOF

echo "==> Creating RBAC for agents and sandboxes..."
cat <<'EOF' | oc apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: lightspeed-agent
  namespace: openshift-lightspeed
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: lightspeed-agent-reader
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-reader
subjects:
- kind: ServiceAccount
  name: lightspeed-agent
  namespace: openshift-lightspeed
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: lightspeed-agentic-sandbox
  namespace: openshift-lightspeed
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: lightspeed-agentic-sandbox-reader
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-reader
subjects:
- kind: ServiceAccount
  name: lightspeed-agentic-sandbox
  namespace: openshift-lightspeed
EOF

echo "==> Configuration complete!"
echo "==> Verify with: oc get configmap,approvalpolicy,sa -n $NAMESPACE"
