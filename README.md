# Comprehensive Guide to Setting Up OpenEBS Replicated Persistent Volumes with MetalLB and Istio on Kubernetes

This guide will walk you through the process of setting up a Kubernetes cluster enhanced with **OpenEBS** for replicated Persistent Volumes (PVs), **MetalLB** for load balancing, **Istio** for service mesh capabilities, and the **Metrics Server** and **Kubernetes Dashboard** for cluster monitoring. By following these steps, you'll achieve a robust, high-availability storage solution leveraging AWS EBS volumes, along with advanced networking features.

---

## Table of Contents

1. [Introduction](#1-introduction)
2. [Prerequisites](#2-prerequisites)
3. [Installing OpenEBS with Mayastor](#3-installing-openebs-with-mayastor)
4. [Deploying Metrics Server and Kubernetes Dashboard](#4-deploying-metrics-server-and-kubernetes-dashboard)
5. [Configuring MetalLB for Load Balancing](#5-configuring-metallb-for-load-balancing)
6. [Installing Istio Service Mesh](#6-installing-istio-service-mesh)
7. [Conclusion](#7-conclusion)
8. [References](#8-references)

---

## 1. Introduction

In this guide, I will walk through setting up a Kubernetes cluster with enhanced storage and networking capabilities. We will:

- **Install OpenEBS with Mayastor** for high-performance, replicated Persistent Volumes.
- **Deploy the Metrics Server and Kubernetes Dashboard** for real-time monitoring and management.
- **Configure MetalLB** to provide LoadBalancer services in a bare-metal environment.
- **Install Istio** to introduce advanced service mesh features like traffic management, security, and observability.

This setup is ideal for creating a robust, scalable, and highly available Kubernetes environment, suitable for running stateful applications that require reliable storage and advanced networking.

---

## 2. Prerequisites

Before we begin, ensure the following prerequisites are met:

- **Kubernetes Cluster**: Set up using the `Deploy-k8s-kubeadm-terraform-Ansible` repository. Please refer to the `README.md` file inside this folder for detailed instructions on creating and running the Terraform and Ansible scripts.

  ```
  Deploy-k8s-kubeadm-terraform-Ansible/
  ├── README.md
  ├── ansible/
  └── terraform/
  ```

- **Cluster Details**:
  - **One Control Plane Node**
  - **Three Worker Nodes**
  - **Ubuntu OS** installed on all nodes
  - **EBS Volumes** attached to each worker node (via Terraform)

- **Access to the Following Tools**:
  - `kubectl` configured to interact with the cluster
  - `helm` (version 3.7 or higher) installed on the control plane node
  - `openssl` installed for generating secrets

- **Network Configuration**: Ensure that the nodes can communicate with each other and that the necessary ports are open for Kubernetes components.

---

## 3. Installing OpenEBS with Mayastor

OpenEBS provides cloud-native storage for Kubernetes, and Mayastor offers high-performance storage engines. We'll install OpenEBS and configure Mayastor for replicated PVs.

### 3.1 Prepare Worker Nodes

Perform the following steps on **each worker node**.

#### 3.1.1 Verify Kernel Version and Modules

- **Check Kernel Version**:

  ```bash
  uname -r
  ```

  Ensure it's **5.13** or higher. If not, upgrade the kernel:

  ```bash
  sudo apt update -y
  sudo apt upgrade -y
  sudo reboot
  ```

- **Install `nvme_tcp` Kernel Module**:

  ```bash
  sudo apt update -y
  sudo apt install linux-modules-extra-$(uname -r) -y
  sudo modprobe nvme_tcp
  echo "nvme_tcp" | sudo tee -a /etc/modules
  ```

- **Verify CPU Supports SSE4.2**:

  ```bash
  grep sse4_2 /proc/cpuinfo
  ```

- **Verify `ext4` Filesystem Support**:

  ```bash
  lsmod | grep ext4
  cat /proc/filesystems
  ```

  If not present, load it:

  ```bash
  sudo modprobe ext4
  ```

#### 3.1.2 Install Necessary Packages

```bash
sudo apt update -y
sudo apt install -y lsscsi nvme-cli
```

#### 3.1.3 Configure HugePages

HugePages are essential for high-performance storage operations.

```bash
echo 'vm.nr_hugepages=1024' | sudo tee -a /etc/sysctl.conf
sudo sysctl -p
sudo systemctl restart kubelet
```

Verify HugePages:

```bash
grep HugePages /proc/meminfo
```

Expected output:

```
HugePages_Total:    1024
HugePages_Free:     1024
```

### 3.2 Verify EBS Volumes on Worker Nodes

Ensure each worker node has an unformatted EBS volume attached.

- **List Block Devices**:

  ```bash
  lsblk
  ```

- **Check if the New Disk is Unformatted**:

  ```bash
  sudo fdisk -l /dev/nvme1n1
  ```

  There should be no valid partition table on the new disk.

**Repeat these steps for all worker nodes.**

### 3.3 Label Worker Nodes for OpenEBS

On the control plane node, label the worker nodes:

```bash
kubectl label node worker-node-1 openebs.io/engine=mayastor
kubectl label node worker-node-2 openebs.io/engine=mayastor
kubectl label node worker-node-3 openebs.io/engine=mayastor
```

### 3.4 Install Helm on Control Plane Node

Check if Helm is installed:

```bash
helm version --short
```

If not installed, run:

```bash
curl https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash
```

### 3.5 Install OpenEBS and Mayastor

#### 3.5.1 Add OpenEBS Helm Repository

```bash
helm repo add openebs https://openebs.github.io/charts
helm repo update
```

#### 3.5.2 Install OpenEBS

```bash
helm install openebs openebs/openebs --namespace openebs --create-namespace
```

Verify installation:

```bash
helm ls -n openebs
kubectl get pods -n openebs
```

All OpenEBS pods should be in the `Running` state.

#### 3.5.3 Install Mayastor

```bash
kubectl apply -f https://raw.githubusercontent.com/openebs/Mayastor/master/deploy/mayastor-operator.yaml
```

Verify Mayastor pods:

```bash
kubectl get pods -n mayastor
```

All Mayastor pods should be in the `Running` state.

### 3.6 Create DiskPools on Worker Nodes

On each worker node, find the disk link:

```bash
ls -l /dev/disk/by-id/ | grep nvme
```

Sample output:

```
lrwxrwxrwx 1 root root 13 Nov 25 16:42 nvme-Amazon_Elastic_Block_Store_vol083f7398414064f9b -> ../../nvme1n1
```

On the control plane node, create DiskPools using the disk IDs found:

```bash
# DiskPool for worker-node-1
cat <<EOF | kubectl apply -f -
apiVersion: openebs.io/v1beta2
kind: DiskPool
metadata:
  name: pool-on-node-1
  namespace: openebs
spec:
  node: worker-node-1
  disks:
    - uring:///dev/disk/by-id/<disk-id-worker-node-1>
EOF

# Repeat for worker-node-2 and worker-node-3 with their respective disk IDs
```

### 3.7 Verify DiskPools Creation

```bash
kubectl get diskpool -n openebs
```

The `STATE` should transition from `Creating` to `Healthy` once the DiskPools are ready.

### 3.8 Label DiskPools

Apply labels to DiskPools:

```bash
kubectl label diskpool pool-on-node-1 topology-key=topology-value -n openebs
kubectl label diskpool pool-on-node-2 topology-key=topology-value -n openebs
kubectl label diskpool pool-on-node-3 topology-key=topology-value -n openebs
```

Verify labels:

```bash
kubectl get diskpool -n openebs -o wide
```

Ensure that all DiskPools are in the `Healthy` state with available capacity.

### 3.9 Create StorageClass for Mayastor with Replication

```bash
cat <<EOF | kubectl create -f -
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: mayastor-3
parameters:
  protocol: nvmf
  repl: "3"
provisioner: io.openebs.csi-mayastor
EOF
```

Verify the StorageClass:

```bash
kubectl get storageclass
```

`mayastor-3` should be listed with the provisioner `io.openebs.csi-mayastor`.

### 3.10 Create PersistentVolumeClaim (PVC)

```bash
cat <<EOF | kubectl create -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: ms-volume-claim
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
  storageClassName: mayastor-3
EOF
```

Verify PVC status:

```bash
kubectl get pvc
```

Initially, `ms-volume-claim` may show as `Pending` while provisioning.

### 3.11 Deploy a Test Pod Using the PVC

Create a YAML file named `test-rep-pvc.yml`:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: fio
spec:
  nodeSelector:
    openebs.io/engine: mayastor
  volumes:
    - name: ms-volume
      persistentVolumeClaim:
        claimName: ms-volume-claim
  containers:
    - name: fio
      image: nixery.dev/shell/fio
      args:
        - sleep
        - "1000000"
      volumeMounts:
        - mountPath: "/volume"
          name: ms-volume
```

Apply the pod configuration:

```bash
kubectl apply -f test-rep-pvc.yml
```

Verify the pod is running:

```bash
kubectl get pods
```

Ensure the `fio` pod is in the `Running` state.

### 3.12 Verify the Setup

Check PVC binding:

```bash
kubectl get pvc
```

`ms-volume-claim` should transition to `Bound`.

Describe the PVC:

```bash
kubectl describe pvc ms-volume-claim
```

Run an I/O benchmark inside the `fio` pod:

```bash
kubectl exec -it fio -- fio --name=benchtest --size=800m --filename=/volume/test --direct=1 --rw=randrw --ioengine=libaio --bs=4k --iodepth=16 --numjobs=8 --time_based --runtime=60
```

Interpret the output to assess storage performance.

---

## 4. Deploying Metrics Server and Kubernetes Dashboard

### 4.1 Install Metrics Server

```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
```

Edit the Metrics Server deployment:

```bash
kubectl edit deploy -n kube-system metrics-server
```

Add the following argument under `spec.template.spec.containers.args`:

```yaml
- --kubelet-insecure-tls
```

Verify Metrics Server is running:

```bash
kubectl get pods -n kube-system
```

Test Metrics Server:

```bash
kubectl top nodes
```

### 4.2 Install Kubernetes Dashboard

```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.2.0/aio/deploy/recommended.yaml
```

Verify installation:

```bash
kubectl get pods -n kubernetes-dashboard
```

### 4.3 Create an Admin User

Create a Service Account:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: admin-user
  namespace: kubernetes-dashboard
EOF
```

Bind the Service Account to Cluster Admin Role:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: admin-user
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: admin-user
  namespace: kubernetes-dashboard
EOF
```

Generate a Bearer Token:

```bash
kubectl -n kubernetes-dashboard create token admin-user
```

### 4.4 Access the Dashboard

Start the proxy:

```bash
kubectl proxy
```

Access the dashboard at:

```
http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/
```

Log in using the token generated earlier.

---

## 5. Configuring MetalLB for Load Balancing

MetalLB provides a network load-balancer implementation for Kubernetes clusters that do not have built-in cloud provider support.

### 5.1 Clean Up Previous Installations (If Any)

If MetalLB was previously installed, remove it completely:

```bash
kubectl delete namespace metallb-system --grace-period=0 --force
kubectl delete crd $(kubectl get crd | grep metallb | awk '{print $1}')
kubectl delete validatingwebhookconfiguration metallb-webhook-configuration
```

Ensure all MetalLB pods are deleted:

```bash
kubectl get pods --all-namespaces | grep metallb
```

Delete any lingering pods.

### 5.2 Install MetalLB

Apply the MetalLB manifest:

```bash
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.14.8/config/manifests/metallb-native.yaml
```

Create the `memberlist` secret:

```bash
kubectl create secret generic -n metallb-system memberlist --from-literal=secretkey="$(openssl rand -base64 128)"
```

### 5.3 Configure MetalLB Address Pool

Create `metallb-ipaddresspool.yml` in the `metalLB` directory:

```yaml
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: default-addresspool
  namespace: metallb-system
spec:
  addresses:
  - 10.0.1.200-10.0.1.210  # Update this range to match your network
```

Apply the configuration:

```bash
kubectl apply -f metalLB/metallb-ipaddresspool.yml
```

Create `metallb-l2advertisement.yml`:

```yaml
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: default-l2advertisement
  namespace: metallb-system
spec:
  ipAddressPools:
  - default-addresspool
```

Apply the configuration:

```bash
kubectl apply -f metalLB/metallb-l2advertisement.yml
```

### 5.4 Verify MetalLB Installation

Check MetalLB pods:

```bash
kubectl get pods -n metallb-system
```

Test MetalLB with a sample service:

```bash
kubectl create deployment nginx-test --image=nginx
kubectl expose deployment nginx-test --port=80 --type=LoadBalancer
kubectl get svc nginx-test
```

Access the service via the assigned external IP:

```bash
curl http://<EXTERNAL-IP>
```

---

## 6. Installing Istio Service Mesh

Istio enhances the Kubernetes cluster with service mesh capabilities.

### 6.1 Download and Install Istio

Navigate to the `istio` directory and download Istio:

```bash
cd isito
curl -L https://istio.io/downloadIstio | sh -
cd istio-1.24.0
export PATH=$PWD/bin:$PATH
```

Install Istio:

```bash
istioctl install --set profile=default -y
kubectl get pods -n istio-system
```

All Istio pods should be in the `Running` state.

### 6.2 Expose Istio Ingress Gateway

Create `istio-ingressgateway.yaml`:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: istio-ingressgateway
  namespace: istio-system
spec:
  type: LoadBalancer
  selector:
    istio: ingressgateway
  ports:
  - name: http
    port: 80
    targetPort: 8080
  - name: https
    port: 443
    targetPort: 8443
```

Apply the configuration:

```bash
kubectl apply -f istio-1.24.0/samples/istio-ingressgateway.yaml
```

### 6.3 Deploy a Sample Application

Deploy the Bookinfo application:

```bash
kubectl apply -f istio-1.24.0/samples/bookinfo/platform/kube/bookinfo.yaml
```

Create Istio Gateway and VirtualService:

```bash
kubectl apply -f istio-1.24.0/samples/bookinfo/networking/bookinfo-gateway.yaml
```

### 6.4 Access the Application

Get the external IP of the Istio ingress gateway:

```bash
kubectl get svc istio-ingressgateway -n istio-system
```

Access the application at:

```
http://<EXTERNAL-IP>/productpage
```

You should see the Bookinfo application interface.

---

## 7. Conclusion

By following this guide, we have successfully:

- **Installed and configured OpenEBS with Mayastor** to provide high-performance, replicated Persistent Volumes.
- **Deployed the Metrics Server and Kubernetes Dashboard** for monitoring and managing the cluster.
- **Configured MetalLB** to enable LoadBalancer services in our bare-metal Kubernetes cluster.
- **Installed Istio** to provide advanced service mesh capabilities, enhancing traffic management and observability.

Our Kubernetes cluster is now equipped with robust storage solutions, monitoring tools, load balancing, and service mesh features, ready to support scalable and resilient applications.

---

## 8. References

- [OpenEBS Official Documentation](https://openebs.io/docs/)
- [Mayastor Official Documentation](https://mayastor.io/docs/)
- [Kubernetes Official Documentation](https://kubernetes.io/docs/home/)
- [MetalLB Official Documentation](https://metallb.universe.tf/)
- [Istio Official Documentation](https://istio.io/latest/docs/)
- [Helm Official Documentation](https://helm.sh/docs/)
- [Metrics Server GitHub](https://github.com/kubernetes-sigs/metrics-server)
- [Kubernetes Dashboard GitHub](https://github.com/kubernetes/dashboard)
- [Service Mesh Setup Guide](https://makeoptim.com/en/service-mesh/kubeadm-kubernetes-istio-setup/#metric-serverl)
