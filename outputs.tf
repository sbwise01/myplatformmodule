output "eks_cluster_id" {
  value = module.eks.cluster_id
}

output "eks_oidc_provider_arn" {
  value = module.eks.oidc_provider_arn
}
