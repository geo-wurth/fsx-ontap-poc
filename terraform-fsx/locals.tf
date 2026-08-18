locals {
  common_tags = merge(
    {
      Projeto     = var.projeto
      Owner       = var.owner
      Shared      = tostring(var.shared)
      Stack       = var.stack
      Iac         = var.iac
      Environment = var.environment
    },
    var.extra_tags
  )
}
