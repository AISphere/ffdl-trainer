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

DLAAS_KUBE_CONTEXT=${DLAAS_KUBE_CONTEXT:-$(kubectl config current-context)}

echo "Creating persistent volume."

(kubectl --context "$DLAAS_KUBE_CONTEXT" create -f - <<EOF
apiVersion: v1
kind: PersistentVolume
metadata:
  name: nfs
spec:
  capacity:
    storage: 20Gi
  accessModes:
    - ReadWriteMany
  nfs:
    server: ${TARGET_SERVER}
    path: "/nfs/var/nfs/general"
EOF
) || true

# Could test like this:

#kubectl create -f - <<EOF
#apiVersion: v1
#kind: Pod
#metadata:
#  name: nfs-test-pod
#  namespace: default
#spec:
#  containers:
#  - name: nfs-test-container
#    image: anaudiyal/infinite-loop
#    volumeMounts:
#    - mountPath: "/job"
#      name: nfs-test-volume
#  volumes:
#  - name: nfs-test-volume
#    persistentVolumeClaim:
#      claimName: static-volume-1
#EOF
