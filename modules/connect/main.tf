############################################
# Amazon Connect instance, its private recordings bucket, opening hours, queues, a routing profile and security profiles.
# Agents are not created here: a user needs a password or an identity provider, and neither belongs in Terraform state.
############################################

data "aws_partition" "current" {}

locals {
  partition = data.aws_partition.current.partition
}

# Connect writes contact flow logs to /aws/connect/<alias>. The group is created here first so its retention is controlled.
resource "aws_cloudwatch_log_group" "flow_logs" {
  name              = "/aws/connect/${var.instance_alias}"
  retention_in_days = var.log_retention_days
}

resource "aws_connect_instance" "this" {
  identity_management_type         = "CONNECT_MANAGED"
  instance_alias                   = var.instance_alias
  inbound_calls_enabled            = var.inbound_calls_enabled
  outbound_calls_enabled           = var.outbound_calls_enabled
  contact_lens_enabled             = var.contact_lens_enabled
  contact_flow_logs_enabled        = var.contact_flow_logs_enabled
  auto_resolve_best_voices_enabled = true
  early_media_enabled              = var.outbound_calls_enabled

  depends_on = [aws_cloudwatch_log_group.flow_logs]
}

# ---- Recordings and transcripts: private, encrypted, versioned, expiring ----
# The name starts with amazon-connect- so the Connect service-linked role is allowed to use it by default.
resource "aws_s3_bucket" "recordings" {
  bucket        = "amazon-connect-${var.name_prefix}-${var.bucket_suffix}"
  force_destroy = var.force_destroy
}

resource "aws_s3_bucket_public_access_block" "recordings" {
  bucket                  = aws_s3_bucket.recordings.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "recordings" {
  bucket = aws_s3_bucket.recordings.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_versioning" "recordings" {
  bucket = aws_s3_bucket.recordings.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "recordings" {
  bucket = aws_s3_bucket.recordings.id

  rule {
    bucket_key_enabled = var.kms_key_arn != null

    apply_server_side_encryption_by_default {
      sse_algorithm     = var.kms_key_arn == null ? "AES256" : "aws:kms"
      kms_master_key_id = var.kms_key_arn
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "recordings" {
  bucket = aws_s3_bucket.recordings.id

  rule {
    id     = "expire-recordings"
    status = "Enabled"

    filter {}

    expiration {
      days = var.recordings_retention_days
    }

    noncurrent_version_expiration {
      noncurrent_days = var.noncurrent_expiry_days
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

data "aws_iam_policy_document" "recordings" {
  statement {
    sid       = "DenyInsecureTransport"
    effect    = "Deny"
    actions   = ["s3:*"]
    resources = [aws_s3_bucket.recordings.arn, "${aws_s3_bucket.recordings.arn}/*"]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }

  statement {
    sid       = "ConnectWritesRecordings"
    actions   = ["s3:PutObject", "s3:GetObject", "s3:GetBucketAcl", "s3:GetBucketLocation", "s3:ListBucket"]
    resources = [aws_s3_bucket.recordings.arn, "${aws_s3_bucket.recordings.arn}/*"]

    principals {
      type        = "Service"
      identifiers = ["connect.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [var.account_id]
    }

    condition {
      test     = "ArnEquals"
      variable = "aws:SourceArn"
      values   = [aws_connect_instance.this.arn]
    }
  }
}

resource "aws_s3_bucket_policy" "recordings" {
  bucket = aws_s3_bucket.recordings.id
  policy = data.aws_iam_policy_document.recordings.json

  depends_on = [aws_s3_bucket_public_access_block.recordings]
}

resource "aws_connect_instance_storage_config" "call_recordings" {
  instance_id   = aws_connect_instance.this.id
  resource_type = "CALL_RECORDINGS"

  storage_config {
    storage_type = "S3"

    s3_config {
      bucket_name   = aws_s3_bucket.recordings.id
      bucket_prefix = "connect/call-recordings"

      dynamic "encryption_config" {
        for_each = var.kms_key_arn == null ? [] : [var.kms_key_arn]

        content {
          encryption_type = "KMS"
          key_id          = encryption_config.value
        }
      }
    }
  }

  depends_on = [aws_s3_bucket_policy.recordings]
}

resource "aws_connect_instance_storage_config" "chat_transcripts" {
  instance_id   = aws_connect_instance.this.id
  resource_type = "CHAT_TRANSCRIPTS"

  storage_config {
    storage_type = "S3"

    s3_config {
      bucket_name   = aws_s3_bucket.recordings.id
      bucket_prefix = "connect/chat-transcripts"

      dynamic "encryption_config" {
        for_each = var.kms_key_arn == null ? [] : [var.kms_key_arn]

        content {
          encryption_type = "KMS"
          key_id          = encryption_config.value
        }
      }
    }
  }

  depends_on = [aws_s3_bucket_policy.recordings]
}

# ---- Opening hours ----
resource "aws_connect_hours_of_operation" "business" {
  instance_id = aws_connect_instance.this.id
  name        = "${var.name_prefix}-business-hours"
  description = "Standard opening hours."
  time_zone   = var.time_zone

  dynamic "config" {
    for_each = var.business_hours

    content {
      day = config.key

      start_time {
        hours   = tonumber(split(":", config.value.start)[0])
        minutes = tonumber(split(":", config.value.start)[1])
      }

      end_time {
        hours   = tonumber(split(":", config.value.end)[0])
        minutes = tonumber(split(":", config.value.end)[1])
      }
    }
  }
}

# ---- Queues ----
resource "aws_connect_queue" "this" {
  for_each = var.queues

  instance_id           = aws_connect_instance.this.id
  name                  = "${var.name_prefix}-${each.key}"
  description           = each.value.description
  hours_of_operation_id = aws_connect_hours_of_operation.business.hours_of_operation_id
  max_contacts          = var.queue_max_contacts

  outbound_caller_config {
    outbound_caller_id_name = "Contact centre"
  }
}

# ---- Routing profile: voice and chat for every queue, priority from the queue definition ----
resource "aws_connect_routing_profile" "standard" {
  instance_id               = aws_connect_instance.this.id
  name                      = "${var.name_prefix}-standard"
  description               = "Voice and chat agents working every queue."
  default_outbound_queue_id = aws_connect_queue.this["general"].queue_id

  media_concurrencies {
    channel     = "VOICE"
    concurrency = var.voice_concurrency
  }

  media_concurrencies {
    channel     = "CHAT"
    concurrency = var.chat_concurrency
  }

  dynamic "queue_configs" {
    for_each = { for pair in setproduct(keys(var.queues), ["VOICE", "CHAT"]) : "${pair[0]}-${pair[1]}" => pair }

    content {
      channel  = queue_configs.value[1]
      delay    = 0
      priority = var.queues[queue_configs.value[0]].priority
      queue_id = aws_connect_queue.this[queue_configs.value[0]].queue_id
    }
  }
}

# ---- Security profiles (least privilege) ----
resource "aws_connect_security_profile" "agent" {
  instance_id = aws_connect_instance.this.id
  name        = "${var.name_prefix}-agent"
  description = "Agents: control panel and outbound calls only."
  permissions = ["BasicAgentAccess", "OutboundCallAccess"]
}

resource "aws_connect_security_profile" "supervisor" {
  instance_id = aws_connect_instance.this.id
  name        = "${var.name_prefix}-supervisor"
  description = "Supervisors: agent access plus metrics."
  permissions = ["BasicAgentAccess", "OutboundCallAccess", "AccessMetrics"]
}

# ---- Optional claimed number ----
resource "aws_connect_phone_number" "main" {
  count = var.claim_phone_number ? 1 : 0

  target_arn   = aws_connect_instance.this.arn
  country_code = var.phone_number_country_code
  type         = var.phone_number_type
  description  = "Main inbound number."
}
