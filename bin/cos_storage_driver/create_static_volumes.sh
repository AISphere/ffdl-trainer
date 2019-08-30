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

# Helper script to create static volumes.

# SCRIPTDIR="$(cd $(dirname "$0")/ && pwd)"

# Be sure to set the DLAAS_KUBE_CONTEXT to override the current context (i.e., kubectl config current-context)
# DLAAS_KUBE_CONTEXT=${DLAAS_KUBE_CONTEXT:-$(kubectl config current-context)}

#echo "Kube context: $DLAAS_KUBE_CONTEXT"

# Should be "ibmc-file-gold" for Bluemix deployment
SHARED_VOLUME_STORAGE_CLASS="${SHARED_VOLUME_STORAGE_CLASS:-""}"

volumeNum=${1:-1}
NAMESPACE=${NAMESPACE:-default}

echo "Creating persistent volume claim $volumeNum"
(kubectl apply -f - <<EOF
kind: PersistentVolumeClaim
apiVersion: v1
metadata:
  name: static-volume-$volumeNum
  namespace: $NAMESPACE
  annotations:
    volume.beta.kubernetes.io/storage-class: "$SHARED_VOLUME_STORAGE_CLASS"
  labels:
    type: dlaas-static-volume
spec:
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 20Gi
EOF
) || true
