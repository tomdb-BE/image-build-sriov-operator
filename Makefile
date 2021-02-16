SEVERITIES = HIGH,CRITICAL

ifeq ($(ARCH),)
ARCH=$(shell go env GOARCH)
endif

ORG ?= rancher
TAG ?= release-4.8

ifneq ($(DRONE_TAG),)
TAG := $(DRONE_TAG)
endif

.PHONY: image-build-operator
image-build-operator:
	docker build \
		--build-arg ARCH=$(ARCH) \
		--build-arg TAG=$(TAG) \
		--tag $(ORG)/hardened-sriov-operator:$(TAG) \
		--tag $(ORG)/hardened-sriov-operator:$(TAG)-$(ARCH) \
	.

.PHONY: image-push-operator
image-push-operator:
	docker push $(ORG)/hardened-sriov-operator:$(TAG)-$(ARCH)

.PHONY: image-manifest-operator
image-manifest-operator:
	DOCKER_CLI_EXPERIMENTAL=enabled docker manifest create --amend \
		$(ORG)/hardened-sriov-operator:$(TAG) \
		$(ORG)/hardened-sriov-operator:$(TAG)-$(ARCH)
	DOCKER_CLI_EXPERIMENTAL=enabled docker manifest push \
		$(ORG)/hardened-sriov-operator:$(TAG)

.PHONY: image-scan-operator
image-scan-operator:
	trivy --severity $(SEVERITIES) --no-progress --ignore-unfixed $(ORG)/hardened-sriov-operator:$(TAG)

.PHONY: image-build-network-config-daemon
image-build-network-config-daemon:
	docker build \
		-f Dockerfile.sriov-network-config-daemon \
		--build-arg ARCH=$(ARCH) \
		--build-arg TAG=$(TAG) \
		--tag $(ORG)/hardened-network-config-daemon:$(TAG) \
		--tag $(ORG)/hardened-network-config-daemon:$(TAG)-$(ARCH) \
	.

.PHONY: image-push-network-config-daemon
image-push-network-config-daemon:
	docker push $(ORG)/hardened-network-config-daemon:$(TAG)-$(ARCH)

.PHONY: image-manifest-network-config-daemon
image-manifest-network-config-daemon:
	DOCKER_CLI_EXPERIMENTAL=enabled docker manifest create --amend \
		$(ORG)/hardened-network-config-daemon:$(TAG) \
		$(ORG)/hardened-network-config-daemon:$(TAG)-$(ARCH)
	DOCKER_CLI_EXPERIMENTAL=enabled docker manifest push \
		$(ORG)/hardened-network-config-daemon:$(TAG)

.PHONY: image-scan-network-config-daemon
image-scan-network-config-daemon:
	trivy --severity $(SEVERITIES) --no-progress --ignore-unfixed $(ORG)/hardened-network-config-daemon:$(TAG)

