output "configure_kubectl" {
  description = "Configure kubectl: make sure you're logged in with the correct AWS profile and run the following command to update your kubeconfig"
  value       = "aws eks --region ${var.region} update-kubeconfig --name ${module.eks.cluster_name}"
}

output "eks_cluster_name" {
  description = "Name of the cluster"
  value       = module.eks.cluster_name
}

output "eks_cluster_public_subnet_ids" {
  description = "List of public subnets IDs"
  value       = module.vpc.public_subnets
}

output "eks_cluster_private_subnet_ids" {
  description = "List of private subnets IDs"
  value       = module.vpc.private_subnets
}

output "eks_cluster_sg_id" {
  description = "Security Group ID"
  value       = module.eks.node_security_group_id
}

output "eks_iam_role_arn" {
  description = "EKS IAM Role"
  value       = module.eks.cluster_iam_role_arn
}