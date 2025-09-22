#!/usr/bin/env bash

GRAFANA_URL="http://localhost:3000"
GRAFANA_USER="admin"
GRAFANA_PASS="$(kubectl get secret -n prometheus prometheus-grafana -o jsonpath="{.data.admin-password}" | base64 --decode)"

# Create a Service Account
SERVICE_ACCOUNT_NAME=my-service-account
SERVICE_ACCOUNT_ID=$(curl -s -X GET -u "$GRAFANA_USER:$GRAFANA_PASS" "$GRAFANA_URL/api/serviceaccounts/search?query=my-service-account" | jq -r '.serviceAccounts[0].id')

if [ -z "$SERVICE_ACCOUNT_ID" ]; then
  echo "Service account 'my-service-account' not found. Creating it..."
  curl -s -X POST \
    -u "$GRAFANA_USER:$GRAFANA_PASS" \
    -H "Content-Type: application/json" \
    -d '{"name":"$SERVICE_ACCOUNT_NAME","role":"Admin"}' \
    "$GRAFANA_URL/api/serviceaccounts"
  
  SERVICE_ACCOUNT_ID=$(curl -s -X GET -u "$GRAFANA_USER:$GRAFANA_PASS" "$GRAFANA_URL/api/serviceaccounts/search?query=my-service-account" | jq -r '.serviceAccounts[0].id')
  echo "Service account 'my-service-account' created with ID: $SERVICE_ACCOUNT_ID"
else
  echo "Service account 'my-service-account' already exists with ID: $SERVICE_ACCOUNT_ID"
fi

# Create a token for the Service Account
TOKEN_NAME="my-token"
TOKEN_EXISTS=$(curl -s -X GET -u "$GRAFANA_USER:$GRAFANA_PASS" "$GRAFANA_URL/api/serviceaccounts/$SERVICE_ACCOUNT_ID/tokens" | jq -r --arg TOKEN_NAME "$TOKEN_NAME" '.[] | select(.name == $TOKEN_NAME) | .name')

if [ -z "$TOKEN_EXISTS" ]; then
  echo "Token '$TOKEN_NAME' not found for service account ID $SERVICE_ACCOUNT_ID. Creating it..."
  TOKEN_RESPONSE=$(curl -s -X POST \
    -u "$GRAFANA_USER:$GRAFANA_PASS" \
    -H "Content-Type: application/json" \
    -d '{"name":"my-token"}' \
    "$GRAFANA_URL/api/serviceaccounts/$SERVICE_ACCOUNT_ID/tokens")
  
  TOKEN=$(echo "$TOKEN_RESPONSE" | jq -r '.key')
  # echo "Token '$TOKEN_NAME' created. Token: $TOKEN"

  ENCODED_TOKEN=$(echo -n "$TOKEN" | base64)
  SECRET_NAME="prometheus-grafana-api-key-$SERVICE_ACCOUNT_NAME-$TOKEN_NAME"
  SECRET_FILE="grafana-mcp/$SECRET_NAME.yaml"

  cat <<EOF > "$SECRET_FILE"
apiVersion: v1
kind: Secret
metadata:
  name: $SECRET_NAME
  namespace: prometheus
type: Opaque
data:
  api-key: $ENCODED_TOKEN
EOF

  echo "Kubernetes secret manifest created at $SECRET_FILE"
  kubectl apply -f "$SECRET_FILE"
  echo "Kubernetes secret '$SECRET_NAME' applied."
  
else
  echo "Token '$TOKEN_NAME' already exists for service account ID $SERVICE_ACCOUNT_ID."
  TOKEN=$(kubectl get secrets -n prometheus prometheus-grafana-api-key-$SERVICE_ACCOUNT_NAME-$TOKEN_NAME -o=jsonpath='{.data.api-key}' | base64 --decode)
  # echo "Token '$TOKEN_NAME'. Token: $TOKEN"
fi

# Use host.docker.internal to connect to grafana instance
# https://docs.docker.com/desktop/features/networking/#i-want-to-connect-from-a-container-to-a-service-on-the-host
if [ -z "$MCP_GRAFANA_URL" ]; then
  MCP_GRAFANA_URL=http://host.docker.internal:3000
fi
echo "Running MCP server with Docker and connect to $MCP_GRAFANA_URL"
docker run --rm -i \
  -e GRAFANA_URL=$MCP_GRAFANA_URL \
  -e GRAFANA_SERVICE_ACCOUNT_TOKEN=$TOKEN \
  -p 8000:8000 mcp/grafana \
  -debug

