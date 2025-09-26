#!/usr/bin/env bash

# Configuration
EDA_CONTROLLER_URL="http://localhost:80"
USERNAME="admin"
PASSWORD=$(kubectl get secret my-eda-admin-password -n eda -o jsonpath="{.data.password}" | base64 --decode ; echo)
echo $PASSWORD

# Project details
PROJECT_NAME="my-ansible-project"
PROJECT_DESCRIPTION="Project for EDA rulebooks and playbooks"
SCM_URL="https://github.com/mansunkuo/hello-world-2025.git"
SCM_BRANCH="main"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Creating EDA Controller Project...${NC}"

# Function to check if command succeeded
check_status() {
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ $1${NC}"
    else
        echo -e "${RED}✗ $1${NC}"
        exit 1
    fi
}

AUTH_BASIC=$(printf $USERNAME:$PASSWORD | base64)
ORG_ID=$(curl -s -X GET \
    "${EDA_CONTROLLER_URL}/api/eda/v1/organizations/" \
    -H "Authorization: Basic $AUTH_BASIC" \
    -H "Content-Type: application/json" \
    | jq '.results[] | select(.name=="Default") | .id' \
    )
echo $ORG_RESPONSE
# Step 2: Create the project
echo "Creating project: $PROJECT_NAME"
# AUTH_BASIC=$(printf $USERNAME:$PASSWORD | base64)
PROJECT_RESPONSE=$(curl -s -X POST \
    "${EDA_CONTROLLER_URL}/api/eda/v1/projects/" \
    -H "Authorization: Basic $AUTH_BASIC" \
    -H "Content-Type: application/json" \
    -d "{
        \"name\": \"${PROJECT_NAME}\",
        \"description\": \"${PROJECT_DESCRIPTION}\",
        \"organization_id\": \"${ORG_ID}\",
        \"scm_type\": \"git\",
        \"url\": \"${SCM_URL}\",
        \"scm_branch\": \"${SCM_BRANCH}\",
        \"scm_refspec\": \"\",
        \"credential\": null,
        \"signature_validation_credential\": null,
        \"verify_ssl\": true
    }")
echo $PROJECT_RESPONSE
