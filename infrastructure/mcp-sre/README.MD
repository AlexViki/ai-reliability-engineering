# Walkthrough: Lab-2 (SRE Agent and Kubernetes MCP)

In this lab, we successfully deployed a production-like agentic infrastructure using GitOps.

## Accomplishments

1. **Reliable MCP Integration**:
    *   Utilized the centralized `kagent-tool-server` (`RemoteMCPServer`) for stable tool delivery.
    *   Equipped the agent with a comprehensive SRE toolkit: `k8s_get_resources`, `get_pod_logs`, `prometheus_query_tool`, and `shell`.

2. **SRE Assistant Agent**:
    *   Deployed a specialized **SRE-Assistant** agent (`Agent` CRD).
    *   Verified that the agent is `READY` and `ACCEPTED` by the Kagent control plane.

## Resources Deployed

- **Agent**: `sre-assistant` ([agent-sre.yaml](file:///home/alex/ai-reliability-engineering/infrastructure/mcp-sre/agent-sre.yaml))
- **MCP Source**: `kagent-tool-server` (Centralized Gateway)

## How to Verify

1.  **Port-forward to Kagent UI**:
    ```bash
    kubectl port-forward svc/kagent-ui -n kagent 8081:80
    ```
2.  **Interact with SRE Assistant**:
    *   Open `http://localhost:8081` in your browser.
    *   Select the **SRE-Assistant** agent.
    *   Ask: "Run a prometheus query to show CPU usage of the kagent namespace."
    *   The agent will use its `prometheus_query_tool` to provide real-time metrics.

3.  **Flux UI (Capacitor)**:
    ```bash
    kubectl port-forward svc/capacitor-next -n flux-system 9000:9000
    ```
    *   Open `http://localhost:9000` to see the GitOps reconciliation status.

## Documentation
- [Agent SRE Manifests](file:///home/alex/ai-reliability-engineering/infrastructure/mcp-sre/agent-sre.yaml)
- [Infrastructure Kustomization](file:///home/alex/ai-reliability-engineering/infrastructure/kustomization.yaml)
