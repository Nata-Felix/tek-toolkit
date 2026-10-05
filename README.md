<div align="center">

# TEK Toolkit

**Instalação, atualização e suporte técnico automatizado para ambientes TekFarma**

[![PowerShell](https://img.shields.io/badge/PowerShell-Automação-5391FE?style=flat-square&logo=powershell)](instalar_tekfarma.ps1)
[![C#](https://img.shields.io/badge/C%23-WinForms-512BD4?style=flat-square&logo=dotnet)](gui/TekFarmaInstallerGui.cs)
[![Release](https://img.shields.io/github/v/release/Nata-Felix/TEK-Toolkit?style=flat-square)](https://github.com/Nata-Felix/TEK-Toolkit/releases)

</div>

O **TEK Toolkit** transforma procedimentos extensos de implantação e suporte em fluxos guiados. Ele combina interfaces Windows com automações PowerShell para reduzir erros manuais e manter logs do atendimento.

| Central de suporte | Instalador TekFarma / Crystal |
| --- | --- |
| ![Central de suporte TekSoftware](docs/images/tek-suporte.png) | ![Instalador TekFarma e Crystal](docs/images/tek-instalador.png) |

## Principais recursos

- Instalação guiada para servidor e terminal.
- Atualização de versões do sistema com validação das etapas.
- Instalação e correção do Crystal Reports Runtime.
- Instalação de .NET Framework e Visual C++ Redistributable.
- Instalação e validação do Universal CRT/KB2999226 no Windows 7 e no Windows Server 2012 R2.
- Configuração e recuperação do Firebird.
- Preparação de rede, compartilhamentos SMB e mapeamentos.
- Suspensão e restauração controlada de compartilhamentos durante atualizações.
- Proteção dos processos do instalador durante o encerramento de aplicações em uso.
- Reset de região e moeda para o padrão pt-BR do Windows, com backup dos formatos anteriores.
- Registro detalhado de sucesso, avisos e falhas para diagnóstico.

## Arquitetura

```text
install.ps1                    Bootstrap do instalador gráfico
instalar_tekfarma.ps1          Fluxo completo de instalação
suporte.ps1                    Bootstrap da central de suporte
suporte_teksoftware.ps1        Ações operacionais de suporte
gui/TekFarmaInstallerGui.cs    Interface do instalador
gui/TekSoftwareSuporteGui.cs   Interface da central de suporte
gui/build.ps1                  Compilação dos executáveis
```

## Execução

Instalador:

```powershell
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; irm https://github.com/Nata-Felix/TEK-Toolkit/releases/download/v1.0/install.ps1 | iex
```

Central de suporte:

```powershell
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; irm https://github.com/Nata-Felix/TEK-Toolkit/releases/download/v1.0/suporte.ps1 | iex
```

### Reset de região e moeda

Na central de suporte, abra **Autonomia Windows**, marque
**Resetar regiao e moeda para pt-BR** e clique em **Executar**.
A ação restaura a localização Brasil e os formatos nativos pt-BR de moeda,
números, datas e horas, descartando as personalizações anteriores.
Os padrões são obtidos do Windows instalado, inclusive a posição do símbolo
R$ e a apresentação de valores negativos.

O reset se aplica à **conta que executa o suporte**. Se a elevação usar as
credenciais de outra conta, será essa outra conta que receberá os ajustes.
Não altera teclado, idioma de exibição, fuso horário, localidade de programas
não Unicode ou os perfis dos demais usuários.

O backup permanece em `%LOCALAPPDATA%\\TEK-Toolkit\\Backups\\Regional`;
o caminho completo é informado no log. Para restaurar os formatos anteriores,
importe o arquivo `.reg` correspondente e saia e entre novamente na conta.
Faça também esse novo login após o reset para atualizar todos os aplicativos.

### Redes com conexão HTTPS instável

Se o PowerShell informar que a conexão subjacente foi fechada, use o bloco
abaixo. Ele força TLS 1.2 e tenta baixar o bootstrap até três vezes:

```powershell
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$uri = "https://github.com/Nata-Felix/TEK-Toolkit/releases/download/v1.0/install.ps1"
$bootstrap = $null
$ultimoErro = $null

for ($tentativa = 1; $tentativa -le 3 -and $null -eq $bootstrap; $tentativa++) {
    try {
        $bootstrap = (New-Object Net.WebClient).DownloadString($uri)
    }
    catch {
        $ultimoErro = $_

        if ($tentativa -lt 3) {
            Start-Sleep -Seconds 2
        }
    }
}

if ($null -eq $bootstrap) {
    throw $ultimoErro
}

Invoke-Expression $bootstrap
```

## Cache de downloads

Os instaladores e pacotes válidos são preservados em
`%TEMP%\TEK-Toolkit_Cache`. Ao repetir uma instalação interrompida, o
instalador procura primeiro nesse cache e nas pastas temporárias de execuções
anteriores.

- arquivos de Release podem ser reutilizados por até 30 dias;
- arquivos de versão e banco baixados do site TekFarma podem ser reutilizados
  por até 2 horas;
- a interface inicial pode ser reutilizada por até 15 minutos;
- scripts PowerShell são sempre baixados novamente;
- arquivos com sufixo `.partial` nunca são reutilizados.

Para forçar todos os downloads novamente, exclua a pasta
`%TEMP%\TEK-Toolkit_Cache`.

## Compilação

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\gui\build.ps1
```

## Cuidados de uso

O toolkit executa tarefas administrativas e foi criado para atendimento técnico controlado. Antes de usar, valide permissões, backups e compatibilidade com o ambiente de destino.


## Ferramentas adicionais de suporte

A central de suporte agora inclui:

- Acesso rápido a comandos administrativos com pesquisa e sugestões.
- Assistente de adaptadores de rede, DHCP/IP fixo, DNS, teste de conflito de IP, proxy WinHTTP, TLS e reparos Winsock/TCP-IP.
- Download e abertura de AnyDesk, instalação de TeamViewer e acesso ao site oficial do Hamachi.
- Assistente de licenças com configurações e ajuda de ativação Windows/Office, atalho identificado para MasGrave (script externo), e instalação Office 2019/2021 pela Office Deployment Tool oficial.
- Microsoft Print to PDF, correções de registro de impressão e remoção independente de impressoras/drivers.
- Verificação de atualizações do suporte na release v1.0, comparando SHA-256, com confirmação dentro do aplicativo e recuperação da versão anterior pelo TekSoftwareUpdater.exe.

Mantém os fluxos de TekFarma, Firebird, certificados e reset regional pt-BR. Os downloads de suporte e drivers continuam vinculados às releases do TEK Toolkit.

O fluxo de CI compila as três interfaces e verifica o reset regional, os planos de execução, a sintaxe dos scripts gerados e a integridade/substituição do atualizador. Os testes dos novos assistentes não instalam aplicativos nem alteram rede ou impressoras.


## Interface compacta

A interface compacta reorganiza o suporte em uma janela de 800 × 600, com abas, busca global por nome/descrição (inclusive sem acentos), seleção preservada entre categorias e acompanhamento compacto. O log continua sendo salvo e pode ser acompanhado em uma janela própria.

As subjanelas usam o mesmo tema claro, tipografia Segoe UI, botões azuis e campos discretos. Os assistentes de Office e rede foram compactados; as opções e validações existentes são mantidas.

A verificação de atualização permanece ativa no aplicativo publicado. Os testes de interface desativam somente essa consulta para validar as janelas de forma isolada. O CI disponibiliza binários e capturas em artefatos; a release é atualizada após integração na main.
