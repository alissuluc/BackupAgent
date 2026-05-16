unit BackupAgent.Core.Setup;

interface

uses
  System.SysUtils, System.IOUtils, System.Types, System.DateUtils, System.Classes;

type
  TSetupManager = class
  public
    /// <summary>
    /// Força a criação das pastas necessárias para a operação do Agente, 
    /// garantindo que a infraestrutura local exista antes de rodar.
    /// </summary>
    class procedure InitializeEnvironment;
    class function GetBackupPath: string;
    class function GetInstallPath: string;
    class function GetLogsPath: string;
    class function GetUIPath: string;
    class procedure ApplyRetentionPolicy(const ABackupPath: string; ADays: Integer);
    
    /// <summary>
    /// Verifica se o disco de destino tem espaço livre suficiente com base 
    /// no tamanho do banco de dados (FDB) para evitar travar o C: da máquina.
    /// Levanta uma exceção fatal se o limite for atingido.
    /// </summary>
    class procedure EnsureSufficientDiskSpace(const ADatabasePath, ADestinationPath: string);
  end;

implementation

uses
  Winapi.Windows;

{ TSetupManager }

class function TSetupManager.GetBackupPath: string;
begin
  Result := 'C:\backup\BackupAgent\';
end;

class function TSetupManager.GetInstallPath: string;
begin
  Result := 'C:\Install\arquivos\BackupAgent\';
end;

class function TSetupManager.GetLogsPath: string;
begin
  Result := GetInstallPath + 'logs\';
end;

class function TSetupManager.GetUIPath: string;
begin
  Result := GetInstallPath + 'ui\';
end;

class procedure TSetupManager.InitializeEnvironment;
begin
  ForceDirectories(GetBackupPath);
  ForceDirectories(GetInstallPath);
  ForceDirectories(GetLogsPath);
  ForceDirectories(GetUIPath);
end;

function CompareFilesByLastWriteTime(List: TStringList; Index1, Index2: Integer): Integer;
var
  DT1, DT2: TDateTime;
begin
  DT1 := TFile.GetLastWriteTime(List[Index1]);
  DT2 := TFile.GetLastWriteTime(List[Index2]);
  if DT1 > DT2 then Result := -1
  else if DT1 < DT2 then Result := 1
  else Result := 0;
end;

class procedure TSetupManager.ApplyRetentionPolicy(const ABackupPath: string; ADays: Integer);
var
  Files: TStringDynArray;
  FileList: TStringList;
  F: string;
  I: Integer;
  CutoffDate: TDateTime;
begin
  Files := TDirectory.GetFiles(ABackupPath, '*.zip');
  
  // Regra de Ouro: Se tem apenas 1 ou 0 arquivos, não apaga NADA (garante o fallback).
  if Length(Files) <= 1 then Exit;

  FileList := TStringList.Create;
  try
    for F in Files do
      FileList.Add(F);

    // Ordena do mais recente (índice 0) para o mais velho, baseado na data de modificação
    FileList.CustomSort(CompareFilesByLastWriteTime);

    CutoffDate := IncDay(Now, -ADays);
    
    // Iteramos a partir do índice 1 (o índice 0 está salvo e intocável)
    for I := 1 to FileList.Count - 1 do
    begin
      if TFile.GetLastWriteTime(FileList[I]) < CutoffDate then
      begin
        try
          TFile.Delete(FileList[I]);
        except
          // Ignora silentemente se o arquivo estiver em uso por outro app
        end;
      end;
    end;
  finally
    FileList.Free;
  end;
end;

class procedure TSetupManager.EnsureSufficientDiskSpace(const ADatabasePath, ADestinationPath: string);
var
  DbSize: Int64;
  DriveLetter: Char;
  DriveNum: Integer;
  FreeSpace: Int64;
  DriveStr: string;
  AttrData: TWin32FileAttributeData;
begin
  if not FileExists(ADatabasePath) then
    Exit; // Se for um mapeamento remoto inacessível via disco local, pula a checagem nativa

  // Usa GetFileAttributesEx (WinAPI) para descobrir tamanho sem tentar abrir com locks, 
  // o que poderia dar "File in use" se o Firebird 2.5 estivesse travando o FDB.
  DbSize := 0;
  if GetFileAttributesEx(PChar(ADatabasePath), GetFileExInfoStandard, @AttrData) then
    DbSize := Int64(AttrData.nFileSizeHigh) shl 32 + AttrData.nFileSizeLow;

  // Extrai a letra do drive destino (Ex: "C:\backup\..." -> "C:")
  DriveStr := ExtractFileDrive(ADestinationPath);
  if DriveStr = '' then 
    DriveStr := ExtractFileDrive(GetCurrentDir);
    
  if DriveStr <> '' then
  begin
    DriveLetter := UpCase(DriveStr[1]);
    DriveNum := Ord(DriveLetter) - 64; // Conversão ASCII para Drive API (A=1, B=2, C=3)

    FreeSpace := DiskFree(DriveNum);

    // REGRA DE SEGURANÇA: Exige que o disco tenha o tamanho do FDB atual + 20% de margem
    if FreeSpace < (DbSize * 1.2) then
      raise Exception.CreateFmt(
        'OPERACAO ABORTADA POR SEGURANCA: Disco %s: quase cheio! ' +
        'O banco FDB ocupa %.2f GB e ha apenas %.2f GB livres. Libere espaco imediatamente.',
        [DriveLetter, DbSize / 1073741824, FreeSpace / 1073741824]);
  end;
end;

end.
