variable "name_prefix" {
  type        = string
  description = "Flow name prefix."
}

variable "account_id" {
  type        = string
  description = "Account that owns the instance (Lambda permission condition)."
}

variable "instance_id" {
  type        = string
  description = "Connect instance ID."
}

variable "instance_arn" {
  type        = string
  description = "Connect instance ARN."
}

variable "queue_arns" {
  type        = map(string)
  description = "Queue ARNs by short name. Must contain general and priority."
}

variable "lex_alias_arn" {
  type        = string
  description = "Lex V2 bot alias the flow calls."
}

variable "lambda_arns" {
  type        = map(string)
  description = "Lambda ARNs by short name. Must contain crm_lookup and callback."
}

variable "lambda_names" {
  type        = map(string)
  description = "Lambda function names by short name (for the invoke permission)."
}

variable "enable_analytics" {
  type        = bool
  default     = true
  description = "Contact Lens post-call analytics, sentiment and redaction."
}

variable "analytics_language" {
  type        = string
  default     = "en-US"
  description = "Contact Lens language code."
}

variable "opening_hours_text" {
  type        = string
  description = "Opening hours as spoken to the caller."
}

variable "phone_number_id" {
  type        = string
  default     = null
  description = "Claimed phone number to point at the inbound flow. null = none."
}
