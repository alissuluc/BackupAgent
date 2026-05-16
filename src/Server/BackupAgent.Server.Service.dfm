object BackupAgentSvc: TBackupAgentSvc
  Name = 'BackupAgentSvc'
  DisplayName = 'Digifarma BackupAgent Server'
  ErrorSeverity = esNormal
  StartType = stAuto
  OnStart = ServiceStart
  OnStop = ServiceStop
  Height = 150
  Width = 215
end
