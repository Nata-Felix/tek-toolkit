#requires -Version 5.1
$ErrorActionPreference = 'Stop'
# A interface e compilada em x86; a reflexao deve usar o mesmo processo de 32 bits.
if ([Environment]::Is64BitProcess) {
    & "$env:WINDIR\SysWOW64\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File $PSCommandPath
    exit $LASTEXITCODE
}
$root = Split-Path -Parent $PSScriptRoot
Add-Type -AssemblyName System.Windows.Forms
$assembly = [Reflection.Assembly]::LoadFrom((Join-Path $root 'TekSoftwareSuporte.exe'))
$flags = [Reflection.BindingFlags]'Public,NonPublic,Instance,Static'
function Type([string]$name) { return $assembly.GetType('TekSoftwareSuporte.' + $name, $true) }
function New-Model([string]$name) { return [Activator]::CreateInstance((Type $name), $true) }
function Invoke-Private($target, [string]$name, [object[]]$values = @()) {
    return $target.GetType().GetMethod($name, $flags).Invoke($target, $values)
}
function Assert($condition, [string]$message) { if (!$condition) { throw $message } }
function Parse-Script([string]$text, [string]$label) {
    $tokens = $null; $errors = $null
    $ast = [Management.Automation.Language.Parser]::ParseInput($text, [ref]$tokens, [ref]$errors)
    if ($errors.Count) { throw ($label + ': ' + ($errors | Out-String)) }
    return $ast
}
$form = New-Model 'SupportForm'
try {
    $actions = $form.GetType().GetField('actionOptions', $flags).GetValue($form)
    $ids = @($actions | ForEach-Object { $_.Id })
    foreach ($id in @('regiaomoeda','rede','credencial','mapear','ssltlssefaz','certificados','farmaciapopular','firewall','firebird','trocaservidor','radminvpn','net35','net48','gpedit','impressora','resetimpressora','portacom','windowsupdatefix','limpezareparowindows','cacheicone','firewalloff','removersenhacompartilhamento','admcomando','configuracaorede','anydesk','teamviewer','hamachi','licencasoffice','impressorapdf','insertregistroimpressora','removerdrivers')) {
        Assert ($ids -contains $id) ("Opcao ausente: " + $id)
    }
    Assert (($ids | Select-Object -Unique).Count -eq $ids.Count) 'IDs de acoes duplicados.'
    foreach ($id in @('configuracaorede','anydesk','teamviewer','hamachi','licencasoffice','impressorapdf','insertregistroimpressora','removerdrivers')) {
        Assert (Invoke-Private $form 'IsGuiHandledAction' @($id)) ("Acao nova enviada ao backend incorretamente: " + $id)
    }
    Assert (!(Invoke-Private $form 'IsGuiHandledAction' @('regiaomoeda'))) 'Reset regional deve continuar no backend.'
    foreach ($action in $actions) {
        if ($action.Id -in @('regiaomoeda','anydesk')) { $action.CheckBox.Checked = $true }
    }
    $work = Invoke-Private $form 'BuildWorkPlan'
    $backend = @($work.Downloads | Where-Object { $_.FileName -eq 'suporte_teksoftware.ps1' })
    Assert ($backend.Count -eq 1) 'Plano misto deve baixar o backend TEK uma unica vez.'
    Assert ($backend[0].Url -eq 'https://github.com/Nata-Felix/TEK-Toolkit/releases/download/v1.0/suporte_teksoftware.ps1') 'URL de backend incorreta.'
    Assert (@($work.Downloads | Where-Object { $_.FileName -eq 'AnyDesk.exe' }).Count -eq 1) 'AnyDesk ausente do plano.'
    foreach ($action in $actions) { $action.CheckBox.Checked = $false }
    foreach ($action in $actions) { if ($action.Id -eq 'anydesk') { $action.CheckBox.Checked = $true } }
    $work = Invoke-Private $form 'BuildWorkPlan'
    Assert (@($work.Downloads | Where-Object { $_.FileName -eq 'suporte_teksoftware.ps1' }).Count -eq 0) 'Acao local nao deve baixar o backend.'

    $network = New-Model 'NetworkConfigurationPlan'
    $network.InterfaceIndex = 7
    $network.InterfaceAlias = "Rede d'empresa"
    $network.ApplyIpSettings = $true; $network.UseDhcp = $false
    $network.IpAddress = '192.168.55.30'; $network.PrefixLength = 24; $network.Gateway = '192.168.55.1'
    $network.ApplyDnsSettings = $true; $network.UseAutomaticDns = $false
    $network.PrimaryDns = '1.1.1.1'; $network.SecondaryDns = '8.8.8.8'
    $network.FlushAndRenewDns = $true; $network.ResetWinHttpProxy = $true; $network.EnableTls12 = $true
    $network.ResetWinsockAndTcpIp = $true; $network.TestConnectivity = $true
    $generated = Invoke-Private $form 'BuildNetworkConfigurationScript' @($network)
    $null = Parse-Script $generated 'Rede estatica e reparos'
    Assert ($generated.Contains("'Rede d''empresa'")) 'Nome do adaptador nao escapado.'
    Assert ($generated.IndexOf('Verificando se o IPv4') -lt $generated.IndexOf('Set-NetIPInterface')) 'Verificacao de conflito deve anteceder a alteracao.'
    $network.UseDhcp = $true; $network.UseAutomaticDns = $true
    $null = Parse-Script (Invoke-Private $form 'BuildNetworkConfigurationScript' @($network)) 'DHCP e DNS automaticos'

    $work = New-Model 'WorkPlan'
    $work.PrintersToRemove.Add("Impressora d'empresa")
    $work.PrinterDriversToRemove.Add('Driver com espacos')
    $generated = Invoke-Private $form 'BuildPrinterRemovalScript' @($work)
    $null = Parse-Script $generated 'Remocao independente'
    Assert ($generated.Contains("'Impressora d''empresa'")) 'Nome da impressora nao escapado.'
    foreach ($method in @('BuildPrintToPdfScript','BuildPrinterRegistryScript')) {
        $null = Parse-Script (Invoke-Private $form $method) $method
    }

    $productType = Type 'OfficeProductChoice'
    $itemType = Type 'OfficeDownloadItem'
    foreach ($year in @(2019,2021)) {
        $plan = New-Model 'OfficeDownloadPlan'
        $plan.Year = $year; $plan.LanguageCode = 'pt-br'
        $product = [Activator]::CreateInstance($productType, [object[]]@('Word','Microsoft Word','Aplicativo'))
        $item = [Activator]::CreateInstance($itemType, [object[]]@([int]$year,$product,'pt-br'))
        $plan.Items.Add($item)
        $generated = Invoke-Private $form 'BuildOfficeSilentInstallScript' @($plan)
        $null = Parse-Script $generated ('Office ' + $year)
        Assert ($generated.Contains(('Word' + $year + 'Retail'))) 'Produto ODT incorreto.'
        Assert ($generated.Contains('Get-AuthenticodeSignature')) 'Validacao de assinatura Microsoft ausente.'
        Assert ($generated.Contains('[Environment]::Is64BitOperatingSystem')) 'Arquitetura do Windows nao considerada.'
    }
    $badPlan = New-Model 'OfficeDownloadPlan'
    $rejected = $false
    try { $null = Invoke-Private $form 'BuildOfficeSilentInstallScript' @($badPlan) } catch { $rejected = $true }
    Assert $rejected 'Plano Office vazio deve ser rejeitado.'
    $gui = Get-Content -Raw -LiteralPath (Join-Path $root 'gui\TekSoftwareSuporteGui.cs')
    Assert (!$gui.Contains('SOLPPE') -and !$gui.Contains('toolkit_all.ps1')) 'Referencias do SOLPPE permaneceram no TEK.'
    Assert ($gui.Contains('"/releases/tags/" + Version')) 'Atualizador deve usar a release do bootstrap.'
    $bootstrap = Get-Content -Raw -LiteralPath (Join-Path $root 'suporte.ps1')
    Assert ($bootstrap.Contains('.update-in-progress')) 'Bootstrap deve preservar a pasta durante atualizacao.'
    Write-Host 'PASS: menus, roteamento misto, rede, Office e impressoras verificados sem alterar o Windows.'
} finally { $form.Dispose() }
