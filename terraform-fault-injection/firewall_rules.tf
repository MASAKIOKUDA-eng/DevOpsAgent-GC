################################################################################
# ファイアウォールルール
#
# 注入された障害:
# [FAULT-SEC-01] LBのファイアウォールが全ポート開放 (0.0.0.0/0 全許可)
# [FAULT-SEC-02] Cloud Runへのトラフィックポートが不一致
# [FAULT-SEC-03] Cloud SQLが0.0.0.0/0からのアクセスを許可（パブリック公開）
# [FAULT-SEC-04] アプリケーションからCloud SQLへの通信がファイアウォールで許可されていない
################################################################################

# ロードバランサー用ファイアウォールルール
# [FAULT-SEC-01] 全ポートを0.0.0.0/0に開放 - 本来はHTTP/HTTPSのみにすべき
resource "google_compute_firewall" "allow_lb_inbound" {
  name    = "${var.project_name}-allow-lb-inbound"
  network = google_compute_network.main.name

  # 全トラフィック許可 - 本来はport 80, 443のみ
  allow {
    protocol = "all"
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["lb"]

  # 優先度が低い（数値が大きい）ため、他のルールに上書きされる可能性
  priority = 1000
}

# アプリケーション用ファイアウォールルール
# [FAULT-SEC-02] LBからのポート8080を許可しているが、コンテナはポート3000で起動
resource "google_compute_firewall" "allow_app_from_lb" {
  name    = "${var.project_name}-allow-app-from-lb"
  network = google_compute_network.main.name

  # ポート不一致: LBはポート3000にフォワードするが、ファイアウォールはポート8080のみ許可
  allow {
    protocol = "tcp"
    ports    = ["8080"]
  }

  # Google Cloud LBのヘルスチェック元IPレンジ
  source_ranges = ["130.211.0.0/22", "35.191.0.0/16"]
  target_tags   = ["app"]

  priority = 900
}

# Cloud SQL用ファイアウォールルール
# [FAULT-SEC-03] 0.0.0.0/0からのアクセスを許可 - Cloud SQLがパブリックに公開
resource "google_compute_firewall" "allow_sql_from_anywhere" {
  name    = "${var.project_name}-allow-sql-from-anywhere"
  network = google_compute_network.main.name

  # [FAULT-SEC-03] 全世界からDBポートへのアクセスを許可
  allow {
    protocol = "tcp"
    ports    = ["5432"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["database"]

  priority = 1000
}

# [FAULT-SEC-04] アプリケーションからCloud SQLへの通信ルールが欠落
# 本来は以下が必要:
# resource "google_compute_firewall" "allow_app_to_sql" {
#   name    = "${var.project_name}-allow-app-to-sql"
#   network = google_compute_network.main.name
#
#   allow {
#     protocol = "tcp"
#     ports    = ["5432"]
#   }
#
#   source_tags = ["app"]
#   target_tags = ["database"]
#
#   priority = 800
# }
