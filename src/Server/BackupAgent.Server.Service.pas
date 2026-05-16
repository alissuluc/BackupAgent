unit BackupAgent.Server.Service;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Classes, Vcl.SvcMgr;

type
  TBackupAgentSvc = class(TService)
    procedure ServiceStart(Sender: TService; var Started: Boolean);
    procedure ServiceStop(Sender: TService; var Stopped: Boolean);
  private
    { Private declarations }
  public
    function GetServiceController: TServiceController; override;
  end;

var
  BackupAgentSvc: TBackupAgentSvc;

implementation

uses
  Horse, BackupAgent.Server.API, BackupAgent.Core.Setup, BackupAgent.Core.Config,
  System.Threading;

{$R *.dfm}

procedure ServiceController(CtrlCode: DWord); stdcall;
begin
  BackupAgentSvc.Controller(CtrlCode);
end;

function TBackupAgentSvc.GetServiceController: TServiceController;
begin
  Result := ServiceController;
end;

procedure TBackupAgentSvc.ServiceStart(Sender: TService; var Started: Boolean);
begin
  Started := False;
  try
    TSetupManager.InitializeEnvironment;
    
    // Inicia o Horse em uma Thread separada para não bloquear o SCM (Service Control Manager)
    // Se o ServiceStart demorar mais de 30 segundos, o Windows mata o serviço.
    TThread.CreateAnonymousThread(
      procedure
      var
        Config: TConfigManager;
      begin
        Config := TConfigManager.Create;
        try
          if Config.AppMode = amTerminal then
            Exit; // Falha silenciosa no log do Windows, não deve rodar no terminal
            
          TServerAPI.RegisterRoutes;
          THorse.Listen(Config.RESTPort);
        finally
          Config.Free;
        end;
      end).Start;
      
    Started := True;
  except
    on E: Exception do
      // Log no Event Viewer do Windows
      LogMessage('Erro ao iniciar BackupAgentSvc: ' + E.Message, EVENTLOG_ERROR_TYPE, 0, 1);
  end;
end;

procedure TBackupAgentSvc.ServiceStop(Sender: TService; var Stopped: Boolean);
begin
  try
    THorse.StopListen;
    Stopped := True;
  except
    on E: Exception do
    begin
      LogMessage('Erro ao parar BackupAgentSvc: ' + E.Message, EVENTLOG_ERROR_TYPE, 0, 2);
      Stopped := False;
    end;
  end;
end;

end.
