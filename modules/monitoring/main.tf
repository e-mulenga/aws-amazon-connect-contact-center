############################################
# Alarms (a standard alarm is about USD 0.10 per month; a metric-math alarm is billed per metric it references), log metric filters, saved Logs Insights
# queries and the operations dashboard (the first three dashboards in an account are free).
############################################

# CloudWatch alarms cannot publish to a topic encrypted with the AWS managed key aws/sns, so this topic is unencrypted.
resource "aws_sns_topic" "this" {
  count = var.create_topic ? 1 : 0
  name  = "${var.name_prefix}-alerts"
}

resource "aws_sns_topic_subscription" "email" {
  count = var.create_topic && var.alert_email != "" ? 1 : 0

  topic_arn = aws_sns_topic.this[0].arn
  protocol  = "email"
  endpoint  = var.alert_email
}

locals {
  topic_arn = var.create_topic ? aws_sns_topic.this[0].arn : var.topic_arn
}

resource "aws_cloudwatch_metric_alarm" "this" {
  for_each = var.alarms

  alarm_name          = "${var.name_prefix}-${each.key}"
  alarm_description   = each.value.description
  namespace           = each.value.namespace
  metric_name         = each.value.metric_name
  dimensions          = each.value.dimensions
  statistic           = each.value.extended_statistic == null ? each.value.statistic : null
  extended_statistic  = each.value.extended_statistic
  threshold           = each.value.threshold
  comparison_operator = each.value.comparison_operator
  period              = each.value.period
  evaluation_periods  = each.value.evaluation_periods
  treat_missing_data  = "notBreaching"
  alarm_actions       = local.topic_arn == null ? [] : [local.topic_arn]
  ok_actions          = local.topic_arn == null ? [] : [local.topic_arn]
}

# Error rate as a percentage. Below minimum_denominator requests the rate is not evaluated, so one failed call at night cannot page anyone.
resource "aws_cloudwatch_metric_alarm" "ratio" {
  for_each = var.ratio_alarms

  alarm_name          = "${var.name_prefix}-${each.key}"
  alarm_description   = each.value.description
  comparison_operator = "GreaterThanThreshold"
  threshold           = each.value.threshold
  evaluation_periods  = each.value.evaluation_periods
  treat_missing_data  = "notBreaching"
  alarm_actions       = local.topic_arn == null ? [] : [local.topic_arn]
  ok_actions          = local.topic_arn == null ? [] : [local.topic_arn]

  metric_query {
    id = "n"

    metric {
      namespace   = each.value.numerator.namespace
      metric_name = each.value.numerator.metric_name
      dimensions  = each.value.numerator.dimensions
      period      = each.value.period
      stat        = each.value.numerator.stat
    }
  }

  metric_query {
    id = "d"

    metric {
      namespace   = each.value.denominator.namespace
      metric_name = each.value.denominator.metric_name
      dimensions  = each.value.denominator.dimensions
      period      = each.value.period
      stat        = each.value.denominator.stat
    }
  }

  metric_query {
    id          = "rate"
    expression  = "IF(d >= ${each.value.minimum_denominator}, 100 * n / d, 0)"
    label       = "Error rate (%)"
    return_data = true
  }
}

resource "aws_cloudwatch_log_metric_filter" "this" {
  for_each = var.log_metric_filters

  name           = "${var.name_prefix}-${each.key}"
  log_group_name = each.value.log_group_name
  pattern        = each.value.pattern

  metric_transformation {
    name          = each.value.metric_name
    namespace     = each.value.namespace
    value         = "1"
    default_value = "0"
  }
}

resource "aws_cloudwatch_query_definition" "this" {
  for_each = var.log_queries

  name            = "${var.name_prefix}/${each.key}"
  log_group_names = each.value.log_group_names
  query_string    = each.value.query
}

resource "aws_cloudwatch_dashboard" "this" {
  count          = var.dashboard_widgets == null ? 0 : 1
  dashboard_name = "${var.name_prefix}-operations"

  dashboard_body = jsonencode({ widgets = var.dashboard_widgets })
}
