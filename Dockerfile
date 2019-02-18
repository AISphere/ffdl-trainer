#
# Copyright 2017-2018 IBM Corporation
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

ARG DOCKER_HOST_NAME=registry.ng.bluemix.net
ARG DOCKER_NAMESPACE=dlaas_dev
ARG DLAAS_SERVICE_BASE_DOCKER_PATH=${DOCKER_HOST_NAME}/${DOCKER_NAMESPACE}
ARG DLAAS_SERVICE_BASE_IMAGE_TAG=ubuntu16.04
FROM ${DLAAS_SERVICE_BASE_DOCKER_PATH}/ffdl-service-base:${DLAAS_SERVICE_BASE_IMAGE_TAG}

ADD bin/main /main
RUN chmod 755 /main

# assign "random" non-root user id
USER 6342627

ENTRYPOINT ["/main"]
