variable "name_prefix" {
  type        = string
  description = "Resource name prefix."
}

variable "account_id" {
  type        = string
  description = "Account that owns the instance (used in bucket policy conditions)."
}

variable "instance_alias" {
  type        = string
  description = "Connect instance alias."
}

variable "bucket_suffix" {
  type        = string
  description = "Short deterministic suffix that makes the bucket name globally unique."
}

variable "contact_lens_enabled" {
  type        = bool
  default     = true
  description = "Contact Lens on the instance."
}

variable "contact_flow_logs_enabled" {
  type        = bool
  default     = true
  description = "Contact flow logs."
}

variable "inbound_calls_enabled" {
  type        = bool
  default     = true
  description = "Inbound calls."
}

variable "outbound_calls_enabled" {
  type        = bool
  default     = true
  description = "Outbound calls."
}

variable "kms_key_arn" {
  type        = string
  default     = null
  description = "Landing Zone shared S3 CMK for recordings and transcripts. null = SSE-S3 (AWS managed)."
}

variable "time_zone" {
  type        = string
  description = "Hours of operation time zone."
}

variable "business_hours" {
  type        = map(object({ start = string, end = string }))
  description = "Opening hours by day."
}

variable "queue_max_contacts" {
  type        = number
  default     = 25
  description = "Queue capacity."
}

variable "voice_concurrency" {
  type        = number
  default     = 1
  description = "Voice concurrency."
}

variable "chat_concurrency" {
  type        = number
  default     = 3
  description = "Chat concurrency."
}

variable "queues" {
  description = "Queues by short name with the routing priority used by the standard routing profile."
  type = map(object({
    description = string
    priority    = number
  }))
}

variable "recordings_retention_days" {
  type        = number
  default     = 90
  description = "Expiry of recordings and transcripts."
}

variable "noncurrent_expiry_days" {
  type        = number
  default     = 7
  description = "Expiry of old versions."
}

variable "force_destroy" {
  type        = bool
  default     = false
  description = "Delete the bucket even when it holds objects."
}

variable "claim_phone_number" {
  type        = bool
  default     = false
  description = "Claim a phone number."
}

variable "phone_number_country_code" {
  type        = string
  default     = "ZA"
  description = "Country of the claimed number."
}

variable "phone_number_type" {
  type        = string
  default     = "DID"
  description = "TOLL_FREE or DID."
}

variable "log_retention_days" {
  type        = number
  default     = 14
  description = "Retention of the contact flow log group."
}
