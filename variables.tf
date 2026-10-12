# ── Identity ──────────────────────────────────────────────
variable "environment" {
  description = "Environment: dev | qa | prod"
  type        = string
  nullable    = false

  validation {
    condition     = contains(["dev", "qa", "prod"], var.environment)
    error_message = "environment must be one of: dev, qa, prod."
  }
}

variable "project" {
  description = "Project code that owns the microservice"
  type        = string
  nullable    = false
  
  validation {
    condition     = can(regex("^ms-[a-z0-9]+(-[a-z0-9]+)*$", var.component)) && length(var.component) <= 50
    error_message = "component use only lowercase letters, numbers and single hyphens, and be at most 50 characters."
  }
}

variable "component" {
  description = "Microservice name, e.g. 'ms-xyz'. Builds the role name ({environment}-{project}-eks-{component}) and the default ServiceAccount name ({component}-sa)"
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^ms-[a-z0-9]+(-[a-z0-9]+)*$", var.component)) && length(var.component) <= 50
    error_message = "component must start with 'ms-xyz', use only lowercase letters, numbers and single hyphens, and be at most 50 characters."
  }
}

# ── Kubernetes (trust only, nothing is created in the cluster) ──
variable "namespace" {
  description = "Kubernetes namespace where the ServiceAccount lives"
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[a-z0-9]([-a-z0-9]{0,61}[a-z0-9])?$", var.namespace))
    error_message = "namespace must be a valid Kubernetes name: lowercase letters, numbers and hyphens, at most 63 characters."
  }
}

variable "service_account" {
  description = "ServiceAccount name. Defaults to '{component}-sa'. Set it only if the microservice breaks the naming convention"
  type        = string
  default     = null

  validation {
    condition     = var.service_account == null || can(regex("^[a-z0-9]([-a-z0-9.]{0,251}[a-z0-9])?$", var.service_account))
    error_message = "service_account must be a valid Kubernetes name: lowercase letters, numbers, hyphens and dots."
  }
}

variable "oidc_provider_arn" {
  description = "ARN of the EKS cluster IAM OIDC provider. Fixed value while the cluster exists"
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^arn:aws[a-z-]*:iam::[0-9]{12}:oidc-provider/oidc\\.eks\\.[a-z0-9-]+\\.amazonaws\\.com(\\.cn)?/id/[A-Za-z0-9]+$", var.oidc_provider_arn))
    error_message = "oidc_provider_arn must look like arn:aws:iam::<account>:oidc-provider/oidc.eks.<region>.amazonaws.com/id/<ID>."
  }
}

# ── Permissions ───────────────────────────────────────────
variable "permissions_boundary_arn" {
  description = "ARN of the managed policy used as permissions boundary (e.g. dev-hc-eks-workload-boundary). Optional: can be enabled later without recreating the role"
  type        = string
  default     = null

  validation {
    condition     = var.permissions_boundary_arn == null || can(regex("^arn:aws[a-z-]*:iam::([0-9]{12}|aws):policy/.+$", var.permissions_boundary_arn))
    error_message = "permissions_boundary_arn must be an IAM policy ARN."
  }
}

variable "policies" {
  description = "Map of policy key to JSON document content. Each entry becomes an inline policy named '{role_name}-{key}'. Read the files in the caller, e.g. file(\"policies/ms-core/s3-read.json\")"
  type        = map(string)
  nullable    = false

  validation {
    condition     = length(var.policies) > 0
    error_message = "At least one policy is required: an IRSA role without permissions has no purpose."
  }

  validation {
    condition     = alltrue([for k in keys(var.policies) : can(regex("^[a-z0-9]+(-[a-z0-9]+)*$", k)) && length(k) <= 60])
    error_message = "Policy keys must use only lowercase letters, numbers and single hyphens (e.g. 's3-read'), at most 60 characters."
  }

  validation {
    condition     = alltrue([for p in values(var.policies) : can(jsondecode(p))])
    error_message = "Every policy must be valid JSON."
  }

  validation {
    condition     = try(length(join("", [for p in values(var.policies) : jsonencode(jsondecode(p))])) <= 10240, true)
    error_message = "Inline policies of a role cannot exceed 10,240 characters in total (whitespace excluded). Review least privilege or split the microservice permissions."
  }
}
