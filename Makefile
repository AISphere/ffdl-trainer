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

DOCKER_IMG_NAME = trainer-v2-service

include ../ffdl-commons/ffdl-commons.mk

# Rate limiter proto is a plugin, so we don't need/want REPO or VERSION
RATELIMITER_LOCATION ?= plugins/ratelimiter
RATELIMITER_SUBDIR ?= service/grpc_ratelimiter_v1
RATELIMITER_PROTO_LOC ?= plugins/ratelimiter
RATELIMITER_FNAME ?= ratelimiter

clean-ratelimiter:                     ## clean ratelimiter artifacts
	rm -rf $(RATELIMITER_LOCATION)/$(RATELIMITER_SUBDIR)

protoc-ratelimiter:  clean-ratelimiter ## Make the rate limiter plugin client, depends on `make glide` being run first
	rm -rf $(RATELIMITER_LOCATION)/$(RATELIMITER_SUBDIR)
	mkdir -p $(RATELIMITER_LOCATION)/$(RATELIMITER_SUBDIR)
	protoc -I./$(RATELIMITER_PROTO_LOC) --go_out=plugins=grpc:$(RATELIMITER_LOCATION)/$(RATELIMITER_SUBDIR) ./$(RATELIMITER_PROTO_LOC)/$(RATELIMITER_FNAME).proto
	@# At the time of writing, protoc does not support custom tags, hence use a little regex to add "bson:..." tags
	@# See: https://github.com/golang/protobuf/issues/52
	cd $(RATELIMITER_LOCATION); \
	sed -i .bak '/.*bson:.*/! s/json:"\([^"]*\)"/json:"\1" bson:"\1"/' ./$(RATELIMITER_SUBDIR)/$(RATELIMITER_FNAME).pb.go

protoc: protoc-lcm protoc-tds          ## Make gRPC proto clients, depends on `make glide` being run first

install-deps: protoc-ratelimiter install-deps-base protoc  ## Remove vendor directory, rebuild dependencies

docker-build: docker-build-base        ## Install dependencies if vendor folder is missing, build go code, build docker image

docker-push: docker-push-base          ## Push docker image to a docker hub

deploy:           ## Deploy the services to Kubernetes
	@docker images
	@echo $(DOCKER_REPO)
	@echo $(DOCKER_PULL_POLICY)
	@# deploy the stack via helm
	@echo Deploying services to Kubernetes. This may take a while.
	@if ! helm list > /dev/null 2>&1; then \
		echo 'Installing helm/tiller'; \
		helm init > /dev/null 2>&1; \
		sleep 3; \
	fi;
	@echo collecting existing pods
	@while kubectl get pods --all-namespaces | \
		grep -v RESTARTS | \
		grep -v Running | \
		grep 'alertmanager\|etcd0\|lcm\|restapi\|trainer\|trainingdata\|ui\|mongo\|prometheus\|pushgateway\|storage' > /dev/null; \
	do \
		sleep 1; \
	done
	@echo finding out which pods are running
	@while ! (kubectl get pods --all-namespaces | grep tiller-deploy | grep '1/1' > /dev/null); \
	do \
		sleep 1; \
	done
	@echo calling big command
	@set -o verbose; \
		echo HELM_DEPLOY_DIR: ${HELM_DEPLOY_DIR}; \
		mkdir -p ${HELM_DEPLOY_DIR}; \
		cp -rf Chart.yaml values.yaml templates ${HELM_DEPLOY_DIR}; \
		existing=$$(helm list | grep ffdl | awk '{print $$1}' | head -n 1); \
		if [ "$$CI" = "true" ]; then \
			export helm_params='--set lcm.shared_volume_storage_class=${SHARED_VOLUME_STORAGE_CLASS},has_static_volumes=${HAS_STATIC_VOLUMES},prometheus.deploy=false,learner.docker_namespace=${DOCKER_NAMESPACE},docker.namespace=${DOCKER_NAMESPACE},learner.tag=${IMAGE_TAG},docker.pullPolicy=${DOCKER_PULL_POLICY},docker.registry=${DOCKER_REPO},trainer.version=${IMAGE_TAG},restapi.version=${IMAGE_TAG},lcm.version=${IMAGE_TAG},trainingdata.version=${IMAGE_TAG},databroker.tag=${IMAGE_TAG},databroker.version=${IMAGE_TAG},webui.version=${IMAGE_TAG}'; \
		else \
			export helm_params='--set lcm.shared_volume_storage_class=${SHARED_VOLUME_STORAGE_CLASS},has_static_volumes=${HAS_STATIC_VOLUMES},learner.docker_namespace=${DOCKER_NAMESPACE},docker.namespace=${DOCKER_NAMESPACE},learner.tag=${IMAGE_TAG},docker.pullPolicy=${DOCKER_PULL_POLICY},docker.registry=${DOCKER_REPO},trainer.version=${IMAGE_TAG},restapi.version=${IMAGE_TAG},lcm.version=${IMAGE_TAG},trainingdata.version=${IMAGE_TAG},databroker.tag=${IMAGE_TAG},databroker.version=${IMAGE_TAG},webui.version=${IMAGE_TAG}'; \
		fi; \
		(if [ -z "$$existing" ]; then \
			echo "Deploying the stack via Helm. This will take a while."; \
			helm --debug install $$helm_params ${HELM_DEPLOY_DIR} ; \
			sleep 10; \
		else \
			echo "Upgrading existing Helm deployment ($$existing). This will take a while."; \
			helm --debug upgrade $$helm_params $$existing ${HELM_DEPLOY_DIR} ; \
		fi) & pid=$$!; \
		sleep 5; \
		while kubectl get pods --all-namespaces | \
			grep -v RESTARTS | \
			grep -v Running | \
			grep 'alertmanager\|etcd0\|lcm\|restapi\|trainer\|trainingdata\|ui\|mongo\|prometheus\|pushgateway\|storage'; \
		do \
			sleep 5; \
		done; \
		existing=$$(helm list | grep ffdl | awk '{print $$1}' | head -n 1); \
		for i in $$(seq 1 10); do \
			status=`helm status $$existing | grep STATUS:`; \
			echo $$status; \
			if echo "$$status" | grep "DEPLOYED" > /dev/null; then \
				kill $$pid > /dev/null 2>&1; \
				exit 0; \
			fi; \
			sleep 3; \
		done; \
		exit 0
	@echo done with big command
	@echo Initializing...
	@# wait for pods to be ready
	@while kubectl get pods --all-namespaces | \
		grep -v RESTARTS | \
		grep -v Running | \
		grep 'alertmanager\|etcd0\|lcm\|restapi\|trainer\|trainingdata\|ui\|mongo\|prometheus\|pushgateway\|storage' > /dev/null; \
	do \
		sleep 5; \
	done
	@echo initialize monitoring dashboards
	@if [ "$$CI" != "true" ]; then bin/grafana.init.sh; fi
	@echo
	@echo System status:
	@make status

undeploy:         ## Undeploy the services from Kubernetes
	@# undeploy the stack
	@existing=$$(helm list | grep ffdl | awk '{print $$1}' | head -n 1); \
		(if [ ! -z "$$existing" ]; then echo "Undeploying the stack via helm. This may take a while."; helm delete "$$existing"; echo "The stack has been undeployed."; fi) > /dev/null;

$(addprefix undeploy-, $(SERVICES)): undeploy-%: %
	@SERVICE_NAME=$< make .undeploy-service

.undeploy-service:
	@echo deleting $(SERVICE_NAME)
	(kubectl delete deploy,svc,statefulset --selector=service="ffdl-$(SERVICE_NAME)")

rebuild-and-deploy-lcm: build-lcm docker-build-lcm undeploy-lcm deploy

rebuild-and-deploy-trainer: build-trainer docker-build-trainer undeploy-trainer deploy

status:           ## Print the current system status and service endpoints
	@tiller=s; \
		status_kube=$$(kubectl config current-context) && status_kube="Running (context '$$status_kube')" || status_kube="n/a"; \
		echo "Kubernetes:\t$$status_kube"; \
		node_ip=$$(make --no-print-directory kubernetes-ip); \
		status_tiller=$$(helm list 2> /dev/null) && status_tiller="Running" || status_tiller="n/a"; \
		echo "Helm/Tiller:\t$$status_tiller"; \
		status_ffdl=$$(helm list 2> /dev/null | grep ffdl | awk '{print $$1}' | head -n 1) && status_ffdl="Running ($$(helm status "$$status_ffdl" 2> /dev/null | grep STATUS:))" || status_ffdl="n/a"; \
		echo "FfDL Services:\t$$status_ffdl"; \
		port_api=$$(kubectl get service ffdl-restapi -o jsonpath='{.spec.ports[0].nodePort}' 2> /dev/null) && status_api="Running (http://$$node_ip:$$port_api)" || status_api="n/a"; \
		echo "REST API:\t$$status_api"; \
		port_ui=$$(kubectl get service ffdl-ui -o jsonpath='{.spec.ports[0].nodePort}' 2> /dev/null) && status_ui="Running (http://$$node_ip:$$port_ui/#/login?endpoint=$$node_ip:$$port_api&username=test-user)" || status_ui="n/a"; \
		echo "Web UI:\t\t$$status_ui"; \
		status_grafana=$$(kubectl get service grafana -o jsonpath='{.spec.ports[0].nodePort}' 2> /dev/null) && status_grafana="Running (http://$$node_ip:$$status_grafana) (login: admin/admin)" || status_grafana="n/a"; \
		echo "Grafana:\t$$status_grafana"

clean: clean-base clean-ratelimiter    ## clean all build artifacts
	rm -rf build; \
