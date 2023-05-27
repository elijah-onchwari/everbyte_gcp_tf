#-------------------------Terraform Variables---------------------
variable "environment" {
  description = "Environment name for deployment"
  type        = string
}

variable "gcp_project" {
  description = "GCP project"
  type        = string
}

variable "gcp_region" {
  description = "GCP region resources are deployed to"
  type        = string
}

variable "gcp_zone" {
  description = "GCP zone resources are deployed to"
  type        = string
}

variable "subnet_cidr" {
  description = "Subnet cidr block"
  type        = string
}
