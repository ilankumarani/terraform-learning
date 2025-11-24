resource "aws_iam_group" "admin_group" {
  name = var.admin_group_name
}

resource "aws_iam_group_policy_attachment" "admin_group_admin_policy" {
  count      = var.attach_administrator_access ? 1 : 0
  group      = aws_iam_group.admin_group.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

resource "aws_iam_user" "admin_users" {
  for_each = toset(var.usernames)

  name          = each.key
  force_destroy = true
}

resource "aws_iam_user_group_membership" "admin_memberships" {
  for_each = aws_iam_user.admin_users

  user   = each.value.name
  groups = [aws_iam_group.admin_group.name]
}

# Optional: access keys for each user
resource "aws_iam_access_key" "admin_user_keys" {
  for_each = var.create_access_keys ? aws_iam_user.admin_users : {}

  user = each.value.name
}
