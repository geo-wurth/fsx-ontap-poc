# Terraform - Infraestrutura Adjacente para FSx ONTAP POC

Este diretório contém a infraestrutura como código para provisionar a rede, instâncias de teste (Linux e Windows) e regras de firewall (Security Groups) necessários para a POC. **O File System FSx não é criado por este código.**

## Como utilizar

1. Copie o arquivo de variáveis de exemplo:
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```
2. Modifique os valores no arquivo `terraform.tfvars` caso deseje alterar região ou tamanhos das instâncias.
3. Inicialize o Terraform:
   ```bash
   terraform init
   ```
4. Aplique as modificações para criar a infraestrutura:
   ```bash
   terraform apply
   ```
5. Guarde os **Outputs** exibidos ao final. Você precisará do `private_subnet_id` e do `fsx_security_group_id` para criar o FSx manualmente na AWS.

## Notas sobre destruição
Ao terminar a POC, não esqueça de rodar `terraform destroy`. 
**ATENÇÃO:** O `terraform destroy` só funcionará corretamente se você destruir manualmente o FSx for NetApp ONTAP que foi criado pelo console ANTES, pois o FSx possui dependências de rede com a Subnet e Security Group criados aqui.
