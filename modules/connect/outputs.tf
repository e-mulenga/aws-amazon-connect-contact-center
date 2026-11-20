output "instance_id" {
  value = aws_connect_instance.this.id
}

output "instance_arn" {
  value = aws_connect_instance.this.arn
}

output "instance_alias" {
  value = aws_connect_instance.this.instance_alias
}

output "access_url" {
  description = "Sign-in URL of the instance."
  value       = "https://${aws_connect_instance.this.instance_alias}.my.connect.aws"
}

output "queue_ids" {
  value = { for k, q in aws_connect_queue.this : k => q.queue_id }
}

output "queue_arns" {
  value = { for k, q in aws_connect_queue.this : k => q.arn }
}

output "hours_of_operation_id" {
  value = aws_connect_hours_of_operation.business.hours_of_operation_id
}

output "routing_profile_id" {
  value = aws_connect_routing_profile.standard.routing_profile_id
}

output "security_profile_ids" {
  value = {
    agent      = aws_connect_security_profile.agent.security_profile_id
    supervisor = aws_connect_security_profile.supervisor.security_profile_id
  }
}

output "recordings_bucket_name" {
  value = aws_s3_bucket.recordings.id
}

output "recordings_bucket_arn" {
  value = aws_s3_bucket.recordings.arn
}

output "phone_number_id" {
  value = var.claim_phone_number ? aws_connect_phone_number.main[0].id : null
}

output "phone_number" {
  value = var.claim_phone_number ? aws_connect_phone_number.main[0].phone_number : null
}

output "flow_log_group_name" {
  value = aws_cloudwatch_log_group.flow_logs.name
}
