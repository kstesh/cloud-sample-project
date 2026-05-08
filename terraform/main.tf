terraform {
  required_version = ">= 1.5"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

data "google_project" "current" {}

locals {
  apis = [
    "run.googleapis.com",
    "cloudbuild.googleapis.com",
    "artifactregistry.googleapis.com",
  ]
  cloudbuild_sa = "${data.google_project.current.number}@cloudbuild.gserviceaccount.com"
}

resource "google_project_service" "apis" {
  for_each           = toset(local.apis)
  service            = each.value
  disable_on_destroy = false
}

resource "google_artifact_registry_repository" "webapi" {
  location      = var.region
  repository_id = var.repository_name
  format        = "DOCKER"
  description   = "Docker images for ${var.service_name}"
  depends_on    = [google_project_service.apis]
}

resource "google_project_iam_member" "cloudbuild_run_admin" {
  project = var.project_id
  role    = "roles/run.admin"
  member  = "serviceAccount:${local.cloudbuild_sa}"
}

resource "google_project_iam_member" "cloudbuild_sa_user" {
  project = var.project_id
  role    = "roles/iam.serviceAccountUser"
  member  = "serviceAccount:${local.cloudbuild_sa}"
}

resource "google_cloudbuild_trigger" "deploy" {
  name        = "${var.service_name}-deploy"
  description = "Build and deploy to Cloud Run service ${var.service_name} on push to \"^main$\""
  filename    = "cloudbuild.yaml"

  github {
    owner = var.github_owner
    name  = var.github_repo
    push {
      branch = "^main$"
    }
  }

  substitutions = {
    _REGION  = var.region
    _REPO    = var.repository_name
    _SERVICE = var.service_name
  }

  depends_on = [google_project_service.apis]
}