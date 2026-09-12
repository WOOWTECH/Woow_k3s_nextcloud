# Woow_k3s_nextcloud — Nextcloud 的 K3s/Kubernetes Helm Chart

[English](README.md)

![chart](https://github.com/WOOWTECH/Woow_k3s_nextcloud/actions/workflows/lint.yml/badge.svg)

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

## 密鑰(Secret)

預設(`secrets.create=false`)這個 chart **不會**管理 `nextcloud-secret`:
它必須已經存在,這樣 `helm upgrade` 就不可能把真正的密碼覆寫成空值。
先照 [`examples/secrets.example.yaml`](examples/secrets.example.yaml) 建立
(把每個 `REPLACE_ME_*` 換成真的值,副本放在倉庫外面):

```bash
kubectl create namespace nextcloud
kubectl apply -f /secure/path/secrets.yaml   # 你改過的 examples/secrets.example.yaml 副本
```

如果是測試安裝,想讓 chart 自己產生 Secret,設定 `secrets.create=true`
並帶入真實的值——兩個密碼任一留空都會讓渲染失敗並印出明確訊息:

```bash
helm install nextcloud . \
  --set secrets.create=true \
  --set secrets.postgresPassword="$(openssl rand -base64 24)" \
  --set secrets.nextcloudAdminPassword="$(openssl rand -base64 24)"
```

## 快速開始

```bash
# 直接以倉庫 tarball 安裝(免 clone)
helm install nextcloud https://github.com/WOOWTECH/Woow_k3s_nextcloud/archive/refs/heads/main.tar.gz \
  --set secrets.create=true \
  --set secrets.postgresPassword="$(openssl rand -base64 24)" \
  --set secrets.nextcloudAdminPassword="$(openssl rand -base64 24)"

# 或 clone 後安裝
git clone https://github.com/WOOWTECH/Woow_k3s_nextcloud.git
cd Woow_k3s_nextcloud
helm install nextcloud . \
  --set secrets.create=true \
  --set secrets.postgresPassword="$(openssl rand -base64 24)" \
  --set secrets.nextcloudAdminPassword="$(openssl rand -base64 24)"
```

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
| `secrets.create` | `false` | 是否由 chart 從下面的值渲染 `nextcloud-secret`,而不是要求它已經存在 |
| `secrets.postgresPassword` / `secrets.nextcloudAdminPassword` | `""` | `secrets.create=true` 時必填(留空會讓渲染失敗) |
| `keepOnUninstall` | `true` | `helm uninstall` 時保留 Namespace、所有 PVC 與 Secret |
| `tests.enabled` | `true` | 是否渲染 `helm test` 的煙霧測試 pod |

完整清單:[`values.yaml`](values.yaml)

## 驗證

```bash
kubectl get pods -n nextcloud                 # 所有 pod 均 Running/Ready
kubectl exec -n nextcloud deploy/nextcloud -- \
  curl -sS -H 'Host: localhost' http://127.0.0.1/status.php

# 唯讀煙霧測試:status.php 回報已安裝、Nextcloud 的資料表存在
helm test nextcloud -n nextcloud
```

## 移除

```bash
helm uninstall nextcloud
```

預設 `keepOnUninstall: true` 下,Namespace、四個 PVC(`postgres-data`、
`redis-data`、`nextcloud-html`、`nextcloud-data`)和 `nextcloud-secret`
Secret 都帶有 `helm.sh/resource-policy: keep`,uninstall 後原封不動地保
留——把 chart 重新裝回同一個 namespace 就能接回原本的資料。如果真的要
連資料一起刪掉:

```bash
kubectl delete pvc -n nextcloud postgres-data redis-data nextcloud-html nextcloud-data
kubectl delete secret -n nextcloud nextcloud-secret
kubectl delete namespace nextcloud
```

## 從舊 Kustomize 部署遷移

本倉庫取代已封存的
[Woow_nextcloud_docker_compose_all](https://github.com/WOOWTECH/Woow_nextcloud_docker_compose_all)
`k3s` 分支。Chart 預設渲染結果與原 manifests 資源等價(名稱、namespace、
標籤、埠、PVC、PostgreSQL 的 StatefulSet 均相同),既有部署可交由 Helm
接管或維持原狀;原始 Kustomize 檔案保留在本倉庫的 git 歷史中。

**Phase 1 現況:**目前 WOOWTECH 叢集裡沒有任何叢集在跑這個 chart 的正式
釋出(不需要、也沒有執行接管演練)。上面的說明是給日後有人要接管既有
`kubectl apply` 部署時參考用的。

## 授權

MIT
