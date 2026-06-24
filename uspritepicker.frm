object SpritePickerForm: TSpritePickerForm
  Left = 501
  Height = 594
  Top = 256
  Width = 947
  BorderStyle = bsSizeToolWin
  Caption = 'SpritePickerForm'
  ClientHeight = 594
  ClientWidth = 947
  LCLVersion = '8.8'
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  object btnOk: TButton
    Left = 16
    Height = 25
    Top = 144
    Width = 75
    Caption = 'Ok'
    ModalResult = 1
    TabOrder = 0
  end
  object btnCancel: TButton
    Left = 152
    Height = 25
    Top = 144
    Width = 75
    Caption = 'Cancel'
    ModalResult = 2
    TabOrder = 1
  end
  object imgSample: TImage
    Left = 56
    Height = 128
    Top = 8
    Width = 128
    Constraints.MaxHeight = 128
    Constraints.MaxWidth = 128
    Constraints.MinHeight = 128
    Constraints.MinWidth = 128
  end
  object btnLoadSet: TButton
    Left = 16
    Height = 25
    Top = 176
    Width = 75
    Caption = 'Load Set'
    TabOrder = 2
    OnClick = btnLoadSetClick
  end
  object GLControl: TOpenGLControl
    Left = 264
    Height = 570
    Top = 16
    Width = 669
    Anchors = [akTop, akLeft, akRight, akBottom]
    OnMouseDown = GLControlMouseDown
    OnMouseMove = GLControlMouseMove
    OnMouseUp = GLControlMouseUp
    OnPaint = GLControlPaint
    OnResize = GLControlResize
  end
  object lbTiles: TListBox
    Left = 8
    Height = 176
    Top = 272
    Width = 240
    ItemHeight = 0
    TabOrder = 4
    OnClick = lbTilesClick
  end
  object seX: TSpinEdit
    Left = 40
    Height = 23
    Top = 528
    Width = 50
    TabOrder = 5
    OnChange = seXChange
  end
  object seY: TSpinEdit
    Left = 40
    Height = 23
    Top = 560
    Width = 50
    TabOrder = 6
    OnChange = seYChange
  end
  object seW: TSpinEdit
    Left = 160
    Height = 23
    Top = 528
    Width = 50
    TabOrder = 7
    OnChange = seWChange
  end
  object seH: TSpinEdit
    Left = 160
    Height = 23
    Top = 560
    Width = 50
    TabOrder = 8
    OnChange = seHChange
  end
  object btnNewTile: TButton
    Left = 24
    Height = 25
    Top = 456
    Width = 75
    Caption = 'New Tile'
    TabOrder = 9
    OnClick = btnNewTileClick
  end
  object btnDelTile: TButton
    Left = 152
    Height = 25
    Top = 456
    Width = 75
    Caption = 'Del Tile'
    TabOrder = 10
    OnClick = btnDelTileClick
  end
  object btnSaveSet: TButton
    Left = 152
    Height = 25
    Top = 176
    Width = 75
    Caption = 'Save Set'
    TabOrder = 11
    OnClick = btnSaveSetClick
  end
  object btnChange: TButton
    Left = 15
    Height = 25
    Top = 208
    Width = 75
    Caption = 'Change img'
    TabOrder = 12
    OnClick = btnChangeClick
  end
  object btnBgColor: TButton
    Left = 152
    Height = 25
    Top = 208
    Width = 75
    Caption = 'BgColor'
    TabOrder = 13
    OnClick = btnBgColorClick
  end
  object TrackBar1: TTrackBar
    Left = 8
    Height = 17
    Top = 248
    Width = 240
    Max = 200
    Position = 0
    OnChange = TrackBar1Change
    Color = 3487029
    ParentColor = False
    TabOrder = 14
  end
  object Label1: TLabel
    Left = 104
    Height = 15
    Top = 232
    Width = 32
    Caption = 'Zoom'
  end
  object Label2: TLabel
    Left = 15
    Height = 15
    Top = 528
    Width = 10
    Caption = 'X:'
  end
  object Label3: TLabel
    Left = 120
    Height = 15
    Top = 528
    Width = 14
    Caption = 'W:'
  end
  object Label4: TLabel
    Left = 15
    Height = 15
    Top = 560
    Width = 10
    Caption = 'Y:'
  end
  object Label5: TLabel
    Left = 120
    Height = 15
    Top = 560
    Width = 12
    Caption = 'H:'
  end
  object lblName: TLabel
    Left = 16
    Height = 15
    Top = 496
    Width = 56
    Caption = 'Tile Name:'
  end
  object edTileName: TEdit
    Left = 88
    Height = 23
    Top = 496
    Width = 139
    TabOrder = 15
    Text = 'edTileName'
    OnChange = edTileNameChange
  end
  object OpenPictureDialog1: TOpenPictureDialog
    Left = 16
    Top = 24
  end
  object ColorDlg: TColorDialog
    Color = clBlack
    CustomColors.Strings = (
      'ColorA=000000'
      'ColorB=000080'
      'ColorC=008000'
      'ColorD=008080'
      'ColorE=800000'
      'ColorF=800080'
      'ColorG=808000'
      'ColorH=808080'
      'ColorI=C0C0C0'
      'ColorJ=0000FF'
      'ColorK=00FF00'
      'ColorL=00FFFF'
      'ColorM=FF0000'
      'ColorN=FF00FF'
      'ColorO=FFFF00'
      'ColorP=FFFFFF'
      'ColorQ=C0DCC0'
      'ColorR=F0CAA6'
      'ColorS=F0FBFF'
      'ColorT=A4A0A0'
    )
    Left = 16
    Top = 78
  end
end
