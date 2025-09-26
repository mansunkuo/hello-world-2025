# Hello World Conf 2025

A sample setup of AWX, Prometheus, Grafana, Grafana MCP, and Event-Driven Ansible on Docker Desktop for [Hello World Dev Conf 2025](https://hwdc.ithome.com.tw/2025/speaker-page/704)

## Trigger Strategy
### AWX 
In this strategy, Grafana alerts directly trigger AWX.  
- Prometheus scrapes metrics from Node Exporter.  
- Grafana queries Prometheus for metrics and, when a threshold is breached, it triggers an automation workflow in AWX.  

This is a straightforward integration where Grafana acts as the bridge between monitoring and automation.  

```plantuml
@startuml
!include https://raw.githubusercontent.com/plantuml-stdlib/C4-PlantUML/master/C4_Container.puml

LAYOUT_WITH_LEGEND()

' Define the systems
System_Boundary(monitoring, "Monitoring"){
    Container(prometheus, "Prometheus", "Time-series database", "Collects metrics from targets")
    Container(grafana, "Grafana", "Dashboard", "Visualizes metrics from Prometheus")
    Container(node_exporter, "Node Exporter", "Agent", "Collects host-level metrics")    
}
System(awx, "AWX", "Automation Platform")

' Define relationships
Rel(prometheus, node_exporter, "Scrapes metrics from")
Rel(grafana, prometheus, "Queries data from")
Rel(grafana, awx, "Triggers")

@enduml
```

### EDA
In this strategy, Grafana alerts trigger EDA directly, without involving AWX.  

- Prometheus scrapes metrics, and Grafana evaluates them.  
- When an alert condition is met, Grafana sends the trigger to EDA.  
- EDA processes the event using rulebooks and handles actions directly within EDA.  

This model provides the flexibility of EDA’s event-driven engine, making it well-suited for lightweight automation without the overhead of AWX.  
```plantuml
@startuml
!include https://raw.githubusercontent.com/plantuml-stdlib/C4-PlantUML/master/C4_Container.puml

LAYOUT_WITH_LEGEND()

' Define the systems
System_Boundary(monitoring, "Monitoring"){
    Container(prometheus, "Prometheus", "Time-series database", "Collects metrics from targets")
    Container(grafana, "Grafana", "Dashboard", "Visualizes metrics from Prometheus")
    Container(node_exporter, "Node Exporter", "Agent", "Collects host-level metrics")    
}
System(eda, "EDA", "Event-Driven Automation")

' Define relationships
Rel(prometheus, node_exporter, "Scrapes metrics from")
Rel(grafana, prometheus, "Queries data from")
Rel(grafana, eda, "Triggers")

@enduml
```

### EDA with AWX 
In this combined strategy, Grafana alerts trigger EDA, and EDA orchestrates AWX.
- Prometheus scrapes metrics, and Grafana evaluates them.
- When an alert condition is met, Grafana sends the trigger to EDA.
- EDA processes the event using rulebooks, then delegates execution of more complex or scheduled automation tasks to AWX.

This model provides the flexibility of EDA’s event-driven engine with the robust job execution and inventory management of AWX.
```plantuml
@startuml
!include https://raw.githubusercontent.com/plantuml-stdlib/C4-PlantUML/master/C4_Container.puml

LAYOUT_WITH_LEGEND()

' Define the systems
System_Boundary(monitoring, "Monitoring"){
    Container(prometheus, "Prometheus", "Time-series database", "Collects metrics from targets")
    Container(grafana, "Grafana", "Dashboard", "Visualizes metrics from Prometheus")
    Container(node_exporter, "Node Exporter", "Agent", "Collects host-level metrics")    
}
System(awx, "AWX", "Automation Platform")
System(eda, "EDA", "Event-Driven Automation")

' Define relationships
Rel(eda, awx, "Executes playbooks on")
Rel(prometheus, node_exporter, "Scrapes metrics from")
Rel(grafana, prometheus, "Queries data from")
Rel(grafana, eda, "Triggers")

@enduml
```

## Setup
### Essential Tools for k8s
- [Docker Desktop](https://docs.docker.com/desktop/)
- [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/)
    - [kustomize](https://kubernetes.io/docs/tasks/manage-kubernetes-objects/kustomization/)
- [helm](https://helm.sh/docs/intro/install/)
- [Linux stress command With Examples](https://www.geeksforgeeks.org/linux-unix/linux-stress-command-with-examples/)
- [uv](https://github.com/astral-sh/uv)

### AWX 
- [AWX Operator Helm Chart](https://github.com/ansible-community/awx-operator-helm/)
- [Ansible AWX Operator Documentation](https://ansible.readthedocs.io/projects/awx-operator/en/latest/installation/basic-install.html)
```bash
helm repo add awx-operator https://ansible-community.github.io/awx-operator-helm/

helm upgrade --install my-awx-operator awx-operator/awx-operator -n awx --create-namespace -f awx/values.yaml

# http://localhost:8081
kubectl get secrets -n awx awx-admin-password -o jsonpath='{.data.password}' | base64 --decode ; echo
```

Trigger a job:
```bash
# https://grafana.com/docs/grafana-cloud/monitor-infrastructure/integrations/integration-reference/integration-awx/
AWX_HOST="http://localhost:8081/"
ADMIN_PASSWORD=$(kubectl get secrets -n awx awx-admin-password -o jsonpath='{.data.password}' | base64 --decode)
AWX_TOKEN=$(printf admin:$ADMIN_PASSWORD | base64)
AWX_JOB_TEMPLATE_ID="7"
curl -X POST "$AWX_HOST/api/v2/job_templates/$AWX_JOB_TEMPLATE_ID/launch/" \
    -H "Content-Type: application/json" \
    -H "Authorization: Basic $AWX_TOKEN" \
    -d '{
        "extra_vars": {
        }
    }'
```

Get metrics:
```bash
AWX_HOST="http://localhost:8081/"
ADMIN_PASSWORD=$(kubectl get secrets -n awx awx-admin-password -o jsonpath='{.data.password}' | base64 --decode)
AWX_TOKEN=$(printf admin:$ADMIN_PASSWORD | base64)
curl -X GET "$AWX_HOST/api/v2/metrics/" \
    -H "Content-Type: application/json" \
    -H "Authorization: Basic $AWX_TOKEN"
```

Uninstall:
```bash
helm uninstall -n awx my-awx-operator
```

### Prometheus & Grafana
- [kube-prometheus-stack](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack)

```bash
helm upgrade --install prometheus oci://ghcr.io/prometheus-community/charts/kube-prometheus-stack \
    --version 77.5.0 \
    -n prometheus --create-namespace \
    -f prometheus/values.yaml

kubectl --namespace prometheus get secrets prometheus-grafana -o jsonpath="{.data.admin-password}" | base64 -d ; echo

# http://awx-service.awx.svc.cluster.local:8081/api/v2/job_templates/7/launch/
```

### Grafana MCP
- [Grafana MCP server](https://github.com/grafana/mcp-grafana)
```bash
bash grafana-mcp/setup.sh
```


### Event-Driven Ansible 

- [EDA Server Operator](https://github.com/ansible/eda-server-operator)
    - [Install EDA Server Operator with Kustomize](https://github.com/ansible/eda-server-operator/blob/main/docs/kustomize-install.md)
- [EDA Server](https://github.com/ansible/eda-server/tree/main)

#### Deployment
```bash
# operator
kubectl kustomize eda | kubectl apply -f - 

# eda
kubectl apply -f eda/eda.yaml -n eda
```
#### UI
http://localhost:80

```bash
# admin secret
kubectl get secret my-eda-admin-password -n eda -o jsonpath="{.data.password}" | base64 --decode ; echo
```
#### API
http://localhost:80/api

### Ansible
- [Ansible Rulebook](https://ansible.readthedocs.io/projects/rulebook/en/latest/)

Check EDA collection:
```bash
# Install globally
uv tool install ansible-core

# Install EDA collection
ansible-galaxy collection install ansible.eda
cp -r ~/.ansible/collections/ansible_collections/ansible/eda/extensions ~/.ansible/collections/ansible_collections/ansible/eda/playbooks .
```

Test rulebook locally:
```bash
# Run local with Docker
docker run -it --rm \
  -v "$(pwd)":/workdir \
  -w /workdir \
  -p 5555:5555 \
  quay.io/ansible/ansible-rulebook:latest \
  ansible-rulebook \
    -i inventories/local/hosts \
    -r extensions/eda/rulebooks/demo_webhook_rulebook.yml \
    --verbose

# Basic curl command to trigger the webhook
curl -X POST http://localhost:5555/ \
  -H "Content-Type: application/json" \
  -d '{"message": "Hello from curl"}'
```

With Ansible Galaxy:
```bash
docker run -it --rm \
  -v "$(pwd)":/workdir \
  -w /workdir \
  quay.io/ansible/ansible-rulebook:latest \
  ansible-rulebook \
    -i inventories/local/hosts \
    -r extensions/eda/rulebooks/hello_events.yml \
    --verbose
```

With local playbook
```bash
docker run -it --rm \
  -v "$(pwd)":/workdir \
  -w /workdir \
  quay.io/ansible/ansible-rulebook:latest \
  ansible-rulebook \
    -i inventories/local/hosts \
    -r extensions/eda/rulebooks/hello_events_local.yml \
    --verbose

```

Ansible Builder:
```bash
uv tool install ansible-builder

ansible-builder build \
    -f decision-environment-eda-galaxy.yaml \
    -t ghcr.io/mansunkuo/hello-world-2025/eda-galaxy:v1.2.0 \
    -v3

# https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-container-registry
echo $CR_PAT | docker login ghcr.io -u mansunkuo --password-stdi
docker push ghcr.io/mansunkuo/hello-world-2025/eda-galaxy:v1.2.0
```