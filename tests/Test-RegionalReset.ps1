# Execute somente em uma VM/runner Windows de teste.
# O teste altera HKCU e restaura o snapshot original ao terminar.
$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path -Parent $PSScriptRoot
$Backend = Join-Path $RepoRoot "suporte_teksoftware.ps1"
$Tokens = $null
$ParseErrors = $null
$Ast = [System.Management.Automation.Language.Parser]::ParseFile($Backend, [ref]$Tokens, [ref]$ParseErrors)
if ($ParseErrors.Count -gt 0) { throw ($ParseErrors | Out-String) }

$FunctionAst = $Ast.Find({
    param($Node)
    $Node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $Node.Name -eq "ResetarRegiaoMoedaPtBr"
}, $true)
if ($null -eq $FunctionAst) { throw "Funcao regional nao encontrada." }
# Carrega somente a funcao nova; nenhuma das outras acoes de suporte e executada.
Invoke-Expression $FunctionAst.Extent.Text
$script:Mensagens = New-Object System.Collections.Generic.List[string]
function LogMsg { param([string]$Texto) $script:Mensagens.Add($Texto) }
function Assert-Equal {
    param($Actual, $Expected, [string]$Label)
    if ([string]$Actual -cne [string]$Expected) {
        throw ("{0}: esperado '{1}', recebido '{2}'." -f $Label, $Expected, $Actual)
    }
}
function Read-Formats {
    Get-ItemProperty "HKCU:\Control Panel\International"
}
function Check-Formats {
    $Atual = Read-Formats
    $Padrao = New-Object System.Globalization.CultureInfo -ArgumentList @("pt-BR", $false)
    Assert-Equal $Atual.LocaleName "pt-BR" "Cultura"
    Assert-Equal $Atual.Locale "00000416" "LCID"
    Assert-Equal $Atual.sCurrency 'R$' "Moeda"
    Assert-Equal $Atual.sDecimal "," "Decimal numerico"
    Assert-Equal $Atual.sThousand "." "Milhar numerico"
    Assert-Equal $Atual.sMonDecimalSep "," "Decimal monetario"
    Assert-Equal $Atual.sMonThousandSep "." "Milhar monetario"
    Assert-Equal $Atual.iCurrDigits 2 "Casas monetarias"
    Assert-Equal $Atual.iCurrency $Padrao.NumberFormat.CurrencyPositivePattern "Moeda positiva"
    Assert-Equal $Atual.iNegCurr $Padrao.NumberFormat.CurrencyNegativePattern "Moeda negativa"
    Assert-Equal $Atual.iDigits $Padrao.NumberFormat.NumberDecimalDigits "Casas numericas"
    Assert-Equal $Atual.iNegNumber $Padrao.NumberFormat.NumberNegativePattern "Numero negativo"
    Assert-Equal $Atual.sShortDate $Padrao.DateTimeFormat.ShortDatePattern "Data curta"
    Assert-Equal $Atual.sTimeFormat $Padrao.DateTimeFormat.LongTimePattern "Hora"
    Assert-Equal (Get-WinHomeLocation).GeoId 32 "Localizacao"
    Assert-Equal (Get-TimeZone).Id $script:TimeZoneOriginal "Fuso preservado"
    Assert-Equal (Get-WinSystemLocale).Name $script:SystemLocaleOriginal "Localidade do sistema preservada"
    Assert-Equal (Get-WinUserLanguageList | ConvertTo-Json -Depth 5 -Compress) $script:LanguageListOriginal "Idiomas e teclados preservados"
    Assert-Equal (Get-WinUILanguageOverride | Out-String) $script:UIOriginal "Idioma de exibicao preservado"
}

$Snapshot = Join-Path $env:TEMP ("regional_test_" + [guid]::NewGuid().ToString("N") + ".reg")
& reg.exe export "HKCU\Control Panel\International" $Snapshot /y | Out-Null
if ($LASTEXITCODE -ne 0) { throw "Falha ao salvar snapshot de teste." }
$OriginalCulture = (Get-Culture).Name
$OriginalGeo = (Get-WinHomeLocation).GeoId
$script:TimeZoneOriginal = (Get-TimeZone).Id
$script:SystemLocaleOriginal = (Get-WinSystemLocale).Name
$script:LanguageListOriginal = Get-WinUserLanguageList | ConvertTo-Json -Depth 5 -Compress
$script:UIOriginal = Get-WinUILanguageOverride | Out-String

try {
    foreach ($Cultura in @("en-US", "pt-BR")) {
        Set-Culture $Cultura
        Set-WinHomeLocation -GeoId 244
        $Corrompidos = @{
            sCurrency = "TEST"; sDecimal = "!"; sThousand = "_"
            sMonDecimalSep = "!"; sMonThousandSep = "_"
            iCurrDigits = "4"; iCurrency = "3"; iNegCurr = "0"
            iDigits = "4"; iNegNumber = "0"
            sShortDate = "yyyy-MM-dd"; sTimeFormat = "h:mm:ss tt"
        }
        foreach ($Item in $Corrompidos.GetEnumerator()) {
            Set-ItemProperty "HKCU:\Control Panel\International" $Item.Key $Item.Value
        }
        $script:Mensagens.Clear()
        ResetarRegiaoMoedaPtBr
        Check-Formats
        $BackupMessage = @($script:Mensagens | Where-Object { $_ -like "Backup regional: *" })[0]
        $BackupPath = $BackupMessage.Substring("Backup regional: ".Length)
        if (-not (Test-Path -LiteralPath $BackupPath)) { throw "Backup ausente." }
        if ((Get-Content -LiteralPath $BackupPath -Raw) -notmatch '"sCurrency"="TEST"') { throw "Backup nao preservou a moeda anterior." }
        Write-Host "PASS: reset de $Cultura com moeda e formatos personalizados; backup preservado."
    }

    $Antes = Read-Formats | ConvertTo-Json -Depth 5 -Compress
    ResetarRegiaoMoedaPtBr
    Assert-Equal (Read-Formats | ConvertTo-Json -Depth 5 -Compress) $Antes "Idempotencia"
    Write-Host "PASS: segundo reset preserva os mesmos valores."

    # Falha de backup deve impedir qualquer alteracao.
    Set-ItemProperty "HKCU:\Control Panel\International" sCurrency "KEEP"
    function reg.exe { $global:LASTEXITCODE = 1 }
    $Falhou = $false
    try { ResetarRegiaoMoedaPtBr } catch { $Falhou = $true }
    finally { Remove-Item Function:\reg.exe }
    if (-not $Falhou) { throw "Falha de backup deveria interromper o reset." }
    Assert-Equal (Read-Formats).sCurrency "KEEP" "Sem alteracoes apos falha de backup"
    Write-Host "PASS: backup obrigatorio antes de alterar os formatos."

    # Simula falha depois de uma alteracao parcial e verifica o rollback.
    function Set-Culture {
        param($CultureInfo, $ErrorAction)
        Set-ItemProperty "HKCU:\Control Panel\International" sCurrency "PARTIAL"
        throw "Falha simulada de cultura."
    }
    $Falhou = $false
    try { ResetarRegiaoMoedaPtBr } catch { $Falhou = $true }
    finally { Remove-Item Function:\Set-Culture }
    if (-not $Falhou) { throw "Falha parcial deveria interromper o reset." }
    Assert-Equal (Read-Formats).sCurrency "KEEP" "Rollback"
    Write-Host "PASS: rollback restaura os ajustes apos falha parcial."

    # Simula Windows sem o cmdlet International (caminho de compatibilidade).
    function Get-Command {
        param([string]$Name, $ErrorAction)
        if ($Name -ne "Set-Culture") { Microsoft.PowerShell.Core\Get-Command $Name }
    }
    try { ResetarRegiaoMoedaPtBr } finally { Remove-Item Function:\Get-Command }
    Check-Formats
    Write-Host "PASS: reset sem depender de Set-Culture."
}
finally {
    Set-Culture $OriginalCulture
    Set-WinHomeLocation -GeoId $OriginalGeo
    & reg.exe import $Snapshot | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Falha ao restaurar o snapshot original: $Snapshot" }
}
