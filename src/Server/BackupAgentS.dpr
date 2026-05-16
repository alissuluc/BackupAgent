program BackupAgentS;

uses
  Vcl.SvcMgr,
  System.SysUtils,
  Winapi.Windows,
  Horse,
  BackupAgent.Core.Setup in '..\Core\BackupAgent.Core.Setup.pas',
  BackupAgent.Core.Config in '..\Core\BackupAgent.Core.Config.pas',
  BackupAgent.Core.State in '..\Core\BackupAgent.Core.State.pas',
  BackupAgent.Core.Crypto in '..\Core\BackupAgent.Core.Crypto.pas',
  BackupAgent.Core.Interfaces in '..\Core\BackupAgent.Core.Interfaces.pas',
  BackupAgent.Infra.ProviderFactory in '..\Infra\BackupAgent.Infra.ProviderFactory.pas',
  BackupAgent.Infra.Firebird5 in '..\Infra\BackupAgent.Infra.Firebird5.pas',
  BackupAgent.Infra.Firebird25 in '..\Infra\BackupAgent.Infra.Firebird25.pas',
  BackupAgent.Server.API in 'BackupAgent.Server.API.pas',
  BackupAgent.Server.Controller in 'BackupAgent.Server.Controller.pas',
  BackupAgent.Server.Service in 'BackupAgent.Server.Service.pas' {BackupAgentSvc: TService};

{$R *.res}

function IsConsoleMode: Boolean;
begin
  Result := FindCmdLineSwitch('console', ['-', '/'], True) or
            FindCmdLineSwitch('c', ['-', '/'], True);
end;

procedure RunAsConsole;
var
  Config: TConfigManager;
begin
  AllocConsole;
  try
    Writeln('==============================================');
    Writeln(' BackupAgent - Agente Servidor (Console Mode) ');
    Writeln('==============================================');
    Writeln('');
    
    TSetupManager.InitializeEnvironment;
    Writeln('[OK] Infraestrutura de pastas verificada.');
    
    Config := TConfigManager.Create;
    try
      if Config.AppMode = amTerminal then
      begin
        Writeln('[ERRO] Configuracao de Terminal detectada.');
        Readln;
        Exit;
      end;
      
      TServerAPI.RegisterRoutes;
      Writeln('[OK] Horse Server escutando na porta ' + Config.RESTPort.ToString);
      Writeln('Pressione Ctrl+C para interromper.');
      
      THorse.Listen(Config.RESTPort);
    finally
      Config.Free;
    end;
  finally
    FreeConsole;
  end;
end;

begin
  // Evitar interface fantasma na Sessão 0 do Windows
  if not Application.DelayInitialize or Application.Installing then
    Application.Initialize;
    
  if IsConsoleMode then
  begin
    RunAsConsole;
  end
  else
  begin
    Application.CreateForm(TBackupAgentSvc, BackupAgentSvc);
    Application.Run;
  end;
end.
