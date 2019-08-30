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

declare -a arrNodes=($(docker ps --format '{{.Names}}' | grep "kube-node-\|kube-master"))
for node in "${arrNodes[@]}"
do
docker cp $FFDL_PATH/bin/ibmc-s3fs $node:/root/ibmc-s3fs
docker cp $FFDL_PATH/bin/s3fs $node:/usr/local/bin/s3fs
docker exec -i $node /bin/bash <<_EOF
apt-get -y update
apt-get -y install s3fs
mkdir -p /usr/libexec/kubernetes/kubelet-plugins/volume/exec/ibm~ibmc-s3fs
cp /root/ibmc-s3fs /usr/libexec/kubernetes/kubelet-plugins/volume/exec/ibm~ibmc-s3fs
chmod +x /usr/libexec/kubernetes/kubelet-plugins/volume/exec/ibm~ibmc-s3fs/ibmc-s3fs
systemctl restart kubelet
_EOF
done
