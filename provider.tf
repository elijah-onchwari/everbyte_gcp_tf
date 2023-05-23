terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "4.65.2"
    }
  }
  backend "gcs" {
    bucket = "everbyte-tf-state"
    prefix = "dev"
  }
}

provider "google" {
  region  = var.gcp_region
  project = var.gcp_project
  zone    = var.gcp_zone
}