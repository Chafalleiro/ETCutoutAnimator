unit uObjectEditorForm;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, ExtCtrls, StdCtrls,
  Spin, Buttons, ComCtrls, Grids, VirtualTrees, BGRABitmap, BGRABitmapTypes,
  fpjson, jsonparser, uDebugLog, uSpritePicker, uCutoutAnimator;

type
  TTransformType = uCutoutAnimator.TTransformType;
  TAnimationDef = uCutoutAnimator.TAnimationDef;
  PAnimationDef = uCutoutAnimator.PAnimationDef;

  // Reusable icon definition — same structure for the object's main Icon
  // and each action's ActIcon. Points at a tile inside a source image.
  TIconDef = record
    SourceImage: string;     // actual image file (PNG/BMP/...)
    TilesetPath: string;     // descriptor file (or same as SourceImage)
    X: integer;
    Y: integer;
    W: integer;
    H: integer;
    Name: string;
  end;

  // Animation reference — just a path to the .anim file + the row position
  // where this animation should be rendered in the composed spritesheet.
  TAnimRef = record
    AnimFile: string;
    Row: integer;
  end;

  // Action — a named behaviour (walk, attack, etc.) that can have multiple
  // orientation-related animations. Each action has its own ActIcon which
  // also serves as the default image for layers in the animation composer.
  TAction = record
    Name: string;
    ActIcon: TIconDef;
    Animations: array of TAnimRef;
  end;

  // Object main record
  TObject = class
  public
    ID: string;                 // unique ID with prefix (NPC_, MOB_, OBJ_)
    Name: string;
    Category: string;          // "Weapon", "Clothing", "Tool", "Static", "Consumable", "Quest Item"
    Indexed: boolean;           // if true, included in external index file
    Tradeable: boolean;         // can be traded between players/NPCs
    Stacked: boolean;           // stackable in inventories
    StackSize: integer;         // max stack count
    Stats: TStringList;         // key-value pairs (e.g., "HP=100", "MP=50")
    Icon: TIconDef;             // main object icon (tile reference)
    Actions: array of TAction;  // available actions with their animations

    constructor Create;
    destructor Destroy; override;
    procedure Assign(Source: TObject);
  end;

  // Node data for the Virtual Tree
  PObjectNode = ^TObjectNode;

  TObjectNode = record
    anObject: TObject;
  end;

  { TObjectEditorForm }

  TObjectEditorForm = class(TForm)
    btnIcon: TButton;
    cbCategory: TComboBox;
    imgIcon: TImage;
    seInventorySize: TSpinEdit;
    // Main splitter and panels
    Splitter1: TSplitter;
    PanelLeft: TPanel;
    PanelRight: TPanel;
    PanelButtons: TPanel;

    // Left side: character tree and buttons
    TreeObjects: TVirtualStringTree;
    btnNew: TButton;
    btnDelete: TButton;

    // Right side: character editing controls (grouped by category)
    gbBasic: TGroupBox;
    lblName: TLabel;
    edName: TEdit;
    lblType: TLabel;
    cbTradeable: TCheckBox;
    cbStack: TCheckBox;
    cbIndexed: TCheckBox;

    gbSpritesheets: TGroupBox;
    lbSpritesheets: TListBox;
    btnAddSpritesheet: TButton;
    btnEditSpritesheet: TButton;
    btnDeleteSpritesheet: TButton;

    gbInventory: TGroupBox;
    lblStackSize: TLabel;

    gbStats: TGroupBox;
    sgStats: TStringGrid;

    gbGlobal: TGroupBox;
    btnSave: TButton;
    btnReload: TButton;

    procedure btnIconClick(Sender: TObject);
    procedure cbCategoryChange(Sender: System.TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);

    procedure TreeObjectsFreeNode(Sender: TBaseVirtualTree; Node: PVirtualNode);
    procedure TreeObjectsGetText(Sender: TBaseVirtualTree; Node: PVirtualNode; Column: TColumnIndex; TextType: TVSTTextType; var CellText: string);
    procedure TreeObjectsGetNodeDataSize(Sender: TBaseVirtualTree; var NodeDataSize: integer);
    procedure TreeObjectsFocusChanged(Sender: TBaseVirtualTree; Node: PVirtualNode; Column: TColumnIndex);
    procedure btnNewClick(Sender: TObject);
    procedure btnDeleteClick(Sender: TObject);
    procedure btnSaveClick(Sender: TObject);
    procedure btnReloadClick(Sender: TObject);
    procedure btnAddSpritesheetClick(Sender: TObject);
    procedure btnEditSpritesheetClick(Sender: TObject);
    procedure btnDeleteSpritesheetClick(Sender: TObject);
    procedure sgStatsSetEditText(Sender: TObject; ACol, ARow: integer; const Value: string);
    procedure sgStatsSelectCell(Sender: TObject; ACol, ARow: integer; var CanSelect: boolean);

    function GetFileSize(const FileName: string): int64;
  private
    FObjects: TList;          // list of TObject*
    FCurrentFile: string;
    FSelectedObject: TObject;
    FUpdating: boolean;       // guards against OnChange handlers firing
                              // during programmatic UI updates

    // Internal helpers
    procedure ClearObjects;
    procedure LoadObjectsFromFile(const FileName: string);
    procedure SaveObjectsToFile(const FileName: string);
    procedure UpdateIndexFile;
    function GenerateUniqueID(const Prefix: string): string;
    procedure PopulateTree;
    procedure UpdateDetailPanel(anObject: TObject);
    procedure ClearDetailPanel;
    procedure LoadObjectToUI(anObject: TObject);
    procedure SaveUIToObject(anObject: TObject);
    procedure AddDefaultObject;
    procedure ApplyCategoryDefaults(anObject: TObject; const Category: string);
    procedure EditAction(anObject: TObject; Index: integer);
    procedure RefreshActionList;
    procedure RefreshStatsGrid;
    procedure CommitStatsGrid;  // reads grid → FSelectedObject.Stats

    procedure RenderIcon(anObject: TObject);
    procedure ClearIconImage;

    procedure SaveGlobalIndex;
  public
    procedure LoadFile(const FileName: string);
    procedure SaveFile;
  end;

implementation

{$R *.frm}

uses
  TypInfo, DateUtils, StrUtils, Math;

  { TObject }

constructor TObject.Create;
begin
  TDebugLogger.Debug('TObject.Create', {$I %CURRENTROUTINE%}, {$I %FILE%}, {$I %lineNum%});
  Stats := TStringList.Create;
  Indexed := False;
  Tradeable := False;
  Stacked := False;
  StackSize := 0;
  Name := '';
  ID := '';
  Category := '';
  // Icon defaults — TIconDef is a record, fields auto-zero-initialized
  Icon.SourceImage := '';
  Icon.TilesetPath := '';
  Icon.Name := '';
  TDebugLogger.Debug('TObject.Create END', {$I %CURRENTROUTINE%}, {$I %FILE%}, {$I %lineNum%});
end;

destructor TObject.Destroy;
var
  i, j: integer;
begin
  Stats.Free;

  // ---------------------------------------------------------------------
  // Explicitly release TAction contents BEFORE SetLength.
  //
  // This class is named TObject (shadows System.TObject), and in that
  // configuration FPC's auto-finalization of managed fields nested
  // inside dynamic arrays of records does not appear to fire reliably.
  //
  // SetLength(Actions, 0) alone is NOT enough — it drops the array
  // reference but leaves the per-TAction strings allocated:
  //   - Actions[i].Name
  //   - Actions[i].ActIcon.SourceImage / TilesetPath / Name
  //   - Actions[i].Animations[]          (the dyn-array storage itself)
  //   - Actions[i].Animations[k].AnimFile
  //
  // Walking the array and clearing each managed field manually is the
  // safe workaround: every string assignment decrements the refcount,
  // every SetLength(..., 0) on a nested dyn-array releases its storage.
  // This matches the leak pattern observed in heapdump_Obj.txt (one
  // TAction with N Animations = 4 + N unfreed blocks).
  // ---------------------------------------------------------------------
  for i := 0 to High(Actions) do
  begin
    Actions[i].Name := '';
    Actions[i].ActIcon.SourceImage := '';
    Actions[i].ActIcon.TilesetPath := '';
    Actions[i].ActIcon.Name := '';
    for j := 0 to High(Actions[i].Animations) do
      Actions[i].Animations[j].AnimFile := '';
    SetLength(Actions[i].Animations, 0);
  end;
  SetLength(Actions, 0);

  Icon.SourceImage := '';
  Icon.TilesetPath := '';
  Icon.Name := '';
  ID := '';
  Name := '';
  Category := '';
  inherited;
end;

procedure TObject.Assign(Source: TObject);
var
  i, j: integer;
begin
  TDebugLogger.Debug('TObject.Assing', {$I %CURRENTROUTINE%}, {$I %FILE%}, {$I %lineNum%});
  ID := Source.ID;
  Name := Source.Name;
  Category := Source.Category;
  Indexed := Source.Indexed;
  Tradeable := Source.Tradeable;
  Stacked := Source.Stacked;
  StackSize := Source.StackSize;
  Icon := Source.Icon;  // TIconDef is a record — direct copy

  // Deep-copy Actions (each TAction contains a dynamic array of TAnimRef)
  SetLength(Actions, Length(Source.Actions));
  for i := 0 to High(Source.Actions) do
  begin
    Actions[i].Name := Source.Actions[i].Name;
    Actions[i].ActIcon := Source.Actions[i].ActIcon;
    SetLength(Actions[i].Animations, Length(Source.Actions[i].Animations));
    for j := 0 to High(Source.Actions[i].Animations) do
      Actions[i].Animations[j] := Source.Actions[i].Animations[j];
  end;

  Stats.Assign(Source.Stats);
  TDebugLogger.Debug('TObject.Assing', {$I %CURRENTROUTINE%}, {$I %FILE%}, {$I %lineNum%});
end;

{ TObjectEditorForm }

procedure TObjectEditorForm.FormCreate(Sender: TObject);
begin
  TDebugLogger.SetLogLevel(dllDebug);
  TDebugLogger.SetLogFile('ObjectPlugin.log');
  TDebugLogger.Debug('ObjectEditor FormCreate', {$I %CURRENTROUTINE%}, {$I %FILE%}, {$I %lineNum%});

  FObjects := TList.Create;
  FUpdating := False;

  // Configure tree
  TreeObjects.NodeDataSize := SizeOf(TObjectNode);
  TreeObjects.Header.Columns.Add;
  TreeObjects.Header.Columns[0].Text := 'Type';
  TreeObjects.Header.Columns[0].Width := 60;
  TreeObjects.Header.Columns.Add;
  TreeObjects.Header.Columns[1].Text := 'Name';
  TreeObjects.Header.Columns[1].Width := 150;
  TreeObjects.Header.Columns.Add;
  TreeObjects.Header.Columns[2].Text := 'ID';
  TreeObjects.Header.Columns[2].Width := 200;

  sgStats.ColCount := 2;
  sgStats.RowCount := 2;
  sgStats.FixedCols := 0;   // no fixed columns — both Stat and Value
                             // columns are editable. Default FixedCols=1
                             // makes column 0 gray/non-editable, which
                             // prevented editing the stat name.
  sgStats.FixedRows := 1;   // keep row 0 as the header (fixed, gray)
  sgStats.Cells[0, 0] := 'Stat';
  sgStats.Cells[1, 0] := 'Value';
  // goAutoAddRows is NOT included — it conflicts with our manual empty-row
  // logic in RefreshStatsGrid. We manage the empty row ourselves.
  sgStats.Options := sgStats.Options + [goEditing, goAlwaysShowEditor, goTabs];
  sgStats.Options := sgStats.Options - [goAutoAddRows];
  // Wire OnSelectCell to add a new empty row when the user navigates
  // away from the last row (if it has content). This gives the
  // "infinite empty row" feel without per-keystroke chaos.
//  sgStats.OnSelectCell := @sgStatsSelectCell;

  // Wire cbCategory.OnChange so changing the category offers to apply
  // category-specific defaults (stats, stacked, tradeable, etc.).
  cbCategory.OnChange := @cbCategoryChange;

  // Start with empty UI
  ClearDetailPanel;
end;

procedure TObjectEditorForm.btnIconClick(Sender: TObject);
var
  OD: TOpenDialog;
  Picker: TSpritePickerForm;
  PickedTile: TTileDef;
  StartPath: string;
begin
  if FSelectedObject = nil then
  begin
    ShowMessage('Select an object first.');
    Exit;
  end;

  // -------------------------------------------------------------------
  // Step 1: figure out which tileset to load. Prefer the object's
  // existing IconTilesetPath / IconSourceImage so the user can re-pick
  // from the same tileset without re-browsing. If neither is set or the
  // file is missing, fall back to a TOpenDialog so the user can pick
  // a .tileset / .json / image file. This mirrors the pattern used in
  // uCutoutAnimator.btnBrowseClick / btnImgEditClick.
  // -------------------------------------------------------------------
  StartPath := '';
  if (FSelectedObject.Icon.TilesetPath <> '') and FileExists(FSelectedObject.Icon.TilesetPath) then
    StartPath := FSelectedObject.Icon.TilesetPath
  else if (FSelectedObject.Icon.SourceImage <> '') and FileExists(FSelectedObject.Icon.SourceImage) then
    StartPath := FSelectedObject.Icon.SourceImage;

  if StartPath = '' then
  begin
    OD := TOpenDialog.Create(Self);
    try
      OD.Title := 'Pick tileset for object icon';
      OD.Filter := 'Tileset files|*.tileset;*.json|Image files|*.png;*.jpg;*.jpeg;*.bmp;*.gif|All files|*.*';
      if not OD.Execute then Exit;
      StartPath := OD.FileName;
    finally
      OD.Free;
    end;
  end;

  // -------------------------------------------------------------------
  // Step 2: open TSpritePickerForm on that tileset. The picker lets the
  // user pan/zoom the source image, draw new tile rects, or select an
  // existing tile from a previously-saved tileset descriptor. On OK it
  // exposes the picked tile via GetSelectedTile + GetImagePath.
  // -------------------------------------------------------------------
  Picker := TSpritePickerForm.Create(Application);
  try
    Picker.LoadTileset(StartPath);
    Picker.Caption := 'Pick Object Icon — ' + FSelectedObject.Name;
    if Picker.ShowModal <> mrOk then Exit;

    if Picker.SelectedIndex < 0 then
    begin
      ShowMessage('No tile selected.');
      Exit;
    end;

    PickedTile := Picker.GetSelectedTile;

    // -----------------------------------------------------------------
    // Step 3: write the picked tile back onto the object's icon fields.
    // IconSourceImage is the actual image file the picker opened (so
    // RenderIcon can re-extract the tile pixels later); IconTilesetPath
    // is the descriptor file (could be the same as IconSourceImage when
    // the user pointed at a plain PNG/BMP instead of a .tileset/.json).
    // -----------------------------------------------------------------
    FSelectedObject.Icon.SourceImage := Picker.GetImagePath;
    FSelectedObject.Icon.TilesetPath := StartPath;
    FSelectedObject.Icon.X := PickedTile.X;
    FSelectedObject.Icon.Y := PickedTile.Y;
    FSelectedObject.Icon.W := PickedTile.Width;
    FSelectedObject.Icon.H := PickedTile.Height;
    if PickedTile.Name <> '' then
      FSelectedObject.Icon.Name := PickedTile.Name
    else
      FSelectedObject.Icon.Name := ExtractFileName(StartPath);

    RenderIcon(FSelectedObject);
  finally
    Picker.Free;
  end;
end;

procedure TObjectEditorForm.cbCategoryChange(Sender: System.TObject);
var
  newCategory: string;
  response: integer;
begin
  // When the user changes the category in the detail panel, offer to
  // apply category-specific defaults. This replaces the object's stats
  // and checkbox states with the new category's defaults — useful when
  // the user created an object as "Static" and later decides it's a
  // "Consumable".
  //
  // We ask for confirmation because this DESTROYS the current stats —
  // the user may have added custom stats they want to keep. If they
  // say No, only the Category field changes (no stat/checkbox reset).
  if (FSelectedObject = nil) or FUpdating then Exit;
  newCategory := cbCategory.Text;
  if newCategory = FSelectedObject.Category then Exit;  // no change
  response := MessageDlg('Apply Category Defaults',
    Format('Apply default stats and properties for "%s"?'#10#10 +
           'This will replace the current stats. Choose No to keep ' +
           'existing stats and only change the category.',
           [newCategory]),
    mtConfirmation, [mbYes, mbNo, mbCancel], 0);
  if response = mrCancel then
  begin
    // Revert the combo box to the object's current category
    FUpdating := True;
    try
      cbCategory.Text := FSelectedObject.Category;
    finally
      FUpdating := False;
    end;
    Exit;
  end;
  if response = mrYes then
  begin
    ApplyCategoryDefaults(FSelectedObject, newCategory);
    // Reload the UI to show the new defaults
    LoadObjectToUI(FSelectedObject);
  end
  else
  begin
    // No — just change the category, keep existing stats.
    // Commit the grid first so any pending edits are captured.
    CommitStatsGrid;
    FSelectedObject.Category := newCategory;
  end;
end;

procedure TObjectEditorForm.RenderIcon(anObject: TObject);
var
  Src: TBGRABitmap;
  TileBmp: TBGRABitmap;
  ScaledBmp: TBGRABitmap;
  W, H, SW, SH: integer;
begin
  if imgIcon = nil then Exit;

  // Always start from a clean bitmap so stale icons don't bleed through.
  imgIcon.Picture.Bitmap.SetSize(0, 0);
  imgIcon.Picture.Assign(nil);

  if (anObject = nil) or (anObject.Icon.SourceImage = '') or
     (not FileExists(anObject.Icon.SourceImage)) then Exit;
  if (anObject.Icon.W <= 0) or (anObject.Icon.H <= 0) then Exit;

  try
    Src := TBGRABitmap.Create(anObject.Icon.SourceImage);
  except
    Exit;
  end;
  try
    if (anObject.Icon.X + anObject.Icon.W > Src.Width) or
       (anObject.Icon.Y + anObject.Icon.H > Src.Height) then Exit;

    TileBmp := Src.GetPart(Rect(anObject.Icon.X, anObject.Icon.Y,
      anObject.Icon.X + anObject.Icon.W, anObject.Icon.Y + anObject.Icon.H)) as TBGRABitmap;
    try
      W := imgIcon.ClientWidth;
      H := imgIcon.ClientHeight;
      if (W <= 0) or (H <= 0) then
      begin
        W := imgIcon.Width;
        H := imgIcon.Height;
      end;
      if (W <= 0) or (H <= 0) then Exit;

      imgIcon.Picture.Bitmap.SetSize(W, H);
      // Preserve aspect ratio while fitting into the available area
      SW := W;
      SH := H;
      if TileBmp.Width / TileBmp.Height > W / H then
        SH := Round(W * TileBmp.Height / TileBmp.Width)
      else
        SW := Round(H * TileBmp.Width / TileBmp.Height);

      ScaledBmp := TileBmp.Resample(SW, SH) as TBGRABitmap;
      try
        ScaledBmp.Draw(imgIcon.Picture.Bitmap.Canvas,
          (W - SW) div 2, (H - SH) div 2, False);
        imgIcon.Invalidate;
      finally
        ScaledBmp.Free;
      end;
    finally
      TileBmp.Free;
    end;
  finally
    Src.Free;
  end;
end;

procedure TObjectEditorForm.ClearIconImage;
begin
  if imgIcon = nil then Exit;
  imgIcon.Picture.Bitmap.SetSize(0, 0);
  imgIcon.Picture.Assign(nil);
  imgIcon.Invalidate;
end;

procedure TObjectEditorForm.FormDestroy(Sender: TObject);
begin
  ClearObjects;
  FObjects.Free;
end;

procedure TObjectEditorForm.TreeObjectsFreeNode(Sender: TBaseVirtualTree; Node: PVirtualNode);
begin

end;

procedure TObjectEditorForm.ClearObjects;
var
  i: integer;
begin
  // Clear FSelectedObject BEFORE freeing the objects. Without this,
  // FSelectedObject becomes a dangling pointer after the Free calls,
  // and any subsequent access (e.g. CommitStatsGrid firing during
  // PopulateTree's focus change) raises an access violation.
  FSelectedObject := nil;
  for i := 0 to FObjects.Count - 1 do
    TObject(FObjects[i]).Free;
  FObjects.Clear;
end;

procedure TObjectEditorForm.LoadObjectsFromFile(const FileName: string);
var
  Stream: TFileStream;
  Parser: TJSONParser;
  JSON: TJSONObject;
  Arr: TJSONArray;
  i, j, k: integer;
  CharObj, ActObj, AnimObj: TJSONObject;
  char: TObject;
  FileSize: int64;
begin
  ClearObjects;

  if not FileExists(FileName) then
  begin
    AddDefaultObject;
    Exit;
  end;

  FileSize := GetFileSize(FileName);
  if FileSize = 0 then
  begin
    AddDefaultObject;
    Exit;
  end;

  try
    Stream := TFileStream.Create(FileName, fmOpenRead);
    try
      Parser := TJSONParser.Create(Stream, []);
      try
        JSON := Parser.Parse as TJSONObject;
        try
          if JSON.Find('objects') = nil then
            raise Exception.Create('Missing "objects" array');

          Arr := JSON.Arrays['objects'];
          if Arr.Count = 0 then
          begin
            AddDefaultObject;
            Exit;
          end;

          for i := 0 to Arr.Count - 1 do
          begin
            CharObj := Arr.Objects[i];
            char := TObject.Create;
            try
              // All field assignments are inside this try block so that
              // if any one of them raises (missing key, type mismatch,
              // malformed nested array, ...) the partially-built `char`
              // is freed by the except handler before the exception
              // propagates to the outer handler. Without this, `char`
              // would leak because FObjects.Add(char) hasn't run yet —
              // FObjects owns it only AFTER the Add call.
              char.ID := CharObj.Get('id', '');
              char.Name := CharObj.Get('name', '');
              char.Category := CharObj.Get('category', '');
              char.Indexed := CharObj.Get('indexed', False);
              char.Tradeable := CharObj.Get('tradeable', False);
              char.Stacked := CharObj.Get('stacked', False);
              char.StackSize := CharObj.Get('stackSize', 0);

            // Icon
            if CharObj.Find('icon') <> nil then
            begin
              with CharObj.Objects['icon'] do
              begin
                char.Icon.SourceImage := Get('sourceImage', '');
                char.Icon.TilesetPath := Get('tilesetPath', '');
                char.Icon.X := Get('x', 0);
                char.Icon.Y := Get('y', 0);
                char.Icon.W := Get('w', 0);
                char.Icon.H := Get('h', 0);
                char.Icon.Name := Get('name', '');
              end;
            end;

            // Actions (each with ActIcon + Animations[])
            if CharObj.Find('actions') <> nil then
            begin
              with CharObj.Arrays['actions'] do
              begin
                SetLength(char.Actions, Count);
                for j := 0 to Count - 1 do
                begin
                  ActObj := Objects[j];
                  char.Actions[j].Name := ActObj.Get('name', '');

                  // Action ActIcon
                  if ActObj.Find('actIcon') <> nil then
                  begin
                    with ActObj.Objects['actIcon'] do
                    begin
                      char.Actions[j].ActIcon.SourceImage := Get('sourceImage', '');
                      char.Actions[j].ActIcon.TilesetPath := Get('tilesetPath', '');
                      char.Actions[j].ActIcon.X := Get('x', 0);
                      char.Actions[j].ActIcon.Y := Get('y', 0);
                      char.Actions[j].ActIcon.W := Get('w', 0);
                      char.Actions[j].ActIcon.H := Get('h', 0);
                      char.Actions[j].ActIcon.Name := Get('name', '');
                    end;
                  end;

                  // Animation references
                  if ActObj.Find('animations') <> nil then
                  begin
                    with ActObj.Arrays['animations'] do
                    begin
                      SetLength(char.Actions[j].Animations, Count);
                      for k := 0 to Count - 1 do
                      begin
                        AnimObj := Objects[k];
                        char.Actions[j].Animations[k].AnimFile := AnimObj.Get('animFile', '');
                        char.Actions[j].Animations[k].Row := AnimObj.Get('row', 0);
                      end;
                    end;
                  end;
                end;
              end;
            end;

            // Stats
            if CharObj.Find('stats') <> nil then
            begin
              with CharObj.Objects['stats'] do
              begin
                for j := 0 to Count - 1 do
                  char.Stats.Values[Names[j]] := (Items[j] as TJSONString).Value;
              end;
            end;

              // Ownership transfers to FObjects from this point on.
              FObjects.Add(char);
            except
              // Loading failed for this object — free the partially-built
              // instance and re-raise so the outer except handler can
              // clear whatever objects did load and fall back to default.
              char.Free;
              raise;
            end;
          end;

          if FObjects.Count = 0 then
            AddDefaultObject;

        finally
          JSON.Free;
        end;
      finally
        Parser.Free;
      end;
    finally
      Stream.Free;
    end;
  except
    on E: Exception do
    begin
      TDebugLogger.Error('Failed to load objects file: ' + E.Message);
      ClearObjects;
      AddDefaultObject;
    end;
  end;
end;

procedure TObjectEditorForm.SaveObjectsToFile(const FileName: string);
var
  JSON, CharObj, StatObj, IconObj, ActObj, ActIconObj, AnimObj: TJSONObject;
  Arr, ActArr, AnimArr: TJSONArray;
  i, j, k: integer;
  char: TObject;
begin
  JSON := TJSONObject.Create;
  Arr := TJSONArray.Create;
  for i := 0 to FObjects.Count - 1 do
  begin
    char := TObject(FObjects[i]);
    CharObj := TJSONObject.Create;
    CharObj.Add('id', char.ID);
    CharObj.Add('name', char.Name);
    CharObj.Add('category', char.Category);
    CharObj.Add('indexed', char.Indexed);
    CharObj.Add('tradeable', char.Tradeable);
    CharObj.Add('stacked', char.Stacked);
    CharObj.Add('stackSize', char.StackSize);

    // Icon
    IconObj := TJSONObject.Create;
    IconObj.Add('sourceImage', char.Icon.SourceImage);
    IconObj.Add('tilesetPath', char.Icon.TilesetPath);
    IconObj.Add('x', char.Icon.X);
    IconObj.Add('y', char.Icon.Y);
    IconObj.Add('w', char.Icon.W);
    IconObj.Add('h', char.Icon.H);
    IconObj.Add('name', char.Icon.Name);
    CharObj.Add('icon', IconObj);

    // Actions
    if Length(char.Actions) > 0 then
    begin
      ActArr := TJSONArray.Create;
      for j := 0 to High(char.Actions) do
      begin
        ActObj := TJSONObject.Create;
        ActObj.Add('name', char.Actions[j].Name);

        // Action ActIcon
        ActIconObj := TJSONObject.Create;
        ActIconObj.Add('sourceImage', char.Actions[j].ActIcon.SourceImage);
        ActIconObj.Add('tilesetPath', char.Actions[j].ActIcon.TilesetPath);
        ActIconObj.Add('x', char.Actions[j].ActIcon.X);
        ActIconObj.Add('y', char.Actions[j].ActIcon.Y);
        ActIconObj.Add('w', char.Actions[j].ActIcon.W);
        ActIconObj.Add('h', char.Actions[j].ActIcon.H);
        ActIconObj.Add('name', char.Actions[j].ActIcon.Name);
        ActObj.Add('actIcon', ActIconObj);

        // Animation references
        AnimArr := TJSONArray.Create;
        for k := 0 to High(char.Actions[j].Animations) do
        begin
          AnimObj := TJSONObject.Create;
          AnimObj.Add('animFile', char.Actions[j].Animations[k].AnimFile);
          AnimObj.Add('row', char.Actions[j].Animations[k].Row);
          AnimArr.Add(AnimObj);
        end;
        ActObj.Add('animations', AnimArr);

        ActArr.Add(ActObj);
      end;
      CharObj.Add('actions', ActArr);
    end;

    // Stats
    StatObj := TJSONObject.Create;
    for j := 0 to char.Stats.Count - 1 do
      StatObj.Add(char.Stats.Names[j], char.Stats.ValueFromIndex[j]);
    CharObj.Add('stats', StatObj);

    Arr.Add(CharObj);
  end;
  JSON.Add('objects', Arr);

  with TStringList.Create do
  try
    Text := JSON.FormatJSON;
    SaveToFile(FileName);
  finally
    Free;
  end;
  JSON.Free;
end;

procedure TObjectEditorForm.UpdateIndexFile;
var
  IdxFile: string;
  JSON: TJSONObject;
  Arr: TJSONArray;
  i: integer;
  char: TObject;
begin
  IdxFile := ChangeFileExt(FCurrentFile, '.chars.idx');
  JSON := TJSONObject.Create;
  Arr := TJSONArray.Create;
  for i := 0 to FObjects.Count - 1 do
  begin
    char := TObject(FObjects[i]);
    if char.Indexed then
      Arr.Add(char.ID);
  end;
  JSON.Add('indexed_objects', Arr);
  with TStringList.Create do
  try
    Text := JSON.FormatJSON;
    SaveToFile(IdxFile);
  finally
    Free;
  end;
  JSON.Free;
end;

function TObjectEditorForm.GenerateUniqueID(const Prefix: string): string;
var
  Guid: TGUID;
begin
  CreateGUID(Guid);
  Result := Prefix + '_' + Copy(GUIDToString(Guid), 2, 36); // remove braces
end;

procedure TObjectEditorForm.PopulateTree;
var
  i: integer;
  Node: PVirtualNode;
  Data: PObjectNode;
  char: TObject;
begin
  TDebugLogger.Debug('  PopulateTree START', {$I %CURRENTROUTINE%}, {$I %FILE%}, {$I %lineNum%});
  TreeObjects.BeginUpdate;
  TreeObjects.Clear;
  for i := 0 to FObjects.Count - 1 do
  begin
    char := TObject(FObjects[i]);
    Node := TreeObjects.AddChild(nil);
    Data := TreeObjects.GetNodeData(Node);
    Data^.anObject := char;
  end;
  TreeObjects.EndUpdate;
  if TreeObjects.RootNodeCount > 0 then
    TreeObjects.FocusedNode := TreeObjects.GetFirst;
  TDebugLogger.Debug('  PopulateTree END', {$I %CURRENTROUTINE%}, {$I %FILE%}, {$I %lineNum%});
end;

procedure TObjectEditorForm.UpdateDetailPanel(anObject: TObject);
begin
  TDebugLogger.Debug('  UpdateDetailPanel START', {$I %CURRENTROUTINE%}, {$I %FILE%}, {$I %lineNum%});
  if anObject = nil then
  begin
    ClearDetailPanel;
    Exit;
  end;
  FSelectedObject := anObject;
  LoadObjectToUI(anObject);
  TDebugLogger.Debug('  UpdateDetailPanel END', {$I %CURRENTROUTINE%}, {$I %FILE%}, {$I %lineNum%});
end;

procedure TObjectEditorForm.ClearDetailPanel;
begin
  edName.Text := '';
  cbCategory.Text := '';
  cbTradeable.Checked := False;
  cbStack.Checked := False;
  cbIndexed.Checked := False;
  seInventorySize.Value := 0;
  lbSpritesheets.Clear;
  sgStats.RowCount := 2;
  ClearIconImage;
  FSelectedObject := nil;
end;

procedure TObjectEditorForm.LoadObjectToUI(anObject: TObject);
var
  i: integer;
begin
  if anObject = nil then Exit;
  if edName = nil then Exit;
  // Guard against cbCategory.OnChange firing while we set the category
  // text programmatically. Without this, loading an object would
  // trigger the "Apply category defaults?" dialog for every object.
  FUpdating := True;
  try
    edName.Text := anObject.Name;
    cbCategory.Text := anObject.Category;
    cbIndexed.Checked := anObject.Indexed;
    cbTradeable.Checked := anObject.Tradeable;
    cbStack.Checked := anObject.Stacked;
    seInventorySize.Value := anObject.StackSize;
  finally
    FUpdating := False;
  end;
  // Action list (lbSpritesheets — control name kept for now, will rename later)
  lbSpritesheets.Clear;
  for i := 0 to High(anObject.Actions) do
    lbSpritesheets.Items.Add(anObject.Actions[i].Name);
  // Stats
  RefreshStatsGrid;
  // Icon preview (picked tile rendered into imgIcon)
  RenderIcon(anObject);
end;

procedure TObjectEditorForm.SaveUIToObject(anObject: TObject);
begin
  if anObject = nil then Exit;
  anObject.Name := edName.Text;
  anObject.Category := cbCategory.Text;
  anObject.Indexed := cbIndexed.Checked;
  anObject.Tradeable := cbTradeable.Checked;
  anObject.Stacked := cbStack.Checked;
  anObject.StackSize := seInventorySize.Value;
  // Stats — commit the grid buffer to the object
  CommitStatsGrid;
  // Actions are not edited directly in the main UI — they're managed via
  // the animator dialog (EditAction). We do not overwrite them here.
end;

procedure TObjectEditorForm.AddDefaultObject;
var
  char: TObject;
begin
  char := TObject.Create;
  char.ID := GenerateUniqueID('OBJ');
  char.Name := 'New Object';
  char.Indexed := False;
  ApplyCategoryDefaults(char, 'Static');
  FObjects.Add(char);
end;

// Apply category-specific defaults to an object. Called when creating a
// new object (btnNewClick) and when the user changes the category in the
// detail panel (cbCategoryChange — to be wired). Each category has
// sensible defaults for tradeable/stacked/stackSize and a relevant set
// of starting stats. The user can always edit these afterwards.
procedure TObjectEditorForm.ApplyCategoryDefaults(anObject: TObject;
  const Category: string);
begin
  anObject.Category := Category;
  anObject.Tradeable := True;
  anObject.Stacked := False;
  anObject.StackSize := 1;
  anObject.Stats.Clear;

  if Category = 'Consumable' then
  begin
    // Consumables: stackable, default stack 10, healing-focused stats
    anObject.Stacked := True;
    anObject.StackSize := 10;
    anObject.Stats.Add('HP=50');
    anObject.Stats.Add('Effect=Heal');
    anObject.Stats.Add('Duration=0');
  end
  else if Category = 'Weapon' then
  begin
    anObject.Stats.Add('Damage=10');
    anObject.Stats.Add('Durability=100');
    anObject.Stats.Add('Range=1');
  end
  else if Category = 'Clothing' then
  begin
    anObject.Stats.Add('Defense=5');
    anObject.Stats.Add('Durability=100');
    anObject.Stats.Add('Slot=Body');
  end
  else if Category = 'Tool' then
  begin
    anObject.Stats.Add('Durability=100');
    anObject.Stats.Add('Uses=10');
  end
  else if Category = 'Quest Item' then
  begin
    // Quest items: not tradeable, not stackable
    anObject.Tradeable := False;
    anObject.Stats.Add('QuestID=0');
  end
  else
  begin
    // Static (default)
    anObject.Stats.Add('HP=100');
    anObject.Stats.Add('MP=50');
  end;
end;

procedure TObjectEditorForm.EditAction(anObject: TObject; Index: integer);

  // Local helper: properly disposes a PAnimationDef AND all its heap-allocated
  // layers (recursively, including children). Without this, Dispose(PAnimationDef)
  // would leak every PLayerDef inside Frames[].Layers[].
  procedure DisposeAnimWithLayers(A: PAnimationDef);
    procedure DisposeLayerRecursive(L: PLayerDef);
    var
      c: integer;
    begin
      if L = nil then Exit;
      for c := 0 to High(L^.Children) do
        DisposeLayerRecursive(L^.Children[c]);
      SetLength(L^.Children, 0);
      Dispose(L);
    end;
  var
    f, j: integer;
  begin
    if A = nil then Exit;
    for f := 0 to High(A^.Frames) do
      for j := 0 to High(A^.Frames[f].Layers) do
        DisposeLayerRecursive(A^.Frames[f].Layers[j]);
    Dispose(A);
    A := nil;
  end;

var
  dlg: TCutoutAnimatorForm;
  AnimList: TList;
  i: integer;
  anim: PAnimationDef;
  Act: TAction;
  AnimPath, BaseDir: string;
  ActIdx: integer;
begin
  if anObject = nil then Exit;

  dlg := TCutoutAnimatorForm.Create(Self);
  AnimList := TList.Create;
  try
    BaseDir := ExtractFilePath(FCurrentFile);
    dlg.AnimBasePath := BaseDir;

    // If editing an existing action, preload its animations + ActIcon.
    // If Index < 0 (new action), the dialog starts blank.
    if (Index >= 0) and (Index < Length(anObject.Actions)) then
    begin
      Act := anObject.Actions[Index];

      // Set the action name in the dialog's edAction field
      dlg.edAction.Text := Act.Name;

      // STEP 1: Load animation .anim files from disk FIRST, before calling
      // SetTilesetTile. SetTilesetTile creates a default animation when
      // FAnimations.Count = 0 — by loading animations first, no default
      // is created and the loaded data is what the user sees.
      for i := 0 to High(Act.Animations) do
      begin
        if Act.Animations[i].AnimFile = '' then Continue;
        AnimPath := Act.Animations[i].AnimFile;
        if not FileExists(AnimPath) then
          AnimPath := BaseDir + Act.Animations[i].AnimFile;
        if not FileExists(AnimPath) then
          AnimPath := BaseDir + ExtractFileName(Act.Animations[i].AnimFile);
        if dlg.LoadAnimationFromFile(AnimPath, anim) then
        begin
          anim^.RowIndex := Act.Animations[i].Row;
          anim^.AnimFilePath := AnimPath;
          AnimList.Add(anim);
        end;
      end;

      if AnimList.Count > 0 then
      begin
        dlg.LoadAnimations(AnimList);
        for i := 0 to AnimList.Count - 1 do
          DisposeAnimWithLayers(PAnimationDef(AnimList[i]));
        AnimList.Clear;
      end;

      // STEP 2: Load the ActIcon into the dialog via SetTilesetTile.
      // Since FAnimations is already populated, SetTilesetTile will NOT
      // create a default animation — it just sets the tile info + icon preview.
      if (Act.ActIcon.SourceImage <> '') and FileExists(Act.ActIcon.SourceImage) then
        dlg.SetTilesetTile(Act.ActIcon.TilesetPath, Act.ActIcon.SourceImage,
          Act.ActIcon.X, Act.ActIcon.Y, Act.ActIcon.W, Act.ActIcon.H,
          Act.ActIcon.Name);
    end;

    if dlg.ShowModal = mrOk then
    begin
      // The dialog's btnOKClick already saved every animation to its
      // .anim file (debug-logged). Now we read back:
      //   1. The action name (edAction.Text)
      //   2. The ActIcon (GetTilesetPath, GetSourceImage, GetTileX/Y, etc.)
      //   3. The animation references (AnimFilePath + RowIndex from GetAnimations)

      // Determine the action slot: use Index if valid, otherwise append.
      if (Index >= 0) and (Index < Length(anObject.Actions)) then
        ActIdx := Index
      else
      begin
        ActIdx := Length(anObject.Actions);
        SetLength(anObject.Actions, ActIdx + 1);
      end;

      anObject.Actions[ActIdx].Name := dlg.edAction.Text;

      // Read back ActIcon from the dialog
      anObject.Actions[ActIdx].ActIcon.TilesetPath := dlg.GetTilesetPath;
      anObject.Actions[ActIdx].ActIcon.SourceImage := dlg.GetSourceImage;
      anObject.Actions[ActIdx].ActIcon.X := dlg.GetTileX;
      anObject.Actions[ActIdx].ActIcon.Y := dlg.GetTileY;
      anObject.Actions[ActIdx].ActIcon.W := dlg.seTileW.Value;
      anObject.Actions[ActIdx].ActIcon.H := dlg.seTileH.Value;
      anObject.Actions[ActIdx].ActIcon.Name := dlg.GetTileName;

      // Read back animation references
      dlg.GetAnimations(AnimList);
      try
        SetLength(anObject.Actions[ActIdx].Animations, AnimList.Count);
        for i := 0 to AnimList.Count - 1 do
        begin
          anim := PAnimationDef(AnimList[i]);
          anObject.Actions[ActIdx].Animations[i].AnimFile := anim^.AnimFilePath;
          anObject.Actions[ActIdx].Animations[i].Row := anim^.RowIndex;
        end;
      finally
        for i := 0 to AnimList.Count - 1 do
          DisposeAnimWithLayers(PAnimationDef(AnimList[i]));
        AnimList.Clear;
      end;

      RefreshActionList;
    end;
  finally
    for i := 0 to AnimList.Count - 1 do
      DisposeAnimWithLayers(PAnimationDef(AnimList[i]));
    AnimList.Free;
    dlg.Free;
  end;
end;

procedure TObjectEditorForm.RefreshActionList;
var
  i: integer;
begin
  if FSelectedObject <> nil then
  begin
    lbSpritesheets.Clear;
    for i := 0 to High(FSelectedObject.Actions) do
      lbSpritesheets.Items.Add(FSelectedObject.Actions[i].Name);
  end;
end;

procedure TObjectEditorForm.RefreshStatsGrid;
var
  i: integer;
begin
  if FSelectedObject = nil then Exit;
  FUpdating := True;
  try
    // Show existing stats + 1 empty row at the bottom for adding new
    // stats. The grid is a BUFFER — it does NOT sync to FSelectedObject
    // on every keystroke (that caused chaos: every char added a row,
    // partial stat names got saved, etc.). Instead, CommitStatsGrid
    // reads the grid into FSelectedObject.Stats at well-defined points
    // (switching objects, saving, applying category defaults).
    sgStats.RowCount := Max(2, FSelectedObject.Stats.Count + 2);
    for i := 0 to FSelectedObject.Stats.Count - 1 do
    begin
      sgStats.Cells[0, i + 1] := FSelectedObject.Stats.Names[i];
      sgStats.Cells[1, i + 1] := FSelectedObject.Stats.ValueFromIndex[i];
    end;
    // Clear the empty bottom row
    sgStats.Cells[0, FSelectedObject.Stats.Count + 1] := '';
    sgStats.Cells[1, FSelectedObject.Stats.Count + 1] := '';
  finally
    FUpdating := False;
  end;
end;

procedure TObjectEditorForm.CommitStatsGrid;
var
  i: integer;
  statName, statValue: string;
begin
  // Read the grid into FSelectedObject.Stats. Called before switching
  // objects, saving, or applying category defaults — NOT on every
  // keystroke. This is the "commit" half of the buffer pattern:
  //   RefreshStatsGrid = Stats → Grid (load)
  //   CommitStatsGrid  = Grid → Stats (save)
  //
  // Rows with empty stat names are skipped (effectively deleted).
  if FSelectedObject = nil then Exit;
  FSelectedObject.Stats.Clear;
  for i := 1 to sgStats.RowCount - 1 do
  begin
    statName := Trim(sgStats.Cells[0, i]);
    statValue := Trim(sgStats.Cells[1, i]);
    if statName <> '' then
      FSelectedObject.Stats.Values[statName] := statValue;
  end;
end;

// Tree events
procedure TObjectEditorForm.TreeObjectsGetText(Sender: TBaseVirtualTree; Node: PVirtualNode; Column: TColumnIndex; TextType: TVSTTextType; var CellText: string);
var
  Data: PObjectNode;
  char: TObject;
  Prefix: string;
begin
  Data := Sender.GetNodeData(Node);
  if Data = nil then Exit;
  char := Data^.anObject;
  case Column of
    0: begin
      if Pos('OBJ_', char.ID) = 1 then Prefix := 'OBJ'
      else if Pos('WEA_', char.ID) = 1 then Prefix := 'WEA'
      else
        Prefix := 'Unknown';
      CellText := Prefix;
    end;
    1: CellText := char.Name;
    2: CellText := char.ID;
  end;
end;

procedure TObjectEditorForm.TreeObjectsGetNodeDataSize(Sender: TBaseVirtualTree; var NodeDataSize: integer);
begin
  NodeDataSize := SizeOf(TObjectNode);
end;

procedure TObjectEditorForm.TreeObjectsFocusChanged(Sender: TBaseVirtualTree; Node: PVirtualNode; Column: TColumnIndex);
var
  Data: PObjectNode;
begin
  // Commit the stats grid BEFORE switching to a new object — but only
  // if FSelectedObject is still valid. During ClearObjects (called by
  // LoadFile/reload), FSelectedObject is freed before the tree is
  // rebuilt, so CommitStatsGrid would write to freed memory → AV.
  // ClearObjects sets FSelectedObject := nil, which guards us here.
  if FSelectedObject <> nil then
    CommitStatsGrid;
  if Node = nil then
    UpdateDetailPanel(nil)
  else
  begin
    Data := Sender.GetNodeData(Node);
    if (Data <> nil) and (Data^.anObject <> nil) then
      UpdateDetailPanel(Data^.anObject)
    else
      UpdateDetailPanel(nil);
  end;
end;

// Buttons actions
procedure TObjectEditorForm.btnNewClick(Sender: TObject);
var
  dlg: TForm;
  lblTypePrompt, lblNamePrompt: TLabel;
  cbType: TComboBox;
  edNewName: TEdit;
  btnOK, btnCancel: TButton;
  Prefix, SelectedType: string;
  NewChar: TObject;
begin
  dlg := TForm.Create(Self);
  try
    dlg.Caption := 'New Object';
    dlg.Width := 320;
    dlg.Height := 180;
    dlg.Position := poMainFormCenter;

    lblTypePrompt := TLabel.Create(dlg);
    lblTypePrompt.Parent := dlg;
    lblTypePrompt.Caption := 'Type:';
    lblTypePrompt.SetBounds(20, 15, 50, 20);

    cbType := TComboBox.Create(dlg);
    cbType.Parent := dlg;
    cbType.Style := csDropDownList;
    cbType.SetBounds(80, 12, 200, 24);
    cbType.Items.Add('Weapon');
    cbType.Items.Add('Clothing');
    cbType.Items.Add('Tool');
    cbType.Items.Add('Static');
    cbType.Items.Add('Consumable');
    cbType.Items.Add('Quest Item');
    cbType.ItemIndex := 0;

    lblNamePrompt := TLabel.Create(dlg);
    lblNamePrompt.Parent := dlg;
    lblNamePrompt.Caption := 'Name:';
    lblNamePrompt.SetBounds(20, 50, 50, 20);

    edNewName := TEdit.Create(dlg);
    edNewName.Parent := dlg;
    edNewName.SetBounds(80, 47, 200, 24);
    edNewName.Text := 'New Object';

    btnOK := TButton.Create(dlg);
    btnOK.Parent := dlg;
    btnOK.Caption := 'OK';
    btnOK.SetBounds(70, 90, 80, 30);
    btnOK.ModalResult := mrOk;

    btnCancel := TButton.Create(dlg);
    btnCancel.Parent := dlg;
    btnCancel.Caption := 'Cancel';
    btnCancel.SetBounds(170, 90, 80, 30);
    btnCancel.ModalResult := mrCancel;

    if dlg.ShowModal = mrOk then
    begin
      SelectedType := cbType.Items[cbType.ItemIndex];

      // ID prefix based on type
      if SelectedType = 'Weapon' then Prefix := 'WEA'
      else if SelectedType = 'Consumable' then Prefix := 'CON'
      else if SelectedType = 'Quest Item' then Prefix := 'QST'
      else
        Prefix := 'OBJ';

      NewChar := TObject.Create;
      NewChar.ID := GenerateUniqueID(Prefix);
      NewChar.Name := edNewName.Text;
      NewChar.Indexed := False;
      // Apply category-specific defaults (tradeable, stacked, stackSize,
      // starting stats). This replaces the old hardcoded HP=100/MP=50.
      ApplyCategoryDefaults(NewChar, SelectedType);
      // No actions by default — user adds them via the animator dialog
      FObjects.Add(NewChar);
      PopulateTree;
    end;
  finally
    dlg.Free;
  end;
end;

procedure TObjectEditorForm.btnDeleteClick(Sender: TObject);
var
  Node: PVirtualNode;
  Data: PObjectNode;
  idx: integer;
begin
  Node := TreeObjects.GetFirstSelected;
  if Node = nil then Exit;
  Data := TreeObjects.GetNodeData(Node);
  if Data = nil then Exit;
  if MessageDlg('Delete Object', 'Are you sure?', mtConfirmation, [mbYes, mbNo], 0) = mrYes then
  begin
    idx := FObjects.IndexOf(Data^.anObject);
    if idx >= 0 then FObjects.Delete(idx);
    Data^.anObject.Free;
    TreeObjects.DeleteNode(Node);
    if TreeObjects.RootNodeCount = 0 then
      UpdateDetailPanel(nil);
  end;
end;

procedure TObjectEditorForm.btnSaveClick(Sender: TObject);
begin
  SaveUIToObject(FSelectedObject);
  SaveObjectsToFile(FCurrentFile);
  UpdateIndexFile;
  SaveGlobalIndex;   // instead of UpdateIndexFile
  ShowMessage('Saved to ' + FCurrentFile);
end;

procedure TObjectEditorForm.btnReloadClick(Sender: TObject);
begin
  if FCurrentFile <> '' then
    LoadFile(FCurrentFile);
end;

// Action buttons (control names kept as btnAddSpritesheet etc. for now)
procedure TObjectEditorForm.btnAddSpritesheetClick(Sender: TObject);
begin
  if FSelectedObject = nil then Exit;
  // Index=-1 means "new action" — EditAction creates the slot on mrOk
  EditAction(FSelectedObject, -1);
  RefreshActionList;
end;

procedure TObjectEditorForm.btnEditSpritesheetClick(Sender: TObject);
begin
  if (FSelectedObject = nil) or (lbSpritesheets.ItemIndex < 0) then Exit;
  EditAction(FSelectedObject, lbSpritesheets.ItemIndex);
end;

procedure TObjectEditorForm.btnDeleteSpritesheetClick(Sender: TObject);
var
  idx, i: integer;
begin
  if (FSelectedObject = nil) or (lbSpritesheets.ItemIndex < 0) then Exit;
  idx := lbSpritesheets.ItemIndex;
  for i := idx to High(FSelectedObject.Actions) - 1 do
    FSelectedObject.Actions[i] := FSelectedObject.Actions[i + 1];
  SetLength(FSelectedObject.Actions, Length(FSelectedObject.Actions) - 1);
  RefreshActionList;
end;

procedure TObjectEditorForm.sgStatsSetEditText(Sender: TObject; ACol, ARow: integer; const Value: string);
var
  lastRow: integer;
begin
  // The grid is a BUFFER — no per-keystroke sync to FSelectedObject.Stats.
  // But we DO need to add a new empty row when the user starts typing in
  // the last row's stat-name column, so there's always room for one more.
  //
  // OnSetEditText fires per keystroke, but we only add a row when:
  //   - The edit is in column 0 (stat name)
  //   - The edit is in the LAST row
  //   - The Value is non-empty (first character typed)
  //   - We haven't already added a row for this edit session (FUpdating
  //     guards against re-entrancy)
  if (FSelectedObject = nil) or FUpdating then Exit;
  if ACol <> 0 then Exit;  // only stat-name column triggers row add
  if Trim(Value) = '' then Exit;  // empty — don't add a row yet
  lastRow := sgStats.RowCount - 1;
  if ARow <> lastRow then Exit;  // not the last row — no need to add
  // User typed in the last row's stat name — add a new empty row below.
  // FUpdating prevents OnSelectCell / re-entrant OnSetEditText from
  // firing while we modify the grid.
  FUpdating := True;
  try
    sgStats.RowCount := sgStats.RowCount + 1;
    sgStats.Cells[0, sgStats.RowCount - 1] := '';
    sgStats.Cells[1, sgStats.RowCount - 1] := '';
  finally
    FUpdating := False;
  end;
end;

procedure TObjectEditorForm.sgStatsSelectCell(Sender: TObject; ACol, ARow: integer; var CanSelect: boolean);
begin
  // Intentionally empty. Row-adding is handled in sgStatsSetEditText
  // (fires when the user types the first character in the last row's
  // stat-name column). OnSelectCell was unreliable for this because it
  // fires before the editor commits, so the last row's content wasn't
  // yet visible to our check.
end;

function TObjectEditorForm.GetFileSize(const FileName: string): int64;
var
  Info: TSearchRec;
begin
  if FindFirst(FileName, faAnyFile, Info) = 0 then
    Result := Info.Size
  else
    Result := 0;
  FindClose(Info);
end;

// Public methods
procedure TObjectEditorForm.LoadFile(const FileName: string);
begin
  TDebugLogger.DebugFmt('LoadFile: %s', [FileName]);
  FCurrentFile := FileName;
  ClearObjects;
  LoadObjectsFromFile(FileName);
  PopulateTree;
  Caption := 'Object Editor - ' + ExtractFileName(FileName);
end;

procedure TObjectEditorForm.SaveFile;
begin
  if FCurrentFile = '' then Exit;
  SaveUIToObject(FSelectedObject);
  SaveObjectsToFile(FCurrentFile);
  UpdateIndexFile;
  SaveGlobalIndex;   // instead of UpdateIndexFile
end;

procedure TObjectEditorForm.SaveGlobalIndex;
var
  IndexFileName: string;
  JSONArray, NewArray: TJSONArray;
  JSON, Entry, IconEntry: TJSONObject;
  i: integer;
  char: TObject;
  SL: TStringList;
  SourceFileName: string;
begin
  // Use a fixed name for the global index file (located in the same folder as the .chars file)
  IndexFileName := ExtractFilePath(FCurrentFile) + 'Objects.ndx';
  SourceFileName := ExtractFileName(FCurrentFile);

  // Load existing index if it exists
  NewArray := TJSONArray.Create;
  try
    if FileExists(IndexFileName) then
    begin
      SL := TStringList.Create;
      try
        SL.LoadFromFile(IndexFileName);
        JSON := GetJSON(SL.Text) as TJSONObject;
        try
          if JSON.Find('objects') <> nil then
            JSONArray := JSON.Arrays['objects']
          else
            JSONArray := TJSONArray.Create;
          // Copy all entries that do NOT belong to the current source file
          for i := 0 to JSONArray.Count - 1 do
          begin
            Entry := JSONArray.Objects[i];
            if Entry.Get('sourceFile', '') <> SourceFileName then
              NewArray.Add(Entry.Clone);
          end;
        finally
          JSON.Free;
        end;
      finally
        SL.Free;
      end;
    end;

    // Add entries for all objects in the current file
    for i := 0 to FObjects.Count - 1 do
    begin
      char := TObject(FObjects[i]);
      Entry := TJSONObject.Create;
      Entry.Add('id', char.ID);
      Entry.Add('name', char.Name);
      Entry.Add('category', char.Category);
      Entry.Add('sourceFile', SourceFileName);

      // Embed the icon reference so external tools (asset browsers, world
      // editors, ...) can render the object icon without having to load the
      // full .objects file. When no icon is set, an empty block is emitted
      // to keep the schema stable.
      IconEntry := TJSONObject.Create;
      IconEntry.Add('sourceImage', char.Icon.SourceImage);
      IconEntry.Add('tilesetPath', char.Icon.TilesetPath);
      IconEntry.Add('x', char.Icon.X);
      IconEntry.Add('y', char.Icon.Y);
      IconEntry.Add('w', char.Icon.W);
      IconEntry.Add('h', char.Icon.H);
      IconEntry.Add('name', char.Icon.Name);
      Entry.Add('icon', IconEntry);

      NewArray.Add(Entry);
    end;

    // Write the updated index
    JSON := TJSONObject.Create;
    JSON.Add('objects', NewArray);
    SL := TStringList.Create;
    try
      SL.Text := JSON.FormatJSON;
      SL.SaveToFile(IndexFileName);
    finally
      SL.Free;
      JSON.Free;
    end;
  except
    on E: Exception do
      TDebugLogger.ErrorFmt('Failed to save global index: %s', [E.Message]);
  end;
end;

end.


