# General DIND Setup

Note: The following commands are a rough sketch of how I setup a working deployment and not yet well automated.

```bash
# Install protoc and protoc-gen-go
# cmp. https://github.com/protocolbuffers/protobuf/releases
PROTOC_ZIP="protoc-3.6.1-linux-x86_64.zip"
curl -OL https://github.com/protocolbuffers/protobuf/releases/download/v3.6.1/${PROTOC_ZIP}
sudo unzip -o ${PROTOC_ZIP} -d /usr/local bin/protoc
rm -f ${PROTOC_ZIP}

git clone https://github.com/golang/protobuf.git
cd ${GOPATH}/src/github.com/golang/protobuf/protoc-gen-go && git checkout v1.2.0 && go install
# Version flag issue: https://github.com/golang/protobuf/issues/524

# Build AISphere's FfDL
cd ${GOPATH}/src/github.com/AISphere/ffdl-commons
make gen-certs build

# Create dev file
printf "\n  ca_crt: " && cat certs/ca.crt | base64 | tr -d '\n' && \
printf "\n  server_crt: " && cat certs/server.crt | base64 | tr -d '\n' && \
printf "\n  server_key: " && cat certs/server.key | base64 | tr -d '\n'
# ... and manual entries

# Create registry access secret
export DOCKER_REPO="registry.ng.bluemix.net"
export DOCKER_REPO_USER=token
export DOCKER_REPO_PASS="<REGISTRY_PASSWORD_2>"
kubectl create secret docker-registry bluemix-cr-ng --docker-server=${DOCKER_REPO} --docker-username=${DOCKER_REPO_USER} --docker-password=${DOCKER_REPO_PASS} --docker-email=wps@us.ibm.com

# Create storage volumes
cd ${GOPATH}/src/github.com/AISphere/ffdl-trainer/bin/cos_storage_driver
make deploy-nfs-volume
make setup-cos-plugin
make create-volumes

# Adapt helm rights
helm init --service-account tiller --tiller-namespace default --upgrade
# kubectl create serviceaccount --namespace default tiller
# kubectl create clusterrolebinding tiller-cluster-rule-default --clusterrole=cluster-admin --serviceaccount=default:tiller
# kubectl patch deploy --namespace default tiller-deploy -p '{"spec":{"template":{"spec":{"serviceAccount":"tiller"}}}}'
kubectl create serviceaccount --namespace kube-system tiller
kubectl create clusterrolebinding tiller-cluster-rule --clusterrole=cluster-admin --serviceaccount=kube-system:tiller
kubectl patch deploy --namespace kube-system tiller-deploy -p '{"spec":{"template":{"spec":{"serviceAccount":"tiller"}}}}'
helm init --service-account tiller --upgrade

# Create configmap
kubectl apply -f - <<EOF
apiVersion: v1
data:
  learner-config.json: |
    {"frameworks":{"blueconnect":{"versions":[{"version":"0.1","build":"master-25","prevBuild":"master-25","external":false,"compute":["gpu","libs"]}]},"theano":{"versions":[{"version":"1.0","build":"master-46","prevBuild":"master-45","external":false,"compute":["gpu"]}]},"parameter-server":{"versions":[{"version":"0.0","build":"master-46","prevBuild":"master-45","external":false,"compute":["cpu"]}]},"caffe":{"versions":[{"version":"1.0-ddl","build":"master-17","prevBuild":"master-17","external":true,"compute":["gpu","cpu","em"]},{"version":"1.0-py2","build":"master-73","prevBuild":"master-72","external":false,"compute":["gpu"]},{"version":"1.0-py3","build":"master-73","prevBuild":"master-72","external":false,"compute":["gpu"]}]},"tensorflow":{"versions":[{"version":"1.4-py2-ddl","build":"master-38","prevBuild":"master-32","external":true,"compute":["cpu"]},{"version":"1.4-py3-ddl","build":"master-38","prevBuild":"master-32","external":true,"compute":["gpu"]},{"version":"1.2-py3","build":"master-184","prevBuild":"master-181","external":true,"compute":["gpu"]},{"version":"1.2-py2","build":"master-184","prevBuild":"master-181","external":true,"compute":["gpu"]},{"version":"1.3-py3","build":"master-184","prevBuild":"master-181","external":true,"compute":["gpu"]},{"version":"1.3-py2","build":"master-184","prevBuild":"master-181","external":true,"compute":["gpu"]},{"version":"1.4-py3","build":"master-184","prevBuild":"master-181","external":true,"compute":["gpu"]},{"version":"1.4-py2","build":"master-184","prevBuild":"master-181","external":true,"compute":["gpu"]},{"version":"1.5-py3","build":"master-186","prevBuild":"master-184","external":true,"compute":["gpu"]},{"version":"1.5-py2","build":"master-186","prevBuild":"master-184","external":true,"compute":["gpu"]},{"version":"1.6-py3","build":"master-186","prevBuild":"master-184","external":true,"compute":["gpu"]},{"version":"1.6-py2","build":"master-186","prevBuild":"master-184","external":true,"compute":["gpu"]},{"version":"1.5-py3-ddl","build":"master-38","prevBuild":"master-32","external":true,"compute":["gpu"]},{"version":"1.4-py3-horovod","build":"master-11","prevBuild":"fake","external":true,"compute":["gpu"]},{"version":"1.5-py3-horovod","build":"master-21","prevBuild":"master-19","external":true,"compute":["gpu"]},{"version":"1.7-py3","build":"master-186","prevBuild":"master-184","external":true,"compute":["gpu"]},{"version":"1.7-py2","build":"master-186","prevBuild":"master-184","external":true,"compute":["gpu"]},{"version":"1.8-py3","build":"master-186","prevBuild":"master-184","external":true,"compute":["gpu"]},{"version":"1.8-py2","build":"master-186","prevBuild":"master-184","external":true,"compute":["gpu"]}]},"pytorch":{"versions":[{"version":"0.3-py2","build":"master-41","prevBuild":"master-40","external":true,"compute":["gpu"]},{"version":"0.3-py3","build":"master-41","prevBuild":"master-40","external":true,"compute":["gpu"]},{"version":"0.4-py3","build":"master-41","prevBuild":"master-40","external":true,"compute":["gpu"]},{"version":"0.4-py2","build":"master-41","prevBuild":"master-41","external":true,"compute":["gpu"]}]},"mxnet":{"versions":[{"version":"0.10","build":"master-18","prevBuild":"master-17","external":false,"compute":["gpu"]},{"version":"1.1","build":"master-20","prevBuild":"master-19","external":false,"compute":["gpu"]},{"version":"1.1-py2","build":"master-23","prevBuild":"master-22","external":false,"compute":["gpu"]}]},"caffe2":{"versions":[{"version":"0.8","build":"master-33","prevBuild":"master-32","external":true,"compute":["gpu"]}]},"torch":{"versions":[{"version":"luajit","build":"master-56","prevBuild":"master-53","external":true,"compute":["gpu"]},{"version":"lua52","build":"master-56","prevBuild":"master-53","external":true,"compute":["gpu"]}]}}}
kind: ConfigMap
metadata:
  name: learner-config-new
EOF

# Build and push job monitor
cd ${GOPATH}/src/github.com/AISphere//ffdl-job-monitor
make docker-build make docker-push

# Build and push model metrics
cd ${GOPATH}/src/github.com/AISphere//ffdl-job-monitor
make docker-build docker-push

# Deploy Trainer
cd ${GOPATH}/src/github.com/AISphere/ffdl-trainer
# make deploy
cd helmdeploy/ && rm -rf * && cd ../charts/ && rm -f * && cd ..
cp -rf Chart.yaml values.yaml templates helmdeploy && cd helmdeploy/
helm install --tiller-namespace default -f /Users/fpk/go/src/github.com/AISphere/ffdl-trainer/envs/dev_values.yaml .
cd ..

# Deploy LCM
kubectl create serviceaccount --namespace default editor
kubectl create clusterrolebinding tiller-cluster-rule-editor --clusterrole=cluster-admin --serviceaccount=default:editor
# Line 20 of lcm-deployment.yml needs to be         version:  {{.Values.ffdl_lcm.lcm.version}}
cd ${GOPATH}/src/github.com/AISphere/ffdl-lcm/
# Make sure helmdeploy exists and is empty
mkdir -p helmdeploy && rm -rf helmdeploy/*
cp -rf Chart.yaml values.yaml templates helmdeploy
helm install --tiller-namespace default -f /Users/fpk/go/src/github.com/AISphere/ffdl-trainer/envs/dev_values.yaml /Users/fpk/go/src/github.com/AISphere/ffdl-lcm/helmdeploy

# Print values for gRPC CLI
make cli-grpc-config
```

Run training job (on actual machine - no SSH forwarding here currently)
```bash
# Run export commands from previous command (make cli-grpc-config)
alias ffdl=~/go/src/github.com/AISphere/ffdl-cli/bin/ffdl_linux
ffdl list
# The following will currently break:
ffdl train manifest.yml .
```

For instance with `manifest.yml`:
```yaml
name: test-custom-image
   version: "1.0"
   description: Test custom images
   gpus: 0
   cpus: 1
                   # gpu_type: cpu will NOT allocate any gpu for the job (i.e. cpu-only training)
   gpu_type: nvidia-TeslaK80   # Use gpu_type: nvidia-TeslaK80 here for gpu training
   memory: 500MiB
   
   # Object stores that allow the system to retrieve training data.
   data_stores:
     # This is a Softlayer internal object store. We cannot use ACLs here so we need
     # to use the credentials directly.
     - id: sl-internal-os
       type: mount_cos
       training_data:
         container: <INPUT_BUCKET>
       training_results:
         container: <OUTPUT_BUCKET>
       connection:
         auth_url: https://s3-api.dal-us-geo.objectstorage.service.networklayer.com
         user_name: <COS_CREDENTIALS_1>
         password: <COS_CREDENTIALS_1>
   
   framework:
     name: custom-learner-image
     version: "ubuntu16"
     command: python hello.py
     image_location:
        registry:  registry.ng.bluemix.net
        namespace: dlaas_test
        email:     wdcdlaas@us.ibm.com
        access_token: <REGISTRY_PASSWORD_2>
```

And code `hello.py`:
```python
#!/usr/bin/env python
import os
import sys

print("Successfully executed custom image.")
```

# Tooling
## DIND Forwarding
```bash
# On remote server
sudo vim  /etc/ssh/sshd_config
# Add the following to  /etc/ssh/sshd_config on target (maybe unnecessary - not sure):
AllowTcpForwarding yes
GatewayPorts yes

service ssh restart

# On local machine
ssh -L 32773:localhost:32773 ffdlr@ffdltest.sl.cloud9.ibm.com -N
vim .kube/config
# Add the following 2 parts and then modify the third (current context)
- cluster:
    insecure-skip-tls-verify: true
    server: http://127.0.0.1:32773
  name: dind2
...
- context:
    cluster: dind2
    user: ""
  name: dind2
...
current-context: dind2

# To try launch something
kubectl create deployment hello-node --image=gcr.io/hello-minikube-zero-install/hello-node
```

## Convenience Tricks
Can add aliases and default namespaces
```bash
alias ffdl=~/go/src/github.com/AISphere/ffdl-cli/bin/ffdl_linux

export TILLER_NAMESPACE=default

alias kc=kubectl

alias kd="kc describe"
alias kg="kc get"

alias kdp="kc describe pod"
alias kgp="kc get pod"
```