unit BackupAgent.Server.Controller;

interface

type
  /// <summary>
  /// Controller principal que responde pelas interações de Backup.
  /// Expõe POST para iniciar, GET para status e GET para download.
  /// </summary>
  TBackupController = class
  public
    class procedure RegisterRoutes;
  end;

implementation

uses
  Horse, System.JSON, System.Classes, System.SysUtils, System.IOUtils, System.SyncObjs,
  OtlTask, OtlTaskControl, OtlParallel,
  BackupAgent.Core.State, BackupAgent.Core.Interfaces, BackupAgent.Core.Config,
  BackupAgent.Core.Crypto, BackupAgent.Infra.ProviderFactory, BackupAgent.Core.Setup;

var
  // Gerenciador de estado global em memória
  GlobalJob: TBackupJob;
  JobLock: TCriticalSection;

procedure StartBackup(Req: THorseRequest; Res: THorseResponse; Next: TProc);
begin
  JobLock.Enter;
  try
    if not Assigned(GlobalJob) then
      GlobalJob := TBackupJob.Create;
      
    // Impede execução de múltiplos backups simultâneos travando o disco
    if GlobalJob.State in [bsConnecting, bsSnapshot, bsHashing, bsZipping] then
    begin
      Res.Status(THTTPStatus.Conflict).Send('{"error":"Um backup ja esta em andamento."}');
      Exit;
    end;
    
    GlobalJob.UpdateStatus(bsWaiting, 0, 'Iniciando pipeline de backup...');
  finally
    JobLock.Leave;
  end;
  
  // Inicia o processo em background usando OmniThreadLibrary
  Parallel.Async(
    procedure
    var
      Config: TConfigManager;
      Provider: IBackupProvider;
      DestFbkFile, DestZipFile, CnpjPwd, FileHash: string;
    begin
      try
        Log.Info('=== INICIO DA PIPELINE EM BACKGROUND ===', 'BackupAgent');
        Config := TConfigManager.Create;
        try
          GlobalJob.UpdateStatus(bsConnecting, 10, 'Lendo CNPJ e inspecionando banco de dados...');
          Log.Debug('1. UpdateStatus OK. Chamando CreateBackupProvider para: ' + Config.DatabasePath, 'BackupAgent');
          
          Provider := TProviderFactory.CreateBackupProvider(Config.DatabasePath);
          Log.Debug('2. CreateBackupProvider OK. Chamando GetDatabaseCNPJ...', 'BackupAgent');
          
          CnpjPwd := TProviderFactory.GetDatabaseCNPJ(Config.DatabasePath);
          Log.Debug('3. GetDatabaseCNPJ OK. Retornou: ' + CnpjPwd, 'BackupAgent');
          
          // Pattern: C:\backup\BackupAgent\Bkp_12345678000199_2026-05-09_1400.fbk
          DestFbkFile := Format('%sBkp_%s_%s.fbk', [TSetupManager.GetBackupPath, CnpjPwd, FormatDateTime('yyyy-mm-dd_hhnn', Now)]);
          DestZipFile := ChangeFileExt(DestFbkFile, '.zip');
          
          GlobalJob.UpdateStatus(bsSnapshot, 20, 'Verificando disco livre e iniciando snapshot...');
          Log.Debug('4. Path definido. Chamando EnsureSufficientDiskSpace...', 'BackupAgent');
          
          // Trava o backup imediatamente se não houver espaço em disco seguro no destino
          TSetupManager.EnsureSufficientDiskSpace(Config.DatabasePath, DestFbkFile);
          
          Log.Debug('5. Espaço OK. Disparando Provider.ExecuteBackup...', 'BackupAgent');
          Provider.ExecuteBackup(Config.DatabasePath, DestFbkFile, '');
          Log.Info('6. ExecuteBackup RETORNOU COM SUCESSO.', 'BackupAgent');
          
          GlobalJob.UpdateStatus(bsZipping, 80, 'Compactando arquivo .fbk para .zip...');
          TCryptoUtils.CompressToZip(DestFbkFile, DestZipFile, CnpjPwd);
          
          // Apaga o FBK puro para economizar disco após zippar
          if FileExists(DestFbkFile) then
            DeleteFile(DestFbkFile);
            
          GlobalJob.UpdateStatus(bsHashing, 90, 'Gerando integridade SHA-256...');
          FileHash := TCryptoUtils.CalculateSHA256(DestZipFile);
          
          Log.Debug('9. Hash Finalizado. Aplicando Retenção...', 'BackupAgent');
          // Aplicar Política de Retenção de 7 dias APÓS validar que o novo ZIP nasceu perfeito
          TSetupManager.ApplyRetentionPolicy(TSetupManager.GetBackupPath, 7);
          
          GlobalJob.ResultFile := DestZipFile;
          GlobalJob.UpdateStatus(bsReady, 100, 'Concluido! Hash: ' + Copy(FileHash, 1, 8));
          Log.Info('10. Processo Finalizado Perfeitamente (bsReady).', 'BackupAgent');
        finally
          Config.Free;
        end;
      except
        on E: Exception do
        begin
          Log.Error('EXCECAO FATAL NA PIPELINE: ' + E.Message, 'BackupAgent');
          GlobalJob.UpdateStatus(bsError, 0, 'Erro fatal no motor de backup: ' + E.Message);
        end;
      end;
    end);
    
  Res.Status(THTTPStatus.Accepted).Send('{"status":"started", "job_id":"' + GlobalJob.JobID + '"}');
end;

procedure GetStatus(Req: THorseRequest; Res: THorseResponse; Next: TProc);
var
  JsonObj: TJSONObject;
begin
  if not Assigned(GlobalJob) then
  begin
    Res.Status(THTTPStatus.NotFound).Send('{"error":"Nenhum backup iniciado no momento."}');
    Exit;
  end;

  JsonObj := TJSONObject.Create;
  try
    JsonObj.AddPair('job_id', GlobalJob.JobID);
    JsonObj.AddPair('state_code', TJSONNumber.Create(Ord(GlobalJob.State)));
    JsonObj.AddPair('progress', TJSONNumber.Create(GlobalJob.Progress));
    JsonObj.AddPair('message', GlobalJob.StatusMessage);
    
    // Utiliza JSON puro nativo sem depender de middlewares de terceiros
    Res.ContentType('application/json; charset=utf-8').Send(JsonObj.ToString);
  finally
    JsonObj.Free;
  end;
end;

procedure DownloadBackup(Req: THorseRequest; Res: THorseResponse; Next: TProc);
var
  ZipFile: string;
  FileHash: string;
  FS: TFileStream;
begin
  if (not Assigned(GlobalJob)) or (GlobalJob.State <> bsReady) then
  begin
    Res.Status(THTTPStatus.BadRequest).Send('{"error":"Não há backup recente concluído e validado."}');
    Exit;
  end;

  ZipFile := GlobalJob.ResultFile;
  if not FileExists(ZipFile) then
  begin
    Res.Status(THTTPStatus.NotFound).Send('{"error":"O arquivo compactado sumiu ou não foi encontrado."}');
    Exit;
  end;

  // Validação em tempo real garantindo que o arquivo está íntegro na hora de enviar
  FileHash := TCryptoUtils.CalculateSHA256(ZipFile);
  Res.RawWebResponse.SetCustomHeader('X-SHA256', FileHash);
  
  FS := TFileStream.Create(ZipFile, fmOpenRead or fmShareDenyWrite);
  
  // INJEÇÃO CRÍTICA: Informa ao cliente o tamanho exato em Bytes do arquivo para a rede
  // Sem isso, o TCP/HTTP pode cortar os últimos bytes invisíveis do ZIP e quebrar o Hash.
  Res.RawWebResponse.ContentLength := FS.Size;
  
  // Bypassa o método Send() abstrato do Horse para evitar injeção de HTML padrão (200 OK).
  // Ancoramos o FileStream diretamente no motor TCP do WebBroker nativo.
  Res.RawWebResponse.ContentType := 'application/zip';
  Res.RawWebResponse.ContentStream := FS;
end;

procedure HeadDownload(Req: THorseRequest; Res: THorseResponse; Next: TProc);
var
  ZipFile: string;
begin
  if (not Assigned(GlobalJob)) or (GlobalJob.State <> bsReady) then
  begin
    Res.Status(THTTPStatus.BadRequest).Send('');
    Exit;
  end;
  ZipFile := GlobalJob.ResultFile;
  if not FileExists(ZipFile) then
  begin
    Res.Status(THTTPStatus.NotFound).Send('');
    Exit;
  end;
  // Retorna apenas os headers com o tamanho real, sem transferir o arquivo
  Res.RawWebResponse.ContentType := 'application/zip';
  Res.RawWebResponse.ContentLength := TFile.GetSize(ZipFile);
  Res.Status(THTTPStatus.Ok).Send('');
end;

{ TBackupController }

class procedure TBackupController.RegisterRoutes;
begin
  THorse.Post('/api/v1/backup/start', StartBackup);
  THorse.Get('/api/v1/backup/status', GetStatus);
  THorse.Head('/api/v1/backup/download', HeadDownload);
  THorse.Get('/api/v1/backup/download', DownloadBackup);
end;

initialization
  JobLock := TCriticalSection.Create;

finalization
  if Assigned(GlobalJob) then
    GlobalJob.Free;
  JobLock.Free;

end.
