variable "name_prefix" {
  type        = string
  description = "Bot name prefix."
}

variable "account_id" {
  type        = string
  description = "Account that owns the bot (resource policy condition)."
}

variable "connect_instance_arn" {
  type        = string
  description = "Connect instance allowed to call the bot alias."
}

variable "connect_instance_id" {
  type        = string
  description = "Connect instance the alias is associated with."
}

variable "locale_id" {
  type        = string
  default     = "en_ZA"
  description = "Bot locale."
}

variable "voice_id" {
  type        = string
  default     = "Ayanda"
  description = "Polly voice."
}

variable "voice_engine" {
  type        = string
  default     = "standard"
  description = "Polly engine: standard or neural."
}

variable "nlu_confidence_threshold" {
  type        = number
  default     = 0.75
  description = "Confidence below which Lex returns the fallback intent."
}

variable "idle_session_ttl_seconds" {
  type        = number
  default     = 120
  description = "Idle session TTL."
}

variable "conversation_logs" {
  type        = bool
  default     = false
  description = "Text conversation logs to CloudWatch Logs."
}

variable "log_retention_days" {
  type        = number
  default     = 14
  description = "Retention of the conversation log group."
}

variable "intents" {
  description = "Self-service intents by name."

  type = map(object({
    description             = string
    utterances              = list(string)
    parent_intent_signature = optional(string)
  }))
}
