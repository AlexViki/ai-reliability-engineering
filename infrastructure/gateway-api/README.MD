# Gateway API Installation via FluxCD

This directory contains the FluxCD configuration for installing Kubernetes Gateway API in your cluster.

## Overview

Gateway API is a standard, vendor-neutral API for managing network traffic in Kubernetes. It provides a more expressive and extensible alternative to Ingress.

## Installation

The gateway-api is automatically installed through FluxCD using the resources defined in this directory:

- **helmrepository.yaml** - GitRepository source pointing to the official gateway-api GitHub repository
- **helmrelease.yaml** - Kustomization resource that applies the CRDs from the gateway-api repository

## How It Works

1. FluxCD's `source-controller` pulls the gateway-api repository from GitHub
2. The `kustomize-controller` applies the CRDs from the `./config/crd` path
3. Gateway API resources (GatewayClass, Gateway, HTTPRoute, etc.) become available in your cluster

## Installed CRDs

The following Custom Resource Definitions are created:

- `gatewayclasses.gateway.networking.k8s.io` - Defines gateway implementations
- `gateways.gateway.networking.k8s.io` - Creates gateway instances
- `httproutes.gateway.networking.k8s.io` - Routes HTTP traffic
- `grpcroutes.gateway.networking.k8s.io` - Routes gRPC traffic
- `tlsroutes.gateway.networking.k8s.io` - Routes TLS traffic
- `grpcroutes.gateway.networking.k8s.io` - Routes gRPC traffic
- `referencegrants.gateway.networking.k8s.io` - Cross-namespace references
- `backendtlspolicies.gateway.networking.k8s.io` - TLS policies for backends
- `listenersets.gateway.networking.k8s.io` - Advanced listener configurations

## Issues and Solutions

### Issue 1: API Version v1beta2 Not Supported

**Error:**
```
no matches for kind "GitRepository" in version "source.toolkit.fluxcd.io/v1beta2"
```

**Cause:** 
The initial configuration used FluxCD API version `v1beta2`, but the cluster had only `v1` available.

**Solution:**
Updated all FluxCD API resources to use `source.toolkit.fluxcd.io/v1` and `kustomize.toolkit.fluxcd.io/v1`:

```yaml
# Before (incorrect)
apiVersion: source.toolkit.fluxcd.io/v1beta2
kind: GitRepository

# After (correct)
apiVersion: source.toolkit.fluxcd.io/v1
kind: GitRepository
```

**Check your cluster's supported API versions:**
```bash
kubectl api-resources | grep -i source
```

### Issue 2: No Helm Chart Available

**Error:**
Initially tried to use a Helm repository, but gateway-api doesn't have an official Helm chart.

**Solution:**
Changed the approach to use a GitRepository source with Kustomization instead of HelmRelease:

```yaml
# Using GitRepository to pull the official gateway-api repo
kind: GitRepository
spec:
  url: https://github.com/kubernetes-sigs/gateway-api.git
  ref:
    branch: main

# Using Kustomization to apply CRDs from the repo
kind: Kustomization
spec:
  path: ./config/crd
```

## Verification

Verify the installation was successful:

```bash
# Check if the kustomization was applied
kubectl get kustomization gateway-api-crd -n flux-system

# List all Gateway API CRDs
kubectl get crds | grep gateway

# View detailed status
kubectl describe kustomization gateway-api-crd -n flux-system
```

Expected output should show all gateway API CRDs:
```
backendtlspolicies.gateway.networking.k8s.io
gatewayclasses.gateway.networking.k8s.io
gateways.gateway.networking.k8s.io
grpcroutes.gateway.networking.k8s.io
httproutes.gateway.networking.k8s.io
listenersets.gateway.networking.k8s.io
referencegrants.gateway.networking.k8s.io
tlsroutes.gateway.networking.k8s.io
```

## Usage Example

Once installed, you can create Gateway API resources:

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: GatewayClass
metadata:
  name: my-gateway-class
spec:
  controllerName: example.com/gateway-controller

---
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: my-gateway
spec:
  gatewayClassName: my-gateway-class
  listeners:
  - name: http
    protocol: HTTP
    port: 80

---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: my-route
spec:
  parentRefs:
  - name: my-gateway
  hostnames:
  - example.com
  rules:
  - matches:
    - path:
        type: PathPrefix
        value: /api
    backendRefs:
    - name: my-service
      port: 8080
```

## References

- [Official Gateway API Documentation](https://gateway-api.sigs.k8s.io/)
- [Gateway API GitHub Repository](https://github.com/kubernetes-sigs/gateway-api)
- [FluxCD Documentation](https://fluxcd.io/)

## Troubleshooting

**Kustomization not reconciling:**
```bash
kubectl describe kustomization gateway-api-crd -n flux-system
```

**Check GitRepository status:**
```bash
kubectl describe gitrepository gateway-api -n flux-system
```

**View FluxCD controller logs:**
```bash
kubectl logs -n flux-system deployment/kustomize-controller
kubectl logs -n flux-system deployment/source-controller
```
