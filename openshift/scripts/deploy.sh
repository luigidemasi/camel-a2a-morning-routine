#!/bin/bash
set -e

echo "========================================="
echo "A2A Morning Routine - OpenShift Deploy"
echo "========================================="
echo ""

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check if logged in to OpenShift
echo -e "${BLUE}Checking OpenShift login...${NC}"
if ! oc whoami &>/dev/null; then
  echo -e "${RED}Error: Not logged in to OpenShift${NC}"
  echo "Please login with: oc login --token=<token> --server=<server>"
  exit 1
fi

CURRENT_USER=$(oc whoami)
CURRENT_PROJECT=$(oc project -q 2>/dev/null || echo "")
echo -e "${GREEN}✓ Logged in as: ${CURRENT_USER}${NC}"

# Check if namespace exists, create if needed
NAMESPACE="a2a-morning-routine"
if [ -z "$CURRENT_PROJECT" ] || [ "$CURRENT_PROJECT" != "$NAMESPACE" ]; then
  echo -e "${YELLOW}Setting up project: ${NAMESPACE}${NC}"
  oc project $NAMESPACE 2>/dev/null || oc new-project $NAMESPACE
fi
echo -e "${GREEN}✓ Using project: ${NAMESPACE}${NC}"
echo ""

# Deploy Keycloak
echo -e "${BLUE}Step 1/5: Deploying Keycloak...${NC}"
kubectl apply -k openshift/base/keycloak/
echo -e "${YELLOW}Waiting for Keycloak to be ready (this may take 2-3 minutes)...${NC}"
oc wait --for=condition=Ready pod -l app=keycloak --timeout=5m 2>/dev/null || echo -e "${YELLOW}⚠ Keycloak not ready yet, continuing...${NC}"
echo ""

# Trigger all builds in parallel
echo -e "${BLUE}Step 2/5: Triggering container builds...${NC}"
echo "Starting builds for all components (parallel):"
for agent in weather-agent news-agent fortune-agent traffic-agent email-agent package-agent breakfast-agent assistant; do
  echo "  - $agent"
  oc start-build $agent 2>/dev/null || kubectl apply -k openshift/base/agents/${agent}/ && oc start-build $agent &
done
echo "  - dashboard"
oc start-build dashboard 2>/dev/null || kubectl apply -k openshift/base/dashboard/ && oc start-build dashboard &
wait
echo -e "${GREEN}✓ All builds started${NC}"

echo -e "${YELLOW}Waiting for builds to complete (10-15 minutes)...${NC}"
echo "You can monitor build progress with: oc get builds -w"
oc wait --for=condition=Complete build -l app=a2a-morning-routine --timeout=20m 2>/dev/null || echo -e "${YELLOW}⚠ Some builds may still be running${NC}"
echo ""

# Deploy consumer agents
echo -e "${BLUE}Step 3/5: Deploying consumer agents...${NC}"
for agent in weather-agent news-agent fortune-agent traffic-agent email-agent package-agent breakfast-agent; do
  echo "  - $agent"
  kubectl apply -k openshift/base/agents/${agent}/
done
echo -e "${GREEN}✓ Consumer agents deployed${NC}"

echo -e "${YELLOW}Waiting 30 seconds for consumer agents to initialize...${NC}"
sleep 30
echo ""

# Deploy assistant
echo -e "${BLUE}Step 4/5: Deploying assistant agent...${NC}"
kubectl apply -k openshift/base/agents/assistant/
echo -e "${GREEN}✓ Assistant deployed${NC}"
echo ""

# Deploy dashboard
echo -e "${BLUE}Step 5/5: Deploying dashboard...${NC}"
kubectl apply -k openshift/base/dashboard/
echo -e "${GREEN}✓ Dashboard deployed${NC}"
echo ""

# Wait for all deployments
echo -e "${YELLOW}Waiting for all pods to be ready (2-3 minutes)...${NC}"
oc wait --for=condition=Ready pod -l app=a2a-morning-routine --timeout=5m 2>/dev/null || echo -e "${YELLOW}⚠ Some pods may still be starting${NC}"
echo ""

# Show status
echo -e "${GREEN}=========================================${NC}"
echo -e "${GREEN}Deployment Complete!${NC}"
echo -e "${GREEN}=========================================${NC}"
echo ""

echo -e "${BLUE}Public URLs:${NC}"
oc get routes -o custom-columns=NAME:.metadata.name,URL:.spec.host --no-headers | \
  awk '{print "  " $1 ": https://" $2}'
echo ""

echo -e "${BLUE}Pod Status:${NC}"
oc get pods -l app=a2a-morning-routine -o custom-columns=NAME:.metadata.name,STATUS:.status.phase,READY:.status.conditions[?\(@.type==\"Ready\"\)].status
echo ""

echo -e "${YELLOW}Next steps:${NC}"
echo "  1. Visit the dashboard URL above to see your morning briefing"
echo "  2. Check logs: ./openshift/scripts/logs.sh <component-name>"
echo "  3. View status: ./openshift/scripts/status.sh"
echo ""
