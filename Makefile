\
APP_NAME ?= quarkus-native-proto
VERSION  ?= 0.1.0
IMAGE    ?= $(APP_NAME):$(VERSION)

KUSTOMIZE_PATH ?= k8s/overlays/local
PORT ?= 8080

.PHONY: help
help:
	@echo "Targets:"
	@echo "  make native         Build native executable (container build)"
	@echo "  make image          Build Docker image (native runtime)"
	@echo "  make kind-up        Create a kind cluster (if none exists)"
	@echo "  make kind-load      Load the local Docker image into kind"
	@echo "  make k8s-apply      Apply manifests via kustomize overlay"
	@echo "  make k8s-run        native + image + kind-load + k8s-apply"
	@echo "  make port-forward   Port-forward service to localhost:$(PORT)"
	@echo "  make smoke          Smoke test /hello and /q/health/ready"
	@echo "  make logs           Follow pod logs"
	@echo "  make k8s-delete     Delete resources applied by the overlay"
	@echo "  make kind-down      Delete the kind cluster"

.PHONY: native
native:
	./gradlew clean build \
      -Dquarkus.native.enabled=true \
      -Dquarkus.package.jar.enabled=false \
      -Dquarkus.native.container-build=true \
      -Dquarkus.native.builder-image=quay.io/quarkus/ubi9-quarkus-mandrel-builder-image:jdk-25



.PHONY: image
image:
	docker build -f Dockerfile.native -t $(IMAGE) .

.PHONY: kind-up
kind-up:
	kind get clusters >/dev/null 2>&1 || true
	@if kind get clusters | grep -q "^kind$$"; then \
		echo "kind cluster 'kind' already exists"; \
	else \
		kind create cluster; \
	fi

.PHONY: kind-load
kind-load:
	kind load docker-image $(IMAGE)

.PHONY: k8s-apply
k8s-apply:
	kubectl apply -k $(KUSTOMIZE_PATH)

.PHONY: k8s-delete
k8s-delete:
	kubectl delete -k $(KUSTOMIZE_PATH) --ignore-not-found

.PHONY: port-forward
port-forward:
	kubectl port-forward svc/$(APP_NAME) $(PORT):80

.PHONY: logs
logs:
	kubectl logs -l app=$(APP_NAME) -f

.PHONY: smoke
smoke:
	@echo "Waiting for deployment rollout..."
	kubectl rollout status deployment/$(APP_NAME)
	@echo "Running smoke checks (requires port-forward in another terminal)..."
	curl -fsS http://localhost:$(PORT)/hello | head -c 200 && echo
	curl -fsS http://localhost:$(PORT)/q/health/ready | head -c 200 && echo


.PHONY: minikube-up
minikube-up:
	@minikube status >/dev/null 2>&1 && echo "minikube is running" || minikube start

.PHONY: minikube-env
minikube-env:
	@echo "Run the following in your shell to use the minikube Docker daemon:"
	@echo "  eval $$(minikube docker-env)"

.PHONY: minikube-run
minikube-run: native minikube-up
	@echo "Switching Docker to minikube daemon for this command only..."
	@bash -lc 'eval $$(minikube docker-env) && docker build -f Dockerfile.native -t $(IMAGE) .'
	$(MAKE) k8s-apply
	@echo "Done. Run 'make port-forward' in another terminal, then 'make smoke'."

.PHONY: k8s-run
k8s-run: native image kind-up kind-load k8s-apply
	@echo "Done. Run 'make port-forward' in another terminal, then 'make smoke'."
