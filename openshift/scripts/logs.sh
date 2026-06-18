#!/bin/bash

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Usage function
usage() {
  echo "Usage: $0 <component-name> [options]"
  echo ""
  echo "Stream logs from an A2A Morning Routine component"
  echo ""
  echo "Components:"
  echo "  keycloak            - Authentication server"
  echo "  weather-agent       - Weather data agent"
  echo "  news-agent          - News headlines agent"
  echo "  fortune-agent       - Fortune quotes agent"
  echo "  traffic-agent       - Traffic data agent"
  echo "  email-agent         - Email digest agent"
  echo "  package-agent       - Package tracking agent"
  echo "  breakfast-agent     - Breakfast agent (intentional failure demo)"
  echo "  assistant           - Orchestrator agent"
  echo "  dashboard           - Web dashboard"
  echo ""
  echo "Options:"
  echo "  -f, --follow        Stream logs (default)"
  echo "  -p, --previous      Show logs from previous crashed pod"
  echo "  -n, --lines N       Show last N lines (default: 50)"
  echo "  -h, --help          Show this help message"
  echo ""
  echo "Examples:"
  echo "  $0 weather-agent                    # Stream weather-agent logs"
  echo "  $0 assistant --previous             # Show previous assistant logs"
  echo "  $0 keycloak --lines 100             # Show last 100 lines of Keycloak"
  echo ""
  exit 1
}

# Check if logged in to OpenShift
if ! oc whoami &>/dev/null; then
  echo -e "${RED}Error: Not logged in to OpenShift${NC}"
  echo "Please login with: oc login --token=<token> --server=<server>"
  exit 1
fi

# Parse arguments
COMPONENT=""
FOLLOW=true
PREVIOUS=false
LINES=50

while [[ $# -gt 0 ]]; do
  case $1 in
    -h|--help)
      usage
      ;;
    -p|--previous)
      PREVIOUS=true
      FOLLOW=false
      shift
      ;;
    -n|--lines)
      LINES="$2"
      shift 2
      ;;
    -f|--follow)
      FOLLOW=true
      shift
      ;;
    *)
      if [ -z "$COMPONENT" ]; then
        COMPONENT="$1"
      else
        echo -e "${RED}Error: Unknown argument: $1${NC}"
        usage
      fi
      shift
      ;;
  esac
done

# Check if component specified
if [ -z "$COMPONENT" ]; then
  echo -e "${RED}Error: Component name required${NC}"
  echo ""
  usage
fi

# Validate component name
VALID_COMPONENTS=("keycloak" "weather-agent" "news-agent" "fortune-agent" "traffic-agent" "email-agent" "package-agent" "breakfast-agent" "assistant" "dashboard")
if [[ ! " ${VALID_COMPONENTS[@]} " =~ " ${COMPONENT} " ]]; then
  echo -e "${RED}Error: Invalid component: ${COMPONENT}${NC}"
  echo ""
  usage
fi

# Switch to correct namespace
NAMESPACE="a2a-morning-routine"
if ! oc project $NAMESPACE &>/dev/null; then
  echo -e "${RED}Error: Project ${NAMESPACE} does not exist${NC}"
  echo "Run deployment first: ./openshift/scripts/deploy.sh"
  exit 1
fi

# Determine resource type
if [ "$COMPONENT" = "keycloak" ]; then
  RESOURCE_TYPE="statefulset"
else
  RESOURCE_TYPE="deployment"
fi

# Build log command
LOG_CMD="oc logs ${RESOURCE_TYPE}/${COMPONENT}"

if [ "$PREVIOUS" = true ]; then
  LOG_CMD="$LOG_CMD --previous"
fi

if [ "$FOLLOW" = true ]; then
  LOG_CMD="$LOG_CMD -f"
else
  LOG_CMD="$LOG_CMD --tail=$LINES"
fi

# Show header
echo -e "${BLUE}=========================================${NC}"
echo -e "${BLUE}Logs: ${COMPONENT}${NC}"
if [ "$PREVIOUS" = true ]; then
  echo -e "${YELLOW}(previous crashed pod)${NC}"
fi
echo -e "${BLUE}=========================================${NC}"
echo ""

# Execute log command
if [ "$FOLLOW" = true ]; then
  echo -e "${YELLOW}Streaming logs... (Ctrl+C to stop)${NC}"
  echo ""
fi

eval $LOG_CMD

# Check exit status
EXIT_CODE=$?
if [ $EXIT_CODE -ne 0 ]; then
  echo ""
  echo -e "${RED}Error: Failed to retrieve logs${NC}"
  echo ""
  echo -e "${YELLOW}Troubleshooting:${NC}"
  echo "  1. Check if pod exists: oc get pods -l app=${COMPONENT}"
  echo "  2. Check pod status: oc describe pod -l app=${COMPONENT}"
  echo "  3. View all pods: oc get pods"
  echo ""
  exit $EXIT_CODE
fi
