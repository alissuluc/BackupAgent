unit BackupAgent.Core.State;

interface

uses
  System.SysUtils, System.SyncObjs, BackupAgent.Core.Interfaces;

type
  /// <summary>
  /// Gerencia o estado em memória da Thread de Backup,
  /// abolindo a necessidade inicial de gravar um state.json no disco
  /// enquanto provê thread-safety para a API REST ler o status.
  /// </summary>
  TBackupJob = class
  private
    FJobID: string;
    FState: TBackupState;
    FProgress: Integer;
    FMessage: string;
    FResultFile: string;
    FLock: TCriticalSection;
    function GetState: TBackupState;
    function GetProgress: Integer;
    function GetMessage: string;
    procedure SetProgress(const Value: Integer);
    procedure SetState(const Value: TBackupState);
    procedure SetMessage(const Value: string);
  public
    constructor Create;
    destructor Destroy; override;
    
    procedure UpdateStatus(AState: TBackupState; AProgress: Integer; const AMessage: string);

    property JobID: string read FJobID;
    property State: TBackupState read GetState write SetState;
    property Progress: Integer read GetProgress write SetProgress;
    property StatusMessage: string read GetMessage write SetMessage;
    property ResultFile: string read FResultFile write FResultFile;
  end;

implementation

{ TBackupJob }

constructor TBackupJob.Create;
begin
  FLock := TCriticalSection.Create;
  FJobID := TGUID.NewGuid.ToString; // Gera ID único para rastreio
  FState := bsWaiting;
  FProgress := 0;
  FMessage := 'Aguardando início...';
end;

destructor TBackupJob.Destroy;
begin
  FLock.Free;
  inherited;
end;

function TBackupJob.GetMessage: string;
begin
  FLock.Enter;
  try
    Result := FMessage;
  finally
    FLock.Leave;
  end;
end;

function TBackupJob.GetProgress: Integer;
begin
  FLock.Enter;
  try
    Result := FProgress;
  finally
    FLock.Leave;
  end;
end;

function TBackupJob.GetState: TBackupState;
begin
  FLock.Enter;
  try
    Result := FState;
  finally
    FLock.Leave;
  end;
end;

procedure TBackupJob.SetMessage(const Value: string);
begin
  FLock.Enter;
  try
    FMessage := Value;
  finally
    FLock.Leave;
  end;
end;

procedure TBackupJob.SetProgress(const Value: Integer);
begin
  FLock.Enter;
  try
    FProgress := Value;
  finally
    FLock.Leave;
  end;
end;

procedure TBackupJob.SetState(const Value: TBackupState);
begin
  FLock.Enter;
  try
    FState := Value;
  finally
    FLock.Leave;
  end;
end;

procedure TBackupJob.UpdateStatus(AState: TBackupState; AProgress: Integer; const AMessage: string);
begin
  FLock.Enter;
  try
    FState := AState;
    FProgress := AProgress;
    FMessage := AMessage;
  finally
    FLock.Leave;
  end;
end;

end.
