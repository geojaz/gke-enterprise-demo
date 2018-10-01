# Copyright 2018 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

PROJECT := $(shell gcloud config get-value core/project)
ROOT := ${CURDIR}/
SHELL := /usr/bin/env bash

# default bazel go containers don't even have a shell to exec into for debugging. 
# -c dbg gives you busybox. comment it out for production
DEBUG?=-c dbg

# add any bazel build options here
BAZEL_OPTIONS?=

IMAGE_REGISTRY?=gcr.io
PYRIOS_REPO?=pso-examples/pyrios
PYRIOS_UI_REPO?=pso-examples/pyrios-ui

.PHONY: bootstrap
bootstrap:
	gcloud services enable \
	  cloudresourcemanager.googleapis.com \
	  compute.googleapis.com \
	  container.googleapis.com \
	  cloudbuild.googleapis.com \
	  containerregistry.googleapis.com \
	  logging.googleapis.com \
	  bigquery-json.googleapis.com

# Step 2: terraform is used to automate the terraform workflow
.PHONY: deploy-infra
deploy-infra:
	terraform fmt
	terraform validate -check-variables=false
	terraform init
	terraform apply -var "project=$(PROJECT)" -auto-approve

# Step 3: configure the k8s context by generateing a k8s.env, decoupling the
# k8s configurations from the scripts
.PHONY: config
config:
	$(ROOT)/configure.sh

# Step 4: create kubernetes objects
.PHONY: create
create:
	$(ROOT)/create.sh

# Step 5: Expose the elasticsearch API endpoint localhost:9200 via the laptop/desktop
.PHONY: expose
expose:
	$(ROOT)/expose.sh

.PHONY: close-expose
close-expose:
	killall kubectl

# Step 6: load the shakespeare data via the elasticsearch API endpoint
.PHONY: load
load:
	$(ROOT)/load-shakespeare.sh

# Step 7: Valide the data via the elasticsearch API endpoint
.PHONY: validate
validate:
	$(ROOT)/validate.sh

# Step 8: Expose the UI on localhost:8080 via the laptop/desktop
.PHONY: expose-ui
expose-ui:
	$(ROOT)/expose-ui.sh

# Step 9: tear down kubernetes and the rest of GCP infrastructure used
.PHONY: teardown
teardown:
	$(ROOT)/teardown.sh

# .PHONY: push-pyrios
# push-pyrios:
# 	docker push ${PYRIOS_DOCKER_REPO}:${PYRIOS_VERSION}

# .PHONY: push-pyrios-ui
# push-pyrios-ui:
# 	docker push ${PYRIOS_UI_DOCKER_REPO}:${PYRIOS_UI_VERSION}	


################################################################################################
#                      Bazel new world order 9/26/18                                           #
################################################################################################
.PHONY: bazel-clean
bazel-clean:
	bazel clean --expunge

.PHONY: bazel-test
bazel-test:
	bazel ${BAZEL_OPTIONS} test //pyrios/... //pyrios-ui/... //hack:verify-all --test_output=errors

# build for your host OS, for local development/testing (not in docker)
.PHONY: bazel-build-pyrios
bazel-build-pyrios:
	bazel build ${BAZEL_OPTIONS} --features=pure //pyrios/...

.PHONY: bazel-build-pyrios-ui
bazel-build-pyrios-ui:
	bazel build ${BAZEL_OPTIONS} --features=pure //pyrios-ui/...	

.PHONY: bazel-build
bazel-build: bazel-build-pyrios bazel-build-pyrios-ui

.PHONY: bazel-build-pyrios-image
bazel-build-pyrios-image:
	bazel run ${BAZEL_OPTIONS} ${DEBUG} \
		--platforms=@io_bazel_rules_go//go/toolchain:linux_amd64 \
		--define REGISTRY=${IMAGE_REGISTRY} \
		--define REPOSITORY=${PYRIOS_REPO} \
		--define TAG=${PYRIOS_TAG} \
		//app_repos/pyrios:go_image

.PHONY: bazel-build-pyrios-ui-image
bazel-build-pyrios-ui-image:
	bazel run ${BAZEL_OPTIONS} ${DEBUG} \
		--platforms=@io_bazel_rules_go//go/toolchain:linux_amd64 \
		--define REGISTRY=${IMAGE_REGISTRY} \
		--define REPOSITORY=${PYRIOS_UI_REPO} \
		--define TAG=${PYRIOS_UI_TAG} \
		//pyrios-ui:go_image

.PHONY: bazel-build-images
bazel-build-images: bazel-build-pyrios-image bazel-build-pyrios-ui-image

.PHONY: bazel-push-pyrios
bazel-push-pyrios:
	bazel run ${BAZEL_OPTIONS} ${DEBUG} \
		--platforms=@io_bazel_rules_go//go/toolchain:linux_amd64 \
		--define REGISTRY=${IMAGE_REGISTRY} \
		--define REPOSITORY=${PYRIOS_REPO} \
		--define TAG=${PYRIOS_TAG} \
		--define BUILD_USER="${BUILD_USER}" \
		//app_repos/pyrios:push			

.PHONY: bazel-push-pyrios-ui
bazel-push-pyrios-ui:
	bazel run ${BAZEL_OPTIONS} ${DEBUG} \
		--platforms=@io_bazel_rules_go//go/toolchain:linux_amd64 \
        --define REGISTRY=${IMAGE_REGISTRY} \
		--define REPOSITORY=${PYRIOS_UI_REPO} \
		--define TAG=${PYRIOS_UI_TAG} \
		//app_repos/pyrios-ui:push

.PHONY: bazel-push-images
bazel-push-images: bazel-push-pyrios bazel-push-pyrios-ui

# .PHONY: bazel-deploy-pyrios
# bazel-deploy-pyrios: 
# 	bazel run ${BAZEL_OPTIONS} \
# 	    --platforms=@io_bazel_rules_go//go/toolchain:linux_amd64 \
# 		//app_repos/pyrios :dev.create		
#       --define REGISTRY=${IMAGE_REGISTRY} \
#		--define REPOSITORY=${PYRIOS_REPO} \
		

bazel-push-images: bazel-push-pyrios bazel-push-pyrios-ui

################################################################################################
#                                 kubernetes helpers                                           #
################################################################################################

.PHONY: deploy
deploy:
	kubectl apply -f pyrios/manifests/
	kubectl apply -f pyrios-ui/manifests/

################################################################################################
#                                 testing helpers                                              #
################################################################################################

.PHONY: gofmt
gofmt:
	gofmt -s -w pyrios-ui/
	gofmt -s -w pyrios/
