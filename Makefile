#---------------------------------------------------------------#
#                                                               #
# IBM Confidential                                              #
# OCO Source Materials                                          #
#                                                               #
# (C) Copyright IBM Corp. 2016, 2017                            #
#                                                               #
# The source code for this program is not published or          #
# otherwise divested of its trade secrets, irrespective of      #
# what has been deposited with the U.S. Copyright Office.       #
#                                                               #
#---------------------------------------------------------------#



# The ip or hostname of the Docker host.
# Note the awkward name is to avoid clashing with the DOCKER_HOST variable.
DOCKERHOST_HOST ?= localhost

ifeq ($(DOCKERHOST_HOST),localhost)
 # Check if minikube is active, otherwise leave it as 'localhost'
 MINIKUBE_IP := $(shell minikube ip 2>/dev/null)
 ifdef MINIKUBE_IP
  DOCKERHOST_HOST := $(MINIKUBE_IP)
 endif
endif

THIS_DIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))

WHOAMI ?= $(shell whoami)
DOCKER_BX_NS = registry.ng.bluemix.net/dlaas_dev
TEST_PKGS ?= $(shell glide nv)
DOCKER_IMG_NAME=trainer-v2-service
DOCKER_BASE_IMG_NAME=dlaas-service-base
DOCKER_BASE_IMG_TAG=ubuntu16.04
DLAAS_IMAGE_TAG ?= user-$(WHOAMI)
DLAAS_PORT ?= 30005
DLAAS_MONGO_ADDRESS ?= $(DOCKERHOST_HOST):27017

KUBE_CURRENT_CONTEXT=$(shell kubectl config current-context)
DLAAS_SERVICES_KUBE_CONTEXT ?= $(KUBE_CURRENT_CONTEXT)
DLAAS_SERVICES_KUBE_NAMESPACE ?= $(shell env DLAAS_KUBE_CONTEXT=$(DLAAS_SERVICES_KUBE_CONTEXT) ./bin/kubecontext.sh namespace)
KUBE_SERVICES_CONTEXT_ARGS = --context $(DLAAS_SERVICES_KUBE_CONTEXT) --namespace $(DLAAS_SERVICES_KUBE_NAMESPACE)

usage:              ## Show this help
	@fgrep -h " ## " $(MAKEFILE_LIST) | fgrep -v fgrep | sed -e 's/\\$$//' | sed -e 's/##//'

# LCM_REPO ?= raw.githubusercontent.com/AISphere/ffdl-lcm
LCM_REPO ?= raw.githubusercontent.com/sboagibm/ffdl-lcm
LCM_VERSION ?= branch2
LCM_LOCATION ?= vendor/github.com/AISphere/ffdl-lcm
LCM_SUBDIR ?= service
LCM_SUBDIR_IN ?= service/grpc
LCM_FNAME ?= lcm

TDS_REPO ?= raw.githubusercontent.com/AISphere/ffdl-model-metrics
TDS_VERSION ?= 7ff38aaa21a47c354b7c64dde79dc88ff4372b1e
TDS_LOCATION ?= vendor/github.com/AISphere/ffdl-model-metrics
TDS_SUBDIR ?= service/grpc_training_data_v1
TDS_FNAME ?= training_data

# Rate limiter proto is a plugin, so we don't need/want REPO or VERSION
RATELIMITER_LOCATION ?= vendor/github.com/AISphere/ffdl-trainer/plugins/ratelimiter
RATELIMITER_SUBDIR ?= service/grpc_ratelimiter_v1
RATELIMITER_PROTO_LOC ?= plugins/ratelimiter
RATELIMITER_FNAME ?= ratelimiter

protoc-lcm:  ## Make the lcm protoc client, depends on `make glide` being run first
	#	rm -rf $(LCM_LOCATION)/$(LCM_SUBDIR)
	wget https://$(LCM_REPO)/$(LCM_VERSION)/$(LCM_SUBDIR_IN)/$(LCM_FNAME).proto -P $(LCM_LOCATION)/$(LCM_SUBDIR)
	wget https://$(LCM_REPO)/$(LCM_VERSION)/service/lifecycle.go -P $(LCM_LOCATION)/service
	cd ./$(LCM_LOCATION); \
	protoc -I./$(LCM_SUBDIR) --go_out=plugins=grpc:$(LCM_SUBDIR) ./$(LCM_SUBDIR)/$(LCM_FNAME).proto
	@# At the time of writing, protoc does not support custom tags, hence use a little regex to add "bson:..." tags
	@# See: https://github.com/golang/protobuf/issues/52
	cd $(LCM_LOCATION); \
	sed -i .bak '/.*bson:.*/! s/json:"\([^"]*\)"/json:"\1" bson:"\1"/' ./$(LCM_SUBDIR)/$(LCM_FNAME).pb.go

protoc-tds:  ## Make the training-data service protoc client, depends on `make glide` being run first
	rm -rf $(TDS_LOCATION)/$(TDS_SUBDIR)
	wget https://$(TDS_REPO)/$(TDS_VERSION)/$(TDS_SUBDIR)/$(TDS_FNAME).proto -P $(TDS_LOCATION)/$(TDS_SUBDIR)
	cd ./$(TDS_LOCATION); \
	protoc -I./$(TDS_SUBDIR) --go_out=plugins=grpc:$(TDS_SUBDIR) ./$(TDS_SUBDIR)/$(TDS_FNAME).proto
	@# At the time of writing, protoc does not support custom tags, hence use a little regex to add "bson:..." tags
	@# See: https://github.com/golang/protobuf/issues/52
	cd $(TDS_LOCATION); \
	sed -i .bak '/.*bson:.*/! s/json:"\([^"]*\)"/json:"\1" bson:"\1"/' ./$(TDS_SUBDIR)/$(TDS_FNAME).pb.go

protoc-ratelimiter:  ## Make the rate limiter plugin client, depends on `make glide` being run first
	rm -rf $(RATELIMITER_LOCATION)/$(RATELIMITER_SUBDIR)
	mkdir -p $(RATELIMITER_LOCATION)/$(RATELIMITER_SUBDIR)
	protoc -I./$(RATELIMITER_PROTO_LOC) --go_out=plugins=grpc:$(RATELIMITER_LOCATION)/$(RATELIMITER_SUBDIR) ./$(RATELIMITER_PROTO_LOC)/$(RATELIMITER_FNAME).proto
	@# At the time of writing, protoc does not support custom tags, hence use a little regex to add "bson:..." tags
	@# See: https://github.com/golang/protobuf/issues/52
	cd $(RATELIMITER_LOCATION); \
	sed -i .bak '/.*bson:.*/! s/json:"\([^"]*\)"/json:"\1" bson:"\1"/' ./$(RATELIMITER_SUBDIR)/$(RATELIMITER_FNAME).pb.go

protoc: protoc-lcm protoc-tds protoc-ratelimiter  ## Make gRPC proto clients, depends on `make glide` being run first

vet:
	go vet $(shell glide nv)

lint:               ## Run the code linter
	go list ./... | grep -v /vendor/ | grep -v /grpc_trainer_v2 | xargs -L1 golint -set_exit_status

glide:               ## Run full glide rebuild
	glide cache-clear; \
	rm -rf vendor; \
	glide install

build-x86-64: lint
	CGO_ENABLED=0 GOOS=linux go build -ldflags "-s" -a -installsuffix cgo -o bin/main

test-deps-start:
	docker run --name mongo-trainer -p 27017:27017 -d mongo:3.0 --smallfiles

test-deps-stop:
	docker rm -f mongo-trainer

# Runs all unit tests (short tests)
test-unit:          ## Run unit tests
	DLAAS_LOGLEVEL=debug DLAAS_DNS_SERVER=disabled DLAAS_ENV=local go test $(TEST_PKGS) -v -short

#build-deps: clean
#	mkdir build
##	git -C build clone --depth 1 --single-branch git@github.ibm.com:deep-learning-platform/grpc-health-checker.git
#	cd build/grpc-health-checker && make install-deps build-x86-64
#
docker-pull-base:
	docker pull "$(DOCKER_BX_NS)/$(DOCKER_BASE_IMG_NAME):$(DOCKER_BASE_IMG_TAG)"
	docker tag "$(DOCKER_BX_NS)/$(DOCKER_BASE_IMG_NAME):$(DOCKER_BASE_IMG_TAG)" "$(DOCKER_BASE_IMG_NAME):$(DOCKER_BASE_IMG_TAG)"

docker-build:       ## Build the Docker image
docker-build: build-x86-64
	cd vendor/github.com/AISphere/ffdl-commons/grpc-health-checker && make install-deps build-x86-64
	(cd . && docker build --label git-commit=$(shell git rev-list -1 HEAD) -t "$(DOCKER_BX_NS)/$(DOCKER_IMG_NAME):$(DLAAS_IMAGE_TAG)" .)

docker-push:        ## Push the Docker image to the registry
	docker push "$(DOCKER_BX_NS)/$(DOCKER_IMG_NAME):$(DLAAS_IMAGE_TAG)"


SERVICE_BASE_DIR = ../dlaas-platform-apis
ifeq ($(DLAAS_ENV), local)
  INVENTORY ?= ansible/envs/local/minikube.ini
else
  INVENTORY ?= ansible/envs/local/hybrid.ini
endif

# This list is restricted to items related to the restapi service
DEPLOY_EXTRA_VARS = --extra-vars "service_version=$(DLAAS_IMAGE_TAG)" \
		--extra-vars "DLAAS_NAMESPACE=$(DLAAS_SERVICES_KUBE_NAMESPACE)"

deploy:             ## Deploy the service
	(cd $(SERVICE_BASE_DIR) && ANSIBLE_HOST_KEY_CHECKING=False ANSIBLE_ROLES_PATH=$(THIS_DIR)/$(SERVICE_BASE_DIR)/ansible/roles \
		ansible-playbook -b -i $(INVENTORY) ansible/plays/dlaas-single-service-k8s.yml \
		-c local \
		--verbose \
		--extra-vars "service=trainer-v2" \
		$(DEPLOY_EXTRA_VARS) \
	)

undeploy:           ## Undeploy the service
	-kubectl $(KUBE_SERVICES_CONTEXT_ARGS) delete service dlaas-trainer-v2 --ignore-not-found=true
	-kubectl $(KUBE_SERVICES_CONTEXT_ARGS) delete deployment dlaas-trainer-v2 --ignore-not-found=true
	-kubectl $(KUBE_SERVICES_CONTEXT_ARGS) delete ingress dlaas-trainer-v2 --ignore-not-found=true

redeploy: undeploy deploy


###
# Local targets for development
##
DLAAS_ENV_VARS = DLAAS_LOGLEVEL=debug DLAAS_ENV=local DLAAS_DNS_SERVER=disabled

FSWATCH := $(shell which fswatch 2>/dev/null)
serve-local:
ifndef FSWATCH
	@echo "ERROR: fswatch not found. Please install it to use this target."
	@exit 1
endif
	make kill-local
	make run-local
	fswatch -r -o api_v1 *.go *.yml | xargs -n1 -I{}  make run-local || make kill-local

# exec-local is a dev special for executing something with the same environment that run-services-local uses.
exec-local:
	$(shell $(DLAAS_ENV_VARS) $(LOCALEXECCOMMAND))

run-local:
	make kill-local
	go build -o ./bin/dlaas-trainer-v2 main.go && $(DLAAS_ENV_VARS) DLAAS_PORT=$(DLAAS_PORT) DLAAS_MONGO_ADDRESS=$(DLAAS_MONGO_ADDRESS) ./bin/dlaas-trainer-v2

kill-local:
	-pkill -f "dlaas-trainer-v2"

clean:
	rm -rf build

.PHONY: lint
