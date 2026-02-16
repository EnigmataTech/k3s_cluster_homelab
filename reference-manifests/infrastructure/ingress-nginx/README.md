# ingress-nginx (Helm Managed)

The NGINX Ingress Controller is currently managed via Helm, not static YAML manifests.

## Current Installation

```bash
helm upgrade --install ingress-nginx ingress-nginx \
  --repo https://kubernetes.github.io/ingress-nginx \
  --namespace ingress-nginx --create-namespace
```

## Status

- **Status:** Deployed and operational
- **External IP:** 192.168.1.241 (from MetalLB)
- **HTTP Port:** 80
- **HTTPS Port:** 443
- **IngressClass:** nginx

## GitOps Migration

When migrating to Flux CD, this will be managed by a HelmRelease resource:

```yaml
apiVersion: helm.toolkit.fluxcd.io/v2beta1
kind: HelmRelease
metadata:
  name: ingress-nginx
  namespace: ingress-nginx
spec:
  interval: 5m
  chart:
    spec:
      chart: ingress-nginx
      sourceRef:
        kind: HelmRepository
        name: ingress-nginx
        namespace: flux-system
  values:
    controller:
      service:
        loadBalancerIP: 192.168.1.241
```

This file will be created during Flux setup in Phase 4.
