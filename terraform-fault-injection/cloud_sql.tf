################################################################################
# Cloud SQL for PostgreSQL (RDS相当)
#
# 注入された障害:
# [FAULT-SQL-01] Multi-AZ(高可用性)無効 - 単一障害点
# [FAULT-SQL-02] パブリックアクセス有効 - インターネットからDB直接アクセス可能
# [FAULT-SQL-03] 暗号化無効(CMEK未設定) - データがデフォルト暗号化のみ
# [FAULT-SQL-04] 自動バックアップ無効 - データ復旧不能
# [FAULT-SQL-05] パスワードがハードコード - セキュリティリスク
# [FAULT-SQL-06] 削除保護なし & 最終スナップショットなし
################################################################################

# Cloud SQL インスタンス
resource "google_sql_database_instance" "main" {
  name             = "${var.project_name}-db"
  database_version = "POSTGRES_14"
  region           = var.gcp_region

  # [FAULT-SQL-06] 削除保護なし & 最終スナップショットスキップ相当
  deletion_protection = false

  settings {
    # 本番には不十分なスペック (db.t3.micro相当)
    tier = "db-f1-micro"

    # [FAULT-SQL-01] Multi-AZ無効 (ZONAL = 単一ゾーン)
    availability_type = "ZONAL"

    # ストレージ設定
    disk_size       = 10
    disk_autoresize = false  # オートスケーリング無効
    disk_type       = "PD_HDD"

    # [FAULT-SQL-04] 自動バックアップ無効 (retention = 0 相当)
    backup_configuration {
      enabled                        = false
      point_in_time_recovery_enabled = false
    }

    # [FAULT-SQL-02] パブリックアクセス有効
    ip_configuration {
      ipv4_enabled = true  # パブリックIP有効
      # private_network未設定 = プライベート接続なし

      # 全IPからアクセス許可
      authorized_networks {
        name  = "allow-all"
        value = "0.0.0.0/0"
      }

      require_ssl = false
    }

    # パフォーマンスインサイト無効
    insights_config {
      query_insights_enabled = false
    }
  }

  # [FAULT-SQL-03] CMEK暗号化なし（Googleデフォルト暗号化のみ）
  # encryption_key_name = google_kms_crypto_key.sql_key.id
}

# データベース
resource "google_sql_database" "main" {
  name     = "myapp"
  instance = google_sql_database_instance.main.name
}

# データベースユーザー
# [FAULT-SQL-05] パスワードがTerraformコードにハードコード
resource "google_sql_user" "admin" {
  name     = "admin"
  instance = google_sql_database_instance.main.name
  password = "password123"
}
