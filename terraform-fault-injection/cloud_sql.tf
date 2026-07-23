################################################################################
# Cloud SQL for PostgreSQL
#
# 注入された障害:
# [FAULT-SQL-01] 高可用性(HA)無効 - 単一障害点
# [FAULT-SQL-02] パブリックIPが有効 - インターネットからDB直接アクセス可能
# [FAULT-SQL-03] 暗号化がデフォルトのまま - CMEKによるカスタム暗号化なし
# [FAULT-SQL-04] 自動バックアップ無効 - データ復旧不能
# [FAULT-SQL-05] パスワードがハードコード - セキュリティリスク
# [FAULT-SQL-06] 削除保護なし & データベースフラグ未設定
# [FAULT-SQL-07] Authorized Networksが0.0.0.0/0 - 全IPからアクセス可能
################################################################################

# Cloud SQL インスタンス
resource "google_sql_database_instance" "main" {
  name             = "${var.project_name}-db"
  database_version = "POSTGRES_14"
  region           = var.gcp_region

  # [FAULT-SQL-06] 削除保護なし
  deletion_protection = false

  settings {
    # 本番には不十分なスペック
    tier = "db-f1-micro"

    # [FAULT-SQL-01] 高可用性が無効 - フェイルオーバー不可
    availability_type = "ZONAL"  # 本来は "REGIONAL" にすべき

    # ディスク設定
    disk_size         = 10       # GB - 最小限
    disk_autoresize   = false    # オートスケーリング無効
    disk_type         = "PD_HDD" # HDDはSSDより低速

    # [FAULT-SQL-04] 自動バックアップ無効
    backup_configuration {
      enabled                        = false  # バックアップ無効
      point_in_time_recovery_enabled = false  # PITR無効
      # transaction_log_retention_days = 7
      # backup_retention_settings {
      #   retained_backups = 7
      # }
    }

    # [FAULT-SQL-02] パブリックIPが有効
    ip_configuration {
      ipv4_enabled    = true   # パブリックIP有効 - 本来はfalseにすべき
      private_network = null   # プライベートネットワーク接続なし

      # [FAULT-SQL-07] 全IPからのアクセスを許可
      authorized_networks {
        name  = "allow-all"
        value = "0.0.0.0/0"  # 全世界からアクセス可能
      }

      # SSL接続を強制しない
      require_ssl = false
    }

    # [FAULT-SQL-06] データベースフラグ未設定
    # 本来はlog_connections, log_disconnections等を有効にすべき
    # database_flags {
    #   name  = "log_connections"
    #   value = "on"
    # }
    # database_flags {
    #   name  = "log_disconnections"
    #   value = "on"
    # }
    # database_flags {
    #   name  = "log_min_duration_statement"
    #   value = "1000"
    # }

    # メンテナンスウィンドウ未設定
    # maintenance_window {
    #   day          = 7  # 日曜日
    #   hour         = 3  # 午前3時
    #   update_track = "stable"
    # }

    # Insights未設定 - クエリパフォーマンス監視不能
    insights_config {
      query_insights_enabled  = false
      query_plans_per_minute  = 0
      query_string_length     = 0
      record_application_tags = false
      record_client_address   = false
    }
  }

  # [FAULT-SQL-03] CMEKによるカスタム暗号化なし（Googleデフォルト暗号化のみ）
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
  password = "password123"  # ハードコード - Secret Managerを使うべき
}
