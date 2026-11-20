output "inbound_flow_id" {
  value = aws_connect_contact_flow.inbound.contact_flow_id
}

output "inbound_flow_arn" {
  value = aws_connect_contact_flow.inbound.arn
}

output "contact_flow_json" {
  value = jsonencode({
    Version     = "2019-10-30"
    StartAction = "logging"
    Actions     = values(local.actions)
  })
}
