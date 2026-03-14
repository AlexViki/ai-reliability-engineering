# Phase 1 — Basic Kubernetes Infrastructure

This phase establishes a **local Kubernetes cluster** that will serve as the foundation for the Agentic AI infrastructure used in the lab environment.

The cluster is deployed on a **single-node Ubuntu VM** running inside **Hyper-V** and uses modern production-grade components such as **containerd**, **Cilium (eBPF networking)**, and **NGINX Ingress**.

---

# Environment

Host environment:

```
Hyper-V VM
OS: Ubuntu 22.04.5 LTS
CPU: 4 cores
RAM: 8 GB
Disk: 80 GB
```

Kubernetes version:

```
Kubernetes v1.34
```

---

# Cluster Architecture

The cluster uses the following stack:

```
Kubernetes
 ├─ containerd (container runtime)
 ├─ kubeadm (cluster bootstrap)
 ├─ kubelet
 ├─ kubectl
 ├─ Cilium (CNI networking / eBPF)
 ├─ CoreDNS
 ├─ Metrics Server
 └─ NGINX Ingress Controller
```

This configuration represents a **production-grade Kubernetes networking stack** suitable for local development and platform experiments.

---

# Step 1 — System Preparation

Update system packages:

```bash
sudo apt update
sudo apt upgrade -y
```

Disable swap (required by kubelet):

```bash
sudo swapoff -a
```

Kubernetes requirement:

> “The kubelet will not start if swap is enabled.”
> — Kubernetes installation guide

---

# Step 2 — Kernel Configuration

Enable required kernel modules:

```bash
sudo modprobe overlay
sudo modprobe br_netfilter
```

Persist modules:

```
/etc/modules-load.d/k8s.conf
```

```
overlay
br_netfilter
```

Configure networking:

```
/etc/sysctl.d/k8s.conf
```

```
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward = 1
```

Apply configuration:

```bash
sudo sysctl --system
```

---

# Step 3 — Install Container Runtime

Kubernetes requires a CRI compatible runtime.

Install containerd:

```bash
sudo apt install containerd -y
```

Generate configuration:

```bash
containerd config default | sudo tee /etc/containerd/config.toml
```

Enable systemd cgroups:

```
SystemdCgroup = true
```

Restart containerd:

```bash
sudo systemctl restart containerd
sudo systemctl enable containerd
```

---

# Step 4 — Install Kubernetes Components

Add Kubernetes repository:

```bash
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.34/deb/Release.key \
| sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
```

```
/etc/apt/sources.list.d/kubernetes.list
```

Install components:

```bash
sudo apt update
sudo apt install -y kubelet kubeadm kubectl
```

Lock versions:

```bash
sudo apt-mark hold kubelet kubeadm kubectl
```

---

# Step 5 — Initialize Kubernetes Cluster

Initialize control plane:

```bash
sudo kubeadm init --pod-network-cidr=10.244.0.0/16
```

Configure kubectl access:

```bash
mkdir -p $HOME/.kube
sudo cp /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

Allow scheduling on the control-plane node (single node cluster):

```bash
kubectl taint nodes --all node-role.kubernetes.io/control-plane-
```

---

# Step 6 — Install CNI (Cilium)

Cilium provides Kubernetes networking using **eBPF**.

> “Cilium uses eBPF to implement highly efficient networking, security, and load-balancing.”
> — Cilium documentation

Install CLI:

```bash
curl -L --remote-name https://github.com/cilium/cilium-cli/releases/latest/download/cilium-linux-amd64.tar.gz
tar xzvf cilium-linux-amd64.tar.gz
sudo mv cilium /usr/local/bin
```

Deploy Cilium:

```bash
cilium install
```

Verify installation:

```bash
cilium status
```

---

# Step 7 — Install Metrics Server

Metrics Server enables cluster resource metrics.

Required for:

```
kubectl top
autoscaling
monitoring
```

Install:

```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
```

Patch TLS option (for kubeadm clusters):

```bash
kubectl patch deployment metrics-server -n kube-system \
--type=json \
-p='[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}]'
```

---

# Step 8 — Install NGINX Ingress Controller

Ingress enables HTTP routing to services.

Install controller:

```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/cloud/deploy.yaml
```

Verify:

```bash
kubectl get pods -n ingress-nginx
```

Service type:

```
NodePort
```

Ingress access example:

```
http://NODE_IP:32157
```

---

# Step 9 — Networking Validation

Validate Pod-to-Pod communication.

Create test pods:

```bash
kubectl run pod1 --image=busybox:1.36 --restart=Never -- sleep 3600
kubectl run pod2 --image=busybox:1.36 --restart=Never -- sleep 3600
```

Check Pod IPs:

```bash
kubectl get pods -o wide
```

Example:

```
pod1 10.0.0.84
pod2 10.0.0.238
```

Test connectivity:

```bash
kubectl exec -it pod1 -- ping <pod2-ip>
```

Expected result:

```
0% packet loss
```

This confirms:

```
Pod → Pod networking works
Cilium datapath is operational
```

---

# Step 10 — Service and Ingress Validation

Deploy test application:

```
hashicorp/http-echo
```

Create Service and Ingress.

Test request:

```bash
curl -H "Host: hello.local" http://NODE_IP:32157
```

Expected response:

```
hello from kubernetes
```

This validates the full request path:

```
Client
 ↓
NodePort
 ↓
Ingress
 ↓
Service
 ↓
Pod
```

---

# Result of Phase 1

A fully functional local Kubernetes platform was deployed with:

```
Kubernetes v1.34
containerd runtime
Cilium eBPF networking
CoreDNS
Metrics Server
NGINX Ingress
```

All critical networking layers were validated:

```
Pod networking
Service networking
DNS resolution
Ingress routing
```

This cluster will serve as the **foundation for the Agentic Infrastructure deployed in Lab-1**.
