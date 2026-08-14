# Guia Completo de Provisionamento e Testes - Amazon FSx for NetApp ONTAP

Este documento contém o passo a passo detalhado para:
1. Criar o File System FSx, a Storage Virtual Machine (SVM) e os Volumes no Console AWS.
2. Configurar o serviço CIFS/SMB no ONTAP para permitir acesso do Windows a volumes com estilo de segurança **NTFS** e **UNIX**.
3. Realizar testes cruzados de leitura e escrita bidirecional entre Linux e Windows.
4. Destruir os recursos manuais via AWS CLI evitando custos residuais.

---

## 🔑 Padrão de Credenciais da POC

Para simplificar e unificar a operação do laboratório, utilize a seguinte senha padrão em todas as etapas:
- **Senha Padrão**: `Fsx@dm1n`
- **Usuário Admin do File System**: `fsxadmin`
- **Usuário Admin da SVM**: `vsadmin`
- **Usuário Local SMB (Windows/Linux)**: `smbuser`

---

## 🗺️ Topologia e Fluxo de Acesso entre as Máquinas

Como a arquitetura da POC não expõe portas SSH/RDP para a Internet pública, o fluxo de acesso e configuração é estruturado da seguinte forma:

```
[Seu Computador / AWS Console]
        │
        ├── (AWS SSM Session Manager) ──> [EC2 Linux (Public Subnet)]
        │                                        │
        │                                        ├── (SSH porta 22) ──> [FSx ONTAP Management CLI (Private Subnet)]
        │                                        ├── (NFS porta 2049) ─> [Volume NFS /vol_nfs]
        │                                        └── (SMB porta 445) ──> [Volume SMB /vol_smb]
        │
        └── (AWS SSM Session Manager) ──> [EC2 Windows (Public Subnet)]
                                                 │
                                                 ├── (SMB porta 445) ──> [Volume SMB \\<endpoint>\vol_smb]
                                                 └── (SMB porta 445) ──> [Volume NFS \\<endpoint>\vol_nfs]
```

---

## 1. Pré-requisitos (Terraform)

Execute o provisionamento da infraestrutura adjacente no diretório `terraform/`:
```bash
terraform init
terraform apply
```

Anote os seguintes outputs:
- `vpc_id` (Ex: `vpc-xxxxxx`)
- `private_subnet_id` (Ex: `subnet-xxxxxx`)
- `fsx_security_group_id` (Ex: `sg-xxxxxx`)
- `linux_instance_id` e `windows_instance_id`

---

## 2. Criação do FSx for NetApp ONTAP via Console AWS

### 2.1 Criar o File System
1. Acesse o console da AWS no serviço **Amazon FSx** e clique em **Create file system**.
2. Selecione **Amazon FSx for NetApp ONTAP** e clique em **Next**.
3. Escolha **Standard create** e configure:
   - **File system name**: `fsx-ontap-poc-fs`
   - **Deployment type**: `Single-AZ`
   - **Storage capacity**: `1024` GiB (SSD)
   - **Provisioned SSD IOPS**: `Automatic`
   - **Throughput capacity**: `128` MB/s
   - **Virtual Private Cloud (VPC)**: Selecione a VPC criada pelo Terraform (`vpc_id`).
   - **VPC Security Groups**: Selecione o Security Group do FSx (`fsx_security_group_id`). *Remova o Security Group default*.
   - **Subnet**: Selecione a Subnet Privada (`private_subnet_id`).
   - **File system administrator password**: `Fsx@dm1n`
   - **Daily automatic backup**: **Desmarcar/Disable** (para evitar cobranças de backup).
4. Clique em **Next** e confirme a criação clicando em **Create file system**.
*(Aguarde cerca de 15 a 20 minutos até que o status passe para `Available`).*

### 2.2 Criar a Storage Virtual Machine (SVM)
1. No menu lateral do FSx, clique em **Storage virtual machines** e em **Create storage virtual machine**.
2. Configure:
   - **File system**: Selecione `fsx-ontap-poc-fs`.
   - **Storage virtual machine name**: `svmpoc`
   - **Root volume security style**: `UNIX`
   - **SVM administrator password**: `Fsx@dm1n`
3. Clique em **Create storage virtual machine** e aguarde ficar `Available`.

### 2.3 Criar os Volumes (NFS e SMB)
No menu lateral, clique em **Volumes** > **Create volume**.

#### Volume 1: NFS (`vol_nfs`)
- **Storage virtual machine**: `svmpoc`
- **Volume name**: `vol_nfs`
- **Volume size**: `10` GiB
- **Junction path**: `/vol_nfs`
- **Storage efficiency**: `Enabled`
- **Security style**: `UNIX`
- **Snapshot policy**: `None` (ou `Default`)

#### Volume 2: SMB (`vol_smb`)
- **Storage virtual machine**: `svmpoc`
- **Volume name**: `vol_smb`
- **Volume size**: `10` GiB
- **Junction path**: `/vol_smb`
- **Storage efficiency**: `Enabled`
- **Security style**: `NTFS`
- **Snapshot policy**: `None` (ou `Default`)

---

## 3. Configuração do CIFS/SMB no ONTAP CLI

Para que o Windows possa acessar e editar tanto o volume NTFS (`vol_smb`) quanto o volume UNIX (`vol_nfs`), precisamos criar o servidor CIFS, o usuário local e os respectivos shares no ONTAP.

### 3.1 Conectar na CLI do ONTAP a partir do Linux
1. Abra uma sessão no **EC2 Linux** via AWS Systems Manager:
   ```bash
   aws ssm start-session --target <linux_instance_id>
   ```
2. Na EC2 Linux, conecte-se via SSH no **Management Endpoint** do FSx (ou da SVM):
   ```bash
   ssh fsxadmin@<management_dns_name>
   ```
   > *Exemplo real:* `ssh fsxadmin@management.fs-0312dff317496811b.fsx.us-east-1.amazonaws.com`  
   > **Senha**: `Fsx@dm1n`

### 3.2 Executar os Comandos de Configuração do CIFS
Dentro do prompt do ONTAP (`fsx::>`):

```bash
# 1. Criar o servidor CIFS em modo Workgroup na SVM svmpoc
vserver cifs create -vserver svmpoc -cifs-server FSXSMB -workgroup WORKGROUP

# 2. Criar o usuário local smbuser
vserver cifs users-and-groups local-user create -vserver svmpoc -user-name smbuser

# 3. Definir a senha do usuário smbuser (digite Fsx@dm1n quando solicitado)
vserver cifs users-and-groups local-user set-password -vserver svmpoc -user-name smbuser

# 4. Criar os shares SMB para AMBOS os volumes (NTFS e UNIX)
vserver cifs share create -vserver svmpoc -share-name vol_smb -path /vol_smb
vserver cifs share create -vserver svmpoc -share-name vol_nfs -path /vol_nfs

# 5. Comandos de Verificação e Validação
vserver cifs users-and-groups local-user show -vserver svmpoc
vserver cifs share access-control show -vserver svmpoc
vserver security file-directory show -vserver svmpoc -path /vol_nfs
vserver security file-directory show -vserver svmpoc -path /vol_smb
volume show -vserver svmpoc -volume vol_smb -fields volume,security-style,junction-path
```

Digite `exit` para sair da CLI do ONTAP e retornar ao terminal da EC2 Linux.

---

## 4. Montagem dos Volumes nos Clientes

Obtenha o DNS da SVM no console do FSx (ex: `svm-007291e2eb8158be3.fs-0312dff317496811b.fsx.us-east-1.amazonaws.com`).

### 4.1 No EC2 Linux (via SSM Session)
Execute como root (`sudo su -`):

```bash
# Criar diretórios de montagem
mkdir -p /mnt/nfs /mnt/smb

# Montar o volume NFS
mount -t nfs <svm_dns_name>:/vol_nfs /mnt/nfs

# Montar o volume SMB (CIFS)
mount -t cifs //<svm_dns_name>/vol_smb /mnt/smb -o username=smbuser,domain=FSXSMB,password=Fsx@dm1n,vers=3.0

# Validar montagens
df -hT | grep /mnt
```

### 4.2 No EC2 Windows (via SSM Session ou PowerShell)
Abra uma sessão SSM na instância Windows:
```bash
aws ssm start-session --target <windows_instance_id>
```

No PowerShell:
```powershell
# Credenciais do usuário SMB
$secPass = ConvertTo-SecureString "Fsx@dm1n" -AsPlainText -Force
$cred = New-Object System.Management.Automation.PSCredential("FSXSMB\smbuser", $secPass)

# Mapear volume NTFS (Z:) e volume UNIX (Y:)
New-PSDrive -Name Z -PSProvider FileSystem -Root "\\<svm_dns_name>\vol_smb" -Credential $cred
New-PSDrive -Name Y -PSProvider FileSystem -Root "\\<svm_dns_name>\vol_nfs" -Credential $cred

# Verificar unidades mapeadas
Get-PSDrive Z, Y
```

---

## 5. Testes Cruzados de Leitura e Escrita Bidirecional (Multi-Protocolo)

### 🧪 Teste 1: Windows cria arquivo ➔ Linux lê e edita

#### Cenário A: No Volume NTFS (`vol_smb`)
1. **No Windows (PowerShell)**:
   ```powershell
   "Arquivo criado pelo Windows no volume NTFS" | Out-File -FilePath Z:\win_created_ntfs.txt -Encoding ascii
   ```
2. **No Linux**:
   ```bash
   cat /mnt/smb/win_created_ntfs.txt
   echo "Linha adicionada pelo Linux no volume NTFS" >> /mnt/smb/win_created_ntfs.txt
   ```
3. **No Windows (validar edição)**:
   ```powershell
   Get-Content Z:\win_created_ntfs.txt
   ```

#### Cenário B: No Volume UNIX (`vol_nfs`)
1. **No Windows (PowerShell)**:
   ```powershell
   "Arquivo criado pelo Windows no volume UNIX" | Out-File -FilePath Y:\win_created_unix.txt -Encoding ascii
   ```
2. **No Linux**:
   ```bash
   cat /mnt/nfs/win_created_unix.txt
   echo "Linha adicionada pelo Linux no volume UNIX" >> /mnt/nfs/win_created_unix.txt
   ```
3. **No Windows (validar edição)**:
   ```powershell
   Get-Content Y:\win_created_unix.txt
   ```

---

### 🧪 Teste 2: Linux cria arquivo ➔ Windows lê e edita

> [!IMPORTANT]
> **Ajuste de Permissões (`chmod 666`):**  
> Quando um arquivo é criado no Linux em um volume com security-style `UNIX`, as permissões padrão do Linux (umask) geralmente concedem escrita apenas ao proprietário (ex: `root`).  
> O usuário SMB do Windows (`smbuser`) mapeia para um usuário sem privilégios UNIX (`pcuser` / `nobody`). Portanto, para permitir que o Windows edite o arquivo criado no Linux, é **necessário** liberar permissão de escrita para outros com `chmod 666`.

#### Cenário A: No Volume UNIX (`vol_nfs`)
1. **No Linux**:
   ```bash
   echo "Arquivo criado pelo Linux no volume UNIX" > /mnt/nfs/linux_created_unix.txt
   
   # Alterar permissões para permitir que o Windows edite
   chmod 666 /mnt/nfs/linux_created_unix.txt
   ls -l /mnt/nfs/linux_created_unix.txt
   ```
2. **No Windows (PowerShell)**:
   ```powershell
   Get-Content Y:\linux_created_unix.txt
   Add-Content -Path Y:\linux_created_unix.txt -Value "Linha adicionada pelo Windows no volume UNIX"
   ```
3. **No Linux (validar edição)**:
   ```bash
   cat /mnt/nfs/linux_created_unix.txt
   ```

#### Cenário B: No Volume NTFS (`vol_smb`)
1. **No Linux**:
   ```bash
   echo "Arquivo criado pelo Linux no volume NTFS" > /mnt/smb/linux_created_ntfs.txt
   chmod 666 /mnt/smb/linux_created_ntfs.txt
   ```
2. **No Windows (PowerShell)**:
   ```powershell
   Get-Content Z:\linux_created_ntfs.txt
   Add-Content -Path Z:\linux_created_ntfs.txt -Value "Linha adicionada pelo Windows no volume NTFS"
   ```
3. **No Linux (validar edição)**:
   ```bash
   cat /mnt/smb/linux_created_ntfs.txt
   ```

---

## 6. Referência Prática com Endpoints Reais

Abaixo estão os comandos consolidados com o padrão de endpoints utilizados durante os testes reais de laboratório:

```bash
# 1. SSH na CLI de Gerência do ONTAP a partir do Linux:
ssh fsxadmin@management.fs-0312dff317496811b.fsx.us-east-1.amazonaws.com
# Password: Fsx@dm1n

# 2. Configurações ONTAP executadas:
vserver cifs create -vserver svmpoc -cifs-server FSXSMB -workgroup WORKGROUP
vserver cifs users-and-groups local-user create -vserver svmpoc -user-name smbuser
vserver cifs users-and-groups local-user set-password -vserver svmpoc -user-name smbuser
vserver cifs share create -vserver svmpoc -share-name vol_smb -path /vol_smb
vserver cifs share create -vserver svmpoc -share-name vol_nfs -path /vol_nfs

# 3. Montagens no Linux:
sudo mkdir -p /mnt/nfs /mnt/smb
sudo mount -t nfs svm-007291e2eb8158be3.fs-0312dff317496811b.fsx.us-east-1.amazonaws.com:/vol_nfs /mnt/nfs
sudo mount -t cifs //svm-007291e2eb8158be3.fs-0312dff317496811b.fsx.us-east-1.amazonaws.com/vol_smb /mnt/smb -o username=smbuser,domain=FSXSMB,password=Fsx@dm1n,vers=3.0

# 4. Ajuste de permissão de teste:
chmod 666 /mnt/nfs/linux_test.txt

# 5. Caminhos UNC para acesso no Windows:
# \\svm-007291e2eb8158be3.fs-0312dff317496811b.fsx.us-east-1.amazonaws.com\vol_smb
# \\svm-007291e2eb8158be3.fs-0312dff317496811b.fsx.us-east-1.amazonaws.com\vol_nfs
# Usuário: FSXSMB\smbuser
# Senha:   Fsx@dm1n
```

---

## 7. Destruição do Ambiente e Limpeza de Network Interfaces (NICs/ENIs)

> [!CAUTION]
> **Ordem Obrigatória de Destruição:**
> 1. Deletar os Volumes e o File System (sem criar backups).
> 2. Validar e excluir as **Network Interfaces (ENIs/NICs)** criadas pelo FSx no **AWS CloudShell**.
> 3. Só então executar o `terraform destroy`.
> 
> Se tentar rodar o `terraform destroy` antes da liberação das ENIs, a VPC e os Security Groups ficarão **travados com erro de `DependencyViolation`**.

---

### 7.1 Deletando os Recursos do FSx

Você pode optar por deletar via **AWS Console** ou via **AWS CLI**:

#### Opção A: Pelo Console AWS
1. **Deletar Volumes**: Vá em FSx > Volumes > Selecione o volume (`vol_nfs` e `vol_smb`) > Actions > **Delete volume**.
   - ⚠️ **MUITO IMPORTANTE**: Na janela de confirmação, **DESMARQUE** a opção *"Create final backup"* (ou escolha *"Do not create final backup"*). Digite o nome do volume e confirme.
2. **Deletar SVM**: Vá em Storage Virtual Machines > Selecione `svmpoc` > Actions > **Delete storage virtual machine**.
3. **Deletar File System**: Vá em File Systems > Selecione `fsx-ontap-poc-fs` > Actions > **Delete file system**.
   - ⚠️ **MUITO IMPORTANTE**: Na janela de confirmação, **DESMARQUE** a opção *"Create final backup"*. Digite o ID do File System e confirme.
   - *Aguarde alguns minutos até que o File System desapareça completamente do console.*

#### Opção B: Pelo AWS CLI
```bash
# 1. Deletar Volumes ignorando Final Backup
aws fsx delete-volume --volume-id <VOL_NFS_ID>
aws fsx delete-volume --volume-id <VOL_SMB_ID>

# 2. Deletar a Storage Virtual Machine (SVM)
aws fsx delete-storage-virtual-machine --storage-virtual-machine-id <SVM_ID>

# 3. Deletar o File System ignorando Final Backup
aws fsx delete-file-system --file-system-id <FSX_ID> --skip-final-backup
```

---

### 7.2 Limpeza das Network Interfaces (ENIs) no AWS CloudShell

Ao criar o FSx, a AWS anexa interfaces de rede elásticas (ENIs) na Subnet Privada associadas ao Security Group do FSx. Mesmo após deletar o FSx, algumas ENIs podem permanecer como "órfãs" ou demorar para desanexar, impedindo o Terraform de destruir a VPC e a Subnet.

Abra o **AWS CloudShell** no console AWS (ou utilize seu terminal local com AWS CLI) e execute o script de limpeza de ENIs:

#### Executar o script automatizado:
```bash
# Baixar ou colar o conteúdo de scripts/cleanup-enis.sh e executar:
bash scripts/cleanup-enis.sh
```

#### Ou execute os comandos manuais no CloudShell:
```bash
# 1. Obter o ID da VPC do projeto
VPC_ID=$(aws ec2 describe-vpcs --filters "Name=tag:Project,Values=fsx-ontap-poc" --query "Vpcs[0].VpcId" --output text)

# 2. Listar todas as ENIs residuais na VPC do FSx
aws ec2 describe-network-interfaces \
  --filters "Name=vpc-id,Values=$VPC_ID" \
  --query "NetworkInterfaces[].[NetworkInterfaceId,Status,Description]" \
  --output table

# 3. Excluir ENIs residuais que estiverem com status 'available'
# (Substitua <ENI_ID> pelo ID da interface listada acima)
aws ec2 delete-network-interface --network-interface-id <ENI_ID>
```

---

### 7.3 Destruir a Infraestrutura Adjacente via Terraform

Após validar no CloudShell que nenhuma interface de rede residual do FSx está vinculada à VPC/Subnet, execute a destruição completa da infraestrutura base:

```bash
cd terraform
terraform destroy
```
Digite `yes` para confirmar. Todos os recursos (VPC, Subnets, EC2s, Security Groups, IAM Roles) serão destruídos de forma limpa e sem erros de dependência!
