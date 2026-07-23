################################################################################
# VPC & ネットワーク構成
# 
# 注入された障害:
# [FAULT-NET-01] Cloud NATなし - プライベートサブネットからインターネットアクセス不可
# [FAULT-NET-02] 単一リージョンの単一ゾーンのみにサブネット配置 - 可用性の欠如
# [FAULT-NET-03] Cloud Routerが存在しない - Cloud NATやBGP接続が不可能
################################################################################

# VPCネットワーク
resource "google_compute_network" "main" {
  name                    = "${var.project_name}-vpc"
  auto_create_subnetworks = false  # カスタムサブネットモード
  routing_mode            = "REGIONAL"

  # GCPではVPCは暗黙的にグローバル。routing_mode=REGIONALの場合、他リージョンへのルートが伝播されない
}

################################################################################
# サブネット
# [FAULT-NET-02] 単一ゾーンのみ - Cloud RunやGKEで冗長性が確保できない
################################################################################

# パブリック相当サブネット（外部IPを持つリソース用）
resource "google_compute_subnetwork" "public" {
  name          = "${var.project_name}-public-subnet"
  ip_cidr_range = "10.0.1.0/24"
  region        = var.gcp_region
  network       = google_compute_network.main.id

  # Private Google Accessが無効 - Google APIへのプライベートアクセス不可
  private_ip_google_access = false

  # [FAULT-NET-02] secondary_ip_rangeが未設定 - GKE Pod/Service用のIPレンジなし
}

# プライベートサブネット
# [FAULT-NET-01] Cloud NATが存在しないため、外部アクセスが不可能
resource "google_compute_subnetwork" "private" {
  name          = "${var.project_name}-private-subnet"
  ip_cidr_range = "10.0.10.0/24"
  region        = var.gcp_region
  network       = google_compute_network.main.id

  # Private Google Accessが無効
  # [FAULT-NET-01] Cloud NATもないため、Container Registryからイメージ取得不可
  private_ip_google_access = false

  # VPC Flow Logsが無効 - ネットワークトラブルシュート不能
  # log_config {
  #   aggregation_interval = "INTERVAL_5_SEC"
  #   flow_sampling        = 0.5
  #   metadata             = "INCLUDE_ALL_METADATA"
  # }
}

################################################################################
# Cloud Router & Cloud NAT
# [FAULT-NET-03] Cloud Routerが存在しない - Cloud NATの前提条件が欠落
# [FAULT-NET-01] Cloud NATが存在しない - プライベートサブネットから外部通信不可
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

# → プライベートサブネットのリソースがインターネットアクセス不可
# → Container Registry/Artifact RegistryからのイメージPull不可
