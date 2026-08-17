resource "aws_fsx_ontap_volume" "volumes" {
  for_each = var.volumes

  name                       = each.value.name
  junction_path              = each.value.junction_path
  size_in_megabytes          = each.value.size_in_megabytes
  storage_efficiency_enabled = each.value.storage_efficiency_enabled
  storage_virtual_machine_id = aws_fsx_ontap_storage_virtual_machine.svm.id
  security_style             = each.value.security_style
  snapshot_policy            = each.value.snapshot_policy
  skip_final_backup          = each.value.skip_final_backup

  # ============================================================================
  # Política de Tiering de Capacidade (Capacity Pool)
  # ============================================================================
  dynamic "tiering_policy" {
    for_each = each.value.tiering_policy_name != "NONE" ? [1] : []
    content {
      name           = each.value.tiering_policy_name
      cooling_period = each.value.cooling_period_days
    }
  }

  tags = {
    Name           = "${var.project_name}-${each.value.name}"
    SecurityStyle  = each.value.security_style
    SnapshotPolicy = each.value.snapshot_policy
  }
}
