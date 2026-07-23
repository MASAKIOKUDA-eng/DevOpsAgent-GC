################################################################################
# GCP DevOps Agent 障害検知テスト - メイン設定
# 注意: このコードは意図的に障害を含んでいます
################################################################################

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project = var.gcp_project_id
  region  = var.gcp_region

  default_labels = {
    project     = "devops-agent-fault-test"
    environment = "test"
    managed_by  = "terraform"
  }
}
