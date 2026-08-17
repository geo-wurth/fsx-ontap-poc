#!/bin/bash
# ==============================================================================
# Script AWS CLI: Criação de S3 Bucket e Upload de Projetos Terraform / CFN
# ==============================================================================
# Este script cria um bucket seguro no S3 e envia os códigos do terraform e
# cloudformation, ignorando arquivos de estado temporários (.terraform, tfstate)
# ==============================================================================

# Se falhar em algum comando, o script aborta
set -e

# Nome do bucket precisa ser globalmente único, usamos timestamp para garantir
BUCKET_NAME="fsx-ontap-templates-$(date +%s)"
REGION="us-east-1"

echo "=========================================================="
echo "Iniciando criação do S3 Bucket e Upload dos arquivos IaC"
echo "=========================================================="

echo "1. Criando S3 Bucket: $BUCKET_NAME na região $REGION..."
# Se a região for diferente de us-east-1, a AWS exige o parâmetro LocationConstraint
if [ "$REGION" == "us-east-1" ]; then
    aws s3api create-bucket --bucket "$BUCKET_NAME" --region "$REGION" > /dev/null
else
    aws s3api create-bucket --bucket "$BUCKET_NAME" --region "$REGION" \
        --create-bucket-configuration LocationConstraint="$REGION" > /dev/null
fi

echo "2. Bloqueando acesso público (Segurança)..."
aws s3api put-public-access-block \
    --bucket "$BUCKET_NAME" \
    --public-access-block-configuration "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true" > /dev/null

echo "3. Fazendo upload da pasta terraform-fsx/ ..."
if [ -d "../terraform-fsx" ]; then
    aws s3 sync ../terraform-fsx "s3://$BUCKET_NAME/terraform-fsx/" \
        --exclude ".terraform/*" \
        --exclude ".terraform.lock.hcl" \
        --exclude "*.tfstate*" \
        --exclude "*.tfstate.backup"
else
    echo "⚠️ Diretório ../terraform-fsx não encontrado. Pulando."
fi

echo "=========================================================="
echo "✅ Sucesso! Seus arquivos foram copiados para: s3://$BUCKET_NAME"
echo "Para listar seus arquivos via CLI, execute:"
echo "aws s3 ls s3://$BUCKET_NAME/ --recursive"
echo "=========================================================="
