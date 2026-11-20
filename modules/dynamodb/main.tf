############################################
# customers    - pseudonymised customer profile keyed by a keyed hash of the phone number (tier, language, segment).
#                No name, address or identity number is stored.
# callbacks    - callback requests raised when the centre is closed or queues are full. Short TTL: the number is needed
#                only until the agent calls back.
# interactions - one summary row per contact (outcome, queue, sentiment bucket) with TTL, the analytics source.
# On-demand billing, encrypted at rest, private to this stack.
############################################

resource "aws_dynamodb_table" "customers" {
  name                        = "${var.name_prefix}-customers"
  billing_mode                = "PAY_PER_REQUEST"
  hash_key                    = "customer_key"
  deletion_protection_enabled = var.deletion_protection

  attribute {
    name = "customer_key"
    type = "S"
  }

  point_in_time_recovery {
    enabled = var.point_in_time_recovery
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = var.kms_key_arn
  }
}

resource "aws_dynamodb_table" "callbacks" {
  name                        = "${var.name_prefix}-callbacks"
  billing_mode                = "PAY_PER_REQUEST"
  hash_key                    = "callback_id"
  deletion_protection_enabled = var.deletion_protection

  attribute {
    name = "callback_id"
    type = "S"
  }

  ttl {
    attribute_name = "expires_at"
    enabled        = true
  }

  point_in_time_recovery {
    enabled = var.point_in_time_recovery
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = var.kms_key_arn
  }
}

resource "aws_dynamodb_table" "interactions" {
  name                        = "${var.name_prefix}-interactions"
  billing_mode                = "PAY_PER_REQUEST"
  hash_key                    = "day"
  range_key                   = "ts_id"
  deletion_protection_enabled = var.deletion_protection

  attribute {
    name = "day"
    type = "S"
  }

  attribute {
    name = "ts_id"
    type = "S"
  }

  ttl {
    attribute_name = "expires_at"
    enabled        = true
  }

  point_in_time_recovery {
    enabled = var.point_in_time_recovery
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = var.kms_key_arn
  }
}
