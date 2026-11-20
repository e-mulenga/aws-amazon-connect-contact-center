############################################
# aws-amazon-connect-contact-center: wiring of the modules.
# Landing Zone resources are consumed in landing_zone.tf; nothing here recreates them.
# Every service used here is offered in af-south-1, so no Ireland alias is needed (docs/regional-availability.md).
############################################

locals {
  instance_alias = coalesce(var.instance_alias, "${local.name_prefix}-${substr(sha256(local.account_id), 0, 6)}")
  bucket_suffix  = substr(sha256("${local.account_id}-${var.primary_region}"), 0, 8)

  queues = {
    general  = { description = "Standard customers.", priority = 2 }
    priority = { description = "Priority customers identified by the CRM lookup.", priority = 1 }
  }

  intents = {
    SpeakToAgent = {
      description = "Caller wants an agent."
      utterances  = ["agent", "speak to an agent", "I want to talk to a person", "representative", "operator", "put me through to someone"]
    }

    OpeningHours = {
      description = "Caller asks when the centre is open."
      utterances  = ["opening hours", "what time do you open", "when are you open", "are you open on Saturday", "what are your hours"]
    }

    RequestCallback = {
      description = "Caller wants a call back."
      utterances  = ["call me back", "I want a callback", "phone me later", "can someone call me", "request a call back"]
    }

    FallbackIntent = {
      description             = "Fallback intent."
      utterances              = []
      parent_intent_signature = "AMAZON.FallbackIntent"
    }
  }

  opening_hours_text = "We are open ${join(", ", [for d, h in var.business_hours : "${lower(d)} ${h.start} to ${h.end}"])}, South African time."
}

# ---- Pseudonymisation key: the CRM lookup hashes phone numbers with it, so the table holds no phone numbers ----
resource "random_password" "pseudonymisation" {
  length  = 48
  special = false
}

resource "aws_secretsmanager_secret" "pseudonymisation" {
  name                    = "${local.name_prefix}/pseudonymisation-key"
  description             = "HMAC key that turns phone numbers into customer keys."
  recovery_window_in_days = var.environment == "prod" ? 30 : 7
}

resource "aws_secretsmanager_secret_version" "pseudonymisation" {
  secret_id     = aws_secretsmanager_secret.pseudonymisation.id
  secret_string = random_password.pseudonymisation.result
}

# ---- Tables ----
module "dynamodb" {
  source = "./modules/dynamodb"

  name_prefix            = local.name_prefix
  kms_key_arn            = local.tables_kms_arn
  point_in_time_recovery = var.environment != "dev"
  deletion_protection    = var.environment == "prod"

  depends_on = [terraform_data.landing_zone_contract]
}

# ---- Lambda functions called by the flow ----
module "lambda" {
  source = "./modules/lambda"

  name_prefix        = local.name_prefix
  architecture       = var.lambda_architecture
  log_retention_days = var.log_retention_days
  enable_xray        = var.enable_xray

  functions = {
    crm-lookup = {
      description = "CRM lookup by keyed hash of the caller number; returns tier and language."
      files = {
        "handler.py" = "${path.root}/lambda/crm_lookup/handler.py"
        "emf.py"     = "${path.root}/lambda/shared/emf.py"
      }
      environment = {
        CUSTOMERS_TABLE             = module.dynamodb.table_names["customers"]
        INTERACTIONS_TABLE          = module.dynamodb.table_names["interactions"]
        INTERACTION_RETENTION_DAYS  = tostring(var.interaction_retention_days)
        PSEUDONYMISATION_SECRET_ARN = aws_secretsmanager_secret.pseudonymisation.arn
        METRICS_NAMESPACE           = local.metrics_namespace
      }
      statements = concat(
        [
          { sid = "ReadCustomers", actions = ["dynamodb:GetItem"], resources = [module.dynamodb.table_arns["customers"]] },
          { sid = "WriteInteractions", actions = ["dynamodb:PutItem"], resources = [module.dynamodb.table_arns["interactions"]] },
          { sid = "ReadKey", actions = ["secretsmanager:GetSecretValue"], resources = [aws_secretsmanager_secret.pseudonymisation.arn] },
        ],
        local.tables_kms_arn == null ? [] : [{ sid = "TableKey", actions = ["kms:Decrypt", "kms:GenerateDataKey"], resources = [local.tables_kms_arn] }],
      )
    }
    callback = {
      description = "Stores a callback request with a short expiry."
      files = {
        "handler.py" = "${path.root}/lambda/callback/handler.py"
        "emf.py"     = "${path.root}/lambda/shared/emf.py"
      }
      environment = {
        CALLBACKS_TABLE         = module.dynamodb.table_names["callbacks"]
        CALLBACK_RETENTION_DAYS = tostring(var.callback_retention_days)
        METRICS_NAMESPACE       = local.metrics_namespace
      }
      statements = concat(
        [{ sid = "WriteCallbacks", actions = ["dynamodb:PutItem"], resources = [module.dynamodb.table_arns["callbacks"]] }],
        local.tables_kms_arn == null ? [] : [{ sid = "TableKey", actions = ["kms:Decrypt", "kms:GenerateDataKey"], resources = [local.tables_kms_arn] }],
      )
    }
  }
}

# ---- Connect instance, storage, hours, queues, routing and security profiles ----
module "connect" {
  source = "./modules/connect"

  name_prefix               = local.name_prefix
  account_id                = local.account_id
  instance_alias            = local.instance_alias
  bucket_suffix             = local.bucket_suffix
  contact_lens_enabled      = var.contact_lens_enabled
  contact_flow_logs_enabled = var.contact_flow_logs_enabled
  inbound_calls_enabled     = var.inbound_calls_enabled
  outbound_calls_enabled    = var.outbound_calls_enabled
  kms_key_arn               = local.recordings_kms_arn
  time_zone                 = var.time_zone
  business_hours            = var.business_hours
  queue_max_contacts        = var.queue_max_contacts
  voice_concurrency         = var.voice_concurrency
  chat_concurrency          = var.chat_concurrency
  queues                    = local.queues
  recordings_retention_days = var.recordings_retention_days
  noncurrent_expiry_days    = var.noncurrent_expiry_days
  force_destroy             = var.force_destroy
  claim_phone_number        = var.claim_phone_number
  phone_number_country_code = var.phone_number_country_code
  phone_number_type         = var.phone_number_type
  log_retention_days        = var.log_retention_days

  depends_on = [terraform_data.landing_zone_contract]
}

# ---- Lex V2 self-service bot ----
module "lex_bot" {
  source = "./modules/lex-bot"

  name_prefix              = local.name_prefix
  account_id               = local.account_id
  connect_instance_arn     = module.connect.instance_arn
  connect_instance_id      = module.connect.instance_id
  locale_id                = var.lex_locale_id
  voice_id                 = var.lex_voice_id
  nlu_confidence_threshold = var.lex_nlu_confidence_threshold
  idle_session_ttl_seconds = var.lex_idle_session_ttl_seconds
  conversation_logs        = var.lex_conversation_logs
  log_retention_days       = var.log_retention_days
  intents                  = local.intents
}

# ---- Inbound contact flow ----
module "contact_flows" {
  source = "./modules/contact-flows"

  name_prefix        = local.name_prefix
  account_id         = local.account_id
  instance_id        = module.connect.instance_id
  instance_arn       = module.connect.instance_arn
  queue_arns         = module.connect.queue_arns
  lex_alias_arn      = module.lex_bot.bot_alias_arn
  lambda_arns        = { crm_lookup = module.lambda.function_arns["crm-lookup"], callback = module.lambda.function_arns["callback"] }
  lambda_names       = { crm_lookup = module.lambda.function_names["crm-lookup"], callback = module.lambda.function_names["callback"] }
  enable_analytics   = var.enable_contact_lens_analytics
  analytics_language = var.analytics_language
  opening_hours_text = local.opening_hours_text
  phone_number_id    = module.connect.phone_number_id

  # The flow can only reference the bot once Connect knows about it.
  depends_on = [module.lex_bot]
}

# ---- Monitoring in af-south-1 (notifies the Landing Zone alert topic) ----
locals {
  voice_dims = { InstanceId = module.connect.instance_id, MetricGroup = "VoiceCalls" }

  dashboard_widgets = [
    {
      type = "metric", x = 0, y = 0, width = 12, height = 6
      properties = {
        title  = "Calls"
        region = var.primary_region
        stat   = "Sum"
        period = 300
        metrics = [
          ["AWS/Connect", "CallsPerInterval", "InstanceId", module.connect.instance_id, "MetricGroup", "VoiceCalls"],
          ["AWS/Connect", "MissedCalls", "InstanceId", module.connect.instance_id, "MetricGroup", "VoiceCalls"],
          ["AWS/Connect", "ThrottledCalls", "InstanceId", module.connect.instance_id, "MetricGroup", "VoiceCalls"],
        ]
      }
    },
    {
      type = "metric", x = 12, y = 0, width = 12, height = 6
      properties = {
        title  = "Concurrent calls (percent of quota)"
        region = var.primary_region
        stat   = "Maximum"
        period = 300
        metrics = [
          ["AWS/Connect", "ConcurrentCallsPercentage", "InstanceId", module.connect.instance_id, "MetricGroup", "VoiceCalls"],
        ]
      }
    },
    {
      type = "metric", x = 0, y = 6, width = 12, height = 6
      properties = {
        title  = "Lambda invocations and errors"
        region = var.primary_region
        stat   = "Sum"
        period = 300
        metrics = concat(
          [for n in values(module.lambda.function_names) : ["AWS/Lambda", "Invocations", "FunctionName", n]],
          [for n in values(module.lambda.function_names) : ["AWS/Lambda", "Errors", "FunctionName", n]],
        )
      }
    },
    {
      type = "metric", x = 12, y = 6, width = 12, height = 6
      properties = {
        title  = "CRM lookups and callbacks"
        region = var.primary_region
        stat   = "Sum"
        period = 300
        metrics = [
          [local.metrics_namespace, "CrmHit", "Service", "crm_lookup"],
          [local.metrics_namespace, "CrmMiss", "Service", "crm_lookup"],
          [local.metrics_namespace, "CrmError", "Service", "crm_lookup"],
          [local.metrics_namespace, "CallbacksQueued", "Service", "callback"],
          [local.metrics_namespace, "CallbacksRejected", "Service", "callback"],
        ]
      }
    },
  ]
}

module "monitoring" {
  count  = var.enable_alarms ? 1 : 0
  source = "./modules/monitoring"

  name_prefix = local.name_prefix
  topic_arn   = local.alert_topic_arn

  alarms = merge(
    {
      missed-calls = {
        description = "Calls were missed (abandoned before an agent answered or Connect could route them)."
        namespace   = "AWS/Connect"
        metric_name = "MissedCalls"
        dimensions  = local.voice_dims
        period      = 900
        threshold   = var.missed_calls_alarm_threshold
      }
      concurrent-calls-high = {
        description = "Concurrent calls are close to the instance quota."
        namespace   = "AWS/Connect"
        metric_name = "ConcurrentCallsPercentage"
        dimensions  = local.voice_dims
        statistic   = "Maximum"
        threshold   = var.concurrent_calls_alarm_percent
      }
      throttled-calls = {
        description = "Calls were throttled because the concurrent call quota was reached."
        namespace   = "AWS/Connect"
        metric_name = "ThrottledCalls"
        dimensions  = local.voice_dims
        threshold   = 1
      }
      crm-lookup-slow = {
        description        = "CRM lookup p95 is above 2.5 seconds; the flow gives up after 4."
        namespace          = "AWS/Lambda"
        metric_name        = "Duration"
        dimensions         = { FunctionName = module.lambda.function_names["crm-lookup"] }
        extended_statistic = "p95"
        threshold          = 2500
        evaluation_periods = 2
      }
      customers-read-throttles = {
        description = "Reads on the customers table were throttled."
        namespace   = "AWS/DynamoDB"
        metric_name = "ReadThrottleEvents"
        dimensions  = { TableName = module.dynamodb.table_names["customers"] }
        threshold   = 1
      }
      callbacks-write-throttles = {
        description = "Writes on the callbacks table were throttled."
        namespace   = "AWS/DynamoDB"
        metric_name = "WriteThrottleEvents"
        dimensions  = { TableName = module.dynamodb.table_names["callbacks"] }
        threshold   = 1
      }
    },
    {
      callback-lambda-errors = {
        description = "The callback Lambda is failing."
        namespace   = "AWS/Lambda"
        metric_name = "Errors"
        dimensions = {
          FunctionName = "${local.name_prefix}-callback"
        }
        threshold = 3
      }
    }
  )

  log_metric_filters = var.contact_flow_logs_enabled ? {
    flow-errors = {
      log_group_name = module.connect.flow_log_group_name
      pattern        = "\"Error\""
      metric_name    = "ContactFlowErrors"
      namespace      = local.metrics_namespace
    }
  } : {}

  log_queries = {
    lambda-errors = {
      log_group_names = [for n in values(module.lambda.log_group_names) : n]
      query           = "fields @timestamp, @log, @message | filter @message like /error|ERROR|Traceback|failed/ | sort @timestamp desc | limit 100"
    }
  }

  dashboard_widgets = local.dashboard_widgets
}

# ---- GitHub Actions OIDC deployment roles (the OIDC provider is a Landing Zone resource) ----
module "iam" {
  count  = var.github_repository == "" ? 0 : 1
  source = "./modules/iam"

  name_prefix       = local.name_prefix
  oidc_provider_arn = local.github_oidc_provider_arn
  github_repository = var.github_repository
  environment       = var.environment
  state_bucket      = var.landing_zone_state_bucket
  state_key_prefix  = "aws-amazon-connect-contact-center/"
}
