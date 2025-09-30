# Hello World Conf 2025

A sample setup of AWX, Prometheus, Grafana, Grafana MCP, and Event-Driven Ansible Controller on Docker Desktop for [Hello World Dev Conf 2025](https://hwdc.ithome.com.tw/2025/speaker-page/704)


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

#### Deployment
```bash
helm repo add awx-operator https://ansible-community.github.io/awx-operator-helm/

helm upgrade --install my-awx-operator awx-operator/awx-operator -n awx --create-namespace -f awx/values.yaml
```

#### UI
http://localhost:8081

```bash
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

#### Deployment

```bash
helm upgrade --install prometheus oci://ghcr.io/prometheus-community/charts/kube-prometheus-stack \
    --version 77.5.0 \
    -n prometheus --create-namespace \
    -f prometheus/values.yaml
```

#### UI
- http://localhost:3000

```bash
kubectl --namespace prometheus get secrets prometheus-grafana -o jsonpath="{.data.admin-password}" | base64 -d ; echo

# http://awx-service.awx.svc.cluster.local:8081/api/v2/job_templates/7/launch/
```

### Grafana MCP
- [Grafana MCP server](https://github.com/grafana/mcp-grafana)
```bash
bash grafana-mcp/setup.sh
```


### Event-Driven Ansible Controller

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


## Trigger Strategy

Choose AWX Direct Integration when:
- You have simple threshold-based alerting requirements
- Automation responses are straightforward (single playbook per alert)
- You want to minimize infrastructure complexity

Choose EDA Controller with AWX when:
- You have a lot of templates to be triggered
- You want to simplify the complex API call of template id with assigning template name
- You want to centralize the triggering logics from multiple sources
- Complex conditional logic and event processing is required

Comparison

| Aspect | AWX Direct | EDA + AWX |
|--------|-----------|-----------|
| Setup Complexity | Low | Medium |
| Template Reference | By ID | By Name |
| Multi-source Events | Manual per source | Centralized |
| Conditional Logic | Limited | Advanced |
| Best for | Few simple alerts | Lot of templates or complex logic |

### AWX Direct Integration
In this strategy, Grafana alerts directly trigger AWX automation workflows.

**Flow:**
- Prometheus scrapes metrics from Node Exporter
- Grafana queries Prometheus and evaluates alert conditions
- When a threshold is breached, Grafana triggers an AWX job template via webhook

![AWX Direct Integration](https://kroki.io/plantuml/svg/eNpdUsFu2zAMvfsrNF-WAE20FgNW9NQsCdoCSZs1LrKdDNpmbG2yZEhU2m7Yv49K0nSJL9Kj-R6pR157Akeh1ckHZUodKhQNUeevpHTwPKwVNaEIHl1pDaGhYWlb2WkwkTPwVGlVyPHnwSKGnuYz2YIndBzKx8wAZdANu6ifzEY_Hp6yfHWX3eaz6c30ftLrJ8lHMcE1ZwlqUPhXJrc-WW7P_KsNpgL32mutUWSdMvWZSOcHkPb_JIK_Q6Ve52yLrBQ8Jy4OIGWUqRYH_BCFXlRAUIDHGB9brbEkLzjXqdKLNdMEu1Ij-bR_UqB2sAYDzLvZ3aLEBHxTWHBVBPO9zEb5AFr9BlLWCDCVAI2Otm2fiBpbYY4vnXVsHUvcMxbTPX7XFPtWrTvqu7GeBho3qN-ekPajfvJ372MPnl-YMFp9j7xRINvumuKh0dq6Nv1_Dg719q9vVOeTR9RHpp62uiwddHhsXqwSl4hlI_1g2dFwvoX3UexYJ9m7pjOn6hrddoIrLBprf52Jx-kyE6PF3VshXlbOjsPdqBKHfL-6_HR5LqFTcnMhf9oiZxt4awm9_CI1BFM2Mr76Gk3Fy_kPvXsIVQ==)

<!-- ```plantuml
@startuml
!include https://raw.githubusercontent.com/plantuml-stdlib/C4-PlantUML/master/C4_Container.puml

LAYOUT_WITH_LEGEND()

' Define the systems
System_Boundary(monitoring, "Monitoring"){
    Container(prometheus, "Prometheus", "Time-series database", "Collects metrics from targets")
    Container(grafana, "Grafana", "Dashboard", "Metrics visualization and alerting")
    Container(node_exporter, "Node Exporter", "Metric Collector", "Collects host-level metrics")    
}
System(awx, "AWX", "Automation Platform")

' Define relationships
Rel(prometheus, node_exporter, "Scrapes metrics from", "http")
Rel(grafana, prometheus, "Queries data from")
Rel(grafana, awx, "Triggers", "Webhook, REST API", "http://awx-service.awx:8081/api/v2/job_templates/7/launch/")

@enduml
``` -->

This is a straightforward integration where Grafana acts as the bridge between monitoring and automation.

**When to use:**
- Simple threshold-based alerting requirements
- Minimal infrastructure complexity preferred

**Pros:**
- Simple architecture with fewer components
- Direct integration reduces latency
- Easy to troubleshoot
- Low operational overhead
- Quick to implement

**Cons:**
- Must manage AWX template IDs manually in Grafana webhooks
- No event correlation or aggregation
- Each alert source requires separate webhook configuration
- Limited conditional logic beyond alert thresholds


### EDA Controller with AWX
In this combined strategy, Grafana alerts trigger EDA Controller, which processes events and orchestrates AWX job execution.

**Flow:**
- Prometheus scrapes metrics from Node Exporter
- Grafana queries Prometheus and evaluates alert conditions
- When an alert fires, Grafana sends the event to EDA Controller
- EDA processes the event using rulebooks and decision logic
- EDA triggers AWX job templates by name using `run_job_template` action

![EDA Controller with AWX](https://kroki.io/plantuml/svg/eNptU01v2zAMvftXaLk0AebksvbQU7PE6AYkXbemyHYyZJux1cmSQVH5WLH_Psp20ySYLxJpvsfHD905kki-1tEHZXLtCxAVUeNuJxOUu3GpqPKZd4C5NQSGxrmtJ42WJmBiR4VW2WT2KX4MruflYlJLR4DsSmeMkMoAjpvAHy2mv749r9L119WXdJHcJw_z4SiKrsQcNhwlqALhDgyuXfTUnuln600h8TCsrVFkUZnyoxgsj8Zg9BoJ_o6Zhg3aGpjJOw58PBoDtlaqhpgLUeBEIUlm0kHwz6zWkJMTHIsqd2LDMMFdKYHcYHSRoES5kUYy7r67BYq5dFVmJRbBWPY0W-W81OqPJGWNkKYQUgNSK_uC1NgCUtg3Frl1TPHAtkh6-51T9FItnumurKNYwxb0WwmDUeCP_vZ9HMrdngHT9c-Am3qydSeKh0YbizUL6iOhCKUl82mrDkOKNlmy5dnHc1R8iqlxKtNwGnI6SATd0rtKNS76Abpj7UQke8g98Qh4hw6Ztb-dsCZkQG_SF5ulrIJ_ETBlgJ4O9LJNTznKBs4H18OOYzpbiO_-ffz_je7KX6EqS8B2a9aQVawyXMO74Gex6zwxC45ZcPwmeMzg2-vrm5vQjDswBS_9P1_1J00=)

<!-- ```plantuml
@startuml
!include https://raw.githubusercontent.com/plantuml-stdlib/C4-PlantUML/master/C4_Container.puml

LAYOUT_WITH_LEGEND()

' Define the systems
System_Boundary(monitoring, "Monitoring"){
    Container(prometheus, "Prometheus", "Time-series database", "Collects metrics from targets")
    Container(grafana, "Grafana", "Dashboard", "Metrics visualization and alerting")
    Container(node_exporter, "Node Exporter", "Metric Collector", "Collects host-level metrics")    
}
System(awx, "AWX", "Automation Platform")
System(eda, "EDA Controller", "Event-Driven Ansible Controller")

' Define relationships
Rel(eda, awx, "Executes playbooks on", "run_job_template")
Rel(prometheus, node_exporter, "Scrapes metrics from")
Rel(grafana, prometheus, "Queries data from")
Rel(grafana, eda, "Triggers", "Webhook", "http://webhook-run-job-template.eda:5566")

@enduml
``` -->

This model provides flexible event processing with centralized automation orchestration.

**When to use:**
- Many job templates to be triggered
- Want to reference templates by name instead of managing IDs
- Need to centralize triggering logic from multiple sources
- Complex conditional logic and event correlation required

**Pros:**
- Reference AWX templates by name, not ID
- Centralized event processing from multiple sources
- Powerful event correlation and aggregation
- Flexible conditional logic with rulebooks
- Event enrichment and transformation capabilities
- Single place to manage automation logic

**Cons:**
- More complex architecture
- Higher operational overhead
- Additional infrastructure component to maintain

> The EDA Controller UI does not provide built-in inventory configuration. No additional benefit to only have EDA crontroller for playbook execution.
