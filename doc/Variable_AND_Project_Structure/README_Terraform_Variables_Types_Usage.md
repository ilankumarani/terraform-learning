# Terraform Variables – Types and How to Use Them

This README explains **all the main Terraform variable types** and **how to use them** with examples.

---

## 1. Declaring a variable – basic syntax

```hcl
variable "variable_name" {
  type        = string        # (optional but recommended)
  description = "What this variable is for"
  default     = "some value"  # (optional)
}
```

You can then use it in code as:

```hcl
resource "aws_instance" "example" {
  ami           = var.ami_id
  instance_type = var.instance_type
}
```

---

## 2. Primitive types

Primitive = single simple values.

### 2.1 `string`

Text values.

```hcl
variable "env" {
  type        = string
  description = "Deployment environment"
  default     = "dev"
}
```

Usage:

```hcl
tags = {
  Environment = var.env
}
```

---

### 2.2 `number`

Numeric values (int / float).

```hcl
variable "instance_count" {
  type        = number
  description = "Number of instances"
  default     = 2
}
```

Usage:

```hcl
count = var.instance_count
```

---

### 2.3 `bool`

True / false.

```hcl
variable "enable_logging" {
  type        = bool
  description = "Enable CloudWatch logging"
  default     = true
}
```

Usage:

```hcl
resource "aws_cloudwatch_log_group" "this" {
  count = var.enable_logging ? 1 : 0
  name  = "/aws/app"
}
```

---

## 3. Collection types

Collections hold **multiple values**.

### 3.1 `list(<TYPE>)`

Ordered list, indexed (0, 1, 2, …). All elements are same type.

```hcl
variable "availability_zones" {
  type        = list(string)
  description = "AZs to use"
  default     = ["eu-west-2a", "eu-west-2b"]
}
```

Usage:

```hcl
subnet_az = var.availability_zones[0]
```

---

### 3.2 `set(<TYPE>)`

Unordered, unique elements. No duplicates. Good when order doesn’t matter.

```hcl
variable "allowed_ips" {
  type        = set(string)
  description = "IP CIDR blocks allowed in security group"
  default     = ["10.0.0.0/24", "192.168.1.0/24"]
}
```

Usage:

```hcl
ingress {
  cidr_blocks = var.allowed_ips
}
```

---

### 3.3 `map(<TYPE>)`

Key–value pairs. Keys are always strings.

```hcl
variable "common_tags" {
  type        = map(string)
  description = "Tags to apply to all resources"
  default = {
    Application = "my-app"
    Environment = "dev"
    Owner       = "team-x"
  }
}
```

Usage:

```hcl
tags = var.common_tags
```

---

## 4. Structural types

Structural types describe **shaped** data – multiple attributes together.

### 4.1 `object({ ... })`

Fixed structure with named attributes and types.

```hcl
variable "db_config" {
  type = object({
    engine   = string
    version  = string
    storage  = number
    multi_az = bool
  })

  default = {
    engine   = "postgres"
    version  = "14"
    storage  = 20
    multi_az = false
  }
}
```

Usage:

```hcl
resource "aws_db_instance" "db" {
  engine            = var.db_config.engine
  engine_version    = var.db_config.version
  allocated_storage = var.db_config.storage
  multi_az          = var.db_config.multi_az
}
```

---

### 4.2 `tuple([ ... ])`

Ordered collection where each position can have **different type**.

```hcl
variable "example_tuple" {
  type = tuple([string, number, bool])
  default = ["hello", 10, true]
}
```

Usage:

```hcl
local message  = var.example_tuple[0] # string
local retries  = var.example_tuple[1] # number
local enabled  = var.example_tuple[2] # bool
```

---

## 5. Dynamic / flexible type – `any`

`any` means “no type constraint”. The variable can be **string, list, map, object, anything**.

```hcl
variable "config" {
  type        = any
  description = "Generic configuration blob"
}
```

Usage:

```hcl
locals {
  config = var.config
}
```

> Good for quick experiments, but not recommended for large / team projects because you lose validation.

---

## 6. Nested / combined types

You can **combine** types for more complex inputs.

### 6.1 List of objects

```hcl
variable "subnets" {
  type = list(object({
    name = string
    cidr = string
    az   = string
  }))
  description = "List of subnets to create"
}
```

Example value in `.tfvars`:

```hcl
subnets = [
  {
    name = "public-1"
    cidr = "10.0.1.0/24"
    az   = "eu-west-2a"
  },
  {
    name = "public-2"
    cidr = "10.0.2.0/24"
    az   = "eu-west-2b"
  }
]
```

Usage:

```hcl
resource "aws_subnet" "this" {
  for_each = {
    for s in var.subnets : s.name => s
  }

  vpc_id            = aws_vpc.main.id
  cidr_block        = each.value.cidr
  availability_zone = each.value.az
  tags = {
    Name = each.value.name
  }
}
```

---

### 6.2 Map of objects (per environment config)

```hcl
variable "environments" {
  type = map(object({
    instance_type = string
    min_size      = number
    max_size      = number
  }))

  default = {
    dev = {
      instance_type = "t3.micro"
      min_size      = 1
      max_size      = 2
    }
    prod = {
      instance_type = "t3.medium"
      min_size      = 2
      max_size      = 5
    }
  }
}
```

Usage:

```hcl
locals {
  current_env = var.environments[var.env]
}

resource "aws_autoscaling_group" "asg" {
  min_size      = local.current_env.min_size
  max_size      = local.current_env.max_size
  # ...
}
```

---

## 7. Optional and nullable attributes (more advanced)

Terraform allows **optional** attributes in object types.

```hcl
variable "service_config" {
  type = object({
    name        = string
    port        = number
    enable_tls  = optional(bool, false)
    extra_tags  = optional(map(string), {})
  })
}
```

- `optional(bool, false)` → attribute can be missing; if missing, default is `false`.
- `optional(map(string), {})` → optional map with default empty map.

Usage:

```hcl
resource "aws_lb_listener" "this" {
  port     = var.service_config.port
  protocol = var.service_config.enable_tls ? "HTTPS" : "HTTP"
}
```

---

## 8. Variable validation

You can validate values **inside** a variable block.

```hcl
variable "env" {
  type        = string
  description = "Environment name"
  default     = "dev"

  validation {
    condition     = contains(["dev", "stage", "prod"], var.env)
    error_message = "env must be one of: dev, stage, prod."
  }
}
```

If someone passes `env = "blah"`, Terraform will fail with the custom error message.

---

## 9. Providing variable values

There are several ways to **pass values** into variables.

### 9.1 `terraform.tfvars` (recommended)

Create a file `terraform.tfvars`:

```hcl
env            = "prod"
instance_count = 3

availability_zones = ["eu-west-2a", "eu-west-2b"]
```

Terraform loads `terraform.tfvars` automatically.

---

### 9.2 `*.auto.tfvars` files

All `*.auto.tfvars` files are also loaded automatically.

Example: `dev.auto.tfvars`, `stage.auto.tfvars`.

---

### 9.3 Command line `-var`

```bash
terraform apply -var="env=prod" -var="instance_count=3"
```

---

### 9.4 Variable file `-var-file`

```bash
terraform apply -var-file="prod.tfvars"
```

---

### 9.5 Environment variables

Environment variables of the form `TF_VAR_<name>`.

Example (Linux / macOS):

```bash
export TF_VAR_env=prod
export TF_VAR_instance_count=3
```

Example (Windows PowerShell):

```powershell
$env:TF_VAR_env = "prod"
$env:TF_VAR_instance_count = "3"
```

---

## 10. Variables in modules

When you call a module, you pass variables as arguments.

### 10.1 In the module (`modules/network/variables.tf`):

```hcl
variable "vpc_cidr" {
  type = string
}

variable "public_subnets" {
  type = list(string)
}
```

### 10.2 In root module:

```hcl
module "network" {
  source         = "./modules/network"
  vpc_cidr       = "10.0.0.0/16"
  public_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
}
```

Inside the module, you use `var.vpc_cidr` and `var.public_subnets`.

---

## 11. Quick reference summary

### Primitive

- `string`
- `number`
- `bool`

### Collection

- `list(<TYPE>)`
- `set(<TYPE>)`
- `map(<TYPE>)`

### Structural

- `object({ attr = TYPE, ... })`
- `tuple([TYPE, TYPE, ...])`

### Dynamic

- `any`

### Extras

- `optional(TYPE, default)` in `object`
- `validation { ... }` to validate values

---

## 12. Minimal cheat-sheet examples

### Simple string var

```hcl
variable "region" {
  type    = string
  default = "eu-west-2"
}
```

### List of strings

```hcl
variable "subnet_ids" {
  type = list(string)
}
```

### Map of strings

```hcl
variable "tags" {
  type = map(string)
}
```

### Object

```hcl
variable "app" {
  type = object({
    name = string
    port = number
  })
}
```

---

This should give you everything you need to **define, use, and validate** Terraform variables in real projects.
