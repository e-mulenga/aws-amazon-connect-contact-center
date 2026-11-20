variable "name_prefix" {
  type        = string
  description = "Table name prefix."
}

variable "kms_key_arn" {
  type        = string
  default     = null
  description = "Landing Zone CMK for table encryption. null = AWS managed key aws/dynamodb (still encrypted at rest)."
}

variable "point_in_time_recovery" {
  type        = bool
  default     = true
  description = "Point-in-time recovery on the tables."
}

variable "deletion_protection" {
  type        = bool
  default     = false
  description = "DynamoDB deletion protection."
}
