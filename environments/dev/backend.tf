terraform {
  cloud {
    organization = "dev_env_ilan"  # change to your org

    workspaces {
      name = "iam-dev"             # change to your dev workspace
    }
  }
}
