# Lab 4: A2A Protocol, Custom Agents, and AI Inventory

This document outlines the successful implementation of Lab 4 for the AI Reliability Engineering course. The lab focused on understanding the Agent-to-Agent (A2A) protocol, creating a custom AI agent that exposes an Agent Card, and deploying an AI Inventory (AgentRegistry) system to discover active AI resources in the cluster.

## 1. Development: Custom A2A Agent

### Overview
In accordance with the A2A specification (a2a-protocol.org), an AI agent announces its capabilities, identity, and interface details using an **Agent Card**. This card MUST be discoverable over a standard endpoint known as the **Well-Known URI** (`/.well-known/agent-card.json`).

### Implementation & Deployment
We implemented a lightweight, custom A2A Agent using Python's built-in `http.server`, which dynamically serves the Agent Card. The implementation follows standard GitLessOps / GitOps patterns using FluxCD.

- **Source Code**: Python server injected via Kubernetes `ConfigMap`.
- **Runtime Environment**: Minimal `python:3.11-alpine` container inside a Kubernetes `Deployment`.
- **Availability**: Exposed internally via a Kubernetes `Service` within the `kagent` namespace.

**Agent Card Example Served:**
```json
{
  "name": "Custom-Lab4-Agent",
  "description": "A2A Agent created for Lab 4",
  "icon_url": "https://a2a-protocol.org/icon.png",
  "version": "1.0.0",
  "supported_interfaces": [
    {
      "url": "http://a2a-custom-agent.kagent.svc.cluster.local:8080/protocol",
      "protocol": "HTTP"
    }
  ],
  "capabilities": {
    "streaming": false
  },
  "default_input_modes": ["text/plain"],
  "default_output_modes": ["text/plain"],
  "skills": [
    {
      "id": "echo-skill",
      "name": "Echo Skill",
      "description": "Echoes back the input",
      "input_modes": ["text/plain"],
      "output_modes": ["text/plain"]
    }
  ]
}
```

The server is available at `http://a2a-custom-agent:8080/.well-known/agent-card.json` and successfully answers GET requests with the above JSON structure.

---

## 2. Infrastructure: Deploying Inventory (Agent Registry)

To obtain a centralized view of AI components within the cluster, we deployed **AgentRegistry** (AI Inventory), an open-source platform that enables the discovery and management of deployed MCP servers, models, and AI agents.

### Deployment Process
1. **Database Backend**: Beginning with version `0.3.2`, AgentRegistry dropped bundled PostgreSQL support in favor of an external `pgvector` requirement. We deployed an independent `pgvector:pg15` database in the `agentregistry` namespace to fulfill semantic search constraints.
2. **Helm Installation**: We used the OCI Helm artifact directly from the developer's registry:
   ```bash
   helm install agentregistry oci://ghcr.io/agentregistry-dev/agentregistry/charts/agentregistry \
     -n agentregistry \
     --create-namespace \
     --set database.postgres.url="..." \
     --set database.postgres.vectorEnabled=true
   ```
3. **Agent Discovery**: While previous iterations of AgentRegistry relied heavily on the `DiscoveryConfig` CRD, the cluster APIs successfully index and keep track of running components via Kagent definitions.

---

## 3. Discovered AI Resources

Through the Kubernetes Kagent APIs and internal AI registry tracking, the following AI resources are currently operating within the cluster:

### 🤖 Active Agents
| Name | Type | Runtime | State |
| :--- | :--- | :--- | :--- |
| `k8s-agent` | Declarative | Python | Accepted & Ready |
| `kgateway-agent` | Declarative | Python | Accepted & Ready |
| `sre-assistant`| Declarative | Python | Accepted & Ready |

### 🔌 Deployed MCP Servers
| Name | Status | Uptime |
| :--- | :--- | :--- |
| `k8s-inspector` | Ready | > 7 days |
| `memory-mcp` | Ready | > 5 days |

### 🧠 Configured Models
| Configuration Name | Provider | Underlying Model |
| :--- | :--- | :--- |
| `default-model-config` | Gemini | `gemini-2.5-flash` |

---
**Summary:** The infrastructure perfectly fulfills the requirements of Lab 4. The custom A2A agent broadcasts its capabilities cleanly via the standardized protocol, and the AgentRegistry setup provides transparency and discoverability for all AI components inside the cluster.
