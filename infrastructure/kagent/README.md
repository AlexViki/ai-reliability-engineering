# Kagent Installation and Configuration Guide

This document describes the complete setup, configuration, and deployment of Kagent v0.7.23 in Kubernetes via FluxCD with Google Gemini 2.0 Flash LLM integration.

---

## Table of Contents

1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Prerequisites](#prerequisites)
4. [Installation](#installation)
5. [Configuration](#configuration)
6. [Troubleshooting](#troubleshooting)
7. [Verification](#verification)
8. [Known Issues](#known-issues)
9. [Advanced Configuration](#advanced-configuration)

---

## Overview

**Kagent** is a Kubernetes-native agent framework that enables building and deploying intelligent agents with LLM support. This setup integrates Kagent with:

- **Kubernetes**: Native deployment as CRDs
- **FluxCD**: GitOps-based declarative deployment
- **Google Gemini 2.0 Flash**: Default LLM provider
- **MCP Protocol**: Model Context Protocol support for tool integration

**Deployment Method**: Helm charts via FluxCD for full GitOps automation.

---

## Architecture

### Component Hierarchy

```
FluxCD (flux-system namespace)
  │
  ├─→ HelmRepository (kagent)
  │   └─ oci://ghcr.io/kagent-dev/kagent/helm
  │
  ├─→ HelmRelease (kagent-crds)
  │   └─ Installs Custom Resource Definitions
  │
  └─→ HelmRelease (kagent) [depends on kagent-crds]
      └─ Deploys all Kagent components

        ↓

kagent-system Namespace
  │
  ├─ Pods:
  │   ├─ kagent-system-kagent-controller (Main orchestrator)
  │   ├─ kagent-system-kagent-ui (Web dashboard)
  │   ├─ kagent-system-kagent-grafana-mcp (Grafana integration)
  │   ├─ kagent-system-kagent-kmcp-controller-manager (KMCP)
  │   ├─ kagent-system-kagent-querydoc (Query documentation agent)
  │   ├─ kagent-system-kagent-tools (Tools provider service)
  │   └─ promql-agent (Prometheus/PromQL integration)
  │
  ├─ Services:
  │   ├─ kagent-system-kagent-controller (gRPC, port 8083)
  │   ├─ kagent-system-kagent-ui (HTTP, port 8080)
  │   ├─ kagent-system-kagent-tools (gRPC, port 8084)
  │   └─ ... (8 total services)
  │
  └─ Secrets:
      ├─ kagent-llm-secrets (Gemini API key)
      ├─ kagent-gemini (Provider configuration)
      └─ ... (4 total secrets)
```

### Deployment Flow

```
Local Development
    ↓
Git Repository (ai-reliability-engineering)
    ↓
FluxCD Reconciliation (every 5 minutes)
    ↓
HelmRelease Processing
    ├─ kagent-crds installed first
    ├─ Dependencies awaited
    └─ kagent deployed to kagent-system namespace
    ↓
Kubernetes Cluster
    ├─ Pods scheduled and started
    ├─ Services created
    ├─ Secrets injected
    └─ UI accessible on port 8080
```

---

## Prerequisites

### Required Tools
- `kubectl` (v1.24+)
- `helm` (v3.10+)
- `git`
- Access to Kubernetes cluster with FluxCD installed
- Google Cloud API key for Gemini LLM access

### Cluster Requirements
- FluxCD installed and configured
- 2+ CPU cores available
- 1GB+ free memory
- Network connectivity to:
  - `ghcr.io` (image registry)
  - `oci://ghcr.io/kagent-dev/kagent/helm` (Helm repository)
  - Google Gemini API endpoint

### API Access
- Google AI Studio account: https://aistudio.google.com
- Create API key for Gemini 2.0 Flash model
- Store securely (not in Git repository)

---

## Installation

### Step 1: Prepare Directory Structure

```bash
mkdir -p infrastructure/kagent
cd infrastructure/kagent
```

### Step 2: Create HelmRepository Configuration

**File**: `infrastructure/kagent/helmrepository.yaml`

```yaml
apiVersion: source.toolkit.fluxcd.io/v1
kind: HelmRepository
metadata:
  name: kagent
  namespace: flux-system
spec:
  interval: 10m
  type: oci
  url: oci://ghcr.io/kagent-dev/kagent/helm
```

**Key Points**:
- Uses OCI (Open Container Initiative) format for Helm charts
- Registry: `ghcr.io/kagent-dev/kagent/helm`
- Reconciliation interval: 10 minutes
- This must be created BEFORE HelmRelease

### Step 3: Create Namespace

**File**: `infrastructure/kagent/namespace.yaml`

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: kagent-system
```

**Note**: The namespace is created before HelmReleases to ensure proper ordering.

### Step 4: Create Secrets (Local Only - Not in Git)

**Location**: `~/access/secrets.yaml` (NOT committed to Git)

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: kagent-llm-secrets
  namespace: kagent-system
type: Opaque
stringData:
  GEMINI_API_KEY: "your-actual-google-gemini-api-key"
```

**Application**:
```bash
kubectl apply -f ~/access/secrets.yaml
```

**Security Considerations**:
- Never commit secrets to Git repository
- Store in secure location locally
- Consider using Sealed Secrets for production
- Rotate API keys regularly

### Step 5: Create HelmReleases

**File**: `infrastructure/kagent/helmrelease.yaml`

Contains TWO HelmRelease resources:

#### A. CRDs Installation (kagent-crds)
```yaml
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: kagent-crds
  namespace: flux-system
spec:
  interval: 10m
  chart:
    spec:
      chart: kagent-crds
      version: "*"  # Latest version
      sourceRef:
        kind: HelmRepository
        name: kagent
        namespace: flux-system
  targetNamespace: kagent-system
  install:
    crds: Create
    disableWait: true
    remediation:
      retries: 5
  upgrade:
    crds: CreateReplace
    disableWait: true
  values: {}
```

**Purpose**: 
- Installs all Custom Resource Definitions needed by Kagent
- Must run BEFORE main kagent deployment
- `disableWait: true` prevents timeout during initialization

#### B. Main Kagent Deployment (kagent)
```yaml
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: kagent
  namespace: flux-system
spec:
  interval: 10m
  dependsOn:
    - name: kagent-crds  # Wait for CRDs first
  chart:
    spec:
      chart: kagent
      version: "*"
      sourceRef:
        kind: HelmRepository
        name: kagent
        namespace: flux-system
  targetNamespace: kagent-system
  install:
    crds: Create
    disableWait: true
    remediation:
      retries: 5
  upgrade:
    crds: CreateReplace
    disableWait: true
  values:
    # LLM Provider Configuration - Gemini
    providers:
      default: gemini
      gemini:
        apiKey: GEMINI_API_KEY
    
    # Controller configuration
    controller:
      env:
        - name: KAGENT_CONTROLLER_NAME
          value: kagent-controller
        - name: LOG_LEVEL
          value: info
      envFrom:
        - secretRef:
            name: kagent-llm-secrets
    
    # UI Configuration
    ui:
      enabled: true
      service:
        type: ClusterIP
        port: 8080
    
    # Resource configuration
    resources:
      requests:
        cpu: 250m
        memory: 256Mi
      limits:
        cpu: 500m
        memory: 512Mi
    
    # Pod annotations for Prometheus
    podAnnotations:
      prometheus.io/scrape: "true"
      prometheus.io/port: "8080"
```

**Key Configuration**:
- `dependsOn`: Ensures CRDs are installed first
- `disableWait: true`: Allows installation to complete without pod readiness
- `envFrom.secretRef`: Injects Gemini API key from Secret
- Resource limits prevent excessive resource consumption
- Prometheus annotations enable metrics collection

### Step 6: Create Kustomization File

**File**: `infrastructure/kagent/kustomization.yaml`

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - namespace.yaml
  - helmrepository.yaml
  - secrets.yaml
  - helmrelease.yaml
```

**Note**: The ordering of resources matters:
1. `namespace.yaml` - Created first
2. `helmrepository.yaml` - Before HelmReleases can reference it
3. `secrets.yaml` - Before pods that need environment variables
4. `helmrelease.yaml` - After all dependencies

### Step 7: Register with Main Infrastructure

**File**: `infrastructure/kustomization.yaml` (Update)

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- gateway-api
- agentgateway
- kagent          # ← Add this line
- namespace.yaml
```

### Step 8: Commit to Git

```bash
cd /path/to/ai-reliability-engineering
git add infrastructure/kagent/
git commit -m "Add kagent FluxCD deployment with Gemini 2.0 Flash LLM"
git push origin main
```

**Important**: Do NOT commit `~/access/secrets.yaml` - manage it separately

---

## Configuration

### LLM Provider: Google Gemini 2.0 Flash

#### Setup Steps

1. **Create Google Cloud API Key**:
   ```bash
   # Visit: https://aistudio.google.com/api-keys
   # Create new API key for Gemini
   # Copy the key to secure location
   ```

2. **Encode for Kubernetes Secret**:
   ```bash
   echo -n "your-api-key-here" | base64
   # Output: eW91ci1hcGkta2V5LWhlcmU=
   ```

3. **Create Secret Manifest**:
   ```yaml
   apiVersion: v1
   kind: Secret
   metadata:
     name: kagent-llm-secrets
     namespace: kagent-system
   type: Opaque
   data:
     GEMINI_API_KEY: "eW91ci1hcGkta2V5LWhlcmU="
   ```

4. **Apply Secret**:
   ```bash
   kubectl apply -f ~/access/secrets.yaml
   ```

#### Verification

```bash
# Check secret exists
kubectl get secret kagent-llm-secrets -n kagent-system

# Verify secret data (careful - shows keys)
kubectl get secret kagent-llm-secrets -n kagent-system -o jsonpath='{.data}' | jq

# Check if pods receive the environment variable
kubectl exec -it deployment/kagent-system-kagent-controller -n kagent-system -- env | grep GEMINI
```

### Environment Variables in Kagent

The following environment variables are injected via Secret:

| Variable | Source | Purpose |
|----------|--------|---------|
| `GEMINI_API_KEY` | Secret `kagent-llm-secrets` | Authentication for Gemini API |
| `KAGENT_CONTROLLER_NAME` | HelmRelease values | Service name for agent discovery |
| `LOG_LEVEL` | HelmRelease values | Logging verbosity (info/debug) |

### Resource Configuration

**Current Settings** (in `helmrelease.yaml`):
```yaml
resources:
  requests:
    cpu: 250m        # Minimum CPU guaranteed
    memory: 256Mi    # Minimum memory guaranteed
  limits:
    cpu: 500m        # Maximum CPU allowed
    memory: 512Mi    # Maximum memory allowed
```

**Tuning Guide**:
- Small deployments: Keep as-is
- Heavy workloads: Increase both requests and limits proportionally
- High-density clusters: Reduce requests/limits but maintain ratio

### Scaling Configuration

To enable Horizontal Pod Autoscaling:

```bash
# After installation, create HPA resource
kubectl autoscale deployment -n kagent-system \
  kagent-system-kagent-controller \
  --min=1 --max=3 --cpu-percent=80
```

---

## Verification

### Check Installation Status

```bash
# 1. Verify HelmRepository
kubectl get helmrepository -n flux-system | grep kagent

# 2. Check HelmRelease status
kubectl get helmrelease -n flux-system | grep kagent

# 3. Detailed HelmRelease info
kubectl describe helmrelease kagent -n flux-system
kubectl describe helmrelease kagent-crds -n flux-system

# 4. View HelmRelease events
kubectl get events -n flux-system --sort-by='.lastTimestamp' | grep kagent
```

### Verify Pods

```bash
# List all kagent pods
kubectl get pods -n kagent-system

# Expected output (all should be 1/1 Running):
NAME                                                           READY   STATUS
kagent-system-kagent-controller-779d76d469-tjng9               1/1     Running
kagent-system-kagent-grafana-mcp-54f6b9d458-f8cxw              1/1     Running
kagent-system-kagent-kmcp-controller-manager-5c7c554fc-r7slg   1/1     Running
kagent-system-kagent-querydoc-5f7bf599ff-jmjfq                 1/1     Running
kagent-system-kagent-tools-798647666c-l99p5                    1/1     Running
kagent-system-kagent-ui-675dcf9d4b-gntbx                       1/1     Running
promql-agent-6f894dccfc-lrscp                                  1/1     Running

# Check pod logs
kubectl logs -n kagent-system -l app.kubernetes.io/name=kagent --tail=50
```

### Verify Services

```bash
# List all services
kubectl get svc -n kagent-system

# Get service endpoints
kubectl get endpoints -n kagent-system

# Test service connectivity
kubectl exec -it <kagent-pod> -n kagent-system -- \
  curl http://kagent-system-kagent-controller:8083/health
```

### Verify Secrets

```bash
# List secrets
kubectl get secret -n kagent-system

# Verify secret data
kubectl get secret kagent-llm-secrets -n kagent-system -o jsonpath='{.data.GEMINI_API_KEY}'
```

### Access Web UI

```bash
# Port-forward to local machine
kubectl port-forward -n kagent-system svc/kagent-system-kagent-ui 8080:8080

# In browser, navigate to:
# http://localhost:8080
```

### Test LLM Connectivity

```bash
# Get controller pod name
POD_NAME=$(kubectl get pod -n kagent-system -l app.kubernetes.io/name=kagent -o jsonpath='{.items[0].metadata.name}')

# Test Gemini API connection
kubectl exec -it $POD_NAME -n kagent-system -- bash -c '
  curl -X POST https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent \
    -H "Content-Type: application/json" \
    -H "x-goog-api-key: $GEMINI_API_KEY" \
    -d "{\"contents\": [{\"parts\": [{\"text\": \"Hello\"}]}]}"
'
```

---

## Troubleshooting

### Issue 1: HelmRelease Status "SourceNotReady"

**Symptom**:
```
Message: HelmChart 'flux-system/flux-system-kagent' is not ready: 
chart pull error: failed to download chart
```

**Causes**:
1. HelmRepository not synced yet
2. Chart version doesn't exist in registry
3. Network connectivity issue

**Solutions**:
```bash
# 1. Check HelmRepository status
kubectl describe helmrepository kagent -n flux-system

# 2. Force reconciliation
kubectl annotate helmrepository kagent -n flux-system \
  source.toolkit.fluxcd.io/reconcile=now --overwrite

# 3. Check if chart exists
helm search repo kagent --versions

# 4. Add repo manually for testing
helm repo add kagent oci://ghcr.io/kagent-dev/kagent/helm
helm repo update kagent
```

### Issue 2: Pods in ImagePullBackOff

**Symptom**:
```
STATUS: ImagePullBackOff
Events: Failed to pull image "ghcr.io/kagent-dev/kagent:..."
```

**Causes**:
1. Registry authentication issue
2. Image doesn't exist in registry
3. Network connectivity to registry

**Solutions**:
```bash
# 1. Check image pull logs
kubectl describe pod <pod-name> -n kagent-system | grep -A 10 "Events:"

# 2. Verify image exists
docker pull ghcr.io/kagent-dev/kagent:latest

# 3. Check registry credentials
kubectl get secret -n kagent-system | grep dockercfg

# 4. Manually pull for testing
kubectl run test-pull --image=ghcr.io/kagent-dev/kagent:latest \
  --overrides='{"spec":{"serviceAccountName":"kagent"}}' -n kagent-system
```

### Issue 3: MCP Service Connection Errors

**Symptom**:
```
Error logs: "dial tcp 10.110.188.88:8080: connect: connection refused"
Failed to fetch tools for toolServer
```

**Expected Behavior**: 
These errors during initial pod startup (first 2-3 minutes) are NORMAL and not a deployment failure.

**Why It Happens**:
1. Services start but aren't ready to accept connections
2. MCP protocol initialization still in progress
3. Service discovery hasn't fully propagated

**Resolution**:
```bash
# Wait 3 minutes and check again
sleep 180
kubectl logs -n kagent-system -l app.kubernetes.io/name=kagent --tail=20

# If errors persist after 5 minutes, check:
# 1. Pod CPU/memory isn't exhausted
kubectl top pod -n kagent-system

# 2. DNS resolution works
kubectl exec -it <pod-name> -n kagent-system -- nslookup kagent-system-kagent-querydoc

# 3. Service exists and has endpoints
kubectl get svc kagent-system-kagent-querydoc -n kagent-system
kubectl get endpoints kagent-system-kagent-querydoc -n kagent-system
```

### Issue 4: Gemini API Key Not Working

**Symptom**:
```
Error: Invalid API key
401 Unauthorized from generativelanguage.googleapis.com
```

**Verification**:
```bash
# 1. Check secret is properly set
kubectl get secret kagent-llm-secrets -n kagent-system -o yaml

# 2. Verify environment variable in pod
kubectl exec -it <pod-name> -n kagent-system -- env | grep GEMINI

# 3. Test API key directly
curl -X POST https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent \
  -H "Content-Type: application/json" \
  -H "x-goog-api-key: YOUR_API_KEY" \
  -d '{"contents": [{"parts": [{"text": "Hello"}]}]}'

# 4. Check API key format
# Should start with 'AIz...' and be about 40+ characters
echo $GEMINI_API_KEY | wc -c
```

**Solutions**:
```bash
# 1. Update secret with new key
kubectl delete secret kagent-llm-secrets -n kagent-system
kubectl create secret generic kagent-llm-secrets \
  -n kagent-system \
  --from-literal=GEMINI_API_KEY=your-new-key

# 2. Restart pods to pick up new secret
kubectl rollout restart deployment -n kagent-system

# 3. Verify new key
kubectl exec -it <pod-name> -n kagent-system -- \
  curl https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent \
    -H "x-goog-api-key: $GEMINI_API_KEY"
```

### Issue 5: Insufficient Resources

**Symptom**:
```
Status: Pending
Message: 0/1 nodes available: insufficient cpu
```

**Solutions**:
```bash
# 1. Check cluster resources
kubectl describe nodes | grep -A 5 "Allocated resources"

# 2. Check resource requests in HelmRelease
kubectl get helmrelease kagent -n flux-system -o yaml | grep -A 10 "resources:"

# 3. Reduce resource requirements
kubectl patch helmrelease kagent -n flux-system --type merge -p '
  {"spec": {"values": {"resources": {"requests": {"cpu": "100m", "memory": "128Mi"}}}}}'

# 4. Add more nodes to cluster
# (cluster-specific commands)

# 5. Restart kubelet if resources are misreported
sudo systemctl restart kubelet
```

---

## Known Issues

### Issue: MCP Service Connection Errors During Startup

**Status**: ✅ Expected and Harmless  
**Frequency**: Always occurs on fresh deployment  
**Duration**: 2-3 minutes until services stabilize  
**Impact**: None - UI and core functionality work normally  
**Root Cause**: MCP (Model Context Protocol) services attempt connection before target pods are ready

**Example Error Logs**:
```
failed to connect client for toolServer kagent-system/kagent-system-kagent-querydoc: 
calling "initialize": sending "initialize": rejected by transport: 
Post "http://kagent-system-kagent-querydoc.kagent-system:8080/mcp": 
dial tcp 10.110.188.88:8080: connect: connection refused
```

**When They Stop**:
```bash
# Check logs after 3 minutes
kubectl logs -n kagent-system -l app.kubernetes.io/name=kagent --since=5m | grep -i error | wc -l

# Should significantly decrease compared to initial deployment
```

**Mitigation**:
- No action required - these are transient startup errors
- Ignore if UI is accessible and pods are Running
- Only investigate if errors persist after 10 minutes

### Issue: Chart Version Selection with Wildcard

**Status**: ⚠️ Design Choice  
**Current Setting**: `version: "*"` (always use latest)  
**Alternative**: Specify explicit version like `version: "0.7.23"`

**Pros of Wildcard**:
- Always get latest fixes and features
- Automatic updates via FluxCD

**Cons of Wildcard**:
- Potential breaking changes
- Non-deterministic deployments
- May fail if incompatible version released

**Recommendation**:
```yaml
# For production, use explicit version:
chart:
  spec:
    chart: kagent
    version: "0.7.23"  # ← Pin to specific version
```

### Issue: Secrets in Git Repository

**Status**: 🔒 Security Concern  
**Current Approach**: Secrets stored locally in `~/access/secrets.yaml`  
**Why**: Never commit sensitive data to Git  

**For Production**:
```bash
# Use Sealed Secrets
kubectl create secret generic kagent-llm-secrets \
  --from-literal=GEMINI_API_KEY=<key> \
  -n kagent-system \
  -o yaml | kubeseal -f - > sealed-secret.yaml

# Then commit sealed-secret.yaml to Git
```

---

## Advanced Configuration

### Custom LLM Provider (OpenAI Alternative)

To use OpenAI instead of Gemini:

```yaml
# In helmrelease.yaml values section
providers:
  default: openAI
  openAI:
    apiKey: OPENAI_API_KEY

# And update secret:
apiVersion: v1
kind: Secret
metadata:
  name: kagent-llm-secrets
  namespace: kagent-system
type: Opaque
stringData:
  OPENAI_API_KEY: "sk-..."
```

### Enable Debug Logging

```yaml
# In helmrelease.yaml values
controller:
  env:
    - name: LOG_LEVEL
      value: debug  # Changed from 'info'
```

### Custom Controller Service Name

```yaml
controller:
  env:
    - name: KAGENT_CONTROLLER_NAME
      value: my-custom-kagent-name  # For cross-cluster discovery
```

### Add Network Policies

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: kagent-network-policy
  namespace: kagent-system
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/name: kagent
  policyTypes:
    - Ingress
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              name: kagent-system
      ports:
        - protocol: TCP
          port: 8080
```

### Enable Ingress Access

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: kagent-ui
  namespace: kagent-system
spec:
  ingressClassName: nginx
  rules:
    - host: kagent.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: kagent-system-kagent-ui
                port:
                  number: 8080
```

### Integration with Prometheus

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: kagent
  namespace: kagent-system
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: kagent
  endpoints:
    - port: metrics
      interval: 30s
```

---

## References

### Official Documentation
- [Kagent GitHub](https://github.com/kagent-dev/kagent)
- [Kagent Documentation](https://kagent.dev/docs/)
- [Kagent Helm Charts](https://github.com/kagent-dev/kagent/tree/main/helm)

### Related Projects
- [FluxCD Documentation](https://fluxcd.io/)
- [Google Gemini API](https://ai.google.dev/)
- [Model Context Protocol (MCP)](https://modelcontextprotocol.io/)
- [Kubernetes Gateway API](https://gateway-api.sigs.k8s.io/)

### Useful Commands

```bash
# Complete deployment check
kubectl get ns,helmrepo,helmrelease,pod,svc,secret -n kagent-system

# Real-time pod logs
kubectl logs -n kagent-system -l app.kubernetes.io/name=kagent -f

# Port-forward for UI access
kubectl port-forward -n kagent-system svc/kagent-system-kagent-ui 8080:8080

# Interactive shell in pod
kubectl exec -it <pod-name> -n kagent-system -- /bin/bash

# Resource usage
kubectl top pod -n kagent-system

# Event history
kubectl get events -n kagent-system --sort-by='.lastTimestamp'

# Restart all kagent pods
kubectl rollout restart deployment -n kagent-system

# Delete and reinstall
kubectl delete ns kagent-system
# Then git push will retrigger FluxCD deployment
```

---

## Support & Next Steps

### Verification Checklist

- [ ] HelmRepository synced (`kubectl describe helmrepository kagent -n flux-system`)
- [ ] Both HelmReleases succeeded (`kubectl get helmrelease -n flux-system | grep kagent`)
- [ ] All 7 pods running (`kubectl get pods -n kagent-system`)
- [ ] All 8 services created (`kubectl get svc -n kagent-system`)
- [ ] Secret contains Gemini key (`kubectl get secret kagent-llm-secrets -n kagent-system`)
- [ ] UI accessible (`kubectl port-forward -n kagent-system svc/kagent-system-kagent-ui 8080:8080`)

### Next Steps

1. **Test UI**: Access http://localhost:8080 and explore dashboard
2. **Verify LLM**: Send test message through Gemini integration
3. **Deploy Agents**: Create custom Agent CRDs for specific tasks
4. **Setup Monitoring**: Configure Prometheus scraping for metrics
5. **Production Hardening**: Enable TLS, sealed secrets, network policies

---

**Last Updated**: March 15, 2026  
**Kagent Version**: 0.7.23  
**Gemini Model**: gemini-2.0-flash  
**FluxCD Integration**: ✅ Complete
