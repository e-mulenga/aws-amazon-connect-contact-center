# ============================================================
# Shared posture: applied to dev, test AND prod by scripts/tf.sh.
# Only identity (names, Landing Zone state location) differs per environment.
# Cost rule: Connect bills per minute of voice and chat plus a monthly fee per claimed number; Lex bills per request;
# everything else is pay-per-request. Guards: queue capacity, concurrent-call alarm, recording expiry, no number claimed.
# ============================================================

primary_region = "af-south-1"

# Connect
contact_lens_enabled          = true
contact_flow_logs_enabled     = true
inbound_calls_enabled         = true
outbound_calls_enabled        = true
time_zone                     = "Africa/Johannesburg"
queue_max_contacts            = 25
chat_concurrency              = 3
enable_contact_lens_analytics = true
analytics_language            = "en-US"

# Lex
lex_locale_id                = "en_ZA"
lex_voice_id                 = "Ayanda"
lex_nlu_confidence_threshold = 0.75
lex_idle_session_ttl_seconds = 120
lex_conversation_logs        = false

# Data lifecycle
recordings_retention_days  = 90
callback_retention_days    = 7
interaction_retention_days = 365
noncurrent_expiry_days     = 7
force_destroy              = false

# Operations
log_retention_days             = 14
enable_alarms                  = true
enable_xray                    = true
lambda_architecture            = "arm64"
missed_calls_alarm_threshold   = 5
concurrent_calls_alarm_percent = 80

# A claimed number is billed monthly, so it stays off until needed
claim_phone_number = false
