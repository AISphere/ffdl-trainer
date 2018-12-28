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


FROM golang:1.11.4-stretch

ENV GOBIN $GOPATH/bin

ENV PROTOC_ZIP protoc-3.6.1-linux-x86_64.zip

ENV registry docker_hub_account/repository_name
ENV registryCredential dockerhub

#ENV DEBIAN_FRONTEND noninteractive

RUN mkdir -p $GOBIN

RUN  apt-get update
RUN apt-get install -y apt-transport-https ca-certificates software-properties-common
RUN curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
RUN add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu xenial stable"
RUN apt-get update
RUN apt-get install -y docker-ce

RUN apt-get install -y zip

RUN curl -OL https://github.com/google/protobuf/releases/download/v3.6.1/$PROTOC_ZIP
RUN unzip -o $PROTOC_ZIP -d /usr/local bin/protoc
RUN rm -f $PROTOC_ZIP

RUN rm -rf $GOPATH/src/github.com/golang/protobuf
RUN mkdir -p $GOPATH/src/github.com/golang
WORKDIR $GOPATH/src/github.com/golang
RUN git clone https://github.com/golang/protobuf.git
WORKDIR protobuf
RUN git checkout v1.2.0
RUN go build -o /usr/local/bin/protoc-gen-go ./protoc-gen-go
WORKDIR $GOPATH

RUN apt-get install -y apt-transport-https
RUN curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
RUN echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" | tee -a /etc/apt/sources.list.d/kubernetes.list
RUN apt-get update
RUN apt-get install -y kubectl

WORKDIR /usr/local/bin
RUN curl https://glide.sh/get | bash || true
RUN mv $GOBIN/glide /usr/local/bin

WORKDIR $GOPATH

