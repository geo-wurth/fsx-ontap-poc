resource "aws_fsx_ontap_file_system" "main" {
  storage_capacity    = var.storage_capacity_gib
  subnet_ids          = var.subnet_ids
  preferred_subnet_id = var.preferred_subnet_id
  deployment_type     = var.deployment_type
  throughput_capacity = var.throughput_capacity_mbps
  security_group_ids  = var.security_group_ids
  kms_key_id          = var.kms_key_id
  fsx_admin_password  = var.fsx_admin_password

  # ============================================================================
  # Políticas de Backup e Integridade de Dados
  # ============================================================================
  automatic_backup_retention_days   = var.automatic_backup_retention_days
  daily_automatic_backup_start_time = var.daily_automatic_backup_start_time
  weekly_maintenance_start_time     = var.weekly_maintenance_start_time

  tags = {
    Name = "${var.project_name}-fsx-ontap"
  }

  lifecycle {
    prevent_destroy = false
  }
}
