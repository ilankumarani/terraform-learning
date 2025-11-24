output "group_name" {
  description = "Name of the created IAM admin group"
  value       = aws_iam_group.admin_group.name
}

output "iam_usernames" {
  description = "List of IAM usernames created"
  value       = var.usernames
}

output "iam_user_access_keys" {
  description = "Access key IDs for users (if created)"
  value       = { for u, k in aws_iam_access_key.admin_user_keys : u => k.id }
  sensitive   = true
}

output "iam_user_secret_keys" {
  description = "Secret access keys for users (if created). STORE THESE SECURELY."
  value       = { for u, k in aws_iam_access_key.admin_user_keys : u => k.secret }
  sensitive   = true
}
