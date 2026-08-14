# Terraform - Infraestrutura Adjacente para FSx ONTAP POC

Este diretório contém a infraestrutura como código para provisionar a rede (VPC, Subnets, Route Tables, Internet Gateway), instâncias clientes (Linux e Windows) e regras de firewall (Security Groups) necessários para a POC.

> [!NOTE]
> O File System FSx for NetApp ONTAP **não** é provisionado via Terraform neste projeto; ele é criado manualmente conforme documentado no arquivo `FSX_MANUAL_SETUP.md`.

---

## 1. Abrindo o AWS CloudShell

O **AWS CloudShell** é um terminal pré-autenticado diretamente no navegador.

1. Faça login no **AWS Management Console**.
2. No canto superior direito (ou na barra de navegação superior), clique no ícone do CloudShell **`>_`** (ou digite "CloudShell" na barra de busca).
3. Verifique se a região selecionada no canto superior direito é a mesma que você utilizará para a POC (ex: **`us-east-1`** / N. Virginia).

---

## 2. Verificação e Instalação Oficial do Terraform

No terminal do CloudShell, verifique se o Terraform já está instalado:

```bash
terraform version
```

### Se o Terraform NÃO estiver instalado:
Execute os comandos oficiais da HashiCorp para instalação no Amazon Linux:

```bash
# 1. Instalar utilitários de gerenciamento de repositórios
sudo yum install -y yum-utils shadow-utils

# 2. Adicionar o repositório oficial da HashiCorp para Amazon Linux
sudo yum-config-manager --add-repo https://rpm.releases.hashicorp.com/AmazonLinux/hashicorp.repo

# 3. Instalar o Terraform
sudo yum -y install terraform

# 4. Validar a instalação
terraform -version
```

---

## 3. Preparação do Projeto no CloudShell

Navegue até a pasta do projeto (caso tenha clonado via Git ou enviado os arquivos para o CloudShell):

```bash
cd fsx-ontap-poc/terraform
```

---

## 4. Execução do Terraform

### Passo 1: Criar o arquivo de variáveis
```bash
cp terraform.tfvars.example terraform.tfvars
```
*(Opcional: edite com `nano terraform.tfvars` caso queira alterar a região ou tipos de instância).*

### Passo 2: Inicializar o provedor AWS
```bash
terraform init
```

### Passo 3: Planejar a execução
```bash
terraform plan
```

### Passo 4: Aplicar e criar os recursos
```bash
terraform apply
```
Digite `yes` para confirmar.

---

## 5. Outputs Importantes

Após a conclusão com sucesso, o Terraform exibirá os `Outputs`. Guarde especialmente:
- **`vpc_id`**: ID da VPC onde o FSx será criado.
- **`private_subnet_id`**: Subnet privada onde o FSx será alocado.
- **`fsx_security_group_id`**: Security Group com as portas NFS (111, 635, 2049), SMB (135, 139, 445) e ONTAP Mgmt (22, 443) liberadas.
- **`linux_instance_id`** e **`windows_instance_id`**: IDs para acesso via SSM Session Manager.

Com esses valores em mãos, prossiga para o arquivo `FSX_MANUAL_SETUP.md` na raiz do projeto para criar o storage.

---

## 6. Destruição da Infraestrutura

> [!CAUTION]
> **ATENÇÃO:** O comando `terraform destroy` só deve ser executado **DEPOIS** que você excluir os volumes, a SVM, o File System FSx e executar o script de limpeza de ENIs (`scripts/cleanup-enis.sh`). Caso contrário, a VPC ficará travada por dependências de rede.

Após a limpeza do storage e das ENIs no CloudShell, destrua a infraestrutura base com:

```bash
terraform destroy
```
Digite `yes` para confirmar a remoção completa.
