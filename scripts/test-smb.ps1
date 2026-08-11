# Script para testar mapeamento SMB no Windows (Execute via PowerShell)

Write-Host "=== Teste SMB ==="

$smbDns = Read-Host "Informe o DNS SMB Endpoint da SVM"
$smbUser = Read-Host "Informe o usuário SMB criado (ex: smbuser)"
$smbPass = Read-Host -AsSecureString "Informe a senha do usuário SMB"

$sharePath = "\\$smbDns\pocshare"
$driveLetter = "Z:"

Write-Host "Verificando conectividade na porta 445..."
$tcpTest = Test-NetConnection -ComputerName $smbDns -Port 445
if ($tcpTest.TcpTestSucceeded) {
    Write-Host "[OK] Conexão TCP 445 bem sucedida."
} else {
    Write-Host "[FALHA] Falha na conexão TCP 445."
    exit
}

Write-Host "Mapeando $sharePath para a unidade $driveLetter..."
$credential = New-Object System.Management.Automation.PSCredential("SMB-POC\$smbUser", $smbPass)

New-PSDrive -Name Z -PSProvider FileSystem -Root $sharePath -Credential $credential | Out-Null

if (Test-Path "$driveLetter\") {
    Write-Host "[OK] Share SMB mapeado com sucesso."
} else {
    Write-Host "[ERRO] Falha ao mapear share."
    exit
}

$testFile = "$driveLetter\teste_smb.txt"

Write-Host "Criando arquivo de teste em $testFile..."
"Arquivo de teste criado pelo Windows no volume SMB" | Out-File -FilePath $testFile

if (Test-Path $testFile) {
    Write-Host "[OK] Arquivo criado."
    Write-Host "Conteúdo:"
    Get-Content $testFile
    
    Write-Host "Removendo arquivo..."
    Remove-Item $testFile
} else {
    Write-Host "[ERRO] Não foi possível gravar no disco."
}

Write-Host "Desmontando a unidade..."
Remove-PSDrive -Name Z
Write-Host "[OK] Drive removido."

Write-Host "=== Teste finalizado com sucesso! ==="
