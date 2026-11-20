# ============================================================
# Landing Zone consumption (source of truth).
# This stack never creates VPCs, subnets, NAT, endpoints, KMS keys, the Route 53 zone, ACM certificates, the
# platform SNS topic, logging buckets, GuardDuty, Security Hub, flow logs, backup vaults, ECR repositories, state
# buckets or the GitHub OIDC provider. Everything below is READ from the Landing Zone's remote state.
# ============================================================

variable "landing_zone_state_bucket" {
  description = "S3 bucket holding the Landing Zone Terraform state (Landing Zone output: terraform_state.bucket)."
  type        = string
}

variable "landing_zone_state_key" {
  description = "S3 key of the Landing Zone Terraform state (Landing Zone output: terraform_state.key)."
  type        = string
}

variable "landing_zone_state_region" {
  description = "Region of the Landing Zone state bucket (Landing Zone output: terraform_state.region)."
  type        = string
}

variable "expected_landing_zone_contract_version" {
  description = "Landing Zone contract_schema_version this stack was written against."
  type        = string
  default     = "2"
}

data "terraform_remote_state" "landing_zone" {
  backend = "s3"

  config = {
    bucket  = var.landing_zone_state_bucket
    key     = var.landing_zone_state_key
    region  = var.landing_zone_state_region
    encrypt = true
  }
}

data "aws_caller_identity" "current" {}

locals {
  lz = data.terraform_remote_state.landing_zone.outputs

  account_id = data.aws_caller_identity.current.account_id

  name_prefix       = "${var.workload_name}-${var.environment}"
  metrics_namespace = "ContactCenter/${var.environment}"

  # ---- Governance perimeter ----
  organization_id = try(local.lz.organization_id, null)

  # ---- Alerts: the Landing Zone topic lives in af-south-1, the same Region as every alarm in this stack ----
  alert_topic_arn = try(local.lz.monitoring_topic_arn, null)

  # ---- Key strategy: aws-managed in every environment unless the Landing Zone switch is flipped ----
  key_strategy = try(local.lz.key_strategy, "aws-managed")
  use_cmk      = local.key_strategy != "aws-managed"
  # Recordings and transcripts use the Landing Zone shared S3 key, the tables use the shared analytics key.
  recordings_kms_arn = local.use_cmk ? try(local.lz.shared_kms_keys["s3"].arn, null) : null
  tables_kms_arn     = local.use_cmk ? try(local.lz.shared_kms_keys["analytics"].arn, null) : null

  # ---- Deployment identity: the OIDC provider already exists in the Landing Zone ----
  github_oidc_provider_arn = try(local.lz.github_oidc_provider_arn, null)
}

resource "terraform_data" "landing_zone_contract" {
  lifecycle {
    precondition {
      condition     = try(local.lz.contract_schema_version, "") == var.expected_landing_zone_contract_version
      error_message = "The Landing Zone contract_schema_version does not match expected_landing_zone_contract_version. Review the Landing Zone changelog before applying."
    }

    precondition {
      condition     = !local.use_cmk || (local.recordings_kms_arn != null && local.tables_kms_arn != null)
      error_message = "The Landing Zone uses customer managed keys but exports no shared_kms_keys.s3 or shared_kms_keys.analytics key."
    }

    precondition {
      condition     = var.github_repository == "" || local.github_oidc_provider_arn != null
      error_message = "github_repository is set but the Landing Zone exports no github_oidc_provider_arn."
    }
  }
}
