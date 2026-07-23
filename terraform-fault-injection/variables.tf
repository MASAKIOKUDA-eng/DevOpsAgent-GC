################################################################################
# 変数定義
################################################################################

variable "gcp_project_id" {
  description = "GCP project ID"
  type        = string
  default     = "my-fault-test-project"
}

variable "gcp_region" {
  description = "GCP region"
  type        = string
  default     = "asia-northeast1"
}

variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
  default     = "fault-test"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC subnet"
  type        = string
  default     = "10.0.0.0/16"
}
