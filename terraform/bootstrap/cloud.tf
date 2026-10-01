# The HCP Terraform organization comes from TF_CLOUD_ORGANIZATION (.env), so anyone can use their own
terraform {
  cloud {
    workspaces {
      name = "runnerbootstrap"
    }
  }
}
