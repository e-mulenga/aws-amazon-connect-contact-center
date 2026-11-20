############################################
# Amazon Lex V2 self-service bot (Cape Town), published as a version and a "live" alias, then associated with the
# Connect instance. The aws provider has no resource for the alias or for the Lex V2 association, so those use awscc;
# the bot itself is created with awscc as well because the Cloud Control resource builds the locale (the aws provider
# resources never start a build).
############################################

data "aws_partition" "current" {}

locals {
  partition = data.aws_partition.current.partition
}

data "aws_iam_policy_document" "assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lexv2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "bot" {
  name               = "${var.name_prefix}-lex"
  assume_role_policy = data.aws_iam_policy_document.assume.json
}

resource "aws_cloudwatch_log_group" "conversation" {
  count = var.conversation_logs ? 1 : 0

  name              = "/aws/lex/${var.name_prefix}"
  retention_in_days = var.log_retention_days
}

data "aws_iam_policy_document" "bot" {
  statement {
    sid       = "SynthesizeSpeech"
    actions   = ["polly:SynthesizeSpeech"]
    resources = ["*"]
  }

  dynamic "statement" {
    for_each = var.conversation_logs ? [1] : []

    content {
      sid       = "WriteConversationLogs"
      actions   = ["logs:CreateLogStream", "logs:PutLogEvents"]
      resources = ["${aws_cloudwatch_log_group.conversation[0].arn}:*"]
    }
  }
}

resource "aws_iam_role_policy" "bot" {
  name   = "access"
  role   = aws_iam_role.bot.id
  policy = data.aws_iam_policy_document.bot.json
}

resource "awscc_lex_bot" "this" {
  name                        = var.name_prefix
  description                 = "Self-service bot for the contact centre."
  role_arn                    = aws_iam_role.bot.arn
  idle_session_ttl_in_seconds = var.idle_session_ttl_seconds
  auto_build_bot_locales      = true

  data_privacy = {
    child_directed = false
  }

  bot_locales = [{
    locale_id                = var.locale_id
    description              = "Self-service intents."
    nlu_confidence_threshold = var.nlu_confidence_threshold

    voice_settings = {
      voice_id = var.voice_id
      engine   = var.voice_engine
    }

    intents = [
      for name, i in var.intents :
      merge(
        {
          name              = name
          description       = i.description
          sample_utterances = [for u in i.utterances : { utterance = u }]
        },
        i.parent_intent_signature != null ? {
          parent_intent_signature = i.parent_intent_signature
        } : {}
      )
    ]
  }]

  lifecycle {
    ignore_changes = [
      bot_locales
    ]
  }
  depends_on = [aws_iam_role_policy.bot]
}

resource "awscc_lex_bot_version" "this" {
  bot_id      = awscc_lex_bot.this.bot_id
  description = "Published from Terraform."

  bot_version_locale_specification = [{
    locale_id = var.locale_id

    bot_version_locale_details = {
      source_bot_version = "DRAFT"
    }
  }]
}

resource "awscc_lex_bot_alias" "live" {
  bot_id         = awscc_lex_bot.this.bot_id
  bot_alias_name = "live"
  bot_version    = awscc_lex_bot_version.this.bot_version
  description    = "Alias the contact flows call."

  bot_alias_locale_settings = [{
    locale_id = var.locale_id

    bot_alias_locale_setting = {
      enabled = true
    }
  }]

  conversation_log_settings = var.conversation_logs ? {
    text_log_settings = [{
      enabled = true

      destination = {
        cloudwatch = {
          cloudwatch_log_group_arn = aws_cloudwatch_log_group.conversation[0].arn
          log_prefix               = "lex/"
        }
      }
    }]
  } : null
}

# Lets the Connect instance (and only it) call the alias.
resource "awscc_lex_resource_policy" "connect" {
  resource_arn = awscc_lex_bot_alias.live.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "ConnectInvokesBot"
      Effect    = "Allow"
      Principal = { Service = "connect.amazonaws.com" }
      Action    = ["lex:RecognizeText", "lex:StartConversation"]
      Resource  = awscc_lex_bot_alias.live.arn
      Condition = {
        StringEquals = { "AWS:SourceAccount" = var.account_id }
        ArnEquals    = { "AWS:SourceArn" = var.connect_instance_arn }
      }
    }]
  })
}

resource "awscc_connect_integration_association" "lex" {
  instance_id      = var.connect_instance_arn
  integration_type = "LEX_BOT"
  integration_arn  = awscc_lex_bot_alias.live.arn

  depends_on = [awscc_lex_resource_policy.connect]
}
