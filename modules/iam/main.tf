############################################
# GitHub Actions OIDC deployment roles. The OIDC identity provider belongs to the Landing Zone and is only referenced.
#   plan  - assumed by pull requests: read-only on AWS, read/write on this repository's state objects (the lock file)
#   apply - assumed by the protected environment (or main): deploys the stack
# No long-lived access keys exist anywhere.
############################################

data "aws_partition" "current" {}

locals {
  partition = data.aws_partition.current.partition
  repo      = var.github_repository
  provider  = replace(var.oidc_provider_arn, "/^arn:[^:]+:iam::[0-9]+:oidc-provider\\//", "")
}

data "aws_iam_policy_document" "trust_plan" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.provider}:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.provider}:sub"
      values   = ["repo:${local.repo}:pull_request"]
    }
  }
}

data "aws_iam_policy_document" "trust_apply" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.provider}:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.provider}:sub"
      values   = ["repo:${local.repo}:environment:${var.environment}", "repo:${local.repo}:${var.apply_ref}"]
    }
  }
}

data "aws_iam_policy_document" "state" {
  statement {
    sid       = "ListStateBucket"
    actions   = ["s3:ListBucket"]
    resources = ["arn:${local.partition}:s3:::${var.state_bucket}"]

    condition {
      test     = "StringLike"
      variable = "s3:prefix"
      values   = ["${var.state_key_prefix}*", "landing-zone/*"]
    }
  }

  statement {
    sid       = "ThisStackState"
    actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = ["arn:${local.partition}:s3:::${var.state_bucket}/${var.state_key_prefix}*"]
  }

  # terraform_remote_state reads the Landing Zone state; read only.
  statement {
    sid       = "ReadLandingZoneState"
    actions   = ["s3:GetObject"]
    resources = ["arn:${local.partition}:s3:::${var.state_bucket}/landing-zone/*"]
  }

  dynamic "statement" {
    for_each = var.state_kms_key_arn == null ? [] : [var.state_kms_key_arn]

    content {
      sid       = "StateKey"
      actions   = ["kms:Decrypt", "kms:GenerateDataKey", "kms:DescribeKey"]
      resources = [statement.value]
    }
  }
}

# The apply role may manage IAM only for roles and policies of this workload (name prefix), never account-level IAM.
data "aws_iam_policy_document" "apply_iam" {
  statement {
    sid = "ManageWorkloadRoles"
    actions = [
      "iam:CreateRole", "iam:DeleteRole", "iam:GetRole", "iam:UpdateRole", "iam:TagRole", "iam:UntagRole",
      "iam:PutRolePolicy", "iam:DeleteRolePolicy", "iam:GetRolePolicy", "iam:ListRolePolicies",
      "iam:AttachRolePolicy", "iam:DetachRolePolicy", "iam:ListAttachedRolePolicies", "iam:ListInstanceProfilesForRole",
      "iam:UpdateAssumeRolePolicy", "iam:PassRole", "iam:CreatePolicy", "iam:DeletePolicy", "iam:GetPolicy",
      "iam:GetPolicyVersion", "iam:ListPolicyVersions", "iam:CreatePolicyVersion", "iam:DeletePolicyVersion",
    ]
    resources = [
      "arn:${local.partition}:iam::*:role/${var.name_prefix}-*",
      "arn:${local.partition}:iam::*:policy/${var.name_prefix}-*",
    ]
  }

  statement {
    sid       = "PassRoleOnlyToServices"
    actions   = ["iam:PassRole"]
    resources = ["arn:${local.partition}:iam::*:role/${var.name_prefix}-*"]

    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["lambda.amazonaws.com", "lexv2.amazonaws.com"]
    }
  }
}

# Amazon Connect creates its service-linked role the first time an instance is created in the account. The Landing Zone does
# not create it, so the apply role may create only that role.
data "aws_iam_policy_document" "apply_connect_slr" {
  statement {
    sid       = "CreateConnectServiceLinkedRole"
    actions   = ["iam:CreateServiceLinkedRole"]
    resources = ["arn:${local.partition}:iam::*:role/aws-service-role/connect.amazonaws.com/AWSServiceRoleForAmazonConnect*"]

    condition {
      test     = "StringEquals"
      variable = "iam:AWSServiceName"
      values   = ["connect.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "plan" {
  name                 = "${var.name_prefix}-gha-plan"
  assume_role_policy   = data.aws_iam_policy_document.trust_plan.json
  max_session_duration = var.max_session_seconds
}

resource "aws_iam_role_policy_attachment" "plan_readonly" {
  role       = aws_iam_role.plan.name
  policy_arn = "arn:${local.partition}:iam::aws:policy/ReadOnlyAccess"
}

resource "aws_iam_role_policy" "plan_state" {
  name   = "state"
  role   = aws_iam_role.plan.id
  policy = data.aws_iam_policy_document.state.json
}

resource "aws_iam_role" "apply" {
  name                 = "${var.name_prefix}-gha-apply"
  assume_role_policy   = data.aws_iam_policy_document.trust_apply.json
  max_session_duration = var.max_session_seconds
}

# PowerUserAccess covers every service this stack uses except IAM; IAM is added back for this workload's names only.
resource "aws_iam_role_policy_attachment" "apply_poweruser" {
  role       = aws_iam_role.apply.name
  policy_arn = "arn:${local.partition}:iam::aws:policy/PowerUserAccess"
}

resource "aws_iam_role_policy" "apply_iam" {
  name   = "workload-iam"
  role   = aws_iam_role.apply.id
  policy = data.aws_iam_policy_document.apply_iam.json
}

resource "aws_iam_role_policy" "apply_connect_slr" {
  name   = "connect-service-linked-role"
  role   = aws_iam_role.apply.id
  policy = data.aws_iam_policy_document.apply_connect_slr.json
}

resource "aws_iam_role_policy" "apply_state" {
  name   = "state"
  role   = aws_iam_role.apply.id
  policy = data.aws_iam_policy_document.state.json
}
