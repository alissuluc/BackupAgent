unit BackupAgent.Core.Crypto;

interface

uses
  System.SysUtils, System.Classes, System.Zip, System.Hash;

type
  /// <summary>
  /// Utilitário central para criptografia e compactação.
  /// </summary>
  TCryptoUtils = class
  public
    /// <summary>
    /// Compacta o arquivo .fbk fonte para o destino .zip.
    /// Obs: A VCL padrão TZipFile não possui suporte robusto a senhas (AES).
    /// Para o MVP inicial a senha é mapeada, mas a compressão ocorre sem criptografia AES.
    /// Na próxima refatoração será adicionado o Abbrevia para suporte a zip com senha.
    /// </summary>
    class procedure CompressToZip(const ASourceFile, ADestZipFile, APassword: string);
    
    /// <summary>
    /// Gera o Hash SHA-256 de um arquivo físico em disco para garantir que a cópia
    /// de rede no Agente Terminal seja exatamente igual à original.
    /// </summary>
    class function CalculateSHA256(const AFilePath: string): string;
  end;

implementation

class procedure TCryptoUtils.CompressToZip(const ASourceFile, ADestZipFile, APassword: string);
var
  Zip: TZipFile;
begin
  Zip := TZipFile.Create;
  try
    Zip.Open(ADestZipFile, zmWrite);
    
    // Adiciona o arquivo com compressão máxima
    Zip.Add(ASourceFile, '', zcDeflate);
    
    Zip.Close;
  finally
    Zip.Free;
  end;
end;

class function TCryptoUtils.CalculateSHA256(const AFilePath: string): string;
var
  Stream: TFileStream;
begin
  if not FileExists(AFilePath) then
    Exit('');
    
  // Abre o arquivo como read-only e permite que outros leiam enquanto calcula
  Stream := TFileStream.Create(AFilePath, fmOpenRead or fmShareDenyWrite);
  try
    Result := THashSHA2.GetHashString(Stream, THashSHA2.TSHA2Version.SHA256);
  finally
    Stream.Free;
  end;
end;

end.
