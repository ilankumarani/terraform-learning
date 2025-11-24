# Terraform IAM Admin Project

This repository provides a **clean, production-style Terraform layout** for managing IAM admin users and groups in AWS, using **Terraform Cloud** for remote state and (optionally) remote runs.

The core use case is:

- Create an **admin IAM group** (e.g. `TERRAFORM_ADMIN_GROUP_DEV`, `TERRAFORM_ADMIN_GROUP_PROD`)
- Attach the AWS managed policy **`AdministratorAccess`**
- Create one or more **IAM users** (e.g. `terraform_user_dev1`, `terraform_user_prod1`)
- Add those users to the admin group
- Optionally create **access keys** for those users and output them **once at creation time**


---

## 1. Folder & File Structure (with `backend.tf`)

Recommended structure for this project:

```text
.
├── README.md
├── modules/
│   └── iam-admin/
│       ├── main.tf
│       ├── variables.tf
│       └── outputs.tf
└── environments/
    ├── dev/
    │   ├── main.tf
    │   ├── providers.tf
    │   ├── versions.tf
    │   ├── backend.tf          # Terraform Cloud or other backend config
    │   └── terraform.tfvars    # optional, for env-specific variables
    └── prod/
        ├── main.tf
        ├── providers.tf
        ├── versions.tf
        ├── backend.tf          # Terraform Cloud or other backend config
        └── terraform.tfvars    # optional
```

### What each part is for

- **`modules/iam-admin`**  
  Reusable module that knows how to:
  - Create an IAM group
  - Attach `AdministratorAccess`
  - Create a list of IAM users
  - Add all users to the group
  - (Optionally) expose outputs like created user names

- **`environments/dev`**, **`environments/prod`**  
  "Live" environments that **call the module** with different values.  
  Each environment:
  - Has its own **Terraform Cloud workspace** (or backend)
  - Has its own AWS credentials (e.g. pointing to different AWS accounts)
  - Can be applied independently

- **`versions.tf`**  
  Defines:
  - Terraform version constraints
  - Provider versions

- **`backend.tf`**  
  Defines the **backend / remote state configuration**.  
  Here we use Terraform Cloud, but you could swap this for an S3 backend if you prefer.

- **`providers.tf`**  
  Contains the `provider "aws"` block, e.g. region configuration (and later, aliases if needed).

- **`main.tf` (in environments)**  
  Calls the `iam-admin` module with the environment-specific values (group name, usernames, etc.).


---

## 2. Module: `modules/iam-admin`

### `variables.tf`

```hcl
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
```

### `main.tf`

```hcl
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
```

### `outputs.tf`

```hcl
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
```


---

## 3. Environment: `environments/dev`

### `versions.tf`

```hcl
terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
```

### `backend.tf` (Terraform Cloud backend example)

```hcl
terraform {
  cloud {
    organization = "dev_env_ilan"   # your Terraform Cloud org

    workspaces {
      name = "iam-dev"              # workspace for dev
    }
  }
}
```

> 🔎 Note:  
> Terraform doesn't care that this is in `backend.tf` vs `versions.tf`.  
> Splitting into `versions.tf` and `backend.tf` is just for clarity.

If you prefer an **S3 backend** instead of Terraform Cloud, `backend.tf` could look like this:

```hcl
terraform {
  backend "s3" {
    bucket         = "my-terraform-state-dev"
    key            = "iam/terraform.tfstate"
    region         = "eu-west-1"
    dynamodb_table = "terraform-locks"   # optional, for state locking
    encrypt        = true
  }
}
```

### `providers.tf`

```hcl
provider "aws" {
  region = "eu-west-1"
}
```

### `main.tf`

```hcl
module "iam_admin" {
  source = "../../modules/iam-admin"

  admin_group_name            = "TERRAFORM_ADMIN_GROUP_DEV"
  usernames                   = ["terraform_user_dev1", "terraform_user_dev2"]
  attach_administrator_access = true
  create_access_keys          = true
}
```

### `terraform.tfvars` (optional)

```hcl
# Example if you want to parameterize values instead of hard-coding them
admin_group_name   = "TERRAFORM_ADMIN_GROUP_DEV"
usernames          = ["terraform_user_dev1", "terraform_user_dev2"]
create_access_keys = true
```


---

## 4. Environment: `environments/prod`

Same idea as `dev`, but you probably want:

- Different Terraform Cloud workspace (or different backend config)
- Different group name
- Different IAM users
- Possibly a different AWS account/credentials

### `versions.tf`

```hcl
terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
```

### `backend.tf` (Terraform Cloud)

```hcl
terraform {
  cloud {
    organization = "dev_env_ilan"   # same org or a different one

    workspaces {
      name = "iam-prod"             # workspace for prod
    }
  }
}
```

Or, alternative **S3 backend** for prod:

```hcl
terraform {
  backend "s3" {
    bucket         = "my-terraform-state-prod"
    key            = "iam/terraform.tfstate"
    region         = "eu-west-1"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}
```

### `providers.tf`

```hcl
provider "aws" {
  region = "eu-west-1"
}
```

### `main.tf`

```hcl
module "iam_admin" {
  source = "../../modules/iam-admin"

  admin_group_name            = "TERRAFORM_ADMIN_GROUP_PROD"
  usernames                   = ["terraform_user_prod1"]
  attach_administrator_access = true
  create_access_keys          = false       # maybe you don't want access keys in prod
}
```


---

## 5. Credentials & Remote Runs (Important)

### 5.1. Terraform Cloud runs

When using remote runs in Terraform Cloud (the default when you declare a `cloud {}` block), the plan/apply runs on **Terraform Cloud workers**, not your laptop.

That means:

- Your **local `aws configure` does NOT apply** to those runs.
- You must set AWS credentials in **Terraform Cloud workspace variables**.

For each workspace (`iam-dev`, `iam-prod`):

1. Go to **Workspace → Variables → Environment Variables**.
2. Add:

   - `AWS_ACCESS_KEY_ID`  
   - `AWS_SECRET_ACCESS_KEY` (mark as **Sensitive**)  
   - `AWS_DEFAULT_REGION` (e.g. `eu-west-1`, optional but recommended)

3. Save and queue a new run.

### 5.2. Local runs with remote state (Cloud or S3)

If you prefer to run plans/applies locally but still use a remote backend:

- For **Terraform Cloud** backend:
  ```bash
  terraform login                     # one-time, to authenticate to Terraform Cloud
  ```

- For **S3** backend:
  - Ensure your AWS CLI credentials/environment variables are set.

Then, in either case:

```bash
terraform init
terraform plan
terraform apply
```

You can validate your AWS session with:

```bash
aws sts get-caller-identity
```

If that works, Terraform AWS provider will also work.


---

## 6. Typical Workflow

For **dev environment**:

```bash
cd environments/dev

# First time
terraform login              # if using Terraform Cloud backend
terraform init               # download providers, connect to backend

terraform plan               # see what will be created
terraform apply              # actually create IAM group/users
```

To see outputs (such as access keys if enabled):

```bash
terraform output
terraform output iam_user_access_keys
terraform output iam_user_secret_keys   # will only show in the context that created them
```


For **prod environment**:

```bash
cd environments/prod
terraform init
terraform plan
terraform apply
```

Keep a practice of always running `plan` before `apply`, and consider requiring approvals in Terraform Cloud for production.


---

## 7. Naming & Design Guidelines

- **Modules**: small, focused, reusable.  
  This `iam-admin` module only deals with IAM groups/users, no unrelated resources.

- **Environments**:
  - One folder per environment (`dev`, `qa`, `prod`).
  - One backend config per environment (`backend.tf`).
  - One Terraform Cloud workspace or one S3 key per environment.
  - Ideally, one AWS account per environment (for strong isolation).

- **Variables & Outputs**:
  - Variables describe "inputs" (group name, usernames, flags).
  - Outputs surface useful info (group name, usernames, access key IDs).

- **Credentials**:
  - Never hard-code access keys inside `.tf` files or commit them to Git.
  - Use environment variables or Terraform Cloud sensitive variables.

This layout scales nicely as you add more modules (e.g. `network`, `eks`, `s3`); each module lives under `modules/`, and each environment simply wires modules together with environment-specific values and its own backend configuration in `backend.tf`.
