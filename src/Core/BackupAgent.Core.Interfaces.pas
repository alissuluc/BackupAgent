unit BackupAgent.Core.Interfaces;

interface

type
  TBackupState = (bsWaiting, bsConnecting, bsSnapshot, bsHashing, bsZipping, bsReady, bsError);

  IBackupProvider = interface
    ['{F4D5A18C-8F72-46C5-9DF8-9F54E70D09B1}']
    procedure ExecuteBackup(const ADatabasePath, ADestinationPath, ACnpjPwd: string);
    function GetProgress: Integer;
    function GetCurrentState: TBackupState;
  end;

  ILogger = interface
    ['{69A4D3B0-86BC-4ED5-901F-A8C5B32CA922}']
    procedure Info(const AMessage: string);
    procedure Error(const AMessage: string);
    procedure Warning(const AMessage: string);
  end;

implementation

end.
