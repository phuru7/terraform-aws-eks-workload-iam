# ── IAM Role ──────────────────────────────────────────────
output "role_arn" {
  description = "ARN of the IAM role"
  value       = aws_iam_role.this.arn
}

output "role_name" {
  description = "Name of the IAM role"
  value       = aws_iam_role.this.name
}

# ── Policies ──────────────────────────────────────────────
output "policy_names" {
  description = "Map of policy key to the inline policy name created in the role"
  value       = { for k, p in aws_iam_role_policy.this : k => p.name }
}

# ── ServiceAccount contract ───────────────────────────────
output "service_account" {
  description = "What the Kubernetes process must create: a ServiceAccount with this name, namespace and annotations"
  value = {
    name      = local.service_account
    namespace = var.namespace
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.this.arn
    }
  }
}
