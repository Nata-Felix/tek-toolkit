#requires -Version 5.1
$ErrorActionPreference = 'Stop'
if ([Environment]::Is64BitProcess) {
    & "$env:WINDIR\SysWOW64\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File $PSCommandPath
    exit $LASTEXITCODE
}
Add-Type -AssemblyName System.Windows.Forms, System.Drawing
[Windows.Forms.Application]::EnableVisualStyles()
$root = Split-Path -Parent $PSScriptRoot
$assembly = [Reflection.Assembly]::LoadFrom((Join-Path $root 'TekSoftwareSuporte.exe'))
$flags = [Reflection.BindingFlags]'Public,NonPublic,Instance,Static'
$previewDirectory = Join-Path $root 'ui-previews'
New-Item -ItemType Directory -Path $previewDirectory -Force | Out-Null
function Assert-Ui($condition, [string]$message) { if (!$condition) { throw $message } }
function New-Window([string]$name, [object[]]$arguments = @()) {
    $type = $assembly.GetType('TekSoftwareSuporte.' + $name, $true)
    return [Activator]::CreateInstance($type, $arguments)
}
function Field($object, [string]$name) { return $object.GetType().GetField($name, $flags).GetValue($object) }
function Call($object, [string]$method, [object[]]$arguments = @()) {
    return $object.GetType().GetMethod($method, $flags).Invoke($object, $arguments)
}
function Save-Preview($window, [string]$name) {
    $window.PerformLayout()
    $window.CreateControl()
    $bitmap = New-Object Drawing.Bitmap($window.Width, $window.Height)
    try {
        $window.DrawToBitmap($bitmap, (New-Object Drawing.Rectangle(0,0,$window.Width,$window.Height)))
        $path = Join-Path $previewDirectory ($name + '.png')
        $bitmap.Save($path, [Drawing.Imaging.ImageFormat]::Png)
        Write-Host ('TEK_UI_PREVIEW|' + $name + '|' + [Convert]::ToBase64String([IO.File]::ReadAllBytes($path)))
    } finally { $bitmap.Dispose() }
}
function Assert-ControlBounds($parent) {
    foreach ($control in $parent.Controls) {
        if (!$control.Visible -or $control -is [Windows.Forms.TabPage] -or $parent -is [Windows.Forms.TabControl]) { continue }
        if ($parent -isnot [Windows.Forms.ScrollableControl] -or !$parent.AutoScroll) {
            Assert-Ui ($control.Left -ge 0 -and $control.Top -ge 0 -and
                $control.Right -le ($parent.ClientSize.Width + 2) -and
                $control.Bottom -le ($parent.ClientSize.Height + 2)) (
                    'Controle fora da janela: ' + $parent.GetType().Name + ' / ' + $control.GetType().Name + ' / ' + $control.Text)
        }
        Assert-ControlBounds $control
    }
}
$form = New-Window 'SupportForm' @($true)
try {
    $form.Show()
    [Windows.Forms.Application]::DoEvents()
    $tabs = Field $form 'categoryTabs'
    $search = Field $form 'searchBox'
    $actions = Field $form 'actionOptions'
    Assert-Ui ($form.ClientSize.Width -le 800 -and $form.ClientSize.Height -le 600) 'Janela principal deixou de ser compacta.'
    Assert-Ui ($tabs.TabPages.Count -eq 7) 'Categorias ausentes.'
    Assert-Ui ($tabs.SelectedTab.Text -eq 'Windows') 'Categoria inicial deve ser Windows.'
    Assert-ControlBounds $form
    Save-Preview $form 'principal'

    $regional = @($actions | Where-Object { $_.Id -eq 'regiaomoeda' })[0]
    $regional.CheckBox.Checked = $true
    $search.Text = 'regiao'
    [Windows.Forms.Application]::DoEvents()
    Assert-Ui $regional.CheckBox.Visible 'Busca deve ignorar acentos.'
    Assert-Ui ($regional.CheckBox.Parent -eq (Field $form 'actionsPanel')) 'Busca deve usar os mesmos controles e preservar callbacks.'
    Assert-Ui (@($actions | Where-Object { $_.CheckBox.Visible }).Count -eq 1) 'Busca por regiao deve filtrar uma ferramenta.'
    $search.Text = 'anydesk'
    [Windows.Forms.Application]::DoEvents()
    $anydesk = @($actions | Where-Object { $_.Id -eq 'anydesk' })[0]
    Assert-Ui $anydesk.CheckBox.Visible 'Busca deve encontrar ferramenta de outra categoria.'
    $anydesk.CheckBox.Checked = $true
    $search.Text = 'ferramenta-inexistente-987654'
    [Windows.Forms.Application]::DoEvents()
    Assert-Ui (Field $form 'emptySearchLabel').Visible 'Busca vazia deve ter feedback.'
    $search.Clear()
    Assert-Ui ($regional.CheckBox.Checked -and $anydesk.CheckBox.Checked) 'Busca nao pode perder a selecao.'
    $plan = Call $form 'BuildWorkPlan'
    Assert-Ui ($plan.ContainsAction('regiaomoeda') -and $plan.ContainsAction('anydesk')) 'Selecoes entre abas devem entrar no plano de execucao.'
    foreach ($action in $actions) { $action.CheckBox.Checked = $false }

    foreach ($page in $tabs.TabPages) {
        $tabs.SelectedTab = $page
        [Windows.Forms.Application]::DoEvents()
        Assert-ControlBounds $form
    }
    $tabs.SelectedIndex = 0
    $form.ClientSize = New-Object Drawing.Size(724,521)
    [Windows.Forms.Application]::DoEvents()
    Assert-ControlBounds $form
    $form.ClientSize = New-Object Drawing.Size(800,600)

    $mapping = New-Window 'MappingHostDialog' @('SERVIDOR')
    try {
        $mapping.Show($form)
        [Windows.Forms.Application]::DoEvents()
        Assert-ControlBounds $mapping
        Save-Preview $mapping 'mapeamento'
    } finally { $mapping.Dispose() }

    $office = New-Window 'OfficeDownloadDialog' @($null)
    try {
        $office.Show($form)
        [Windows.Forms.Application]::DoEvents()
        Assert-Ui ($office.ClientSize.Height -le 560) 'Office deve usar janela compacta.'
        Assert-ControlBounds $office
        Save-Preview $office 'office'
    } finally { $office.Dispose() }

    $license = New-Window 'LicenseOfficeDialog' @($null)
    try {
        $license.Show($form)
        [Windows.Forms.Application]::DoEvents()
        Assert-ControlBounds $license
        Save-Preview $license 'licencas'
    } finally { $license.Dispose() }

    $sefaz = New-Window 'SefazTimeZoneDialog' @($null)
    try {
        $sefaz.Show($form)
        [Windows.Forms.Application]::DoEvents()
        Assert-ControlBounds $sefaz
        Save-Preview $sefaz 'sefaz'
    } finally { $sefaz.Dispose() }

    # Exibe sem confirmar: consulta adaptadores e impressoras, mas nao altera o Windows.
    foreach ($name in @('NetworkConfigurationDialog','ServerMigrationDialog','PrinterRemovalDialog')) {
        $window = if ($name -eq 'PrinterRemovalDialog') { New-Window $name } else { New-Window $name @($null) }
        try {
            $window.Show($form)
            [Windows.Forms.Application]::DoEvents()
            Assert-ControlBounds $window
            Save-Preview $window $name
        } finally { $window.Dispose() }
    }

    Assert-Ui ((Call $form 'CalculateDownloadEta' @([long]100,[long]1000,[double]2)) -eq 18) 'Estimativa deve considerar bytes restantes e velocidade.'
    Assert-Ui ((Call $form 'CalculateDownloadEta' @([long]0,[long]1000,[double]2)) -eq -1) 'Sem bytes recebidos nao existe estimativa.'
    Assert-Ui ((Call $form 'CalculateDownloadEta' @([long]100,[long]-1,[double]2)) -eq -1) 'Sem tamanho conhecido nao existe estimativa.'
    Assert-Ui ((Call $form 'CalculateDownloadEta' @([long]1000,[long]1000,[double]2)) -eq 0) 'Download completo deve ter tempo restante zero.'
    Assert-Ui ((Call $form 'CalculateDownloadEta' @([long]100,[long]1000,[double]0.2)) -eq -1) 'Estimativa deve aguardar amostra de velocidade.'

    Add-Type -ReferencedAssemblies System.dll,System.Core.dll,System.Windows.Forms.dll -TypeDefinition @'
using System;
using System.IO;
using System.Net;
using System.Net.Sockets;
using System.Reflection;
using System.Threading;
using System.Diagnostics;
using System.ComponentModel;
using System.Windows.Forms;
public static class DownloadProgressTest
{
    public static void Run(object form, bool cancel)
    {
        BindingFlags flags = BindingFlags.Instance | BindingFlags.Public | BindingFlags.NonPublic;
        Type type = form.GetType();
        type.GetField("cancelRequested", flags).SetValue(form, false);
        type.GetField("totalUnits", flags).SetValue(form, 2);
        type.GetField("completedUnits", flags).SetValue(form, 0);
        string path = Path.Combine(Path.GetTempPath(), "tek-download-test-" + Guid.NewGuid().ToString("N"));
        TcpListener listener = new TcpListener(IPAddress.Loopback, 0);
        listener.Start();
        int port = ((IPEndPoint)listener.LocalEndpoint).Port;
        Thread server = new Thread(delegate()
        {
            try
            {
                using (TcpClient connection = listener.AcceptTcpClient())
                using (NetworkStream stream = connection.GetStream())
                {
                    StreamReader reader = new StreamReader(stream);
                    string line;
                    do { line = reader.ReadLine(); } while (!String.IsNullOrEmpty(line));
                    byte[] header = System.Text.Encoding.ASCII.GetBytes("HTTP/1.1 200 OK\r\nContent-Length: 1048576\r\nConnection: close\r\n\r\n");
                    stream.Write(header, 0, header.Length);
                    byte[] chunk = new byte[65536];
                    for (int i = 0; i < 16; i++) { stream.Write(chunk, 0, chunk.Length); stream.Flush(); Thread.Sleep(120); }
                }
            } catch (IOException) { } catch (SocketException) { } catch (ObjectDisposedException) { }
        });
        server.IsBackground = true;
        server.Start();
        Type itemType = type.Assembly.GetType("TekSoftwareSuporte.DownloadItem", true);
        object item = Activator.CreateInstance(itemType, new object[] { "http://127.0.0.1:" + port + "/", "test.bin", "arquivo de teste" });
        bool done = false, sawEta = false, sawSpeed = false;
        int reports = 0;
        Exception error = null;
        BackgroundWorker worker = new BackgroundWorker();
        worker.WorkerReportsProgress = true;
        worker.DoWork += delegate
        {
            type.GetMethod("DownloadFileWithVisualProgress", flags).Invoke(form, new object[] { item, path, worker });
        };
        worker.ProgressChanged += delegate(object sender, ProgressChangedEventArgs e)
        {
            reports++;
            object state = e.UserState;
            Type info = state.GetType();
            sawEta |= (int)info.GetField("EtaSeconds").GetValue(state) >= 0;
            sawSpeed |= ((string)info.GetField("Detail").GetValue(state)).Contains("/s");
        };
        worker.RunWorkerCompleted += delegate(object sender, RunWorkerCompletedEventArgs e) { error = e.Error; done = true; };
        Stopwatch clock = Stopwatch.StartNew();
        try
        {
            worker.RunWorkerAsync();
            while (!done && clock.Elapsed.TotalSeconds < 15)
            {
                Application.DoEvents();
                if (cancel && clock.ElapsedMilliseconds >= 500)
                    type.GetField("cancelRequested", flags).SetValue(form, true);
                Thread.Sleep(20);
            }
            if (!done) throw new Exception("Download de teste nao concluiu.");
            if (error != null) throw new Exception("Falha no download de teste.", error);
            if (cancel)
            {
                if (File.Exists(path)) throw new Exception("Cancelamento deve remover arquivo parcial.");
            }
            else
            {
                if (!File.Exists(path) || new FileInfo(path).Length != 1048576) throw new Exception("Download truncado.");
                if (reports < 2 || !sawEta || !sawSpeed) throw new Exception("Download deve informar bytes, velocidade e estimativa.");
            }
        }
        finally
        {
            listener.Stop();
            server.Join(3000);
            worker.Dispose();
            type.GetField("cancelRequested", flags).SetValue(form, false);
            if (File.Exists(path)) File.Delete(path);
        }
    }
}
'@
    [DownloadProgressTest]::Run($form, $false)
    [DownloadProgressTest]::Run($form, $true)
    $clock = Field $form 'executionClock'
    $clock.Restart()
    $form.GetType().GetField('lastActivityUtc',$flags).SetValue($form,[DateTime]::UtcNow)
    $form.GetType().GetField('estimateUpdatedUtc',$flags).SetValue($form,[DateTime]::UtcNow)
    $form.GetType().GetField('remainingEstimateSeconds',$flags).SetValue($form,90)
    Call $form 'RefreshActivityStatus'
    Assert-Ui ((Field $form 'statusLabel').Text.Contains('Estimativa desta etapa')) 'Estimativa deve aparecer na interface.'
    (Field $form 'currentStepLabel').Text = 'Baixando Firebird...'
    (Field $form 'activityDetailLabel').Text = '12 MB de 48 MB · 2 MB/s'
    Save-Preview $form 'download-estimativa'
    $form.GetType().GetField('lastActivityUtc',$flags).SetValue($form,[DateTime]::UtcNow.AddSeconds(-30))
    Call $form 'RefreshActivityStatus'
    Assert-Ui ((Field $form 'statusLabel').Text.Contains('Sem novo progresso')) 'Pausa deve suspender a contagem estimada.'
    $clock.Stop()
    Write-Host 'PASS: download local com bytes, velocidade e ETA; cancelamento remove parcial; aviso de pausa e ETA visiveis.'

    Write-Host 'PASS: busca global, acentos, selecao entre abas, plano misto, dimensoes e subjanelas verificadas.'
} finally { $form.Dispose() }
