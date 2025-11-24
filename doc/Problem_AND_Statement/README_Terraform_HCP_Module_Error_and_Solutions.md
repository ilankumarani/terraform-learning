# Terraform Project Layout, Module Error, and How to Fix It

This document explains:

- The **problem** you are seeing with the `Unreadable module directory` error  
- **Why** it happens (what Terraform is doing under the hood)  
- **From which folder** you should run `terraform init/plan/apply`  
- The **best solution** and **alternative ways** to fix it in real projects  

---

## 1. Current Project Structure

You have a structure like this:

```text
create-terraform-iam-admin/
├── doc/
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
│       ├── terraform.auto.tfvars
│       ├── terraform.tfvars
│       └── versions.tf
└── modules/
    └── iam-admin/
        ├── main.tf
        ├── outputs.tf
        └── variables.tf
```

And in `environments/dev/main.tf`:

```hcl
module "iam_admin" {
  source = "../../modules/iam-admin"

  admin_group_name           = "TERRAFORM_ADMIN_GROUP_DEV"
  usernames                  = ["terraform_user_dev1", "terraform_user_dev2"]
  attach_administrator_access = true
  create_access_keys          = true
}
```

You run Terraform from:

```text
create-terraform-iam-admin/environments/dev
```

---

## 2. Error Message

When you run `terraform init` or `terraform plan` from `environments/dev`, you see:

```text
Initializing modules...
- iam_admin in

Error: Unreadable module directory

Unable to evaluate directory symlink: lstat ../../modules: no such file or directory
The directory could not be read for module "iam_admin" at main.tf:1.
```

And it also shows:

```text
Initializing HCP Terraform...
Operation failed: failed running terraform init (exit 1)
```

---

## 3. What Terraform *thinks* is happening

From your local machine:

- The folder `../../modules/iam-admin` **does exist** relative to `environments/dev`.
- If Terraform ran **entirely locally**, this path would be fine.

However, you are using **HCP Terraform (remote backend with remote execution)**.  
That changes how Terraform sees your files.

### 3.1 What HCP Terraform does

When you use the `cloud {}` or HCP Terraform backend:

1. Terraform takes the **current working directory** (here: `environments/dev`).
2. It **zips only that folder** and uploads it to HCP Terraform.
3. HCP Terraform unzips it on its remote workers.
4. It runs `terraform init/plan/apply` **remotely**, _inside that folder only_.

Files that are **outside** `environments/dev` (like `../../modules`) are **not uploaded**.

So inside the HCP Terraform run, the path `../../modules/iam-admin` really **does not exist**.  
That is why you see:

```text
lstat ../../modules: no such file or directory
```

Locally it exists ✅  
Remotely (in HCP) it does not ❌

That’s the core problem.

---

## 4. From which folder should I run `terraform init`?

Your intention is correct:

- To work with **dev**:  
  ```powershell
  cd environments/dev
  terraform init
  terraform plan
  terraform apply
  ```

- To work with **prod**:  
  ```powershell
  cd environments/prod
  terraform init
  terraform plan
  terraform apply
  ```

You should **not** run Terraform in `modules/iam-admin`.  
The `modules` folder holds only *reusable code*; it is pulled in by `main.tf` using the `module` block.

So the folder choice is correct. The problem is just **where the module code lives** relative to what HCP uploads.

---

## 5. Problem Statement (short summary)

> I am using HCP Terraform with a project layout where my root Terraform configs live in `environments/dev` and `environments/prod`, and my reusable modules live in a top-level `modules/` folder.  
> When I reference a module with `source = "../../modules/iam-admin"` and run `terraform init` from `environments/dev`, I get an `Unreadable module directory` error because HCP Terraform cannot see the `../../modules` directory during remote execution.

---

## 6. Best Solution (recommended pattern)

The cleanest solution **when using HCP Terraform remote execution** is:

> **Keep modules inside the same directory tree that gets uploaded.**

In practice, that means either:

- Put a **shared `modules` folder under `environments/`**, or  
- Use a separate **“root” folder that includes both env configs and modules**, and point HCP Terraform to that root.

A simple and effective change is:

### 6.1 Move `modules` under `environments`

Example:

```text
create-terraform-iam-admin/
├── environments/
│   ├── dev/
│   │   ├── backend.tf
│   │   ├── main.tf
│   │   ├── providers.tf
│   │   ├── terraform.tfvars
│   │   ├── versions.tf
│   │   └── modules/
│   │       └── iam-admin/
│   │           ├── main.tf
│   │           ├── outputs.tf
│   │           └── variables.tf
│   └── prod/
│       ├── backend.tf
│       ├── main.tf
│       ├── providers.tf
│       ├── terraform.auto.tfvars
│       ├── terraform.tfvars
│       ├── versions.tf
│       └── modules/
│           └── iam-admin/
│               ├── main.tf
│               ├── outputs.tf
│               └── variables.tf
└── doc/
```

And in `dev/main.tf`:

```hcl
module "iam_admin" {
  source = "./modules/iam-admin"

  admin_group_name            = "TERRAFORM_ADMIN_GROUP_DEV"
  usernames                   = ["terraform_user_dev1", "terraform_user_dev2"]
  attach_administrator_access = true
  create_access_keys          = true
}
```

In `prod/main.tf`:

```hcl
module "iam_admin" {
  source = "./modules/iam-admin"

  admin_group_name            = "TERRAFORM_ADMIN_GROUP_PROD"
  usernames                   = ["terraform_user_prod1", "terraform_user_prod2"]
  attach_administrator_access = true
  create_access_keys          = true
}
```

Now, when HCP Terraform zips `environments/dev`, it includes `./modules/iam-admin` as well, so the module path is valid.

> This is the **safest & most predictable** solution when you want each environment folder to be an independent Terraform workspace in HCP.

---

## 7. Alternative Ways to Fix the Problem

There are other approaches depending on how you want to work.

### 7.1 Option A – Use local / non-remote execution (no HCP remote runs)

If you **don’t** need HCP Terraform to run your plans remotely, you can:

1. Use a **local backend** (or S3/DynamoDB) instead of `cloud {}` / HCP.
2. Run Terraform **entirely on your machine**.

In that case, this layout:

```hcl
source = "../../modules/iam-admin"
```

works fine, because local Terraform can access the whole repository.

This looks like:

```hcl
terraform {
  backend "s3" {
    bucket = "my-terraform-state-bucket"
    key    = "iam-admin/dev/terraform.tfstate"
    region = "eu-west-2"
  }
}
```

or even:

```hcl
terraform {
  backend "local" {}
}
```

Then:

```powershell
cd environments/dev
terraform init
terraform apply
```

works with `../../modules/iam-admin` without complaints.

---

### 7.2 Option B – Use a root repo path for HCP Terraform

Another strategy is:

1. Make a **single root folder** that includes **both** envs and modules.
2. Configure your HCP Terraform workspace to use that root folder instead of `environments/dev`.

Example root:

```text
create-terraform-iam-admin/
├── environments/
│   ├── dev/
│   └── prod/
└── modules/
    └── iam-admin/
```

Then HCP Terraform should be configured to treat `create-terraform-iam-admin` as the root directory so that `../../modules/iam-admin` is still inside the uploaded tree.

This depends on **how you connected your repo to HCP** (workspace settings, working directory path). It’s slightly more advanced and workspace-specific.

---

### 7.3 Option C – Move modules into a separate Git repo (remote module source)

For bigger organisations:

- Put modules into **their own Git repo**, e.g. `git@github.com:company/terraform-modules.git`
- Reference the module with a **remote Git source**:

```hcl
module "iam_admin" {
  source = "git::ssh://git@github.com/company/terraform-modules.git//iam-admin?ref=v1.0.0"

  # input variables...
}
```

Now HCP Terraform doesn’t need the `modules` folder locally; it fetches it directly from Git.

This is more advanced but very scalable for shared modules.

---

## 8. Which approach is best?

**For your current setup and learning stage, the best choice is:**

> Keep using HCP Terraform (if you like it) and move the `iam-admin` module under each environment (or under a shared folder that is still inside the working directory HCP uploads), and use `source = "./modules/iam-admin"`.

Why this is good for you:

- No changes needed in HCP workspace settings.
- The relative path becomes simple (`./modules/iam-admin`).
- Each environment is self-contained and easy to understand.
- No need to debug “why can’t HCP see ../../modules?” again.

If later you want a more advanced structure, you can then:

- Move modules into a separate Git repo (**Option C**), or
- Use a single root folder and adjust HCP working directory (**Option B**).

---

## 9. Final Checklist

1. ✅ **Run Terraform only from environment folders**
   - `cd environments/dev` for dev
   - `cd environments/prod` for prod

2. ✅ **Do not run Terraform inside the `modules` folder**

3. ✅ **For HCP Terraform remote execution**:
   - Ensure all modules you reference via `source` are **inside the directory tree** that HCP uploads.
   - Use `source = "./modules/iam-admin"` if `modules` is directly under the env folder.

4. ✅ **For local-only runs**:
   - You can keep `source = "../../modules/iam-admin"` and use a non-cloud backend.

With this, your `terraform init`, `terraform plan`, and `terraform apply` should work cleanly for both **dev** and **prod** without the unreadable module directory error.
