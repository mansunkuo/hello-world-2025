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

# curl -i -X GET "http://localhost/api/eda/v1/auth/session/login/" -c cookies.txt
# CSRF_TOKEN=$(awk '/csrftoken/ {print $NF}' cookies.txt)
# echo "CSRF_TOKEN: $CSRF_TOKEN"

# # Step 1: Authenticate and get token
# echo "Authenticating with EDA Controller..."
# AUTH_RESPONSE=$(curl -s -X POST \
#     "${EDA_CONTROLLER_URL}/api/eda/v1/auth/session/login/" \
#     -H "Content-Type: application/json" \
#     -H "X-CSRFToken: $CSRF_TOKEN" \
#     -b cookies.txt \
#     -d "{
#         \"username\": \"${USERNAME}\",
#         \"password\": \"${PASSWORD}\"
#     }")

# check_status "Authentication request sent"
# echo $AUTH_RESPONSE
# # Extract token (adjust based on actual response format)
# TOKEN=$(echo "$AUTH_RESPONSE" | jq -r '.token // .access_token // .key // empty')
# echo $TOKEN
# if [ -z "$TOKEN" ] || [ "$TOKEN" = "null" ]; then
#     echo -e "${RED}Failed to extract authentication token${NC}"
#     echo "Response: $AUTH_RESPONSE"
#     exit 1
# fi

# echo -e "${GREEN}Authentication successful${NC}"

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
# check_status "Project creation request sent"

# # Check if project was created successfully
# PROJECT_ID=$(echo "$PROJECT_RESPONSE" | jq -r '.id // empty')

# if [ -z "$PROJECT_ID" ] || [ "$PROJECT_ID" = "null" ]; then
#     echo -e "${RED}Failed to create project${NC}"
#     echo "Response: $PROJECT_RESPONSE"
#     exit 1
# fi

# echo -e "${GREEN}Project created successfully!${NC}"
# echo "Project ID: $PROJECT_ID"
# echo "Project Name: $PROJECT_NAME"

# # Step 3: Check project status
# echo "Checking project sync status..."
# sleep 2
# PROJECT_STATUS=$(curl -s -X GET \
#     "${EDA_CONTROLLER_URL}/api/eda/v1/projects/${PROJECT_ID}/" \
#     -H "Authorization: Bearer $TOKEN")

# STATUS=$(echo "$PROJECT_STATUS" | jq -r '.import_state // .status // "unknown"')
# echo "Project Status: $STATUS"

# # Optional: Wait for project to sync
# echo "Waiting for project synchronization..."
# COUNTER=0
# MAX_WAIT=30

# while [ "$STATUS" = "pending" ] || [ "$STATUS" = "running" ]; do
#     if [ $COUNTER -ge $MAX_WAIT ]; then
#         echo -e "${YELLOW}Timeout waiting for sync. Check project status manually.${NC}"
#         break
#     fi
    
#     sleep 5
#     COUNTER=$((COUNTER + 5))
    
#     PROJECT_STATUS=$(curl -s -X GET \
#         "${EDA_CONTROLLER_URL}/api/eda/v1/projects/${PROJECT_ID}/" \
#         -H "Authorization: Bearer $TOKEN")
    
#     STATUS=$(echo "$PROJECT_STATUS" | jq -r '.import_state // .status // "unknown"')
#     echo "Current status: $STATUS (${COUNTER}s elapsed)"
# done

# if [ "$STATUS" = "successful" ] || [ "$STATUS" = "completed" ]; then
#     echo -e "${GREEN}✓ Project synchronized successfully!${NC}"
# elif [ "$STATUS" = "failed" ] || [ "$STATUS" = "error" ]; then
#     echo -e "${RED}✗ Project synchronization failed${NC}"
#     echo "Check the EDA Controller UI for details"
# else
#     echo -e "${YELLOW}Project created but sync status unclear: $STATUS${NC}"
# fi

# echo -e "${GREEN}Done!${NC}"
# echo "You can now view your project at: ${EDA_CONTROLLER_URL}/#/projects/${PROJECT_ID}"