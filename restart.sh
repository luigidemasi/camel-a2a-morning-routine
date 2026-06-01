#!/bin/bash
# Restart all agents in the A2A Morning Routine demo
# Stops running agents, keeps Keycloak up, then starts everything

BOLD='\033[1m'
GREEN='\033[0;32m'
RESET='\033[0m'

echo -e "${BOLD}🔄 Restarting A2A Morning Routine${RESET}"
echo ""

echo -e "🛑 Stopping Camel agents..."
jbang camel@apache/camel stop 2>/dev/null
echo -e "   ${GREEN}✔ Agents stopped${RESET}"
echo ""

exec "$(dirname "$0")/start.sh"
