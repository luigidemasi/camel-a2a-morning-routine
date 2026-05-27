#!/bin/bash
# Stop all agents in the A2A Morning Routine demo

BOLD='\033[1m'
GREEN='\033[0;32m'
RESET='\033[0m'

echo -e "🛑 Stopping all Camel agents..."
jbang camel@apache/camel stop  2>/dev/null
echo -e "   ${GREEN}✔ All agents stopped${RESET}"

echo -e "🔐 Stopping Keycloak..."
podman compose -f "$(dirname "$0")/podman-compose.yml" down 2>/dev/null
echo -e "   ${GREEN}✔ Keycloak stopped${RESET}"

echo ""
echo -e "${BOLD}👋 A2A Morning Routine shut down${RESET}"
echo ""
