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

variable "github_pat" {
  type        = string
  description = "GitHub Personal Access Token (classic, scope=repo) used by the Cloud Build v2 connection."
  sensitive   = true
}

variable "github_app_installation_id" {
  type        = string
  description = "Installation ID of the Cloud Build GitHub App on your account. Find it at https://github.com/settings/installations → Configure → URL number."
}