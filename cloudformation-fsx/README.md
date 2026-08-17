# Variação CloudFormation (MVP / Produção) para Amazon FSx for NetApp ONTAP

Este módulo é uma tradução do modelo `terraform-fsx` para a linguagem nativa da AWS: **AWS CloudFormation**. 
Ele foi desenvolvido como um MVP para o ambiente pós-POC (produção real), integrando a Storage Virtual Machine (SVM) ao **Active Directory**, implantando Volumes (SMB e NFS), habilitando as políticas de Tiering, Storage Efficiency e garantindo os backups necessários para proteção e retenção dos dados.

## 📁 Estrutura de Arquivos

- `fsx-ontap.yaml`: O template principal do CloudFormation escrito em YAML. Nele estão definidos o cluster FSx, a SVM com a configuração condicional do Active Directory e os dois volumes base (`vol_smb` e `vol_nfs`).
- `parameters-example.json`: Arquivo em JSON exemplificando os parâmetros necessários. Serve como alternativa às respostas interativas para acelerar a implantação via CLI.

## 🚀 Como fazer o Deploy

### Opção 1: Via AWS Console (Interface Gráfica)
1. Acesse o **AWS CloudFormation** no painel da AWS.
2. Clique em **Create stack** (With new resources).
3. Em *Prerequisite - Prepare template*, escolha **Template is ready**.
4. Em *Specify template*, escolha **Upload a template file** e selecione o arquivo `fsx-ontap.yaml` deste diretório.
5. Em *Specify stack details*, informe um nome (ex: `fsx-ontap-mvp`) e preencha todos os parâmetros requeridos.
6. Avance, revise as configurações e clique em **Submit**.

### Opção 2: Via AWS CLI (Terminal)
Utilizando o arquivo de parâmetros JSON:

1. Faça uma cópia do arquivo de exemplo para evitar commitar credenciais no git:
   ```bash
   cp parameters-example.json my-parameters.json
   ```
2. Edite `my-parameters.json` e insira suas credenciais reais (como `FsxAdminPassword`, IDs das Subnets e senha de serviço do AD).
3. Execute o comando de criação da Stack:
   ```bash
   aws cloudformation create-stack \
       --stack-name fsx-ontap-mvp \
       --template-body file://fsx-ontap.yaml \
       --parameters file://my-parameters.json
   ```
   > O comando retorna um `StackId`. Acompanhe o progresso no console da AWS ou com o comando:
   > `aws cloudformation describe-stacks --stack-name fsx-ontap-mvp`

---

## 🛡️ Gestão de Backups e Destruição (Pós-POC)

> [!CAUTION]
> **Deletando a Stack**  
> Como este ambiente foi projetado para um cenário "Pós-POC" (Produção), a propriedade de exclusão dos volumes (`AWS::FSx::Volume`) está definida com:
> ```yaml
> DeletionPolicy: Snapshot
> UpdateReplacePolicy: Snapshot
> ```
> Isso significa que **ao excluir a Stack no CloudFormation, a AWS irá reter e gerar um Snapshot final desses volumes** (o que equivale ao `skip_final_backup = false` do Terraform). 
> 
> Se você quiser apagar a infraestrutura **definitivamente** sem gerar e reter os dados finais, precisará editar temporariamente o arquivo `fsx-ontap.yaml`, alterando `DeletionPolicy: Snapshot` para `DeletionPolicy: Delete` e fazer o update da Stack antes de deletar, ou apagar os snapshots gerados manualmente no painel posteriormente.

Para excluir a stack via CLI:
```bash
aws cloudformation delete-stack --stack-name fsx-ontap-mvp
```
