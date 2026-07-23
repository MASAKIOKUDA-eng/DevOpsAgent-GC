################################################################################
# Cloud Run サービス (ECS Fargate相当)
#
# 注入された障害:
# [FAULT-RUN-01] コンテナのCPU/メモリが極端に不足
# [FAULT-RUN-02] max_instance_count=1 でスケーラビリティ・冗長性なし
# [FAULT-RUN-03] コンテナポート(3000)とターゲットグループポート(8080)の不一致
# [FAULT-RUN-04] ログ設定なし - 構造化ログが出力されない
# [FAULT-RUN-05] サービスアカウントにArtifact Registryからのpull権限がない
################################################################################

# Cloud Run サービスアカウント
# [FAULT-RUN-05] ECR Pull権限相当（Artifact Registry Reader）がないため、イメージ取得に失敗する
resource "google_service_account" "cloud_run" {
  account_id   = "${var.project_name}-run-sa"
  display_name = "Cloud Run Service Account for ${var.project_name}"
}

# [FAULT-RUN-05] 本来は Artifact Registry Reader ロールをアタッチすべき
# resource "google_project_iam_member" "artifact_registry_reader" {
#   project = var.gcp_project_id
#   role    = "roles/artifactregistry.reader"
#   member  = "serviceAccount:${google_service_account.cloud_run.email}"
# }

# Cloud Run サービス
# [FAULT-RUN-01] CPU: 0.25, Memory: 256Mi は Node.js アプリには不十分
# [FAULT-RUN-03] コンテナポート3000だがヘルスチェック/FWは8080を期待
resource "google_cloud_run_v2_service" "app" {
  name     = "${var.project_name}-service"
  location = var.gcp_region
  ingress  = "INGRESS_TRAFFIC_ALL"

  template {
    # [FAULT-RUN-02] max_instance_count=1 で単一インスタンスのみ - 耐障害性なし
    scaling {
      min_instance_count = 0
      max_instance_count = 1
    }

    service_account = google_service_account.cloud_run.email

    containers {
      # [FAULT-RUN-05] Artifact Registry権限がないためイメージPull失敗
      image = "us-docker.pkg.dev/cloudrun/container/hello:latest"

      # [FAULT-RUN-01] リソースが極端に不足
      resources {
        limits = {
          cpu    = "1"
          memory = "256Mi"
        }
      }

      # [FAULT-RUN-03] コンテナはポート3000だが、FW/ヘルスチェックはポート8080を期待
      ports {
        container_port = 3000
      }

      # [FAULT-RUN-04] ログ設定なし - CloudWatch Logs相当の出力なし
      # logConfiguration相当がない

      env {
        name  = "PORT"
        value = "3000"
      }
      env {
        # DBの接続情報をハードコード - Secret Managerを使うべき
        name  = "DATABASE_URL"
        value = "postgresql://admin:password123@${var.project_name}-db:5432/myapp"
      }
    }
  }

  traffic {
    type    = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
    percent = 100
  }
}

# Cloud Run IAM - 未認証アクセスを許可
resource "google_cloud_run_v2_service_iam_member" "public_access" {
  project  = var.gcp_project_id
  location = var.gcp_region
  name     = google_cloud_run_v2_service.app.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}
