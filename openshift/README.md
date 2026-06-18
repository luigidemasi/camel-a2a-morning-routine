# OpenShift Deployment Guide

Deploy A2A Morning Routine to Red Hat Developer Sandbox (OpenShift).

## Architecture Overview

This deployment uses OpenShift-native BuildConfigs and ImageStreams for containerization, Keycloak for authentication, 8 Camel agent Deployments, and a Node.js dashboard, all exposed via Routes with automatic HTTPS.

### Components

| Component | Type | Purpose | Port | Resources |
|-----------|------|---------|------|-----------|
| Keycloak | StatefulSet | Authentication server | 8080 | 512Mi RAM, 500m CPU |
| Weather Agent | Deployment | Mock weather data provider | 8080 | 128Mi RAM, 100m CPU |
| News Agent | Deployment | Mock news headlines | 8080 | 128Mi RAM, 100m CPU |
| Fortune Agent | Deployment | Random fortune quotes | 8080 | 128Mi RAM, 100m CPU |
| Traffic Agent | Deployment | Async traffic data | 8080 | 128Mi RAM, 100m CPU |
| Email Agent | Deployment | Email digest | 8080 | 128Mi RAM, 100m CPU |
| Package Agent | Deployment | Package tracking | 8080 | 128Mi RAM, 100m CPU |
| Breakfast Agent | Deployment | Intentional failure demo | 8080 | 128Mi RAM, 100m CPU |
| Assistant | Deployment | Orchestrator agent | 8090 | 256Mi RAM, 300m CPU |
| Dashboard | Deployment | UI/BFF (Node.js) | 3000 | 192Mi RAM, 200m CPU |

**Total Resources:** ~1.9GB RAM, ~1.7 CPU (fits within Developer Sandbox free tier: 2GB RAM, 2 CPU)

### Networking

**Internal Communication (ClusterIP Services):**
- All agents communicate via internal DNS: `http://weather-agent:8080`, `http://keycloak:8080`, etc.
- No external traffic between agents

**External Access (Routes):**
- Each component has a public HTTPS Route with automatic TLS termination
- Example: `https://weather-agent-a2a-morning-routine.apps.sandbox-m2.ll9k.p1.openshiftapps.com`

### Deployment Sequence

1. **Keycloak** starts first (StatefulSet with PVC for persistence)
2. **Consumer agents** start in parallel (weather, news, fortune, traffic, email, package, breakfast)
   - Each has an initContainer waiting for Keycloak readiness
3. **Wait 30 seconds** for agent cards to be available
4. **Assistant** starts (has initContainer waiting for all consumer agents)
5. **Dashboard** starts (has initContainer waiting for assistant)

## Prerequisites

- **Red Hat Developer Sandbox account** (free): https://developers.redhat.com/developer-sandbox
- **oc CLI installed** (for manual deployment): https://docs.openshift.com/container-platform/latest/cli_reference/openshift_cli/getting-started-cli.html
- **GitHub repository** with this code (for automated deployment)

## Quick Start (Automated Deployment via GitHub Actions)

1. **Fork this repository** to your GitHub account

2. **Get OpenShift login credentials:**
   - Login to [Developer Sandbox](https://developers.redhat.com/developer-sandbox)
   - Click "Copy login command"
   - Extract token from: `oc login --token=sha256~YOUR_TOKEN --server=https://api.sandbox...`

3. **Add GitHub secrets:**
   - Go to Settings → Secrets and variables → Actions
   - Add `OPENSHIFT_SERVER`: Your server URL (e.g., `https://api.sandbox-m2.ll9k.p1.openshiftapps.com:6443`)
   - Add `OPENSHIFT_TOKEN`: Your token (e.g., `sha256~YOUR_TOKEN`)

4. **Update BuildConfig Git URLs:**
   - Replace `YOUR_USERNAME` in all `openshift/base/agents/*/buildconfig.yaml` and `openshift/base/dashboard/buildconfig.yaml`
   - Update to your GitHub repository URL

5. **Push to main branch:**
   - GitHub Actions will automatically deploy (takes 15-20 minutes)
   - Monitor progress: GitHub → Actions → Deploy to OpenShift

6. **Access your application:**
   ```bash
   # View public URLs
   oc get routes
   ```
   Visit the dashboard URL to see your morning briefing!

## Manual Deployment

### Login to OpenShift

```bash
# Login with your token
oc login --token=<your-token> --server=<your-server>

# Create namespace (if it doesn't exist)
oc new-project a2a-morning-routine

# Or switch to existing namespace
oc project a2a-morning-routine
```

### Deploy Using Helper Script (Recommended)

```bash
# Make script executable
chmod +x scripts/deploy-openshift.sh

# Run deployment
./scripts/deploy-openshift.sh
```

The script will:
1. Deploy Keycloak
2. Trigger parallel builds for all agents
3. Wait for builds to complete
4. Deploy consumer agents
5. Deploy assistant and dashboard
6. Output public URLs

### Deploy Using Kustomize (Advanced)

```bash
# Deploy all resources
kubectl apply -k openshift/

# Or deploy components individually
kubectl apply -k openshift/base/keycloak/
kubectl apply -k openshift/base/agents/weather-agent/
kubectl apply -k openshift/base/agents/news-agent/
# ... (repeat for other agents)
kubectl apply -k openshift/base/dashboard/
```

### Trigger Builds Manually

```bash
# Start builds for all agents
for agent in weather-agent news-agent fortune-agent traffic-agent email-agent package-agent breakfast-agent assistant; do
  oc start-build $agent
done
oc start-build dashboard

# Monitor build progress
oc get builds --watch

# View build logs
oc logs -f build/weather-agent-1
```

## Accessing the Application

### Get Public URLs

```bash
# List all routes
oc get routes

# Get specific URLs
oc get route dashboard -o jsonpath='{.spec.host}'
oc get route assistant -o jsonpath='{.spec.host}'
```

### Test Endpoints

```bash
# Test dashboard
DASHBOARD_URL=$(oc get route dashboard -o jsonpath='{.spec.host}')
curl -k https://${DASHBOARD_URL}

# Test agent cards
WEATHER_URL=$(oc get route weather-agent -o jsonpath='{.spec.host}')
curl -k https://${WEATHER_URL}/.well-known/agent-card.json
```

### Access Keycloak Admin Console

```bash
KEYCLOAK_URL=$(oc get route keycloak -o jsonpath='{.spec.host}')
echo "Keycloak Admin: https://${KEYCLOAK_URL}"
# Username: admin
# Password: admin
```

## Resource Management

### View Resource Usage

```bash
# View pod resource usage
oc adm top pods

# View node resource usage
oc adm top nodes

# View pod status
oc get pods -o wide
```

### Scale Services

```bash
# Scale up
oc scale deployment/weather-agent --replicas=2

# Scale down (save resources)
oc scale deployment/fortune-agent --replicas=0

# Scale back up
oc scale deployment/fortune-agent --replicas=1
```

### Reduce Resource Limits (if needed)

```bash
# Reduce memory limit for an agent
oc set resources deployment/weather-agent --limits=memory=96Mi,cpu=50m

# Reset to default
oc set resources deployment/weather-agent --limits=memory=128Mi,cpu=100m
```

## Troubleshooting

### View Pod Status

```bash
# List all pods
oc get pods

# Describe pod (see events)
oc describe pod <pod-name>

# View pod logs
oc logs deployment/weather-agent

# View previous pod logs (if crashed)
oc logs deployment/weather-agent --previous
```

### Common Issues

**Pod stuck in CrashLoopBackOff:**
```bash
# Check logs
oc logs deployment/weather-agent --previous

# Check if Keycloak is ready
oc get pod -l app=keycloak

# Restart deployment
oc rollout restart deployment/weather-agent
```

**Build failures:**
```bash
# Check build logs
oc logs build/weather-agent-1

# Retry build
oc start-build weather-agent --follow

# Cancel stuck build
oc cancel-build weather-agent-1
```

**Out of memory (OOMKilled):**
```bash
# Check pod events
oc describe pod <pod-name> | grep -A 5 Events

# Scale down non-critical agents
oc scale deployment/fortune-agent --replicas=0
oc scale deployment/breakfast-agent --replicas=0

# Increase memory limit
oc set resources deployment/weather-agent --limits=memory=256Mi
```

**Dashboard not loading:**
```bash
# Check dashboard logs
oc logs deployment/dashboard

# Check if assistant is ready
oc get pod -l app=assistant

# Restart dashboard
oc rollout restart deployment/dashboard
```

For detailed troubleshooting, see [TROUBLESHOOTING.md](./TROUBLESHOOTING.md).

## Cleanup

### Using Helper Script

```bash
./scripts/cleanup-openshift.sh
```

### Manual Cleanup

```bash
# Delete all resources with label
oc delete all -l app=a2a-morning-routine

# Delete ConfigMaps
oc delete configmap -l app=a2a-morning-routine

# Delete PersistentVolumeClaims
oc delete pvc -l app=a2a-morning-routine

# Delete BuildConfigs and ImageStreams
oc delete bc -l app=a2a-morning-routine
oc delete is -l app=a2a-morning-routine

# Verify cleanup
oc get all -l app=a2a-morning-routine
```

### Delete Namespace (Complete Cleanup)

```bash
# WARNING: This deletes everything in the namespace
oc delete project a2a-morning-routine
```

## Build Process Details

### BuildConfigs

- **Source:** GitHub repository
- **Strategy:** Docker build
- **Dockerfiles:**
  - Camel agents: `dockerfiles/camel-agent.Dockerfile` (reusable with `ARG AGENT_NAME`)
  - Dashboard: `dockerfiles/dashboard.Dockerfile`

### ImageStreams

- Internal OpenShift registry: `image-registry.openshift-image-registry.svc:5000`
- Images stored as: `a2a-morning-routine/weather-agent:latest`
- Automatic deployment triggers on new image builds

### Build Time

- **Parallel builds:** ~10-15 minutes for all 9 components
- **Sequential builds:** ~45-60 minutes (not recommended)

## Configuration Management

### ConfigMaps

Each agent has a ConfigMap with `application.properties` overrides:

**Key differences from local development:**
- Keycloak URL: `localhost:8180` → `keycloak:8080`
- Agent URLs: `localhost:808X` → `<agent-name>:8080`
- HTTPS: Uses internal HTTP (TLS termination at Route level)

### Environment Variables (Dashboard)

Dashboard uses ConfigMap with environment variables:
- `ASSISTANT_URL=http://assistant:8090`
- `KEYCLOAK_URL=http://keycloak:8080`
- `KEYCLOAK_REALM=a2a-morning-routine`
- etc.

## Health Checks

### Liveness Probes

- **Path:** `/.well-known/agent-card.json` (agents), `/` (dashboard), `/health/live` (Keycloak)
- **Initial Delay:** 60s (agents), 30s (dashboard), 120s (Keycloak)
- **Period:** 30s
- **Failure Threshold:** 3

**Purpose:** Restart pod if unhealthy

### Readiness Probes

- **Path:** Same as liveness
- **Initial Delay:** 30s (agents), 10s (dashboard), 60s (Keycloak)
- **Period:** 10s
- **Failure Threshold:** 3

**Purpose:** Remove from load balancer if not ready

## CI/CD Pipeline (GitHub Actions)

### Workflow Triggers

- Push to `main` branch (automatic)
- Manual dispatch via GitHub Actions UI

### Workflow Steps

1. Checkout code
2. Install `oc` CLI
3. Login to OpenShift
4. Deploy Keycloak
5. Wait for Keycloak ready
6. Trigger parallel builds for all agents
7. Wait for builds to complete
8. Deploy consumer agents
9. Wait 30 seconds for agents to start
10. Deploy assistant
11. Deploy dashboard
12. Wait for all pods to be ready
13. Output public URLs to GitHub Actions summary
14. Health check dashboard

**Duration:** 15-20 minutes for complete deployment

### Required GitHub Secrets

- `OPENSHIFT_SERVER`: OpenShift API server URL
- `OPENSHIFT_TOKEN`: Authentication token (expires after 24 hours)

## Documentation

- **Design Specification:** `docs/superpowers/specs/2026-06-18-openshift-deployment-design.md`
- **Implementation Plan:** `docs/superpowers/plans/2026-06-18-openshift-deployment.md`
- **Troubleshooting Guide:** `openshift/TROUBLESHOOTING.md`

## Support

- **OpenShift Status:** https://status.redhat.com/
- **Red Hat Support:** https://access.redhat.com/support
- **Developer Sandbox Docs:** https://developers.redhat.com/developer-sandbox
- **GitHub Issues:** https://github.com/YOUR_USERNAME/camel-a2a-morning-routine/issues
