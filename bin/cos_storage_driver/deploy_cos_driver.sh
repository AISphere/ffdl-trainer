#!/usr/bin/env bash

#--------------------------------------------------------------------------#
#                                                                          #
# Copyright 2017-2018 IBM Corporation                                      #
#                                                                          #
# Licensed under the Apache License, Version 2.0 (the "License");          #
# you may not use this file except in compliance with the License.         #
# You may obtain a copy of the License at                                  #
#                                                                          #
# http://www.apache.org/licenses/LICENSE-2.0                               #
#                                                                          #
# Unless required by applicable law or agreed to in writing, software      #
# distributed under the License is distributed on an "AS IS" BASIS,        #
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. #
# See the License for the specific language governing permissions and      #
# limitations under the License.                                           #
#--------------------------------------------------------------------------#

operating_system=$(uname)
if [[ "$operating_system" == 'Linux' ]]; then
    CMD_SED=sed
elif [[ "$operating_system" == 'Darwin' ]]; then
    CMD_SED=gsed
fi
if ! [[ -x "$(command -v ${CMD_SED})" ]]; then
    echo "Error: Proper sed command not found for deploy_cos_driver script." 1>&2
    exit 1
fi

if ! [[ -e ~/s3fs-fuse/src/s3fs ]]; then
    echo "Error: s3fs does not exist for deploy_cos_driver script."
    exit 1
fi

if ! [[ -e ${GOPATH}/bin/ibmc-s3fs ]]; then
    echo "Error: The COS Driver ibmc-s3fs does not exist for deploy_cos_driver script."
    exit 1
fi

#if [[ "$(docker images -q ibmcloud-object-storage-plugin 2> /dev/null)" == "" ]]; then  # could add :<tag> for version
#    echo "Error: The IBM Cloud COS Plugin image does not exist for deploy_cos_driver script."
#    exit 1
#fi

# .:: Copy binaries into every node (manual for DIND, daemonset for IBM Cloud) ::.
DEPLOY_MODE="DIND"
if [[ ${DEPLOY_MODE} = "DIND" ]]; then
    declare -a arrNodes=($(docker ps --format '{{.Names}}' | grep "kube-node-\|kube-master"))
    for node in "${arrNodes[@]}"
    do
    docker cp ${GOPATH}/bin/ibmc-s3fs ${node}:/root/ibmc-s3fs
    docker cp ~/s3fs-fuse/src/s3fs ${node}:/usr/local/bin/s3fs

# Cannot indent the following due to _EOF
docker exec -i ${node} /bin/bash <<_EOF
apt-get update && apt-get install -y libssl1.0.2 nfs-common libfuse2 libxml2 curl libcurl3
mkdir -p /usr/libexec/kubernetes/kubelet-plugins/volume/exec/ibm~ibmc-s3fs
cp /root/ibmc-s3fs /usr/libexec/kubernetes/kubelet-plugins/volume/exec/ibm~ibmc-s3fs
chmod +x /usr/libexec/kubernetes/kubelet-plugins/volume/exec/ibm~ibmc-s3fs/ibmc-s3fs
systemctl restart kubelet
docker pull ${DOCKER_REPO}/ibmcloud-object-storage-plugin:latest
_EOF

    done
else
    echo "Daemonset deployment for IBM Cloud currently not implemented. But see ibmc_scripts/experimental_master.sh"
fi

# TODO .:: Verify binaries are in place ::.

# .:: Deploy ibmcloud-object-storage-plugin ::.
# TODO: I want deploy/provisioner-sa.yaml and deploy/provisioner.yaml below, not the deploy-provisioner file !!!
cd ${GOPATH}/src/github.com/IBM/ibmcloud-object-storage-plugin/deploy/
cp provisioner.yaml provisioner_public_docker.yaml
COS_PLUGIN_REPO=docker.io
COS_PLUGIN_REPO_NAMESPACE=ffdl
COS_PLUGIN_VERSION=v0.1
${CMD_SED} -i "s/image: ibmcloud-object-storage-plugin:latest/image: \"${COS_PLUGIN_REPO}\/${COS_PLUGIN_REPO_NAMESPACE}\/ibmcloud-object-storage-plugin:${COS_PLUGIN_VERSION}\"/g" provisioner_public_docker.yaml
kubectl create -f provisioner-sa.yaml
kubectl create -f provisioner_public_docker.yaml

# .:: Verify image is deployed ::.
# The following should return code 0 if plugin is there and 1 if it is not
kubectl rollout status deploy/ibmcloud-object-storage-plugin -n kube-system

# .:: Create Storage Class ::.
cd ${GOPATH}/src/github.com/IBM/ibmcloud-object-storage-plugin/deploy
kubectl create -f ibmc-s3fs-standard-StorageClass.yaml
if [[ "$(kubectl get sc 2> /dev/null | grep ibmc-s3fs-standard)" == "" ]]; then
    echo "Error: The COS StorageClass was not correctly created in the COS driver deployment script."
    exit 1
fi

# .:: Optional: Verify COS test pod can be launched ::.
# TEST_ACCESS_KEY=
#TEST_SECRET_KEY=
#TEST_BUCKET=
#
#kubectl apply -f - <<EOF
#apiVersion: v1
#kind: Secret
#type: ibm/ibmc-s3fs
#metadata:
#  name: test-secret
#  namespace: default
#data:
#  access-key: ${TEST_ACCESS_KEY}
#  secret-key: ${TEST_SECRET_KEY}
#EOF
#
#echo - <<EOF
#kind: PersistentVolumeClaim
#apiVersion: v1
#metadata:
#  name: s3fs-test-pvc
#  namespace: default
#  annotations:
#    volume.beta.kubernetes.io/storage-class: "ibmc-s3fs-standard"
#    ibm.io/auto-create-bucket: "false"
#    ibm.io/auto-delete-bucket: "false"
#    ibm.io/bucket: "${TEST_BUCKET}"
#    ibm.io/endpoint: "https://s3-api.us-geo.objectstorage.softlayer.net"
#    ibm.io/region: "us-standard"
#    ibm.io/secret-name: "test-secret"
#spec:
#  accessModes:
#    - ReadWriteOnce
#  resources:
#    requests:
#      storage: 8Gi
#EOF
#
#kubectl get pvc
#
#kubectl apply -f - <<EOF
#apiVersion: v1
#kind: Pod
#metadata:
#  name: s3fs-test-pod
#  namespace: default
#spec:
#  containers:
#  - name: s3fs-test-container
#    image: anaudiyal/infinite-loop
#    volumeMounts:
#    - mountPath: "/mnt/s3fs"
#      name: s3fs-test-volume
#  volumes:
#  - name: s3fs-test-volume
#    persistentVolumeClaim:
#      claimName: s3fs-test-pvc
#EOF
