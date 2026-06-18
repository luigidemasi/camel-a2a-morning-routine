# OpenShift Deployment Troubleshooting

Common issues and solutions for A2A Morning Routine on Red Hat OpenShift Developer Sandbox.

## Table of Contents

- [Build Failures](#build-failures)
- [Pod Crashes and Restarts](#pod-crashes-and-restarts)
- [Deployment Failures](#deployment-failures)
- [Network and DNS Issues](#network-and-dns-issues)
- [Resource Limits Exceeded](#resource-limits-exceeded)
- [Keycloak Authentication Problems](#keycloak-authentication-problems)
- [Agent Not Ready](#agent-not-ready)
- [Dashboard Not Loading](#dashboard-not-loading)
- [GitHub Actions Failures](#github-actions-failures)
- [General Debugging Commands](#general-debugging-commands)

---

## Build Failures

### Symptom: BuildConfig fails during image creation

**Diagnostic commands:**
```bash
# Check build status
oc get builds

# View build logs
oc logs build/weather-agent-1

# Describe build (see events and errors)
oc describe build/weather-agent-1
```

### Common Causes and Solutions

#### 1. Dockerfile Syntax Error

**Symptom:** Build fails with Docker parsing error

**Solution:**
```bash
# Verify Dockerfile locally first
docker build -f dockerfiles/camel-agent.Dockerfile --build-arg AGENT_NAME=weather-agent -t test .

# Fix Dockerfile, commit, push to git
git add dockerfiles/
git commit -m "fix: correct Dockerfile syntax"
git push

# Retry build
oc start-build weather-agent --follow
```

#### 2. Network Timeout (JBang/Maven Download)

**Symptom:** `curl: (28) Operation timed out` or `Connection timeout`

**Solution:**
```bash
# Retry build (usually transient network issue)
oc start-build weather-agent --follow

# If persistent, increase build timeout
oc patch bc/weather-agent -p '{"spec":{"completionDeadlineSeconds":1800}}'
```

#### 3. GitHub Repository Not Accessible

**Symptom:** `fatal: could not read from remote repository`

**Solution:**
```bash
# Verify BuildConfig has correct Git URL
oc get bc/weather-agent -o yaml | grep uri

# Update Git URL
oc edit bc/weather-agent
# Change spec.source.git.uri to your repository

# Ensure repository is public (or configure Git credentials)
```

#### 4. Build Timeout

**Symptom:** Build exceeds time limit and is cancelled

**Solution:**
```bash
# Increase completion deadline (default 600s = 10min)
oc patch bc/weather-agent -p '{"spec":{"completionDeadlineSeconds":1800}}'

# For all agents
for agent in weather-agent news-agent fortune-agent traffic-agent email-agent package-agent breakfast-agent assistant; do
  oc patch bc/$agent -p '{"spec":{"completionDeadlineSeconds":1800}}'
done
```

#### 5. Out of Disk Space

**Symptom:** `no space left on device`

**Solution:**
```bash
# Clean up old builds
oc delete builds --field-selector status!=Complete,status!=Failed

# Prune old images
oc adm prune images --confirm

# Delete unused ImageStreamTags
oc delete istag --all -l app=a2a-morning-routine
```

### Recovery Commands

```bash
# Retry failed build
oc start-build weather-agent --follow

# Cancel stuck build
oc cancel-build weather-agent-1

# Delete failed build
oc delete build weather-agent-1

# Start fresh build from scratch
oc delete bc,is weather-agent
kubectl apply -k openshift/base/agents/weather-agent/
oc start-build weather-agent --follow
```

---

## Pod Crashes and Restarts

### Symptom: Pod stuck in CrashLoopBackOff

**Diagnostic commands:**
```bash
# Check pod status
oc get pods

# Describe pod (see restart count and events)
oc describe pod <pod-name>

# View current logs
oc logs deployment/weather-agent

# View previous crashed pod logs
oc logs deployment/weather-agent --previous

# View all pod events
oc get events --sort-by='.lastTimestamp' | grep <pod-name>
```

### Common Causes and Solutions

#### 1. Application Startup Failure

**Symptom:** Logs show Java exception, Camel route failure, or configuration error

**Solution:**
```bash
# Check logs for stack trace
oc logs deployment/weather-agent --previous | grep -A 20 "ERROR"

# Verify ConfigMap is correct
oc get configmap weather-agent-config -o yaml

# Check if file paths are correct
oc exec deployment/weather-agent -- ls -la /app/

# Update ConfigMap if needed
oc edit configmap weather-agent-config
oc rollout restart deployment/weather-agent
```

#### 2. InitContainer Timeout (Keycloak Not Ready)

**Symptom:** initContainer logs show "Waiting for Keycloak..." repeatedly

**Solution:**
```bash
# Check Keycloak pod status
oc get pod -l app=keycloak

# Check Keycloak logs
oc logs statefulset/keycloak

# Test Keycloak health endpoint
POD=$(oc get pod -l app=keycloak -o name | head -1)
oc exec $POD -- curl -f http://localhost:8080/health/ready

# If Keycloak is down, restart it
oc rollout restart statefulset/keycloak
```

#### 3. OOMKilled (Out of Memory)

**Symptom:** Pod status shows `OOMKilled`, pod restarts frequently

**Solution:**
```bash
# Check pod events for OOMKilled
oc describe pod <pod-name> | grep -i oomkilled

# View resource usage
oc adm top pods

# Increase memory limit
oc set resources deployment/weather-agent --limits=memory=256Mi

# Or reduce memory of other agents to free up space
oc scale deployment/fortune-agent --replicas=0
oc scale deployment/breakfast-agent --replicas=0
```

#### 4. Image Pull Error

**Symptom:** `Failed to pull image`, `ImagePullBackOff`, `ErrImagePull`

**Solution:**
```bash
# Check if ImageStream exists
oc get is/weather-agent

# Check if image exists in registry
oc get istag/weather-agent:latest

# If image missing, rebuild
oc start-build weather-agent --follow

# If build successful but deployment still fails, check deployment image reference
oc get deployment/weather-agent -o yaml | grep image:
```

#### 5. ConfigMap Missing

**Symptom:** `Error: configmap "weather-agent-config" not found`

**Solution:**
```bash
# Check if ConfigMap exists
oc get configmap weather-agent-config

# Create ConfigMap
kubectl apply -k openshift/base/agents/weather-agent/

# Verify volume mount
oc get deployment/weather-agent -o yaml | grep -A 5 volumeMounts
```

### Recovery Commands

```bash
# Restart deployment
oc rollout restart deployment/weather-agent

# Rollback to previous version
oc rollout undo deployment/weather-agent

# Delete and recreate pod
oc delete pod -l app=weather-agent

# Scale down and up
oc scale deployment/weather-agent --replicas=0
oc scale deployment/weather-agent --replicas=1
```

---

## Deployment Failures

### Symptom: Deployment stuck in Pending or not progressing

**Diagnostic commands:**
```bash
# Check deployment status
oc get deployments

# Describe deployment
oc describe deployment/weather-agent

# Check replica sets
oc get rs -l app=weather-agent

# Check pod status
oc get pods -l app=weather-agent
```

### Common Causes and Solutions

#### 1. Insufficient Resources

**Symptom:** Pod stuck in `Pending`, events show `Insufficient memory` or `Insufficient cpu`

**Solution:**
```bash
# Check resource quotas
oc describe quota

# Check node resource usage
oc adm top nodes

# Reduce resource requests/limits
oc set resources deployment/weather-agent --requests=memory=64Mi,cpu=50m --limits=memory=128Mi,cpu=100m

# Scale down optional agents
oc scale deployment/fortune-agent --replicas=0
```

#### 2. PVC Not Bound (Keycloak)

**Symptom:** Keycloak pod stuck in `Pending`, PVC shows `Pending` status

**Solution:**
```bash
# Check PVC status
oc get pvc

# Describe PVC
oc describe pvc keycloak-data

# Check storage class
oc get sc

# Delete and recreate (WARNING: loses data)
oc delete pvc keycloak-data
kubectl apply -k openshift/base/keycloak/
```

#### 3. Image Not Found

**Symptom:** Deployment exists but no pods created, events show `InvalidImageName`

**Solution:**
```bash
# Verify image exists
oc get is/weather-agent
oc get istag/weather-agent:latest

# Check deployment image reference
oc get deployment/weather-agent -o yaml | grep image:

# Rebuild image
oc start-build weather-agent --follow
```

---

## Network and DNS Issues

### Symptom: Agents cannot reach Keycloak or other agents

**Diagnostic commands:**
```bash
# Test DNS resolution
POD=$(oc get pod -l app=weather-agent -o name | head -1)
oc exec $POD -- nslookup keycloak

# Test HTTP connectivity
oc exec $POD -- curl -v http://keycloak:8080/health/ready

# Check service endpoints
oc get endpoints keycloak
```

### Common Causes and Solutions

#### 1. Service Not Created

**Symptom:** `could not resolve host: keycloak`

**Solution:**
```bash
# Check if service exists
oc get svc keycloak

# Create service
kubectl apply -k openshift/base/keycloak/

# Verify service has endpoints
oc get endpoints keycloak
```

#### 2. Keycloak Pod Not Ready

**Symptom:** `Connection refused` on port 8080

**Solution:**
```bash
# Check Keycloak pod status
oc get pod -l app=keycloak

# Check readiness probe
oc describe pod -l app=keycloak | grep -A 10 Readiness

# Wait for Keycloak to be ready
oc wait --for=condition=Ready pod -l app=keycloak --timeout=5m
```

#### 3. Wrong Port in ConfigMap

**Symptom:** Connection refused or timeout

**Solution:**
```bash
# Verify service port
oc get svc keycloak -o yaml | grep port:

# Verify ConfigMap URLs
oc get configmap weather-agent-config -o yaml | grep keycloak

# Update ConfigMap if needed
oc edit configmap weather-agent-config
oc rollout restart deployment/weather-agent
```

#### 4. Network Policy Blocking Traffic

**Symptom:** Timeout connecting to other pods

**Solution:**
```bash
# Check for network policies
oc get networkpolicy

# Describe network policy
oc describe networkpolicy <policy-name>

# Delete restrictive policy (not recommended for production)
oc delete networkpolicy <policy-name>
```

---

## Resource Limits Exceeded

### Symptom: Pods evicted, OOMKilled, or cluster at capacity

**Diagnostic commands:**
```bash
# Check resource usage
oc adm top nodes
oc adm top pods

# Check resource quotas
oc describe quota

# Check limit ranges
oc get limitrange
```

### Common Causes and Solutions

#### 1. Memory Limit Exceeded

**Symptom:** Pods show `Evicted` status, OOMKilled in events

**Solution:**
```bash
# Scale down non-critical agents
oc scale deployment/fortune-agent --replicas=0
oc scale deployment/breakfast-agent --replicas=0

# Reduce memory limits for agents
for agent in weather-agent news-agent traffic-agent email-agent package-agent; do
  oc set resources deployment/$agent --limits=memory=96Mi
done

# Reduce Keycloak memory (if safe)
oc set resources statefulset/keycloak --limits=memory=384Mi
```

#### 2. CPU Limit Exceeded

**Symptom:** Pods stuck in `Pending`, `Insufficient cpu` in events

**Solution:**
```bash
# Reduce CPU limits
for agent in weather-agent news-agent fortune-agent traffic-agent email-agent package-agent breakfast-agent; do
  oc set resources deployment/$agent --limits=cpu=50m
done
```

#### 3. Storage Quota Exceeded

**Symptom:** PVC stuck in `Pending`, quota exceeded error

**Solution:**
```bash
# Check storage usage
oc get pvc

# Delete old builds and images
oc delete builds --field-selector status=Complete
oc adm prune images --confirm
```

#### 4. Too Many Pods

**Symptom:** Pod limit reached (Developer Sandbox limit: ~15 pods)

**Solution:**
```bash
# Count current pods
oc get pods --all-namespaces | wc -l

# Scale down optional agents
oc scale deployment/fortune-agent --replicas=0
oc scale deployment/breakfast-agent --replicas=0
```

---

## Keycloak Authentication Problems

### Symptom: Agents fail to authenticate with Keycloak

**Diagnostic commands:**
```bash
# Test OAuth token acquisition
KEYCLOAK_URL=$(oc get route keycloak -o jsonpath='{.spec.host}')
curl -k -X POST https://${KEYCLOAK_URL}/realms/a2a-morning-routine/protocol/openid-connect/token \
  -d "grant_type=client_credentials" \
  -d "client_id=weather-agent" \
  -d "client_secret=weather-agent-secret"

# Check Keycloak logs
oc logs statefulset/keycloak | grep ERROR

# Check agent logs for auth errors
oc logs deployment/weather-agent | grep -i "auth\|oauth\|token"
```

### Common Causes and Solutions

#### 1. Client Not Configured in Keycloak

**Symptom:** `invalid_client` error

**Solution:**
```bash
# Check if realm ConfigMap has client definition
oc get configmap keycloak-realm -o yaml | grep weather-agent

# Verify Keycloak imported realm
KEYCLOAK_URL=$(oc get route keycloak -o jsonpath='{.spec.host}')
curl -k https://${KEYCLOAK_URL}/realms/a2a-morning-routine/.well-known/openid-configuration

# If realm not imported, restart Keycloak
oc rollout restart statefulset/keycloak
```

#### 2. Wrong Client Secret

**Symptom:** `unauthorized_client` error

**Solution:**
```bash
# Check ConfigMap secret
oc get configmap weather-agent-config -o yaml | grep client-secret

# Check realm ConfigMap secret
oc get configmap keycloak-realm -o yaml | grep -A 2 "weather-agent" | grep secret

# Update if mismatch
oc edit configmap weather-agent-config
oc rollout restart deployment/weather-agent
```

#### 3. Keycloak URL Incorrect

**Symptom:** Connection refused or timeout on auth requests

**Solution:**
```bash
# Verify ConfigMap uses internal service URL
oc get configmap weather-agent-config -o yaml | grep keycloak.oidc.url

# Should be: http://keycloak:8080 (not external route)
oc edit configmap weather-agent-config
# Change to: http://keycloak:8080/realms/a2a-morning-routine/.well-known/openid-configuration
oc rollout restart deployment/weather-agent
```

#### 4. Realm Not Created

**Symptom:** `Realm does not exist` error

**Solution:**
```bash
# Check if realm was imported
KEYCLOAK_URL=$(oc get route keycloak -o jsonpath='{.spec.host}')
curl -k https://${KEYCLOAK_URL}/realms/a2a-morning-routine

# Check Keycloak logs for import errors
oc logs statefulset/keycloak | grep -i "import\|realm"

# Verify realm ConfigMap exists
oc get configmap keycloak-realm

# Restart Keycloak to retry import
oc rollout restart statefulset/keycloak
```

---

## Agent Not Ready

### Symptom: Readiness probe failing, agent not available

**Diagnostic commands:**
```bash
# Check readiness probe
POD=$(oc get pod -l app=weather-agent -o name | head -1)
oc exec $POD -- curl -f http://localhost:8080/.well-known/agent-card.json

# Check agent logs
oc logs deployment/weather-agent | grep ERROR

# Check health endpoint from outside pod
oc port-forward deployment/weather-agent 8080:8080
curl http://localhost:8080/.well-known/agent-card.json
```

### Common Causes and Solutions

#### 1. Camel Route Not Started

**Symptom:** `404 Not Found` on agent-card endpoint

**Solution:**
```bash
# Check Camel logs for startup errors
oc logs deployment/weather-agent | grep "Camel\|ERROR"

# Verify application.properties is mounted
oc exec deployment/weather-agent -- cat /app/application.properties

# Check for Java exceptions
oc logs deployment/weather-agent | grep -i exception
```

#### 2. Port Mismatch

**Symptom:** Connection refused on health check

**Solution:**
```bash
# Verify camel.server.port matches container port
oc get configmap weather-agent-config -o yaml | grep server.port
oc get deployment weather-agent -o yaml | grep containerPort

# Update if mismatch
oc edit configmap weather-agent-config
oc rollout restart deployment/weather-agent
```

#### 3. Slow Startup

**Symptom:** Probe timeout before agent ready, but eventually starts

**Solution:**
```bash
# Increase initialDelaySeconds for readiness probe
oc patch deployment/weather-agent -p '{"spec":{"template":{"spec":{"containers":[{"name":"weather-agent","readinessProbe":{"initialDelaySeconds":60}}]}}}}'

# Or edit deployment directly
oc edit deployment weather-agent
# Change: readinessProbe.initialDelaySeconds: 60
```

---

## Dashboard Not Loading

### Symptom: Dashboard shows error or blank page

**Diagnostic commands:**
```bash
# Check dashboard logs
oc logs deployment/dashboard

# Test dashboard endpoint
DASHBOARD_URL=$(oc get route dashboard -o jsonpath='{.spec.host}')
curl -k -v https://${DASHBOARD_URL}

# Check if assistant is ready
oc get pod -l app=assistant

# Port forward for local debugging
oc port-forward deployment/dashboard 3000:3000
```

### Common Causes and Solutions

#### 1. Assistant Not Ready

**Symptom:** Dashboard logs show `ECONNREFUSED http://assistant:8090`

**Solution:**
```bash
# Check assistant pod
oc get pod -l app=assistant

# Check assistant logs
oc logs deployment/assistant

# Test assistant endpoint
oc exec deployment/dashboard -- curl -f http://assistant:8090/.well-known/agent-card.json

# Restart assistant if needed
oc rollout restart deployment/assistant
```

#### 2. Missing Environment Variables

**Symptom:** Dashboard logs show `undefined` for URLs

**Solution:**
```bash
# Verify ConfigMap
oc get configmap dashboard-config -o yaml

# Verify env vars are mounted
oc describe deployment/dashboard | grep -A 10 "Environment:"

# Update ConfigMap
oc edit configmap dashboard-config
oc rollout restart deployment/dashboard
```

#### 3. Node.js Application Error

**Symptom:** Dashboard pod crashes, shows JavaScript error

**Solution:**
```bash
# Check logs for stack trace
oc logs deployment/dashboard --previous | grep -A 20 "Error"

# Verify npm dependencies installed
oc exec deployment/dashboard -- ls -la node_modules/

# Rebuild dashboard image
oc start-build dashboard --follow
```

---

## GitHub Actions Failures

### Symptom: Workflow fails on GitHub Actions

**Diagnostic commands:**
```bash
# Check workflow logs in GitHub UI:
# GitHub → Actions → Failed workflow → Expand failed step
```

### Common Causes and Solutions

#### 1. OPENSHIFT_TOKEN Expired

**Symptom:** `error: You must be logged in to the server (Unauthorized)`

**Solution:**
```bash
# Get new token (expires after 24 hours)
oc login --token=<new-token> --server=<server>
oc whoami -t

# Update GitHub secret:
# GitHub → Settings → Secrets and variables → Actions → OPENSHIFT_TOKEN
# Replace with new token
```

#### 2. Build Timeout in Workflow

**Symptom:** Step exceeds 15 minute timeout

**Solution:**
Edit `.github/workflows/deploy-openshift.yaml`:
```yaml
- name: Trigger parallel builds
  run: |
    # ... existing commands ...
  timeout-minutes: 20  # Increase from 15
```

#### 3. Network Issue

**Symptom:** `curl: (28) Connection timeout`, transient failure

**Solution:**
```bash
# Re-run workflow manually
# GitHub → Actions → Failed workflow → Re-run jobs
```

#### 4. Namespace Not Created

**Symptom:** `Error from server (NotFound): namespaces "a2a-morning-routine" not found`

**Solution:**
Verify workflow creates namespace:
```yaml
- name: Login to OpenShift
  run: |
    oc login --token=${{ secrets.OPENSHIFT_TOKEN }} --server=${{ secrets.OPENSHIFT_SERVER }}
    oc project a2a-morning-routine || oc new-project a2a-morning-routine
```

---

## General Debugging Commands

### View All Resources

```bash
# List all resources
oc get all -l app=a2a-morning-routine

# Get detailed status
oc get pods,svc,routes,deployments,statefulsets,pvc -o wide
```

### View Events (Recent Activity)

```bash
# All events sorted by time
oc get events --sort-by='.lastTimestamp'

# Events for specific pod
oc get events --field-selector involvedObject.name=<pod-name>

# Warning events only
oc get events --field-selector type=Warning
```

### View Logs

```bash
# Current logs
oc logs deployment/weather-agent

# Previous pod logs (if crashed)
oc logs deployment/weather-agent --previous

# Follow logs
oc logs -f deployment/weather-agent

# Logs from specific container
oc logs deployment/assistant -c wait-for-agents
```

### Exec Into Pod

```bash
# Get shell
oc exec -it deployment/weather-agent -- /bin/bash

# Run specific command
oc exec deployment/weather-agent -- curl http://localhost:8080/.well-known/agent-card.json

# Check environment variables
oc exec deployment/weather-agent -- env | grep CAMEL
```

### Describe Resources

```bash
# Describe pod (shows events and status)
oc describe pod <pod-name>

# Describe deployment
oc describe deployment/weather-agent

# Describe service
oc describe svc/keycloak
```

### Port Forwarding (Local Testing)

```bash
# Forward pod port to localhost
oc port-forward deployment/weather-agent 8080:8080

# Forward service port
oc port-forward svc/keycloak 8080:8080

# Test in another terminal
curl http://localhost:8080/.well-known/agent-card.json
```

### Restart Resources

```bash
# Restart deployment
oc rollout restart deployment/weather-agent

# Restart statefulset
oc rollout restart statefulset/keycloak

# Delete pod (recreates automatically)
oc delete pod -l app=weather-agent
```

### Rollback Deployment

```bash
# View rollout history
oc rollout history deployment/weather-agent

# Rollback to previous version
oc rollout undo deployment/weather-agent

# Rollback to specific revision
oc rollout undo deployment/weather-agent --to-revision=2
```

### OpenShift Web Console

For visual debugging, access the OpenShift web console:

```bash
# Get console URL
oc whoami --show-console

# Login with same credentials
# Navigate to: a2a-morning-routine project → Workloads → Pods
```

---

## Getting Help

If issues persist after trying these solutions:

1. **Check OpenShift Status:** https://status.redhat.com/
2. **Red Hat Developer Support:** https://developers.redhat.com/support
3. **OpenShift Documentation:** https://docs.openshift.com/
4. **GitHub Issues:** https://github.com/YOUR_USERNAME/camel-a2a-morning-routine/issues
5. **Community Forums:** https://discuss.openshift.com/

### Collecting Debug Information

When reporting issues, include:

```bash
# Version information
oc version

# All resources
oc get all -l app=a2a-morning-routine -o yaml > all-resources.yaml

# Pod descriptions
oc describe pods -l app=a2a-morning-routine > pod-descriptions.txt

# Logs from all agents
for agent in weather-agent news-agent fortune-agent traffic-agent email-agent package-agent breakfast-agent assistant; do
  oc logs deployment/$agent > $agent-logs.txt
done

# Recent events
oc get events --sort-by='.lastTimestamp' > events.txt
```
