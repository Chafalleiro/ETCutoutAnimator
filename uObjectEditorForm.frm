object ObjectEditorForm: TObjectEditorForm
  Left = 501
  Height = 505
  Top = 256
  Width = 805
  BorderStyle = bsDialog
  Caption = 'ObjectEditorForm'
  ClientHeight = 505
  ClientWidth = 805
  LCLVersion = '8.8'
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  object Splitter1: TSplitter
    Left = 0
    Height = 505
    Top = 0
    Width = 5
  end
  object PanelLeft: TPanel
    Left = 16
    Height = 482
    Top = 16
    Width = 298
    Anchors = [akTop, akLeft, akBottom]
    Caption = 'PanelLeft'
    ClientHeight = 482
    ClientWidth = 298
    TabOrder = 1
    object TreeObjects: TVirtualStringTree
      Left = 0
      Height = 424
      Top = 0
      Width = 288
      DefaultText = 'Node'
      Header.AutoSizeIndex = 0
      Header.Columns = <>
      Header.MainColumn = -1
      TabOrder = 0
      OnFocusChanged = TreeObjectsFocusChanged
      OnFreeNode = TreeObjectsFreeNode
      OnGetText = TreeObjectsGetText
      OnGetNodeDataSize = TreeObjectsGetNodeDataSize
    end
    object PanelButtons: TPanel
      Left = 40
      Height = 40
      Top = 424
      Width = 198
      ClientHeight = 40
      ClientWidth = 198
      TabOrder = 1
      object btnNew: TButton
        Left = 8
        Height = 25
        Top = 8
        Width = 75
        Caption = 'New'
        TabOrder = 0
        OnClick = btnNewClick
      end
      object btnDelete: TButton
        Left = 112
        Height = 25
        Top = 8
        Width = 75
        Caption = 'Delete'
        TabOrder = 1
        OnClick = btnDeleteClick
      end
    end
  end
  object PanelRight: TPanel
    Left = 328
    Height = 490
    Top = 8
    Width = 472
    Anchors = [akTop, akLeft, akBottom]
    ClientHeight = 490
    ClientWidth = 472
    TabOrder = 2
    object gbBasic: TGroupBox
      Left = 16
      Height = 280
      Top = 8
      Width = 217
      Caption = 'Basic'
      ClientHeight = 260
      ClientWidth = 213
      TabOrder = 0
      object lblName: TLabel
        Left = 9
        Height = 15
        Top = 8
        Width = 32
        Caption = 'Name'
      end
      object lblType: TLabel
        Left = 16
        Height = 15
        Top = 80
        Width = 24
        Caption = 'Type'
      end
      object edName: TEdit
        Left = 96
        Height = 23
        Top = 8
        Width = 112
        TabOrder = 0
      end
      object cbCategory: TComboBox
        Left = 96
        Height = 23
        Top = 80
        Width = 112
        ItemHeight = 15
        ItemIndex = 0
        Items.Strings = (
          'Weapon'
          'Clothing'
          'Tool'
          'Static'
          'Consumable'
          'Quest Item'
        )
        TabOrder = 1
        Text = 'Weapon'
      end
      object imgIcon: TImage
        Left = 64
        Height = 90
        Top = 120
        Width = 90
      end
      object btnIcon: TButton
        Left = 72
        Height = 25
        Top = 224
        Width = 75
        Caption = 'Set Icon'
        TabOrder = 2
        OnClick = btnIconClick
      end
    end
    object gbSpritesheets: TGroupBox
      Left = 248
      Height = 296
      Top = 8
      Width = 218
      Caption = 'Spritesheets'
      ClientHeight = 276
      ClientWidth = 214
      TabOrder = 1
      object lbSpritesheets: TListBox
        Left = 8
        Height = 186
        Top = 0
        Width = 200
        ItemHeight = 0
        TabOrder = 0
      end
      object btnAddSpritesheet: TButton
        Left = 8
        Height = 25
        Top = 200
        Width = 91
        Caption = 'Add Animations'
        TabOrder = 1
        OnClick = btnAddSpritesheetClick
      end
      object btnEditSpritesheet: TButton
        Left = 112
        Height = 25
        Top = 200
        Width = 96
        Caption = 'Edit Animations'
        TabOrder = 2
        OnClick = btnEditSpritesheetClick
      end
      object btnDeleteSpritesheet: TButton
        Left = 64
        Height = 25
        Top = 232
        Width = 91
        Caption = 'Del Animations'
        TabOrder = 3
        OnClick = btnDeleteSpritesheetClick
      end
    end
    object gbInventory: TGroupBox
      Left = 16
      Height = 120
      Top = 296
      Width = 217
      Caption = 'Inventory'
      ClientHeight = 100
      ClientWidth = 213
      TabOrder = 2
      object lblStackSize: TLabel
        Left = 8
        Height = 15
        Top = 32
        Width = 51
        Caption = 'Stack Size'
      end
      object seInventorySize: TSpinEdit
        Left = 95
        Height = 23
        Top = 34
        Width = 103
        TabOrder = 0
      end
    end
    object gbStats: TGroupBox
      Left = 248
      Height = 187
      Top = 288
      Width = 218
      Caption = 'Stats'
      ClientHeight = 167
      ClientWidth = 214
      TabOrder = 3
      object sgStats: TStringGrid
        Left = 8
        Height = 151
        Top = 8
        Width = 200
        FixedCols = 0
        HeaderHotZones = [gzFixedRows]
        HeaderPushZones = [gzFixedRows]
        Options = [goFixedVertLine, goFixedHorzLine, goVertLine, goHorzLine, goRangeSelect, goEditing, goAutoAddRows, goTabs, goAlwaysShowEditor, goSmoothScroll, goAutoAddRowsSkipContentCheck]
        Options2 = [goFixedColClick, goFixedRowClick]
        TabOrder = 0
        OnSelectCell = sgStatsSelectCell
        OnSetEditText = sgStatsSetEditText
      end
    end
  end
  object cbTradeable: TCheckBox
    Left = 488
    Height = 19
    Top = 80
    Width = 69
    Caption = 'Tradeable'
    TabOrder = 3
  end
  object cbStack: TCheckBox
    Left = 416
    Height = 19
    Top = 320
    Width = 59
    Caption = 'Stacked'
    TabOrder = 4
  end
  object cbIndexed: TCheckBox
    Left = 360
    Height = 19
    Top = 80
    Width = 60
    Caption = 'Indexed'
    TabOrder = 5
  end
  object gbGlobal: TGroupBox
    Left = 288
    Height = 48
    Top = 440
    Width = 184
    Caption = 'Global'
    ClientHeight = 28
    ClientWidth = 180
    TabOrder = 6
    object btnSave: TButton
      Left = 8
      Height = 25
      Top = 0
      Width = 75
      Caption = 'Save'
      TabOrder = 0
      OnClick = btnSaveClick
    end
    object btnReload: TButton
      Left = 96
      Height = 25
      Top = 0
      Width = 75
      Caption = 'Reload'
      TabOrder = 1
      OnClick = btnReloadClick
    end
  end
end
