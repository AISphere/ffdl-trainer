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

#####################################################
# Dynamically get the commons makefile for shared
# variables and targets.
#####################################################
CM_REPO ?= raw.githubusercontent.com/ffdl-commons
CM_VERSION ?= master
CM_MK_LOC ?= .
CM_MK_NM ?= "ffdl-commons.mk"

# If the .mk file is changed on commons, and the file already exists here, it seems to update, but might take a while.
# Delete the file and try again to make sure, if you are having trouble.
CM_MK=$(shell wget -N https://${CM_REPO}/${CM_VERSION}/${CM_MK_NM} -P ${CM_MK_LOC} > /dev/null 2>&1 && echo "${CM_MK_NM}")

include $(CM_MK)

## show variable used in commons .mk include mechanism
show_cm_vars:
	@echo CM_REPO=$(CM_REPO)
	@echo CM_VERSION=$(CM_VERSION)
	@echo CM_MK_LOC=$(CM_MK_LOC)
	@echo CM_MK_NM=$(CM_MK_NM)

#####################################################

# Rate limiter proto is a plugin, so we don't need/want REPO or VERSION
RATELIMITER_LOCATION ?= vendor/github.com/AISphere/ffdl-trainer/plugins/ratelimiter
RATELIMITER_SUBDIR ?= service/grpc_ratelimiter_v1
RATELIMITER_PROTO_LOC ?= plugins/ratelimiter
RATELIMITER_FNAME ?= ratelimiter

protoc-ratelimiter:  ## Make the rate limiter plugin client, depends on `make glide` being run first
	rm -rf $(RATELIMITER_LOCATION)/$(RATELIMITER_SUBDIR)
	mkdir -p $(RATELIMITER_LOCATION)/$(RATELIMITER_SUBDIR)
	protoc -I./$(RATELIMITER_PROTO_LOC) --go_out=plugins=grpc:$(RATELIMITER_LOCATION)/$(RATELIMITER_SUBDIR) ./$(RATELIMITER_PROTO_LOC)/$(RATELIMITER_FNAME).proto
	@# At the time of writing, protoc does not support custom tags, hence use a little regex to add "bson:..." tags
	@# See: https://github.com/golang/protobuf/issues/52
	cd $(RATELIMITER_LOCATION); \
	sed -i .bak '/.*bson:.*/! s/json:"\([^"]*\)"/json:"\1" bson:"\1"/' ./$(RATELIMITER_SUBDIR)/$(RATELIMITER_FNAME).pb.go

protoc: protoc-lcm protoc-tds protoc-ratelimiter  ## Make gRPC proto clients, depends on `make glide` being run first

build-x86-64: lint
	CGO_ENABLED=0 GOOS=linux go build -ldflags "-s" -a -installsuffix cgo -o bin/main

test-deps-start:
	docker run --name mongo-trainer -p 27017:27017 -d mongo:3.0 --smallfiles

test-deps-stop:
	docker rm -f mongo-trainer

# Runs all unit tests (short tests)
test-unit:          ## Run unit tests
	DLAAS_LOGLEVEL=debug DLAAS_DNS_SERVER=disabled DLAAS_ENV=local go test $(TEST_PKGS) -v -short

#clean:
#	rm -rf build

.PHONY: lint
