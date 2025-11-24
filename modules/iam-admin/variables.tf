variable "admin_group_name" {
  type        = string
  description = "Name of the IAM admin group to create"
}

variable "usernames" {
  type        = list(string)
  description = "List of IAM user names to create and add to the group"
}

variable "attach_administrator_access" {
  type        = bool
  description = "Whether to attach the AWS managed AdministratorAccess policy to the group"
  default     = true
}

variable "create_access_keys" {
  type        = bool
  description = "Whether to create access keys for each IAM user"
  default     = false
}
