################################################################################
# VPC & ネットワーク構成
# 
# 注入された障害:
# [FAULT-NET-01] NATゲートウェイなし - プライベートサブネットからインターネットアクセス不可
# [FAULT-NET-02] 単一リージョンの単一ゾーンのみ - 可用性の欠如
# [FAULT-NET-03] パブリックサブネットへのルート未設定（Private Google Access無効）
################################################################################

# VPCネットワーク
resource "google_compute_network" "main" {
  name                    = "${var.project_name}-vpc"
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"
}

################################################################################
# パブリックサブネット
# [FAULT-NET-02] 単一リージョンのみ - 冗長性なし
################################################################################
resource "google_compute_subnetwork" "public_a" {
  name          = "${var.project_name}-public-a"
  ip_cidr_range = "10.0.1.0/24"
  region        = var.gcp_region
  network       = google_compute_network.main.id

  # [FAULT-NET-03] Private Google Access無効 - Google APIへのプライベートアクセス不可
  private_ip_google_access = false
}

# [FAULT-NET-02] 2つ目のサブネット（別ゾーン/リージョン）が存在しない
# 本来は以下が必要:
# resource "google_compute_subnetwork" "public_c" {
#   name          = "${var.project_name}-public-c"
#   ip_cidr_range = "10.0.2.0/24"
#   region        = var.gcp_region
#   network       = google_compute_network.main.id
# }

################################################################################
# プライベートサブネット
# [FAULT-NET-01] Cloud NATが存在しないため、Cloud RunやGCEがインターネットアクセス不可
################################################################################
resource "google_compute_subnetwork" "private_a" {
  name          = "${var.project_name}-private-a"
  ip_cidr_range = "10.0.10.0/24"
  region        = var.gcp_region
  network       = google_compute_network.main.id

  # Private Google Access無効 - Artifact RegistryへのアクセスもNG
  private_ip_google_access = false
}

resource "google_compute_subnetwork" "private_c" {
  name          = "${var.project_name}-private-c"
  ip_cidr_range = "10.0.11.0/24"
  region        = var.gcp_region
  network       = google_compute_network.main.id

  private_ip_google_access = false
}

################################################################################
# Cloud Router & Cloud NAT
# [FAULT-NET-01] Cloud Router/NATが存在しない - プライベートサブネットから外部通信不可
################################################################################

# Cloud Routerが存在しない
# 本来は以下が必要:
# resource "google_compute_router" "main" {
#   name    = "${var.project_name}-router"
#   region  = var.gcp_region
#   network = google_compute_network.main.id
#
#   bgp {
#     asn = 64514
#   }
# }

# Cloud NATが存在しない
# 本来は以下が必要:
# resource "google_compute_router_nat" "main" {
#   name                               = "${var.project_name}-nat"
#   router                             = google_compute_router.main.name
#   region                             = var.gcp_region
#   nat_ip_allocate_option             = "AUTO_ONLY"
#   source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
#
#   log_config {
#     enable = true
#     filter = "ERRORS_ONLY"
#   }
# }
