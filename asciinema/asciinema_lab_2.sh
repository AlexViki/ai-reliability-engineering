#!/bin/bash

echo -e ""
date
sleep 3s && echo -e "###############################################################################################################"

echo -e "Port forwarding to kagent-ui..."
nohup kubectl port-forward -n kagent svc/kagent-ui 8088:8080 &> /dev/null &
sleep 3s && echo -e "###############################################################################################################"

echo -e "Checking if kagent-ui is reachable..."
sleep 10s && curl localhost:8088 -I && pkill -f "kubectl port-forward"
sleep 3s && echo -e "###############################################################################################################"