################################################################################
# 出力定義
################################################################################

output "vpc_id" {
  description = "VPC Network ID"
  value       = google_compute_network.main.id
}

output "lb_ip_address" {
  description = "Load Balancer IP address"
  value       = google_compute_global_address.lb.address
}

output "lb_forwarding_rule" {
  description = "Load Balancer forwarding rule"
  value       = google_compute_global_forwarding_rule.http.id
}

output "cloud_run_service_name" {
  description = "Cloud Run service name"
  value       = google_cloud_run_v2_service.app.name
}

output "cloud_run_service_url" {
  description = "Cloud Run service URL"
  value       = google_cloud_run_v2_service.app.uri
}

output "cloud_sql_instance_name" {
  description = "Cloud SQL instance name"
  value       = google_sql_database_instance.main.name
}

output "cloud_sql_public_ip" {
  description = "Cloud SQL public IP (should not exist in production)"
  value       = google_sql_database_instance.main.public_ip_address
}

output "cloud_sql_connection_name" {
  description = "Cloud SQL connection name"
  value       = google_sql_database_instance.main.connection_name
}
