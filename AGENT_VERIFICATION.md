# Agent Verification Guide

This guide demonstrates how to verify that built-in agents are deployed and functioning correctly in the Kagent framework.

## Prerequisites

- Kubernetes cluster with Kagent v0.7.23 deployed
- kubectl configured to access your cluster
- Port-forward access to Kagent controller API (port 8083)

## Quick Status Check

### 1. Verify All Agents Are Deployed

List all agents in the cluster:

```bash
kubectl get agent -n kagent-system -o wide
```

Expected output should show all 10 built-in agents with READY and ACCEPTED status:

```
NAME                         TYPE           READY   ACCEPTED
argo-rollouts-conversion-agent   Declarative   True    True
cilium-debug-agent              Declarative   False   False
cilium-manager-agent            Declarative   False   False
cilium-policy-agent             Declarative   False   False
helm-agent                      Declarative   False   False
istio-agent                     Declarative   False   False
k8s-agent                       Declarative   False   False
kgateway-agent                  Declarative   False   False
observability-agent             Declarative   False   False
promql-agent                    Declarative   True    True
```

### 2. Check Specific Agent Status

To check the status of a specific agent (e.g., promql-agent):

```bash
kubectl get agent promql-agent -n kagent-system -o wide
```

Output:
```
NAME           TYPE           READY   ACCEPTED
promql-agent   Declarative   True    True
```

### 3. View Agent Capabilities

To see what an agent can do, inspect its definition:

```bash
kubectl describe agent promql-agent -n kagent-system
```

This shows:
- **Skills**: What the agent can perform
- **System Message**: Detailed instructions and capabilities
- **Resources**: CPU/Memory allocation
- **Status Conditions**: Deployment readiness

Example for promql-agent skills:
```
Skills:
  Generate PromQL Query
  Explain or Debug PromQL Query
  PromQL Concepts and Best Practices
```

## Kagent API Access

### 1. Set Up Port-Forward

Access the Kagent controller API locally:

```bash
kubectl port-forward -n kagent-system svc/kagent-system-kagent-controller 8083:8083
```

Expected output:
```
Forwarding from 127.0.0.1:8083 -> 8083
Forwarding from [::1]:8083 -> 8083
Listening on both 8083
```

### 2. Check API Health

```bash
curl -s http://localhost:8083/health | jq .
```

Expected response:
```json
{
  "error": false,
  "data": {
    "status": "OK"
  },
  "message": "OK"
}
```

### 3. List All Agents via API

```bash
curl -s http://localhost:8083/api/agents | python3 << 'EOF'
import json, sys
data = json.load(sys.stdin)
print(f"Total agents: {len(data['data'])}")
print("\nAvailable agents:")
for agent in sorted([a['agent']['metadata']['name'] for a in data['data']]):
    print(f"  - {agent}")
EOF
```

### 4. Retrieve Agent Details via API

```bash
curl -s http://localhost:8083/api/agents/kagent-system/promql-agent | python3 << 'EOF'
import json, sys
data = json.load(sys.stdin)
agent_data = data['data']['agent']
print(f"Agent: {agent_data['metadata']['name']}")
print(f"Namespace: {agent_data['metadata']['namespace']}")
print(f"Ready: {agent_data['status']['conditions'][1]['status']}")
print(f"Accepted: {agent_data['status']['conditions'][0]['status']}")
print(f"\nSkills:")
for skill in agent_data['spec']['declarative']['a2aConfig']['skills']:
    print(f"  - {skill['name']}")
EOF
```

## Agent Functionality Testing

### 1. Test promql-agent (PromQL Query Generator)

The promql-agent specializes in generating Prometheus Query Language (PromQL) queries from natural language descriptions.

**Example Use Cases:**
- "Generate a PromQL query to show CPU usage percentage"
- "Create a query for HTTP error rate"
- "What's the 95th percentile latency query?"

### 2. Test k8s-agent (Kubernetes Operations)

The k8s-agent handles Kubernetes resource management and troubleshooting.

**Example Use Cases:**
- "Get all pods in the default namespace"
- "Describe the agentgateway-gateway service"
- "Fix deployment issues in my cluster"

### 3. Test helm-agent (Helm Package Management)

The helm-agent manages Helm releases and charts.

**Example Use Cases:**
- "List all Helm releases in the cluster"
- "Upgrade the kagent release to the latest version"
- "What Helm charts are available from the agentgateway repository?"

## Verification Checklist

Run this comprehensive verification script:

```bash
#!/bin/bash

echo "=== Agent Verification Checklist ==="
echo ""

# Check 1: Agents deployed
echo "✓ Checking deployed agents..."
AGENT_COUNT=$(kubectl get agent -n kagent-system --no-headers | wc -l)
echo "  Found $AGENT_COUNT agents"
echo ""

# Check 2: Ready agents
echo "✓ Checking ready agents..."
READY_COUNT=$(kubectl get agent -n kagent-system --no-headers | grep "True.*True" | wc -l)
echo "  $READY_COUNT agents READY and ACCEPTED"
echo ""

# Check 3: Agent pods
echo "✓ Checking agent pods..."
POD_COUNT=$(kubectl get pods -n kagent-system --no-headers | grep agent | wc -l)
echo "  Found $POD_COUNT agent pods"
echo ""

# Check 4: Kagent API
echo "✓ Checking Kagent API..."
API_STATUS=$(curl -s http://localhost:8083/health | python3 -c "import json,sys; print(json.load(sys.stdin)['data']['status'])" 2>/dev/null)
if [ "$API_STATUS" == "OK" ]; then
    echo "  API: $API_STATUS"
else
    echo "  API: UNREACHABLE (ensure port-forward is active)"
fi
echo ""

# Check 5: Agent accessibility via API
echo "✓ Checking agent API accessibility..."
API_AGENTS=$(curl -s http://localhost:8083/api/agents | python3 -c "import json,sys; print(len(json.load(sys.stdin)['data']))" 2>/dev/null)
if [ ! -z "$API_AGENTS" ]; then
    echo "  API reports $API_AGENTS agents"
else
    echo "  API: Could not retrieve agents"
fi
echo ""

echo "=== Verification Complete ==="
```

Save this as `verify-agents.sh`, make it executable, and run:

```bash
chmod +x verify-agents.sh
./verify-agents.sh
```

## Troubleshooting

### Agent Not Showing as READY

If an agent shows `READY: False`:

```bash
kubectl describe agent <agent-name> -n kagent-system
```

Look for `DeploymentNotFound` or `ReconcileFailed` in the status conditions.

**Solution**: Ensure the agent deployment exists:

```bash
kubectl get deployment -n kagent-system | grep <agent-name>
```

### API Port-Forward Not Working

If `curl http://localhost:8083/health` fails:

1. Check if port-forward is still active:
   ```bash
   ps aux | grep port-forward
   ```

2. Restart port-forward:
   ```bash
   kubectl port-forward -n kagent-system svc/kagent-system-kagent-controller 8083:8083
   ```

3. Verify Kagent controller pod is running:
   ```bash
   kubectl get pods -n kagent-system | grep controller
   ```

### Agent Not Responding to Queries

If the agent API responds but agent doesn't process queries:

1. Check agent pod logs:
   ```bash
   kubectl logs -n kagent-system deployment/<agent-name> --tail=50
   ```

2. Verify model configuration:
   ```bash
   kubectl get modelconfig -n kagent-system
   ```

3. Check if LLM API key is configured:
   ```bash
   kubectl get secret -n kagent-system | grep -i gemini
   ```

## Agent Deployment Details

All agents are deployed as Kubernetes Deployments in the `kagent-system` namespace.

**Common deployment characteristics:**

- **Resource Requests**: 100m CPU, 256Mi Memory
- **Resource Limits**: 1000m CPU, 1Gi Memory
- **Model Provider**: Gemini (2.0-flash-lite)
- **Framework**: MCP (Model Context Protocol)

## Next Steps

After verifying agents are working:

1. **Test Agent Interactions**: Use the Kagent UI (port 8080) to interact with agents
2. **Monitor Agent Usage**: Check Kagent controller logs for agent execution
3. **Integrate with Applications**: Build custom workflows using agent APIs
4. **Scale Usage**: Deploy additional agents or create custom agents as needed

## Additional Resources

- [Kagent Documentation](https://kagent.dev)
- [Agent Framework Reference](https://kagent.dev/docs/agents)
- [Kubernetes Gateway API](https://gateway-api.sigs.k8s.io/)
- [Model Context Protocol](https://modelcontextprotocol.io/)
