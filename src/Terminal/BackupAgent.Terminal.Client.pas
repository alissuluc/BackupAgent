unit BackupAgent.Terminal.Client;

interface

uses
  System.SysUtils, System.Classes, System.Net.HttpClient, System.Net.URLClient,
  System.JSON;

type
  /// <summary>
  /// Cliente REST nativo responsável por conversar com o Horse no Agente Servidor.
  /// </summary>
  TBackupClient = class
  private
    FBaseURL: string;
    FHttp: THTTPClient;
  public
    constructor Create;
    destructor Destroy; override;
    
    property BaseURL: string read FBaseURL write FBaseURL;
    
    function StartBackup(out AError: string): Boolean;
    function CheckStatus(out AStateCode, AProgress: Integer; out AMessage, AError: string): Boolean;
    function GetDownloadSize(out AFileSizeBytes: Int64; out AError: string): Boolean;
    function DownloadBackup(const ADestFilePath: string; out AServerHash, AError: string): Boolean;
  end;

implementation

{ TBackupClient }

constructor TBackupClient.Create;
begin
  FHttp := THTTPClient.Create;
  FHttp.ConnectionTimeout := 5000;
  FHttp.ResponseTimeout := 60000; // Tolerância inicial alta para endpoints
end;

destructor TBackupClient.Destroy;
begin
  FHttp.Free;
  inherited;
end;

function TBackupClient.StartBackup(out AError: string): Boolean;
var
  Resp: IHTTPResponse;
  DummyBody: TStringStream;
begin
  Result := False;
  DummyBody := TStringStream.Create('');
  try
    try
      // Inicia a call passando stream vazio para evitar erro de ambiguidade do compilador
      Resp := FHttp.Post(FBaseURL + '/api/v1/backup/start', DummyBody);
      if Resp.StatusCode = 202 then
        Result := True
      else
        AError := 'Servidor recusou iniciar. Status: ' + Resp.StatusCode.ToString;
    except
      on E: Exception do
        AError := 'Erro de rede: O servidor pode estar desligado ou porta bloqueada (8095). ' + E.Message;
    end;
  finally
    DummyBody.Free;
  end;
end;

function TBackupClient.CheckStatus(out AStateCode, AProgress: Integer; out AMessage, AError: string): Boolean;
var
  Resp: IHTTPResponse;
  JsonObj: TJSONObject;
begin
  Result := False;
  try
    FHttp.ConnectionTimeout := 3000;
    Resp := FHttp.Get(FBaseURL + '/api/v1/backup/status');
    
    if Resp.StatusCode = 200 then
    begin
      JsonObj := TJSONObject.ParseJSONValue(Resp.ContentAsString(TEncoding.UTF8)) as TJSONObject;
      if Assigned(JsonObj) then
      begin
        try
          AStateCode := JsonObj.GetValue<Integer>('state_code', 0);
          AProgress := JsonObj.GetValue<Integer>('progress', 0);
          AMessage := JsonObj.GetValue<string>('message', '');
          Result := True;
        finally
          JsonObj.Free;
        end;
      end
      else
        AError := 'O JSON devolvido pelo servidor não é legível.';
    end
    else
      AError := 'Status code da API: ' + Resp.StatusCode.ToString;
  except
    on E: Exception do
      AError := 'Rompimento de conexao: ' + E.Message;
  end;
end;

function TBackupClient.GetDownloadSize(out AFileSizeBytes: Int64; out AError: string): Boolean;
var
  Resp: IHTTPResponse;
  ContentLen: string;
begin
  Result := False;
  AFileSizeBytes := 0;
  try
    FHttp.ConnectionTimeout := 5000;
    FHttp.ResponseTimeout := 10000;
    Resp := FHttp.Head(FBaseURL + '/api/v1/backup/download');
    if Resp.StatusCode = 200 then
    begin
      ContentLen := Resp.HeaderValue['Content-Length'];
      if ContentLen <> '' then
        AFileSizeBytes := StrToInt64Def(ContentLen, 0);
      Result := True;
    end
    else if Resp.StatusCode = 400 then
      AError := 'Backup ainda não concluído no servidor.'
    else
      AError := 'Status inesperado: ' + Resp.StatusCode.ToString;
  except
    on E: Exception do
      AError := 'Falha ao consultar tamanho: ' + E.Message;
  end;
end;

function TBackupClient.DownloadBackup(const ADestFilePath: string; out AServerHash, AError: string): Boolean;
var
  Resp: IHTTPResponse;
  FileStream: TFileStream;
begin
  Result := False;
  try
    FHttp.ResponseTimeout := 10800000; // 3 Horas de limite (Cópia de FDB gigante sobre rede de farmácia via Wi-Fi)
    
    // TFileStream evita que um arquivo de 10GB encha a Memória RAM local. O sistema escreve direto no disco.
    FileStream := TFileStream.Create(ADestFilePath, fmCreate or fmShareDenyWrite);
    try
      Resp := FHttp.Get(FBaseURL + '/api/v1/backup/download', FileStream);
      
      if Resp.StatusCode = 200 then
      begin
        // Recupera o Headers X-SHA256 gerado pelo servidor (HeaderValue é uma property indexada em versões novas)
        AServerHash := Resp.HeaderValue['X-SHA256'];
        Result := True;
      end
      else
        AError := 'Erro no stream HTTP (Server pode ter matado o down): ' + Resp.StatusCode.ToString;
    finally
      FileStream.Free;
    end;
  except
    on E: Exception do
      AError := 'Falha crítica ao gravar/baixar arquivo: ' + E.Message;
  end;
end;

end.
