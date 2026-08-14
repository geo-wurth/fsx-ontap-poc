# Guia Completo de Provisionamento e Testes - Amazon FSx for NetApp ONTAP

Este documento contém o passo a passo detalhado para:
1. Identificar com clareza os **Endpoints** do FSx e da SVM.
2. Criar o File System FSx, a Storage Virtual Machine (SVM) e os Volumes no Console AWS.
3. Configurar o serviço CIFS/SMB no ONTAP para permitir acesso do Windows a volumes **NTFS** e **UNIX**.
4. Ajustar as permissões raiz no Linux (`chmod 777`) para desbloquear a gravação do Windows no volume UNIX.
5. Executar o **teste cruzado ordenado** (Windows Cria ➔ Linux Edita & Cria ➔ Windows Edita ➔ Linux Valida).
6. Destruir os recursos com limpeza de Network Interfaces (ENIs/NICs) no CloudShell.

---

## 🔑 Padrão de Credenciais da POC

Utilize a seguinte senha padrão em todas as etapas:
- **Senha Padrão**: `Fsx@dm1n`
- **Usuário Admin do File System**: `fsxadmin`
- **Usuário Admin da SVM**: `vsadmin`
- **Usuário Local SMB (Windows/Linux)**: `smbuser`

---

## 🧭 Guia Rápido de Endpoints: Onde pegar e onde usar?

O FSx for NetApp ONTAP fornece diferentes endpoints para finalidades distintas. Localize-os no Console da AWS:

| Nome do Endpoint | Onde localizar no Console AWS | Usuário / Porta | Para que serve? |
| :--- | :--- | :--- | :--- |
| **File System Management DNS** | **FSx** > **File systems** > Selecione `fsx-ontap-poc-fs` > Aba *Network & security* > *Management DNS name* | `fsxadmin`<br>Porta `22` (SSH) | **Acesso de Gerência Geral:** Usado para conectar via SSH a partir da EC2 Linux e rodar os comandos administrativos do ONTAP (`vserver cifs ...`). *(Ex: `management.fs-0312dff317496811b.fsx.us-east-1.amazonaws.com`)* |
| **SVM Management DNS** | **FSx** > **Storage virtual machines** > Selecione `svmpoc` > Aba *Endpoints* > *Management DNS name* | `vsadmin`<br>Porta `22` (SSH) | **Acesso de Gerência da SVM:** Alternativa para gerenciar exclusivamente a SVM `svmpoc`. |
| **SVM NFS / SMB DNS Name** | **FSx** > **Storage virtual machines** > Selecione `svmpoc` > Aba *Endpoints* > *NFS DNS name* / *SMB DNS name* | `smbuser`<br>Portas `2049` (NFS), `445` (SMB) | **Acesso aos Dados:** Usado no Linux para montar NFS/SMB (`/mnt/nfs`, `/mnt/smb`) e no Windows para mapear as unidades (`\\<endpoint>\vol_smb`, `\\<endpoint>\vol_nfs`). *(Ex: `svm-007291e2eb8158be3.fs-0312dff317496811b.fsx.us-east-1.amazonaws.com`)* |

---

## 🗺️ Topologia e Fluxo de Acesso entre as Máquinas

```
[Seu Computador / AWS Console]
        │
        ├── (AWS SSM Session Manager) ──> [EC2 Linux (Public Subnet)]
        │                                        │
        │                                        ├── (SSH porta 22) ──> [File System Management DNS (FSx CLI)]
        │                                        ├── (NFS porta 2049) ─> [SVM NFS DNS :/vol_nfs]
        │                                        └── (SMB porta 445) ──> [SVM SMB DNS :/vol_smb]
        │
        └── (AWS SSM Session Manager) ──> [EC2 Windows (Public Subnet)]
                                                 │
                                                 ├── (SMB porta 445) ──> [\\<SVM SMB DNS>\vol_smb (Z:)]
                                                 └── (SMB porta 445) ──> [\\<SVM SMB DNS>\vol_nfs (Y:)]
```

---

## 1. Pré-requisitos (Terraform)

No **AWS CloudShell**, execute o provisionamento da infraestrutura adjacente no diretório `terraform/`:
```bash
cd fsx-ontap-poc/terraform
terraform init
terraform apply
```

Anote os seguintes outputs:
- `vpc_id`
- `private_subnet_id`
- `fsx_security_group_id`
- `linux_instance_id` e `windows_instance_id`

---

## 2. Criação do FSx for NetApp ONTAP via Console AWS

### 2.1 Criar o File System
1. Acesse o **Amazon FSx** no Console AWS e clique em **Create file system**.
2. Selecione **Amazon FSx for NetApp ONTAP** > **Next**.
3. Escolha **Standard create**:
   - **File system name**: `fsx-ontap-poc-fs`
   - **Deployment type**: `Single-AZ`
   - **Storage capacity**: `1024` GiB (SSD)
   - **Throughput capacity**: `128` MB/s
   - **Virtual Private Cloud (VPC)**: Selecione o `vpc_id` do Terraform.
   - **VPC Security Groups**: Selecione o `fsx_security_group_id`. (*Remova o default*).
   - **Subnet**: Selecione a `private_subnet_id`.
   - **File system administrator password**: `Fsx@dm1n`
   - **Daily automatic backup**: **Desmarcar/Disable** (evita custos na POC).
4. Clique em **Next** e confirme em **Create file system**. *(Aguarde status `Available`)*.

### 2.2 Criar a Storage Virtual Machine (SVM)
1. No menu lateral, clique em **Storage virtual machines** > **Create storage virtual machine**.
2. Configure:
   - **File system**: `fsx-ontap-poc-fs`
   - **Storage virtual machine name**: `svmpoc`
   - **Root volume security style**: `UNIX`
   - **SVM administrator password**: `Fsx@dm1n`
3. Clique em **Create storage virtual machine**. *(Aguarde status `Available`)*.

### 2.3 Criar os Volumes (NFS e SMB)
No menu lateral, clique em **Volumes** > **Create volume**.

#### Volume 1: NFS (`vol_nfs`)
- **Storage virtual machine**: `svmpoc`
- **Volume name**: `vol_nfs`
- **Volume size**: `10` GiB
- **Junction path**: `/vol_nfs`
- **Security style**: `UNIX`
- **Snapshot policy**: `None`

#### Volume 2: SMB (`vol_smb`)
- **Storage virtual machine**: `svmpoc`
- **Volume name**: `vol_smb`
- **Volume size**: `10` GiB
- **Junction path**: `/vol_smb`
- **Security style**: `NTFS`
- **Snapshot policy**: `None`

---

## 3. Configuração do CIFS/SMB no ONTAP CLI

Configura o servidor CIFS, o usuário local e publica os dois volumes (`vol_smb` e `vol_nfs`) como compartilhamentos SMB para o Windows.

### 3.1 Conectar na CLI do ONTAP a partir do Linux
1. Abra uma sessão no **EC2 Linux** via AWS Systems Manager:
   ```bash
   aws ssm start-session --target <linux_instance_id>
   ```
2. Na EC2 Linux, conecte-se via SSH no **File System Management DNS**:
   ```bash
   ssh fsxadmin@<file_system_management_dns>
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

# 5. Comandos de Verificação
vserver cifs users-and-groups local-user show -vserver svmpoc
vserver cifs share access-control show -vserver svmpoc
vserver security file-directory show -vserver svmpoc -path /vol_nfs
vserver security file-directory show -vserver svmpoc -path /vol_smb
```

Digite `exit` para retornar ao terminal do Linux.

---

## 4. Montagem dos Volumes e Ajuste Obrigatório de Permissões

> [!IMPORTANT]
> **Por que ajustar a permissão da pasta `/mnt/nfs` para `777` no Linux?**  
> Por padrão, a raiz de um volume UNIX montado em Linux pertence ao usuário `root:root` com permissão `755` (`drwxr-xr-x`).  
> Quando o Windows conecta via SMB ao volume UNIX (`\\<svm_dns>\vol_nfs`), o ONTAP mapeia o usuário do Windows (`smbuser`) para um usuário sem privilégios UNIX (`nobody` / `pcuser`). Como `others` têm apenas permissão de leitura (`r-x`), o Windows **não conseguirá criar pastas nem arquivos** dentro do drive `Y:` a menos que o root no Linux execute `chmod 777 /mnt/nfs`.

### 4.1 No EC2 Linux: Montar e Liberar Permissões
Conectado na EC2 Linux (`sudo su -`):

```bash
# 1. Criar pontos de montagem
mkdir -p /mnt/nfs /mnt/smb

# 2. Montar o volume NFS (usando o SVM NFS DNS Name)
mount -t nfs <svm_nfs_dns_name>:/vol_nfs /mnt/nfs

# 3. Montar o volume SMB (usando o SVM SMB DNS Name)
mount -t cifs //<svm_smb_dns_name>/vol_smb /mnt/smb -o username=smbuser,domain=FSXSMB,password=Fsx@dm1n,vers=3.0

# 4. 🔑 AJUSTE OBRIGATÓRIO: Conceder permissão total na raiz do volume UNIX para o Windows poder criar arquivos
chmod 777 /mnt/nfs

# Validar montagens e permissões
df -hT | grep /mnt
ls -ld /mnt/nfs
```

### 4.2 No EC2 Windows: Mapear os Drives
Conecte-se na EC2 Windows via SSM Session Manager (`aws ssm start-session --target <windows_instance_id>`):

No PowerShell do Windows:
```powershell
# Definir credenciais do smbuser
$secPass = ConvertTo-SecureString "Fsx@dm1n" -AsPlainText -Force
$cred = New-Object System.Management.Automation.PSCredential("FSXSMB\smbuser", $secPass)

# Mapear Volume NTFS na unidade Z: e Volume UNIX na unidade Y:
New-PSDrive -Name Z -PSProvider FileSystem -Root "\\<svm_smb_dns_name>\vol_smb" -Credential $cred
New-PSDrive -Name Y -PSProvider FileSystem -Root "\\<svm_smb_dns_name>\vol_nfs" -Credential $cred

# Verificar unidades mapeadas
Get-PSDrive Z, Y
```

---

## 5. Testes Cruzados de Leitura e Escrita Bidirecional (Passo a Passo Ordenado)

Siga exatamente a ordem sequencial das 4 fases abaixo:

```
[Fase 1: Windows Cria] ──> [Fase 2: Linux Edita & Cria] ──> [Fase 3: Windows Valida & Edita] ──> [Fase 4: Linux Valida Final]
```

---

### 🟢 FASE 1: Windows ➔ Cria os Arquivos Iniciais

No PowerShell do **Windows**:

```powershell
# 1. Criar arquivo no volume NTFS (Z:)
"Linha 1: Arquivo criado pelo WINDOWS no volume NTFS." | Out-File -FilePath Z:\win_created_ntfs.txt -Encoding ascii

# 2. Criar arquivo no volume UNIX (Y:) [Funcionará perfeitamente graças ao chmod 777 feito na etapa 4]
"Linha 1: Arquivo criado pelo WINDOWS no volume UNIX." | Out-File -FilePath Y:\win_created_unix.txt -Encoding ascii

# Verificar criação
Get-ChildItem Z:\win_created_ntfs.txt, Y:\win_created_unix.txt
```

---

### 🟡 FASE 2: Linux ➔ Edita os Arquivos do Windows E Cria os Arquivos do Linux

No terminal do **Linux**:

#### 2.1 Editar os arquivos que o Windows criou:
```bash
# Ler e editar no volume NTFS (/mnt/smb)
cat /mnt/smb/win_created_ntfs.txt
echo -e "\nLinha 2: Editado com sucesso pelo LINUX no volume NTFS." >> /mnt/smb/win_created_ntfs.txt

# Ler e editar no volume UNIX (/mnt/nfs)
cat /mnt/nfs/win_created_unix.txt
echo -e "\nLinha 2: Editado com sucesso pelo LINUX no volume UNIX." >> /mnt/nfs/win_created_unix.txt
```

#### 2.2 Criar novos arquivos e aplicar `chmod 666`:
> [!IMPORTANT]
> O Linux cria arquivos com umask restritiva (`rw-r--r--`). Aplicamos `chmod 666` para que o usuário do Windows (`smbuser`) tenha permissão de gravar alterações neles.

```bash
# Criar no volume NTFS e liberar permissão
echo "Linha 1: Arquivo criado pelo LINUX no volume NTFS." > /mnt/smb/linux_created_ntfs.txt
chmod 666 /mnt/smb/linux_created_ntfs.txt

# Criar no volume UNIX e liberar permissão
echo "Linha 1: Arquivo criado pelo LINUX no volume UNIX." > /mnt/nfs/linux_created_unix.txt
chmod 666 /mnt/nfs/linux_created_unix.txt

# Validar permissões
ls -l /mnt/smb/linux_created_ntfs.txt /mnt/nfs/linux_created_unix.txt
```

---

### 🔵 FASE 3: Windows ➔ Valida Edições do Linux E Edita os Arquivos do Linux

No PowerShell do **Windows**:

#### 3.1 Validar se o Linux editou os arquivos criados na Fase 1:
```powershell
Write-Host "--- Validando Z:\win_created_ntfs.txt ---"
Get-Content Z:\win_created_ntfs.txt

Write-Host "--- Validando Y:\win_created_unix.txt ---"
Get-Content Y:\win_created_unix.txt
```

#### 3.2 Editar os arquivos criados pelo Linux na Fase 2:
```powershell
# Editar arquivo criado pelo Linux no volume NTFS (Z:)
Add-Content -Path Z:\linux_created_ntfs.txt -Value "Linha 2: Editado com sucesso pelo WINDOWS no volume NTFS."

# Editar arquivo criado pelo Linux no volume UNIX (Y:)
Add-Content -Path Y:\linux_created_unix.txt -Value "Linha 2: Editado com sucesso pelo WINDOWS no volume UNIX."
```

---

### 🟣 FASE 4: Linux ➔ Validação Final

No terminal do **Linux**, confirme que as edições feitas pelo Windows nos arquivos do Linux foram persistidas:

```bash
echo "=== Conteudo Final do Volume NTFS (/mnt/smb/linux_created_ntfs.txt) ==="
cat /mnt/smb/linux_created_ntfs.txt

echo "=== Conteudo Final do Volume UNIX (/mnt/nfs/linux_created_unix.txt) ==="
cat /mnt/nfs/linux_created_unix.txt
```

🎉 **Resultado:** Todos os cenários de leitura, escrita, criação cruzada e coexistência de protocolos (NFS e SMB) em volumes NTFS e UNIX foram validados com sucesso!

---

## 6. Referência Prática com Endpoints Reais

Comandos consolidados com o padrão de endpoints utilizados durante os testes de laboratório:

```bash
# 1. SSH na CLI do ONTAP a partir do Linux:
ssh fsxadmin@management.fs-0312dff317496811b.fsx.us-east-1.amazonaws.com
# Password: Fsx@dm1n

# 2. Configurações ONTAP:
vserver cifs create -vserver svmpoc -cifs-server FSXSMB -workgroup WORKGROUP
vserver cifs users-and-groups local-user create -vserver svmpoc -user-name smbuser
vserver cifs users-and-groups local-user set-password -vserver svmpoc -user-name smbuser
vserver cifs share create -vserver svmpoc -share-name vol_smb -path /vol_smb
vserver cifs share create -vserver svmpoc -share-name vol_nfs -path /vol_nfs

# 3. Montagens e Liberação de Permissão no Linux:
sudo mkdir -p /mnt/nfs /mnt/smb
sudo mount -t nfs svm-007291e2eb8158be3.fs-0312dff317496811b.fsx.us-east-1.amazonaws.com:/vol_nfs /mnt/nfs
sudo mount -t cifs //svm-007291e2eb8158be3.fs-0312dff317496811b.fsx.us-east-1.amazonaws.com/vol_smb /mnt/smb -o username=smbuser,domain=FSXSMB,password=Fsx@dm1n,vers=3.0
sudo chmod 777 /mnt/nfs

# 4. Mapeamento no Windows:
# Z: -> \\svm-007291e2eb8158be3.fs-0312dff317496811b.fsx.us-east-1.amazonaws.com\vol_smb
# Y: -> \\svm-007291e2eb8158be3.fs-0312dff317496811b.fsx.us-east-1.amazonaws.com\vol_nfs
# Usuário: FSXSMB\smbuser | Senha: Fsx@dm1n
```

---

## 7. Destruição do Ambiente e Limpeza de Network Interfaces (NICs/ENIs)

> [!CAUTION]
> **Ordem Obrigatória de Destruição:**
> 1. Deletar os Volumes e o File System (sempre desmarcando a criação de backups).
> 2. Validar e excluir as **Network Interfaces (ENIs/NICs)** criadas pelo FSx no **AWS CloudShell**.
> 3. Executar o `terraform destroy`.

---

### 7.1 Deletando os Recursos do FSx

#### Opção A: Pelo Console AWS
1. **Deletar Volumes**: FSx > Volumes > Selecione `vol_nfs` e `vol_smb` > Actions > **Delete volume**.
   - ⚠️ **DESMARQUE** a opção *"Create final backup"*. Digite o nome do volume e confirme.
2. **Deletar SVM**: Storage Virtual Machines > Selecione `svmpoc` > Actions > **Delete storage virtual machine**.
3. **Deletar File System**: File Systems > Selecione `fsx-ontap-poc-fs` > Actions > **Delete file system**.
   - ⚠️ **DESMARQUE** a opção *"Create final backup"*. Digite o ID do File System e confirme.
   - *Aguarde alguns minutos até que o status do File System desapareça do console.*

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

No **AWS CloudShell**:

```bash
# Executar o script automatizado de limpeza de ENIs:
bash scripts/cleanup-enis.sh
```

---

### 7.3 Destruir a Infraestrutura Adjacente via Terraform

Após o CloudShell confirmar que não restam ENIs associadas ao FSx:

```bash
cd terraform
terraform destroy
```
Digite `yes` para confirmar a remoção completa.
