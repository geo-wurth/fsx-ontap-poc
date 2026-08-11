#!/bin/bash
# Script para verificar recursos residuais da POC na AWS
# Requer AWS CLI autenticada com permissões de leitura.

PROJECT_TAG="fsx-ontap-poc"

echo "=== Verificação de Limpeza ==="
echo "Procurando recursos com a tag Project=$PROJECT_TAG..."

VPC_ID=$(aws ec2 describe-vpcs --filters "Name=tag:Project,Values=$PROJECT_TAG" --query "Vpcs[].VpcId" --output text)
EC2_IDS=$(aws ec2 describe-instances --filters "Name=tag:Project,Values=$PROJECT_TAG" "Name=instance-state-name,Values=running,stopped,pending,shutting-down" --query "Reservations[].Instances[].InstanceId" --output text)
FSX_IDS=$(aws fsx describe-file-systems --query "FileSystems[?Tags[?Key=='Project' && Value=='$PROJECT_TAG']].FileSystemId" --output text)

CLEAN=true

if [ -n "$VPC_ID" ]; then
    echo "Encontrado VPC: $VPC_ID"
    CLEAN=false
fi

if [ -n "$EC2_IDS" ]; then
    echo "Encontradas Instâncias EC2: $EC2_IDS"
    CLEAN=false
fi

if [ -n "$FSX_IDS" ]; then
    echo "Encontrado FSx: $FSX_IDS"
    CLEAN=false
fi

if [ "$CLEAN" = true ]; then
    echo "CLEAN"
    echo "Nenhum recurso órfão encontrado!"
else
    echo "=== ATENÇÃO: RECURSOS ENCONTRADOS ==="
    echo "Verifique o painel da AWS para remover os itens listados acima manualmente."
fi
