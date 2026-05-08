variable "project_id" {
  type        = string
  description = "GCP project ID."
}

variable "region" {
  type    = string
  default = "europe-west1"
}

variable "service_name" {
  type    = string
  default = "sample-webapi"
}

variable "repository_name" {
  type    = string
  default = "webapi"
}

variable "github_owner" {
  type        = string
  description = "GitHub username or org that owns the repo."
}

variable "github_repo" {
  type        = string
  description = "GitHub repository name (without owner)."
}