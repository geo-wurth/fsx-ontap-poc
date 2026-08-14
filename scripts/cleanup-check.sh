#!/bin/bash
# ==============================================================================
# Script: cleanup-check.sh
# Finalidade: Verificar se ainda existem recursos ou dependências residuais da POC.
# ==============================================================================

PROJECT_TAG="fsx-ontap-poc"

echo "=== Verificação Completa de Limpeza ==="
echo "Procurando recursos associados à POC..."

VPC_ID=$(aws ec2 describe-vpcs --filters "Name=tag:Project,Values=$PROJECT_TAG" --query "Vpcs[].VpcId" --output text)
EC2_IDS=$(aws ec2 describe-instances --filters "Name=tag:Project,Values=$PROJECT_TAG" "Name=instance-state-name,Values=running,stopped,pending,shutting-down" --query "Reservations[].Instances[].InstanceId" --output text)
FSX_IDS=$(aws fsx describe-file-systems --query "FileSystems[?Tags[?Key=='Project' && Value=='$PROJECT_TAG']].FileSystemId" --output text)
BACKUPS=$(aws fsx describe-backups --query "Backups[?Tags[?Key=='Project' && Value=='$PROJECT_TAG']].BackupId" --output text)

CLEAN=true

if [ -n "$VPC_ID" ]; then
    echo "Encontrada VPC: $VPC_ID"
    CLEAN=false
    
    # Checar ENIs remanescentes na VPC
    ENIS=$(aws ec2 describe-network-interfaces --filters "Name=vpc-id,Values=$VPC_ID" --query "NetworkInterfaces[].[NetworkInterfaceId,Status,Description]" --output text)
    if [ -n "$ENIS" ]; then
        echo "  -> ENIs presentes na VPC:"
        echo "$ENIS"
    fi
fi

if [ -n "$EC2_IDS" ]; then
    echo "Encontradas Instâncias EC2: $EC2_IDS"
    CLEAN=false
fi

if [ -n "$FSX_IDS" ]; then
    echo "Encontrado FSx: $FSX_IDS"
    CLEAN=false
fi

if [ -n "$BACKUPS" ]; then
    echo "Encontrados Backups residuais: $BACKUPS"
    CLEAN=false
fi

echo "----------------------------------------------------"
if [ "$CLEAN" = true ]; then
    echo "✅ CLEAN: Nenhum recurso órfão encontrado na conta!"
else
    echo "⚠️ ATENÇÃO: Ainda existem recursos ativos listados acima."
    echo "Caso vá rodar 'terraform destroy', certifique-se de que o FSx e suas ENIs foram excluídos."
fi
