# ==============================================================================
# Variáveis Gerais e de Identificação
# ==============================================================================
variable "aws_region" {
  description = "Região da AWS onde o FSx será provisionado"
  type        = string
  default     = "us-east-1"
}

variable "projeto" {
  description = "Nome do projeto para identificação e prefixos de recursos"
  type        = string
  default     = "fsx-ontap-poc"
}

variable "owner" {
  description = "Responsável ou equipe dona do recurso"
  type        = string
  default     = "time-infra"
}

variable "shared" {
  description = "Indica se o recurso é compartilhado"
  type        = bool
  default     = false
}

variable "stack" {
  description = "Nome da stack do recurso"
  type        = string
  default     = "storage"
}

variable "iac" {
  description = "Ferramenta de IaC utilizada"
  type        = string
  default     = "terraform"
}

variable "environment" {
  description = "Ambiente do projeto (ex: prod, hml, poc)"
  type        = string
  default     = "poc"
}

variable "extra_tags" {
  description = "Tags adicionais a serem aplicadas a todos os recursos"
  type        = map(string)
  default     = {}
}

# ==============================================================================
# Variáveis de Infraestrutura Existente (Rede e Segurança)
# ==============================================================================
variable "subnet_ids" {
  description = "Lista de Subnet IDs onde o FSx será implantado (1 subnet para Single-AZ, 2 para Multi-AZ)"
  type        = list(string)
}

variable "preferred_subnet_id" {
  description = "Subnet ID preferencial para a interface primária do FSx (obrigatório para Single-AZ ou Multi-AZ)"
  type        = string
}

variable "security_group_ids" {
  description = "Lista de Security Group IDs aplicados às interfaces de rede do FSx"
  type        = list(string)
}

variable "kms_key_id" {
  description = "ARN ou ID da chave AWS KMS para criptografia em repouso. Se nulo, usa a chave gerenciada pela AWS (aws/fsx)"
  type        = string
  default     = null
}

# ==============================================================================
# Variáveis do File System (FSx for NetApp ONTAP)
# ==============================================================================
variable "deployment_type" {
  description = "Tipo de implantação do FSx: SINGLE_AZ_1 ou MULTI_AZ_1"
  type        = string
  default     = "SINGLE_AZ_1"
  validation {
    condition     = contains(["SINGLE_AZ_1", "MULTI_AZ_1"], var.deployment_type)
    error_message = "O deployment_type deve ser 'SINGLE_AZ_1' ou 'MULTI_AZ_1'."
  }
}

variable "storage_capacity_gib" {
  description = "Capacidade de armazenamento SSD em GiB (Mínimo: 1024 GiB para Single-AZ)"
  type        = number
  default     = 1024
}

variable "throughput_capacity_mbps" {
  description = "Capacidade de Throughput em MB/s (Opções: 128, 256, 512, 1024, 2048, 4096)"
  type        = number
  default     = 128
}

variable "fsx_admin_password" {
  description = "Senha administrativa para o usuário fsxadmin do cluster ONTAP (mínimo 8 caracteres, complexa)"
  type        = string
  sensitive   = true
}

# ==============================================================================
# Políticas de Backup e Integridade de Dados
# ==============================================================================
variable "automatic_backup_retention_days" {
  description = "Quantidade de dias para retenção dos backups diários automáticos (0 para desabilitar, padrão 7 para integridade)"
  type        = number
  default     = 7
}

variable "daily_automatic_backup_start_time" {
  description = "Horário de início da janela diária de backup no formato HH:MM (horário UTC). Ex: '03:00'"
  type        = string
  default     = "03:00"
}

variable "weekly_maintenance_start_time" {
  description = "Janela de manutenção semanal de 30 minutos no formato d:HH:MM (UTC), onde d é 1 (Dom) a 7 (Sáb). Ex: '7:04:00'"
  type        = string
  default     = "7:04:00"
}

variable "copy_tags_to_backups" {
  description = "Garante a propagação automática de tags do File System para os snapshots de backup"
  type        = bool
  default     = true
}

# ==============================================================================
# Variáveis da Storage Virtual Machine (SVM) e Active Directory
# ==============================================================================
variable "svm_name" {
  description = "Nome da Storage Virtual Machine (SVM)"
  type        = string
  default     = "svmpoc"
}

variable "svm_admin_password" {
  description = "Senha administrativa para o vsadmin da SVM (se nulo, usa a mesma senha do fsxadmin)"
  type        = string
  sensitive   = true
  default     = null
}

variable "svm_root_volume_security_style" {
  description = "Estilo de segurança do volume raiz da SVM: NTFS, UNIX ou MIXED"
  type        = string
  default     = "UNIX"
}

variable "join_active_directory" {
  description = "Define se a SVM será integrada a um domínio Active Directory"
  type        = bool
  default     = true
}

variable "ad_domain_name" {
  description = "Nome FQDN do Domínio Active Directory (Ex: corp.empresa.local ou corp.exemplo.com)"
  type        = string
  default     = "corp.exemplo.com"
}

variable "ad_dns_ips" {
  description = "Lista de endereços IP dos servidores DNS que resolvem o domínio Active Directory"
  type        = list(string)
  default     = ["10.0.0.2"]
}

variable "ad_netbios_name" {
  description = "Nome NetBIOS do servidor SMB / Computador criado no AD (até 15 caracteres)"
  type        = string
  default     = "FSXSMB"
}

variable "ad_organizational_unit_distinguished_name" {
  description = "Distinguished Name da Unidade Organizacional (OU) no AD para a conta da SVM (opcional). Ex: 'OU=Storage,DC=corp,DC=exemplo,DC=com'"
  type        = string
  default     = null
}

variable "ad_service_account_username" {
  description = "Usuário do Active Directory com privilégios para ingressar computadores no domínio"
  type        = string
  default     = "svc_fsx_join"
}

variable "ad_service_account_password" {
  description = "Senha da conta de serviço do Active Directory para o join"
  type        = string
  sensitive   = true
  default     = "Mudar123!SenhaForte"
}

variable "ad_file_system_administrators_group" {
  description = "Nome do grupo do Active Directory cujos membros terão privilégios de administração no servidor de arquivos"
  type        = string
  default     = "Domain Admins"
}

# ==============================================================================
# Definição e Políticas de Integridade de Volumes
# ==============================================================================
variable "volumes" {
  description = "Mapa de volumes a serem provisionados na SVM com suas configurações e políticas de integridade"
  type = map(object({
    name                       = string
    junction_path              = string
    size_in_megabytes          = number
    security_style             = string # UNIX, NTFS ou MIXED
    storage_efficiency_enabled = bool   # Deduplicação e compressão
    snapshot_policy            = string # default, none, ou personalizada do ONTAP
    tiering_policy_name        = string # NONE, AUTO, SNAPSHOT_ONLY, ALL
    cooling_period_days        = optional(number)
    skip_final_backup          = optional(bool, false)
  }))
  default = {
    "vol_smb" = {
      name                       = "vol_smb"
      junction_path              = "/vol_smb"
      size_in_megabytes          = 10240 # 10 GiB
      security_style             = "NTFS"
      storage_efficiency_enabled = true
      snapshot_policy            = "default" # Snapshots point-in-time automáticos para integridade
      tiering_policy_name        = "AUTO"
      cooling_period_days        = 31
      skip_final_backup          = false
    },
    # "vol_nfs" = {
    #   name                       = "vol_nfs"
    #   junction_path              = "/vol_nfs"
    #   size_in_megabytes          = 10240 # 10 GiB
    #   security_style             = "UNIX"
    #   storage_efficiency_enabled = true
    #   snapshot_policy            = "default"
    #   tiering_policy_name        = "NONE"
    #   cooling_period_days        = null
    #   skip_final_backup          = false
    # }
  }
}
