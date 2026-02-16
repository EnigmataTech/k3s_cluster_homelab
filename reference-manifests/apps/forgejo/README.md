# Forgejo Deployment on K3s

Production-grade Forgejo Git hosting platform with PostgreSQL + Redis backend and Tailscale-only access.

## Architecture Overview

```
Tailscale Network (100.x.x.x)
    ↓
Tailscale Kubernetes Operator (Ingress)
    ↓
Forgejo Service (2 replicas) → PostgreSQL (10Gi PVC)
    ↓                       → Redis (2Gi PVC)
    ↓
Forgejo Data PVC (20Gi Longhorn)
```

**Access Method:** Tailscale-only (git.internal) - No public exposure
**Database:** PostgreSQL 17-alpine + Redis 7.2-alpine
**Storage:** 32Gi total (PostgreSQL 10Gi + Redis 2Gi + Forgejo 20Gi)
**High Availability:** 2 Forgejo replicas for zero-downtime deployments

---

## Prerequisites

### 1. Tailscale Kubernetes Operator

**Check if already installed:**
```bash
kubectl get pods -n tailscale
```

**Install if needed:**
```bash
# Get OAuth credentials from Tailscale Admin Console
# Navigate to: Settings > OAuth Clients > Generate OAuth Client

helm repo add tailscale https://pkgs.tailscale.com/helmcharts
helm repo update

helm install tailscale-operator tailscale/tailscale-operator \
  --namespace=tailscale \
  --create-namespace \
  --set-string oauth.clientId="<your-oauth-client-id>" \
  --set-string oauth.clientSecret="<your-oauth-client-secret>" \
  --wait

# Verify installation
kubectl get pods -n tailscale
kubectl get ingressclass
# Should show: tailscale
```

### 2. Longhorn Storage

Verify Longhorn is available:
```bash
kubectl get storageclass longhorn
```

### 3. Generate Secrets

**IMPORTANT:** Save these credentials securely before deploying!

```bash
# Generate PostgreSQL password
export POSTGRES_PASSWORD=$(openssl rand -base64 32)

# Generate Forgejo admin password
export FORGEJO_ADMIN_PASSWORD=$(openssl rand -base64 32)

# Generate Forgejo secret key (for JWT tokens)
export FORGEJO_SECRET_KEY=$(openssl rand -base64 64)

# Generate internal token (for API authentication)
export FORGEJO_INTERNAL_TOKEN=$(openssl rand -base64 64)

# Display credentials (save these!)
echo "========================================="
echo "SAVE THESE CREDENTIALS SECURELY!"
echo "========================================="
echo "PostgreSQL Password: $POSTGRES_PASSWORD"
echo "Forgejo Admin Password: $FORGEJO_ADMIN_PASSWORD"
echo "Forgejo Secret Key: $FORGEJO_SECRET_KEY"
echo "Internal Token: $FORGEJO_INTERNAL_TOKEN"
echo "========================================="
```

---

## Deployment Steps

### Step 1: Create Namespace

```bash
kubectl apply -f namespace.yaml
```

**Verify:**
```bash
kubectl get namespace forgejo
```

### Step 2: Create Kubernetes Secrets

```bash
# PostgreSQL credentials
kubectl create secret generic postgresql-credentials \
  --namespace=forgejo \
  --from-literal=password="$POSTGRES_PASSWORD"

# Forgejo application secrets
kubectl create secret generic forgejo-secrets \
  --namespace=forgejo \
  --from-literal=admin-password="$FORGEJO_ADMIN_PASSWORD" \
  --from-literal=secret-key="$FORGEJO_SECRET_KEY" \
  --from-literal=internal-token="$FORGEJO_INTERNAL_TOKEN"
```

**Verify:**
```bash
kubectl get secrets -n forgejo
```

### Step 3: Deploy PostgreSQL

```bash
kubectl apply -f postgresql.yaml

# Wait for PostgreSQL to be ready
kubectl wait --for=condition=ready pod -l app=postgresql -n forgejo --timeout=300s
```

**Initialize Database:**
```bash
# Get PostgreSQL password
POSTGRES_PASSWORD=$(kubectl get secret postgresql-credentials -n forgejo -o jsonpath='{.data.password}' | base64 -d)

# Initialize database
kubectl exec -it -n forgejo postgresql-0 -- psql -U postgres <<EOF
CREATE DATABASE forgejo;
CREATE USER forgejo WITH PASSWORD '$POSTGRES_PASSWORD';
GRANT ALL PRIVILEGES ON DATABASE forgejo TO forgejo;
ALTER DATABASE forgejo OWNER TO forgejo;
\q
EOF
```

**Verify:**
```bash
kubectl get pods -n forgejo -l app=postgresql
kubectl get pvc -n forgejo -l app=postgresql
```

### Step 4: Deploy Redis

```bash
kubectl apply -f redis.yaml

# Wait for Redis to be ready
kubectl wait --for=condition=ready pod -l app=redis -n forgejo --timeout=180s
```

**Verify:**
```bash
kubectl get pods -n forgejo -l app=redis
kubectl exec -it -n forgejo $(kubectl get pod -n forgejo -l app=redis -o jsonpath='{.items[0].metadata.name}') -- redis-cli ping
# Expected: PONG
```

### Step 5: Deploy Forgejo

```bash
# Deploy ConfigMap
kubectl apply -f configmap.yaml

# Deploy Forgejo application
kubectl apply -f deployment.yaml

# Deploy Service
kubectl apply -f service.yaml

# Wait for Forgejo pods to be ready
kubectl wait --for=condition=ready pod -l app=forgejo -n forgejo --timeout=300s
```

**Verify:**
```bash
kubectl get pods -n forgejo -l app=forgejo
kubectl get pvc -n forgejo -l app=forgejo

# Check Forgejo logs
kubectl logs -n forgejo -l app=forgejo --tail=50

# Test health endpoint
kubectl exec -it -n forgejo $(kubectl get pod -n forgejo -l app=forgejo -o jsonpath='{.items[0].metadata.name}') -- \
  curl -f http://localhost:3000/api/healthz
# Expected: {"status":"pass"}
```

### Step 6: Deploy Tailscale Ingress

```bash
kubectl apply -f ingress.yaml

# Wait for Ingress to be provisioned
kubectl get ingress -n forgejo -w
```

**Get Tailscale URL:**
```bash
kubectl describe ingress forgejo -n forgejo

# Look for the MagicDNS URL (typically: git-forgejo-forgejo.<tailnet>.ts.net)
# Or use the custom hostname: git.internal (if MagicDNS configured)
```

---

## Accessing Forgejo

### From Tailscale Device

**Option 1: MagicDNS Name**
```
https://git-forgejo-forgejo.<your-tailnet>.ts.net
```

**Option 2: Custom Hostname** (if MagicDNS configured)
```
https://git.internal
```

### Initial Setup

1. Navigate to Forgejo URL from Tailscale device
2. First-time setup should auto-configure (already done via ConfigMap)
3. Login with admin credentials from `forgejo-secrets`

**Get admin password:**
```bash
kubectl get secret forgejo-secrets -n forgejo -o jsonpath='{.data.admin-password}' | base64 -d && echo
```

### Creating First Repository

1. Click "+" in top right > "New Repository"
2. Enter repository name and settings
3. Click "Create Repository"

**Clone repository:**
```bash
# HTTPS (recommended)
git clone https://git.internal/<username>/<repo>.git

# SSH (requires SSH key setup in Forgejo profile)
git clone git@git.internal:<username>/<repo>.git
```

---

## Verification Tests

### 1. Database Connectivity
```bash
kubectl exec -it -n forgejo $(kubectl get pod -n forgejo -l app=forgejo -o jsonpath='{.items[0].metadata.name}') -- \
  nc -zv postgresql.forgejo.svc.cluster.local 5432
# Expected: Connection successful
```

### 2. Redis Connectivity
```bash
kubectl exec -it -n forgejo $(kubectl get pod -n forgejo -l app=redis -o jsonpath='{.items[0].metadata.name}') -- \
  redis-cli ping
# Expected: PONG
```

### 3. Forgejo Health
```bash
kubectl exec -it -n forgejo $(kubectl get pod -n forgejo -l app=forgejo -o jsonpath='{.items[0].metadata.name}') -- \
  curl -f http://localhost:3000/api/healthz
# Expected: {"status":"pass"}
```

### 4. High Availability Test
```bash
# Delete one Forgejo pod
kubectl delete pod -n forgejo -l app=forgejo --force --grace-period=0

# Verify automatic recreation
kubectl get pods -n forgejo -l app=forgejo -w

# Service should remain accessible during pod restart
```

### 5. Create Test Repository
From Tailscale device:
1. Access Forgejo web UI
2. Login with admin credentials
3. Create test repository
4. Clone locally and push test commit
5. Verify commit appears in web UI

---

## Resource Usage

| Component | CPU Request | CPU Limit | RAM Request | RAM Limit | Storage |
|-----------|-------------|-----------|-------------|-----------|---------|
| PostgreSQL | 250m | 1000m | 256Mi | 1Gi | 10Gi |
| Redis | 100m | 500m | 128Mi | 512Mi | 2Gi |
| Forgejo (x2) | 400m | 2000m | 512Mi | 2Gi | 20Gi |
| **Total** | **750m** | **3500m** | **896Mi** | **3.5Gi** | **32Gi** |

---

## Maintenance

### Backup PostgreSQL Database

```bash
# Create backup
kubectl exec -n forgejo postgresql-0 -- \
  pg_dump -U forgejo -F c -b -v forgejo > forgejo_backup_$(date +%Y%m%d).dump

# Restore from backup
kubectl exec -i -n forgejo postgresql-0 -- \
  pg_restore -U forgejo -d forgejo -v < forgejo_backup_20260109.dump
```

### Backup Git Repositories

```bash
# Backup repositories
kubectl exec -n forgejo $(kubectl get pod -n forgejo -l app=forgejo -o jsonpath='{.items[0].metadata.name}') -- \
  tar czf /tmp/git-backup.tar.gz /data/git/repositories

# Copy backup out of cluster
kubectl cp forgejo/$(kubectl get pod -n forgejo -l app=forgejo -o jsonpath='{.items[0].metadata.name}'):/tmp/git-backup.tar.gz \
  ./git-backup-$(date +%Y%m%d).tar.gz
```

### Update Forgejo Version

```bash
# Edit deployment.yaml and change image tag
# Example: codeberg.org/forgejo/forgejo:15 → codeberg.org/forgejo/forgejo:16

kubectl apply -f deployment.yaml

# Monitor rollout
kubectl rollout status deployment/forgejo -n forgejo
```

### Scale Forgejo Replicas

```bash
# Increase replicas
kubectl scale deployment forgejo -n forgejo --replicas=3

# Decrease replicas
kubectl scale deployment forgejo -n forgejo --replicas=1
```

---

## Troubleshooting

### Issue: Pods in CrashLoopBackOff

**Diagnose:**
```bash
kubectl logs -n forgejo -l app=forgejo --tail=100
kubectl describe pod -n forgejo -l app=forgejo
```

**Common Causes:**
1. **Database connection failure**
   - Verify PostgreSQL is running: `kubectl get pods -n forgejo -l app=postgresql`
   - Check credentials: `kubectl get secret postgresql-credentials -n forgejo -o yaml`
   - Test connectivity: See verification tests above

2. **ConfigMap misconfiguration**
   - Validate app.ini syntax in configmap.yaml
   - Check database connection string format

3. **PVC not mounting**
   - Verify PVC is bound: `kubectl get pvc -n forgejo`
   - Check Longhorn status: `kubectl get pv | grep forgejo`

**Solution:**
```bash
# Fix configuration and redeploy
kubectl delete pod -n forgejo -l app=forgejo
kubectl wait --for=condition=ready pod -l app=forgejo -n forgejo --timeout=300s
```

### Issue: Tailscale Ingress not working

**Diagnose:**
```bash
kubectl get ingress -n forgejo
kubectl describe ingress forgejo -n forgejo
kubectl logs -n tailscale -l app=tailscale-operator
```

**Common Causes:**
1. Tailscale Operator not installed
2. OAuth credentials not configured
3. MagicDNS disabled on Tailnet

**Solution:**
```bash
# Verify Tailscale Operator is running
kubectl get pods -n tailscale

# Check Ingress class
kubectl get ingressclass
# Should show: tailscale

# Recreate Ingress
kubectl delete ingress forgejo -n forgejo
kubectl apply -f ingress.yaml
```

### Issue: Database connection refused

**Diagnose:**
```bash
# Test connectivity from Forgejo pod
kubectl exec -it -n forgejo $(kubectl get pod -n forgejo -l app=forgejo -o jsonpath='{.items[0].metadata.name}') -- \
  nc -zv postgresql.forgejo.svc.cluster.local 5432

# Check PostgreSQL logs
kubectl logs -n forgejo -l app=postgresql
```

**Common Causes:**
1. PostgreSQL not ready
2. Incorrect service name in app.ini
3. Database not initialized

**Solution:**
```bash
# Verify PostgreSQL service
kubectl get svc postgresql -n forgejo

# Reinitialize database (see Step 3 above)
```

### Issue: Git clone/push fails

**Diagnose:**
```bash
# Check Forgejo logs for Git operations
kubectl logs -n forgejo -l app=forgejo | grep "git"

# Verify repository permissions
kubectl exec -it -n forgejo $(kubectl get pod -n forgejo -l app=forgejo -o jsonpath='{.items[0].metadata.name}') -- \
  ls -la /data/git/repositories
```

**Common Causes:**
1. File permissions on PVC
2. Git LFS not configured
3. Repository path incorrect in app.ini

**Solution:**
```bash
# Fix permissions (already handled by init container, but manual fix if needed)
kubectl exec -it -n forgejo $(kubectl get pod -n forgejo -l app=forgejo -o jsonpath='{.items[0].metadata.name}') -- \
  chown -R 1000:1000 /data/git/repositories

# Restart Forgejo
kubectl rollout restart deployment/forgejo -n forgejo
```

---

## Rollback Strategy

### Immediate Rollback
```bash
# Delete Forgejo deployment
kubectl delete deployment forgejo -n forgejo

# Review logs and fix configuration
kubectl logs -n forgejo -l app=forgejo --previous

# Redeploy after fixes
kubectl apply -f deployment.yaml
```

### Database Rollback
```bash
# Restore from backup
kubectl exec -i -n forgejo postgresql-0 -- \
  pg_restore -U forgejo -d forgejo -v -c < forgejo_backup_20260109.dump
```

### Complete Teardown
```bash
# WARNING: This deletes all data!
kubectl delete namespace forgejo
kubectl delete pvc -n forgejo --all
```

---

## Security Notes

- **Tailscale-Only Access:** Forgejo is not exposed to the internet
- **TLS:** Automatic via Tailscale with Let's Encrypt certificates
- **Secrets:** Database and admin credentials stored in Kubernetes Secrets
- **Network Isolation:** Forgejo namespace isolated from other applications
- **Non-Root:** Containers run as non-root user (UID 1000)
- **Security Context:** Privilege escalation disabled, all capabilities dropped

---

## Configuration Details

### app.ini Location
- **ConfigMap:** `forgejo-config`
- **Mount Path:** `/etc/gitea/app.ini`
- **Edit:** Modify `configmap.yaml` and reapply

### Environment Variables
Secrets are injected via environment variables:
- `FORGEJO__database__PASSWD` - PostgreSQL password
- `FORGEJO__security__SECRET_KEY` - JWT signing key
- `FORGEJO__security__INTERNAL_TOKEN` - API authentication token
- `FORGEJO__server__LFS_JWT_SECRET` - Git LFS JWT secret

### Storage Paths
- **Git Repositories:** `/data/git/repositories` (20Gi PVC)
- **Git LFS:** `/data/git/lfs`
- **Attachments:** `/data/attachments`
- **Logs:** `/data/log`
- **Indexers:** `/data/indexers`

---

## Next Steps

### Enable CI/CD Actions

Forgejo Actions are enabled in the configuration. To use them:

1. Deploy Actions Runner pods
2. Register runners with Forgejo
3. Create `.forgejo/workflows/*.yml` in repositories

### Configure SSH Access

**Option 1: Via Tailscale** (Recommended)
Git clone via SSH works automatically through Tailscale MagicDNS.

**Option 2: Via LoadBalancer**
Add LoadBalancer service for port 22:
```yaml
apiVersion: v1
kind: Service
metadata:
  name: forgejo-ssh
  namespace: forgejo
spec:
  type: LoadBalancer
  loadBalancerIP: 192.168.1.242  # Next available MetalLB IP
  ports:
  - name: ssh
    port: 22
    targetPort: 22
  selector:
    app: forgejo
```

### Setup Automated Backups

Deploy CronJob for daily backups:
```bash
# Create backup CronJob (example in cluster-manifests/examples/)
kubectl apply -f forgejo-backup-cronjob.yaml
```

---

## References

- [Forgejo Documentation](https://forgejo.org/docs/latest/)
- [Forgejo Configuration Cheat Sheet](https://forgejo.org/docs/latest/admin/config-cheat-sheet/)
- [Tailscale Kubernetes Operator](https://tailscale.com/kb/1185/kubernetes)
- [Deployment Plan](/home/enigma/.claude/plans/distributed-knitting-wall.md)

---

**Status:** Ready for deployment
**Deployment Time:** ~60 minutes
**Tested On:** K3s v1.33.6
