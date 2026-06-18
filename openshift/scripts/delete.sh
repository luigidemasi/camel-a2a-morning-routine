#!/bin/bash

echo "========================================="
echo "A2A Morning Routine - OpenShift Cleanup"
echo "========================================="
echo ""

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Check if logged in to OpenShift
echo -e "${BLUE}Checking OpenShift login...${NC}"
if ! oc whoami &>/dev/null; then
  echo -e "${RED}Error: Not logged in to OpenShift${NC}"
  echo "Please login with: oc login --token=<token> --server=<server>"
  exit 1
fi

CURRENT_USER=$(oc whoami)
echo -e "${GREEN}✓ Logged in as: ${CURRENT_USER}${NC}"

# Check current project
NAMESPACE="a2a-morning-routine"
CURRENT_PROJECT=$(oc project -q 2>/dev/null || echo "")

if [ "$CURRENT_PROJECT" != "$NAMESPACE" ]; then
  echo -e "${YELLOW}Switching to project: ${NAMESPACE}${NC}"
  if ! oc project $NAMESPACE 2>/dev/null; then
    echo -e "${YELLOW}⚠ Project ${NAMESPACE} does not exist, nothing to delete${NC}"
    exit 0
  fi
fi
echo ""

# Show current resources
echo -e "${BLUE}Current resources in ${NAMESPACE}:${NC}"
oc get all -l app=a2a-morning-routine 2>/dev/null || echo "  (none found)"
echo ""

# Confirm deletion
echo -e "${RED}WARNING: This will delete ALL A2A Morning Routine resources!${NC}"
echo ""
read -p "Are you sure you want to continue? (yes/no): " -r
echo ""
if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
  echo -e "${YELLOW}Deletion cancelled${NC}"
  exit 0
fi

# Delete resources in reverse order of creation
echo -e "${BLUE}Deleting dashboard...${NC}"
oc delete deployment,service,route,configmap -l component=dashboard 2>/dev/null || echo "  (not found)"

echo -e "${BLUE}Deleting assistant...${NC}"
oc delete deployment,service,route,configmap -l component=assistant 2>/dev/null || echo "  (not found)"

echo -e "${BLUE}Deleting consumer agents...${NC}"
for agent in weather-agent news-agent fortune-agent traffic-agent email-agent package-agent breakfast-agent; do
  echo "  - $agent"
  oc delete deployment,service,route,configmap -l component=$agent 2>/dev/null || echo "    (not found)"
done

echo -e "${BLUE}Deleting Keycloak...${NC}"
oc delete statefulset,service,route,configmap -l component=keycloak 2>/dev/null || echo "  (not found)"

echo -e "${BLUE}Deleting PersistentVolumeClaims...${NC}"
oc delete pvc -l app=a2a-morning-routine 2>/dev/null || echo "  (none found)"

echo -e "${BLUE}Deleting BuildConfigs...${NC}"
oc delete bc -l app=a2a-morning-routine 2>/dev/null || echo "  (none found)"

echo -e "${BLUE}Deleting ImageStreams...${NC}"
oc delete is -l app=a2a-morning-routine 2>/dev/null || echo "  (none found)"

echo -e "${BLUE}Deleting any remaining resources...${NC}"
oc delete all -l app=a2a-morning-routine 2>/dev/null || echo "  (none found)"
echo ""

# Verify cleanup
echo -e "${GREEN}=========================================${NC}"
echo -e "${GREEN}Cleanup Complete!${NC}"
echo -e "${GREEN}=========================================${NC}"
echo ""

echo -e "${BLUE}Remaining resources (should be empty):${NC}"
REMAINING=$(oc get all -l app=a2a-morning-routine 2>/dev/null)
if [ -z "$REMAINING" ] || echo "$REMAINING" | grep -q "No resources found"; then
  echo -e "${GREEN}✓ All resources deleted successfully${NC}"
else
  echo "$REMAINING"
  echo ""
  echo -e "${YELLOW}⚠ Some resources may still be terminating${NC}"
  echo "Run this command to verify: oc get all -l app=a2a-morning-routine"
fi
echo ""

echo -e "${YELLOW}Note: The project '${NAMESPACE}' still exists.${NC}"
echo "To delete the project itself, run: oc delete project ${NAMESPACE}"
echo ""
