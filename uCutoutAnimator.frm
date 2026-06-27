object CutoutAnimatorForm: TCutoutAnimatorForm
  Left = 86
  Height = 706
  Top = 85
  Width = 1134
  BorderIcons = [biSystemMenu, biMinimize]
  BorderStyle = bsDialog
  Caption = 'Cutout Animator'
  ClientHeight = 706
  ClientWidth = 1134
  LCLVersion = '8.8'
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  object gbData: TGroupBox
    Left = 16
    Height = 144
    Top = 8
    Width = 1105
    Anchors = [akTop, akLeft, akRight]
    Caption = 'Data'
    ClientHeight = 124
    ClientWidth = 1101
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
      Width = 23
      Caption = 'Icon'
    end
    object btnBrowse: TButton
      Left = 632
      Height = 25
      Top = 30
      Width = 75
      Anchors = [akTop, akRight]
      Caption = 'Browse'
      TabOrder = 1
      OnClick = btnBrowseClick
    end
    object btnOK: TButton
      Left = 877
      Height = 25
      Top = 94
      Width = 75
      Anchors = [akTop, akRight]
      Caption = 'OK'
      ModalResult = 1
      TabOrder = 2
    end
    object btnCancel: TButton
      Left = 980
      Height = 25
      Top = 94
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
      Width = 35
      Caption = 'Width:'
    end
    object Label3: TLabel
      Left = 16
      Height = 15
      Top = 96
      Width = 39
      Caption = 'Heigth:'
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
    object seXorig: TSpinEdit
      Left = 304
      Height = 23
      Top = 64
      Width = 50
      TabOrder = 7
    end
    object seYorig: TSpinEdit
      Left = 304
      Height = 23
      Top = 96
      Width = 50
      TabOrder = 8
    end
    object lblXorig: TLabel
      Left = 240
      Height = 15
      Top = 64
      Width = 7
      Caption = 'X'
    end
    object lblYorig: TLabel
      Left = 240
      Height = 15
      Top = 94
      Width = 7
      Caption = 'Y'
    end
    object iconImage: TImage
      Left = 920
      Height = 90
      Top = -11
      Width = 90
    end
    object btnImgEdit: TButton
      Left = 720
      Height = 25
      Top = 30
      Width = 75
      Caption = 'Edit '
      TabOrder = 9
      OnClick = btnImgEditClick
    end
    object Label8: TLabel
      Left = 400
      Height = 15
      Top = 64
      Width = 35
      Caption = 'Name:'
    end
    object lblIconName: TLabel
      Left = 456
      Height = 15
      Top = 64
      Width = 68
      Caption = 'lblIconName'
    end
    object btnNewdAct: TButton
      Left = 720
      Height = 25
      Top = -2
      Width = 75
      Caption = 'New Action'
      TabOrder = 10
      OnClick = btnNewdActClick
    end
    object btnAct: TButton
      Left = 632
      Height = 25
      Top = -2
      Width = 75
      Caption = 'LoadAction'
      TabOrder = 11
      OnClick = btnActClick
    end
  end
  object gbAnimProps: TGroupBox
    Left = 16
    Height = 536
    Top = 160
    Width = 393
    Align = alCustom
    Caption = 'Animation list'
    ClientHeight = 516
    ClientWidth = 389
    TabOrder = 1
    object pnlAniList: TPanel
      AnchorSideBottom.Control = Splitter1
      Left = 3
      Height = 168
      Top = 0
      Width = 383
      Anchors = [akTop, akLeft, akBottom]
      ClientHeight = 168
      ClientWidth = 383
      TabOrder = 0
      object btnDeleteAnim: TButton
        Left = 96
        Height = 25
        Hint = 'Delete an animation/row.'
        Top = 8
        Width = 75
        Caption = 'Delete Anim'
        TabOrder = 0
        OnClick = btnDeleteAnimClick
      end
      object seAnimSpeed: TSpinEdit
        Left = 273
        Height = 23
        Hint = 'Delay between frames in miliseconds'
        Top = 104
        Width = 74
        TabOrder = 1
        Value = 100
        OnChange = AnimPropChange
      end
      object seAnimFrameCount: TSpinEdit
        Left = 273
        Height = 23
        Hint = 'Number of frames the animation has.'
        Top = 72
        Width = 74
        TabOrder = 2
        OnChange = AnimPropChange
      end
      object edAnimName: TEdit
        Left = 248
        Height = 23
        Hint = 'Name of the animation'
        Top = 8
        Width = 112
        TabOrder = 3
        TextHint = 'Animation name'
        OnChange = AnimPropChange
      end
      object lbAnimations: TListBox
        Left = 8
        Height = 96
        Hint = 'Select animation.'
        Top = 64
        Width = 176
        Anchors = [akTop, akLeft, akBottom]
        ItemHeight = 0
        TabOrder = 4
        OnClick = lbAnimationsClick
        OnDragDrop = lbAnimationsDragDrop
        OnDragOver = lbAnimationsDragOver
      end
      object lblAnimSpeed: TLabel
        Left = 194
        Height = 15
        Top = 104
        Width = 67
        Caption = 'Anim Speed:'
      end
      object seAnimRow: TSpinEdit
        Left = 273
        Height = 23
        Hint = 'The row where we will store the animation in the spritesheet.'
        Top = 40
        Width = 74
        TabOrder = 5
        OnChange = AnimPropChange
      end
      object lblFrameCount: TLabel
        Left = 194
        Height = 15
        Top = 72
        Width = 72
        Caption = 'Frame Count:'
      end
      object lblRowIdx: TLabel
        Left = 194
        Height = 15
        Top = 40
        Width = 26
        Caption = 'Row:'
      end
      object lblAnimName: TLabel
        Left = 193
        Height = 15
        Top = 8
        Width = 35
        Caption = 'Name:'
      end
      object btnAddAnim: TButton
        Left = 16
        Height = 25
        Hint = 'Add new animation/row'
        Top = 8
        Width = 75
        Caption = 'Add Anim'
        TabOrder = 6
        OnClick = btnAddAnimClick
      end
      object btnSaveAnim: TButton
        Left = 16
        Height = 25
        Hint = 'Save the animation parameters into an anim file. JSON formatted.'
        Top = 32
        Width = 75
        Caption = 'Save Anim'
        TabOrder = 7
        OnClick = btnSaveAnimClick
      end
      object btnLoadAnim: TButton
        Left = 96
        Height = 25
        Hint = 'Load animation parameters from file.'
        Top = 32
        Width = 75
        Caption = 'Load Anim'
        TabOrder = 8
        OnClick = btnLoadAnimClick
      end
      object Label4: TLabel
        Left = 192
        Height = 15
        Top = 136
        Width = 12
        Caption = 'H:'
      end
      object seAnimH: TSpinEdit
        Left = 208
        Height = 23
        Hint = 'Heigth of the frame/sprite'
        Top = 136
        Width = 58
        TabOrder = 9
      end
      object seAnimW: TSpinEdit
        Left = 297
        Height = 23
        Hint = 'Width of the frame/sprite.'
        Top = 137
        Width = 63
        TabOrder = 10
      end
      object Label7: TLabel
        Left = 273
        Height = 15
        Top = 137
        Width = 14
        Caption = 'W:'
      end
    end
    object Panel1: TPanel
      AnchorSideTop.Control = Splitter1
      AnchorSideTop.Side = asrBottom
      Left = -8
      Height = 1860
      Top = 173
      Width = 383
      Align = alCustom
      Anchors = [akTop, akLeft, akBottom]
      BorderSpacing.Bottom = 5
      Caption = 'Panel1'
      ClientHeight = 1860
      ClientWidth = 383
      TabOrder = 1
      object grFrameTransform: TGroupBox
        Left = 1
        Height = 1853
        Top = 6
        Width = 381
        Align = alClient
        BorderSpacing.Top = 5
        Caption = 'Frame Transform'
        ClientHeight = 1833
        ClientWidth = 377
        TabOrder = 0
        object PageControl1: TPageControl
          Left = 0
          Height = 1833
          Top = 0
          Width = 377
          ActivePage = TabSheet2
          Align = alClient
          TabIndex = 1
          TabOrder = 0
          object TabSheet1: TTabSheet
            Caption = 'Frames'
            ClientHeight = 1805
            ClientWidth = 369
            object btnApplyFrame: TButton
              Left = 8
              Height = 25
              Top = 8
              Width = 75
              Caption = 'Apply Frame'
              TabOrder = 0
              OnClick = btnApplyFrameClick
            end
            object sgFrameTransforms: TStringGrid
              Left = 0
              Height = 224
              Top = 64
              Width = 360
              Align = alCustom
              Anchors = [akTop, akLeft, akBottom]
              TabOrder = 1
              OnClick = sgFrameTransformsClick
            end
            object btnAddFrame: TButton
              Left = 96
              Height = 25
              Top = 8
              Width = 75
              Caption = 'Add Frame'
              TabOrder = 2
              OnClick = btnAddFrameClick
            end
            object btnDelFrame: TButton
              Left = 184
              Height = 25
              Top = 8
              Width = 75
              Caption = 'Del Frame'
              TabOrder = 3
              OnClick = btnDelFrameClick
            end
            object btnDupFrame: TButton
              Left = 272
              Height = 25
              Top = 8
              Width = 75
              Caption = 'Dup Frame'
              TabOrder = 4
              OnClick = btnDupFrameClick
            end
          end
          object TabSheet2: TTabSheet
            Caption = 'Layers'
            ClientHeight = 1805
            ClientWidth = 369
            object Panel2: TPanel
              Left = 0
              Height = 1805
              Top = 0
              Width = 369
              Align = alClient
              Caption = 'Panel2'
              ClientHeight = 1805
              ClientWidth = 369
              TabOrder = 0
              object VirtualStringTree1: TVirtualStringTree
                Left = 0
                Height = 255
                Top = 41
                Width = 264
                Align = alCustom
                Anchors = [akTop, akLeft, akBottom]
                CheckImageKind = ckLightTick
                DefaultText = 'Node'
                Header.AutoSizeIndex = 0
                Header.Columns = <>
                Header.MainColumn = -1
                TabOrder = 0
                TreeOptions.MiscOptions = [toAcceptOLEDrop, toCheckSupport, toFullRepaintOnResize, toGridExtensions, toInitOnSave, toToggleOnDblClick, toWheelPanning, toEditOnClick]
                OnChecking = VirtualStringTree1Checking
                OnDragOver = VirtualStringTree1DragOver
                OnDragDrop = VirtualStringTree1DragDrop
                OnFocusChanged = VirtualStringTree1FocusChanged
                OnFreeNode = VirtualStringTree1FreeNode
                OnGetText = VirtualStringTree1GetText
                OnGetNodeDataSize = VirtualStringTree1GetNodeDataSize
                OnNodeClick = VirtualStringTree1NodeClick
              end
              object lblOffsetX: TLabel
                Left = 272
                Height = 15
                Top = 112
                Width = 39
                Caption = 'OffsetX'
              end
              object lblOffsetY: TLabel
                Left = 272
                Height = 15
                Top = 144
                Width = 39
                Caption = 'OffsetY'
              end
              object lblAngle: TLabel
                Left = 272
                Height = 15
                Top = 184
                Width = 31
                Caption = 'Angle'
              end
              object seOffsetX: TSpinEdit
                Left = 318
                Height = 23
                Top = 112
                Width = 48
                TabOrder = 1
                OnChange = seOffsetXChange
              end
              object seOffsetY: TSpinEdit
                Left = 318
                Height = 23
                Top = 144
                Width = 48
                TabOrder = 2
                OnChange = seOffsetYChange
              end
              object seAngle: TFloatSpinEdit
                Left = 318
                Height = 23
                Top = 184
                Width = 48
                TabOrder = 3
                OnChange = seAngleChange
              end
              object seZIndex: TSpinEdit
                Left = 318
                Height = 23
                Top = 72
                Width = 48
                TabOrder = 4
              end
              object lblZIndex: TLabel
                Left = 272
                Height = 15
                Top = 72
                Width = 41
                Caption = 'Z-Index'
              end
              object btnEditLayer: TButton
                Left = 0
                Height = 25
                Top = 8
                Width = 75
                Caption = 'Edit Layer'
                TabOrder = 5
                OnClick = btnEditLayerClick
              end
              object btnNewLayer: TButton
                Left = 80
                Height = 25
                Top = 8
                Width = 75
                Caption = 'New Layer'
                TabOrder = 6
                OnClick = btnNewLayerClick
              end
              object btnDelLayer: TButton
                Left = 160
                Height = 25
                Top = 8
                Width = 75
                Caption = 'Del Layer'
                TabOrder = 7
                OnClick = btnDelLayerClick
              end
              object Label9: TLabel
                Left = 304
                Height = 15
                Top = 208
                Width = 27
                Caption = 'Pivot'
              end
              object sePivotX: TSpinEdit
                Left = 316
                Height = 23
                Top = 248
                Width = 52
                TabOrder = 8
                OnChange = sePivotXChange
              end
              object sePivotY: TSpinEdit
                Left = 316
                Height = 23
                Top = 273
                Width = 50
                TabOrder = 9
                OnChange = sePivotYChange
              end
              object Label10: TLabel
                Left = 280
                Height = 15
                Top = 281
                Width = 10
                Caption = 'Y:'
              end
              object Label11: TLabel
                Left = 280
                Height = 15
                Top = 249
                Width = 10
                Caption = 'X:'
              end
              object cbPVis: TCheckBox
                Left = 296
                Height = 19
                Top = 224
                Width = 52
                Caption = 'Visible'
                TabOrder = 10
                OnClick = cbPVisClick
              end
              object cbBehindParent: TCheckBox
                Left = 272
                Height = 19
                Top = 49
                Width = 92
                Caption = 'Behind Parent'
                TabOrder = 11
                OnClick = cbBehindParentClick
              end
              object btnFlipH: TButton
                Left = 256
                Height = 25
                Top = 8
                Width = 51
                Caption = 'Flip H'
                TabOrder = 12
                OnClick = btnFlipHClick
              end
              object btnFLipV: TButton
                Left = 313
                Height = 25
                Top = 8
                Width = 51
                Caption = 'Flip V'
                TabOrder = 13
                OnClick = btnFLipVClick
              end
            end
          end
        end
      end
    end
    object Splitter1: TSplitter
      Cursor = crVSplit
      Left = -80
      Height = 5
      Top = 168
      Width = 389
      Align = alNone
      Constraints.MaxHeight = 5
      Constraints.MinHeight = 5
      MinSize = 5
      ResizeAnchor = akBottom
    end
  end
  object gbPreview: TGroupBox
    Left = 416
    Height = 504
    Top = 160
    Width = 704
    Caption = 'Preview'
    ClientHeight = 484
    ClientWidth = 700
    TabOrder = 2
    object pbPreview: TPaintBox
      Left = 16
      Height = 424
      Top = 40
      Width = 424
      Constraints.MaxHeight = 450
      Constraints.MaxWidth = 450
      Constraints.MinHeight = 32
      Constraints.MinWidth = 32
      OnPaint = pbPreviewPaint
    end
    object tbZoom: TTrackBar
      Left = 448
      Height = 25
      Top = 216
      Width = 194
      Max = 600
      Min = 10
      Position = 100
      OnChange = tbZoomChange
      Color = 3487029
      ParentColor = False
      TabOrder = 0
    end
    object tbSpeed: TTrackBar
      Left = 448
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
      Left = 448
      Height = 25
      Top = 312
      Width = 155
      Max = 100
      Position = 0
      OnChange = tbFrameChange
      Color = 3487029
      ParentColor = False
      TabOrder = 2
    end
    object Zoom: TLabel
      Left = 528
      Height = 15
      Top = 192
      Width = 32
      Caption = 'Zoom'
    end
    object Label5: TLabel
      Left = 528
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
      Left = 648
      Height = 15
      Top = 216
      Width = 28
      Caption = '100%'
    end
    object lblSpeed: TLabel
      Left = 648
      Height = 15
      Top = 264
      Width = 45
      Caption = 'lblSpeed'
    end
    object lblTotalFrames: TLabel
      Left = 664
      Height = 15
      Top = 320
      Width = 76
      Caption = 'lblTotalFrames'
    end
    object seFrame: TSpinEdit
      Left = 608
      Height = 23
      Top = 314
      Width = 50
      TabOrder = 3
      OnChange = seFrameChange
    end
    object btnRefresh: TButton
      Left = 528
      Height = 25
      Top = 40
      Width = 75
      Caption = 'Refresh'
      TabOrder = 4
      OnClick = btnRefreshClick
    end
    object btnPlay: TButton
      Left = 528
      Height = 25
      Top = 96
      Width = 75
      Caption = 'Play'
      TabOrder = 5
      OnClick = btnPlayClick
    end
    object cbBackground: TComboBox
      Left = 515
      Height = 23
      Top = 155
      Width = 178
      ItemHeight = 15
      ItemIndex = 0
      Items.Strings = (
        'Checkerboard'
        'Gray'
      )
      TabOrder = 6
      Text = 'Checkerboard'
      OnChange = cbBackgroundChange
    end
    object Label14: TLabel
      Left = 448
      Height = 15
      Top = 155
      Width = 64
      Caption = 'Background'
    end
    object btnExportSprSet: TButton
      Left = 472
      Height = 25
      Top = 365
      Width = 99
      Caption = 'Export Sprite'
      TabOrder = 7
    end
    object btnExportMskSet: TButton
      Left = 584
      Height = 25
      Top = 365
      Width = 99
      Caption = 'Export Masked'
      TabOrder = 8
    end
    object btnPreviewSprite: TButton
      Left = 536
      Height = 25
      Top = 408
      Width = 83
      Caption = 'Preview Sprite'
      TabOrder = 9
    end
  end
  object Timer: TTimer
    Enabled = False
    OnTimer = TimerTimer
    Left = 1024
    Top = 24
  end
end
