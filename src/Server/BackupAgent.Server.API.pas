unit BackupAgent.Server.API;

interface

type
  /// <summary>
  /// Responsável por orquestrar a carga de rotas do Horse e middlewares globais.
  /// Evita poluir o DPR com milhares de endpoints.
  /// </summary>
  TServerAPI = class
  public
    class procedure RegisterRoutes;
  end;

implementation

uses
  Horse, BackupAgent.Server.Controller;

{ TServerAPI }

class procedure TServerAPI.RegisterRoutes;
begin
  // Middlewares globais poderiam entrar aqui (ex: CORS, Compression)
  
  // Registra as rotas da nossa Controller de Backup
  TBackupController.RegisterRoutes;
end;

end.
