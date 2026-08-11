output "vpc_id" {
  description = "ID da VPC"
  value       = aws_vpc.main.id
}

output "public_subnet_id" {
  description = "ID da Subnet Pública"
  value       = aws_subnet.public.id
}

output "private_subnet_id" {
  description = "ID da Subnet Privada"
  value       = aws_subnet.private.id
}

output "linux_instance_id" {
  description = "ID da Instância EC2 Linux"
  value       = aws_instance.linux.id
}

output "windows_instance_id" {
  description = "ID da Instância EC2 Windows"
  value       = aws_instance.windows.id
}

output "linux_private_ip" {
  description = "IP Privado da EC2 Linux"
  value       = aws_instance.linux.private_ip
}

output "windows_private_ip" {
  description = "IP Privado da EC2 Windows"
  value       = aws_instance.windows.private_ip
}

output "fsx_id" {
  description = "ID do FSx for ONTAP"
  value       = aws_fsx_ontap_file_system.fsx.id
}

output "fsx_dns_name" {
  description = "DNS Name do FSx"
  value       = aws_fsx_ontap_file_system.fsx.dns_name
}

output "svm_id" {
  description = "ID da SVM"
  value       = aws_fsx_ontap_storage_virtual_machine.svm.id
}

output "svm_name" {
  description = "Nome da SVM"
  value       = aws_fsx_ontap_storage_virtual_machine.svm.name
}

output "fsx_management_dns_name" {
  description = "DNS Management Endpoint do FSx"
  value       = aws_fsx_ontap_file_system.fsx.endpoints[0].management[0].dns_name
}

output "svm_management_dns_name" {
  description = "DNS Management Endpoint da SVM"
  value       = aws_fsx_ontap_storage_virtual_machine.svm.endpoints[0].management[0].dns_name
}

output "nfs_dns_name" {
  description = "DNS para montagem do NFS"
  value       = aws_fsx_ontap_storage_virtual_machine.svm.endpoints[0].nfs[0].dns_name
}

output "nfs_ip_addresses" {
  description = "IPs do Endpoint NFS"
  value       = aws_fsx_ontap_storage_virtual_machine.svm.endpoints[0].nfs[0].ip_addresses
}

output "smb_dns_name" {
  description = "DNS para mapeamento do SMB"
  value       = aws_fsx_ontap_storage_virtual_machine.svm.endpoints[0].smb[0].dns_name
}

output "smb_ip_addresses" {
  description = "IPs do Endpoint SMB"
  value       = aws_fsx_ontap_storage_virtual_machine.svm.endpoints[0].smb[0].ip_addresses
}

output "linux_ssm_command" {
  description = "Comando para conectar na EC2 Linux via SSM"
  value       = "aws ssm start-session --target ${aws_instance.linux.id}"
}

output "windows_ssm_command" {
  description = "Comando para conectar na EC2 Windows via SSM"
  value       = "aws ssm start-session --target ${aws_instance.windows.id}"
}
