# Terraform - FSx for NetApp ONTAP POC

Este diretório contém a infraestrutura como código para provisionar os recursos mínimos da POC na AWS.

## Como utilizar

1. Copie o arquivo de variáveis de exemplo:
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```
2. Modifique os valores no arquivo `terraform.tfvars` caso deseje alterar região, tamanho de discos ou senha do fsxadmin. A senha precisa ser forte.
3. Inicialize o Terraform:
   ```bash
   terraform init
   ```
4. Verifique o plano de execução:
   ```bash
   terraform plan
   ```
5. Aplique as modificações para criar a infraestrutura:
   ```bash
   terraform apply
   ```

## Notas sobre destruição
Ao terminar a POC, não esqueça de rodar `terraform destroy` para não manter recursos que geram custos. O FSx está configurado para **não gerar backup final** ao ser destruído.
