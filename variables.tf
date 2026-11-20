# ---- Identity ----
variable "workload_name" {
  description = "Short workload name used in resource names."
  type        = string
  default     = "contact-center"
}

variable "environment" {
  description = "Deployment environment."
  type        = string

  validation {
    condition     = contains(["dev", "test", "prod"], var.environment)
    error_message = "environment must be dev, test or prod."
  }
}

variable "owner" {
  description = "Owner tag."
  type        = string
}

variable "cost_center" {
  description = "Cost centre tag."
  type        = string
}

variable "primary_region" {
  description = "Primary region. The whole stack runs in Cape Town."
  type        = string
  default     = "af-south-1"

  validation {
    condition     = var.primary_region == "af-south-1"
    error_message = "Only af-south-1 is approved as the primary region."
  }
}

# ---- Amazon Connect ----
variable "instance_alias" {
  description = "Connect instance alias (it becomes part of the access URL and must be unique in the Region). null = derived from the workload name, environment and a short hash."
  type        = string
  default     = null
}

variable "contact_lens_enabled" {
  description = "Enable Contact Lens on the instance (conversational analytics). Real-time analytics is not available in every Region, see docs/regional-availability.md."
  type        = bool
  default     = true
}

variable "contact_flow_logs_enabled" {
  description = "Write contact flow logs to CloudWatch Logs."
  type        = bool
  default     = true
}

variable "inbound_calls_enabled" {
  description = "Allow inbound voice calls."
  type        = bool
  default     = true
}

variable "outbound_calls_enabled" {
  description = "Allow outbound voice calls (agents calling customers back)."
  type        = bool
  default     = true
}

variable "time_zone" {
  description = "Time zone of the hours of operation."
  type        = string
  default     = "Africa/Johannesburg"
}

variable "business_hours" {
  description = "Opening hours by day: start and end as HH:MM (24 hour clock). Days not listed are closed."
  type        = map(object({ start = string, end = string }))
  default = {
    MONDAY    = { start = "08:00", end = "17:00" }
    TUESDAY   = { start = "08:00", end = "17:00" }
    WEDNESDAY = { start = "08:00", end = "17:00" }
    THURSDAY  = { start = "08:00", end = "17:00" }
    FRIDAY    = { start = "08:00", end = "17:00" }
    SATURDAY  = { start = "08:00", end = "13:00" }
  }

  validation {
    condition     = alltrue([for d, h in var.business_hours : contains(["MONDAY", "TUESDAY", "WEDNESDAY", "THURSDAY", "FRIDAY", "SATURDAY", "SUNDAY"], d) && can(regex("^([01][0-9]|2[0-3]):[0-5][0-9]$", h.start)) && can(regex("^([01][0-9]|2[0-3]):[0-5][0-9]$", h.end))])
    error_message = "business_hours keys must be MONDAY to SUNDAY and times must be HH:MM."
  }
}

variable "queue_max_contacts" {
  description = "Maximum contacts waiting in each queue before callers are told it is full. 0 = no limit."
  type        = number
  default     = 25
}

variable "voice_concurrency" {
  description = "Calls an agent handles at once (Connect allows exactly 1)."
  type        = number
  default     = 1
}

variable "chat_concurrency" {
  description = "Chats an agent handles at once."
  type        = number
  default     = 3
}

variable "claim_phone_number" {
  description = "Claim a phone number and point it at the inbound flow. A number is billed monthly, so this is off until you need it."
  type        = bool
  default     = false
}

variable "phone_number_country_code" {
  description = "ISO country code of the claimed number."
  type        = string
  default     = "ZA"
}

variable "phone_number_type" {
  description = "TOLL_FREE or DID."
  type        = string
  default     = "DID"

  validation {
    condition     = contains(["TOLL_FREE", "DID"], var.phone_number_type)
    error_message = "phone_number_type must be TOLL_FREE or DID."
  }
}

# ---- Contact Lens analytics (set in the inbound flow) ----
variable "enable_contact_lens_analytics" {
  description = "Turn on post-call analytics, sentiment and PII redaction from the inbound flow."
  type        = bool
  default     = true
}

variable "analytics_language" {
  description = "Language code used for Contact Lens analytics."
  type        = string
  default     = "en-US"
}

# ---- Lex ----
variable "lex_locale_id" {
  description = "Amazon Lex V2 locale of the self-service bot (en_ZA is South African English)."
  type        = string
  default     = "en_ZA"
}

variable "lex_voice_id" {
  description = "Amazon Polly voice used by the bot for voice."
  type        = string
  default     = "Ayanda"
}

variable "lex_nlu_confidence_threshold" {
  description = "Below this confidence Lex falls back to the fallback intent."
  type        = number
  default     = 0.75
}

variable "lex_idle_session_ttl_seconds" {
  description = "Seconds Lex keeps a conversation open without input (60 to 86400)."
  type        = number
  default     = 120
}

variable "lex_conversation_logs" {
  description = "Write Lex text conversation logs to CloudWatch Logs. Logs contain what customers said, so they are off by default."
  type        = bool
  default     = false
}

# ---- Data ----
variable "recordings_retention_days" {
  description = "Days call recordings and transcripts are kept before expiry."
  type        = number
  default     = 90
}

variable "callback_retention_days" {
  description = "Days a callback request is kept (DynamoDB TTL)."
  type        = number
  default     = 7
}

variable "interaction_retention_days" {
  description = "Days a contact summary is kept (DynamoDB TTL)."
  type        = number
  default     = 365
}

variable "noncurrent_expiry_days" {
  description = "Days old object versions are kept."
  type        = number
  default     = 7
}

variable "force_destroy" {
  description = "Allow terraform destroy to delete non-empty buckets."
  type        = bool
  default     = false
}

# ---- Operations ----
variable "log_retention_days" {
  description = "Retention of Lambda and flow log groups."
  type        = number
  default     = 14
}

variable "enable_alarms" {
  description = "Create the CloudWatch alarms, queries and dashboard."
  type        = bool
  default     = true
}

variable "enable_xray" {
  description = "Active X-Ray tracing on the Lambda functions."
  type        = bool
  default     = true
}

variable "lambda_architecture" {
  description = "Lambda CPU architecture."
  type        = string
  default     = "arm64"
}

variable "missed_calls_alarm_threshold" {
  description = "Missed calls in 15 minutes that raise an alarm."
  type        = number
  default     = 5
}

variable "concurrent_calls_alarm_percent" {
  description = "Percent of the instance concurrent call quota that raises an alarm."
  type        = number
  default     = 80
}

variable "github_repository" {
  description = "GitHub repository (owner/name). When set, creates the OIDC plan and apply roles against the Landing Zone provider."
  type        = string
  default     = ""

  validation {
    condition     = var.github_repository == "" || can(regex("^[A-Za-z0-9-]+/[A-Za-z0-9._-]+$", var.github_repository))
    error_message = "github_repository must look like owner/name."
  }
}
