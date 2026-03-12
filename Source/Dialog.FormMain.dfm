object FormMain: TFormMain
  Left = 0
  Top = 0
  Caption = 'FormMain'
  ClientHeight = 441
  ClientWidth = 624
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  OnCloseQuery = FormCloseQuery
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  TextHeight = 15
  object btnStartWorker: TButton
    Left = 80
    Top = 80
    Width = 75
    Height = 25
    Caption = 'Start Worker'
    TabOrder = 0
    OnClick = btnStartWorkerClick
  end
  object btnStopWorker: TButton
    Left = 80
    Top = 120
    Width = 75
    Height = 25
    Caption = 'Stop Worker'
    TabOrder = 1
    OnClick = btnStopWorkerClick
  end
  object btnStartHorse: TButton
    Left = 80
    Top = 160
    Width = 75
    Height = 25
    Caption = 'Start Server'
    TabOrder = 2
    OnClick = btnStartHorseClick
  end
  object btnStopHorse: TButton
    Left = 80
    Top = 200
    Width = 75
    Height = 25
    Caption = 'Stop Server'
    TabOrder = 3
    OnClick = btnStopHorseClick
  end
end
