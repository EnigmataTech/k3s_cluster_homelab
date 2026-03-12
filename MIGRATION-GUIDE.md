# Wazuh + ntfy Migration Guide
## VM 100 (UbuntuMonitor) → k3s Cluster

**Migration date:** 2026-03-12
**Wazuh version:** 4.14.0
**ntfy version:** 2.11.0
**New manager IP:** 192.168.1.242 (MetalLB LoadBalancer)

---

## Pre-flight Checklist

- [ ] k3s cluster healthy (`kubectl get nodes`)
- [ ] cert-manager running (`kubectl get pods -n cert-manager`)
- [ ] Longhorn running (`kubectl get pods -n longhorn-system`)
- [ ] MetalLB speakers running (`kubectl get pods -n metallb-system`)
- [ ] 192.168.1.242 not in use (reserved for Wazuh)

---

## Step 1 — Add manifests to repo (on CachyNiri)

```bash
# Clone or pull the k3s_cluster_homelab repo
cd ~/workspace/k3s_cluster_homelab  # or wherever it lives

# Copy the new app directories from the migration bundle
cp -r /path/to/migration/apps/ntfy apps/ntfy
cp -r /path/to/migration/apps/wazuh apps/wazuh

# Add to apps/kustomization.yaml — append these two lines under resources:
#   - ntfy
#   - wazuh

# Commit and push (Flux will auto-apply)
git add apps/ntfy apps/wazuh apps/kustomization.yaml
git commit -m "feat: add ntfy + wazuh k8s migration (replaces VM 100)"
git push
```

---

## Step 2 — Deploy ntfy

Flux will apply automatically after push. Monitor:

```bash
kubectl get pods -n ntfy -w
# Wait for: ntfy-xxx   1/1   Running
```

### 2a. Migrate ntfy user database

```bash
# Run from any machine with kubectl + SSH to monitorlizard
bash scripts/migrate-ntfy.sh
```

### 2b. Verify ntfy

```bash
# Add /etc/hosts entry on test machine:
# 192.168.1.241  ntfy.enigmata.local

curl -H "Authorization: Bearer <your-token>" http://ntfy.enigmata.local/v1/health
# Expected: {"healthy":true}

# Send a test notification
curl -u wazuh-integration:0CB12JwB942djwAcPao0oOfHFQw843Gt \
  -H "Title: Test" -d "ntfy migration test" \
  http://ntfy.enigmata.local/wazuh-high
```

### 2c. Cut over ntfy

Once verified, stop the old ntfy on VM 100:
```bash
ssh enigma@100.81.46.87 "docker stop ntfy"
```

### 2d. Update zeroclaw on phone

```bash
# Add hosts entry (in proot as root or with sudo)
echo '192.168.1.241  ntfy.enigmata.local' >> /etc/hosts

# Update zeroclaw config — change ntfy URL
# Edit /home/enigma/.zeroclaw/config.toml
# Change: http://100.81.46.87:8080 → http://ntfy.enigmata.local

# Also update ~/wazuh_alert_monitor.sh if it has hardcoded ntfy URL
```

---

## Step 3 — Deploy Wazuh

Flux applies automatically. Wazuh takes ~5 minutes for indexer to initialize.

```bash
kubectl get pods -n wazuh -w
# Expected sequence:
#   wazuh-indexer-0   0/1   Init:0/1   (sysctl init)
#   wazuh-indexer-0   0/1   Running    (initializing OpenSearch)
#   wazuh-indexer-0   1/1   Running    (~3-5 min)
#   wazuh-manager-0   0/1   Init:0/1   (jq install)
#   wazuh-manager-0   1/1   Running    (~2 min after indexer ready)
#   wazuh-dashboard   1/1   Running    (~1 min)
```

### 3a. Verify certificates issued

```bash
kubectl get certificates -n wazuh
# All should show READY=True
```

### 3b. Verify Wazuh dashboard

Add to `/etc/hosts` on your browser machine:
```
192.168.1.241  wazuh.enigmata.local
```

Open: `http://wazuh.enigmata.local`
Login: admin / oZL@6l6N!3y$yM

### 3c. Verify manager API

```bash
curl -k -u wazuh-wui:MyS3cr37P450r.*- https://192.168.1.242:55000/
# Expected: {"data":{"title":"Wazuh API REST","api_version":"4.14.0",...}}
```

### 3d. Verify indexer connectivity

```bash
kubectl logs -n wazuh statefulset/wazuh-manager | grep -i "connected\|indexer\|filebeat"
```

---

## Step 4 — Redirect Wazuh Agents

**Before running:** Ensure StingerVPS has subnet routing enabled:
```bash
# On StingerVPS (Hostinger, 100.99.226.7):
sudo tailscale set --accept-routes
# Verify: ping 192.168.1.242 (should succeed via Tailscale subnet route)
```

Note: k3s-control-01 already advertises 192.168.1.0/24 to the tailnet (approved in admin console). StingerVPS just needs to accept routes.

```bash
# Run redirect script (from CachyNiri or any machine with SSH access)
bash scripts/redirect-agents.sh
```

For **Kreation (Windows)**: Manual update required — see script output for instructions.

### Verify all agents connected

```bash
kubectl exec -n wazuh statefulset/wazuh-manager -- \
  /var/ossec/bin/agent_control -l
# All 4 agents should show as Active
```

---

## Step 5 — Cutover Wazuh on VM

Once ALL agents are Active in the new cluster:

```bash
# Stop Wazuh on VM 100
ssh enigma@100.81.46.87 "docker stop single-node-wazuh.manager-1 single-node-wazuh.indexer-1 single-node-wazuh.dashboard-1"
```

Monitor k8s Wazuh for 24 hours. Watch for:
- Alerts still flowing in dashboard
- ntfy notifications still arriving
- No agent disconnections

---

## Step 6 — Decommission VM 100

Only after 24h observation with all systems healthy:

```bash
# Stop all containers on VM 100
ssh enigma@100.81.46.87 "docker stop $(docker ps -q)"

# Destroy VM (from Proxmox)
ssh root@192.168.1.56 "qm destroy 100 --purge"
```

**RAM recovered:** ~10GB → Proxmox drops from ~76% → ~45%

---

## Rollback Plan

If anything goes wrong before decommissioning VM 100:

1. Start Docker services on VM 100: `ssh enigma@100.81.46.87 "docker start $(docker ps -a -q)"`
2. Redirect agents back: update `<address>100.81.46.87</address>` in each ossec.conf
3. Update zeroclaw ntfy URL back to `http://100.81.46.87:8080`

---

## New Architecture

| Service | Endpoint | Auth |
|---------|----------|------|
| ntfy | http://ntfy.enigmata.local | Bearer token |
| Wazuh Dashboard | http://wazuh.enigmata.local | admin / oZL@6l6N!3y$yM |
| Wazuh API | https://192.168.1.242:55000 | wazuh-wui / MyS3cr37P450r.*- |
| Wazuh Agents | 192.168.1.242:1514/1515 | SSL agent auth |

---

## Resource Budget (actual vs plan)

| Component | CPU req | Mem req |
|-----------|---------|---------|
| ntfy | 50m | 64Mi |
| wazuh-indexer | 500m | 1.2Gi (heap: 1GB) |
| wazuh-manager | 500m | 512Mi |
| wazuh-dashboard | 200m | 512Mi |
| **Total** | **1250m** | **~2.3Gi** |

Workers have ~3.2–3.5GB free each. Fits comfortably.
