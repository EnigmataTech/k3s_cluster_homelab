# k3s_cluster_homelab

GitOps configuration for my self-hosted homelab — a 3-node k3s cluster running on Proxmox VMs, managed by [Flux CD](https://fluxcd.io). Every change to the cluster ships as a commit.

## What runs here

### Applications (`apps/`)

| App | Purpose |
|---|---|
| [forgejo](https://forgejo.org) | Self-hosted Git (origin for this repo, ironically) |
| [wazuh](https://wazuh.com) | SIEM / host-based intrusion detection — manager + indexer + dashboard |
| [ntfy](https://ntfy.sh) | Self-hosted push notifications (Wazuh alerts route here) |
| [netalertx](https://github.com/jokob-sk/NetAlertX) | LAN device monitoring + intruder alerting |
| ip-speed | Internet speed test cron + Prometheus exporter |
| portfolio | Personal portfolio site (terminal-themed) |
| [deriv-trading-bot](https://github.com/EnigmataTech/deriv-trading-bot) | Trading bot deployment manifests |
| tailscale-ingress | Routes Tailscale-only services |
| [renovate](https://github.com/renovatebot/renovate) | Dependency PRs for this repo |

### Infrastructure (`infrastructure/`)

| Component | Role |
|---|---|
| [longhorn](https://longhorn.io) | Distributed block storage (3× replica) |
| [metallb](https://metallb.universe.tf) | Bare-metal LoadBalancer (IP pool on LAN) |
| [ingress-nginx](https://kubernetes.github.io/ingress-nginx/) | HTTP/HTTPS ingress |
| [cert-manager](https://cert-manager.io) | Automated TLS via Let's Encrypt (DNS-01) |
| [cloudflare-tunnel](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/) | Zero-trust public ingress without port-forwarding |
| monitoring | kube-prometheus-stack — Prometheus, Grafana, Alertmanager |

## Layout

```
.
├── apps/                Per-app manifests, each with its own kustomization
├── infrastructure/      Controllers + their config (cert-manager, MetalLB, ...)
├── clusters/homelab/    Flux entrypoint Kustomizations + flux-system bootstrap
├── scripts/             Operational helpers (load-secrets, migrate-ntfy, etc.)
├── reference-manifests/ Examples + experiments not actively applied
└── MIGRATION-GUIDE.md   VM → k3s migration notes (Wazuh + ntfy, 2026-03)
```

## Secrets

Secrets are encrypted with [SOPS](https://github.com/getsops/sops) using [age](https://github.com/FiloSottile/age) recipients. Encrypted files (e.g. `apps/wazuh/secret.yaml`) are committed as-is; Flux decrypts at apply-time via the `sops-age` Secret in `flux-system`. The age private key lives only on the operator's machine — losing it means losing the ability to edit secrets, but the cluster keeps running.

Encryption rules are in `.sops.yaml` at the repo root. To edit an encrypted secret:

```sh
sops apps/wazuh/secret.yaml
```

## Hardware

- 3× Ubuntu 24.04 VMs on Proxmox (1 control plane + 2 workers, 8 GB RAM each)
- k3s v1.33 — single control plane, no HA (this is a homelab)
- Longhorn-managed storage on each worker
- LAN traffic only; public ingress exclusively through Cloudflare Tunnel

## Why public

Demonstrates a working GitOps homelab end-to-end: kustomize base/overlay structure, Flux source/kustomization separation, SOPS for secret management, MetalLB + cert-manager + Cloudflare Tunnel for ingress, Longhorn for persistent storage. Useful as a reference if you're going from Docker Compose VMs to a real Kubernetes cluster.

## License

MIT — see [LICENSE](LICENSE) if added. Use the patterns freely; the cluster-specific values (hostnames, LAN ranges) will need adjustment for your own environment.
