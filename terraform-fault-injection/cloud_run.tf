################################################################################
# Cloud Run サービス
#
# 注入された障害:
# [FAULT-RUN-01] コンテナのCPU/メモリが極端に不足
# [FAULT-RUN-02] max_instance_count=1 でスケーラビリティ・冗長性なし
# [FAULT-RUN-03] コンテナポート(3000)とヘルスチェックポート(8080)の不一致
# [FAULT-RUN-04] Cloud Loggingへのログ出力レベルが不適切
# [FAULT-RUN-05] サービスアカウントにArtifact Registryからのpull権限がない
# [FAULT-RUN-06] VPCコネクタが未設定 - Cloud SQLへのプライベート接続不可
################################################################################

# Cloud Run サービスアカウント
# [FAULT-RUN-05] 必要な権限（Artifact Registry読み取り）がない
resource "google_service_account" "cloud_run" {
  account_id   = "${var.project_name}-run-sa"
  display_name = "Cloud Run Service Account for ${var.project_name}"
}

# [FAULT-RUN-05] 本来は Artifact Registry Reader ロールを付与すべき
# resource "google_project_iam_member" "artifact_registry_reader" {
#   project = var.gcp_project_id
#   role    = "roles/artifactregistry.reader"
#   member  = "serviceAccount:${google_service_account.cloud_run.email}"
# }

# [FAULT-RUN-06] VPCアクセスコネクタが未設定
# 本来は以下が必要:
# resource "google_vpc_access_connector" "main" {
#   name          = "${var.project_name}-connector"
#   region        = var.gcp_region
#   network       = google_compute_network.main.name
#   ip_cidr_range = "10.8.0.0/28"
#
#   min_instances = 2
#   max_instances = 3
# }

# Cloud Run サービス
resource "google_cloud_run_v2_service" "app" {
  name     = "${var.project_name}-service"
  location = var.gcp_region

  # Ingress設定 - 全トラフィックを許可（LBからのみに制限すべき）
  ingress = "INGRESS_TRAFFIC_ALL"

  template {
    # [FAULT-RUN-02] max_instance_count=1 で単一インスタンスのみ - 冗長性なし
    scaling {
      min_instance_count = 0
      max_instance_count = 1  # スケールアウト不可
    }

    # サービスアカウント設定
    service_account = google_service_account.cloud_run.email

    # [FAULT-RUN-06] VPCアクセスコネクタ未設定 - Cloud SQLにプライベート接続不可
    # vpc_access {
    #   connector = google_vpc_access_connector.main.id
    #   egress    = "PRIVATE_RANGES_ONLY"
    # }

    containers {
      # [FAULT-RUN-05] Artifact Registry権限がないためイメージPull失敗
      image = "asia-northeast1-docker.pkg.dev/${var.gcp_project_id}/myapp/app:latest"

      # [FAULT-RUN-01] リソースが極端に不足
      resources {
        limits = {
          cpu    = "0.25"   # 極端に少ない - 最低1.0が推奨
          memory = "128Mi"  # 極端に少ない - 最低512Miが推奨
        }
        cpu_idle = true  # アイドル時にCPUを解放 - レイテンシ増加の原因
      }

      # [FAULT-RUN-03] コンテナはポート3000で起動
      ports {
        container_port = 3000
      }

      # 環境変数
      env {
        name  = "PORT"
        value = "3000"
      }

      # DBの接続情報をハードコード - Secret Managerを使うべき
      env {
        name  = "DATABASE_URL"
        value = "postgresql://admin:password123@${var.project_name}-db:5432/myapp"
      }

      # [FAULT-RUN-04] ログレベルがDEBUG - 本番ではINFO以上にすべき
      env {
        name  = "LOG_LEVEL"
        value = "DEBUG"
      }

      # スタートアッププローブ未設定 - 起動時間が長い場合にkillされる
      # startup_probe {
      #   http_get {
      #     path = "/health"
      #     port = 3000
      #   }
      #   initial_delay_seconds = 5
      #   period_seconds        = 3
      #   failure_threshold     = 10
      # }

      # ライブネスプローブ未設定
      # liveness_probe {
      #   http_get {
      #     path = "/health"
      #     port = 3000
      #   }
      #   period_seconds    = 10
      #   failure_threshold = 3
      # }
    }

    # タイムアウト設定が短すぎる
    timeout = "10s"  # デフォルト300s - 10sではリクエスト処理に不十分な可能性

    # リビジョン間のトラフィック分割設定なし
    # セッションアフィニティなし
  }

  # トラフィック設定 - 最新リビジョンに100%
  traffic {
    type    = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
    percent = 100
  }
}

# Cloud RunのIAMポリシー - 未認証アクセスを許可
# 本来はLBからのみアクセスを許可すべき
resource "google_cloud_run_v2_service_iam_member" "public_access" {
  project  = var.gcp_project_id
  location = var.gcp_region
  name     = google_cloud_run_v2_service.app.name
  role     = "roles/run.invoker"
  member   = "allUsers"  # 全ユーザーに公開 - 本来はLBのサービスアカウントのみ
}
