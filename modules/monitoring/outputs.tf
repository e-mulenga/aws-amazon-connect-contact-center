output "topic_arn" {
  description = "Topic the alarms notify (created here or supplied)."
  value       = local.topic_arn
}

output "alarm_names" {
  value = [for a in aws_cloudwatch_metric_alarm.this : a.alarm_name]
}

output "dashboard_name" {
  value = var.dashboard_widgets == null ? null : aws_cloudwatch_dashboard.this[0].dashboard_name
}

output "query_definition_names" {
  value = [for q in aws_cloudwatch_query_definition.this : q.name]
}
