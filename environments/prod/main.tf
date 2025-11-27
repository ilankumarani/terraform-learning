module "iam_admin" {
  # Git repo + subfolder + branch
  source  = "app.terraform.io/Terraform_Module/iam-admin/aws"
  version = "1.0.0"

  admin_group_name            = "TERRAFORM_ADMIN_GROUP_PROD"
  usernames                   = ["terraform_user_prod1"]
  attach_administrator_access = true
  create_access_keys          = false   # likely no access keys in prod
}
