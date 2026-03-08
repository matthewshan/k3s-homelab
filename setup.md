
### 1. System Setup
```bash
# Essential packages (ZFS/NFS/iSCSI)
sudo apt update && sudo apt install -y \
  zfsutils-linux \
  nfs-kernel-server \
  cifs-utils \
  open-iscsi  # Optional but recommended

# Critical kernel modules for Cilium
sudo modprobe iptable_raw xt_socket
echo -e "xt_socket\niptable_raw" | sudo tee /etc/modules-load.d/cilium.conf
```

### 2. K3s Installation
```bash
# Customize these values!
export SETUP_NODEIP=192.168.10.202  # Your node IP
export SETUP_CLUSTERTOKEN=randomtokensecret1234  # Strong token

curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION="v1.32.2+k3s1" \
  INSTALL_K3S_EXEC="--node-ip $SETUP_NODEIP \
  --disable=flannel,local-storage,metrics-server,servicelb,traefik \
  --flannel-backend='none' \
  --disable-network-policy \
  --disable-cloud-controller \
  --disable-kube-proxy" \
  K3S_TOKEN=$SETUP_CLUSTERTOKEN \
  K3S_KUBECONFIG_MODE=644 sh -s -

# Configure kubectl access
mkdir -p $HOME/.kube && sudo cp -i /etc/rancher/k3s/k3s.yaml $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config && chmod 600 $HOME/.kube/config
```

### 3. Install Helm
```
sudo apt-get install curl gpg apt-transport-https --yes
curl -fsSL https://packages.buildkite.com/helm-linux/helm-debian/gpgkey | gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg > /dev/null
echo "deb [signed-by=/usr/share/keyrings/helm.gpg] https://packages.buildkite.com/helm-linux/helm-debian/any/ any main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
sudo apt-get update
sudo apt-get install helm
```


### 3. Networking Setup (Cilium)
```bash
# Install Cilium CLI
CILIUM_CLI_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/cilium-cli/main/stable.txt)
CLI_ARCH=amd64 && [ "$(uname -m)" = "aarch64" ] && CLI_ARCH=arm64
curl -L --fail --remote-name-all \
  https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/cilium-linux-${CLI_ARCH}.tar.gz{,.sha256sum}
sha256sum --check cilium-linux-${CLI_ARCH}.tar.gz.sha256sum
sudo tar xzvfC cilium-linux-${CLI_ARCH}.tar.gz /usr/local/bin
rm cilium-linux-${CLI_ARCH}.tar.gz*

# Helm install Cilium
helm repo add cilium https://helm.cilium.io && helm repo update
# helm install cilium cilium/cilium -n kube-system \
#   -f infrastructure/networking/cilium/values.yaml \
#   --version 1.17.3 \
#   --set operator.replicas=1

cilium install \
  --helm-set=ipam.mode=kubernetes \
  --helm-set=kubeProxyReplacement=true \
  --helm-set=securityContext.capabilities.ciliumAgent="{CHOWN,KILL,NET_ADMIN,NET_RAW,IPC_LOCK,SYS_ADMIN,SYS_RESOURCE,DAC_OVERRIDE,FOWNER,SETGID,SETUID}" \
  --helm-set=securityContext.capabilities.cleanCiliumState="{NET_ADMIN,SYS_ADMIN,SYS_RESOURCE}" \
  --helm-set=cgroup.autoMount.enabled=false \
  --helm-set=cgroup.hostRoot=/sys/fs/cgroup \
  --helm-set=l2announcements.enabled=true \
  --helm-set=externalIPs.enabled=true \
  --helm-set=devices=e+

# Validate installation
cilium status && cilium connectivity test

# Critical L2 Configuration Note:
# Before applying the CiliumL2AnnouncementPolicy, you MUST identify your correct network interface:

# 1. List all network interfaces:
ip a

# 2. Look for your main interface with an IP address matching your network
# Common interface names:
# - Ubuntu/Debian: enp1s0, ens18, eth0
# - macOS: en0
# - RPi: eth0
# The interface should show your node's IP address, for example:
#   enp1s0: <BROADCAST,MULTICAST,UP,LOWER_UP> ... inet 192.168.1.100/24

# 3. Make note of your interface name for the CiliumL2AnnouncementPolicy
# You'll need this when applying the infrastructure components via Argo CD

# DO NOT apply the policy here - it will be applied through Argo CD
# The policy file is located at: infrastructure/networking/cilium/l2policy.yaml
```

### 4. Setup Local PC to connect to Cluster

Get Connection Config
```
cat /etc/rancher/k3s/k3s.yaml
```

Copy output to whatever file kubectl uses to connect. Update IP Address to the node ip address

Then test locally with `kubectl get nodes`

### 5. ArgoCD

```
# Gateway API CRDs
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.2.0/standard-install.yaml
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.2.0/experimental-install.yaml
```