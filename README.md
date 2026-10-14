# terraform-aws-eks-workload-iam

IAM roles for EKS microservices using **IRSA**. One role per microservice, bound to its exact ServiceAccount, with least-privilege inline policies and a per-project permissions boundary.

```
1 microservice → 1 ServiceAccount → 1 IAM role → N inline policies
```

> Terraform only creates IAM resources. ServiceAccounts are created by your Kubernetes deployment process.

## Structure

```
modules/
  eks-irsa-role/          # 1 instance = 1 microservice role
projects/
  <project>/              # 1 project = 1 state = 1 namespace
    main.tf
    outputs.tf
    providers.tf
    variables.tf
    terraform.tfvars      # microservices are declared here
    policies/
      workload-boundary.json
      <microservice>/
        <policy>.json
```

## Naming

| Resource | Format | Example |
|---|---|---|
| IAM role | `{env}-{project}-eks-{microservice}` | `dev-app-eks-ms-orders` |
| Inline policy | `{role}-{policy-key}` | `dev-app-eks-ms-orders-s3-read` |
| Boundary | `{env}-{project}-eks-workload-boundary` | `dev-app-eks-workload-boundary` |
| ServiceAccount | `{microservice}-sa` | `ms-orders-sa` |

## Usage

**1. Declare the microservice** in `terraform.tfvars`:

```hcl
aws_region        = "us-east-1"
aws_profile       = "my-profile"
environment       = "dev"
project           = "app"
namespace         = "my-namespace"
oidc_provider_arn = "arn:aws:iam::<account-id>:oidc-provider/oidc.eks.<region>.amazonaws.com/id/<id>"

microservices = {
  ms-orders = {
    policy_files = {
      s3-read        = "policies/ms-orders/s3-read.json"
      dynamodb-write = "policies/ms-orders/dynamodb-write.json"
    }
  }
}
```

**2. Add its policies** as JSON files in `policies/<microservice>/`. Each file becomes one inline policy.

**3. Apply:**

```bash
terraform init
terraform plan
terraform apply
```

**4. Create the ServiceAccount** in Kubernetes using the output:

```bash
terraform output -json service_accounts
```

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: ms-orders-sa
  namespace: my-namespace
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::<account-id>:role/dev-app-eks-ms-orders
```

To remove a microservice or a policy, delete its entry from `terraform.tfvars` and apply.

## Permissions boundary

Each project has one boundary attached to all its roles. It grants nothing; it caps what any role can do.

```
Effective permissions = inline policies ∩ boundary
```

The default boundary allows S3, DynamoDB, SQS, SNS publish and KMS usage, and always denies IAM, role assumption, destructive or configuration changes on resources, and non-TLS S3 access. Adjust it to your needs.

## Module inputs

| Name | Required | Description |
|---|:---:|---|
| `environment` | ✅ | `dev`, `qa` or `prd` |
| `project` | ✅ | Project code |
| `component` | ✅ | Microservice name, must start with `ms-` |
| `namespace` | ✅ | Kubernetes namespace |
| `oidc_provider_arn` | ✅ | EKS cluster OIDC provider ARN |
| `policies` | ✅ | Map of policy key → JSON content |
| `service_account` | | Defaults to `{component}-sa` |
| `permissions_boundary_arn` | | Boundary policy ARN |

**Outputs:** `role_arn`, `role_name`, `policy_names`, `service_account`.

## Troubleshooting

| Error | Check |
|---|---|
| `AccessDenied` on `AssumeRoleWithWebIdentity` | ServiceAccount name, namespace and annotation match the output; pod was restarted |
| `AccessDenied` on a resource | The action is allowed in the microservice policy **and** in the boundary |
| All roles fail after recreating the cluster | Update `oidc_provider_arn` and apply |

## Requirements

- Terraform `>= 1.5.0`
- AWS provider `~> 6.0`
- EKS cluster with an IAM OIDC provider