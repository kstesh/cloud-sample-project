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
    "secretmanager.googleapis.com",
  ]
  cloudbuild_sa     = "${data.google_project.current.number}@cloudbuild.gserviceaccount.com"
  cloudbuild_agent  = "service-${data.google_project.current.number}@gcp-sa-cloudbuild.iam.gserviceaccount.com"
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

resource "google_service_account" "cloudbuild_trigger" {
  account_id   = "cloudbuild-deploy"
  display_name = "Cloud Build deploy SA for ${var.service_name}"
}

resource "google_project_iam_member" "trigger_sa_run_admin" {
  project = var.project_id
  role    = "roles/run.admin"
  member  = "serviceAccount:${google_service_account.cloudbuild_trigger.email}"
}

resource "google_project_iam_member" "trigger_sa_act_as" {
  project = var.project_id
  role    = "roles/iam.serviceAccountUser"
  member  = "serviceAccount:${google_service_account.cloudbuild_trigger.email}"
}

resource "google_project_iam_member" "trigger_sa_artifact_writer" {
  project = var.project_id
  role    = "roles/artifactregistry.writer"
  member  = "serviceAccount:${google_service_account.cloudbuild_trigger.email}"
}

resource "google_project_iam_member" "trigger_sa_logs_writer" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.cloudbuild_trigger.email}"
}

resource "google_secret_manager_secret" "github_pat" {
  secret_id = "github-pat-cloudbuild"
  replication {
    auto {}
  }
  depends_on = [google_project_service.apis]
}

resource "google_secret_manager_secret_version" "github_pat" {
  secret      = google_secret_manager_secret.github_pat.id
  secret_data = var.github_pat
}

resource "google_secret_manager_secret_iam_member" "cloudbuild_pat_access" {
  secret_id = google_secret_manager_secret.github_pat.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${local.cloudbuild_agent}"
}

resource "google_cloudbuildv2_connection" "github" {
  location = var.region
  name     = "github-connection"

  github_config {
    app_installation_id = var.github_app_installation_id
    authorizer_credential {
      oauth_token_secret_version = google_secret_manager_secret_version.github_pat.id
    }
  }

  depends_on = [
    google_secret_manager_secret_iam_member.cloudbuild_pat_access,
  ]
}

resource "google_cloudbuildv2_repository" "repo" {
  location          = var.region
  name              = var.github_repo
  parent_connection = google_cloudbuildv2_connection.github.name
  remote_uri        = "https://github.com/${var.github_owner}/${var.github_repo}.git"
}

resource "google_cloudbuild_trigger" "deploy" {
  name            = "${var.service_name}-deploy"
  location        = var.region
  filename        = "cloudbuild.yaml"
  service_account = google_service_account.cloudbuild_trigger.id

  repository_event_config {
    repository = google_cloudbuildv2_repository.repo.id
    push {
      branch = "^main$"
    }
  }

  substitutions = {
    _REGION  = var.region
    _REPO    = var.repository_name
    _SERVICE = var.service_name
  }

  depends_on = [
    google_project_iam_member.trigger_sa_run_admin,
    google_project_iam_member.trigger_sa_act_as,
    google_project_iam_member.trigger_sa_artifact_writer,
    google_project_iam_member.trigger_sa_logs_writer,
  ]
}
}