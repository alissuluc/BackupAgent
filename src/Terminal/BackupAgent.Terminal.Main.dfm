object frmMain: TfrmMain
  Left = 100
  Top = 0
  Caption = 'Digifarma - Agente de Backup'
  ClientHeight = 500
  ClientWidth = 500
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poDesigned
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  TextHeight = 15
  object lblStatus: TLabel
    Left = 20
    Top = 68
    Width = 460
    Height = 30
    Alignment = taCenter
    AutoSize = False
    Caption = 'Aguardando a'#231#227'o'
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWindowText
    Font.Height = -16
    Font.Name = 'Segoe UI'
    Font.Style = [fsBold]
    ParentFont = False
  end
  object lblName: TLabel
    Left = 104
    Top = 15
    Width = 307
    Height = 37
    Caption = 'Digifarma BackupAgent'
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWindowText
    Font.Height = -27
    Font.Name = 'Segoe UI'
    Font.Style = [fsBold]
    ParentFont = False
  end
  object pbProgress: TProgressBar
    Left = 20
    Top = 98
    Width = 460
    Height = 25
    TabOrder = 0
  end
  object btnStart: TButton
    Left = 130
    Top = 138
    Width = 240
    Height = 40
    Caption = 'Disparar Backup Seguro'
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWindowText
    Font.Height = -13
    Font.Name = 'Segoe UI'
    Font.Style = [fsBold]
    ParentFont = False
    TabOrder = 1
    OnClick = btnStartClick
  end
  object memLog: TMemo
    Left = 20
    Top = 197
    Width = 460
    Height = 180
    ReadOnly = True
    ScrollBars = ssVertical
    TabOrder = 2
  end
  object btnClose: TButton
    Left = 192
    Top = 400
    Width = 120
    Height = 40
    Caption = 'Fechar'
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWindowText
    Font.Height = -13
    Font.Name = 'Segoe UI'
    Font.Style = [fsBold]
    ParentFont = False
    TabOrder = 3
    OnClick = btnCloseClick
  end
  object tmrPolling: TTimer
    Enabled = False
    Interval = 2000
    OnTimer = tmrPollingTimer
    Left = 448
    Top = 88
  end
  object ApplicationEvents1: TApplicationEvents
    OnIdle = ApplicationEvents1Idle
    Left = 448
    Top = 144
  end
end
