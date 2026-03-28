# Guide: Using MCP Inspector with MCP Server in Kubernetes

This guide explains how to connect using `npx @modelcontextprotocol/inspector@0.21.1` to our custom-created MCP Server (`memory-mcp`), which is already running in the cluster via FluxCD. This fulfills the 2nd part (Development) of Lab 3 ("Familiarize yourself with using the inspector... Screenshot with description").

## Step 1: Running the inspector locally on your computer

The MCP server is already running inside a Pod in the `kagent` namespace and listening for messages on standard input/output (stdio).
Run the inspector in your terminal:

```bash
npx @modelcontextprotocol/inspector@0.21.1
```

## Step 2: Configuring the connection (Transport)

Open your browser and navigate to `http://localhost:5173`.
In the connection window (Connect to MCP Server):

1. Open another terminal and find the exact name of the running pod:
   ```bash
   kubectl get pods -n kagent | grep memory-mcp
   ```
2. In the inspector, choose **Transport Type**: `Command`
3. In the **Command** field, enter: `kubectl`
4. Copy the pod name and add the following arguments in the **Arguments** field (each argument separately, if the inspector UI requires it, or as a single string):
   `exec`, `-i`, `-n`, `kagent`, `<YOUR_POD_NAME>`, `--`, `npx`, `-y`, `@modelcontextprotocol/server-memory`

*Note: The Inspector will execute `kubectl exec` and connect to the `stdio` of your MCP application directly in the cluster!*

## Step 3: Testing and creating a Screenshot (** Screenshot with description)

After clicking "Connect", the inspector will establish a connection with the memory server inside Kubernetes.
You will see available resources (Resources), prompts (Prompts), and tools (Tools, e.g., `read_graph`, `knows`, `add_tags`).

Take a screenshot of the working inspector interface — this is the **"Screenshot with description"** for your lab assignment.

**Description for the screenshot in your report:** 
*"The screenshot demonstrates a successful connection of `npx @modelcontextprotocol/inspector@0.21.1` to the Custom MCP App (memory-mcp), deployed in Kubernetes using GitOps (FluxCD). The connection is configured via stdio transport using the `kubectl exec` command directly into the active memory server pod."*
