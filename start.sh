#!/bin/bash
# Start all agents in the A2A Morning Routine demo

BOLD='\033[1m'
DIM='\033[2m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
RESET='\033[0m'

CAMEL_VERSION="${CAMEL_VERSION:-4.21.0-SNAPSHOT}"
A2A_DEP="--dep=org.apache.camel:camel-a2a:$CAMEL_VERSION"
OAUTH_DEP="--dep=org.apache.camel:camel-oauth:$CAMEL_VERSION"
CAMEL_JBANG="${CAMEL_JBANG:-camel@apache/camel}"
CAMEL="jbang $CAMEL_JBANG run --camel-version=$CAMEL_VERSION"

echo ""
echo -e "${BOLD}🐫 A2A Morning Routine${RESET}"
echo -e "${DIM}   Apache Camel $CAMEL_VERSION${RESET}"
echo ""

echo -e "🧹 Stopping any running agents..."
./stop.sh 2>/dev/null

# Start Keycloak if not already running
if ! podman ps --format '{{.Names}}' | grep -q morning-routine-keycloak; then
    echo -e "🔐 Starting Keycloak..."
    podman compose -f podman-compose.yml up -d
    echo -e "   ${DIM}Waiting for Keycloak to be ready...${RESET}"
    until podman exec morning-routine-keycloak bash -c 'exec 3<>/dev/tcp/localhost/8080' 2>/dev/null; do
        sleep 2
    done
    sleep 3
    echo -e "   ${GREEN}✔ Keycloak ready at http://localhost:8180${RESET}"
else
    echo -e "🔐 ${GREEN}✔ Keycloak already running${RESET}"
fi

echo ""
echo -e "🌤️  Starting Weather Agent on port ${CYAN}8080${RESET}..."
cd weather-agent
$CAMEL * --background $A2A_DEP $OAUTH_DEP --logging-level=info
cd ..

echo -e "📰 Starting News Agent on port ${CYAN}8081${RESET}..."
cd news-agent
$CAMEL * --background $A2A_DEP $OAUTH_DEP --logging-level=info
cd ..

echo -e "🥠 Starting Fortune Agent on port ${CYAN}8082${RESET}..."
cd fortune-agent
$CAMEL * --background $A2A_DEP --logging-level=info
cd ..

echo -e "🚗 Starting Traffic Agent on port ${CYAN}8083${RESET}..."
cd traffic-agent
$CAMEL * --background $A2A_DEP $OAUTH_DEP --logging-level=info
cd ..

echo -e "📧 Starting Email Agent on port ${CYAN}8084${RESET}..."
cd email-agent
$CAMEL * --background $A2A_DEP $OAUTH_DEP --logging-level=info
cd ..

echo -e "📦 Starting Package Agent on port ${CYAN}8085${RESET}..."
cd package-agent
$CAMEL * --background $A2A_DEP --logging-level=info
cd ..

# Wait for consumer agents to be ready before starting the assistant,
# because the a2a producer fetches agent cards at startup
echo -e "   ${DIM}Waiting for agents to be ready...${RESET}"
sleep 5

echo -e "🤖 Starting Assistant Agent on port ${CYAN}8090${RESET}..."
cd assistant
$CAMEL * --background $A2A_DEP $OAUTH_DEP --logging-level=info
cd ..

echo -e "   ${DIM}Waiting for assistant to start...${RESET}"
sleep 5

echo -e "🌐 Starting Dashboard BFF on port ${CYAN}3000${RESET}..."
cd dashboard
if [ ! -d node_modules ]; then
    npm install --silent 2>/dev/null
fi
npm start &
DASHBOARD_PID=$!
echo $DASHBOARD_PID > .dashboard.pid
cd ..
sleep 2

echo ""
jbang camel@apache/camel ps

echo ""
echo -e "${GREEN}${BOLD}══════════════════════════════════════════${RESET}"
echo -e "${GREEN}${BOLD}  ✅ A2A Morning Routine is running!${RESET}"
echo -e "${GREEN}${BOLD}══════════════════════════════════════════${RESET}"
echo ""
echo -e "${BOLD}📋 Agent Cards${RESET}"
echo -e "   🌤️  Weather     ${CYAN}http://localhost:8080/.well-known/agent-card.json${RESET}"
echo -e "   📰 News        ${CYAN}http://localhost:8081/.well-known/agent-card.json${RESET}"
echo -e "   🥠 Fortune     ${CYAN}http://localhost:8082/.well-known/agent-card.json${RESET}  ${DIM}(API key auth)${RESET}"
echo -e "   🚗 Traffic     ${CYAN}http://localhost:8083/.well-known/agent-card.json${RESET}  ${DIM}(OIDC, returnImmediately)${RESET}"
echo -e "   📧 Email       ${CYAN}http://localhost:8084/.well-known/agent-card.json${RESET}  ${DIM}(SSE streaming)${RESET}"
echo -e "   📦 Package     ${CYAN}http://localhost:8085/.well-known/agent-card.json${RESET}  ${DIM}(push notifications)${RESET}"
echo -e "   🤖 Assistant   ${CYAN}http://localhost:8090/.well-known/agent-card.json${RESET}  ${DIM}(A2A orchestrator)${RESET}"
echo ""
echo -e "${BOLD}☕ Morning Briefing${RESET}"
echo -e "   Dashboard  ${CYAN}http://localhost:3000/${RESET}"
echo -e "   BFF API    ${CYAN}http://localhost:3000/api/morning-briefing${RESET}"
echo ""
echo -e "${BOLD}🚀 Try it${RESET}"
echo -e "   ${DIM}Open http://localhost:3000/ in your browser${RESET}"
echo ""
