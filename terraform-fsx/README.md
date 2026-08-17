# Módulo Terraform Isolado - Amazon FSx for NetApp ONTAP

Este projeto Terraform é **totalmente isolado e desacoplado**, dedicado exclusivamente ao provisionamento e governança do **Amazon FSx for NetApp ONTAP**, integração com **Active Directory**, políticas de **Backup Automático** e regras de **Integridade de Dados (Snapshots & Deduplicação)**.

---

## Arquitetura e Recursos Gerenciados

```
                              ┌───────────────────────────────────────────────────┐
                              │  Módulo Base: VPC / Subnets / EC2 / Security SGs   │
                              └─────────────────────────┬─────────────────────────┘
                                                        │ (IDs passados via variáveis)
                                                        ▼
┌─────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│ Módulo Isolado: FSx for NetApp ONTAP (terraform-fsx/)                                                           │
│                                                                                                                 │
│   ┌─────────────────────────────────────────────────────────────────────────────────────────────────────────┐   │
│   │ File System FSx ONTAP                                                                                   │   │
│   │  • Single-AZ / Multi-AZ                                                                                 │   │
│   │  • Backups Automáticos Diários (Janela UTC + Retenção 7-30 dias)                                        │   │
│   │  • Criptografia em Repouso (KMS) & Manutenção Semanal                                                   │   │
│   └────────────────────────────────────────────────────┬────────────────────────────────────────────────────┘   │
│                                                        │                                                        │
│   ┌────────────────────────────────────────────────────┴────────────────────────────────────────────────────┐   │
│   │ Storage Virtual Machine (SVM)                                                                           │   │
│   │  • Join em Domínio Active Directory (Self-Managed AD ou AWS Managed AD)                                │   │
│   │  • Resolução de DNS Corporativo & Autenticação Kerberos/NTLM                                            │   │
│   └────────────────────────────────────────────────────┬────────────────────────────────────────────────────┘   │
│                                                        │                                                        │
│               ┌────────────────────────────────────────┴────────────────────────────────────────┐             │
│               ▼                                                                                 ▼             │
│   ┌────────────────────────────────────────┐                        ┌────────────────────────────────────────┐  │
│   │ Volume SMB (vol_smb)                   │                        │ Volume NFS (vol_nfs)                   │  │
│   │  • Security Style: NTFS                │                        │  • Security Style: UNIX                │  │
│   │  • Snapshot Policy: default (Point-in-Time) │                    │  • Snapshot Policy: default (Point-in-Time) ││
│   │  • Storage Efficiency: Enabled         │                        │  • Storage Efficiency: Enabled         │  │
│   │  • Capacity Tiering: AUTO              │                        │  • Capacity Tiering: NONE              │  │
│   └────────────────────────────────────────┘                        └────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘
```

---

## Melhores Práticas de IaC e Integridade de Dados Implementadas

1. **Garantia de Integridade de Disco pós-Backup:**
   - **Snapshots do ONTAP (`snapshot_policy = "default"`)**: Criam cópias pontuais (*read-only*) no nível de blocos sem overhead de I/O, garantindo proteção contra corrupção lógica, deleção acidental ou ataques de ransomware, permitindo restauração instantânea de arquivos.
   - **Backups do FSx (`automatic_backup_retention_days = 7+`)**: Snapshots consistentes transferidos para o Amazon S3 com retenção configurável e criptografia KMS, permitindo *Point-in-Time Restore* do sistema inteiro.
   - **Eficiência de Armazenamento (`storage_efficiency_enabled = true`)**: Ativa deduplicação e compressão de blocos no motor WAFL do NetApp ONTAP.

2. **Segurança e Variáveis Sensíveis:**
   - Todas as credenciais de cluster (`fsx_admin_password`), SVM (`svm_admin_password`) e Active Directory (`ad_service_account_password`) estão declaradas com `sensitive = true`, impedindo vazamento nos logs do console e outputs.

3. **Integração Dinâmica com Active Directory:**
   - O bloco `active_directory_configuration` é dinâmico. Caso `join_active_directory = false`, o módulo cria uma SVM independente para uso de usuários locais e workgroups.

---

## Como Executar no AWS CloudShell / Terminal

### Passo 1: Obter as Informações da Infraestrutura Base
Antes de aplicar, colete os outputs do seu Terraform de rede (ou do ambiente existente):
- `private_subnet_id` (ex: `subnet-0123456789abcdef0`)
- `fsx_security_group_id` (ex: `sg-0123456789abcdef0`)

### Passo 2: Configurar o Arquivo de Variáveis
Acesse o diretório `terraform-fsx`:
```bash
cd fsx-ontap-poc/terraform-fsx
cp terraform.tfvars.example terraform.tfvars
```

Edite o arquivo `terraform.tfvars`:
```bash
nano terraform.tfvars
```
Preencha os campos de rede, senhas e informações do Active Directory:
- `subnet_ids` e `preferred_subnet_id`
- `security_group_ids`
- `ad_domain_name` (Ex: `corp.suaempresa.com`)
- `ad_dns_ips` (Ex: `["10.0.0.2", "10.0.0.3"]`)
- `ad_service_account_username` e `ad_service_account_password`

### Passo 3: Inicializar e Aplicar
```bash
# Inicializar os provedores
terraform init

# Validar o plano de execução
terraform plan

# Aplicar e provisionar o FSx ONTAP
terraform apply
```
Digite `yes` para confirmar. *(O provisionamento completo do cluster ONTAP e ingresso no AD leva cerca de 15 a 20 minutos).*

---

## Outputs Gerados

Após a criação, o Terraform exibirá os endpoints prontos para conexão:
- `fsx_file_system_id`: ID do cluster FSx.
- `fsx_management_dns_name`: Endpoint para conexão SSH administrativa (`ssh fsxadmin@<endpoint>`).
- `svm_smb_dns_name`: Endpoint para mapeamento de unidades Windows (`\\<svm_smb_dns_name>\vol_smb`).
- `svm_nfs_dns_name`: Endpoint para montagem NFS no Linux (`mount -t nfs <svm_nfs_dns_name>:/vol_nfs /mnt/nfs`).
- `volumes`: Lista detalhada de todos os volumes, IDs e seus respectivos junction paths.

---

## Destruição e Proteção

Ao executar `terraform destroy`, o parâmetro `skip_final_backup` está configurado **individualmente por volume** no bloco `volumes` em `terraform.tfvars`:
- `skip_final_backup = false` (Padrão corporativo: o Terraform solicitará a criação de um backup final dos dados antes de destruir o volume).
- `skip_final_backup = true` (Ideal para ambientes de teste e POC: destrói o volume imediatamente sem guardar snapshot final, evitando custos residuais).

> [!NOTE]
> Diferente de outros serviços, no FSx for NetApp ONTAP o *Final Backup* é atrelado aos **Volumes**, e não diretamente ao File System base.

Para destruir toda a infraestrutura deste módulo isolado:
```bash
terraform destroy
```
