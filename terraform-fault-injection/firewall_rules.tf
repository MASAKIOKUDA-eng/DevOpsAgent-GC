################################################################################
# ファイアウォールルール
#
# 注入された障害:
# [FAULT-SEC-01] LBのファイアウォールが全ポート開放 (0.0.0.0/0 全許可)
# [FAULT-SEC-02] Cloud Runへのトラフィックポートが不一致（8080許可だがコンテナは3000）
# [FAULT-SEC-03] RDS(Cloud SQL)のファイアウォールが0.0.0.0/0からのアクセスを許可
# [FAULT-SEC-04] アプリケーションからCloud SQLへの通信がファイアウォールで許可されていない
################################################################################

# ALB相当 - ロードバランサー用ファイアウォールルール
# [FAULT-SEC-01] 全ポートを0.0.0.0/0に開放 - 本来はHTTP/HTTPSのみにすべき
resource "google_compute_firewall" "alb" {
  name    = "${var.project_name}-alb-fw"
  network = google_compute_network.main.name

  # 全トラフィック許可 - 本来はport 80, 443のみ
  allow {
    protocol = "all"
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["lb"]
}

# ECS相当 - アプリケーション用ファイアウォールルール
# [FAULT-SEC-02] LBからのポート8080を許可しているが、コンテナはポート3000で起動
resource "google_compute_firewall" "ecs" {
  name    = "${var.project_name}-ecs-fw"
  network = google_compute_network.main.name

  # ポート不一致: LBはポート3000にフォワードするが、FWはポート8080のみ許可
  allow {
    protocol = "tcp"
    ports    = ["8080"]
  }

  # Google Cloud LBのヘルスチェック元IPレンジ
  source_ranges = ["130.211.0.0/22", "35.191.0.0/16"]
  target_tags   = ["app"]
}

# RDS相当 - Cloud SQL用ファイアウォールルール
# [FAULT-SEC-03] 0.0.0.0/0からのアクセスを許可 - Cloud SQLがパブリックに公開
# [FAULT-SEC-04] ECSのタグからのアクセスではなくCIDRで制限 - しかも範囲が間違い
resource "google_compute_firewall" "rds" {
  name    = "${var.project_name}-rds-fw"
  network = google_compute_network.main.name

  # [FAULT-SEC-03] 全世界からDBポートへのアクセスを許可
  allow {
    protocol = "tcp"
    ports    = ["5432"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["database"]
}
