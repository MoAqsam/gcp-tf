terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "4.49.0"
    }
  }
}

resource "google_project_iam_binding" "api_service" {
  project = var.project_id
  role    = "roles/editor"
  members = [
    "serviceAccount:${google_service_account.rick_rolled.email}"
  ]
}

resource "google_project_service" "api_services" {
  project = var.project_id
  for_each = toset(
    [
      "iam.googleapis.com",
      "compute.googleapis.com",
      "cloudresourcemanager.googleapis.com",
    ]
  )
  service                    = each.key
  disable_on_destroy         = false
  disable_dependent_services = true
}

resource "google_service_account" "rick_rolled" {
  account_id   = "rick_rolled"
  project = var.project_id
  display_name = "rick_rolled"
  description  = "Authorisation to use with rick_rolled and Compute Engine VM"
  depends_on   = [google_project_service.api_services]
}

resource "google_project_iam_member" "rick_rolled-service-account-iam" {
  for_each = toset([
    "roles/iam.serviceAccountUser",
    "roles/run.admin",
    "roles/logging.admin",
    "roles/bigquery.jobUser",
    "roles/bigquery.dataEditor"
  ])
  role       = each.value
  project    = var.project_id
  member     = "serviceAccount:${google_service_account.rick_rolled.email}"
  depends_on = [google_project_service.api_services]
}

resource "google_compute_instance" "rick_rolled-instance" {
  name                    = "${var.project_id}-rick_rolled-instance"
  project = var.project_id
  zone                    = var.zone
  machine_type            = "e2-micro"
  metadata_startup_script = file("./sh_scripts/rick_rolled.sh")

  boot_disk {
    initialize_params {
      image = "debian-10-buster-v20230206"
    }
  }

  network_interface {
    network    = "default"
    subnetwork_project = var.project_id
    subnetwork = "default"
    access_config {
      network_tier = "PREMIUM"
    }
  }

  service_account {
    scopes = [
      "cloud-platform",
    ]
    email = google_service_account.rick_rolled.email
  }

  depends_on = [google_project_service.api_services]
}
