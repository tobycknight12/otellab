# **New Relic Open Telemetry Lab**

# **Lab 1: Local K8s Observability with Docker, Minikube & New Relic**

This lab provides a complete, step-by-step guide to building a local Kubernetes development environment on an Ubuntu machine. You will install all the necessary tools to run and observe a local cluster:

1. **Docker Engine:** The container runtime that powers everything.  
2. **Minikube:** A tool to run a single-node Kubernetes cluster locally.  
3. **New Relic Pipeline Control Gateway:** A service that will run *inside* your cluster to manage and filter your observability data.

## **Prerequisites**

* An Ubuntu (or Debian-based) system (e.g., Ubuntu 22.04 LTS).  
* A user account with `sudo` privileges.  
* A New Relic account. You will need your **New Relic License Key**.

## **Part 1: Install Docker Engine**

First, we will install the Docker Engine and CLI. We will use the official Docker `apt` repository to ensure we get the latest stable version.

### **1.1 Clean Up Old Versions**

To prevent conflicts, remove any old or unofficial Docker packages:

```
sudo apt-get remove docker docker-engine docker.io containerd runc
```

*(It's okay if this command reports that no packages were found.)*

### **1.2 Set Up the Docker Repository**

Next, we add Docker's official GPG key and `apt` repository.

```
# Update apt and install prerequisites
sudo apt-get update
sudo apt-get install -y ca-certificates curl gpg

# Add Docker's official GPG key
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL [https://download.docker.com/linux/ubuntu/gpg](https://download.docker.com/linux/ubuntu/gpg) -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Add the repository to Apt sources
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] [https://download.docker.com/linux/ubuntu](https://download.docker.com/linux/ubuntu) \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
```

### **1.3 Install Docker Engine**

Now, install the Docker packages:

```
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```

### **1.4 Post-Install: Run Docker as a Non-Root User (Recommended)**

By default, you must use `sudo` for every Docker command. To fix this, add your user to the `docker` group.

```
sudo usermod -aG docker $USER
```

**CRITICAL:** You must **log out and log back in** for this change to take effect.

### **1.5 Verify Docker Installation**

After logging back in, test your installation (without `sudo`):

```
docker run hello-world
```

You should see a "Hello from Docker\!" message.

## **Part 2: Install Minikube & kubectl**

Now we'll install Minikube to run our local cluster and `kubectl` to control it.

### **2.1 Install Minikube Binary**

Download and install the latest Minikube binary:

```
curl -LO [https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64](https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64)
sudo install minikube-linux-amd64 /usr/local/bin/minikube
rm minikube-linux-amd64
```

### **2.2 Install kubectl**

Minikube includes its own version of `kubectl`, but it's best practice to install the official binary.

```
curl -LO "[https://dl.k8s.io/release/$(curl](https://dl.k8s.io/release/$(curl) -L -s [https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl](https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl)"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
rm kubectl
```

### **2.3 Start the Minikube Cluster**

Start your Kubernetes cluster using the Docker driver you just installed. This may take a few minutes as it downloads the cluster images.

```
minikube start --driver=docker
```

### **2.4 Verify Cluster Status**

Check that your cluster is running and `kubectl` is configured:

```
minikube status
kubectl get nodes
```

You should see your `minikube` node with a `Ready` status.

## **Part 3: Install New Relic Control Gateway**

Finally, we will deploy the New Relic Pipeline Control Gateway *into* our Minikube cluster. The easiest way to do this is with Helm (the Kubernetes package manager).

### **3.1 Install Helm**

We'll use a simple script to install Helm:

```
curl -fsSL -o get_helm.sh [https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3](https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3)
chmod 700 get_helm.sh
./get_helm.sh
rm get_helm.sh
```

### **3.2 Add the New Relic Helm Repository**

Make Helm aware of the official New Relic chart repository:

```
helm repo add newrelic [https://helm-charts.newrelic.com](https://helm-charts.newrelic.com)
helm repo update
```

### **3.3 Install the Gateway**

You are now ready to install the gateway. Replace `YOUR_LICENSE_KEY` with your actual New Relic license key.

This command will:

1. Create a new namespace called `newrelic`.  
2. Install the `newrelic-agent-control` chart.  
3. Configure it with your license key.

```
helm upgrade --install agent-control newrelic/newrelic-agent-control \
  --namespace newrelic --create-namespace \
  --set newrelic.licenseKey=YOUR_LICENSE_KEY
```

### **3.4 Verify the Gateway Installation**

Check that the New Relic pods are running inside your cluster.

```
kubectl get pods --namespace newrelic
```

You should see a pod (e.g., `agent-control-newrelic-agent-control-...`) with a status of `Running`.

## **Part 4: Inspect the Gateway Configuration**

The New Relic Gateway's configuration is not stored in a static file inside the pod. Instead, Helm generates the configuration and stores it as a **Kubernetes ConfigMap**. The gateway pod automatically reads this ConfigMap.

### **4.1 How to View the Live Configuration**

You can inspect the full configuration file being used by the running gateway with these commands.

1. **Find the ConfigMap name:**

```
kubectl get configmap -n newrelic
```

2.   
   (The name will be similar to `pipeline-control-gateway-config`)  
3. **Display the full configuration:** Replace the name from the command above to get the full YAML output.

```
kubectl get configmap pipeline-control-gateway-config -n newrelic -o yaml
```

### **4.2 Example `config.yaml` Content**

For reference, the default configuration generated by Helm looks similar to this. This is the file you would be inspecting with the command above.

```
extensions:
  zpages:
  healthcheckv2:
    use_v2: true
    component_health:
      include_permanent_errors: false
      include_recoverable_errors: true
      recovery_duration: 5m
    http:
      endpoint: ${env:MY_POD_IP}:13133
      status:
        enabled: true
        path: "/health/status"
      config:
        enabled: true
        path: "/health/config"

receivers:
  nrproprietaryreceiver:
    nr_host: "collector.newrelic.com"
    logging:
      enable: false
    logfilter:
      enabled: false
      flush_interval: 5s
      pattern: .*
      buffer_size: 262144
    enable_default_host: false
    enable_runtime_metrics: true
    proxy: false
    endpoints:
      event_api_endpoint: "[https://insights-collector.newrelic.com](https://insights-collector.newrelic.com)"
      infra_event_api_endpoint: "[https://infra-api.newrelic.com](https://infra-api.newrelic.com)"
      log_api_endpoint: "[https://log-api.newrelic.com](https://log-api.newrelic.com)"
      metrics_endpoint: "[https://metric-api.newrelic.com](https://metric-api.newrelic.com)"
      traces_endpoint: "[https://trace-api.newrelic.com](https://trace-api.newrelic.com)"
    server:
      endpoint: ${env:MY_POD_IP}:80
    client:
      compression: gzip
      timeout: 10s
  otlp:
    protocols:
      http:
        endpoint: ${env:MY_POD_IP}:4318
      grpc:
        endpoint: ${env:MY_POD_IP}:4317
  prometheus/usage:
    config:
      scrape_configs:
        - job_name: 'pipeline-gateway-usage'
          scrape_interval: 60s
          static_configs:
            - targets: [ '0.0.0.0:8888' ]
              labels:
                version: 1.2.0
                podName: '${env:MY_POD_NAME}'
                clusterName: controldemo
                serviceName: 'pipeline-control-gateway'
          metric_relabel_configs:
            - source_labels: [ __name__ ]
              regex: '.*bytes_received.*'
              action: keep
  prometheus/monitoring:
    config:
      scrape_configs:
        - job_name: 'pipeline-gateway-monitoring'
          scrape_interval: 15s
          static_configs:
            - targets: [ '0.0.0.0:8888' ]
              labels:
                version: 1.2.0
                podName: '${env:MY_POD_NAME}'
                clusterName: controldemo
                serviceName: 'pipeline-control-gateway'
          metric_relabel_configs:
            - action: labeldrop
              regex: 'service_version|service_name|service_instance_id'
            - source_labels: [ __name__ ]
              regex: 'godebug_.*'
              action: drop

processors:
  memory_limiter:
    check_interval: 1s
    limit_mib: 100
  nrprocessor:
    queue:
      enabled: true
      queue_size: 100
    queries:
  cumulativetodelta:

exporters:
  otlp:
    endpoint: "otlp.nr-data.net:443"
    headers:
      api-key: ${env:NEW_RELIC_LICENSE_KEY}
  otlphttp:
    endpoint: "[https://otlp.nr-data.net](https://otlp.nr-data.net)"
    headers:
      api-key: ${env:NEW_RELIC_LICENSE_KEY}
  nrcollectorexporter:
    endpoint: "[https://log-api.newrelic.com](https://log-api.newrelic.com)"
    retry_on_failure:
      enabled: true
      initial_interval: 100ms
      max_interval: 500ms
      max_elapsed_time: 5s
    timeout: 10s
    sending_queue:
      enabled: false
    compression: gzip
    encoding: json
    nr_license_key: ${env:NEW_RELIC_LICENSE_KEY}
  usageexporter:
    endpoint: [https://collector.newrelic.com/external-usage](https://collector.newrelic.com/external-usage)
    headers:
      api-key: ${env:NEW_RELIC_LICENSE_KEY}

service:
  extensions: [ healthcheckv2 ]

  pipelines:
    logs/nr:
      receivers: [nrproprietaryreceiver]
      processors: [nrprocessor]
      exporters: [nrcollectorexporter]
    logs/otlp:
      receivers: [ otlp ]
      processors: [ nrprocessor ]
      exporters: [ otlp ]
    metrics/nr:
      receivers: [nrproprietaryreceiver]
      processors: [nrprocessor]
      exporters: [nrcollectorexter]
    metrics/otlp:
      receivers: [otlp]
      processors: [ nrprocessor]
      exporters: [otlp]
    traces/otlp:
      receivers: [otlp]
      processors: [nrprocessor]
      exporters: [ otlp ]
    traces/nr:
      receivers: [ nrproprietaryreceiver ]
      processors: [ nrprocessor ]
      exporters: [ nrcollectorexporter ]
    metrics/usage:
      receivers: [prometheus/usage]
      processors: [cumulativetodelta]
      exporters: [usageexporter]
    metrics/monitoring:
      receivers: [prometheus/monitoring]
      processors: []
      exporters: [otlphttp]

  telemetry:
    metrics:
      level: detailed
```

# **Lab 2: Java Auto-Instrumentation with OTel (to full New Relic APM)**

This lab guide will walk you through instrumenting a simple Java application *without modifying any source code*. We will use the OpenTelemetry (OTel) automatic Java agent and the **New Relic OTel Extensions** to capture telemetry and see it as a full APM service in New Relic.

This fixes the common issue where OTel data appears as a generic "OpenTelemetry" service instead of a rich "APM" service with Golden Signals.

## **Prerequisites**

* **Ubuntu Host:** An Ubuntu system with `curl` installed.  
* **Maven Installed**  
* **Docker:** You must have Docker installed and running.  
* **New Relic Account:** You will need your **New Relic License Key**.

## **Part 1: Create the Simple Java Application**

This step is the same as before.

1. Create a new directory for your lab (e.g., `otel-java-lab`) and `cd` into it.  
2. Create the `SimpleJavaApp.java` file (provided).  
3. Create the `Dockerfile` file (provided).

Your directory should look like this:

```
otel-java-lab/
├── SimpleJavaApp.java
└── Dockerfile
```

## **Part 2: Download the OTel Agent** 

1. **The standard OTel Agent:**

```
curl -L -o opentelemetry-javaagent.jar https://github.com/open-telemetry/opentelemetry-java-instrumentation/releases/latest/download/opentelemetry-javaagent.jar

```

Your directory should now have all three files:

```
otel-java-lab/
├── SimpleJavaApp.java
├── Dockerfile
├── opentelemetry-javaagent.jar

```

*(You can run `ls -l` to confirm they both have a size greater than 0 bytes).*

## **Part 3: Build and Run the APM-Enabled App**

1. **Build the Docker Image:**

```
docker build -t otel-java-lab .
```

2. **Run the Container with OTel \+ New Relic Extensions:** **Remember to replace `YOUR_NEW_RELIC_LICENSE_KEY` with your actual key.**

```
docker run -d -p 8080:8080   --name otel-java-app   -v "$(pwd)/opentelemetry-javaagent.jar:/app/opentelemetry-javaagent.jar"   -e JAVA_TOOL_OPTIONS="-javaagent:/app/opentelemetry-javaagent.jar"   -e OTEL_RESOURCE_ATTRIBUTES="service.name=simple-java-app"   -e OTEL_EXPORTER_OTLP_PROTOCOL="http/protobuf"   -e OTEL_METRICS_EXPORTER="otlp"   -e OTEL_TRACES_EXPORTER="otlp"   -e OTEL_LOGS_EXPORTER="none"     -e OTEL_EXPORTER_OTLP_ENDPOINT="https://otlp.nr-data.net:443"   -e OTEL_EXPORTER_OTLP_HEADERS="api-key=YOUR-API-KEY"     otel-java-lab

```

## **Part 4: Generate Data and View in New Relic**

1. **Generate Traffic:** Run this command a few times in your terminal:

```
curl http://localhost:8080/hello
```

2. And the other endpoint:

```
curl http://localhost:8080/
```

3. **Check the Container Logs (Optional but Recommended):** You can verify the extensions are loaded by checking the logs.

```
docker logs otel-java-apm-app
```

4. **View in New Relic:**  
   * Go to your New Relic account and navigate to **APM & Services**.  
   * After a minute or two, you will see your new service: **`simple-java-apm-app`**.  
   * When you click on it, you should now see the full, rich **APM Summary** page with Golden Signals (Throughput, Latency, Error Rate).

## **Cleanup**

```
docker stop otel-java-apm-app
docker rm otel-java-apm-app
```

