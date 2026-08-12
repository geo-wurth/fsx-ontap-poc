variable "aws_region" {
  description = "Região da AWS onde os recursos serão provisionados"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Nome do projeto, usado para prefixar recursos"
  type        = string
  default     = "fsx-ontap-poc"
}

variable "environment" {
  description = "Ambiente do projeto (ex: poc, dev)"
  type        = string
  default     = "poc"
}

variable "availability_zone" {
  description = "Availability zone para recursos Single-AZ"
  type        = string
  default     = "us-east-1a"
}

variable "vpc_cidr" {
  description = "Bloco CIDR da VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "Bloco CIDR da Subnet Pública"
  type        = string
  default     = "10.0.1.0/24"
}

variable "private_subnet_cidr" {
  description = "Bloco CIDR da Subnet Privada"
  type        = string
  default     = "10.0.11.0/24"
}

variable "linux_instance_type" {
  description = "Tipo da instância EC2 Linux"
  type        = string
  default     = "t3.micro"
}

variable "windows_instance_type" {
  description = "Tipo da instância EC2 Windows"
  type        = string
  default     = "t3.small"
}
