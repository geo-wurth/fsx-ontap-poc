# Script AWS CLI para Upload de Projetos

Esta pasta contém um script executável em Bash focado na criação automatizada de um bucket seguro no **Amazon S3**, seguido pelo upload sincronizado dos diretórios de código que criamos (Terraform e CloudFormation).

## 📁 Conteúdo

- `upload-to-s3.sh`: O script que fará todo o trabalho pesado no CLI da AWS.

## 🚀 Como Funciona?

O script executa o seguinte fluxo lógico de forma automatizada:
1. Gera um nome de Bucket **globalmente único** no S3 através de timestamp (ex: `fsx-ontap-templates-1715421298`).
2. Adiciona o **Bloqueio de Acesso Público Total** (Block Public Access) ao S3 criado, seguindo as melhores práticas de segurança da AWS.
3. Utiliza a função `aws s3 sync` para copiar todo o diretório `../terraform/` para o Bucket, **excluindo** automaticamente os resíduos de cache locais (estado `.tfstate`, diretórios `.terraform/`), que não devem ir para repositórios compartilhados se não estiverem em remote state configurado via backend.
4. Repete o mesmo processo para o diretório de produção `../terraform-fsx/`.
5. Por fim, copia também nosso modelo recém criado do `../cloudformation-fsx/`.

## ▶️ Como Executar (CloudShell / Linux)

Abra o seu AWS CloudShell ou qualquer terminal Linux autenticado com permissões na AWS, acesse essa pasta e execute:

```bash
# 1. Dê permissão de execução ao script (se ainda não tiver)
chmod +x upload-to-s3.sh

# 2. Execute o script
./upload-to-s3.sh
```

Ao final, ele vai imprimir na sua tela o comando exato para você validar se os arquivos estão corretos no Bucket, algo como `aws s3 ls s3://fsx-ontap-templates-<numero>/ --recursive`.
