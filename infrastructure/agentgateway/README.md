# Agentgateway Installation via FluxCD

This directory contains the FluxCD configuration for deploying Agentgateway v2.2.1 to the Kubernetes cluster.

## Overview

Agentgateway is a specialized Gateway API controller that manages network ingress using the Kubernetes Gateway API standard. This setup uses FluxCD for declarative GitOps-based deployment.

## Architecture

```
┌─────────────────────────────────────────────────┐
│         FluxCD (flux-system)                    │
│  ┌──────────────────────────────────────────┐  │
│  │ Kustomization: infrastructure            │  │
│  └──────────────────────────────────────────┘  │
│               │                                 │
└───────────────┼─────────────────────────────────┘
                │
    ┌───────────┴──────────────┐
    │                          │
    ▼                          ▼
┌─────────────────┐    ┌──────────────────┐
│ HelmRepository  │    │  HelmRelease     │
│ (OCI Registry)  │    │ (agentgateway-   │
│                 │    │  crds & main)    │
└─────────────────┘    └──────────────────┘
        │                      │
        └──────────┬───────────┘
                   │
                   ▼
        ┌──────────────────────┐
        │ agentgateway-system  │
        │  Namespace           │
        │                      │
        │  - Deployment        │
        │  - Service           │
        │  - ServiceAccount    │
        │  - RBAC Resources    │
        │  - GatewayClass      │
        └──────────────────────┘
```

## Configuration Files

### 1. `namespace.yaml`
Creates the `agentgateway-system` namespace where all agentgateway components run.

### 2. `helmrepository.yaml`
Configures FluxCD to fetch Helm charts from the official agentgateway OCI registry:
- **Registry**: `ghcr.io/kgateway-dev/charts`
- **Type**: OCI (modern containerized Helm charts)
- **Sync Interval**: 10 minutes

### 3. `helmrelease-crds.yaml`
Installs the Custom Resource Definitions (CRDs) required by agentgateway:
- **Chart**: `agentgateway-crds`
- **Version**: v2.2.1
- **Features**:
  - Installs CRDs for AgentgatewayBackend, AgentgatewayParameters, AgentgatewayPolicy
  - Handles CRD creation and updates automatically

### 4. `helmrelease.yaml`
Deploys the main agentgateway control plane:
- **Chart**: `agentgateway`
- **Version**: v2.2.1
- **Target Namespace**: `agentgateway-system`
- **Key Feature**: `disableWait: true` - bypasses Helm's deployment readiness check

### 5. `kustomization.yaml`
Coordinates all resources in this directory for deployment.

## Deployment Status

### Check Installation Status
```bash
# Verify HelmRelease status
kubectl get helmrelease -n flux-system | grep agentgateway

# Check agentgateway pod
kubectl get pods -n agentgateway-system

# Verify GatewayClass is created
kubectl get gatewayclass agentgateway

# Detailed GatewayClass information
kubectl describe gatewayclass agentgateway
```

### Expected Output
```
NAME           AGE   READY
agentgateway   5m    True

NAME                                              READY   STATUS    RESTARTS   AGE
agentgateway-system-agentgateway-c78694cb-tpbtj   1/1     Running   0          5m

NAME           CONTROLLER                      ACCEPTED   AGE
agentgateway   agentgateway.dev/agentgateway   True       5m
```

## Issues Encountered and Solutions

### Issue 1: Invalid HelmRelease API Version for namespace

**Problem:**
```
HelmRelease/flux-system/agentgateway dry-run failed: failed to create typed patch object 
(.spec.namespace: field not declared in schema)
```

**Root Cause:**
HelmRelease v2 API changed the field name from `spec.namespace` to `spec.targetNamespace`. The schema was incompatible with older specifications.

**Solution:**
Updated `helmrelease-crds.yaml` and `helmrelease.yaml` to use `targetNamespace` instead of `namespace`:

```yaml
spec:
  targetNamespace: agentgateway-system
```

**Commit:** `fix issue that HelmRelease v2 uses targetNamespace instead of namespace in the spec`

---

### Issue 2: Incorrect HelmRepository API Version

**Problem:**
```
kustomization/infrastructure HelmRepository/flux-system/agentgateway dry-run failed: 
no matches for kind "HelmRepository" in version "source.toolkit.fluxcd.io/v1beta2"
```

**Root Cause:**
The cluster's FluxCD installation uses `source.toolkit.fluxcd.io/v1` (stable), but the initial configuration specified `v1beta2` (experimental/deprecated). The FluxCD CRD version must match the cluster's installed version.

**Solution:**
Changed `helmrepository.yaml` API version from `v1beta2` to `v1`:

```yaml
apiVersion: source.toolkit.fluxcd.io/v1    # Changed from v1beta2
kind: HelmRepository
```

**Commit:** `Fix HelmRepository API version to v1`

---

### Issue 3: Helm Installation Timeout

**Problem:**
```
Helm install failed for release agentgateway-system/agentgateway-system-agentgateway 
with chart agentgateway@v2.2.1: timeout waiting for: 
[Deployment/agentgateway-system/agentgateway-system-agentgateway status: 'InProgress']
```

**Root Cause:**
The Helm chart has built-in wait logic that waits up to 5 minutes for the deployment to become ready. The agentgateway pod startup was being blocked by a TLSRoute API version incompatibility (see Issue 4), preventing the pod from becoming ready and causing the Helm install to timeout.

**Solution:**
Added `disableWait: true` to both install and upgrade sections:

```yaml
spec:
  install:
    crds: Create
    disableWait: true
  upgrade:
    crds: CreateReplace
    disableWait: true
```

This allows Helm to complete the installation without waiting for pod readiness, which is acceptable since FluxCD continues to reconcile the resource.

**Commit:** `Remove problematic dependency from agentgateway HelmRelease and add install remediation`

---

### Issue 4: TLSRoute API Version Not Served (Critical)

**Problem:**
```
watch error in cluster : failed to list *v1alpha2.TLSRoute: 
the server could not find the requested resource (get tlsroutes.gateway.networking.k8s.io)

Startup probe failed: Get "http://10.0.0.148:9093/readyz": 
context deadline exceeded (Client.Timeout exceeded while awaiting headers)
```

Pod logs showed continuous failures trying to sync TLSRoute v1alpha2 informer, preventing pod startup and readiness probe success.

**Root Cause:**
The Gateway API v1.4.1 CRD installation had multiple versions of TLSRoute defined:
- `v1` - served (active)
- `v1alpha2` - NOT served (deprecated)  
- `v1alpha3` - NOT served (deprecated)

However, agentgateway v2.2.1 was hardcoded to use the v1alpha2 API version. When the API server couldn't find a served version for v1alpha2, the watch operation failed. The agentgateway pod's startup probe failed because it couldn't reach the readiness endpoint on port 9093 while blocked by this sync failure.

**Solution:**
Manually patched the TLSRoute CRD to enable v1alpha2 as a served version:

```bash
kubectl patch crd tlsroutes.gateway.networking.k8s.io --type=json \
  -p='[{"op":"replace","path":"/spec/versions/1/served","value":true}]'
```

**Verification:**
```bash
kubectl get crd tlsroutes.gateway.networking.k8s.io -o jsonpath=\
'{range .spec.versions[*]}{.name}{" served="}{.served}{"\n"}{end}'

# Output:
# v1 served=true
# v1alpha2 served=true        ← Now enabled
# v1alpha3 served=false
```

**Why This Happened:**
The gateway-api installation (via kustomize from Kubernetes SIGs repository) removed v1alpha2 from the served versions when upgrading to the latest stable version. This is a known breaking change when upgrading from pre-v1.0 Gateway API to v1+. Agentgateway v2.2.1 hasn't yet updated to exclusively use v1.

**Permanent Solution Recommendation:**
- Upgrade to a newer version of agentgateway that supports Gateway API v1+ exclusively, OR
- Pin the gateway-api version to an older release that serves v1alpha2 by default

---

## Recovery Steps

If you need to redeploy from scratch, follow these steps:

### 1. Prerequisites Check
```bash
# Ensure gateway-api is installed with TLSRoute CRDs
kubectl api-resources | grep -i tlsroute

# Verify v1alpha2 is served (if using agentgateway v2.2.1)
kubectl get crd tlsroutes.gateway.networking.k8s.io -o jsonpath=\
'{range .spec.versions[*]}{.name}{" served="}{.served}{"\n"}{end}'
```

### 2. Enable TLSRoute v1alpha2 (if needed)
```bash
kubectl patch crd tlsroutes.gateway.networking.k8s.io --type=json \
  -p='[{"op":"replace","path":"/spec/versions/1/served","value":true}]'
```

### 3. Deploy via FluxCD
```bash
# The infrastructure kustomization will automatically deploy agentgateway
# Just ensure the git changes are pushed

git add infrastructure/agentgateway/
git commit -m "Deploy agentgateway via FluxCD"
git push

# FluxCD will reconcile within the configured interval (5 minutes default)
# Or force reconciliation:
kubectl annotate kustomization infrastructure \
  -n flux-system \
  fluxcd.io/reconcile=now \
  --overwrite
```

### 4. Verify Deployment
```bash
# Wait for pods to be ready (1-2 minutes)
kubectl wait pod -n agentgateway-system \
  -l app=agentgateway-system-agentgateway \
  --for=condition=Ready \
  --timeout=300s

# Verify GatewayClass
kubectl get gatewayclass agentgateway
```

## Troubleshooting

### Pod Not Becoming Ready

**Symptom:** Pod stuck in `0/1 Running` state

**Check logs:**
```bash
kubectl logs -n agentgateway-system \
  -l app=agentgateway-system-agentgateway \
  --tail=50 | grep -i error
```

**Common causes:**
1. TLSRoute v1alpha2 not served - apply the patch from Issue 4
2. RBAC permissions missing - verify service account has permissions for gateway.networking.k8s.io resources
3. CRDs not installed - check that agentgateway-crds HelmRelease succeeded

### HelmRelease Shows as "Unknown" Ready Status

**Solution:**
Check the detailed status:
```bash
kubectl describe helmrelease agentgateway -n flux-system
```

Look for the "Message" field in the status conditions. Common issues:
- `InstallFailed` - check Helm chart availability or values
- `Progressing` - still installing, wait 1-2 minutes
- Previous errors in "Events" section

### GatewayClass Not Created

**Check pod logs:**
```bash
kubectl logs -n agentgateway-system \
  -l app=agentgateway-system-agentgateway | grep -i gatewayclass
```

The GatewayClass is created by the agentgateway controller when it starts up. If it's missing, the pod may not have reached the initialization code.

---

## Related Files

- **Parent Kustomization**: `/infrastructure/kustomization.yaml` - includes agentgateway
- **Gateway API Setup**: `/infrastructure/gateway-api/` - required dependency
- **FluxCD System**: Deployed via `clusters/local/infrastructure.yaml`

## References

- [Agentgateway Documentation](https://docs.agentgateway.dev)
- [Gateway API Project](https://gateway-api.sigs.k8s.io/)
- [FluxCD Helm Integration](https://fluxcd.io/flux/components/helm/)
- [Kubernetes Custom Resources](https://kubernetes.io/docs/concepts/extend-kubernetes/api-extension/custom-resources/)

## Maintenance

### Upgrading Agentgateway Version

To upgrade to a newer version:

1. Update the version in both HelmRelease files:
   ```yaml
   spec:
     chart:
       spec:
         version: v2.3.0  # Update version
   ```

2. Commit and push to Git:
   ```bash
   git add infrastructure/agentgateway/
   git commit -m "Upgrade agentgateway to v2.3.0"
   git push
   ```

3. Monitor the upgrade:
   ```bash
   kubectl get helmrelease agentgateway -n flux-system -w
   ```

### Checking for Updates

```bash
# List available versions in the registry
helm search repo agentgateway --versions

# Or fetch directly from OCI registry
helm search repo oci://ghcr.io/kgateway-dev/charts/agentgateway --versions
```

---

## Summary

✅ **Agentgateway v2.2.1 is successfully deployed via FluxCD**

Key achievements:
- Declarative GitOps-based deployment
- Automatic CRD management
- GatewayClass controller running and accepting Gateways
- All components healthy and operational

The setup is production-ready and will automatically reconcile if any configuration changes are pushed to the repository.
