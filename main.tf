/* 
   This Terraform deployment creates the following resources:
   VPC, Subnet, Google Kubernetes Engine, Jump Host cloud router, Cloud Nat
   */

#-------------------------Create VPC Resources---------------------

resource "google_compute_network" "vpc" {
  name                    = "${var.environment}-vpc"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "subnet" {
  name          = "${var.environment}-us-subnet"
  region        = var.gcp_region
  network       = google_compute_network.vpc.name
  ip_cidr_range = var.subnet_cidr
}


#-------------------------Create GKE cluster Resources---------------------

resource "google_container_cluster" "master" {
  name                     = "${var.environment}-cluster"
  location                 = var.gcp_zone
  network                  = google_compute_network.vpc.name
  subnetwork               = google_compute_subnetwork.subnet.name
  remove_default_node_pool = true
  initial_node_count       = 1

  private_cluster_config {
    enable_private_endpoint = true
    enable_private_nodes    = true
    master_ipv4_cidr_block  = "10.13.0.0/28"
  }
  ip_allocation_policy {
    cluster_ipv4_cidr_block  = "10.11.0.0/21"
    services_ipv4_cidr_block = "10.12.0.0/21"
  }
  master_authorized_networks_config {
    cidr_blocks {
      cidr_block   = "${google_compute_address.internal_ip_addr.address}/32"
      display_name = "Jump host internal IP"
    }

  }
}


resource "google_container_node_pool" "workers" {
  name       = google_container_cluster.master.name
  location   = var.gcp_zone
  cluster    = google_container_cluster.master.name
  node_count = 3

  node_config {
    oauth_scopes = [
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
    ]

    labels = {
      env = var.environment
    }

    machine_type = "n1-standard-1"
    preemptible  = true
    disk_size_gb = 10

    metadata = {
      disable-legacy-endpoints = "true"
    }
  }
}

#-------------------------Create compute instance ---------------------
# resource "google_service_account" "default" {
#   account_id   = "acess-api"
#   display_name = "Service Account"
# }

resource "google_compute_instance" "evebyte" {
  project                   = var.gcp_project
  zone                      = var.gcp_zone
  name                      = "${var.environment}-jump-host"
  machine_type              = "e2-medium"
  allow_stopping_for_update = true
  metadata = {
    startup-script-url = "gs://everbyte-public/start-up.sh"
  }
  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
    }
  }
  network_interface {
    network    = google_compute_network.vpc.name
    subnetwork = google_compute_subnetwork.subnet.name
    network_ip = google_compute_address.internal_ip_addr.address
  }
  service_account {
    # Google recommends custom service accounts that have cloud-platform scope and permissions granted via IAM Roles.
    email  = "terraform@geczra-380202.iam.gserviceaccount.com"
    scopes = ["cloud-platform"]
  }

}

resource "google_compute_address" "internal_ip_addr" {
  project      = var.gcp_project
  address_type = "INTERNAL"
  region       = var.gcp_region
  subnetwork   = google_compute_subnetwork.subnet.name
  name         = "${var.environment}-internal-ip"
  address      = "10.190.0.2"
  description  = "An internal IP address for jump host"
}

#-------------------------Create Firewall for ssh --------------------

resource "google_compute_firewall" "allow_ssh" {
  project = var.gcp_project
  name    = "allow-ssh-from-anywhere"
  network = google_compute_network.vpc.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
  source_ranges = ["35.235.240.0/20"]
}

resource "google_compute_firewall" "allo_iap" {
  project = var.gcp_project
  name    = "allow-ingress-from-iap"
  network = google_compute_network.vpc.name

  allow {
    protocol = "tcp"
    ports    = ["30000-32767"]
  }
  source_ranges = ["35.235.240.0/20"]
}

#-------------------------Assign Iam Role to Service account --------------------


resource "google_project_iam_member" "project" {
  project = var.gcp_project
  role    = "roles/iap.tunnelResourceAccessor"
  member  = "serviceAccount:terraform-iap-ssh@geczra-380202.iam.gserviceaccount.com"
}


#------------------------- create cloud router for nat gateway --------------------


resource "google_compute_router" "router" {
  project = var.gcp_project
  name    = "${var.environment}-nat-router"
  network = google_compute_network.vpc.name
  region  = var.gcp_region
}


module "cloud-nat" {
  source     = "terraform-google-modules/cloud-nat/google"
  version    = "~> 1.2"
  project_id = var.gcp_project
  region     = var.gcp_region
  router     = google_compute_router.router.name
  name       = "${var.environment}-nat-config"
}