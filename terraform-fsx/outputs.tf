# ==============================================================================
# Outputs do File System FSx
# ==============================================================================
output "fsx_file_system_id" {
  description = "ID do File System FSx for NetApp ONTAP"
  value       = aws_fsx_ontap_file_system.main.id
}

output "fsx_file_system_arn" {
  description = "ARN do File System FSx for NetApp ONTAP"
  value       = aws_fsx_ontap_file_system.main.arn
}

output "fsx_dns_name" {
  description = "DNS Name geral do File System"
  value       = aws_fsx_ontap_file_system.main.dns_name
}

output "fsx_management_dns_name" {
  description = "DNS Management Endpoint do cluster ONTAP para SSH administrativo (fsxadmin)"
  value       = try(aws_fsx_ontap_file_system.main.endpoints[0].management[0].dns_name, null)
}

output "fsx_management_ip_addresses" {
  description = "Endereços IP do endpoint de gerenciamento do cluster"
  value       = try(aws_fsx_ontap_file_system.main.endpoints[0].management[0].ip_addresses, [])
}

# ==============================================================================
# Outputs da Storage Virtual Machine (SVM)
# ==============================================================================
output "svm_id" {
  description = "ID da Storage Virtual Machine (SVM)"
  value       = aws_fsx_ontap_storage_virtual_machine.svm.id
}

output "svm_name" {
  description = "Nome da Storage Virtual Machine"
  value       = aws_fsx_ontap_storage_virtual_machine.svm.name
}

output "svm_management_dns_name" {
  description = "DNS Management Endpoint da SVM para SSH administrativo (vsadmin)"
  value       = try(aws_fsx_ontap_storage_virtual_machine.svm.endpoints[0].management[0].dns_name, null)
}

output "svm_nfs_dns_name" {
  description = "DNS Endpoint para montagem de volumes NFS no Linux"
  value       = try(aws_fsx_ontap_storage_virtual_machine.svm.endpoints[0].nfs[0].dns_name, null)
}

output "svm_nfs_ip_addresses" {
  description = "Endereços IP do endpoint NFS da SVM"
  value       = try(aws_fsx_ontap_storage_virtual_machine.svm.endpoints[0].nfs[0].ip_addresses, [])
}

output "svm_smb_dns_name" {
  description = "DNS Endpoint para mapeamento de compartilhamentos SMB no Windows"
  value       = try(aws_fsx_ontap_storage_virtual_machine.svm.endpoints[0].smb[0].dns_name, null)
}

output "svm_smb_ip_addresses" {
  description = "Endereços IP do endpoint SMB da SVM"
  value       = try(aws_fsx_ontap_storage_virtual_machine.svm.endpoints[0].smb[0].ip_addresses, [])
}

# ==============================================================================
# Outputs dos Volumes Criados
# ==============================================================================
output "volumes" {
  description = "Mapeamento detalhado dos volumes criados e seus caminhos de junção (Junction Paths)"
  value = {
    for k, v in aws_fsx_ontap_volume.volumes : k => {
      id             = v.id
      arn            = v.arn
      name           = v.name
      junction_path  = v.junction_path
      security_style = v.security_style
    }
  }
}
