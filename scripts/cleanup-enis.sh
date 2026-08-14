#!/bin/bash
# ==============================================================================
# Script: cleanup-enis.sh
# Finalidade: Identificar e excluir Network Interfaces (ENIs/NICs) e Backups órfãos
#             do FSx for ONTAP para destravar a VPC antes do terraform destroy.
# Execução: Executar no AWS CloudShell ou terminal com AWS CLI configurado.
# ==============================================================================

set -e

PROJECT_TAG="fsx-ontap-poc"

echo "============================================================"
echo "    🧹 Limpeza de ENIs e Recursos Órfãos do FSx (CloudShell)"
echo "============================================================"

# Obter VPC ID pela tag do projeto se existir
VPC_ID=$(aws ec2 describe-vpcs --filters "Name=tag:Project,Values=$PROJECT_TAG" --query "Vpcs[0].VpcId" --output text 2>/dev/null || true)
if [ "$VPC_ID" == "None" ] || [ -z "$VPC_ID" ]; then
    read -p "Informe o ID da VPC (ex: vpc-xxxxxx): " VPC_ID
fi

# Obter Security Group do FSx se existir
FSX_SG_ID=$(aws ec2 describe-security-groups --filters "Name=group-name,Values=fsx-ontap-poc-fsx" "Name=vpc-id,Values=$VPC_ID" --query "SecurityGroups[0].GroupId" --output text 2>/dev/null || true)

echo "VPC Alvo: $VPC_ID"
if [ "$FSX_SG_ID" != "None" ] && [ -n "$FSX_SG_ID" ]; then
    echo "Security Group do FSx: $FSX_SG_ID"
fi
echo "------------------------------------------------------------"

# 1. Verificar se ainda há File Systems FSx em exclusão
echo "[1/4] Verificando status de File Systems FSx..."
FSX_DELETING=$(aws fsx describe-file-systems --query "FileSystems[?VpcId=='$VPC_ID'].[FileSystemId,Lifecycle]" --output text)
if [ -n "$FSX_DELETING" ]; then
    echo "Aviso: Ainda existem File Systems no FSx nesta VPC:"
    echo "$FSX_DELETING"
    echo "Se o status estiver como 'DELETING', aguarde alguns minutos até que o FSx seja totalmente removido pela AWS antes de tentar deletar as interfaces."
fi

# 2. Localizar ENIs associadas ao FSx / Security Group do FSx na VPC
echo "[2/4] Buscando Network Interfaces (ENIs) associadas ao FSx..."

ENI_LIST=""
if [ "$FSX_SG_ID" != "None" ] && [ -n "$FSX_SG_ID" ]; then
    ENI_LIST=$(aws ec2 describe-network-interfaces --filters "Name=vpc-id,Values=$VPC_ID" "Name=group-id,Values=$FSX_SG_ID" --query "NetworkInterfaces[].[NetworkInterfaceId,Status,Description]" --output text)
fi

# Caso não encontre pelo SG, busca por descrição contendo FSx
if [ -z "$ENI_LIST" ]; then
    ENI_LIST=$(aws ec2 describe-network-interfaces --filters "Name=vpc-id,Values=$VPC_ID" --query "NetworkInterfaces[?contains(Description, 'FSx')].[NetworkInterfaceId,Status,Description]" --output text)
fi

if [ -z "$ENI_LIST" ]; then
    echo "✅ Nenhuma ENI residual do FSx foi encontrada."
else
    echo "ENIs identificadas:"
    echo "$ENI_LIST"
    echo ""
    read -p "Deseja tentar excluir as ENIs residuais agora? (s/N): " CONFIRM
    if [[ "$CONFIRM" =~ ^[sS]$ ]]; then
        echo "$ENI_LIST" | while read -r ENI_ID STATUS DESC; do
            if [ -n "$ENI_ID" ]; then
                echo "Processando ENI: $ENI_ID (Status: $STATUS)..."
                
                # Se estiver in-use, tenta forçar o detach
                if [ "$STATUS" == "in-use" ]; then
                    ATTACH_ID=$(aws ec2 describe-network-interfaces --network-interface-ids "$ENI_ID" --query "NetworkInterfaces[0].Attachment.AttachmentId" --output text 2>/dev/null || true)
                    if [ "$ATTACH_ID" != "None" ] && [ -n "$ATTACH_ID" ]; then
                        echo "  Desanexando interface $ENI_ID (Attachment: $ATTACH_ID)..."
                        aws ec2 detach-network-interface --attachment-id "$ATTACH_ID" --force 2>/dev/null || true
                        sleep 3
                    fi
                fi

                echo "  Excluindo interface $ENI_ID..."
                if aws ec2 delete-network-interface --network-interface-id "$ENI_ID" 2>/dev/null; then
                    echo "  ✅ ENI $ENI_ID excluída com sucesso!"
                else
                    echo "  ⚠️ Não foi possível excluir $ENI_ID imediatamente (pode estar sendo liberada pelo FSx)."
                fi
            fi
        done
    fi
fi

# 3. Verificar Backups do FSx residuais
echo "[3/4] Verificando backups residuais do FSx..."
BACKUPS=$(aws fsx describe-backups --query "Backups[?FileSystem.VpcId=='$VPC_ID'].[BackupId,Lifecycle,FileSystem.FileSystemId]" --output text 2>/dev/null || true)
if [ -n "$BACKUPS" ]; then
    echo "⚠️ Backups encontrados:"
    echo "$BACKUPS"
    read -p "Deseja excluir esses backups da POC para evitar custos? (s/N): " DEL_BACKUP
    if [[ "$DEL_BACKUP" =~ ^[sS]$ ]]; then
        echo "$BACKUPS" | while read -r BKP_ID STATUS FS_ID; do
            if [ -n "$BKP_ID" ]; then
                echo "Excluindo backup $BKP_ID..."
                aws fsx delete-backup --backup-id "$BKP_ID"
            fi
        done
        echo "✅ Backups excluídos!"
    fi
else
    echo "✅ Nenhum backup residual encontrado."
fi

# 4. Status Final
echo "[4/4] Validação de prontidão para o terraform destroy..."
REMAINING_ENIS=$(aws ec2 describe-network-interfaces --filters "Name=vpc-id,Values=$VPC_ID" "Name=group-id,Values=$FSX_SG_ID" --query "NetworkInterfaces[].NetworkInterfaceId" --output text 2>/dev/null || true)

if [ -z "$REMAINING_ENIS" ]; then
    echo "============================================================"
    echo "  🎉 PRONTO! Nenhuma ENI residual travando a VPC."
    echo "  Você pode executar 'terraform destroy' com segurança."
    echo "============================================================"
else
    echo "============================================================"
    echo "  ⚠️ Ainda restam as seguintes ENIs: $REMAINING_ENIS"
    echo "  Aguarde a AWS finalizar a exclusão do FSx ou remova-as."
    echo "============================================================"
fi
