# K3s Cluster Manifests

This directory contains Kubernetes YAML manifests for the K3s homelab cluster, organized for GitOps management with Flux CD.

## Directory Structure

```
cluster-manifests/
├── infrastructure/          # Core infrastructure components
│   ├── metallb/            # LoadBalancer IP management
│   ├── cert-manager/       # Automatic TLS certificate management
│   └── ingress-nginx/      # Ingress controller (installed via Helm)
├── examples/               # Example applications and test manifests
└── README.md              # This file
```

## Infrastructure Components

### MetalLB (LoadBalancer)

**Location:** `infrastructure/metallb/`

MetalLB provides LoadBalancer IPs for services in the cluster. Configured in Layer 2 mode with IP address pool 192.168.1.240-250.

**Files:**
- `config.yaml` - IPAddressPool and L2Advertisement configuration

**Status:** Deployed and operational
- Longhorn UI: 192.168.1.240
- Ingress-NGINX: 192.168.1.241

**Installation:**
```bash
kubectl apply -f infrastructure/metallb/config.yaml
```

### cert-manager (TLS Certificates)

**Location:** `infrastructure/cert-manager/`

cert-manager automates TLS certificate issuance and renewal using Let's Encrypt ACME protocol. Integrates with ingress-nginx to automatically provision certificates for Ingress resources.

**Files:**
- `namespace.yaml` - cert-manager namespace (created by installation manifest)
- `clusterissuer-staging.yaml` - Let's Encrypt staging issuer (for testing)
- `clusterissuer-production.yaml` - Let's Encrypt production issuer (for real certificates)

**Status:** Ready for deployment

**Installation:**
```bash
# 1. Install cert-manager CRDs and controllers
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.3/cert-manager.yaml

# 2. Wait for cert-manager to be ready
kubectl wait --for=condition=ready pod -l app.kubernetes.io/instance=cert-manager -n cert-manager --timeout=300s

# 3. IMPORTANT: Edit ClusterIssuer files and change email address
# Edit clusterissuer-staging.yaml and clusterissuer-production.yaml
# Replace user@example.com with your actual email

# 4. Apply ClusterIssuers (start with staging for testing)
kubectl apply -f infrastructure/cert-manager/clusterissuer-staging.yaml
kubectl apply -f infrastructure/cert-manager/clusterissuer-production.yaml

# 5. Verify ClusterIssuers are ready
kubectl get clusterissuers
```

**How it works:**
1. Add `cert-manager.io/cluster-issuer` annotation to Ingress resource
2. cert-manager detects the annotation and creates a Certificate resource
3. Certificate triggers ACME HTTP-01 challenge via Let's Encrypt
4. cert-manager creates temporary Ingress route for challenge validation
5. Let's Encrypt validates domain ownership and issues certificate
6. cert-manager stores certificate in Kubernetes TLS secret
7. Ingress controller uses the secret for HTTPS
8. cert-manager automatically renews certificates before expiry

**Staging vs Production:**
- **Staging:** Use `letsencrypt-staging` for testing. No rate limits, but certificates show as untrusted.
- **Production:** Use `letsencrypt-prod` only after successful staging test. Rate limited to 50 certs/domain/week.

### ingress-nginx (Ingress Controller)

**Location:** `infrastructure/ingress-nginx/`

NGINX Ingress Controller provides HTTP/HTTPS routing and load balancing for cluster services.

**Status:** Deployed via Helm
- External IP: 192.168.1.241
- HTTP: Port 80
- HTTPS: Port 443

**Installation:** (Already completed)
```bash
helm upgrade --install ingress-nginx ingress-nginx \
  --repo https://kubernetes.github.io/ingress-nginx \
  --namespace ingress-nginx --create-namespace
```

**Note:** ingress-nginx was installed via Helm rather than static manifests. For GitOps, we will manage it with Flux HelmRelease resources.

## Examples

### Test Ingress with TLS

**Location:** `examples/test-ingress-tls.yaml`

Complete example showing how to deploy an application with automatic TLS certificate from Let's Encrypt.

**Includes:**
- Whoami deployment (simple HTTP test server)
- Service
- Ingress with TLS configuration
- Both staging and production issuer examples

**How to use:**
1. Edit the file and change `whoami.example.com` to your actual domain
2. Ensure DNS points to ingress IP (192.168.1.241)
3. Apply with staging issuer first for testing
4. Switch to production issuer after successful test

```bash
# Edit domain in the file first
kubectl apply -f examples/test-ingress-tls.yaml

# Watch certificate issuance
kubectl get certificate -n whoami-test -w

# Check certificate details
kubectl describe certificate whoami-tls-staging -n whoami-test

# Test access (staging cert will show as untrusted - expected)
curl -v https://whoami.example.com
```

## GitOps Workflow

This directory is prepared for Flux CD GitOps management:

1. **Infrastructure** components are applied in order:
   - MetalLB (provides LoadBalancer IPs)
   - ingress-nginx (provides HTTP/HTTPS routing)
   - cert-manager (provides automatic TLS)

2. **Applications** will be added later in `apps/` directory

3. **Flux** will continuously reconcile cluster state with Git repository

## Cluster Information

- **Platform:** K3s v1.33.6
- **Nodes:** 3 nodes (1 control plane, 2 workers)
- **Network:** 192.168.1.0/24
- **MetalLB Pool:** 192.168.1.240-250
- **Ingress IP:** 192.168.1.241

## Next Steps

1. Deploy cert-manager following instructions above
2. Test certificate issuance with example application
3. Set up Flux CD for GitOps
4. Migrate infrastructure to Flux management
5. Deploy production applications

## Resources

- [MetalLB Documentation](https://metallb.universe.tf/)
- [cert-manager Documentation](https://cert-manager.io/docs/)
- [NGINX Ingress Documentation](https://kubernetes.github.io/ingress-nginx/)
- [Let's Encrypt Rate Limits](https://letsencrypt.org/docs/rate-limits/)
- [Flux CD Documentation](https://fluxcd.io/docs/)
