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

DOCKER_IMG_NAME = trainer-v2-service

include ../ffdl-commons/ffdl-commons.mk

# Rate limiter proto is a plugin, so we don't need/want REPO or VERSION
RATELIMITER_LOCATION ?= plugins/ratelimiter
RATELIMITER_SUBDIR ?= service/grpc_ratelimiter_v1
RATELIMITER_PROTO_LOC ?= plugins/ratelimiter
RATELIMITER_FNAME ?= ratelimiter

TOOLCHAIN_DOCKER_HOST ?= docker.io
TOOLCHAIN_DOCKER_NAMESPACE ?= ffdl
TOOLCHAIN_DOCKER_IMG_NAME ?= ffdlbuildtools
TOOLCHAIN_IMAGE_TAG ?= v1

clean-ratelimiter:                     ## clean ratelimiter artifacts
	rm -rf $(RATELIMITER_LOCATION)/$(RATELIMITER_SUBDIR)

protoc-ratelimiter:  clean-ratelimiter ## Make the rate limiter plugin client, depends on `make glide` being run first
	rm -rf $(RATELIMITER_LOCATION)/$(RATELIMITER_SUBDIR)
	mkdir -p $(RATELIMITER_LOCATION)/$(RATELIMITER_SUBDIR)
	protoc -I./$(RATELIMITER_PROTO_LOC) --go_out=plugins=grpc:$(RATELIMITER_LOCATION)/$(RATELIMITER_SUBDIR) ./$(RATELIMITER_PROTO_LOC)/$(RATELIMITER_FNAME).proto
	@# At the time of writing, protoc does not support custom tags, hence use a little regex to add "bson:..." tags
	@# See: https://github.com/golang/protobuf/issues/52
	cd $(RATELIMITER_LOCATION); \
	sed -i.bak '/.*bson:.*/! s/json:"\([^"]*\)"/json:"\1" bson:"\1"/' ./$(RATELIMITER_SUBDIR)/$(RATELIMITER_FNAME).pb.go

protoc: protoc-lcm protoc-tds          ## Make gRPC proto clients, depends on `make glide` being run first

install-deps: protoc-ratelimiter install-deps-base protoc  ## Remove vendor directory, rebuild dependencies

diagnose-target-build:
	@echo "Calling docker-build-base"

diagnose-target-push:
	@echo "Calling docker-push-base"

docker-build: diagnose-target-build docker-build-base        ## Install dependencies if vendor folder is missing, build go code, build docker image

docker-push: diagnose-target-push docker-push-base          ## Push docker image to a docker hub

clean: clean-base clean-ratelimiter    ## clean all build artifacts
	rm -rf build; \

docker-build-toolchain-container:  ## build docker container for running the build
	(cd toolchain && docker build --label git-commit=$(shell git rev-list -1 HEAD) -t "$(TOOLCHAIN_DOCKER_HOST)/$(TOOLCHAIN_DOCKER_NAMESPACE)/$(TOOLCHAIN_DOCKER_IMG_NAME):$(TOOLCHAIN_IMAGE_TAG)" .)

docker-push-toolchain-container:  ## build docker container for running the build
	docker push "$(TOOLCHAIN_DOCKER_HOST)/$(TOOLCHAIN_DOCKER_NAMESPACE)/$(TOOLCHAIN_DOCKER_IMG_NAME):$(TOOLCHAIN_IMAGE_TAG)"

toolchain-container: docker-build-toolchain-container docker-push-toolchain-container ## Build and push toolchain-container



deploy-plugin:
	@# deploy the stack via helm
	@echo Deploying services to Kubernetes. This may take a while.
	@if ! helm list > /dev/null 2>&1; then \
		echo 'Installing helm/tiller'; \
		helm init; \
		sleep 5; \
		echo "Waiting tiller to be ready"; \
		while ! (kubectl get pods --all-namespaces | grep tiller-deploy | grep '1/1' > /dev/null); \
		do \
			sleep 1; \
		done; \
	fi;
	@existingPlugin=$$(helm list | grep ibmcloud-object-storage-plugin | awk '{print $$1}' | head -n 1);
	@# kubectl config set-context $$(kubectl config current-context) --namespace=kube-system
	@if [ "$(VM_TYPE)" = "dind" ]; then \
		export FFDL_PATH=$$(pwd); \
		./bin/s3_driver.sh; \
		sleep 10; \
		(if [ -z "$$existingPlugin" ]; then \
			helm install --set dind=true,cloud=false,namespace=kube-system storage-plugin; \
		else \
			helm upgrade --set dind=true,cloud=false,namespace=kube-system $$existingPlugin storage-plugin; \
		fi) & pid=$$!; \
	else \
		(if [ -z "$$existingPlugin" ]; then \
			helm install --set namespace=kube-system storage-plugin; \
		else \
			helm upgrade --set namespace=kube-system $$existingPlugin storage-plugin; \
		fi) & pid=$$!; \
	fi;
	@echo "Wait while kubectl get pvc shows static-volume-1 in state Pending"
	@./bin/create_static_volumes.sh
	@./bin/create_static_volumes_config.sh
	@sleep 3

undeploy-cos-plugin:
	@existingPlugin=$$(helm list | grep ibmcloud-object-storage-plugin | awk '{print $$1}' | head -n 1); \
		helm delete $$existingPlugin; \
		kubectl delete pvc/static-volume-1 cm/static-volumes cm/static-volumes-v2;

