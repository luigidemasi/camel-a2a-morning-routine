#!/bin/bash

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Check if logged in to OpenShift
if ! oc whoami &>/dev/null; then
  echo -e "${RED}Error: Not logged in to OpenShift${NC}"
  echo "Please login with: oc login --token=<token> --server=<server>"
  exit 1
fi

# Switch to correct namespace
NAMESPACE="a2a-morning-routine"
if ! oc project $NAMESPACE &>/dev/null; then
  echo -e "${RED}Error: Project ${NAMESPACE} does not exist${NC}"
  echo "Run deployment first: ./openshift/scripts/deploy.sh"
  exit 1
fi

echo "========================================="
echo "A2A Morning Routine - Status Overview"
echo "========================================="
echo ""
echo -e "${BLUE}Project: ${NAMESPACE}${NC}"
echo -e "${BLUE}User: $(oc whoami)${NC}"
echo ""

# Check if any resources exist
if ! oc get all -l app=a2a-morning-routine &>/dev/null; then
  echo -e "${YELLOW}⚠ No resources found. Run deployment first:${NC}"
  echo "  ./openshift/scripts/deploy.sh"
  exit 0
fi

# Pods status
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}Pods Status${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
oc get pods -l app=a2a-morning-routine -o custom-columns=\
NAME:.metadata.name,\
STATUS:.status.phase,\
READY:.status.conditions[?\(@.type==\"Ready\"\)].status,\
RESTARTS:.status.containerStatuses[0].restartCount,\
AGE:.metadata.creationTimestamp
echo ""

# Count pod statuses
TOTAL_PODS=$(oc get pods -l app=a2a-morning-routine --no-headers 2>/dev/null | wc -l)
RUNNING_PODS=$(oc get pods -l app=a2a-morning-routine --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l)
PENDING_PODS=$(oc get pods -l app=a2a-morning-routine --field-selector=status.phase=Pending --no-headers 2>/dev/null | wc -l)
FAILED_PODS=$(oc get pods -l app=a2a-morning-routine --field-selector=status.phase=Failed --no-headers 2>/dev/null | wc -l)

echo -e "${BLUE}Summary: ${GREEN}${RUNNING_PODS}/${TOTAL_PODS} Running${NC}"
if [ $PENDING_PODS -gt 0 ]; then
  echo -e "  ${YELLOW}⚠ ${PENDING_PODS} Pending${NC}"
fi
if [ $FAILED_PODS -gt 0 ]; then
  echo -e "  ${RED}✗ ${FAILED_PODS} Failed${NC}"
fi
echo ""

# Deployments status
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}Deployments${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
oc get deployments -l app=a2a-morning-routine -o custom-columns=\
NAME:.metadata.name,\
READY:.status.readyReplicas,\
AVAILABLE:.status.availableReplicas,\
AGE:.metadata.creationTimestamp 2>/dev/null || echo "  (none found)"
echo ""

# StatefulSets status (Keycloak)
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}StatefulSets${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
oc get statefulsets -l app=a2a-morning-routine -o custom-columns=\
NAME:.metadata.name,\
READY:.status.readyReplicas,\
AGE:.metadata.creationTimestamp 2>/dev/null || echo "  (none found)"
echo ""

# Services
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}Services${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
oc get services -l app=a2a-morning-routine -o custom-columns=\
NAME:.metadata.name,\
TYPE:.spec.type,\
PORT:.spec.ports[0].port 2>/dev/null || echo "  (none found)"
echo ""

# Routes (Public URLs)
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}Public URLs (Routes)${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
if oc get routes -l app=a2a-morning-routine &>/dev/null; then
  oc get routes -l app=a2a-morning-routine --no-headers | \
    awk '{print "  " $1 ": https://" $2}'
else
  echo "  (none found)"
fi
echo ""

# Builds
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}Recent Builds${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
BUILDS=$(oc get builds -l app=a2a-morning-routine --no-headers 2>/dev/null | tail -10)
if [ -z "$BUILDS" ]; then
  echo "  (none found)"
else
  echo "$BUILDS" | awk '{
    status = $4
    color = ""
    if (status == "Complete") color = "\033[0;32m"
    else if (status == "Running") color = "\033[1;33m"
    else if (status == "Failed") color = "\033[0;31m"
    printf "  %-30s %s%s\033[0m\n", $1, color, status
  }'
fi
echo ""

# PersistentVolumeClaims
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}Persistent Storage${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
oc get pvc -l app=a2a-morning-routine -o custom-columns=\
NAME:.metadata.name,\
STATUS:.status.phase,\
CAPACITY:.status.capacity.storage 2>/dev/null || echo "  (none found)"
echo ""

# Recent events (last 10)
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}Recent Events${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
EVENTS=$(oc get events --sort-by='.lastTimestamp' -l app=a2a-morning-routine 2>/dev/null | tail -10)
if [ -z "$EVENTS" ]; then
  echo "  (none found)"
else
  echo "$EVENTS" | tail -5
fi
echo ""

# Health summary
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}Health Summary${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Check if all critical components are running
COMPONENTS=("keycloak" "weather-agent" "news-agent" "assistant" "dashboard")
ALL_HEALTHY=true

for component in "${COMPONENTS[@]}"; do
  if oc get pod -l app=$component --field-selector=status.phase=Running &>/dev/null; then
    READY=$(oc get pod -l app=$component -o jsonpath='{.items[0].status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)
    if [ "$READY" = "True" ]; then
      echo -e "  ${GREEN}✓${NC} $component"
    else
      echo -e "  ${YELLOW}⚠${NC} $component (not ready)"
      ALL_HEALTHY=false
    fi
  else
    echo -e "  ${RED}✗${NC} $component (not running)"
    ALL_HEALTHY=false
  fi
done
echo ""

if [ "$ALL_HEALTHY" = true ]; then
  echo -e "${GREEN}✓ All critical components are healthy${NC}"
else
  echo -e "${YELLOW}⚠ Some components are not fully healthy${NC}"
  echo ""
  echo -e "${YELLOW}Troubleshooting commands:${NC}"
  echo "  Check logs:    ./openshift/scripts/logs.sh <component-name>"
  echo "  View pod:      oc describe pod -l app=<component-name>"
  echo "  Restart:       oc rollout restart deployment/<component-name>"
fi
echo ""

echo "========================================="
echo "For detailed logs, run:"
echo "  ./openshift/scripts/logs.sh <component-name>"
echo ""
echo "To refresh this view, run:"
echo "  ./openshift/scripts/status.sh"
echo "========================================="
