#!/bin/bash

echo -e ""
date
sleep 3s && echo -e "###############################################################################################################"

echo -e "- Checking FluxCD Kustomizations to verify GitOps sync:"
kubectl get kustomizations -n flux-system
sleep 3s && echo -e "###############################################################################################################"

echo -e "- Checking deployed MCPServers in kagent namespace:"
kubectl get mcpserver -n kagent
sleep 3s && echo -e "###############################################################################################################"

echo -e "- Describing custom MCPServer (memory-mcp):"
kubectl describe mcpserver memory-mcp -n kagent
sleep 3s && echo -e "###############################################################################################################"

echo -e "- Checking active Pods for MCPServers:"
kubectl get pods -n kagent | grep -E 'mcp|inspector'
sleep 3s && echo -e "###############################################################################################################"

echo -e "- Checking logs of custom memory-mcp Pod:"
kubectl logs -l app.kubernetes.io/name=memory-mcp -n kagent --tail=10
sleep 3s && echo -e "###############################################################################################################"

echo -e "- Checking deployed Agents:"
kubectl get agents -n kagent
sleep 3s && echo -e "###############################################################################################################"

echo -e "- Checking mcp-inspector-ui Service ports (Lab-3 requirement):"
kubectl get svc mcp-inspector-ui -n kagent
sleep 3s && echo -e "###############################################################################################################"

echo -e "- Verifying mcp-inspector-ui is running with auth disabled:"
kubectl logs -l app=mcp-inspector-ui -n kagent --tail=15 | grep -E "Proxy server listening|Authentication is disabled"
sleep 3s && echo -e "###############################################################################################################"
