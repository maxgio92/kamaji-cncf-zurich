# Replay the demo

### Requirements:
- `asciinema`

```shell
make replay
```

# Quickstart

## Setup the admin cluster

### Requirements

- `az` CLI
- `aws` CLI

We're going to setup the Kamaji admin cluster on AKS.

```shell
az group create --location westeurope --resource-group cncf-zurich
az aks create --resource-group cncf-zurich --name kamaji-cncf-zurich --enable-managed-identity
az aks get-credentials --admin --name kamaji-cncf-zurich --resource-group cncf-zurich -f admin.kubeconfig

export KUBECONFIG=admin.kubeconfig
```

## Install Kamaji

> Documentation available [here](https://kamaji.clastix.io/guides/kamaji-azure-deployment-guide/)

This will install Kamaji with the default multi-tenant etcd `DataStore`:

```shell
helm repo add clastix https://clastix.github.io/charts
helm repo update
helm install kamaji clastix/kamaji -n kamaji-system --create-namespace
```

## Create a Control Plane

```shell
kubectl apply -f config/tcp.yaml
```

Wait for provisioning...

```shell
kubectl get tcp -w
```

Get the `kubeconfig`:

```shell
kubectl get secret cncf-zurich-admin-kubeconfig -o=jsonpath='{.data.admin\.conf}' | base64 -d > tenant.kubeconfig
kubectl --kubeconfig=tenant.kubeconfig config set-cluster cncf-zurich --server https://cncf-zurich.westeurope.cloudapp.azure.com:6443
```

```shell
kubectl --kubeconfig=tenant.kubeconfig get svc
kubectl --kubeconfig=tenant.kubeconfig get ep
```

## Join EC2 nodes

> For the sake of the demo we considering to have in place already a VPC with 3 public subnets (i.e. `subnet-093c06bbd03e9c81f`,`subnet-0bb7c6f6465238bb0`,`subnet-036240e210a582a8c`) in the `eu-west-1` region

We're going to create an EC2 Launch Template, that from the Cluster API AMI will run just after the boot `kubeadm join`:

```shell
set +o histexpand

aws ec2 create-launch-template \
  --region eu-west-1 \
  --launch-template-name kamaji-node-cncf-zurich \
  --launch-template-data \
  "{\"ImageId\":\"ami-0086f7d347b66fc76\",\"InstanceType\":\"t3.medium\",\"UserData\":\"$(echo -n "#!/usr/bin/env bash\nsudo $(kubeadm --kubeconfig tenant.kubeconfig token create --print-join-command)" | base64 -w0)\"}"

set -o histexpand
```

and deploy an Auto Scaling Group from the Launch Template:

```shell
aws autoscaling create-auto-scaling-group \
  --auto-scaling-group-name kamaji-nodes-cncf-zurich \
  --launch-template LaunchTemplateName=kamaji-node-cncf-zurich,Version='$Latest' \
  --min-size=2 --max-size=3 \
  --region eu-west-1 \
  --vpc-zone-identifier "subnet-093c06bbd03e9c81f,subnet-0bb7c6f6465238bb0,subnet-036240e210a582a8c"
```

Waiting for nodes joining...

```shell
kubectl --kubeconfig tenant.kubeconfig get nodes -w
```

## Install a CNI plugin

The cluster needs a CNI plugin to get the nodes ready. We are going to install Calico v3.24.1, but feel free to use one of your taste:

```shell
curl -sL https://raw.githubusercontent.com/projectcalico/calico/v3.24.1/manifests/calico.yaml | kubectl --kubeconfig tenant.kubeconfig apply -f -
```

> Just consider that within each AWS VPC subnet no overlay is needed with Calico.

```shell
kubectl --kubeconfig tenant.kubeconfig get nodes
```

You will see that the tenant cluster is now ready to run workloads.
