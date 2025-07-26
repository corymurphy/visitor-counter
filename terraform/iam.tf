resource "google_service_account" "deployment" {
  account_id   = "visitor-counter-deployment"
  display_name = "Visitor Counter Deployment Service Account"
  description  = "Service account for deploying visitor counter application"
}

resource "google_project_iam_binding" "deployment_roles" {
  for_each = toset([
    "roles/compute.viewer",
    "roles/compute.instanceAdmin.v1",
    "roles/iam.serviceAccountUser",
    "roles/compute.osLogin",
    "roles/compute.osAdminLogin"
  ])

  project = var.project_id
  role    = each.value
  members = [
    "serviceAccount:${google_service_account.deployment.email}"
  ]
}

resource "google_iam_workload_identity_pool" "github_actions" {
  workload_identity_pool_id = "github-actions-pool"
  display_name              = "GitHub Actions Pool"
  description               = "Identity pool for GitHub Actions"
}

resource "google_iam_workload_identity_pool_provider" "github_actions" {
  workload_identity_pool_id          = google_iam_workload_identity_pool.github_actions.workload_identity_pool_id
  workload_identity_pool_provider_id = "github-actions-provider"

  # attribute_condition = "assertion.repository == '${var.github_repository}' && assertion.owner == '${var.github_owner}'"
  attribute_condition = "assertion.repository_owner == '${var.github_owner}'"

  attribute_mapping = {
    "google.subject"       = "assertion.sub"
    "attribute.actor"      = "assertion.actor"
    "attribute.repository" = "assertion.repository"
    "attribute.repository_owner" = "assertion.repository_owner"
  }

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

resource "google_service_account_iam_binding" "github_actions_binding" {
  service_account_id = google_service_account.deployment.name
  for_each = toset([
    "roles/iam.workloadIdentityUser",
    "roles/iam.serviceAccountUser",
    "roles/iam.serviceAccountTokenCreator"
  ])

  role    = each.value
  members = [
    "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github_actions.name}/attribute.repository/${var.github_owner}/${var.github_repository}",
  ]
}

output "workload_identity_pool_id" {
  value = google_iam_workload_identity_pool.github_actions.name
}

output "service_account_email" {
  value = google_service_account.deployment.email
}
