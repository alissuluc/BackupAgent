unit BackupAgent.Core.Config;

interface

uses
  System.SysUtils, System.Classes, System.Win.Registry, Winapi.Windows;

type
  TAppMode = (amServer, amTerminal);

  TConfigManager = class
  private
    FDatabasePath: string;
    FAppMode: TAppMode;
    FServerIP: string;
    FRESTPort: Integer;
    procedure LoadFromRegistry;
  public
    constructor Create;
    
    property DatabasePath: string read FDatabasePath;
    property AppMode: TAppMode read FAppMode;
    property ServerIP: string read FServerIP;
    property RESTPort: Integer read FRESTPort;
  end;

implementation

{ TConfigManager }

constructor TConfigManager.Create;
begin
  FRESTPort := 8095; // Porta fixa padronizada para a API REST
  LoadFromRegistry;
end;

procedure TConfigManager.LoadFromRegistry;
var
  Reg: TRegistry;
  RawPath: string;
  Idx, I: Integer;
  Keys: TStringList;
begin
  RawPath := '';
  Reg := TRegistry.Create(KEY_READ);
  try
    Reg.RootKey := HKEY_CURRENT_USER;
    if Reg.OpenKeyReadOnly('\DIGIFARMA') then
    begin
      if Reg.ValueExists('Database') then
        RawPath := Reg.ReadString('Database');
      Reg.CloseKey;
    end;
    
    // Fallback Inteligente para Windows Services (Sessão 0 - SYSTEM)
    // Varre todas as contas de usuário da máquina procurando o registro do Digifarma
    if RawPath = '' then
    begin
      Reg.RootKey := HKEY_USERS;
      if Reg.OpenKeyReadOnly('\') then
      begin
        Keys := TStringList.Create;
        try
          Reg.GetKeyNames(Keys);
          Reg.CloseKey;
          
          for I := 0 to Keys.Count - 1 do
          begin
            if Reg.OpenKeyReadOnly('\' + Keys[I] + '\DIGIFARMA') then
            begin
              if Reg.ValueExists('Database') then
              begin
                RawPath := Reg.ReadString('Database');
                Reg.CloseKey;
                Break;
              end;
              Reg.CloseKey;
            end;
          end;
        finally
          Keys.Free;
        end;
      end;
    end;

    if RawPath <> '' then
    begin
      // Formato Terminal: 192.168.0.2:C:\Digifarma\Dados\digifarma6.fdb
      // Formato Servidor: C:\Digifarma\Dados\digifarma6.fdb
      Idx := Pos(':', RawPath);
      
      // Valida se há um IP/Hostname antes do path padrão do Windows (onde o char ':' cai na posição 2 -> C:\)
      if (Idx > 0) and (Idx <> 2) then
      begin
        FAppMode := amTerminal;
        FServerIP := Copy(RawPath, 1, Idx - 1);
        FDatabasePath := Copy(RawPath, Idx + 1, Length(RawPath) - Idx);
      end
      else
      begin
        FAppMode := amServer;
        FServerIP := '127.0.0.1'; // Localhost
        FDatabasePath := RawPath;
      end;
    end;
  finally
    Reg.Free;
  end;
end;

end.
