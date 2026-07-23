################################################################################
# Cloud Load Balancing (HTTP(S) ロードバランサー)
#
# 注入された障害:
# [FAULT-LB-01] バックエンドサービスにヘルスチェックが誤ったパスを指定
# [FAULT-LB-02] バックエンドサービスのポートとコンテナポートの不一致
# [FAULT-LB-03] SSL証明書なし・HTTPSリダイレクトなし
# [FAULT-LB-04] Cloud Armorセキュリティポリシー未設定 - DDoS/WAF保護なし
# [FAULT-LB-05] ログが無効化されている
################################################################################

# 外部IPアドレス
resource "google_compute_global_address" "lb" {
  name = "${var.project_name}-lb-ip"
}

# ヘルスチェック
# [FAULT-LB-01] 存在しないヘルスチェックパス
resource "google_compute_health_check" "app" {
  name                = "${var.project_name}-health-check"
  check_interval_sec  = 5
  timeout_sec         = 3
  healthy_threshold   = 2
  unhealthy_threshold = 2

  http_health_check {
    # [FAULT-LB-01] アプリは /health で応答するが、/api/healthcheck を指定
    request_path = "/api/healthcheck"
    # [FAULT-LB-02] コンテナはポート3000で起動するが、ポート8080を指定
    port         = 8080
  }
}

# バックエンドサービス
resource "google_compute_backend_service" "app" {
  name                  = "${var.project_name}-backend-service"
  protocol              = "HTTP"
  port_name             = "http"
  timeout_sec           = 30
  load_balancing_scheme = "EXTERNAL"

  # [FAULT-LB-05] ログが無効
  log_config {
    enable      = false
    sample_rate = 0.0
  }

  # [FAULT-LB-04] Cloud Armorセキュリティポリシー未設定
  # security_policy = google_compute_security_policy.main.id

  backend {
    group           = google_compute_region_network_endpoint_group.cloud_run_neg.id
    balancing_mode  = "UTILIZATION"
    capacity_scaler = 1.0
  }

  health_checks = [google_compute_health_check.app.id]
}

# Serverless NEG (Cloud Run用)
resource "google_compute_region_network_endpoint_group" "cloud_run_neg" {
  name                  = "${var.project_name}-neg"
  network_endpoint_type = "SERVERLESS"
  region                = var.gcp_region

  cloud_run {
    service = google_cloud_run_v2_service.app.name
  }
}

# URL Map
resource "google_compute_url_map" "app" {
  name            = "${var.project_name}-url-map"
  default_service = google_compute_backend_service.app.id

  # パスルールなし - 全トラフィックをデフォルトバックエンドに転送
}

# HTTP プロキシ (HTTPSなし)
# [FAULT-LB-03] SSL証明書がなく、HTTPのみで通信 - 暗号化されていない
resource "google_compute_target_http_proxy" "app" {
  name    = "${var.project_name}-http-proxy"
  url_map = google_compute_url_map.app.id
}

# HTTPSプロキシが存在しない
# 本来は以下が必要:
# resource "google_compute_target_https_proxy" "app" {
#   name             = "${var.project_name}-https-proxy"
#   url_map          = google_compute_url_map.app.id
#   ssl_certificates = [google_compute_managed_ssl_certificate.app.id]
# }
#
# resource "google_compute_managed_ssl_certificate" "app" {
#   name = "${var.project_name}-cert"
#   managed {
#     domains = ["app.example.com"]
#   }
# }

# フォワーディングルール (HTTP のみ)
resource "google_compute_global_forwarding_rule" "http" {
  name                  = "${var.project_name}-http-forwarding-rule"
  ip_address            = google_compute_global_address.lb.address
  port_range            = "80"
  target                = google_compute_target_http_proxy.app.id
  load_balancing_scheme = "EXTERNAL"
}

# HTTPSフォワーディングルールが存在しない
# HTTPからHTTPSへのリダイレクトも設定されていない
