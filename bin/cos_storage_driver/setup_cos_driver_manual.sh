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

# .:: Verify fundamental dependencies ::.

if [[ -z "${GOPATH}" ]]; then
    echo "Error: Environment variable GOPATH not set." 1>&2
    exit 1
fi

if ! [[ -x "$(command -v docker)" ]]; then
    echo "Error: docker command not found." 1>&2
    exit 1
fi

if ! [[ -x "$(command -v glide)" ]]; then
    echo "Error: glide command not found." 1>&2
    exit 1
fi

if ! [[ -x "$(command -v go)" ]]; then
    echo "Error: go command not found." 1>&2
    exit 1
fi

# .:: Create container for direct dependency compilation ::.
docker build -t s3fs_compilation_container -f Dockerfile.compile .
docker run -d --name s3compiler -v /var/run/docker.sock:/var/run/docker.sock -v $(which docker):/usr/bin/docker \
    s3fs_compilation_container tail -f /dev/null
mkdir -p ~/s3fs-fuse/src/
docker cp s3compiler:/s3fs-fuse/src/s3fs ~/s3fs-fuse/src/s3fs
# docker cp s3compiler:/root/go/bin/ibmc-s3fs binary_executables/ibmc-s3fs
docker stop s3compiler && docker rm s3compiler
# Result: s3fs is now in ~/s3fs-fuse/src/s3fs


mkdir -p ${GOPATH}/bin
mkdir -p ${GOPATH}/src/github.com/IBM && cd $_
git clone https://github.com/IBM/ibmcloud-object-storage-plugin.git && cd ibmcloud-object-storage-plugin
make provisioner
# Result: Driver ibmc-s3fs is now in ${GOPATH}/bin/ibmc-s3fs
make driver
# Result: ibmcloud-object-storage-plugin container is now in Docker (as in docker images, not yet registry)

# .:: Verify results of build steps ::.
if ! [[ -e ~/s3fs-fuse/src/s3fs ]]; then
    echo "Error: s3fs does not exist after running COS driver script."
    exit 1
fi

if ! [[ -e ${GOPATH}/bin/ibmc-s3fs ]]; then
    echo "Error: The COS Driver ibmc-s3fs does not exist after running COS driver script."
    exit 1
fi

if [[ "$(docker images -q ibmcloud-object-storage-plugin 2> /dev/null)" == "" ]]; then  # could add :<tag> for version
    echo "Error: The IBM Cloud COS Plugin image does not exist after running COS driver script."
    exit 1
fi