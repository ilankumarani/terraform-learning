terraform {
  required_version = ">= 1.6.0" # Terraform version, if this property not provided, then it always takes the latest

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.23.0" # AWS provider plugin version. At this point in time, this is the latest
    }
  }
}
