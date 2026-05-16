program BackupAgentT;

uses
  Vcl.Forms,
  BackupAgent.Core.Setup in '..\Core\BackupAgent.Core.Setup.pas',
  BackupAgent.Core.Config in '..\Core\BackupAgent.Core.Config.pas',
  BackupAgent.Core.Crypto in '..\Core\BackupAgent.Core.Crypto.pas',
  BackupAgent.Core.Interfaces in '..\Core\BackupAgent.Core.Interfaces.pas',
  BackupAgent.Core.State in '..\Core\BackupAgent.Core.State.pas',
  BackupAgent.Terminal.Main in 'BackupAgent.Terminal.Main.pas' {frmMain},
  BackupAgent.Terminal.Client in 'BackupAgent.Terminal.Client.pas',
  BackupAgent.Terminal.UIAssets in 'BackupAgent.Terminal.UIAssets.pas';

{$R *.res}
{$R WebView2Loader.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  
  // Garantimos que a máquina terminal possua os diretórios
  // C:\backup e C:\Install\arquivos\BackupAgent\logs criados.
  TSetupManager.InitializeEnvironment;
  
  Application.CreateForm(TfrmMain, frmMain);
  Application.Run;
end.
