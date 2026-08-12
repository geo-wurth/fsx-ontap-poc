# Guia de Provisionamento Manual - Amazon FSx for NetApp ONTAP

Para manter a separação clara, o Terraform desta POC cria apenas a infraestrutura adjacente (VPC, Subnets, EC2, Security Groups, IAM). O Storage (FSx, SVM e Volumes) deve ser criado manualmente seguindo os passos abaixo.

## 1. Pré-requisitos
Certifique-se de que o Terraform executou com sucesso (`terraform apply`). Você precisará dos seguintes valores do `terraform output`:
- `vpc_id`
- `private_subnet_id`
- `fsx_security_group_id`

## 2. Criar o File System
1. Acesse o **AWS Management Console**.
2. Vá para o serviço **FSx** e clique em **Create file system**.
3. Selecione **Amazon FSx for NetApp ONTAP** e clique em **Next**.
4. Na tela de criação:
   - **Creation method**: Selecione `Standard create`.
   - **File system details**:
     - **File system name**: `fsx-ontap-poc-fs`
     - **Deployment type**: `Single-AZ` (Para menor custo)
     - **Storage capacity**: `1024` GiB (Mínimo exigido para Single-AZ ONTAP)
     - **Storage type**: `SSD`
     - **Provisioned SSD IOPS**: `Automatic`
     - **Throughput capacity**: `128` MB/s
   - **Network & security**:
     - **VPC**: Selecione a VPC criada pelo Terraform (compare com seu `vpc_id`).
     - **VPC Security Groups**: Selecione o Security Group criado para o FSx (compare com seu `fsx_security_group_id`). **Remova o default**.
     - **Subnet**: Selecione a **Private Subnet** (compare com seu `private_subnet_id`).
   - **Security & encryption**:
     - **Encryption key**: `aws/fsx` (default KMS key).
     - **File system administrator password**: Digite uma senha forte. Anote-a, você precisará dela nos scripts de configuração (`fsxadmin`).
   - **Backup and maintenance**:
     - **Daily automatic backup**: **Disable** (Desabilite para reduzir custos na POC).
5. Clique em **Next** e depois **Create file system**.
*(Aguarde até o status mudar para "Available". Isso pode levar de 15 a 30 minutos).*

## 3. Criar a Storage Virtual Machine (SVM)
1. No painel do FSx, no menu à esquerda, clique em **Storage virtual machines**.
2. Clique em **Create storage virtual machine**.
3. Na tela de criação:
   - **File system**: Selecione o File System criado no passo anterior.
   - **Storage virtual machine name**: `svmpoc`
   - **Root volume security style**: `UNIX`
   - **SVM administrator password**: Especifique uma senha (recomendável usar a mesma senha do `fsxadmin` para facilitar a POC).
4. Clique em **Create storage virtual machine**.
*(Aguarde o status "Available").*

## 4. Criar os Volumes
Precisamos de dois volumes: um para NFS e outro para SMB.
1. No menu à esquerda, clique em **Volumes**.
2. Clique em **Create volume**.

**Volume 1 (NFS)**:
- **File system**: Selecione o seu File System.
- **Storage virtual machine**: Selecione `svmpoc`.
- **Volume name**: `vol_nfs`
- **Volume size**: `10` GiB
- **Junction path**: `/vol_nfs`
- **Storage efficiency**: `Enabled`
- **Security style**: `UNIX`
- **Snapshot policy**: `Default` (ou `None` para evitar snaps indesejados).
- Clique em **Create volume**.

**Volume 2 (SMB)**:
*(Repita o processo de Create volume)*
- **File system**: Selecione o seu File System.
- **Storage virtual machine**: Selecione `svmpoc`.
- **Volume name**: `vol_smb`
- **Volume size**: `10` GiB
- **Junction path**: `/vol_nfs` *(Wait, deve ser `/vol_smb`)* -> **Mude para:** `/vol_smb`
- **Storage efficiency**: `Enabled`
- **Security style**: `NTFS`
- **Snapshot policy**: `Default` ou `None`.
- Clique em **Create volume**.

## 5. Obter Endpoints para os Testes
Para rodar os scripts de teste e configuração, você precisará dos endpoints. Vá nos detalhes da SVM `svmpoc` e anote:
- **Management DNS name** (Usado no script `configure-ontap.sh`)
- **NFS IP address / DNS name** (Usado no `test-nfs.sh`)
- **SMB IP address / DNS name** (Usado no `test-smb.ps1`)

---

## Destruição Manual (AWS CLI)
Para evitar custos após os testes, destrua o FSx **antes** de destruir o ambiente Terraform, pois a rede e os security groups estão amarrados a ele. Como este processo pela console pode deixar backups residuais, você pode usar os comandos CLI abaixo para uma limpeza limpa e forçada (sem final backup).

> [!CAUTION]
> Os comandos abaixo deletam dados sem backup. Substitua os IDs (`<FSX_ID>`, `<SVM_ID>`, `<VOL_NFS_ID>`, `<VOL_SMB_ID>`) pelos IDs reais gerados na sua conta. Você pode encontrá-los na AWS Console ou rodando listagens no CLI.

```bash
# 1. Deletar os Volumes ignorando Final Backup
aws fsx delete-volume --volume-id <VOL_NFS_ID>
aws fsx delete-volume --volume-id <VOL_SMB_ID>

# 2. Deletar a SVM
aws fsx delete-storage-virtual-machine --storage-virtual-machine-id <SVM_ID>

# 3. Deletar o File System ignorando Final Backup
aws fsx delete-file-system --file-system-id <FSX_ID> --skip-final-backup
```
Acompanhe a exclusão pelo console. Somente após o FSx desaparecer por completo (Status `Deleted`), você pode rodar o `terraform destroy` no diretório Terraform para limpar o resto da infraestrutura (VPC, EC2s, etc).
