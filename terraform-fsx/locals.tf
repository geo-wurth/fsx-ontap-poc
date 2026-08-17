locals {
  common_tags = merge(
    {
      Project     = var.project_name
      ManagedBy   = "Terraform"
      Environment = var.environment
    },
    var.extra_tags
  )
}
