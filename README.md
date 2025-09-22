# Hello World Conf 2025

A sample setup of AWX, Prometheus, Grafana, Grafana MCP, and Event-Driven Ansible on Docker Desktop for [Hello World Dev Conf 2025](https://hwdc.ithome.com.tw/2025/speaker-page/704)

## Essential Tools for k8s
- [Docker Desktop](https://docs.docker.com/desktop/)
- [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/)
    - [kustomize](https://kubernetes.io/docs/tasks/manage-kubernetes-objects/kustomization/)
- [helm](https://helm.sh/docs/intro/install/)
- [Linux stress command With Examples](https://www.geeksforgeeks.org/linux-unix/linux-stress-command-with-examples/)
- [uv](https://github.com/astral-sh/uv)

## AWX 
- [AWX Operator Helm Chart](https://github.com/ansible-community/awx-operator-helm/)
- [Ansible AWX Operator Documentation](https://ansible.readthedocs.io/projects/awx-operator/en/latest/installation/basic-install.html)
```bash
helm repo add awx-operator https://ansible-community.github.io/awx-operator-helm/
# helm install my-awx-operator awx-operator/awx-operator

# git clone https://github.com/ansible-community/awx-operator-helm.git
# cd awx-operator-helm

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

## Prometheus & Grafana
- [kube-prometheus-stack](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack)

```bash
helm upgrade --install prometheus oci://ghcr.io/prometheus-community/charts/kube-prometheus-stack \
    --version 77.5.0 \
    -n prometheus --create-namespace \
    -f prometheus/values.yaml

kubectl --namespace prometheus get secrets prometheus-grafana -o jsonpath="{.data.admin-password}" | base64 -d ; echo

# http://awx-service.awx.svc.cluster.local:8081/api/v2/job_templates/7/launch/
```

## Grafana MCP
- [Grafana MCP server](https://github.com/grafana/mcp-grafana)
```bash
bash grafana-mcp/setup.sh
```


## Event-Driven Ansible 

- [EDA Server Operator](https://github.com/ansible/eda-server-operator)
- [Install EDA Server Operator with Kustomize](https://github.com/ansible/eda-server-operator/blob/main/docs/kustomize-install.md)

```bash
# operator
kubectl kustomize eda | kubectl apply -f - 

# eda
kubectl apply -f eda/eda.yaml -n eda

# admin secret
kubectl get secret my-eda-admin-password -n eda -o jsonpath="{.data.password}" | base64 --decode ; echo
```

## Ansible
- [Ansible Rulebook](https://ansible.readthedocs.io/projects/rulebook/en/latest/)

```bash
# Install globally
uv tool install ansible-core

# Install EDA collection
ansible-galaxy collection install ansible.eda

# Run local with Docker
docker run -it --rm \
  -v "$(pwd)":/workdir \
  -w /workdir \
  -p 5555:5555 \
  quay.io/ansible/ansible-rulebook:latest \
  ansible-rulebook \
    -i inventories/local/hosts \
    -r rulebooks/demo_webhook_rulebook.yml \
    --verbose

# Basic curl command to trigger the webhook
curl -X POST http://localhost:5555/ \
  -H "Content-Type: application/json" \
  -d '{"message": "Hello from curl"}'
```