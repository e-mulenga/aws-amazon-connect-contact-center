output "bot_id" {
  value = awscc_lex_bot.this.bot_id
}

output "bot_alias_arn" {
  description = "ARN of the alias the contact flows call."
  value       = awscc_lex_bot_alias.live.arn
}

output "conversation_log_group" {
  value = var.conversation_logs ? aws_cloudwatch_log_group.conversation[0].name : null
}

output "intent_names" {
  value = keys(var.intents)
}
