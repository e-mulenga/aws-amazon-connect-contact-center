############################################
# Lambda functions called by the contact flows. One role per function, least privilege, a log group per function with a
# retention period, and no VPC attachment (the functions only call DynamoDB and Secrets Manager).
############################################

data "archive_file" "this" {
  for_each = var.functions

  type        = "zip"
  output_path = "${path.root}/.build/${each.key}.zip"

  dynamic "source" {
    for_each = each.value.files

    content {
      filename = source.key
      content  = file(source.value)
    }
  }
}

resource "aws_cloudwatch_log_group" "this" {
  for_each = var.functions

  name              = "/aws/lambda/${var.name_prefix}-${each.key}"
  retention_in_days = var.log_retention_days
}

data "aws_iam_policy_document" "assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "this" {
  for_each = var.functions

  name               = "${var.name_prefix}-${each.key}"
  assume_role_policy = data.aws_iam_policy_document.assume.json
}

data "aws_iam_policy_document" "inline" {
  for_each = var.functions

  statement {
    sid       = "WriteOwnLogs"
    actions   = ["logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["${aws_cloudwatch_log_group.this[each.key].arn}:*"]
  }

  dynamic "statement" {
    for_each = var.enable_xray ? [1] : []

    content {
      sid       = "XRay"
      actions   = ["xray:PutTraceSegments", "xray:PutTelemetryRecords"]
      resources = ["*"]
    }
  }

  dynamic "statement" {
    for_each = each.value.statements

    content {
      sid       = statement.value.sid
      actions   = statement.value.actions
      resources = statement.value.resources
    }
  }
}

resource "aws_iam_role_policy" "this" {
  for_each = var.functions

  name   = "access"
  role   = aws_iam_role.this[each.key].id
  policy = data.aws_iam_policy_document.inline[each.key].json
}

resource "aws_lambda_function" "this" {
  for_each = var.functions

  function_name    = "${var.name_prefix}-${each.key}"
  description      = each.value.description
  role             = aws_iam_role.this[each.key].arn
  runtime          = "python3.12"
  handler          = each.value.handler
  architectures    = [var.architecture]
  timeout          = each.value.timeout
  memory_size      = each.value.memory_size
  filename         = data.archive_file.this[each.key].output_path
  source_code_hash = data.archive_file.this[each.key].output_base64sha256
  kms_key_arn      = var.kms_key_arn

  environment {
    variables = each.value.environment
  }

  tracing_config {
    mode = var.enable_xray ? "Active" : "PassThrough"
  }

  depends_on = [aws_cloudwatch_log_group.this, aws_iam_role_policy.this]
}
