# ── Locals ────────────────────────────────────────────────
locals {
  role_name       = "${var.environment}-${var.project}-eks-${var.component}"
  service_account = coalesce(var.service_account, "${var.component}-sa")

  oidc_issuer = split("oidc-provider/", var.oidc_provider_arn)[1]
}

# ── Trust Policy (IRSA) ───────────────────────────────────
data "aws_iam_policy_document" "assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_issuer}:sub"
      values   = ["system:serviceaccount:${var.namespace}:${local.service_account}"]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_issuer}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

# ── IAM Role ──────────────────────────────────────────────
resource "aws_iam_role" "this" {
  name                 = local.role_name
  description          = "IRSA role for ${var.component} (${var.namespace}/${local.service_account})"
  assume_role_policy   = data.aws_iam_policy_document.assume_role.json
  permissions_boundary = var.permissions_boundary_arn
}

# ── Inline Policies ───────────────────────────────────────
resource "aws_iam_role_policy" "this" {
  for_each = var.policies

  name   = "${local.role_name}-${each.key}"
  role   = aws_iam_role.this.id
  policy = each.value
}

# ── Exclusive Inline Policies ─────────────────────────────
resource "aws_iam_role_policies_exclusive" "this" {
  role_name    = aws_iam_role.this.name
  policy_names = [for p in aws_iam_role_policy.this : p.name]
}
