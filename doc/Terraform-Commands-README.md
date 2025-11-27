# Terraform CLI Commands (README / Cheat Sheet)

This README is a simple “what command do I run and why?” guide for **Terraform CLI (v1.14.x)**.  
Tip: your exact command list can vary by version — run `terraform -help` to see *your* full list.  
Official overview of the CLI commands: https://developer.hashicorp.com/terraform/cli/commands

---

## Typical workflow (90% of day-to-day use)

```bash
terraform init              # download providers/modules, setup backend/state
terraform fmt -recursive    # format all .tf files
terraform validate          # validate syntax + basic config correctness
terraform plan -out tf.plan # preview changes (and save the plan)
terraform apply tf.plan     # make the changes
```

To delete everything managed by this config:

```bash
terraform destroy
```

---

## Global options (work with any command)

```bash
terraform -help
terraform <command> -help
terraform -chdir=DIR <command>   # run command as if you 'cd' into DIR
terraform version
```

---

## Main commands

### `terraform init`
**Prepares your working directory** for other commands: initializes backend, downloads providers, installs modules, creates/updates `.terraform.lock.hcl`.  
Common flags:
- `-upgrade` (upgrade provider/module versions within constraints)
- `-reconfigure` (re-read backend config)
- `-migrate-state` (migrate state when backend config changes)

Docs: https://developer.hashicorp.com/terraform/cli/commands/init

### `terraform fmt`
Formats `.tf` files to the standard style.
Common flags:
- `-recursive` (format subfolders too)
- `-check` (exit non‑zero if changes would be made)
- `-diff` (show formatting diff)

### `terraform validate`
Checks whether the configuration is valid (syntax + internal consistency).

### `terraform plan`
Creates an **execution plan** (preview of changes Terraform would make).  
Common flags:
- `-out=tf.plan` (save plan to a file)
- `-var-file=env.tfvars` (load variables)
- `-refresh-only` (sync state from real infra without changing infra)

Docs: https://developer.hashicorp.com/terraform/cli/commands/plan

### `terraform apply`
Applies changes (from configuration, or from a saved plan file).  
Common flags:
- `-auto-approve` (skip the “type yes” prompt)
- `-replace=ADDRESS` (force recreation of a specific resource instance)

Docs: https://developer.hashicorp.com/terraform/cli/commands/apply

### `terraform destroy`
Destroys all infrastructure managed by the current configuration.  
(Effectively `terraform apply -destroy`.)  
Docs: https://developer.hashicorp.com/terraform/cli/commands/destroy

---

## Other useful commands (top-level)

### `terraform console`
Interactive REPL to test expressions against your config/state.  
Docs: https://developer.hashicorp.com/terraform/cli/commands/console

### `terraform get`
Downloads/updates modules into `.terraform/`. (Older workflow; `init` usually covers module install now.)  
Docs: https://developer.hashicorp.com/terraform/cli/commands/get

### `terraform graph`
Outputs a Graphviz graph of dependencies/steps.

### `terraform show`
Shows human-readable output from a state file or plan file.  
Useful flags: `-json` for machine-readable output.  
Docs: https://developer.hashicorp.com/terraform/cli/commands/show

### `terraform output`
Prints output values from the root module (from state).  
Useful flags: `-json`, `-raw`.  
Docs: https://developer.hashicorp.com/terraform/cli/commands/output

### `terraform import`
Associates existing real infrastructure with a Terraform resource address (adds it to state).  
Docs: https://developer.hashicorp.com/terraform/cli/commands/import

### `terraform login` / `terraform logout`
Store/remove credentials for HCP Terraform / Terraform Enterprise (and other remote hosts).

### `terraform force-unlock`
Manually releases a stuck state lock (use carefully).  
Docs: https://developer.hashicorp.com/terraform/cli/commands/force-unlock

### `terraform modules`
Lists modules declared in the working directory (requires Terraform v1.10+).  
Docs: https://developer.hashicorp.com/terraform/cli/commands/modules

---

## Command groups (commands with subcommands)

### `terraform state` (advanced state management)
Use these when you *must* manipulate state (last resort; be careful).
Common subcommands:
- `terraform state list` — list resources in state
- `terraform state show ADDRESS` — show one resource’s state
- `terraform state mv SRC DST` — move/rename a resource in state
- `terraform state rm ADDRESS...` — “forget” resources (does not delete infra)
- `terraform state pull` — download current state to stdout/file
- `terraform state push FILE` — upload a local state file to the backend (**dangerous**)
- `terraform state replace-provider FROM TO` — swap provider addresses inside state

Docs: https://developer.hashicorp.com/terraform/cli/commands/state  
Push docs: https://developer.hashicorp.com/terraform/cli/commands/state/push

### `terraform workspace` (multiple state instances per config)
Common subcommands:
- `terraform workspace list`
- `terraform workspace show`
- `terraform workspace new NAME`
- `terraform workspace select NAME`
- `terraform workspace delete NAME`

Docs: https://developer.hashicorp.com/terraform/cli/commands/workspace

### `terraform providers` (provider inspection + tooling)
- `terraform providers` — show which providers are required and where from
- `terraform providers schema` — print provider schemas (supports `-json`)
- `terraform providers lock` — update `.terraform.lock.hcl` info/checksums
- `terraform providers mirror <dir>` — download providers into a local mirror dir

Docs: https://developer.hashicorp.com/terraform/cli/commands/providers

---

## Deprecated commands (still present, but avoid)

### `terraform refresh` (deprecated)
Use `terraform plan -refresh-only` or `terraform apply -refresh-only` instead.  
Docs: https://developer.hashicorp.com/terraform/cli/commands/refresh

### `terraform taint` (deprecated)
Use `terraform apply -replace=ADDRESS` instead.  
Docs: https://developer.hashicorp.com/terraform/cli/commands/taint

---

## Quick “what should I run?” guide

- New repo / new machine: `terraform init`
- Before committing: `terraform fmt -recursive && terraform validate`
- See what will change: `terraform plan`
- Deploy: `terraform apply`
- Inspect: `terraform show`, `terraform output`
- “Terraform is stuck locked”: `terraform force-unlock <LOCK_ID>`
- You need to bring an existing resource under Terraform: `terraform import`
- You must fix/rename state entries: `terraform state ...` (careful)

---

## Handy tips

- Save plans in CI/CD: `terraform plan -out=tf.plan` then `terraform apply tf.plan`
- Machine-readable: many commands support `-json` (`show`, `output`, etc.)
- Don’t commit `.terraform/` directory, **do commit** `.terraform.lock.hcl`
