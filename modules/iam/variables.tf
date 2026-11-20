variable "name_prefix" {
  type        = string
  description = "Role name prefix."
}

variable "oidc_provider_arn" {
  type        = string
  description = "Landing Zone GitHub OIDC provider ARN. The provider is consumed, never created here."
}

variable "github_repository" {
  type        = string
  description = "GitHub repository (owner/name) allowed to assume the roles."

  validation {
    condition     = can(regex("^[A-Za-z0-9-]+/[A-Za-z0-9._-]+$", var.github_repository))
    error_message = "github_repository must look like owner/name."
  }
}

variable "environment" {
  type        = string
  description = "Environment name. The apply role trusts the GitHub environment of the same name."
}

variable "apply_ref" {
  type        = string
  default     = "refs/heads/main"
  description = "Git ref the apply role also trusts (for a push-triggered deployment without an environment gate)."
}

variable "state_bucket" {
  type        = string
  description = "Landing Zone Terraform state bucket."
}

variable "state_key_prefix" {
  type        = string
  description = "State key prefix of this repository (objects under it are readable and writable by the roles)."
}

variable "state_kms_key_arn" {
  type        = string
  default     = null
  description = "CMK of the state bucket, if it uses one."
}

variable "max_session_seconds" {
  type        = number
  default     = 3600
  description = "Role session duration."
}
