# Quarkus Native Prototype (Java 25, Gradle)

Public prototype of a **Quarkus-based backend application** focused on **fast cold start** and **native image execution** using **GraalVM / Mandrel**.

This repository is intended as a **reference implementation** and starting point for:
- modern Java backend development without Spring,
- monolithic applications prepared for Kubernetes,
- experiments with Java 25, AOT, and native images,
- evaluating startup time and memory footprint.

---

## Technology Stack

- **Java**: 25  
- **Build Tool**: Gradle (Wrapper)  
- **Framework**: Quarkus  
- **HTTP API**: REST (JAX-RS)  
- **JSON**: Jackson  
- **Health Checks**: SmallRye Health  
- **Native Image**: GraalVM / Mandrel (container build)  
- **Target Platform**: Kubernetes (Linux)

---

## Project Structure

```
.
├── build.gradle
├── settings.gradle
├── gradle.properties
├── gradlew
├── gradlew.bat
├── gradle/
│   └── wrapper/
├── k8s/
│   ├── deployment.yaml
│   ├── service.yaml
│   ├── ingress.yaml
│   └── hpa.yaml
├── src/
│   ├── main/
│   │   ├── java/com/acme/GreetingResource.java
│   │   └── resources/application.properties
│   └── test/
│       └── java/com/acme/GreetingResourceTest.java
└── README.md
```

---

## Prerequisites

Recommended environment: **Linux / WSL2**.

Required:
- **JDK 25**
- **Docker** (for native image builds)
- Bash-compatible shell

Verification:
```bash
java -version
docker version
```

---

## Installing Java 25 (WSL / Ubuntu)

This project uses **Gradle Toolchains** and requires **Java 25** to be available locally.
Automatic JDK download is intentionally disabled to keep builds reproducible.

### Install Eclipse Temurin 25

```bash
sudo apt-get update
sudo apt-get install -y wget gpg apt-transport-https ca-certificates

wget -qO- https://packages.adoptium.net/artifactory/api/gpg/key/public \
  | sudo gpg --dearmor -o /usr/share/keyrings/adoptium.gpg

echo "deb [signed-by=/usr/share/keyrings/adoptium.gpg] https://packages.adoptium.net/artifactory/deb $(lsb_release -cs) main" \
  | sudo tee /etc/apt/sources.list.d/adoptium.list

sudo apt-get update
sudo apt-get install -y temurin-25-jdk
```

Verify:
```bash
/usr/lib/jvm/temurin-25-jdk-amd64/bin/java -version
```

---

## Gradle Toolchain Configuration

Tell Gradle where Java 25 is installed.

Add to `gradle.properties`:

```properties
org.gradle.java.installations.paths=/usr/lib/jvm/temurin-25-jdk-amd64
```

Restart Gradle daemons:

```bash
./gradlew --stop
```

---

## Running in Development Mode (JVM)

```bash
chmod +x gradlew
./gradlew quarkusDev
```

Application endpoints:
- http://localhost:8080/hello
- http://localhost:8080/q/health/ready
- http://localhost:8080/q/health/live

---

## Running Tests

```bash
./gradlew test
```

---

## Building a Native Image

Native image is built **inside a container**, no local GraalVM installation required.

```bash

./gradlew clean build \
  -Dquarkus.native.enabled=true \
  -Dquarkus.package.jar.enabled=false \
  -Dquarkus.native.container-build=true \
  -Dquarkus.native.builder-image=quay.io/quarkus/ubi9-quarkus-mandrel-builder-image:jdk-25

```

Result:
- Linux native executable: `build/*-runner`

---

## Docker (Native Runtime Image)

Example minimal Dockerfile:

```dockerfile
FROM registry.access.redhat.com/ubi9/ubi-minimal:9.4

WORKDIR /work/
COPY build/*-runner /work/application

EXPOSE 8080
USER 1001

ENTRYPOINT ["/work/application", "-Dquarkus.http.host=0.0.0.0"]
```

Build and run:

```bash
docker build -f Dockerfile.native -t quarkus-native-proto:0.1.0 .
docker run --rm -p 8080:8080 quarkus-native-proto:0.1.0
```

---

## Kubernetes Manifests (`k8s/`)

Kubernetes manifests are stored under `k8s/` to keep the README concise and the deployment artifacts versioned and reviewable.

### Included manifests

- `k8s/deployment.yaml`  
  Runs the native binary container and defines probes and resource requests/limits.

- `k8s/service.yaml`  
  Exposes the Deployment internally as a `ClusterIP` service on port 80 -> container port 8080.

- `k8s/ingress.yaml` (optional)  
  Example Ingress definition (NGINX-style annotations). Adjust host, annotations, and class for your cluster.

- `k8s/hpa.yaml` (optional)  
  HorizontalPodAutoscaler v2 example using CPU utilization.

### Apply manifests

Assuming your image is available to the cluster (pushed to a registry, or loaded into a local cluster):

```bash
kubectl apply -f k8s/service.yaml
kubectl apply -f k8s/deployment.yaml
```

Optional:

```bash
kubectl apply -f k8s/ingress.yaml
kubectl apply -f k8s/hpa.yaml
```

### Health probes

The Deployment is configured to use Quarkus SmallRye Health endpoints:

- Liveness: `GET /q/health/live`
- Readiness: `GET /q/health/ready`
- Startup: `GET /q/health/live`

`startupProbe` is important to prevent premature restarts during initialization.

### Update the image

Edit `k8s/deployment.yaml` and update:

```yaml
image: quarkus-native-proto:0.1.0
```

to your registry tag, e.g.:

```yaml
image: ghcr.io/<org>/<repo>:0.1.0
```

---

## Why There Is No `main` Class

Quarkus manages the application entry point internally.
No user-defined `main` class is required for HTTP services.

This design:
- reduces bootstrap overhead,
- improves native image compatibility,
- enables faster cold start.

---

## Project Scope

This repository is intentionally minimal and suitable for:
- learning Quarkus fundamentals,
- benchmarking JVM vs native startup,
- evolving into a modular monolith,
- serving as a reference for cloud-native Java.

---

---

## Local Kubernetes quickstart (no remote registry)

This section describes how to run the application **locally in Kubernetes**
without pushing the image to any remote registry.

Two local cluster options are supported:
- **kind** (recommended)
- **minikube**

The application is built as a **native image** and packaged into a local Docker image.

---

### Option A: kind (recommended)

#### 1) Create a local cluster (if not already created)

```bash
kind create cluster
```

Verify:
```bash
kubectl cluster-info
```

---

#### 2) Build the native executable

```bash
./gradlew clean build   -Dquarkus.package.type=native   -Dquarkus.native.container-build=true
```

This produces a Linux native binary: `build/*-runner`.

---

#### 3) Build the Docker image locally

```bash
docker build -f Dockerfile.native -t quarkus-native-proto:0.1.0 .
```

Verify:
```bash
docker images | grep quarkus-native-proto
```

---

#### 4) Load the image into kind

```bash
kind load docker-image quarkus-native-proto:0.1.0
```

This copies the image directly into the kind node images.

---

#### 5) Verify deployment image configuration

Ensure `k8s/deployment.yaml` uses the local image and does not pull from a registry:

```yaml
image: quarkus-native-proto:0.1.0
imagePullPolicy: IfNotPresent
```

---

#### 6) Apply Kubernetes manifests

```bash
kubectl apply -f k8s/service.yaml
kubectl apply -f k8s/deployment.yaml
```

---

#### 7) Check rollout status

```bash
kubectl get pods
kubectl rollout status deployment/quarkus-native-proto
```

---

#### 8) Access the application (port-forward)

```bash
kubectl port-forward svc/quarkus-native-proto 8080:80
```

Verify:
```bash
curl http://localhost:8080/hello
curl http://localhost:8080/q/health/ready
```

---

### Option B: minikube

#### 1) Start minikube

```bash
minikube start
```

---

#### 2) Use the minikube Docker daemon

```bash
eval $(minikube docker-env)
```

This makes `docker build` push images directly into minikube.

---

#### 3) Build the Docker image

```bash
docker build -f Dockerfile.native -t quarkus-native-proto:0.1.0 .
```

---

#### 4) Apply Kubernetes manifests

```bash
kubectl apply -f k8s/service.yaml
kubectl apply -f k8s/deployment.yaml
```

---

#### 5) Access the application

```bash
kubectl port-forward svc/quarkus-native-proto 8080:80
```

---

### Logs and troubleshooting

```bash
kubectl logs -l app=quarkus-native-proto -f
kubectl describe pod -l app=quarkus-native-proto
```

---

### Cleanup

```bash
kubectl delete -f k8s/deployment.yaml
kubectl delete -f k8s/service.yaml
```

(optional)
```bash
kubectl delete -f k8s/ingress.yaml
kubectl delete -f k8s/hpa.yaml
```

---

### Why no remote registry is required

- `kind load docker-image` copies images directly into cluster nodes
- `minikube docker-env` builds images inside the cluster Docker daemon
- `imagePullPolicy: IfNotPresent` prevents Kubernetes from pulling images remotely


---

## Local Kubernetes workflow (Kustomize + Makefile)

For local development on Kubernetes without a remote registry, the repository includes:

- `k8s/base/` — base manifests (Deployment + Service)
- `k8s/overlays/local/` — local overlay (image tag, pull policy, smaller resource limits)
- `Makefile` — one-command workflow for native build, image build, loading into kind, and deployment

### Deploy to kind in one command

```bash
make k8s-run
```

Then, in another terminal:

```bash
make port-forward
```

And run a quick smoke test:

```bash
make smoke
```

### Apply manifests without Makefile

```bash
kubectl apply -k k8s/overlays/local
kubectl rollout status deployment/quarkus-native-proto
kubectl port-forward svc/quarkus-native-proto 8080:80
```

### Notes

- `k8s/overlays/local/kustomization.yaml` pins the image tag to `0.1.0` by default.
  Update `newTag` when you change the image version.
- The local overlay enforces `imagePullPolicy: IfNotPresent` to avoid pulling from remote registries.


## License

MIT


### Minikube
Use `make minikube-run` to build and deploy without a remote registry.
