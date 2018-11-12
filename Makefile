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

clean: clean-base clean-ratelimiter    ## clean all build artifacts
	rm -rf build; \
