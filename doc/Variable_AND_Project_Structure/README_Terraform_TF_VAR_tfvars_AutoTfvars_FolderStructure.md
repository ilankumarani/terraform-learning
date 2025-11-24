# Terraform Variable Inputs in Real Time Projects

This README explains how to use:

- **Environment variables** (`TF_VAR_<NAME>`)
- **`terraform.tfvars`**
- **`*.auto.tfvars` files**
- A practical **folder structure**

…and how all of these are used in **real-world Terraform projects** (local + CI/CD).

---

## 1. Ways to pass values into Terraform variables

Terraform can get variable values from several places:

1. **Default values** in the `variable` block.
2. **`terraform.tfvars`** (if present).
3. **`*.auto.tfvars`** files (all loaded automatically).
4. **`TF_VAR_<NAME>` environment variables**.
5. `-var` and `-var-file` on the command line.

> If the same variable is set in multiple places, Terraform uses a **precedence order**, where CLI options override files, and files override defaults.

---

## 2. Environment variables – `TF_VAR_<NAME>`

Environment variables are useful for:

- **Secrets** (passwords, tokens) – easier to inject from CI/CD.
- Quick overrides without editing files.

### 2.1 Naming rule

For a Terraform variable:

```hcl
variable "db_password" {
  type        = string
  description = "Database password"
}
```

The corresponding environment variable name is:

```text
TF_VAR_db_password
```

### 2.2 Example – Windows PowerShell

```powershell
$env:TF_VAR_db_password = "supersecret123"
terraform plan
```

### 2.3 Example – Linux/macOS (for reference)

```bash
export TF_VAR_db_password="supersecret123"
terraform plan
```

Terraform reads `TF_VAR_db_password` and sets `var.db_password`.

> **Tip:** In CI/CD (GitHub Actions, GitLab, Jenkins), store secrets (e.g. `DB_PASSWORD`) in the secret manager, then map them to `TF_VAR_db_password` in your pipeline job.

---

## 3. `terraform.tfvars`

If a file named **`terraform.tfvars`** exists in the working directory, Terraform **automatically loads** it.

Good for:

- **Default / local values** for a given environment.
- Simple projects with a single environment.

### 3.1 Example `terraform.tfvars`

```hcl
env            = "dev"
instance_count = 2

vpc_cidr = "10.0.0.0/16"

availability_zones = ["eu-west-2a", "eu-west-2b"]
```

Now you can just run:

```bash
terraform plan
terraform apply
```

No need for `-var-file` as long as `terraform.tfvars` is in the same folder where you run Terraform.

---

## 4. `*.auto.tfvars` – multiple automatic var files

All files ending with `.auto.tfvars` are **auto-loaded** by Terraform.

Use cases:

- Different config files such as `dev.auto.tfvars`, `stage.auto.tfvars`, `prod.auto.tfvars`.
- You choose **which folder** to run Terraform from to pick the right `.auto.tfvars`.

### 4.1 Example

Files:

```text
dev.auto.tfvars
stage.auto.tfvars
prod.auto.tfvars
```

`dev.auto.tfvars`:

```hcl
env            = "dev"
instance_count = 1
```

`prod.auto.tfvars`:

```hcl
env            = "prod"
instance_count = 3
```

If you run Terraform in a folder that has **only one** of them (e.g. just `dev.auto.tfvars`), it will automatically use that file.

> **Important:** If multiple `.auto.tfvars` files are present together, all of them are loaded. Usually you **separate environments into different folders** to avoid mixing.

---

## 5. CLI options (`-var` / `-var-file`) – for completeness

### 5.1 `-var`

```bash
terraform apply -var="env=prod" -var="instance_count=3"
```

### 5.2 `-var-file`

```bash
terraform apply -var-file="env/dev.tfvars"
terraform apply -var-file="env/prod.tfvars"
```

This is common in CI/CD where you want to select the environment file based on a parameter.

---

## 6. Real-time folder structure examples

Here are practical folder structures that work well in real projects.

---

### 6.1 Pattern 1 – Single project, per-env folders (very common)

```text
infra/
├── modules/
│   ├── vpc/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   └── app/
│       ├── main.tf
│       ├── variables.tf
│       └── outputs.tf
└── envs/
    ├── dev/
    │   ├── main.tf
    │   ├── variables.tf
    │   ├── terraform.tfvars          # or dev.auto.tfvars
    │   └── backend.tf                # remote state config (optional)
    ├── stage/
    │   ├── main.tf
    │   ├── variables.tf
    │   ├── terraform.tfvars
    │   └── backend.tf
    └── prod/
        ├── main.tf
        ├── variables.tf
        ├── terraform.tfvars
        └── backend.tf
```

#### How it works

- `modules/` contains reusable logic.
- Each environment (`dev`, `stage`, `prod`) has its own folder under `envs/`.
- You `cd` into the environment folder you want and run Terraform from there.

#### Example – `envs/dev/main.tf`

```hcl
module "network" {
  source   = "../../modules/vpc"
  env      = var.env
  vpc_cidr = var.vpc_cidr
}

module "app" {
  source           = "../../modules/app"
  env              = var.env
  instance_count   = var.instance_count
  subnet_ids       = module.network.public_subnet_ids
}
```

#### Example – `envs/dev/variables.tf`

```hcl
variable "env" {
  type        = string
  description = "Environment name"
}

variable "vpc_cidr" {
  type = string
}

variable "instance_count" {
  type = number
}
```

#### Example – `envs/dev/terraform.tfvars`

```hcl
env            = "dev"
vpc_cidr       = "10.0.0.0/16"
instance_count = 1
```

#### Example – `envs/prod/terraform.tfvars`

```hcl
env            = "prod"
vpc_cidr       = "10.10.0.0/16"
instance_count = 3
```

##### Usage (real-time)

```bash
cd infra/envs/dev
terraform init
terraform apply

cd ../prod
terraform init
terraform apply
```

Each environment is **isolated** with its own state, its own `terraform.tfvars`, and possibly its own backend config.

---

### 6.2 Pattern 2 – Root module with separate `.tfvars` files (often used in CI/CD)

Folder:

```text
infra/
├── main.tf
├── variables.tf
├── env/
│   ├── dev.tfvars
│   ├── stage.tfvars
│   └── prod.tfvars
└── backend.tf
```

#### Example – `env/dev.tfvars`

```hcl
env            = "dev"
instance_count = 1
```

#### Example – `env/prod.tfvars`

```hcl
env            = "prod"
instance_count = 3
```

##### Local usage

```bash
terraform init
terraform apply -var-file="env/dev.tfvars"
terraform apply -var-file="env/prod.tfvars"
```

##### CI/CD usage (pseudo YAML)

```yaml
steps:
  - name: Terraform Apply (dev)
    run: terraform apply -auto-approve -var-file="env/dev.tfvars"

  - name: Terraform Apply (prod)
    if: github.ref == 'refs/heads/main'
    run: terraform apply -auto-approve -var-file="env/prod.tfvars"
```

---

## 7. Combining `TF_VAR_` with tfvars in real life

A **very common pattern**:

- Use `terraform.tfvars` or `*.tfvars` for **non-secret config**:
  - environment name
  - instance sizes
  - CIDR blocks
  - feature flags
- Use `TF_VAR_<NAME>` for **secrets**:
  - `TF_VAR_db_password`
  - `TF_VAR_api_token`
  - `TF_VAR_github_token`

### Example

`variables.tf`:

```hcl
variable "env" {
  type = string
}

variable "db_password" {
  type      = string
  sensitive = true
}
```

`terraform.tfvars`:

```hcl
env = "dev"
```

Environment:

```powershell
$env:TF_VAR_db_password = "supersecret123"
terraform apply
```

Here:

- `env` comes from `terraform.tfvars`.
- `db_password` comes from `TF_VAR_db_password`.

In CI/CD, `TF_VAR_db_password` is set from a secure secret store.

---

## 8. Recommended real-time practices

1. **Use `terraform.tfvars` or `*.auto.tfvars` per environment**  
   - Keep these files in the environment folder.
   - Do not commit real secrets into Git.

2. **Use `TF_VAR_` for secrets**  
   - Set them in CI/CD pipelines or locally via environment variables.

3. **Use clear folder structure**  
   - `modules/` for reusable bits.
   - `envs/dev`, `envs/stage`, `envs/prod` (or similar) for per-environment stacks.

4. **Keep variable definitions (`variables.tf`) consistent**  
   - Same variable names across environments; only values differ via tfvars or env vars.

---

## 9. Quick cheat sheet

- `TF_VAR_name` → environment variable → sets `var.name`.
- `terraform.tfvars` → loaded automatically in working directory.
- `*.auto.tfvars` → loaded automatically if present.
- `-var-file="file.tfvars"` → manually specify var file (great for CI).
- Real-world:
  - Folder per environment
  - `terraform.tfvars` inside each env folder
  - Secrets from `TF_VAR_` env variables
  - Modules in `modules/` reused across envs.

This combo gives you a clean, production-style Terraform setup that works both **locally** and in **pipelines**.
