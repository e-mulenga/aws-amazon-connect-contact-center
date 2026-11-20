output "connect_instance_id" {
  value = module.connect.instance_id
}

output "connect_instance_arn" {
  value = module.connect.instance_arn
}

output "connect_access_url" {
  description = "Sign-in URL of the Connect instance (create the first admin in the console, or use your identity provider)."
  value       = module.connect.access_url
}

output "inbound_flow_id" {
  value = module.contact_flows.inbound_flow_id
}

output "queue_ids" {
  value = module.connect.queue_ids
}

output "routing_profile_id" {
  value = module.connect.routing_profile_id
}

output "security_profile_ids" {
  value = module.connect.security_profile_ids
}

output "claimed_phone_number" {
  description = "Claimed number, or null when claim_phone_number is false."
  value       = module.connect.phone_number
}

output "lex_bot_alias_arn" {
  value = module.lex_bot.bot_alias_arn
}

output "recordings_bucket_name" {
  value = module.connect.recordings_bucket_name
}

output "function_names" {
  value = module.lambda.function_names
}

output "dynamodb_tables" {
  value = module.dynamodb.table_names
}

output "pseudonymisation_secret_arn" {
  description = "Secret that holds the HMAC key. Load customer rows with customer_key = HMAC-SHA256(key, E.164 number)."
  value       = aws_secretsmanager_secret.pseudonymisation.arn
}

output "dashboard_name" {
  value = var.enable_alarms ? module.monitoring[0].dashboard_name : null
}

output "github_deploy_roles" {
  description = "OIDC role ARNs for GitHub Actions (set as environment variables), or null."
  value       = var.github_repository == "" ? null : { plan = module.iam[0].plan_role_arn, apply = module.iam[0].apply_role_arn }
}

output "contact_flow_json" {
  value = module.contact_flows.contact_flow_json
}
