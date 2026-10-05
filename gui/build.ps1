$ErrorActionPreference = "Stop"

$RepoRoot = Split-Path -Parent $PSScriptRoot
$Csc = "$env:WINDIR\Microsoft.NET\Framework64\v4.0.30319\csc.exe"

if (!(Test-Path $Csc)) {
    $Csc = "$env:WINDIR\Microsoft.NET\Framework\v4.0.30319\csc.exe"
}

if (!(Test-Path $Csc)) {
    throw "Compilador C# do .NET Framework nao encontrado."
}

function Build-WinFormsExe {
    param(
        [string]$SourceFile,
        [string]$OutputFile,
        [string]$ErrorMessage,
        [string]$SharedUiFile = ""
    )

    $CompilerArguments = @(
        "/nologo"
        "/target:winexe"
        "/platform:x86"
        "/optimize+"
        "/win32icon:$PSScriptRoot\assets\TekFarmaInstaller.ico"
        "/win32manifest:$PSScriptRoot\app.manifest"
        "/reference:System.dll"
        "/reference:System.Core.dll"
        "/reference:System.Drawing.dll"
        "/reference:System.Web.Extensions.dll"
        "/reference:System.Windows.Forms.dll"
        "/resource:$PSScriptRoot\assets\logo_display.png,TekFarmaLogo"
        "/resource:$PSScriptRoot\assets\TekFarmaInstaller.ico,TekFarmaIcon"
        "/out:$OutputFile"
        $SourceFile
    )

    if (![string]::IsNullOrWhiteSpace($SharedUiFile)) { $CompilerArguments += $SharedUiFile }
    & $Csc $CompilerArguments

    if ($LASTEXITCODE -ne 0) {
        throw $ErrorMessage
    }
}

Build-WinFormsExe `
    -SourceFile "$PSScriptRoot\TekFarmaInstallerGui.cs" `
    -OutputFile "$RepoRoot\TekFarmaInstaller.exe" `
    -ErrorMessage "Falha ao compilar TekFarmaInstaller.exe."

Build-WinFormsExe `
    -SourceFile "$PSScriptRoot\TekSoftwareSuporteGui.cs" `
    -OutputFile "$RepoRoot\TekSoftwareSuporte.exe" `
    -ErrorMessage "Falha ao compilar TekSoftwareSuporte.exe." `
    -SharedUiFile "$PSScriptRoot\CompactUi.cs"

Build-WinFormsExe `
    -SourceFile "$PSScriptRoot\TekSoftwareUpdater.cs" `
    -OutputFile "$RepoRoot\TekSoftwareUpdater.exe" `
    -ErrorMessage "Falha ao compilar TekSoftwareUpdater.exe." `
    -SharedUiFile "$PSScriptRoot\CompactUi.cs"

Get-Item "$RepoRoot\TekFarmaInstaller.exe", "$RepoRoot\TekSoftwareSuporte.exe", "$RepoRoot\TekSoftwareUpdater.exe" | Select-Object FullName,Length,LastWriteTime
