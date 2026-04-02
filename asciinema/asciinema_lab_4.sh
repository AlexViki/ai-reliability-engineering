#!/bin/bash

echo -e ""
date
sleep 3s && echo -e "###############################################################################################################"

echo -e "- Checking FluxCD HelmReleases to verify AgentRegistry GitOps sync:"
kubectl get helmreleases -n agentregistry
sleep 3s && echo -e "###############################################################################################################"

echo -e "- Checking deployed Inventory (AgentRegistry) Pods:"
kubectl get pods -n agentregistry
sleep 3s && echo -e "###############################################################################################################"

echo -e "- Checking deployed Custom A2A Agent Pod in kagent namespace:"
kubectl get pods -n kagent -l app=a2a-custom-agent
sleep 3s && echo -e "###############################################################################################################"

echo -e "- Checking A2A Agent Service:"
kubectl get svc a2a-custom-agent -n kagent
sleep 3s && echo -e "###############################################################################################################"

echo -e "- Checking Agent Card payload deployed inside the cluster (app.py):"
kubectl get configmap a2a-agent-config -n kagent -o jsonpath='{.data.app\.py}' | head -n 30
echo "..."
echo ""
sleep 3s && echo -e "###############################################################################################################"

echo -e "- Retrieving all discovered AI Resources in the Cluster (Inventory via Native APIs):"
kubectl get agents,mcpservers,modelconfigs -A
sleep 3s && echo -e "###############################################################################################################"

echo -e "- Port-forwarding to A2A Agent Service:"
kubectl port-forward svc/a2a-custom-agent -n kagent 8080:8080 &> /dev/null &
sleep 3s && echo -e "###############################################################################################################"

echo -e "- Checking A2A Agent Service:"
curl -s http://localhost:8080/.well-known/agent-card.json | jq
sleep 3s && echo -e "###############################################################################################################"
