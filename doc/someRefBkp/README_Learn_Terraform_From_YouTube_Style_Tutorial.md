# Learn Terraform – Practical README (Based on YouTube-Style Tutorial)

> **Goal:** Give you a _single_ README you can follow to learn and practice Terraform:
> - Set up Terraform
> - Write your first configuration
> - Use variables, outputs, and state
> - Create and use modules
> - Separate **dev** and **prod** environments

I’ll also include **placeholder screenshot references** that you can later replace with your own images from VS Code / terminal.

---

## 1. Prerequisites

- Basic understanding of:
  - What AWS is (or another cloud – examples here use **AWS**)
  - Command line (PowerShell / bash)
  - Git & a GitHub repo (optional but recommended)
- Installed:
  - [Terraform CLI](https://developer.hashicorp.com/terraform/downloads)
  - AWS CLI (if using AWS)
  - A code editor (VS Code recommended)

> 📸 **Screenshot idea:**  
> `![Screenshot: Terraform installed version](images/01-terraform-version.png)`  
> → show `terraform -version` in your terminal.

---

## 2. Project Folder Structure

We’ll use a simple but scalable layout:

```text
terraform-demo/
├── environments/
│   ├── dev/
│   │   ├── backend.tf
│   │   ├── main.tf
│   │   ├── providers.tf
│   │   ├── terraform.tfvars
│   │   └── versions.tf
│   └── prod/
│       ├── backend.tf
│       ├── main.tf
│       ├── providers.tf
│       ├── terraform.tfvars
│       └── versions.tf
└── modules/
    └── iam-admin/
        ├── main.tf
        ├── outputs.tf
        └── variables.tf
```

- `modules/` → reusable pieces of infrastructure (here: `iam-admin`)
- `environments/dev` → root module for **dev**
- `environments/prod` → root module for **prod**

> 📸 **Screenshot idea:**  
> `![Screenshot: VS Code project tree](images/02-project-structure.png)`

---

## 3. Terraform Basics

### 3.1 Providers

Terraform itself is generic; a **provider** tells Terraform _which_ platform to manage (AWS, Azure, etc.).

Example `providers.tf` (in `environments/dev`):

```hcl
terraform {
  required_version = ">= 1.4.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket = "my-tf-state-bucket"
    key    = "iam-admin/dev/terraform.tfstate"
    region = "eu-west-2"
  }
}

provider "aws" {
  region = "eu-west-2"
  # profile = "dev"  # if you use AWS CLI profiles
}
```

> 📸 **Screenshot idea:**  
> `![Screenshot: providers.tf in VS Code](images/03-providers.png)`

---

### 3.2 First Resource

A **resource** is something Terraform manages (e.g., IAM user, EC2 instance, S3 bucket).

Example: `modules/iam-admin/main.tf`

```hcl
resource "aws_iam_group" "admin_group" {
  name = var.admin_group_name
}

resource "aws_iam_user" "admins" {
  for_each = toset(var.usernames)

  name = each.value

  tags = {
    ManagedBy = "Terraform"
    Env       = var.env
  }
}

resource "aws_iam_group_membership" "admins_membership" {
  name  = "${var.admin_group_name}-membership"
  users = [for u in aws_iam_user.admins : u.name]
  group = aws_iam_group.admin_group.name
}

resource "aws_iam_group_policy_attachment" "admin_policy_attachment" {
  count      = var.attach_administrator_access ? 1 : 0
  group      = aws_iam_group.admin_group.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}
```

---

## 4. Variables and Outputs

### 4.1 Module variables

`modules/iam-admin/variables.tf`:

```hcl
variable "admin_group_name" {
  type        = string
  description = "Name of the IAM admin group"
}

variable "usernames" {
  type        = list(string)
  description = "List of IAM user names to create"
}

variable "attach_administrator_access" {
  type        = bool
  description = "Attach AdministratorAccess policy to the group"
  default     = true
}

variable "create_access_keys" {
  type        = bool
  description = "Whether to create IAM access keys for each user"
  default     = false
}

variable "env" {
  type        = string
  description = "Environment name (dev/prod/etc.)"
}
```

### 4.2 Module outputs

`modules/iam-admin/outputs.tf`:

```hcl
output "admin_group_name" {
  value       = aws_iam_group.admin_group.name
  description = "Name of the IAM admin group created"
}

output "admin_user_names" {
  value       = [for u in aws_iam_user.admins : u.name]
  description = "List of IAM admin user names"
}
```

> 📸 **Screenshot idea:**  
> `![Screenshot: iam-admin module files](images/04-module-files.png)`

---

## 5. Wiring the Module in Dev

`environments/dev/main.tf`:

```hcl
module "iam_admin" {
  source = "../../modules/iam-admin"

  admin_group_name            = var.admin_group_name
  usernames                   = var.usernames
  attach_administrator_access = var.attach_administrator_access
  create_access_keys          = var.create_access_keys
  env                         = var.env
}
```

`environments/dev/variables.tf`:

```hcl
variable "env" {
  type        = string
  description = "Environment name"
}

variable "admin_group_name" {
  type        = string
  description = "IAM admin group name"
}

variable "usernames" {
  type        = list(string)
  description = "List of admin IAM usernames"
}

variable "attach_administrator_access" {
  type        = bool
  default     = true
}

variable "create_access_keys" {
  type        = bool
  default     = true
}
```

`environments/dev/terraform.tfvars`:

```hcl
env               = "dev"
admin_group_name  = "TERRAFORM_ADMIN_GROUP_DEV"
usernames         = ["terraform_user_dev1", "terraform_user_dev2"]
attach_administrator_access = true
create_access_keys          = true
```

> 📸 **Screenshot idea:**  
> `![Screenshot: dev main.tf and terraform.tfvars side by side](images/05-dev-main-tfvars.png)`

---

## 6. Wiring the Module in Prod

Almost identical, but with **prod values**.

`environments/prod/main.tf`:

```hcl
module "iam_admin" {
  source = "../../modules/iam-admin"

  admin_group_name            = var.admin_group_name
  usernames                   = var.usernames
  attach_administrator_access = var.attach_administrator_access
  create_access_keys          = var.create_access_keys
  env                         = var.env
}
```

`environments/prod/terraform.tfvars`:

```hcl
env               = "prod"
admin_group_name  = "TERRAFORM_ADMIN_GROUP_PROD"
usernames         = ["terraform_user_prod1", "terraform_user_prod2"]
attach_administrator_access = true
create_access_keys          = false
```

> 📸 **Screenshot idea:**  
> `![Screenshot: prod terraform.tfvars](images/06-prod-tfvars.png)`

---

## 7. Running Terraform (Dev vs Prod)

### 7.1 Dev environment

From your terminal:

```bash
cd environments/dev

terraform init
terraform plan
terraform apply
```

- `init` → downloads providers, sets up backend
- `plan` → shows what will be created/changed
- `apply` → actually creates IAM group/users in AWS

> 📸 **Screenshot idea:**  
> `![Screenshot: terraform init in dev](images/07-dev-init.png)`  
> `![Screenshot: terraform plan in dev](images/08-dev-plan.png)`

---

### 7.2 Prod environment

```bash
cd environments/prod

terraform init
terraform plan
terraform apply
```

This will:

- Use separate **state** (if you configure different backend key/bucket)
- Use **prod** values from `terraform.tfvars`

> 📸 **Screenshot idea:**  
> `![Screenshot: terraform plan in prod](images/09-prod-plan.png)`

---

## 8. Understanding State (High Level)

Terraform keeps a **state file** describing what it created.

- Local backend: `terraform.tfstate` file in your folder
- Remote backend (S3, HCP Terraform, etc.): state stored remotely

You **should not manually edit** state.

Key points:

- State maps Terraform resources → real cloud resources
- Deleting state without deleting resources can cause **drift**
- Backends like S3 + DynamoDB help with **locking** and team work

> 📸 **Screenshot idea:**  
> `![Screenshot: S3 bucket with terraform state file](images/10-s3-state.png)`

---

## 9. Common Errors & Fixes

### 9.1 Unreadable module directory

Error:

```text
Error: Unreadable module directory
Unable to evaluate directory symlink: lstat ../../modules: no such file or directory
```

Reasons:

- Terraform (especially with **remote execution**) can’t see the `modules` folder.
- The path in `source = "../../modules/iam-admin"` is wrong **from the point of view of where Terraform runs**.

Fixes:

- Use `source = "./modules/iam-admin"` if the `modules` folder is **inside** your env folder.
- Ensure that if you use HCP Terraform / remote backend, all modules are included in the root directory that’s uploaded.

---

## 10. Suggested Learning Path Using This README

1. **Follow step-by-step for dev**
   - Create the folder structure
   - Implement the `iam-admin` module
   - Wire it in `environments/dev`
   - Run `init/plan/apply`
2. **Clone for prod**
   - Duplicate the dev folder into prod
   - Change `env`, `admin_group_name`, and `usernames`
3. **Experiment**
   - Add more variables (e.g., `tags`, `path` for users)
   - Add a second module (e.g., S3 bucket module)
4. **Refactor**
   - Use workspaces or better backend separation once you’re comfortable.

---

## 11. Cheat Sheet

- `terraform init` → prepare the working directory
- `terraform plan` → preview changes
- `terraform apply` → apply changes
- `terraform destroy` → delete resources
- `var.<name>` → use variable
- `module.<name>.<output>` → use module output
- `TF_VAR_<name>` → environment variable input for `var.name`

---

You can now treat this README as your **mini Terraform course**:

- Fill in the screenshot placeholders with actual images from your YouTube learning or your own terminal/editor.
- Commit this README into your repo so you always have a reference of how your Terraform layouts and modules are structured.
