unit BackupAgent.Infra.Firebird25;

interface

uses
  System.SysUtils, System.StrUtils, System.Classes, System.IOUtils, System.Win.Registry,
  Winapi.Windows, FireDAC.Phys.FB, FireDAC.Phys.IBWrapper,
  FireDAC.Phys.IBBase, FireDAC.Stan.Intf, FireDAC.Phys, FireDAC.ConsoleUI.Wait,
  FireDAC.Comp.UI, BackupAgent.Core.Interfaces;

type
  /// <summary>
  /// Provedor legado para bases Firebird 2.5 (Windows antigos).
  /// Utiliza a Services API via FireDAC com VendorLib explícito para evitar
  /// conflitos de versão de DLL (gds32 vs fbclient, x86 vs x64).
  /// Fallback automático para gbak.exe caso a fbclient.dll não seja localizável.
  /// </summary>
  TFB25BackupProvider = class(TInterfacedObject, IBackupProvider)
  private
    FProgress: Integer;
    FState: TBackupState;
    FBackupService: TFDIBBackup;
    FWaitCursor: TFDGUIxWaitCursor;
    /// <summary>
    /// Localiza a fbclient.dll compatível com a arquitetura do processo atual.
    /// Prioridade: Registro HKLM (arch-aware) → paths físicos padrão → vazio.
    /// </summary>
    function FindFbClientPath: string;
    /// <summary>
    /// Localiza o gbak.exe como caminho de fallback.
    /// Mantido para uso caso a Services API falhe em hardware específico.
    /// </summary>
    function FindGbakPath: string;
    procedure ExecuteViaServicesAPI(const ADatabasePath, ADestinationPath: string);
    procedure ExecuteViaGbak(const ADatabasePath, ADestinationPath: string);
  public
    constructor Create;
    destructor Destroy; override;
    procedure ExecuteBackup(const ADatabasePath, ADestinationPath, ACnpjPwd: string);
    function GetProgress: Integer;
    function GetCurrentState: TBackupState;
  end;

implementation

{ TFB25BackupProvider }

constructor TFB25BackupProvider.Create;
begin
  FProgress := 0;
  FState := bsWaiting;
  FBackupService := TFDIBBackup.Create(nil);
  FWaitCursor := TFDGUIxWaitCursor.Create(nil);
  FWaitCursor.Provider := 'Console';
end;

destructor TFB25BackupProvider.Destroy;
begin
  FWaitCursor.Free;
  FBackupService.Free;
  inherited;
end;

function TFB25BackupProvider.FindFbClientPath: string;

  function TryReadRegValue(const AKey, AValueName: string): string;
  var
    Reg: TRegistry;
  begin
    Result := '';
    Reg := TRegistry.Create(KEY_READ);
    try
      Reg.RootKey := HKEY_LOCAL_MACHINE;
      if Reg.OpenKeyReadOnly(AKey) then
      begin
        if Reg.ValueExists(AValueName) then
          Result := Reg.ReadString(AValueName);
        Reg.CloseKey;
      end;
    finally
      Reg.Free;
    end;
  end;

  function MakeFbClientPath(const ADir: string): string;
  var
    Dir: string;
  begin
    Result := '';
    Dir := ADir;
    if Dir = '' then Exit;
    if Dir[Length(Dir)] <> '\' then Dir := Dir + '\';
    Result := Dir + 'bin\fbclient.dll';
    if not FileExists(Result) then Result := '';
  end;

var
  FB25Dir: string;
  // Detecta se o processo atual é 32-bit ou 64-bit em runtime.
  // Crítico: a fbclient.dll DEVE ter a mesma arquitetura do processo.
  Is64BitProcess: Boolean;
begin
  Result := '';
  Is64BitProcess := (SizeOf(Pointer) = 8);

  if Is64BitProcess then
  begin
    // Processo 64-bit → precisa de fbclient.dll 64-bit
    // Chaves nativas (sem Wow6432Node) contêm instalação 64-bit
    FB25Dir := TryReadRegValue('SOFTWARE\Firebird Project\Firebird Server\Instances', 'DefaultInstance');
    Result := MakeFbClientPath(FB25Dir);
    if Result <> '' then Exit;

    FB25Dir := TryReadRegValue('SOFTWARE\FirebirdSQL\Firebird\CurrentVersion', 'RootDirectory');
    Result := MakeFbClientPath(FB25Dir);
    if Result <> '' then Exit;

    // Fallback físico 64-bit
    if FileExists('C:\Program Files\Firebird\Firebird_2_5\bin\fbclient.dll') then
      Result := 'C:\Program Files\Firebird\Firebird_2_5\bin\fbclient.dll';
  end
  else
  begin
    // Processo 32-bit → precisa de fbclient.dll 32-bit
    // Chaves Wow6432Node contêm instalação 32-bit em sistema 64-bit
    FB25Dir := TryReadRegValue('SOFTWARE\Wow6432Node\Firebird Project\Firebird Server\Instances', 'DefaultInstance');
    Result := MakeFbClientPath(FB25Dir);
    if Result <> '' then Exit;

    FB25Dir := TryReadRegValue('SOFTWARE\Wow6432Node\FirebirdSQL\Firebird\CurrentVersion', 'RootDirectory');
    Result := MakeFbClientPath(FB25Dir);
    if Result <> '' then Exit;

    // Fallback físico 32-bit (em sistemas 64-bit, x86 vai para Program Files (x86))
    if FileExists('C:\Program Files (x86)\Firebird\Firebird_2_5\bin\fbclient.dll') then
      Result := 'C:\Program Files (x86)\Firebird\Firebird_2_5\bin\fbclient.dll'
    // Em sistemas Windows 32-bit nativos, vai para Program Files
    else if FileExists('C:\Program Files\Firebird\Firebird_2_5\bin\fbclient.dll') then
      Result := 'C:\Program Files\Firebird\Firebird_2_5\bin\fbclient.dll';
  end;

  // Último recurso: fbclient.dll raiz (instalações customizadas)
  if (Result = '') and FileExists('C:\Firebird\bin\fbclient.dll') then
    Result := 'C:\Firebird\bin\fbclient.dll';
end;

function TFB25BackupProvider.FindGbakPath: string;

  function TryReadRegValue(const AKey, AValueName: string): string;
  var
    Reg: TRegistry;
  begin
    Result := '';
    Reg := TRegistry.Create(KEY_READ);
    try
      Reg.RootKey := HKEY_LOCAL_MACHINE;
      if Reg.OpenKeyReadOnly(AKey) then
      begin
        if Reg.ValueExists(AValueName) then
          Result := Reg.ReadString(AValueName);
        Reg.CloseKey;
      end;
    finally
      Reg.Free;
    end;
  end;

  function MakeGbakPath(const ADir: string): string;
  var
    Dir: string;
  begin
    Result := '';
    Dir := ADir;
    if Dir = '' then Exit;
    if Dir[Length(Dir)] <> '\' then Dir := Dir + '\';
    Result := Dir + 'bin\gbak.exe';
    if not FileExists(Result) then Result := '';
  end;

var
  FB25Dir: string;
begin
  Result := '';
  FB25Dir := TryReadRegValue('SOFTWARE\Firebird Project\Firebird Server\Instances', 'DefaultInstance');
  Result := MakeGbakPath(FB25Dir);
  if Result <> '' then Exit;

  FB25Dir := TryReadRegValue('SOFTWARE\Wow6432Node\Firebird Project\Firebird Server\Instances', 'DefaultInstance');
  Result := MakeGbakPath(FB25Dir);
  if Result <> '' then Exit;

  FB25Dir := TryReadRegValue('SOFTWARE\FirebirdSQL\Firebird\CurrentVersion', 'RootDirectory');
  Result := MakeGbakPath(FB25Dir);
  if Result <> '' then Exit;

  FB25Dir := TryReadRegValue('SOFTWARE\Wow6432Node\FirebirdSQL\Firebird\CurrentVersion', 'RootDirectory');
  Result := MakeGbakPath(FB25Dir);
  if Result <> '' then Exit;

  if FileExists('C:\Program Files\Firebird\Firebird_2_5\bin\gbak.exe') then
    Result := 'C:\Program Files\Firebird\Firebird_2_5\bin\gbak.exe'
  else if FileExists('C:\Program Files (x86)\Firebird\Firebird_2_5\bin\gbak.exe') then
    Result := 'C:\Program Files (x86)\Firebird\Firebird_2_5\bin\gbak.exe'
  else if FileExists('C:\Firebird\bin\gbak.exe') then
    Result := 'C:\Firebird\bin\gbak.exe';
end;

procedure TFB25BackupProvider.ExecuteViaServicesAPI(const ADatabasePath, ADestinationPath: string);
var
  DriverLink: TFDPhysFBDriverLink;
  FbClientPath: string;
begin
  FbClientPath := FindFbClientPath;
  if FbClientPath = '' then
    raise Exception.Create(
      'fbclient.dll compativel nao encontrada para este processo (' +
      IfThen(SizeOf(Pointer) = 8, '64-bit', '32-bit') +
      '). Verifique se o Firebird 2.5 compativel esta instalado.');

  DriverLink := TFDPhysFBDriverLink.Create(FBackupService);
  try
    // Aponta explicitamente para a DLL da versão e arquitetura corretas.
    // Evita que o FireDAC carregue uma fbclient.dll de versão errada do PATH.
    DriverLink.VendorLib := FbClientPath;

    FBackupService.DriverLink := DriverLink;
    FBackupService.Host := '127.0.0.1';
    FBackupService.UserName := 'SYSDBA';
    FBackupService.Password := 'masterkey';
    FBackupService.Protocol := ipTCPIP;
    FBackupService.Verbose := True;
    FBackupService.Database := ADatabasePath;
    FBackupService.BackupFiles.Clear;
    FBackupService.BackupFiles.Add(ADestinationPath);
    FBackupService.Options := [];

    FBackupService.Backup;
  finally
    FBackupService.DriverLink.Free;
  end;
end;

procedure TFB25BackupProvider.ExecuteViaGbak(const ADatabasePath, ADestinationPath: string);
var
  StartupInfo: TStartupInfo;
  ProcessInfo: TProcessInformation;
  CmdLine, GbakPath: string;
  LastErr: DWORD;
begin
  GbakPath := FindGbakPath;
  if GbakPath = '' then
    GbakPath := 'gbak'; // Último recurso: PATH do sistema

  CmdLine := Format('"%s" -b -v -user SYSDBA -pas masterkey 127.0.0.1:"%s" "%s"',
    [GbakPath, ADatabasePath, ADestinationPath]);

  FillChar(StartupInfo, SizeOf(StartupInfo), 0);
  StartupInfo.cb := SizeOf(StartupInfo);
  StartupInfo.dwFlags := STARTF_USESHOWWINDOW;
  StartupInfo.wShowWindow := SW_HIDE;

  UniqueString(CmdLine);

  if CreateProcess(nil, PChar(CmdLine), nil, nil, False, CREATE_NO_WINDOW, nil, nil, StartupInfo, ProcessInfo) then
  begin
    WaitForSingleObject(ProcessInfo.hProcess, INFINITE);
    CloseHandle(ProcessInfo.hProcess);
    CloseHandle(ProcessInfo.hThread);
  end
  else
  begin
    LastErr := GetLastError;
    raise Exception.CreateFmt(
      'Falha ao iniciar gbak.exe (Win32 Error %d). Path tentado: [%s].',
      [LastErr, GbakPath]);
  end;
end;

procedure TFB25BackupProvider.ExecuteBackup(const ADatabasePath, ADestinationPath, ACnpjPwd: string);

  procedure Trace(const AMsg: string);
  begin
    try
      TFile.AppendAllText('C:\backup\BackupAgent\trace_fb25.log',
        FormatDateTime('hh:nn:ss.zzz', Now) + ' - ' + AMsg + sLineBreak);
    except
    end;
  end;

begin
  FState := bsSnapshot;
  FProgress := 10;

  Trace('=== INICIANDO TFB25BackupProvider ===');
  Trace('Processo: ' + IfThen(SizeOf(Pointer) = 8, '64-bit', '32-bit'));
  Trace('fbclient.dll encontrada: [' + FindFbClientPath + ']');

  try
    Trace('Tentando Services API via VendorLib...');
    ExecuteViaServicesAPI(ADatabasePath, ADestinationPath);
    Trace('SUCESSO via Services API.');
  except
    on E: Exception do
    begin
      Trace('Services API FALHOU: ' + E.Message);
      Trace('Iniciando fallback via gbak.exe...');
      try
        ExecuteViaGbak(ADatabasePath, ADestinationPath);
        Trace('SUCESSO via gbak.exe (fallback).');
      except
        on EGbak: Exception do
        begin
          Trace('gbak.exe tambem FALHOU: ' + EGbak.Message);
          raise Exception.CreateFmt(
            'Services API falhou: [%s]. Fallback gbak tambem falhou: [%s].',
            [E.Message, EGbak.Message]);
        end;
      end;
    end;
  end;

  FProgress := 100;
  FState := bsZipping;
  Trace('ExecuteBackup concluido. FState = bsZipping.');
end;

function TFB25BackupProvider.GetCurrentState: TBackupState;
begin
  Result := FState;
end;

function TFB25BackupProvider.GetProgress: Integer;
begin
  Result := FProgress;
end;

end.
