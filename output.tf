############Output############################################
output "kubernetes_cluster_host" {
  value       = google_container_cluster.master.endpoint
  description = "GKE Cluster Host"
}

output "kubernetes_cluster_name" {
  value       = google_container_cluster.master.name
  description = "GKE Cluster Name"
}