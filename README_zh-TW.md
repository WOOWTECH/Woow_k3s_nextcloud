# Woow_k3s_nextcloud — Nextcloud 的 K3s/Kubernetes Helm Chart

[English](README.md)

在 K3s/Kubernetes 上部署 [Nextcloud](https://nextcloud.com) 的 Helm chart,
搭配 PostgreSQL 16(啟用 [pgvector](https://github.com/pgvector/pgvector) 供
AI 相片標記使用)、Redis 快取,以及專用的 cron worker 執行背景任務。

> **要用其他平台部署?**
> Docker/Podman Compose → [Woow_podman_nextcloud](https://github.com/WOOWTECH/Woow_podman_nextcloud) ·
> Home Assistant add-on → [Woow_ha_nextcloud](https://github.com/WOOWTECH/Woow_ha_nextcloud)

## 架構

| 元件 | 映像 | 資源類型 | Service | NodePort |
|---|---|---|---|---|
| Nextcloud | `nextcloud:stable` | Deployment | `nextcloud:80` | `31808` |
| PostgreSQL + pgvector | `pgvector/pgvector:pg16` | StatefulSet | `db:5432` | — |
| Redis | `redis:alpine` | Deployment | `redis:6379` | — |
| Cron(選配) | `nextcloud:stable` | Deployment | — | — |

- 儲存:`local-path` PVC — `nextcloud-html` 5Gi、`nextcloud-data` 50Gi、
  `postgres-data` 10Gi、`redis-data` 1Gi
- Nextcloud 與 Cron 同時掛載 `nextcloud-html` 和 `nextcloud-data`(RWO —
  兩個 pod 會被排程到同一節點)
- 有寫入狀態的元件(Nextcloud、Redis)採用 `Recreate` 策略

## 快速開始

```bash
# 直接以倉庫 tarball 安裝(免 clone)
helm install nextcloud https://github.com/WOOWTECH/Woow_k3s_nextcloud/archive/refs/heads/main.tar.gz

# 或 clone 後安裝
git clone https://github.com/WOOWTECH/Woow_k3s_nextcloud.git
cd Woow_k3s_nextcloud
helm install nextcloud .
```

> **非測試環境部署前務必更換密鑰:**
>
> ```bash
> helm install nextcloud . \
>   --set secrets.postgresPassword="$(openssl rand -base64 24)" \
>   --set secrets.nextcloudAdminPassword="$(openssl rand -base64 24)"
> ```

完成後開啟 `http://<node-ip>:31808`,以 `admin` 帳號和你設定的密碼登入。

### 啟用 pgvector 擴充

當 pod 就緒後,啟用 pgvector 讓 Nextcloud AI 應用(如 Recognize)可使用向量搜尋:

```bash
kubectl exec -n nextcloud statefulset/db -- \
  psql -U nextcloud -d nextcloud -c "CREATE EXTENSION IF NOT EXISTS vector;"
```

## 主要設定值

| 設定 | 預設 | 說明 |
|---|---|---|
| `namespace.create` / `namespace.name` | `true` / `nextcloud` | 目標 namespace |
| `nextcloud.image.tag` | `stable` | Nextcloud 映像 tag |
| `nextcloud.service.type` / `nodePort` | `NodePort` / `31808` | Nextcloud 對外方式 |
| `nextcloud.persistence.html.size` | `5Gi` | 應用檔案 PVC(`local-path`) |
| `nextcloud.persistence.data.size` | `50Gi` | 使用者資料 PVC(`local-path`) |
| `nextcloud.config.*` | 見 `values.yaml` | 環境變數(trusted domains、PHP 上限等) |
| `db.persistence.size` | `10Gi` | PostgreSQL 資料 PVC |
| `redis.persistence.size` | `1Gi` | Redis 持久化 PVC |
| `cron.enabled` | `true` | 是否部署 cron worker |
| `secrets.*` | `changeme-…` | PostgreSQL 與 Nextcloud 管理員密碼 |

完整清單:[`values.yaml`](values.yaml)

## 驗證

```bash
kubectl get pods -n nextcloud                 # 所有 pod 均 Running/Ready
kubectl exec -n nextcloud deploy/nextcloud -- \
  curl -sS -H 'Host: localhost' http://127.0.0.1/status.php
```

## 移除

```bash
helm uninstall nextcloud
# Helm 會保留 PVC;確定不要資料後再刪:
kubectl delete pvc -n nextcloud \
  postgres-data redis-data nextcloud-html nextcloud-data
```

## 從舊 Kustomize 部署遷移

本倉庫取代已封存的
[Woow_nextcloud_docker_compose_all](https://github.com/WOOWTECH/Woow_nextcloud_docker_compose_all)
`k3s` 分支。Chart 預設渲染結果與原 manifests 資源等價(名稱、namespace、
標籤、埠、PVC、PostgreSQL 的 StatefulSet 均相同),既有部署可交由 Helm
接管或維持原狀;原始 Kustomize 檔案保留在本倉庫的 git 歷史中。

## 授權

MIT
