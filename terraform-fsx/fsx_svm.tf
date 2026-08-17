resource "aws_fsx_ontap_storage_virtual_machine" "svm" {
  file_system_id             = aws_fsx_ontap_file_system.main.id
  name                       = var.svm_name
  svm_admin_password         = coalesce(var.svm_admin_password, var.fsx_admin_password)
  root_volume_security_style = var.svm_root_volume_security_style

  # ============================================================================
  # Integração com Domínio Active Directory (Condicional e Parametrizada)
  # ============================================================================
  dynamic "active_directory_configuration" {
    for_each = var.join_active_directory ? [1] : []
    content {
      netbios_name = var.ad_netbios_name
      
      self_managed_active_directory_configuration {
        domain_name                                = var.ad_domain_name
        dns_ips                                    = var.ad_dns_ips
        organizational_unit_distinguished_name     = var.ad_organizational_unit_distinguished_name
        username                                   = var.ad_service_account_username
        password                                   = var.ad_service_account_password
        file_system_administrators_group           = var.ad_file_system_administrators_group
      }
    }
  }

  tags = {
    Name = "${var.project_name}-${var.svm_name}"
  }
}
