object SpritesheetDialog: TSpritesheetDialog
  Left = 315
  Height = 573
  Top = 256
  Width = 1073
  BorderIcons = [biSystemMenu, biMinimize]
  BorderStyle = bsDialog
  Caption = 'SpritesheetDialog'
  ClientHeight = 573
  ClientWidth = 1073
  LCLVersion = '8.8'
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  object gbData: TGroupBox
    Left = 16
    Height = 176
    Top = 8
    Width = 1044
    Anchors = [akTop, akLeft, akRight]
    Caption = 'Data'
    ClientHeight = 156
    ClientWidth = 1040
    TabOrder = 0
    object edAction: TEdit
      Left = 72
      Height = 23
      Top = 0
      Width = 548
      Anchors = [akTop, akLeft, akRight]
      Constraints.MinWidth = 100
      TabOrder = 0
      TextHint = 'Action'
    end
    object lblAction: TLabel
      Left = 16
      Height = 15
      Top = 0
      Width = 38
      Caption = 'Action:'
    end
    object Label1: TLabel
      Left = 17
      Height = 15
      Top = 32
      Width = 36
      Caption = 'Image:'
    end
    object btnBrowse: TButton
      Left = 952
      Height = 25
      Top = 30
      Width = 75
      Anchors = [akTop, akRight]
      Caption = 'Browse'
      TabOrder = 1
      OnClick = btnBrowseClick
    end
    object btnOK: TButton
      Left = 380
      Height = 25
      Top = 112
      Width = 75
      Anchors = [akTop, akRight]
      Caption = 'OK'
      ModalResult = 1
      TabOrder = 2
    end
    object btnCancel: TButton
      Left = 592
      Height = 25
      Top = 112
      Width = 75
      Anchors = [akTop, akRight]
      Caption = 'Cancel'
      ModalResult = 2
      TabOrder = 3
    end
    object Label2: TLabel
      Left = 17
      Height = 15
      Top = 64
      Width = 68
      Caption = 'Sprite Width:'
    end
    object Label3: TLabel
      Left = 16
      Height = 15
      Top = 96
      Width = 72
      Caption = 'Sprite Heigth:'
    end
    object seTileW: TSpinEdit
      Left = 96
      Height = 23
      Top = 64
      Width = 98
      TabOrder = 4
    end
    object seTileH: TSpinEdit
      Left = 94
      Height = 23
      Top = 96
      Width = 100
      TabOrder = 5
    end
    object edImage: TEdit
      Left = 72
      Height = 23
      Top = 30
      Width = 548
      TabOrder = 6
      TextHint = 'Image path'
    end
  end
  object gbAnimProps: TGroupBox
    Left = 16
    Height = 368
    Top = 192
    Width = 393
    Caption = 'Animation list'
    ClientHeight = 348
    ClientWidth = 389
    TabOrder = 1
    object btnAddAnim: TButton
      Left = 8
      Height = 25
      Top = 8
      Width = 75
      Caption = 'Add Anim'
      TabOrder = 0
      OnClick = btnAddAnimClick
    end
    object btnDeleteAnim: TButton
      Left = 109
      Height = 25
      Top = 8
      Width = 75
      Caption = 'Delete Anim'
      TabOrder = 1
      OnClick = btnDeleteAnimClick
    end
    object lblAnimName: TLabel
      Left = 193
      Height = 15
      Top = 8
      Width = 35
      Caption = 'Name:'
    end
    object lblRowIdx: TLabel
      Left = 193
      Height = 15
      Top = 48
      Width = 26
      Caption = 'Row:'
    end
    object lblFrameCount: TLabel
      Left = 193
      Height = 15
      Top = 88
      Width = 72
      Caption = 'Frame Count:'
    end
    object lblAnimSpeed: TLabel
      Left = 193
      Height = 15
      Top = 128
      Width = 67
      Caption = 'Anim Speed:'
    end
    object seAnimRow: TSpinEdit
      Left = 272
      Height = 23
      Top = 48
      Width = 74
      TabOrder = 2
      OnChange = AnimPropChange
    end
    object seAnimFrameCount: TSpinEdit
      Left = 272
      Height = 23
      Top = 88
      Width = 74
      TabOrder = 3
      OnChange = AnimPropChange
    end
    object seAnimSpeed: TSpinEdit
      Left = 272
      Height = 23
      Top = 128
      Width = 74
      TabOrder = 4
      Value = 100
      OnChange = AnimPropChange
    end
    object lbAnimations: TListBox
      Left = 8
      Height = 304
      Top = 40
      Width = 176
      ItemHeight = 0
      TabOrder = 5
      OnClick = lbAnimationsClick
    end
    object edAnimName: TEdit
      Left = 248
      Height = 23
      Top = 8
      Width = 80
      TabOrder = 6
      TextHint = 'Animation name'
      OnChange = AnimPropChange
    end
  end
  object gbPreview: TGroupBox
    Left = 416
    Height = 368
    Top = 192
    Width = 640
    Caption = 'Preview'
    ClientHeight = 348
    ClientWidth = 636
    TabOrder = 2
    object pbPreview: TPaintBox
      Left = 8
      Height = 350
      Top = 0
      Width = 350
      Constraints.MaxHeight = 350
      Constraints.MaxWidth = 350
      Constraints.MinHeight = 32
      Constraints.MinWidth = 32
      OnPaint = pbPreviewPaint
    end
    object tbZoom: TTrackBar
      Left = 384
      Height = 25
      Top = 216
      Width = 194
      Max = 400
      Min = 10
      Position = 100
      OnChange = tbZoomChange
      Color = 3487029
      ParentColor = False
      TabOrder = 0
    end
    object tbSpeed: TTrackBar
      Left = 384
      Height = 25
      Top = 264
      Width = 194
      Max = 500
      Min = 10
      Position = 100
      OnChange = tbSpeedChange
      Color = 3487029
      ParentColor = False
      TabOrder = 1
    end
    object tbFrame: TTrackBar
      Left = 384
      Height = 25
      Top = 312
      Width = 155
      Position = 0
      OnChange = tbFrameChange
      Color = 3487029
      ParentColor = False
      TabOrder = 2
    end
    object Zoom: TLabel
      Left = 464
      Height = 15
      Top = 192
      Width = 32
      Caption = 'Zoom'
    end
    object Label5: TLabel
      Left = 464
      Height = 15
      Top = 248
      Width = 32
      Caption = 'Speed'
    end
    object Label6: TLabel
      Left = 448
      Height = 15
      Top = 296
      Width = 78
      Caption = 'Frame number'
    end
    object lblZoom: TLabel
      Left = 584
      Height = 15
      Top = 216
      Width = 28
      Caption = '100%'
    end
    object lblSpeed: TLabel
      Left = 584
      Height = 15
      Top = 264
      Width = 45
      Caption = 'lblSpeed'
    end
    object lblTotalFrames: TLabel
      Left = 600
      Height = 15
      Top = 320
      Width = 76
      Caption = 'lblTotalFrames'
    end
    object seFrame: TSpinEdit
      Left = 544
      Height = 23
      Top = 314
      Width = 50
      TabOrder = 3
      OnChange = seFrameChange
    end
    object btnRefresh: TButton
      Left = 464
      Height = 25
      Top = 40
      Width = 75
      Caption = 'Refresh'
      TabOrder = 4
      OnClick = btnRefreshClick
    end
    object btnPlay: TButton
      Left = 464
      Height = 25
      Top = 96
      Width = 75
      Caption = 'Play'
      TabOrder = 5
      OnClick = btnPlayClick
    end
    object cbBackground: TComboBox
      Left = 449
      Height = 23
      Top = 155
      Width = 178
      ItemHeight = 15
      ItemIndex = 1
      Items.Strings = (
        'Solid (gray)'
        'Checkerboard'
      )
      TabOrder = 6
      Text = 'Checkerboard'
      OnChange = cbBackgroundChange
    end
    object Label14: TLabel
      Left = 376
      Height = 15
      Top = 155
      Width = 64
      Caption = 'Background'
    end
  end
  object Timer: TTimer
    Enabled = False
    OnTimer = TimerTimer
    Left = 842
    Top = 37
  end
end
