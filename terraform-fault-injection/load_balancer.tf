################################################################################
# Cloud Load Balancing (HTTP(S) ロードバランサー)
#
# 注入された障害:
# [FAULT-LB-01] Serverless NEGを単一リージョンのみ指定 - 冗長性なし
# [FAULT-LB-02] ヘルスチェックのパスが存在しないエンドポイント
# [FAULT-LB-03] バックエンドサービスのポートとコンテナポートの不一致
# [FAULT-LB-04] アクセスログが無効化されている
################################################################################

# 外部IPアドレス
resource "google_compute_global_address" "lb" {
  name = "${var.project_name}-lb-ip"
}

# ヘルスチェック
# [FAULT-LB-02] 存在しないヘルスチェックパス
# [FAULT-LB-03] コンテナはポート3000で起動するが、ポート8080を指定
resource "google_compute_health_check" "app" {
  name                = "${var.project_name}-health-check"
  check_interval_sec  = 5
  timeout_sec         = 3
  healthy_threshold   = 2
  unhealthy_threshold = 2

  http_health_check {
    # [FAULT-LB-02] アプリは /health で応答するが、/api/healthcheck を指定
    request_path = "/api/healthcheck"
    # [FAULT-LB-03] コンテナはポート3000で起動するが、ポート8080を指定
    port = 8080
  }
}

# Serverless NEG (Cloud Run用)
# [FAULT-LB-01] 単一リージョンのみ
resource "google_compute_region_network_endpoint_group" "cloud_run_neg" {
  name                  = "${var.project_name}-neg"
  network_endpoint_type = "SERVERLESS"
  region                = var.gcp_region

  cloud_run {
    service = google_cloud_run_v2_service.app.name
  }
}

# バックエンドサービス
resource "google_compute_backend_service" "app" {
  name                  = "${var.project_name}-backend-service"
  protocol              = "HTTP"
  port_name             = "http"
  timeout_sec           = 30
  load_balancing_scheme = "EXTERNAL"

  # [FAULT-LB-04] アクセスログ無効 - 監査・トラブルシュート不能
  log_config {
    enable      = false
    sample_rate = 0.0
  }

  backend {
    group = google_compute_region_network_endpoint_group.cloud_run_neg.id
  }

  health_checks = [google_compute_health_check.app.id]
}

# URL Map
resource "google_compute_url_map" "app" {
  name            = "${var.project_name}-url-map"
  default_service = google_compute_backend_service.app.id
}

# HTTPプロキシ (HTTPSなし - 本来はHTTPSを使用すべき)
resource "google_compute_target_http_proxy" "app" {
  name    = "${var.project_name}-http-proxy"
  url_map = google_compute_url_map.app.id
}

# フォワーディングルール (HTTP のみ)
# HTTPS へのリダイレクトなし - 本来はHTTPSを使用すべき
resource "google_compute_global_forwarding_rule" "http" {
  name                  = "${var.project_name}-http-forwarding-rule"
  ip_address            = google_compute_global_address.lb.address
  port_range            = "80"
  target                = google_compute_target_http_proxy.app.id
  load_balancing_scheme = "EXTERNAL"
}
