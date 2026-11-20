variable "name_prefix" {
  type        = string
  description = "Function name prefix."
}

variable "functions" {
  description = "Functions by short name. files maps a file name inside the package to a local source path."
  type = map(object({
    description = string
    handler     = optional(string, "handler.handler")
    timeout     = optional(number, 5)
    memory_size = optional(number, 128)
    files       = map(string)
    environment = map(string)
    statements = list(object({
      sid       = string
      actions   = list(string)
      resources = list(string)
    }))
  }))
}

variable "architecture" {
  type        = string
  default     = "arm64"
  description = "Lambda CPU architecture."
}

variable "log_retention_days" {
  type        = number
  default     = 14
  description = "Log group retention."
}

variable "enable_xray" {
  type        = bool
  default     = true
  description = "Active X-Ray tracing."
}

variable "kms_key_arn" {
  type        = string
  default     = null
  description = "Landing Zone CMK that encrypts environment variables and logs. null = service default encryption."
}
