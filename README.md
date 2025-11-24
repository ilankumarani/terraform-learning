# Terraform IAM Admin Project

This project demonstrates a **clean, production-style Terraform layout** for managing IAM admin users and groups in AWS,
using **Terraform Cloud** (or alternatively an S3 backend) for remote state.

## Folder Structure

```text
terraform-iam-admin/
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
    │   ├── backend.tf
    │   └── terraform.tfvars
    └── prod/
        ├── main.tf
        ├── providers.tf
        ├── versions.tf
        ├── backend.tf
        └── terraform.tfvars
```

- `modules/iam-admin` – reusable module to create:
  - an IAM admin group
  - attach `AdministratorAccess`
  - multiple IAM users
  - memberships of users into that group
  - optional access keys per user
- `environments/dev` and `environments/prod` – live environments that call the module with different values
  and use their own backends / workspaces.

---

## Module: `modules/iam-admin`

### variables.tf

- `admin_group_name` – name of the IAM group to create
- `usernames` – list of IAM usernames
- `attach_administrator_access` – whether to attach the AWS managed AdministratorAccess policy
- `create_access_keys` – whether to create IAM access keys for each user

### main.tf

Implements:
- IAM group
- optional AdministratorAccess policy attachment
- IAM users (for each username)
- group memberships (for each user)
- optional access keys

### outputs.tf

Exposes:
- created group name
- list of usernames
- map of access key IDs (if created)
- map of secret access keys (if created; marked sensitive)

---

## Environments: dev / prod

Each environment has:

- `versions.tf` – Terraform & provider versions
- `backend.tf` – backend configuration (Terraform Cloud in this example)
- `providers.tf` – AWS provider configuration (region, aliases, etc.)
- `main.tf` – calls the `iam-admin` module with environment-specific values
- `terraform.tfvars` – optional environment-specific variable values

### Example backend.tf (Terraform Cloud)

```hcl
terraform {
  cloud {
    organization = "dev_env_ilan"

    workspaces {
      name = "iam-dev" # or iam-prod for the prod environment
    }
  }
}
```

If you prefer S3, you can replace this `backend.tf` with an `s3` backend block instead.

---

## How to Use

1. Ensure you have AWS credentials set either:
   - in Terraform Cloud workspace environment variables (`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_DEFAULT_REGION`), or
   - locally via environment variables / `aws configure` (if you run plans/applies from your machine).

2. For **dev**:

   ```bash
   cd environments/dev
   terraform login          # if using Terraform Cloud backend
   terraform init
   terraform plan
   terraform apply
   ```

3. For **prod**:

   ```bash
   cd environments/prod
   terraform init
   terraform plan
   terraform apply
   ```

4. To inspect outputs (e.g. access keys, if created):

   ```bash
   terraform output
   terraform output iam_user_access_keys
   terraform output iam_user_secret_keys
   ```

   Remember: secret access keys are only visible at creation time – store them securely in a vault or password manager.

---

## Notes & Best Practices

- Never commit real AWS access keys into Git.
- Use separate workspaces (or S3 keys) per environment to isolate state.
- Use modules to avoid copy-paste between environments.
- Always run `terraform plan` before `terraform apply` – especially for prod.
