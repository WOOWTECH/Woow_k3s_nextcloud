# Woow_k3s_nextcloud — Nextcloud Helm Chart for K3s/Kubernetes

[繁體中文](README_zh-TW.md)

Helm chart deploying [Nextcloud](https://nextcloud.com) on K3s/Kubernetes with
PostgreSQL 16 ([pgvector](https://github.com/pgvector/pgvector) enabled for AI
photo tagging), Redis cache and a dedicated cron worker for background jobs.

> **Looking for another platform?**
> Docker/Podman Compose → [Woow_podman_nextcloud](https://github.com/WOOWTECH/Woow_podman_nextcloud) ·
> Home Assistant add-on → [Woow_ha_nextcloud](https://github.com/WOOWTECH/Woow_ha_nextcloud)

## Architecture

| Component | Image | Kind | Service | NodePort |
|---|---|---|---|---|
| Nextcloud | `nextcloud:stable` | Deployment | `nextcloud:80` | `31808` |
| PostgreSQL + pgvector | `pgvector/pgvector:pg16` | StatefulSet | `db:5432` | — |
| Redis | `redis:alpine` | Deployment | `redis:6379` | — |
| Cron (optional) | `nextcloud:stable` | Deployment | — | — |

- Storage: `local-path` PVCs — `nextcloud-html` 5Gi, `nextcloud-data` 50Gi,
  `postgres-data` 10Gi, `redis-data` 1Gi
- Nextcloud + Cron mount both `nextcloud-html` and `nextcloud-data` (RWO —
  co-scheduled on the same node)
- `Recreate` strategy on stateful writers (Nextcloud, Redis)

## Quick start

```bash
# Install straight from the repo tarball (no clone needed)
helm install nextcloud https://github.com/WOOWTECH/Woow_k3s_nextcloud/archive/refs/heads/main.tar.gz

# Or from a local clone
git clone https://github.com/WOOWTECH/Woow_k3s_nextcloud.git
cd Woow_k3s_nextcloud
helm install nextcloud .
```

> **Change the secrets before any non-test deployment:**
>
> ```bash
> helm install nextcloud . \
>   --set secrets.postgresPassword="$(openssl rand -base64 24)" \
>   --set secrets.nextcloudAdminPassword="$(openssl rand -base64 24)"
> ```

Then open `http://<node-ip>:31808` and log in as `admin` with the password you set.

### Enable the pgvector extension

Once the pod is Ready, enable pgvector so Nextcloud AI apps (e.g. Recognize) can
use vector search:

```bash
kubectl exec -n nextcloud statefulset/db -- \
  psql -U nextcloud -d nextcloud -c "CREATE EXTENSION IF NOT EXISTS vector;"
```

## Key values

| Value | Default | Description |
|---|---|---|
| `namespace.create` / `namespace.name` | `true` / `nextcloud` | Target namespace |
| `nextcloud.image.tag` | `stable` | Nextcloud image tag |
| `nextcloud.service.type` / `nodePort` | `NodePort` / `31808` | How Nextcloud is exposed |
| `nextcloud.persistence.html.size` | `5Gi` | Application-files PVC (`local-path`) |
| `nextcloud.persistence.data.size` | `50Gi` | User-data PVC (`local-path`) |
| `nextcloud.config.*` | see `values.yaml` | Env vars (trusted domains, PHP limits, etc.) |
| `db.persistence.size` | `10Gi` | PostgreSQL data PVC |
| `redis.persistence.size` | `1Gi` | Redis persistence PVC |
| `cron.enabled` | `true` | Deploy the cron worker |
| `secrets.*` | `changeme-…` | PostgreSQL & Nextcloud admin passwords |

Full list: [`values.yaml`](values.yaml)

## Verify

```bash
kubectl get pods -n nextcloud                 # all pods Running/Ready
kubectl exec -n nextcloud deploy/nextcloud -- \
  curl -sS -H 'Host: localhost' http://127.0.0.1/status.php
```

## Uninstall

```bash
helm uninstall nextcloud
# PVCs are kept by Helm; remove them (and your data!) with:
kubectl delete pvc -n nextcloud \
  postgres-data redis-data nextcloud-html nextcloud-data
```

## Migrating from the old Kustomize deployment

This repository replaces the `k3s` branch of the archived
[Woow_nextcloud_docker_compose_all](https://github.com/WOOWTECH/Woow_nextcloud_docker_compose_all)
repo. The chart's default rendering is resource-equivalent to those manifests
(same names, namespace, labels, ports, PVCs, StatefulSet for PostgreSQL), so an
existing deployment can be adopted by Helm or simply left as-is; the original
Kustomize files remain available in this repo's git history.

## License

MIT
