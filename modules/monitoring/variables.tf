variable "name_prefix" {
  type        = string
  description = "Alarm name prefix."
}

variable "create_topic" {
  type        = bool
  default     = false
  description = "Create an SNS topic in this Region. false = use topic_arn (for example the Landing Zone topic)."
}

variable "topic_arn" {
  type        = string
  default     = null
  description = "Existing same-Region SNS topic. Used when create_topic = false."
}

variable "alert_email" {
  type        = string
  default     = ""
  description = "E-mail subscribed to a topic created here."
}

variable "alarms" {
  description = "Alarms to create, by short name."
  type = map(object({
    description         = string
    namespace           = string
    metric_name         = string
    dimensions          = map(string)
    statistic           = optional(string, "Sum")
    extended_statistic  = optional(string)
    threshold           = number
    comparison_operator = optional(string, "GreaterThanOrEqualToThreshold")
    period              = optional(number, 300)
    evaluation_periods  = optional(number, 1)
  }))
}

variable "ratio_alarms" {
  description = "Alarms on a percentage: 100 * numerator / denominator (metric math). Used for the error-rate alarm."
  type = map(object({
    description         = string
    threshold           = number
    period              = optional(number, 300)
    evaluation_periods  = optional(number, 1)
    numerator           = object({ namespace = string, metric_name = string, dimensions = map(string), stat = optional(string, "Sum") })
    denominator         = object({ namespace = string, metric_name = string, dimensions = map(string), stat = optional(string, "Sum") })
    minimum_denominator = optional(number, 5)
  }))
  default = {}
}

variable "log_metric_filters" {
  description = "Metric filters that turn log lines into counts, by short name."
  type = map(object({
    log_group_name = string
    pattern        = string
    metric_name    = string
    namespace      = string
  }))
  default = {}
}

variable "log_queries" {
  description = "Saved CloudWatch Logs Insights queries, by name."
  type = map(object({
    log_group_names = list(string)
    query           = string
  }))
  default = {}
}

variable "dashboard_widgets" {
  description = "CloudWatch dashboard widgets (a list of widget objects). null = no dashboard. Built by the caller so one dashboard can show metrics from several Regions."
  type        = any
  default     = null
}
