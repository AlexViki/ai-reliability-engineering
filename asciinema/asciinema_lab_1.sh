#!/bin/bash

echo -e ""
date
sleep 3s && echo -e "###############################################################################################################"

echo -e "- HelmRepository, OCIRepository:"
kubectl get helmrepository,ocirepository -A
sleep 3s && echo -e "###############################################################################################################"

echo -e "- HelmRelease:"
kubectl get helmrelease -A
sleep 3s && echo -e "###############################################################################################################"

echo -e "- CRDs:"
kubectl get crd
sleep 3s && echo -e "###############################################################################################################"

echo -e "- Pods in flux-system namespace:"
kubectl get pods --namespace=flux-system
sleep 3s && echo -e "###############################################################################################################"

echo -e "- Pods in agentgateway-system namespace:" 
kubectl get pods --namespace=agentgateway-system
sleep 3s && echo -e "###############################################################################################################"

echo -e "- Pods in kagent namespace:"
kubectl get pods --namespace=kagent
sleep 3s && echo -e "###############################################################################################################"

echo -e "- Secrets in kagent namespace:"
kubectl get secret gemini-api-keys --namespace=kagent
sleep 3s && echo -e "###############################################################################################################"

echo -e "- ModelConfig in kagent namespace:"
kubectl get ModelConfig --namespace=kagent
sleep 3s && echo -e "###############################################################################################################"

echo -e "- ModelConfig default-model-config in kagent namespace:"
kubectl describe ModelConfig default-model-config --namespace=kagent
sleep 3s && echo -e "###############################################################################################################"
kubectl get ModelConfig default-model-config --namespace=kagent -o jsonpath='{.spec}'
sleep 3s && echo -e "###############################################################################################################"

echo -e "- HTTPRoute in agentgateway-system namespace:"
kubectl get HTTPRoute --namespace=agentgateway-system
sleep 3s && echo -e "###############################################################################################################"

echo -e "- HTTPRoute gemini-route in agentgateway-system namespace:"
kubectl describe HTTPRoute gemini-route --namespace=agentgateway-system
sleep 3s && echo -e "###############################################################################################################"

