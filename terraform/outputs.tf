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

output "fsx_security_group_id" {
  description = "ID do Security Group que deve ser anexado ao FSx durante a criação manual"
  value       = aws_security_group.fsx.id
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

output "linux_ssm_command" {
  description = "Comando para conectar na EC2 Linux via SSM"
  value       = "aws ssm start-session --target ${aws_instance.linux.id}"
}

output "windows_ssm_command" {
  description = "Comando para conectar na EC2 Windows via SSM"
  value       = "aws ssm start-session --target ${aws_instance.windows.id}"
}
