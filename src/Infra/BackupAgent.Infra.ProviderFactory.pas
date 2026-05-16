unit BackupAgent.Infra.ProviderFactory;

interface

uses
  System.SysUtils, Data.DB, FireDAC.Comp.Client, FireDAC.Stan.Def, FireDAC.Phys.FB, 
  FireDAC.Stan.Async, FireDAC.DApt, FireDAC.ConsoleUI.Wait, FireDAC.Comp.UI,
  BackupAgent.Core.Interfaces, BackupAgent.Infra.Firebird5, BackupAgent.Infra.Firebird25;

type
  /// <summary>
  /// Fabrica (Factory) que assume a responsabilidade de auditar o servidor 
  /// em runtime e instanciar o provedor exato.
  /// </summary>
  TProviderFactory = class
  public
    class function CreateBackupProvider(const ADatabasePath: string): IBackupProvider;
    class function GetDatabaseCNPJ(const ADatabasePath: string): string;
  end;

implementation

{ TProviderFactory }

class function TProviderFactory.GetDatabaseCNPJ(const ADatabasePath: string): string;
var
  Conn: TFDConnection;
  Qry: TFDQuery;
begin
  Result := '00000000000000'; // CNPJ Genérico caso a base seja virgem ou falhe
  Conn := TFDConnection.Create(nil);
  Qry := TFDQuery.Create(nil);
  try
    Conn.DriverName := 'FB';
    Conn.Params.Add('Server=127.0.0.1');
    Conn.Params.Add('Database=' + ADatabasePath);
    Conn.Params.Add('User_Name=SYSDBA');
    Conn.Params.Add('Password=masterkey');
    Conn.LoginPrompt := False;
    
    try
      Conn.Connected := True;
      Qry.Connection := Conn;
      Qry.SQL.Text := 'SELECT FIRST 1 CNPJ FROM CONFIG';
      Qry.Open;
      if not Qry.IsEmpty then
        Result := Qry.FieldByName('CNPJ').AsString;
        
      // Remove máscara do CNPJ (./-) se houver no banco
      Result := StringReplace(Result, '.', '', [rfReplaceAll]);
      Result := StringReplace(Result, '/', '', [rfReplaceAll]);
      Result := StringReplace(Result, '-', '', [rfReplaceAll]);
    except
      // Se não existir a tabela CONFIG ou der timeout, segue com os Zeros
    end;
  finally
    Qry.Free;
    Conn.Free;
  end;
end;

class function TProviderFactory.CreateBackupProvider(const ADatabasePath: string): IBackupProvider;
var
  Conn: TFDConnection;
  Qry: TFDQuery;
  VersionStr: string;
  MajorVersion: Integer;
begin
  Conn := TFDConnection.Create(nil);
  Qry := TFDQuery.Create(nil);
  try
    Conn.DriverName := 'FB';
    Conn.Params.Add('Server=127.0.0.1');
    Conn.Params.Add('Database=' + ADatabasePath);
    Conn.Params.Add('User_Name=SYSDBA');
    Conn.Params.Add('Password=masterkey');
    Conn.LoginPrompt := False;
    
    try
      Conn.Connected := True;
      Qry.Connection := Conn;
      // Lê de forma bruta o contexto nativo (suportado desde 2.1)
      Qry.SQL.Text := 'SELECT rdb$get_context(''SYSTEM'', ''ENGINE_VERSION'') AS V FROM rdb$database';
      Qry.Open;
      VersionStr := Qry.FieldByName('V').AsString;
      
      // Quebra '5.0.0' para obter apenas o Major
      MajorVersion := StrToIntDef(VersionStr.Split(['.'])[0], 2);
      
      if MajorVersion >= 5 then
        Result := TFB5BackupProvider.Create
      else
        Result := TFB25BackupProvider.Create;
    except
      on E: Exception do
      begin
        // Se for erro de função inexistente, é Firebird antigo (fallback seguro)
        if Pos('rdb$get_context', LowerCase(E.Message)) > 0 then
          Result := TFB25BackupProvider.Create
        else
          // Se for erro de DLL ou conexão recusada, precisamos "gritar" o erro real!
          raise Exception.Create('Falha ao auditar motor do Firebird: ' + E.Message);
      end;
    end;
  finally
    Qry.Free;
    Conn.Free;
  end;
end;

end.
