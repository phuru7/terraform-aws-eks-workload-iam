# terraform-aws-eks-workload-iam
Terraform IAM roles for EKS workloads using IRSA. One role per microservice, bound to its exact ServiceAccount, with inline least-privilege policies from JSON files and a per-project permissions boundary.
