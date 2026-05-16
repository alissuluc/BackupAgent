unit BackupAgent.Terminal.Main;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Vcl.ComCtrls, Vcl.ExtCtrls,
  Vcl.Edge, BackupAgent.Terminal.Client, BackupAgent.Terminal.UIAssets,
  Vcl.AppEvnts;

type
  TfrmMain = class(TForm)
    lblStatus: TLabel;
    pbProgress: TProgressBar;
    btnStart: TButton;
    memLog: TMemo;
    tmrPolling: TTimer;
    lblName: TLabel;
    btnClose: TButton;
    ApplicationEvents1: TApplicationEvents;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure btnStartClick(Sender: TObject);
    procedure tmrPollingTimer(Sender: TObject);
    procedure btnCloseClick(Sender: TObject);
    procedure ApplicationEvents1Idle(Sender: TObject; var Done: Boolean);
  private
    FAgentClient: TBackupClient;
    FEdgeBrowser: TEdgeBrowser;
    FTmrUIHook: TTimer;
    procedure UIHookTimer(Sender: TObject);
    procedure Log(const AMsg: string);
    procedure OnBackupStarted;
    procedure OnBackupFinished;
    procedure ExecuteDownload;
  public
  end;

var
  frmMain: TfrmMain;

implementation

{$R *.dfm}

uses
  BackupAgent.Core.Config, BackupAgent.Core.Setup, System.Threading, BackupAgent.Core.Crypto;

procedure TfrmMain.FormCreate(Sender: TObject);
var
  Config: TConfigManager;
  HTMLPath: string;
begin
  ExtractUIDependencies(TSetupManager.GetUIPath);
  ExtractWebView2Loader;
  HTMLPath := 'file:///' + StringReplace(TSetupManager.GetUIPath + 'index.html', '\', '/', [rfReplaceAll]);

  try
    FEdgeBrowser := TEdgeBrowser.Create(Self);
    FEdgeBrowser.Parent := Self;
    FEdgeBrowser.Align := alClient;
    FEdgeBrowser.Navigate(HTMLPath);
    
    FTmrUIHook := TTimer.Create(Self);
    FTmrUIHook.Interval := 300;
    FTmrUIHook.OnTimer := UIHookTimer;
  except
    if Assigned(FEdgeBrowser) then
      FEdgeBrowser.Free;
    FEdgeBrowser := nil;
  end;

  FAgentClient := TBackupClient.Create;
  
  Config := TConfigManager.Create;
  try
    FAgentClient.BaseURL := Format('http://%s:%d', [Config.ServerIP, Config.RESTPort]);
    Log('Conectado ao Servidor Alvo: ' + FAgentClient.BaseURL);
  finally
    Config.Free;
  end;
end;

procedure TfrmMain.UIHookTimer(Sender: TObject);
begin
  if Assigned(FEdgeBrowser) then
  begin
    if FEdgeBrowser.DocumentTitle = 'CLOSE_APP' then
    begin
      Application.Terminate;
      Exit;
    end;

    if FEdgeBrowser.DocumentTitle = 'CLOSE_HTML' then
    begin
      FEdgeBrowser.Free;
      FEdgeBrowser := nil;
      btnStart.Visible := True;
      memLog.Visible := True;
      pbProgress.Visible := True;
      lblStatus.Visible := True;
      Exit;
    end;

    // O Timer agora atua apenas como hook cross-version para o clique do botão no HTML.
    if FEdgeBrowser.DocumentTitle = 'START_BACKUP' then
    begin
      FEdgeBrowser.ExecuteScript('document.title = "BackupAgent UI";');
      btnStartClick(nil);
    end;
  end;
end;

procedure TfrmMain.FormDestroy(Sender: TObject);
begin
  FAgentClient.Free;
end;

procedure TfrmMain.Log(const AMsg: string);
var
  EscapedMsg: string;
begin
  if Assigned(FEdgeBrowser) then
  begin
    EscapedMsg := StringReplace(AMsg, '\', '\\', [rfReplaceAll]);
    EscapedMsg := StringReplace(EscapedMsg, '"', '\"', [rfReplaceAll]);
    FEdgeBrowser.ExecuteScript('setLog("' + EscapedMsg + '")');
  end;

  memLog.Lines.Add(FormatDateTime('hh:nn:ss', Now) + ' - ' + AMsg);
  memLog.SelStart := Length(memLog.Text);
  memLog.SelLength := 0;
end;

procedure TfrmMain.ApplicationEvents1Idle(Sender: TObject; var Done: Boolean);
begin
  // O btnClose sempre copiará o estado do btnStart
  if btnStart.Enabled = False then
    btnClose.Enabled := False
  else
    btnClose.Enabled := True;
end;

procedure TfrmMain.btnCloseClick(Sender: TObject);
begin
  Close;
end;

procedure TfrmMain.btnStartClick(Sender: TObject);
begin
  btnStart.Enabled := False;
  Log('Enviando sinal de START para o motor do Agente Servidor...');
  
  TTask.Run(
    procedure
    var
      ErrMsg: string;
      Success: Boolean;
    begin
      Success := FAgentClient.StartBackup(ErrMsg);
      
      TThread.Queue(nil,
        procedure
        begin
          if Success then
          begin
            Log('Sinal Aceito (HTTP 202). Monitorando a extração do banco em rede...');
            OnBackupStarted;
          end
          else
          begin
            Log('Erro na comunicação: ' + ErrMsg);
            btnStart.Enabled := True;
          end;
        end);
    end);
end;

procedure TfrmMain.OnBackupStarted;
begin
  pbProgress.Position := 0;
  tmrPolling.Enabled := True;
  if Assigned(FEdgeBrowser) then
  begin
    FEdgeBrowser.ExecuteScript('updateStatus(0, 0, "");');
    FEdgeBrowser.ExecuteScript('setInProgress(true);');
  end;
end;

procedure TfrmMain.OnBackupFinished;
begin
  tmrPolling.Enabled := False;
  Log('O Servidor relatou que o pacote ZIP e a assinatura foram concluídos no lado de lá.');
  Log('Baixando pacote via Stream HTTP puro diretamente na C:\backup do Terminal...');
  
  ExecuteDownload;
end;

procedure TfrmMain.ExecuteDownload;
begin
  TTask.Run(
    procedure
    var
      ZipPath: string;
      LocalHash, ServerHash, ErrMsg: string;
      FileSizeBytes: Int64;
      SizeErr: string;
      Success: Boolean;
    begin
      // 1. HEAD request: obtém o tamanho real do ZIP antes de baixar
      if FAgentClient.GetDownloadSize(FileSizeBytes, SizeErr) and (FileSizeBytes > 0) then
      begin
        TThread.Queue(nil,
          procedure
          begin
            if Assigned(FEdgeBrowser) then
              FEdgeBrowser.ExecuteScript(Format('showFileSize(%d);', [FileSizeBytes]));
          end);
      end;

      ZipPath := TSetupManager.GetBackupPath + 'Terminal_Down_Temp.zip';

      Success := FAgentClient.DownloadBackup(ZipPath, ServerHash, ErrMsg);

      TThread.Queue(nil,
        procedure
        begin
          if Assigned(FEdgeBrowser) then
            FEdgeBrowser.ExecuteScript('setInProgress(false);');

          if not Success then
          begin
            Log('Falha grave de rede no meio do download: ' + ErrMsg);
            btnStart.Enabled := True;
            Exit;
          end;

          Log('Download (Stream) concluído no HD local. Conferindo assinatura Criptográfica...');

          LocalHash := TCryptoUtils.CalculateSHA256(ZipPath);

          if SameText(LocalHash, ServerHash) then
          begin
            Log('SUCESSO! Integridade Hash Validada (SHA-256). Cópias são idênticas.');
            lblStatus.Caption := 'Cópia espelho 100% íntegra.';
            if Assigned(FEdgeBrowser) then FEdgeBrowser.ExecuteScript('updateStatus(5, 100, "Cópia espelho 100% íntegra."); resetUI();');
          end
          else
          begin
            Log('ERRO FATAL: O pacote ZIP baixado divergente! (Hash Incorreto)');
            Log(' -> Hash no Servidor: ' + ServerHash);
            Log(' -> Hash Baixado..: ' + LocalHash);
          end;

          btnStart.Enabled := True;
          if Assigned(FEdgeBrowser) then FEdgeBrowser.ExecuteScript('resetUI();');
        end);
    end);
end;

procedure TfrmMain.tmrPollingTimer(Sender: TObject);
var
  StatusMsg: string;
  Progress, StateCode: Integer;
begin
  // Para o timer na UI Main Thread
  tmrPolling.Enabled := False;
  
  TTask.Run(
    procedure
    var
      Success: Boolean;
      ErrMsg: string;
    begin
      // Vai na rede buscar JSON na porta 8095
      Success := FAgentClient.CheckStatus(StateCode, Progress, StatusMsg, ErrMsg);
      
      TThread.Queue(nil,
        procedure
        begin
          if not Success then
          begin
            Log('Reconectando... (' + ErrMsg + ')');
            tmrPolling.Enabled := True;
            Exit;
          end;
          
          lblStatus.Caption := StatusMsg;
          pbProgress.Position := Progress;
          
          if Assigned(FEdgeBrowser) then
            FEdgeBrowser.ExecuteScript(Format('updateStatus(%d, %d, "");', [StateCode, Progress]));
          
          // Enums: bsReady = 5, bsError = 6
          if StateCode = 5 then
            OnBackupFinished
          else if StateCode = 6 then
          begin
            Log('ABORTADO: O Servidor relatou erro localmente -> ' + StatusMsg);
            btnStart.Enabled := True;
          end
          else
            tmrPolling.Enabled := True; // Continua batendo de 2 em 2 segundos
        end);
    end);
end;

end.
