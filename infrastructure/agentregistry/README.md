# Agent Registry (AI Inventory)

This directory contains the GitOps manifests needed to deploy the [AgentRegistry](https://github.com/agentregistry-dev/agentregistry) platform. Within our AI Reliability Engineering environment, `agentregistry` acts as a centralized AI Inventory, automatically discovering and cataloging Model Context Protocol (MCP) servers, declarative agents, and AI model configurations.

## Architecture & Configuration

Starting from Helm chart version `0.3.2`, AgentRegistry no longer ships with a bundled PostgreSQL database and explicitly requires an external PostgreSQL instance with `pgvector` enabled for semantic vector search functionalities.

Our deployment is separated into carefully structured GitOps components:
1. `namespace.yaml` - defines the `agentregistry` isolated workspace.
2. `postgres.yaml` - provisions a standalone `pgvector:pg15` database for the registry backend.
3. `repository.yaml` - registers the `agentregistry-dev` OCI registry inside FluxCD.
4. `helm-agentregistry.yaml` - declares the main `HelmRelease` that connects the registry application with the database and deploys it to the cluster.

These configurations are tied together at the root level via `infrastructure/kustomization.yaml`.

## Installation 

Since this module is fully tracked using GitOps (FluxCD), installation is fully declarative.

To apply changes immediately (instead of waiting for the automatic FluxCD reconciliation period), run:
```bash
git add .
git commit -m "update agentregistry components"
git push
kubectl apply -k infrastructure/
```

## Verification & Testing

To confirm that the registry was deployed properly and is successfully indexing AI components across the Kubernetes cluster, use the following commands.

### 1. Check Component Health
Verify that the `pgvector` database and the `agentregistry` application are both running:
```bash
kubectl get pods -n agentregistry
```
You should see output similar to:
```text
NAME                               READY   STATUS    RESTARTS   AGE
agentregistry-6c4f4df9f9-244mp     1/1     Running   0          ...
postgres-vector-77984f5978-wdcwf   1/1     Running   0          ...
```

### 2. Verify AI Resource Discovery
AgentRegistry constantly monitors the environment for known identifiers such as `Agent`, `MCPServer`, and `ModelConfig`. You can query what the cluster sees natively:
```bash
kubectl get agents,mcpservers,modelconfigs -A
```

### 3. Accessing the Agent Registry UI
The registry comes with a built-in user interface to graphically monitor all deployed and available AI resources. Open a port-forward stream to the service:

```bash
kubectl port-forward svc/agentregistry -n agentregistry 12121:12121
```

Once the tunnel is active, open your browser and navigate to:
**http://localhost:12121**

From the main dashboard, select the **Deployed** tab to review the `Agents` and `MCP Servers` running in your system.
