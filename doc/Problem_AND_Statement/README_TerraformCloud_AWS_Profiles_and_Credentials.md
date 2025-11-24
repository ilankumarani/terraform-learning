# Terraform Cloud, AWS Profiles, and Why `~/.aws/credentials` Don’t Work Remotely

## 1. Problem Statement

You have a Terraform configuration like:

```hcl
provider "aws" {
  region  = "eu-west-1"
  profile = "default"
}
```

On your **local machine**, you have:

- `~/.aws/credentials`
- `~/.aws/config`

with a `default` profile configured (e.g. via `aws configure`).

You then:

- Connect your Terraform code to **Terraform Cloud**.
- Use a **Terraform Cloud workspace** with **remote execution**.
- Expect Terraform Cloud to use the **same `default` profile** from your local `~/.aws/credentials`.

Result: Terraform Cloud runs fail with **AWS authentication errors** because the `default` profile is not found.

This README explains:

- **Why** this happens  
- How Terraform and Terraform Cloud handle **credentials**  
- **All the valid ways** to solve this, depending on how you want to work

---

## 2. Key Concept: Local vs Remote Execution

### 2.1 Local execution (CLI-driven runs)

When you run:

```bash
terraform init
terraform plan
terraform apply
```

on **your own PC**, Terraform:

1. Loads your configuration files (`main.tf`, `providers.tf`, etc.).
2. Loads your `provider "aws"` block.
3. The AWS provider sees:

   ```hcl
   provider "aws" {
     region  = "eu-west-1"
     profile = "default"
   }
   ```

4. The AWS SDK on your machine then:
   - Reads `~/.aws/credentials` and `~/.aws/config`
   - Finds `[default]` profile
   - Uses those credentials to talk to AWS

✅ In **local execution**, `profile = "default"` + local `~/.aws/credentials` works perfectly.

---

### 2.2 Remote execution (Terraform Cloud runs your code)

With **Terraform Cloud remote execution**, the flow changes:

1. You push your code or run `terraform apply` with a remote backend.
2. Terraform Cloud:
   - Spins up a **remote worker** (a container/VM on HashiCorp’s side)
   - Downloads **your Terraform configuration files**
   - Runs `terraform init/plan/apply` **on that remote machine**.

On that remote worker:

- There is **no `~/.aws/credentials` from your laptop**.
- There is **no `~/.aws/config` from your laptop**.
- So `profile = "default"` refers to a **non-existent profile** on that machine.

❌ Terraform Cloud **cannot read files from your local PC**. It only sees:

- The Terraform configuration files uploaded to the workspace
- Environment variables set in the workspace
- Any variables and secrets you define inside Terraform Cloud

---

## 3. Why You Are Facing This Issue

Short version:

> You are telling the AWS provider to use `profile = "default"`, which only exists in **your local `~/.aws/credentials`**, but you are running Terraform in **Terraform Cloud remote execution**, where that file does **not** exist.

So the AWS provider in Terraform Cloud tries to:

- Look for a `default` profile using the AWS SDK’s credential chain
- Fails, because no such profile is configured in the environment
- Returns an authentication error (e.g. “No valid credential sources found”).

---

## 4. What Terraform Cloud Can and Cannot Use

### 4.1 Terraform Cloud **cannot**:

- Read `~/.aws/credentials` on your laptop
- Read `~/.aws/config` on your laptop
- Reach into your local filesystem at all

### 4.2 Terraform Cloud **can**:

- Read environment variables **inside the remote run environment**
  - e.g. `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_SESSION_TOKEN`
- Read Terraform Cloud **workspace variables**
  - Sensitive and non-sensitive vars defined in the workspace UI
- Use **OIDC / IAM roles** you configure in AWS to assume roles securely

---

## 5. Valid Solutions (All Options)

There is no single “right” answer; it depends on how you want to work.

### Option 1 – Use Terraform Cloud **only as backend**, run Terraform **locally**

This is the approach if you want:

- To keep using your **local AWS profiles** (`~/.aws/credentials`)
- To use Terraform Cloud for **remote state storage**, history, policies, etc.
- To **run `plan/apply` from your own machine**, not from Terraform Cloud’s workers

#### 5.1 How it works

1. Configure your Terraform project with a Terraform Cloud backend (or `cloud {}` block).
2. In Terraform Cloud, set the workspace to **“Local” / CLI-driven runs** (no remote execution).
3. On your machine:
   - `~/.aws/credentials` has the `default` profile
   - You run:

     ```bash
     terraform init
     terraform plan
     terraform apply
     ```

   - Terraform uses your local `profile = "default"` and AWS credentials
   - State is saved in Terraform Cloud, but **execution happens on your PC**.

#### 5.2 When to choose this

- You are comfortable running Terraform on your local dev machine.
- You like using your existing AWS CLI profiles (`dev`, `prod`, etc.).
- You want Terraform Cloud mostly for:
  - State
  - History of runs
  - Team visibility

✅ Your existing provider config is fine:

```hcl
provider "aws" {
  region  = "eu-west-1"
  profile = "default"
}
```

As long as you run Terraform **locally**, this works.

---

### Option 2 – Use Terraform Cloud **remote execution** with **AWS environment variables**

This is the approach if you want:

- Terraform Cloud to run plans/applies **without your laptop**
- CI-style runs on every push
- Centralised execution

In this model, you **do not use `profile = "default"`**. Instead, you give Terraform Cloud explicit AWS credentials.

#### 5.3 Steps

1. In Terraform Cloud workspace **Variables**:
   - Add environment variables:
     - `AWS_ACCESS_KEY_ID`
     - `AWS_SECRET_ACCESS_KEY`
     - `AWS_SESSION_TOKEN` (if you use temporary credentials)
     - Optionally `AWS_DEFAULT_REGION` (or set region in provider)
   - Mark them as **sensitive** where appropriate.

2. Change your `provider "aws"` block to:

   ```hcl
   provider "aws" {
     region = "eu-west-1"
     # Do NOT set profile here for Terraform Cloud remote execution
   }
   ```

3. Run `terraform plan` / `apply` in Terraform Cloud.

Terraform Cloud’s remote worker will:

- Read the environment variables
- Use them as its AWS credentials
- Successfully authenticate to AWS

#### 5.4 When to choose this

- You want **true remote** CI-like runs.
- You are okay with:
  - Creating a dedicated IAM user or role for Terraform Cloud
  - Storing those credentials as environment variables in the workspace

---

### Option 3 – Use Terraform Cloud with **AWS IAM Role via OIDC (Assume Role)**

This is a more advanced and more secure solution:

- No long-lived AWS keys stored in Terraform Cloud
- Terraform Cloud assumes a role in your AWS account using OIDC identity

High-level idea:

1. Configure Terraform Cloud as an OIDC provider in AWS IAM.
2. Create an IAM role (e.g. `TerraformCloudRole`) with the permissions you want.
3. Allow that role to be assumed by your Terraform Cloud workspace.
4. In your provider:

   ```hcl
   provider "aws" {
     region = "eu-west-1"

     assume_role {
       role_arn = "arn:aws:iam::123456789012:role/TerraformCloudRole"
     }
   }
   ```

Now Terraform Cloud:

- Uses OIDC to prove its identity to AWS
- Assumes the specified IAM role
- Gets temporary credentials automatically

This is ideal for **production setups**, but requires more AWS/IAM configuration.

---

### Option 4 – Hybrid: Local Profiles for Dev, Remote Execution for Prod

You can also mix approaches:

- For **dev**:
  - Use local execution (Option 1) with your local `~/.aws/credentials`.
- For **prod**:
  - Use remote execution (Option 2 or 3) with:
    - Workspace environment variables or
    - OIDC + IAM role.

This way you get:

- Easy development using your laptop and local profile
- Controlled, secure production runs using Terraform Cloud and dedicated AWS identities

---

## 6. Summary / FAQ

### ❓ Can Terraform Cloud use `~/.aws/credentials` from my PC?

**No.** Terraform Cloud runs your code on **its own machines**, which do not have access to your local filesystem. It cannot read `~/.aws/credentials` or `~/.aws/config` sitting on your laptop.

---

### ❓ When is `profile = "default"` valid?

- ✅ When you run Terraform **locally**, on the same machine where `~/.aws/credentials` is configured.
- ❌ When you run Terraform in **Terraform Cloud remote execution**, unless you create a matching profile **inside** that remote environment (which you normally don’t).

---

### ❓ What should I do right now?

Pick based on what you want:

- **I want to keep using my local AWS CLI profile and just store state in TFC**  
  → Use **local/CLI execution** with Terraform Cloud as backend (**Option 1**).  
  Your current provider is fine.

- **I want Terraform Cloud to run everything remotely**  
  → Remove `profile` from the provider, and configure AWS credentials **in Terraform Cloud** using:
  - Environment variables (`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, etc.), or  
  - OIDC + IAM role (**Option 2 or 3**).

---

## 7. Example Configs

### 7.1 Local execution + Terraform Cloud backend

```hcl
terraform {
  cloud {
    organization = "my-org"

    workspaces {
      name = "my-workspace"
      # Set to CLI-driven in Terraform Cloud
    }
  }
}

provider "aws" {
  region  = "eu-west-1"
  profile = "default"  # uses your local ~/.aws/credentials
}
```

Run locally:

```bash
terraform init
terraform plan
terraform apply
```

---

### 7.2 Remote execution + AWS env vars (no profile)

```hcl
terraform {
  cloud {
    organization = "my-org"

    workspaces {
      name = "my-workspace"
      # Workspace uses remote execution
    }
  }
}

provider "aws" {
  region = "eu-west-1"
}
```

In Terraform Cloud workspace → Variables → Environment variables:

- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `AWS_DEFAULT_REGION` (optional if not set in provider)

---

With this README, you now have:

- A clear understanding of **why** your current approach fails
- Multiple **valid architectures** to fix it
- Concrete examples for both local and remote execution modes

You can drop this file into your repo as `README_TerraformCloud_AWS_Profiles.md` or just rename it to `README.md` for your Terraform Cloud experiments.
