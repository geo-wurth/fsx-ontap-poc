# Amazon FSx for NetApp ONTAP POC

Este projeto cria uma infraestrutura mínima na AWS para testar o funcionamento do Amazon FSx for NetApp ONTAP. O ambiente inclui uma VPC com subnets pública e privada, uma instância Linux, uma instância Windows. **O provisionamento do FSx ONTAP é realizado manualmente.**

## Custos

> [!WARNING]
> Este projeto provisiona recursos que geram custos na AWS. Certifique-se de destruir o ambiente após os testes para evitar cobranças indesejadas.

Os principais recursos que geram custos são:
- **FSx for NetApp ONTAP**: Cobrado por capacidade provisionada (SSD), throughput, e horas de execução. É o principal custo desta POC.
- **EC2**: Instâncias `t3.micro` e `t3.small` em execução.
- **EBS**: Volumes EBS anexados às instâncias EC2.

## Pré-requisitos

Para utilizar este projeto, você precisará de:
- [AWS CLI](https://aws.amazon.com/cli/) instalado e configurado com credenciais válidas.
- [Terraform](https://www.terraform.io/downloads.html) (versão >= 1.5.0) instalado.
- Permissões IAM na AWS para criar VPCs, EC2, IAM Roles, Security Groups, e recursos do FSx.
- Região AWS de sua preferência (ex: `us-east-1`).
- `fio` e utilitários NFS/SMB instalados localmente, caso deseje reproduzir testes de performance a partir da sua própria máquina via VPN (embora a POC utilize o SSM).

## Estrutura do projeto

- `terraform/`: Código de infraestrutura adjacente (VPC, Subnets, EC2, SG, IAM).
  - `versions.tf`: Definição da versão do Terraform e provider AWS.
  - `provider.tf`: Configuração do provider AWS.
  - `variables.tf`: Definição das variáveis de entrada.
  - `locals.tf`: Variáveis locais e tags comuns.
  - `network.tf`: Recursos de rede (VPC, Subnets, Route Tables, IGW).
  - `security.tf`: Security Groups para instâncias e FSx.
  - `iam.tf`: Role, Policy, e Instance Profile para uso do AWS Systems Manager (SSM).
  - `ec2.tf`: Definição das instâncias EC2 Linux e Windows.
  - `outputs.tf`: Valores de saída importantes após a criação.
  - `terraform.tfvars.example`: Exemplo de configuração de variáveis.
- `FSX_MANUAL_SETUP.md`: Guia para provisionamento manual do FSx for NetApp ONTAP via Console e CLI de destruição.
- `scripts/`: Scripts operacionais para configuração e teste do ONTAP.
  - `configure-ontap.sh`: Configura export policies, SMB shares e usuários locais via SSH no gerenciamento da SVM.
  - `test-connectivity.sh`: Valida a conectividade das EC2 para o FSx.
  - `test-nfs.sh`: Teste de montagem, leitura/escrita com NFS no Linux.
  - `test-smb.ps1`: Teste de mapeamento e uso do SMB no Windows.
  - `test-performance.sh`: Teste simples de throughput utilizando `fio`.
  - `cleanup-check.sh`: Valida se sobraram recursos na conta AWS após o destroy.

## Configuração

1. Acesse o diretório do Terraform:
   ```bash
   cd terraform
   ```

2. Crie seu arquivo de variáveis:
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```

3. Edite o arquivo `terraform.tfvars` se desejar alterar a região, bloco CIDR ou outros parâmetros.

## Inicialização e Criação da Infraestrutura Adjacente

```bash
terraform init
terraform apply
```
Confirme a execução digitando `yes`.

## Provisionamento do Storage (Manual)

Após o Terraform concluir, siga os passos do documento `FSX_MANUAL_SETUP.md` para criar o FSx, SVM e Volumes via Console da AWS. Você precisará dos outputs gerados pelo Terraform (`private_subnet_id`, `fsx_security_group_id`, etc.).

## Acesso às Instâncias (SSM Session Manager)

Não utilizamos SSH ou RDP diretamente com IP público. Todo acesso é via AWS Systems Manager.

**Acesso Linux**:
Substitua `<INSTANCE_ID>` pelo valor em `linux_instance_id` nos outputs.
```bash
aws ssm start-session --target <INSTANCE_ID>
```
Uma vez conectado, você pode assumir root com `sudo su -`.

**Acesso Windows**:
Substitua `<INSTANCE_ID>` pelo valor em `windows_instance_id` nos outputs.
```bash
aws ssm start-session --target <INSTANCE_ID>
```

## Configuração ONTAP

A configuração operacional (shares SMB, usuários, export policies) é feita através dos scripts.

> [!NOTE]
> Você precisará da senha `fsxadmin` que você definiu durante a criação manual no console.

Conecte-se na EC2 Linux via SSM, e execute:
```bash
bash scripts/configure-ontap.sh
```
Serão solicitados os endpoints que você obterá no console da AWS após a criação da SVM.

## Testes

Os testes devem ser executados dentro das respectivas instâncias (NFS no Linux, SMB no Windows).

- **Teste NFS**: `bash scripts/test-nfs.sh`
- **Teste SMB**: Execute o conteúdo de `scripts/test-smb.ps1` no PowerShell do Windows.
- **Teste de performance**: `bash scripts/test-performance.sh`

## Destruição

Para remover toda a infraestrutura e evitar cobranças, a destruição ocorre em duas etapas:

1. Destrua os recursos criados manualmente executando os comandos AWS CLI na seção de destruição do `FSX_MANUAL_SETUP.md`.
2. Após a exclusão do FSx ser concluída:
```bash
cd terraform
terraform destroy
```
Confirme com `yes`. 

## Verificação final

Após o `destroy`, execute o script de validação de limpeza para garantir que não ficaram recursos órfãos:
```bash
bash scripts/cleanup-check.sh
```
