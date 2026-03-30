# Guide: Using MCP Inspector with MCP Server in Kubernetes

This guide explains how to connect to our custom-created MCP Server (`memory-mcp`) using the in-cluster MCP Inspector UI. This fulfills the 2nd part (Development) of Lab 3 ("Familiarize yourself with using the inspector... Screenshot with description").

## Step 1: Port-forwarding the Inspector UI from the cluster

The MCP Inspector has been deployed into the cluster as a service to avoid local environment mismatches.
To access it, you need to port-forward both the Web UI port (`6274`) and the WebSocket Proxy port (`6277`).

Run the following command in your terminal:
```bash
kubectl port-forward svc/mcp-inspector-ui -n kagent 6274:6274 6277:6277
```

## Step 2: Configuring the connection (Transport)

1. Open your browser and navigate **strictly** to `http://localhost:6274` *(using `127.0.0.1` will cause a CORS proxy error)*.
2. Open another terminal and find the exact name of your running memory pod:
   ```bash
   kubectl get pods -n kagent | grep memory-mcp
   ```
   *(Ensure you copy the entire name uniquely, e.g., `memory-mcp-5f69dc5c8d-x5j9m` — do not miss the last letter!)*
3. In the inspector UI, set **Transport Type** to `STDIO`.
4. In the **Command** field, enter: `kubectl`
5. In the **Arguments** field, add the following arguments. **Important:** Add each argument *separately* (press `Enter` after each word to create a chip/tag) or provide them as a JSON array without any backticks or rogue commas:

   `exec`
   `-i`
   `-n`
   `kagent`
   `<YOUR_POD_NAME>`
   `--`
   `npx`
   `-y`
   `@modelcontextprotocol/server-memory`

*Note: The Inspector will execute `kubectl exec` from within the pod and directly connect to the `stdio` of your memory application in the `kagent` namespace!*

## Step 3: Testing and creating a Screenshot

After clicking "Connect", the inspector proxy will establish a stable WebSocket connection with the memory server inside Kubernetes.
You will see available resources, prompts, and tools (e.g., `create_entities`, `create_relations`, `add_observations`).

Take a screenshot of the working inspector interface showing the "Connected" state and the Tools tab — this is the **"Screenshot with description"** for your lab assignment.

**Description for the screenshot in your report:** 
*"The screenshot demonstrates a successful connection using the in-cluster MCP Inspector proxy to the Custom MCP App (memory-mcp), deployed in Kubernetes using GitOps (FluxCD). The connection is configured via stdio transport using the `kubectl exec` command directly into the active memory server pod."*
