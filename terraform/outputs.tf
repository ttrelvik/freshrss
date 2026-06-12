output "app_service_name" {
  value       = docker_service.app.name
  description = "The name of the FreshRSS application service"
}

output "db_service_name" {
  value       = docker_service.db.name
  description = "The name of the PostgreSQL database service"
}

output "freshrss_net_id" {
  value       = docker_network.freshrss_net.id
  description = "The ID of the internal overlay network"
}
