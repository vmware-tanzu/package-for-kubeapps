# Copyright 2022 the Kubeapps contributors.
# SPDX-License-Identifier: Apache-2.0

PACKAGE_VERSION_SUFFIX ?= ""

# Avoid variables evaluation
registry_user=$(shell echo "$$REGISTRY_USER")
registry_token=$(shell echo "$$REGISTRY_TOKEN")

default: package-stg

build-packager-image:
	DOCKER_BUILDKIT=1 docker build --progress=plain -t kubeapps/carvel-packager -f ./Dockerfile .

package-stg: check-env check-version clear
	docker run --rm \
  		--name carvel-packager \
		--net kind \
  		--volume ${PWD}:/usr/src/packager \
		--volume /var/run/docker.sock:/var/run/docker.sock \
		--env REGISTRY_USER='$(registry_user)' \
		--env REGISTRY_TOKEN='$(registry_token)' \
		kubeapps/carvel-packager \
		/usr/src/packager/package-kubeapps-version.sh -s ${PACKAGE_VERSION_SUFFIX} ${PACKAGE_VERSION}

package-prd: check-env check-version clear
	docker run --rm \
  		--name carvel-packager \
		--net kind \
  		--volume ${PWD}:/usr/src/packager \
		--volume /var/run/docker.sock:/var/run/docker.sock \
		--env REGISTRY_USER='$(registry_user)' \
		--env REGISTRY_TOKEN='$(registry_token)' \
		kubeapps/carvel-packager \
		/usr/src/packager/package-kubeapps-version.sh -p ${PACKAGE_VERSION}

clear: check-version
	rm -rf ./${PACKAGE_VERSION}${PACKAGE_VERSION_SUFFIX}

check-version:
ifndef PACKAGE_VERSION
	$(error PACKAGE_VERSION is undefined)
endif

check-env:
ifndef REGISTRY_USER
	$(error REGISTRY_USER is undefined)
endif
ifndef REGISTRY_TOKEN
	$(error REGISTRY_TOKEN is undefined)
endif

.PHONY: default check-version check-env build-packager-image package-stg package-prd
