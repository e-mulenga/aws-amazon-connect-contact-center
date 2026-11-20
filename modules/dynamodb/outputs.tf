output "table_names" {
  value = {
    customers    = aws_dynamodb_table.customers.name
    callbacks    = aws_dynamodb_table.callbacks.name
    interactions = aws_dynamodb_table.interactions.name
  }
}

output "table_arns" {
  value = {
    customers    = aws_dynamodb_table.customers.arn
    callbacks    = aws_dynamodb_table.callbacks.arn
    interactions = aws_dynamodb_table.interactions.arn
  }
}
