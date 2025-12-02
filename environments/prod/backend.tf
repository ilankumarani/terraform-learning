terraform {
  cloud {
    organization = "prod_env_ilan"  # change to your org

    workspaces {
      name = "iam-prod"            # change to your prod workspace
    }
  }
}
