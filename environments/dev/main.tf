module "iam_admin" {
  # Git repo + subfolder + branch
  source = "git::https://github.com/ilankumarani/terraform-aws-modules.git//iam-admin?ref=main"

  admin_group_name            = "TERRAFORM_ADMIN_GROUP_DEV"
  usernames                   = ["terraform_user_dev1", "terraform_user_dev2"]
  attach_administrator_access = true
  create_access_keys          = true
}
