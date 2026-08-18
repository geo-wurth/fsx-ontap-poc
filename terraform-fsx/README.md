# Amazon FSx for NetApp ONTAP - Infrastructure as Code (IaC)

Este diretório contém os módulos do **Terraform** necessários para o provisionamento automatizado do Amazon FSx for NetApp ONTAP em um ambiente produtivo (Pós-POC). A arquitetura inclui a implantação do File System primário, criação de uma Storage Virtual Machine (SVM) com integração ao Active Directory e o provisionamento de volumes lógicos com protocolos SMB e NFS.

---

## 📋 Pré-requisitos e Configuração Básica

Antes de iniciar a implantação, certifique-se de que a infraestrutura base já esteja provisionada. Este módulo pressupõe a existência de:
- **VPC e Subnets**: No mínimo uma subnet privada para implementações *Single-AZ* ou duas subnets para implementações *Multi-AZ*.
- **Security Groups**: Um Security Group associado às interfaces do FSx que permita o tráfego nas portas de gerência (SSH 22, HTTPS 443) e dados (NFS 2049, SMB 445).
- **Active Directory**: Um domínio funcional com acesso de rede a partir das subnets designadas para o FSx.

---

## ⚙️ Variáveis de Configuração

As configurações do projeto são gerenciadas através do arquivo de variáveis. Para iniciar, crie uma cópia do arquivo de exemplo:
```bash
cp terraform.tfvars.example terraform.tfvars
```

### Principais Variáveis e Tags de Identificação
O projeto utiliza um sistema de _locals_ dinâmico (no arquivo `locals.tf`) para padronização de tags em todos os recursos gerados:
- `projeto`: Nome do projeto (ex: `fsx-ontap-poc`).
- `owner`: Equipe responsável (ex: `time-infra`).
- `shared`: Booleano identificando se o recurso é compartilhado.
- `stack`: Nome da stack tecnológica (ex: `storage`).
- `iac`: Ferramenta de IaC em uso (`terraform`).

### Dimensionamento e Capacidade
- `deployment_type`: Escolha entre `SINGLE_AZ_1` ou `MULTI_AZ_1`.
- `storage_capacity_gib`: Capacidade inicial mínima de 1024 GiB (SSD).
- `throughput_capacity_mbps`: Capacidade de banda suportada pelo File System (ex: `128`).

### Segurança e Active Directory
- Senhas administrativas (`fsx_admin_password`, `svm_admin_password`) configuradas de forma sensível e bloqueadas contra exibição em logs nativos.
- Bloco do Active Directory condicionado via `join_active_directory`, mapeando o nome de domínio, IPs dos servidores DNS e as credenciais das contas de serviço para promover o ingresso autônomo do file system no domínio.

### Gestão de Volumes e Backups
- `volumes`: Um mapa estruturado (Object Map) contendo as políticas de armazenamento de volumes independentes, incluindo regras de *Storage Efficiency* (Deduplicação/Compressão ativadas) e diretrizes de *Tiering* automatizado para S3 (`AUTO`, `SNAPSHOT_ONLY`, etc).
- `skip_final_backup`: Controle individual em cada volume para decidir se a AWS deve reter um Snapshot de segurança durante a execução de um `terraform destroy`. O valor `false` (padrão) assegura a retenção e é indicado para cenários de produção.

---

## 🚀 Instalação do Terraform (Versão 1.5.7)

Neste projeto, utilizamos a versão **1.5.7** do Terraform. Esta é a **última versão estável lançada sob a licença open-source (MPL)** antes da transição comercial da HashiCorp para a licença BSL (Business Source License). Manter esta versão garante total conformidade e uso livre em ambientes corporativos e esteiras de automação, sem incorrer em restrições comerciais.

Caso você esteja operando a partir do terminal do **AWS CloudShell** ou em um ambiente local Linux, o binário pode não estar presente ou estar em uma versão diferente. Siga as instruções abaixo para realizar o download direto e a instalação limpa da versão especificada.

### Download e Instalação via CLI
Instale os pacotes de pré-requisito (`wget` e `unzip`), faça o download do binário oficial da HashiCorp e extraia-o no diretório de executáveis do sistema.

Para sistemas baseados em **Amazon Linux 2023**, **RHEL 8+** ou **Fedora** (usando `dnf`):
```bash
sudo dnf install -y wget unzip
wget https://releases.hashicorp.com/terraform/1.5.7/terraform_1.5.7_linux_amd64.zip
sudo unzip terraform_1.5.7_linux_amd64.zip -d /usr/local/bin/
```

Para sistemas baseados em **Amazon Linux 2** ou **CentOS 7** (usando `yum` em substituição ao `dnf`):
```bash
sudo yum install -y wget unzip
wget https://releases.hashicorp.com/terraform/1.5.7/terraform_1.5.7_linux_amd64.zip
sudo unzip terraform_1.5.7_linux_amd64.zip -d /usr/local/bin/
```

Verifique a instalação para garantir que a versão `1.5.7` foi configurada com sucesso no seu `PATH` e atende à política restritiva contida no arquivo `versions.tf` (`~> 1.5.0`):
```bash
terraform version
```

---

## 🛠️ Execução: Planejamento e Implantação

Após configurar devidamente suas credenciais da AWS e preencher os parâmetros obrigatórios no arquivo `terraform.tfvars`, a esteira de implantação se resume a 3 passos primordiais:

### 1. Inicialização do Backend
Processo que valida as dependências do código e faz o download seguro da versão do Provider oficial da AWS definida em nossos módulos.
```bash
terraform init
```

### 2. Validação e Planejamento (Plan)
Verifica a consistência e a integridade de sintaxe do código HCL. O comando `plan` faz a leitura do ambiente contra a API da AWS (simulando a execução) e compila um relatório preciso do que será alterado ou criado, salvando essas intenções no binário `tfplan`.
```bash
terraform validate
terraform plan -out=tfplan
```
> **Nota de Governança:** Inspecione cuidadosamente o plano retornado na tela. É nesta etapa de "Dry-Run" que o arquiteto aprova a coerência do dimensionamento de storage, as portas de sub-rede e as identificações de tags que serão associadas.

### 3. Implantação Efetiva (Apply)
Se os resultados do plano estiverem de acordo com a arquitetura homologada, execute o script de aplicação apontando para o arquivo de plano previamente inspecionado.
```bash
terraform apply tfplan
```
> ⏱️ **Observação:** O processo de provisionamento de novos Clusters FSx ONTAP (em especial configurações Multi-AZ atreladas com domínios LDAP/Active Directory) pode demorar **entre 30 a 60 minutos** até que o estado de todos os componentes atinja o flag `Available`.

---

## 🧹 Destruição e Limpeza Controlada (Clean-up)

Para realocação ou desmonte da infraestrutura sem risco de criar inconsistências, garanta que os bloqueios de rede estejam suspensos e execute a destruição em cadeia de baixo para cima (Volumes ➔ SVM ➔ Cluster). O Terraform orquestra as deleções automaticamente com este comando:

```bash
terraform destroy
```
