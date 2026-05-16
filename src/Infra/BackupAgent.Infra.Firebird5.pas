unit BackupAgent.Infra.Firebird5;

interface

uses
  System.SysUtils, System.Classes, System.IOUtils, FireDAC.Phys.FB, FireDAC.Phys.IBWrapper,
  FireDAC.Phys.IBBase, FireDAC.Stan.Intf, FireDAC.Phys, FireDAC.ConsoleUI.Wait, FireDAC.Comp.UI,
  BackupAgent.Core.Interfaces;

type
  /// <summary>
  /// Provedor nativo Firebird 5. Utiliza a Services API através do FireDAC (TFDIBBackup)
  /// para maior performance, estabilidade e capacidade de paralelismo futuro, sem uso do gbak.exe em disco.
  /// </summary>
  TFB5BackupProvider = class(TInterfacedObject, IBackupProvider)
  private
    FProgress: Integer;
    FState: TBackupState;
    FBackupService: TFDIBBackup;
    FWaitCursor: TFDGUIxWaitCursor;
  public
    constructor Create;
    destructor Destroy; override;
    
    procedure ExecuteBackup(const ADatabasePath, ADestinationPath, ACnpjPwd: string);
    function GetProgress: Integer;
    function GetCurrentState: TBackupState;
  end;

implementation

{ TFB5BackupProvider }

constructor TFB5BackupProvider.Create;
begin
  FProgress := 0;
  FState := bsWaiting;
  FBackupService := TFDIBBackup.Create(nil);
  
  FWaitCursor := TFDGUIxWaitCursor.Create(nil);
  FWaitCursor.Provider := 'Console';
end;

destructor TFB5BackupProvider.Destroy;
begin
  FWaitCursor.Free;
  FBackupService.Free;
  inherited;
end;



procedure TFB5BackupProvider.ExecuteBackup(const ADatabasePath, ADestinationPath, ACnpjPwd: string);

  procedure Trace(const AMsg: string);
  begin
    try
      TFile.AppendAllText('C:\backup\BackupAgent\trace_fb5.log', FormatDateTime('hh:nn:ss.zzz', Now) + ' - ' + AMsg + sLineBreak);
    except
    end;
  end;

begin
  Trace('=== INICIANDO EXECUÇÃO TFB5BackupProvider ===');
  FState := bsSnapshot;
  FProgress := 10;
  
  Trace('1. Criando DriverLink...');
  FBackupService.DriverLink := TFDPhysFBDriverLink.Create(FBackupService);
  try
    try
      Trace('2. Configurando propriedades de conexão (127.0.0.1, SYSDBA)...');
      FBackupService.Host := '127.0.0.1';
      FBackupService.UserName := 'SYSDBA';
      FBackupService.Password := 'masterkey';
      FBackupService.Protocol := ipTCPIP;
      FBackupService.Verbose := True; 
      
      Trace('3. Setando paths: DB=' + ADatabasePath + ' | DEST=' + ADestinationPath);
      FBackupService.Database := ADatabasePath;
      FBackupService.BackupFiles.Clear;
      FBackupService.BackupFiles.Add(ADestinationPath);
      
      FBackupService.Options := [];
      
      Trace('4. Chamando FBackupService.Backup() [PONTO CRÍTICO - BLOQUEANTE]...');
      FBackupService.Backup;
      Trace('5. RETORNO DO BACKUP COM SUCESSO! FBackupService.Backup() não travou!');
      
      FProgress := 100;
      FState := bsReady;
    except
      on E: Exception do
      begin
        Trace('EXCEÇÃO LANÇADA DURANTE O BACKUP: ' + E.Message);
        raise;
      end;
    end;
  finally
    Trace('6. Limpando DriverLink...');
    FBackupService.DriverLink.Free;
    Trace('7. Fim da rotina ExecuteBackup.');
  end;
end;

function TFB5BackupProvider.GetCurrentState: TBackupState;
begin
  Result := FState;
end;

function TFB5BackupProvider.GetProgress: Integer;
begin
  Result := FProgress;
end;

end.
