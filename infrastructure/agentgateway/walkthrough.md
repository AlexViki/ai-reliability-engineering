# Walkthrough: Basic Agentic Infrastructure Deployment

We have successfully deployed the **Basic Agentic Infrastructure** using FluxCD, including the `agentgateway` and `kagent` components with a functional model routing through the gateway.

## 🚀 Accomplishments

### 1. Unified Deployment via FluxCD
All components are managed declaratively in the `ai-reliability-engineering` repository:
- **agentgateway**: Specialized Gateway API controller for LLM traffic.
- **kagent**: Kubernetes-native agent framework.

### 2. Model Routing through Gateway
We configured an end-to-end routing path for LLM requests:
- **AgentgatewayBackend**: Defined a static backend for `generativelanguage.googleapis.com`.
- **HTTPRoute**: Established a proxy route (`gemini.agentgateway.local`) in the `agentgateway-system` namespace.
- **kgateway-agent**: Enabled in the `kagent` namespace to tunnel model requests through the gateway.

### 3. Gemini 2.5 Flash Integration
The `kagent-controller` is configured to use **Gemini 2.5 Flash** as its default LLM provider, with secrets managed via the `gemini-api-keys` K8s secret.

## 🧪 Verification Results

### Cluster Resources
Verified that all components are running and accepted by the cluster:

```bash
# Gateway Resources
$ kubectl get agentgatewaybackends,httproutes -n agentgateway-system
NAME                                                 ACCEPTED   AGE
agentgatewaybackend.agentgateway.dev/google-gemini   True       2m

NAME                                               HOSTNAMES                       AGE
httproute.gateway.networking.k8s.io/gemini-route   ["gemini.agentgateway.local"]   2m

# Kagent Pods
$ kubectl get pods -n kagent
NAME                                READY   STATUS    RESTARTS   AGE
kagent-controller-9858fb4c6-nmcc2   1/1     Running   0          4d
kgateway-agent-68989b877-hk6r8      1/1     Running   0          5m
```

### Agent Connectivity
- `kgateway-agent` logs confirm successful startup and serving of the agent card.
- `kagent-controller` health checks are passing (200 OK).

## 🛠️ Maintenance & Operations
- **Updating Models**: Modify the `providers.gemini` section in [infrastructure/kagent/helm-kagent.yaml](file:///home/alex/ai-reliability-engineering/infrastructure/kagent/helm-kagent.yaml).
- **Scaling**: Adjust `resources` and `replicas` in the respective `HelmRelease` files.
- **GitOps**: Any change pushed to the repository will be automatically reconciled by FluxCD.
