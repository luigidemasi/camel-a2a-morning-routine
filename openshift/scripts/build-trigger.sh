#!/bin/bash

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Usage function
usage() {
  echo "Usage: $0 <component-name|all> [options]"
  echo ""
  echo "Trigger container builds for A2A Morning Routine components"
  echo ""
  echo "Components:"
  echo "  weather-agent       - Weather data agent"
  echo "  news-agent          - News headlines agent"
  echo "  fortune-agent       - Fortune quotes agent"
  echo "  traffic-agent       - Traffic data agent"
  echo "  email-agent         - Email digest agent"
  echo "  package-agent       - Package tracking agent"
  echo "  breakfast-agent     - Breakfast agent"
  echo "  assistant           - Orchestrator agent"
  echo "  dashboard           - Web dashboard"
  echo "  all                 - All components (parallel)"
  echo ""
  echo "Options:"
  echo "  -f, --follow        Follow build logs (default: false)"
  echo "  -w, --wait          Wait for build to complete (default: false)"
  echo "  -h, --help          Show this help message"
  echo ""
  echo "Examples:"
  echo "  $0 weather-agent                    # Trigger weather-agent build"
  echo "  $0 weather-agent --follow           # Trigger and stream build logs"
  echo "  $0 all --wait                       # Trigger all builds and wait"
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
FOLLOW=false
WAIT=false

while [[ $# -gt 0 ]]; do
  case $1 in
    -h|--help)
      usage
      ;;
    -f|--follow)
      FOLLOW=true
      shift
      ;;
    -w|--wait)
      WAIT=true
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

# Switch to correct namespace
NAMESPACE="a2a-morning-routine"
if ! oc project $NAMESPACE &>/dev/null; then
  echo -e "${RED}Error: Project ${NAMESPACE} does not exist${NC}"
  echo "Run deployment first: ./openshift/scripts/deploy.sh"
  exit 1
fi

# All components
ALL_COMPONENTS=("weather-agent" "news-agent" "fortune-agent" "traffic-agent" "email-agent" "package-agent" "breakfast-agent" "assistant" "dashboard")

# Function to trigger a single build
trigger_build() {
  local component=$1
  local follow_flag=""

  if [ "$FOLLOW" = true ]; then
    follow_flag="--follow"
  fi

  echo -e "${BLUE}Triggering build: ${component}${NC}"

  # Check if BuildConfig exists
  if ! oc get bc/$component &>/dev/null; then
    echo -e "${RED}Error: BuildConfig '${component}' does not exist${NC}"
    echo "Available BuildConfigs:"
    oc get bc -l app=a2a-morning-routine --no-headers | awk '{print "  - " $1}'
    return 1
  fi

  # Start build
  if [ "$FOLLOW" = true ]; then
    oc start-build $component --follow
  else
    BUILD_NAME=$(oc start-build $component -o name)
    echo -e "${GREEN}✓ Build started: ${BUILD_NAME}${NC}"
  fi

  return 0
}

# Handle "all" special case
if [ "$COMPONENT" = "all" ]; then
  echo -e "${BLUE}=========================================${NC}"
  echo -e "${BLUE}Triggering builds for all components${NC}"
  echo -e "${BLUE}=========================================${NC}"
  echo ""

  if [ "$FOLLOW" = true ]; then
    echo -e "${YELLOW}⚠ Cannot follow logs for multiple builds${NC}"
    echo -e "${YELLOW}  Starting all builds without follow${NC}"
    echo ""
  fi

  # Start all builds in parallel
  BUILD_NAMES=()
  for component in "${ALL_COMPONENTS[@]}"; do
    if oc get bc/$component &>/dev/null; then
      BUILD_NAME=$(oc start-build $component -o name 2>/dev/null)
      if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓${NC} Started: $component"
        BUILD_NAMES+=("$BUILD_NAME")
      else
        echo -e "${RED}✗${NC} Failed: $component"
      fi
    else
      echo -e "${YELLOW}⚠${NC} Skipped: $component (BuildConfig not found)"
    fi
  done
  echo ""

  # Wait for builds if requested
  if [ "$WAIT" = true ]; then
    echo -e "${YELLOW}Waiting for all builds to complete...${NC}"
    echo "Monitor progress: oc get builds -w"
    echo ""

    oc wait --for=condition=Complete build -l app=a2a-morning-routine --timeout=20m
    EXIT_CODE=$?

    echo ""
    if [ $EXIT_CODE -eq 0 ]; then
      echo -e "${GREEN}✓ All builds completed successfully${NC}"
    else
      echo -e "${RED}✗ Some builds failed or timed out${NC}"
      echo ""
      echo "Failed builds:"
      oc get builds -l app=a2a-morning-routine --field-selector status.phase!=Complete --no-headers
    fi
  else
    echo -e "${GREEN}All builds started in background${NC}"
    echo ""
    echo "Monitor progress:"
    echo "  oc get builds -w"
    echo ""
    echo "View build logs:"
    echo "  oc logs -f build/<build-name>"
    echo ""
    echo "Check build status:"
    echo "  oc get builds -l app=a2a-morning-routine"
  fi

  exit 0
fi

# Validate single component name
if [[ ! " ${ALL_COMPONENTS[@]} " =~ " ${COMPONENT} " ]]; then
  echo -e "${RED}Error: Invalid component: ${COMPONENT}${NC}"
  echo ""
  usage
fi

# Trigger single build
echo -e "${BLUE}=========================================${NC}"
echo -e "${BLUE}Triggering build: ${COMPONENT}${NC}"
echo -e "${BLUE}=========================================${NC}"
echo ""

trigger_build "$COMPONENT"
BUILD_EXIT=$?

if [ $BUILD_EXIT -ne 0 ]; then
  exit 1
fi

# Wait for build if requested (and not following)
if [ "$WAIT" = true ] && [ "$FOLLOW" = false ]; then
  echo ""
  echo -e "${YELLOW}Waiting for build to complete...${NC}"

  # Get the latest build for this component
  LATEST_BUILD=$(oc get builds -l buildconfig=$COMPONENT --sort-by=.metadata.creationTimestamp -o name | tail -1)

  if [ -n "$LATEST_BUILD" ]; then
    oc wait --for=condition=Complete $LATEST_BUILD --timeout=15m
    EXIT_CODE=$?

    echo ""
    if [ $EXIT_CODE -eq 0 ]; then
      echo -e "${GREEN}✓ Build completed successfully${NC}"

      # Show build status
      oc get $LATEST_BUILD -o custom-columns=\
NAME:.metadata.name,\
STATUS:.status.phase,\
DURATION:.status.duration,\
COMPLETION:.status.completionTimestamp
    else
      echo -e "${RED}✗ Build failed or timed out${NC}"
      echo ""
      echo "View build logs:"
      echo "  oc logs $LATEST_BUILD"
    fi
  fi
fi

echo ""
echo "========================================="
echo "Build commands:"
echo "  View logs:      oc logs -f build/<build-name>"
echo "  Cancel build:   oc cancel-build <build-name>"
echo "  Build status:   oc get builds"
echo "========================================="
