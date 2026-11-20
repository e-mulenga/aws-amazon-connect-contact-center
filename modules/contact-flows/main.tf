############################################
# Inbound voice flow:
#   record + analytics -> greet -> CRM lookup (Lambda) -> pick queue by tier -> opening hours?
#     open   -> Lex self-service -> agent | opening hours | callback | anything else goes to an agent
#     closed -> callback offered (Lambda) -> goodbye
#   queue full -> callback offered
# The flow JSON is built in Terraform so the Lambda, Lex and queue ARNs are always the ones this stack created.
############################################

locals {
  analytics = var.enable_analytics ? {
    AnalyticsBehavior = {
      Enabled                    = "True"
      AnalyticsLanguage          = var.analytics_language
      AnalyticsRedactionBehavior = "Enable"
      AnalyticsRedactionResults  = "RedactedOnly"
      ChannelConfiguration = {
        Voice = { AnalyticsModes = ["PostContact"] }
      }
      SentimentConfiguration = { Enabled = "True" }
    }
  } : {}

  err_any = { ErrorType = "NoMatchingError" }

  actions = {
    logging = {
      Identifier  = "logging"
      Type        = "UpdateFlowLoggingBehavior"
      Parameters  = { FlowLoggingBehavior = "Enabled" }
      Transitions = { NextAction = "recording", Errors = [], Conditions = [] }
    }
    recording = {
      Identifier = "recording"
      Type       = "UpdateContactRecordingBehavior"
      Parameters = merge(
        { RecordingBehavior = { RecordedParticipants = ["Agent", "Customer"] } },
        local.analytics,
      )
      Transitions = { NextAction = "greeting", Errors = [], Conditions = [] }
    }
    greeting = {
      Identifier = "greeting"
      Type       = "MessageParticipant"
      Parameters = { Text = "Thank you for calling. Your call may be recorded for quality and training." }
      Transitions = {
        NextAction = "crm_lookup"
        Errors     = [merge(local.err_any, { NextAction = "crm_lookup" })]
        Conditions = []
      }
    }
    crm_lookup = {
      Identifier = "crm_lookup"
      Type       = "InvokeLambdaFunction"
      Parameters = {
        LambdaFunctionARN          = var.lambda_arns["crm_lookup"]
        InvocationTimeLimitSeconds = "4"
        InvocationType             = "SYNCHRONOUS"
        ResponseValidation         = { ResponseType = "STRING_MAP" }
      }
      Transitions = {
        NextAction = "tier_check"
        Errors     = [merge(local.err_any, { NextAction = "set_general_queue" })]
        Conditions = []
      }
    }
    tier_check = {
      Identifier = "tier_check"
      Type       = "Compare"
      Parameters = { ComparisonValue = "$.External.customer_tier" }
      Transitions = {
        NextAction = "set_general_queue"
        Errors     = [{ ErrorType = "NoMatchingCondition", NextAction = "set_general_queue" }]
        Conditions = [{
          NextAction = "set_priority_queue"
          Condition  = { Operator = "Equals", Operands = ["priority"] }
        }]
      }
    }
    set_general_queue = {
      Identifier = "set_general_queue"
      Type       = "UpdateContactTargetQueue"
      Parameters = { QueueId = var.queue_arns["general"] }
      Transitions = {
        NextAction = "check_hours"
        Errors     = [merge(local.err_any, { NextAction = "disconnect" })]
        Conditions = []
      }
    }
    set_priority_queue = {
      Identifier = "set_priority_queue"
      Type       = "UpdateContactTargetQueue"
      Parameters = { QueueId = var.queue_arns["priority"] }
      Transitions = {
        NextAction = "check_hours"
        Errors     = [merge(local.err_any, { NextAction = "disconnect" })]
        Conditions = []
      }
    }
    check_hours = {
      Identifier = "check_hours"
      Type       = "CheckHoursOfOperation"
      Parameters = {}
      Transitions = {
        NextAction = "closed_message"
        Errors     = [merge(local.err_any, { NextAction = "closed_message" })]
        Conditions = [
          { NextAction = "self_service", Condition = { Operator = "Equals", Operands = ["True"] } },
          { NextAction = "closed_message", Condition = { Operator = "Equals", Operands = ["False"] } },
        ]
      }
    }
    self_service = {
      Identifier = "self_service"
      Type       = "ConnectParticipantWithLexBot"
      Parameters = {
        Text     = "How can I help you today? You can ask for an agent, our opening hours, or a call back."
        LexV2Bot = { AliasArn = var.lex_alias_arn }
      }
      Transitions = {
        NextAction = "to_queue"
        Errors = [
          { ErrorType = "NoMatchingCondition", NextAction = "to_queue" },
          merge(local.err_any, { NextAction = "to_queue" }),
        ]
        Conditions = [
          { NextAction = "to_queue", Condition = { Operator = "Equals", Operands = ["SpeakToAgent"] } },
          { NextAction = "hours_message", Condition = { Operator = "Equals", Operands = ["OpeningHours"] } },
          { NextAction = "request_callback", Condition = { Operator = "Equals", Operands = ["RequestCallback"] } },
        ]
      }
    }
    hours_message = {
      Identifier = "hours_message"
      Type       = "MessageParticipant"
      Parameters = { Text = var.opening_hours_text }
      Transitions = {
        NextAction = "self_service"
        Errors     = [merge(local.err_any, { NextAction = "self_service" })]
        Conditions = []
      }
    }
    to_queue = {
      Identifier = "to_queue"
      Type       = "TransferContactToQueue"
      Parameters = {}
      Transitions = {
        NextAction = "disconnect"
        Errors = [
          { ErrorType = "QueueAtCapacity", NextAction = "full_message" },
          merge(local.err_any, { NextAction = "disconnect" }),
        ]
        Conditions = []
      }
    }
    full_message = {
      Identifier = "full_message"
      Type       = "MessageParticipant"
      Parameters = { Text = "All of our agents are busy. We will note a call back for you." }
      Transitions = {
        NextAction = "request_callback"
        Errors     = [merge(local.err_any, { NextAction = "request_callback" })]
        Conditions = []
      }
    }
    closed_message = {
      Identifier = "closed_message"
      Type       = "MessageParticipant"
      Parameters = { Text = "We are closed at the moment. ${var.opening_hours_text} We will note a call back for you." }
      Transitions = {
        NextAction = "request_callback"
        Errors     = [merge(local.err_any, { NextAction = "request_callback" })]
        Conditions = []
      }
    }
    request_callback = {
      Identifier = "request_callback"
      Type       = "InvokeLambdaFunction"
      Parameters = {
        LambdaFunctionARN          = var.lambda_arns["callback"]
        InvocationTimeLimitSeconds = "4"
        InvocationType             = "SYNCHRONOUS"
        ResponseValidation         = { ResponseType = "STRING_MAP" }
      }
      Transitions = {
        NextAction = "callback_check"
        Errors     = [merge(local.err_any, { NextAction = "callback_failed" })]
        Conditions = []
      }
    }
    callback_check = {
      Identifier = "callback_check"
      Type       = "Compare"
      Parameters = { ComparisonValue = "$.External.callback_status" }
      Transitions = {
        NextAction = "callback_failed"
        Errors     = [{ ErrorType = "NoMatchingCondition", NextAction = "callback_failed" }]
        Conditions = [{
          NextAction = "callback_noted"
          Condition  = { Operator = "Equals", Operands = ["queued"] }
        }]
      }
    }
    callback_noted = {
      Identifier = "callback_noted"
      Type       = "MessageParticipant"
      Parameters = { Text = "Thank you. We have noted your call back request and an agent will phone you. Goodbye." }
      Transitions = {
        NextAction = "disconnect"
        Errors     = [merge(local.err_any, { NextAction = "disconnect" })]
        Conditions = []
      }
    }
    callback_failed = {
      Identifier = "callback_failed"
      Type       = "MessageParticipant"
      Parameters = { Text = "We could not note your request. Please call again during opening hours. Goodbye." }
      Transitions = {
        NextAction = "disconnect"
        Errors     = [merge(local.err_any, { NextAction = "disconnect" })]
        Conditions = []
      }
    }
    disconnect = {
      Identifier  = "disconnect"
      Type        = "DisconnectParticipant"
      Parameters  = {}
      Transitions = {}
    }
  }
}

# Connect calls the functions with its own service principal, limited to this account and this instance.
resource "aws_lambda_permission" "connect" {
  for_each = var.lambda_names

  statement_id   = "AllowConnectInvoke"
  action         = "lambda:InvokeFunction"
  function_name  = each.value
  principal      = "connect.amazonaws.com"
  source_account = var.account_id
  source_arn     = var.instance_arn
}

resource "aws_connect_lambda_function_association" "this" {
  for_each = var.lambda_arns

  instance_id  = var.instance_id
  function_arn = each.value

  depends_on = [aws_lambda_permission.connect]
}

resource "aws_connect_contact_flow" "inbound" {
  instance_id = var.instance_id
  name        = "${var.name_prefix}-inbound"
  description = "Inbound voice: CRM lookup, hours check, Lex self-service, queue or callback."
  type        = "CONTACT_FLOW"

  content = jsonencode({
    Version     = "2019-10-30"
    StartAction = "logging"
    Actions     = values(local.actions)
  })

  depends_on = [aws_connect_lambda_function_association.this]
}

resource "aws_connect_phone_number_contact_flow_association" "main" {
  count = var.phone_number_id == null ? 0 : 1

  instance_id     = var.instance_id
  phone_number_id = var.phone_number_id
  contact_flow_id = aws_connect_contact_flow.inbound.contact_flow_id
}
