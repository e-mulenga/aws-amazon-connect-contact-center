output "function_arns" {
  description = "Function ARNs by short name (no version qualifier)."
  value       = { for k, f in aws_lambda_function.this : k => f.arn }
}

output "function_names" {
  value = { for k, f in aws_lambda_function.this : k => f.function_name }
}

output "log_group_names" {
  value = { for k, g in aws_cloudwatch_log_group.this : k => g.name }
}
