object Form1: TForm1
  Left = 269
  Top = 186
  BorderIcons = [biSystemMenu, biMinimize]
  BorderStyle = bsSingle
  Caption = 'EEnot v0.6 - Ego Audio Extractor'
  ClientHeight = 476
  ClientWidth = 474
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  OldCreateOrder = False
  OnCloseQuery = CheckClose
  OnCreate = Init
  PixelsPerInch = 96
  TextHeight = 13
  object lblFileInfo: TLabel
    Left = 280
    Top = 112
    Width = 88
    Height = 13
    Caption = 'Total packages : 0'
  end
  object lbl5: TLabel
    Left = 280
    Top = 136
    Width = 71
    Height = 13
    Caption = 'Selection info :'
  end
  object lblAudioFileInfo: TLabel
    Left = 280
    Top = 160
    Width = 3
    Height = 13
  end
  object lblplaytime: TLabel
    Left = 387
    Top = 445
    Width = 3
    Height = 13
  end
  object btn1: TButton
    Left = 280
    Top = 8
    Width = 89
    Height = 25
    Caption = 'Load'
    TabOrder = 0
    OnClick = btn1Click
  end
  object tv1: TTreeView
    Left = 0
    Top = 0
    Width = 265
    Height = 476
    Align = alLeft
    Images = il1
    Indent = 19
    ReadOnly = True
    TabOrder = 1
    OnChange = SelectTreeNode
    OnDblClick = playtreeitem
  end
  object btnsave: TButton
    Left = 376
    Top = 8
    Width = 89
    Height = 25
    Caption = 'Save'
    Enabled = False
    TabOrder = 2
    OnClick = btnSaveClick
  end
  object btnsaveall: TButton
    Left = 280
    Top = 40
    Width = 89
    Height = 25
    Caption = 'Save all'
    Enabled = False
    TabOrder = 3
    OnClick = btnsaveallClick
  end
  object btnplay: TBitBtn
    Left = 280
    Top = 440
    Width = 75
    Height = 25
    Caption = 'Play'
    Enabled = False
    TabOrder = 4
    OnClick = btnplayClick
  end
  object mmo1: TMemo
    Left = 1
    Top = 40
    Width = 264
    Height = 321
    ReadOnly = True
    TabOrder = 5
    Visible = False
  end
  object btnstop: TButton
    Left = 280
    Top = 440
    Width = 97
    Height = 25
    Caption = 'Stop'
    TabOrder = 6
    Visible = False
    OnClick = btnstopClick
  end
  object btn2: TButton
    Left = 8
    Top = 360
    Width = 75
    Height = 25
    Caption = 'dbgBtn1'
    TabOrder = 7
    Visible = False
    OnClick = btn2Click
  end
  object chkcreatesub: TCheckBox
    Left = 320
    Top = 76
    Width = 129
    Height = 21
    Caption = 'Create subdirectories'
    Checked = True
    State = cbChecked
    TabOrder = 8
  end
  object btn3: TButton
    Left = 376
    Top = 40
    Width = 89
    Height = 25
    Caption = 'Show log'
    TabOrder = 9
    OnClick = tooglelogmmo
  end
  object dlgOpen1: TOpenDialog
    Filter = 'Ego audio library (*.dic)|*.dic|Raw speech audion (*.raw)|*.raw'
    Left = 144
    Top = 8
  end
  object il1: TImageList
    Left = 112
    Top = 8
  end
  object tmrsoundtick: TTimer
    Enabled = False
    Interval = 500
    OnTimer = updateSoundTime
    Left = 176
    Top = 8
  end
end
