
# Image URL to use all building/pushing image targets
IMG ?= kubeflow/training-operator:latest
# Produce CRDs that work back to Kubernetes 1.11 (no version conversion)
CRD_OPTIONS ?= "crd:trivialVersions=true,preserveUnknownFields=false,generateEmbeddedObjectMeta=true"

# Get the currently used golang install path (in GOPATH/bin, unless GOBIN is set)
ifeq (,$(shell go env GOBIN))
GOBIN=$(shell go env GOPATH)/bin
else
GOBIN=$(shell go env GOBIN)
endif

# Setting SHELL to bash allows bash commands to be executed by recipes.
# This is a requirement for 'setup-envtest.sh' in the test target.
# Options are set to exit when a recipe line exits non-zero or a piped command fails.
SHELL = /usr/bin/env bash -o pipefail
.SHELLFLAGS = -ec

all: build

##@ General

# The help target prints out all targets with their descriptions organized
# beneath their categories. The categories are represented by '##@' and the
# target descriptions by '##'. The awk commands is responsible for reading the
# entire set of makefiles included in this invocation, looking for lines of the
# file as xyz: ## something, and then pretty-format the target and help. Then,
# if there's a line with ##@ something, that gets pretty-printed as a category.
# More info on the usage of ANSI control characters for terminal formatting:
# https://en.wikipedia.org/wiki/ANSI_escape_code#SGR_parameters
# More info on the awk command:
# http://linuxcommand.org/lc3_adv_awk.php

help: ## Display this help.
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} /^[a-zA-Z_0-9-]+:.*?##/ { printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

##@ Development

manifests: controller-gen ## Generate WebhookConfiguration, ClusterRole and CustomResourceDefinition objects.
	$(CONTROLLER_GEN) $(CRD_OPTIONS) rbac:roleName=manager-role webhook paths="./pkg/apis/..." output:crd:artifacts:config=manifests/base/crds

generate: controller-gen ## Generate code containing DeepCopy, DeepCopyInto, and DeepCopyObject method implementations.
	$(CONTROLLER_GEN) object:headerFile="hack/boilerplate.go.txt" paths="./pkg/apis/..."

fmt: ## Run go fmt against code.
	go fmt ./...

vet: ## Run go vet against code.
	go vet ./...

GOLANGCI_LINT=$(shell which golangci-lint)
golangci-lint:
ifeq ($(GOLANGCI_LINT),)
	curl -sSfL https://raw.githubusercontent.com/golangci/golangci-lint/master/install.sh | sh -s -- -b $(shell go env GOPATH)/bin v1.42.1
	$(info golangci-lint has been installed)
endif
	golangci-lint run --timeout 5m ./...

ENVTEST_ASSETS_DIR=$(shell pwd)/testbin
test: manifests generate fmt vet golangci-lint ## Run tests.
	mkdir -p ${ENVTEST_ASSETS_DIR}
	test -f ${ENVTEST_ASSETS_DIR}/setup-envtest.sh || curl -sSLo ${ENVTEST_ASSETS_DIR}/setup-envtest.sh https://raw.githubusercontent.com/kubernetes-sigs/controller-runtime/v0.7.2/hack/setup-envtest.sh
	source ${ENVTEST_ASSETS_DIR}/setup-envtest.sh; fetch_envtest_tools $(ENVTEST_ASSETS_DIR); setup_envtest_env $(ENVTEST_ASSETS_DIR); go test ./... -coverprofile cover.out

##@ Build

build: generate fmt vet ## Build manager binary.
	go build -o bin/manager cmd/training-operator.v1/main.go

run: manifests generate fmt vet ## Run a controller from your host.
	go run ./cmd/training-operator.v1/main.go

docker-build: test ## Build docker image with the manager.
	docker build -t ${IMG} -f build/images/training-operator/Dockerfile .

docker-push: ## Push docker image with the manager.
	docker push ${IMG}

##@ Deployment

install: manifests kustomize ## Install CRDs into the K8s cluster specified in ~/.kube/config.
	$(KUSTOMIZE) build manifests/base/crds | kubectl apply -f -

uninstall: manifests kustomize ## Uninstall CRDs from the K8s cluster specified in ~/.kube/config.
	$(KUSTOMIZE) build manifests/base/crds | kubectl delete -f -

deploy: manifests kustomize ## Deploy controller to the K8s cluster specified in ~/.kube/config.
	cd manifests/overlays/standalone && $(KUSTOMIZE) edit set image kubeflow/training-operator=${IMG}
	$(KUSTOMIZE) build manifests/overlays/standalone | kubectl apply -f -

undeploy: ## Undeploy controller from the K8s cluster specified in ~/.kube/config.
	$(KUSTOMIZE) build manifests/overlays/standalone | kubectl delete -f -


CONTROLLER_GEN = $(shell pwd)/bin/controller-gen
controller-gen: ## Download controller-gen locally if necessary.
	$(call go-get-tool,$(CONTROLLER_GEN),sigs.k8s.io/controller-tools/cmd/controller-gen@v0.6.0)

KUSTOMIZE = $(shell pwd)/bin/kustomize
kustomize: ## Download kustomize locally if necessary.
	$(call go-get-tool,$(KUSTOMIZE),sigs.k8s.io/kustomize/kustomize/v3@v3.8.7)

# go-get-tool will 'go get' any package $2 and install it to $1.
PROJECT_DIR := $(shell dirname $(abspath $(lastword $(MAKEFILE_LIST))))
define go-get-tool
@[ -f $(1) ] || { \
set -e ;\
TMP_DIR=$$(mktemp -d) ;\
cd $$TMP_DIR ;\
go mod init tmp ;\
echo "Downloading $(2)" ;\
GOBIN=$(PROJECT_DIR)/bin go get $(2) ;\
rm -rf $$TMP_DIR ;\
}
endef


PROTO_BINARIES := $(GOPATH)/bin/protoc-gen-gogo $(GOPATH)/bin/protoc-gen-gogofast $(GOPATH)/bin/goimports $(GOPATH)/bin/protoc-gen-grpc-gateway

# protoc,my.proto
define protoc
	# protoc $(1)
    [ -e ./vendor ] || go mod vendor
    protoc \
      -I /usr/local/include \
      -I $(CURDIR) \
      -I $(CURDIR)/vendor \
      -I $(GOPATH)/src \
      -I $(GOPATH)/pkg/mod/github.com/gogo/protobuf@v1.3.1/gogoproto \
      -I $(GOPATH)/pkg/mod/github.com/grpc-ecosystem/grpc-gateway@v1.16.0/third_party/googleapis \
      --gogofast_out=plugins=grpc:$(GOPATH)/src \
      --grpc-gateway_out=logtostderr=true:$(GOPATH)/src \
      --swagger_out=logtostderr=true,fqn_for_swagger_name=true:. \
      $(1)

endef


$(GOPATH)/bin/mockery:
	go install github.com/vektra/mockery/v2@v2.10.0
$(GOPATH)/bin/controller-gen:
	go install sigs.k8s.io/controller-tools/cmd/controller-gen@v0.4.1
$(GOPATH)/bin/go-to-protobuf:
	go install k8s.io/code-generator/cmd/go-to-protobuf@v0.21.5
$(GOPATH)/src/github.com/gogo/protobuf:
	[ -e $(GOPATH)/src/github.com/gogo/protobuf ] || git clone --depth 1 https://github.com/gogo/protobuf.git -b v1.3.2 $(GOPATH)/src/github.com/gogo/protobuf
$(GOPATH)/bin/protoc-gen-gogo:
	go install github.com/gogo/protobuf/protoc-gen-gogo@v1.3.2
$(GOPATH)/bin/protoc-gen-gogofast:
	go install github.com/gogo/protobuf/protoc-gen-gogofast@v1.3.2
$(GOPATH)/bin/protoc-gen-grpc-gateway:
	go install github.com/grpc-ecosystem/grpc-gateway/protoc-gen-grpc-gateway@v1.16.0
$(GOPATH)/bin/protoc-gen-swagger:
	go install github.com/grpc-ecosystem/grpc-gateway/protoc-gen-swagger@v1.16.0
$(GOPATH)/bin/openapi-gen:
	go install k8s.io/kube-openapi/cmd/openapi-gen@v0.0.0-20210421082810-95288971da7e
$(GOPATH)/bin/goimports:
	go install golang.org/x/tools/cmd/goimports@v0.1.7



pkg/apis/pytorch/v1/generated.proto: $(GOPATH)/bin/go-to-protobuf $(PROTO_BINARIES) $(TYPES) $(GOPATH)/src/github.com/gogo/protobuf
	# These files are generated on a v3/ folder by the tool. Link them to the root folder
	# Format proto files. Formatting changes generated code, so we do it here, rather that at lint time.
	# Why clang-format? Google uses it.
	$(GOPATH)/bin/go-to-protobuf \
		--go-header-file=./hack/boilerplate/boilerplate.go.txt \
		--packages=github.com/kubeflow/training-operator/pkg/apis/pytorch/v1 \
		--apimachinery-packages=+k8s.io/apimachinery/pkg/util/intstr,+k8s.io/apimachinery/pkg/api/resource,+k8s.io/apimachinery/pkg/runtime/schema,+k8s.io/apimachinery/pkg/runtime,k8s.io/apimachinery/pkg/apis/meta/v1,k8s.io/apimachinery/pkg/apis/meta/v1beta1,k8s.io/api/core/v1,k8s.io/api/policy/v1beta1,k8s.io/api/autoscaling/v2beta2,github.com/kubeflow/common/pkg/apis/common/v1,+sigs.k8s.io/controller-runtime/pkg/scheme \
		--proto-import $(GOPATH)/src
	# Delete the link
	touch pkg/apis/pytorch/v1/generated.proto



