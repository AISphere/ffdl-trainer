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

deploy-nfs-volume:
	@export TARGET_SERVER="ffdltest.sl.cloud9.ibm.com"; \
		./create_static_pv.sh

undeploy-cos-plugin:
	@kubectl delete pvc/static-volume-1 cm/static-volumes cm/static-volumes-v2; \
		kubectl delete deployment ibmcloud-object-storage-plugin -n kube-system; \
		kubectl delete clusterRole ibmcloud-object-storage-plugin ibmcloud-object-storage-secret-reader; \
		kubectl delete sa ibmcloud-object-storage-plugin -n kube-system; \
		kubectl delete sc ibmc-s3fs-standard;

setup-cos-plugin:
	@./deploy_cos_driver.sh

create-volumes:
	@./create_static_volumes.sh
		./create_static_volumes_config.sh