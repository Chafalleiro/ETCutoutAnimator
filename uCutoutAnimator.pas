unit uCutoutAnimator;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, ExtCtrls, StdCtrls,
  Spin, ComCtrls, Grids, BGRABitmap, BGRABitmapTypes,
  VirtualTrees, uDebugLog, uSpritePicker, Types,
  {$ifdef windows}
    ActiveX,
  {$else}
    FakeActiveX,
  {$endif}
  fpjson;

type
  TBackgroundStyle = (bgSolid, bgChecker);
  TTransformType = (ttNone, ttRotate90, ttRotate180, ttRotate270,
                    ttFlipX, ttFlipY, ttFlipXY);

  TFrameTransform = record
    OffsetX: integer;
    OffsetY: integer;
    Angle: double;
  end;
  PFrameTransform = ^TFrameTransform;

  // Forward-declare the layer pointer so we can build a dynamic array of
  // layer pointers before TLayerDef is fully defined. Pointer types can
  // be forward-declared because their size is always SizeOf(Pointer).
  PLayerDef = ^TLayerDef;

  // Dynamic array of layer pointers. Declared BEFORE TLayerDef so the
  // Children field can use it. Using PLayerDef (not TLayerDef) as the
  // element type avoids the circular dependency. Layers are heap-allocated
  // so pointers stay stable when parent arrays are SetLength'd.
  TLayerDynArray = array of PLayerDef;

  // A single composited layer. Layers can be nested via Children to form a
  // skeleton-like hierarchy (no IK). Each layer carries its own transform
  // (OffsetX/Y, Angle, ZIndex) and an optional image (tile reference).
  // PivotX/PivotY are the rotation pivot — PLACEHOLDER, not yet in the UI.
  TLayerDef = record
    Name: string;
    Visible: boolean;
    // Per-layer transform
    OffsetX: integer;
    OffsetY: integer;
    Angle: double;
    ZIndex: integer;
    // Rotation pivot (placeholder — not yet in UI)
    PivotX: integer;
    PivotY: integer;
    // Depth relative to parent. When True, this layer is drawn BEFORE
    // its parent (appears behind it). Default False = drawn after parent
    // (on top, current behaviour). This decouples draw order from the
    // transform hierarchy: a child limb can be visually behind its
    // parent (e.g. back arm behind torso in side view) while still
    // inheriting the parent's transform (offset/rotation). Only affects
    // the parent-child relationship; sibling order is still the VST
    // array order.
    DrawBehindParent: boolean;
    // Flip flags — mirror the tile at its center axis. Unlike rotation,
    // flip doesn't respect the pivot (it's always at the tile center).
    // Both can be True simultaneously (= 180° rotation, but using flip
    // flags keeps the data intent clear: "mirrored" vs "rotated").
    FlipH: boolean;
    FlipV: boolean;
    // Image (tile reference). Empty SourceImage = grouping node.
    SourceImage: string;
    TilesetPath: string;
    TileX: integer;
    TileY: integer;
    TileW: integer;
    TileH: integer;
    TileName: string;
    Children: TLayerDynArray;  // nested children (array of PLayerDef)
  end;

  // A frame is just a container for a set of root layers. Frames are
  // identified by their ordinal (0..FrameCount-1). Each frame can have a
  // completely different layer tree — that's how cutout animation works
  // (you tweak the skeleton pose per frame).
  TFrameDef = record
    Ordinal: integer;
    Layers: TLayerDynArray;   // root-level layers; each can have Children
  end;
  PFrameDef = ^TFrameDef;

  TAnimationDef = record
    Name: string;
    RowIndex: integer;
    AnimFilePath: string;       // path to the .anim file (managed by caller)
    FrameCount: integer;
    SpeedMs: integer;
    Transform: TTransformType;
    Preset: string;
    FrameW: integer;            // per-animation frame width (pixels)
    FrameH: integer;            // per-animation frame height (pixels)
    Frames: array of TFrameDef;  // length = FrameCount
  end;
  PAnimationDef = ^TAnimationDef;

  { TCutoutAnimatorForm }

  TCutoutAnimatorForm = class(TForm)
    btnEditLayer: TButton;
    btnNewLayer: TButton;
    btnDelLayer: TButton;
    btnExportSprSet: TButton;
    btnExportMskSet: TButton;
    btnPreviewSprite: TButton;
    btnSaveAnim: TButton;
    btnLoadAnim: TButton;
    btnAddFrame: TButton;
    btnDelFrame: TButton;
    btnDupFrame: TButton;
    btnFlipH: TButton;
    btnFlipV: TButton;
    btnImgEdit: TButton;
    // Existing controls (keep everything)
    gbData: TGroupBox;
    gbPreview: TGroupBox;
    grFrameTransform: TGroupBox;
    iconImage: TImage;
    Label1: TLabel;
    Label14: TLabel;
    Label2: TLabel;
    Label3: TLabel;
    Label4: TLabel;
    Label7: TLabel;
    Label8: TLabel;
    Label9: TLabel;
    lblXorig: TLabel;
    lblYorig: TLabel;
    lblZIndex: TLabel;
    Label5: TLabel;
    Label6: TLabel;
    lblAction: TLabel;
    edAction: TEdit;
    edImage: TEdit;

    lblAnimName: TLabel;
    PageControl1: TPageControl;
    Panel1: TPanel;
    Panel2: TPanel;
    pnlAniList: TPanel;
    seAnimH: TSpinEdit;
    seAnimW: TSpinEdit;
    seTileW: TSpinEdit;
    seTileH: TSpinEdit;
    btnOK: TButton;
    btnCancel: TButton;
    btnBrowse: TButton;
    pbPreview: TPaintBox;
    sgFrameTransforms: TStringGrid;
    seZIndex: TSpinEdit;
    seXorig: TSpinEdit;
    seYorig: TSpinEdit;
    Splitter1: TSplitter;
    TabSheet1: TTabSheet;
    TabSheet2: TTabSheet;
    tbZoom: TTrackBar;
    lblZoom: TLabel;
    cbBackground: TComboBox;
    btnRefresh: TButton;
    gbAnimProps: TGroupBox;
    lbAnimations: TListBox;
    btnAddAnim: TButton;
    btnDeleteAnim: TButton;
    edAnimName: TEdit;
    lblRowIdx: TLabel;
    seAnimRow: TSpinEdit;
    lblFrameCount: TLabel;
    seAnimFrameCount: TSpinEdit;
    lblAnimSpeed: TLabel;
    seAnimSpeed: TSpinEdit;
    btnPlay: TButton;
    tbSpeed: TTrackBar;
    lblSpeed: TLabel;
    tbFrame: TTrackBar;
    seFrame: TSpinEdit;
    lblTotalFrames: TLabel;
    Timer: TTimer;
    VirtualStringTree1: TVirtualStringTree;
    Zoom: TLabel;

    // New controls
    lblOffsetX: TLabel;
    seOffsetX: TSpinEdit;
    lblOffsetY: TLabel;
    seOffsetY: TSpinEdit;
    lblAngle: TLabel;
    seAngle: TFloatSpinEdit;
    btnApplyFrame: TButton;

    // Pivot controls (rotation pivot — per-layer, stored in .anim as
    // pivotX/pivotY). Declared here so the .frm's sePivotX / sePivotY
    // controls link up to the form class.
    sePivotX: TSpinEdit;
    sePivotY: TSpinEdit;
    cbPVis: TCheckBox;   // toggles pivot marker visibility in preview
    cbBehindParent: TCheckBox;  // toggles DrawBehindParent on selected layer

    // Icon info
    lblIconName: TLabel;

    procedure btnAddFrameClick(Sender: TObject);
    procedure btnDelFrameClick(Sender: TObject);
    procedure btnDupFrameClick(Sender: TObject);
    procedure btnFlipHClick(Sender: TObject);
    procedure btnFlipVClick(Sender: TObject);
    procedure btnDelLayerClick(Sender: TObject);
    procedure btnEditLayerClick(Sender: TObject);
    procedure btnImgEditClick(Sender: TObject);
    procedure btnLoadAnimClick(Sender: TObject);
    procedure btnNewLayerClick(Sender: TObject);
    procedure btnSaveAnimClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);

    procedure btnBrowseClick(Sender: TObject);
    procedure btnRefreshClick(Sender: TObject);
    procedure btnPlayClick(Sender: TObject);
    procedure lbAnimationsClick(Sender: TObject);
    procedure btnAddAnimClick(Sender: TObject);
    procedure btnDeleteAnimClick(Sender: TObject);

    procedure pbPreviewPaint(Sender: TObject);
    procedure tbZoomChange(Sender: TObject);
    procedure cbBackgroundChange(Sender: TObject);

    procedure AnimPropChange(Sender: TObject);
    procedure tbFrameChange(Sender: TObject);
    procedure seFrameChange(Sender: TObject);

    procedure tbSpeedChange(Sender: TObject);
    procedure seOffsetXChange(Sender: TObject);
    procedure seOffsetYChange(Sender: TObject);
    procedure seAngleChange(Sender: TObject);
    procedure sePivotXChange(Sender: TObject);
    procedure sePivotYChange(Sender: TObject);
    procedure btnApplyFrameClick(Sender: TObject);
    procedure sgFrameTransformsClick(Sender: TObject);
    procedure cbPVisClick(Sender: TObject);
    procedure cbBehindParentClick(Sender: TObject);

    procedure TimerTimer(Sender: TObject);

    // Drag-and-drop reordering of lbAnimations
    procedure lbAnimationsDragOver(Sender, Source: TObject; X, Y: Integer;
      State: TDragState; var Accept: Boolean);
    procedure lbAnimationsDragDrop(Sender, Source: TObject; X, Y: Integer);

    // VirtualStringTree1 (layers list) events
    procedure VirtualStringTree1GetText(Sender: TBaseVirtualTree;
      Node: PVirtualNode; Column: TColumnIndex; TextType: TVSTTextType;
      var CellText: String);
    procedure VirtualStringTree1GetNodeDataSize(Sender: TBaseVirtualTree;
      var NodeDataSize: Integer);
    procedure VirtualStringTree1FocusChanged(Sender: TBaseVirtualTree;
      Node: PVirtualNode; Column: TColumnIndex);
    procedure VirtualStringTree1NodeClick(Sender: TBaseVirtualTree;
      const HitInfo: THitInfo);
    procedure VirtualStringTree1FreeNode(Sender: TBaseVirtualTree;
      Node: PVirtualNode);
    procedure VirtualStringTree1Checking(Sender: TBaseVirtualTree;
      Node: PVirtualNode; var NewState: TCheckState; var Allowed: boolean);

    // VST native drag-and-drop for layer reordering + hierarchy changes
    procedure VirtualStringTree1DragAllowed(Sender: TBaseVirtualTree;
      Node: PVirtualNode; Column: TColumnIndex; var Allowed: boolean);
    procedure VirtualStringTree1DragOver(Sender: TBaseVirtualTree;
      Source: TObject; Shift: TShiftState; State: TDragState;
      const Pt: TPoint; Mode: TDropMode; var Effect: LongWord;
      var Accept: boolean);
    procedure VirtualStringTree1DragDrop(Sender: TBaseVirtualTree;
      Source: TObject; DataObject: IDataObject; Formats: TFormatArray;
      Shift: TShiftState; const Pt: TPoint; var Effect: LongWord;
      Mode: TDropMode);

    // Public methods
    procedure UpdatePreview;
    procedure LoadAnimations(AnimList: TList);
    procedure GetAnimations(AnimList: TList);
    procedure SetTilesetTile(const ATilesetPath, AImagePath: string;
      AX, AY, AW, AH: integer; const AName: string);
    function  GetTilesetPath: string;
    function  GetSourceImage: string;
    function  GetTileX: Integer;
    function  GetTileY: Integer;
    function  GetTileName: string;
    // Load a single .anim file into a PAnimationDef. Public so callers
    // (e.g. uObjectEditorForm.EditAction) can preload animations from
    // the .objs file's references before calling LoadAnimations.
    function  LoadAnimationFromFile(const FileName: string; out anim: PAnimationDef): boolean;

  private
    // FAnimBasePath declared here (before the public property below) because
    // FPC requires the backing field to be in scope before the property.
    FAnimBasePath: string;
    FStandalone: boolean;  // True = running as standalone exe (not plugin)
  public
    // Base directory for new .anim files. The caller sets this to the
    // .objs file's directory before ShowModal so newly-created animations
    // get a sensible default file path.
    property AnimBasePath: string read FAnimBasePath write FAnimBasePath;
    // Standalone mode: when True, btnOK saves all animations but does NOT
    // close the form (no ModalResult). Set to True by the standalone .lpr
    // project. Default False (plugin mode — EditAction expects mrOk).
    property Standalone: boolean read FStandalone write FStandalone;

  private
    FBitmap: TBGRABitmap;
    FCurrentFrame: TBGRABitmap;
    FTileWidth, FTileHeight: integer;
    FTileX, FTileY: integer;
    FTileName: string;
    FImageFilename: string;
    FTotalFrames: integer;
    FTotalRows: integer;
    FAnimations: TList;
    FCurrentAnimIndex: integer;
    FCurrentRow: integer;
    FCurrentFrameIndex: integer;
    FCurrentLayer: PLayerDef;     // nil = none selected; can be a child layer
                                  // (PLayerDef pointers stay stable across
                                  // SetLength on the parent array, so this
                                  // handle survives tree reshuffles.)
    FPlaying: boolean;
    FUpdating: boolean;

    FZoom: double;
    FBackground: TBackgroundStyle;
    FFromTileset: boolean;

    // One-shot timer for deferring tree rebuild after OLE drag-drop.
    // VST's drag machinery is still active when DragDrop fires, so
    // calling Clear + re-add inside the handler leaves the tree in a
    // half-rendered state (moved nodes invisible until the next manual
    // refresh). By deferring to the next message-pump cycle (1ms timer),
    // VST finishes its drag cleanup first, and the rebuild works cleanly.
    FDragRefreshTimer: TTimer;
    FPendingDragLayer: PLayerDef;
    procedure DragRefreshTimerTimer(Sender: TObject);

    procedure UpdateFrame;
    procedure UpdateZoom;
    function GetCheckerPattern(Size: integer): TBGRABitmap;
    procedure SetFrameValue(AIndex: integer);
    procedure RefreshAnimationList;
    procedure SelectAnimation(Index: integer);
    procedure ApplySelectedAnimation;
    procedure UpdatePreviewFromAnimation;
    procedure ClearAnimations(List: TList);
    procedure UpdateFrameList;
    procedure UpdateLayerControls;
    procedure ApplyCurrentTransform;
    procedure ApplyTileFromPicker(Picker: TSpritePickerForm);
    procedure UpdateIconImage(ABmp: TBGRABitmap);

    // Layer helpers
    function  CurrentAnimation: PAnimationDef;
    function  CurrentFrame: PFrameDef;
    function  CurrentLayer: PLayerDef;
    function  DeleteLayerByPtr(var Arr: TLayerDynArray; Layer: PLayerDef): boolean;
    procedure RefreshLayersTree;
    procedure SelectLayer(Layer: PLayerDef);
    procedure ApplyLayerEdits;  // write seZIndex back to the current layer
    procedure EnsureLayersSetup; // init VST columns + lbAnimations drag mode

    // Picker helper: calls LoadTileset for .tileset/.json descriptors,
    // SetImage for plain image files (PNG/BMP/etc.). Without this, calling
    // LoadTileset on a PNG triggers "Invalid character at line 1, pos 1"
    // because LoadTileset tries to JSON-parse the file.
    procedure LoadPickerFile(Picker: TSpritePickerForm; const APath: string);

    // Recursive layer helpers (layers are heap-allocated PLayerDef)
    procedure DisposeLayerRecursive(Layer: PLayerDef);
    function  CloneLayerRecursive(Src: PLayerDef): PLayerDef;
    // Properly disposes a PAnimationDef AND all its heap-allocated layers
    // (recursively, including children). Without this, bare Dispose(anim)
    // leaks every PLayerDef inside Frames[].Layers[] — FPC's Dispose only
    // finalizes the record's managed fields (strings, dynamic arrays), not
    // the pointers stored inside.
    procedure DisposeAnimWithLayers(A: PAnimationDef);

    // Z-order sync: VST tree order is the single source of truth for
    // draw order. SortLayersByZIndex is called once after loading (to
    // convert old ZIndex-based order into array order). ResyncZIndices
    // is called after every tree change (drag-drop, add, delete) to
    // keep ZIndex = position within parent's children.
    procedure SortLayersByZIndex(var Arr: TLayerDynArray);
    procedure ResyncZIndices(var Arr: TLayerDynArray);

    // Returns True if Layer is a top-level (root) layer in the current
    // frame — used to disable cbBehindParent for root layers (they have
    // no parent to draw behind).
    function IsRootLayer(Layer: PLayerDef): boolean;

    // Layer reordering helpers (recursive, name-based to avoid pointer
    // invalidation when SetLength moves the array)
    function  RemoveLayerByName(var Arr: TLayerDynArray;
      const AName: string; out Removed: PLayerDef): boolean;
    function  InsertLayerNearName(var Arr: TLayerDynArray;
      const TargetName: string; const Source: PLayerDef;
      InsertAfter: boolean): boolean;
    function  AddLayerAsChildByName(var Arr: TLayerDynArray;
      const TargetName: string; const Source: PLayerDef): boolean;
    function  IsDescendantOfName(var Arr: TLayerDynArray;
      const DescName, AncName: string): boolean;
    procedure RefreshLayersRecursive(Tree: TBaseVirtualTree;
      ParentNode: PVirtualNode; var Layers: TLayerDynArray);

    // Save / load .anim JSON
    procedure SaveAnimationToFile(const FileName: string; anim: PAnimationDef);

    // Save all animations to their .anim files (called on btnOK)
    procedure SaveAllAnimationsToFiles;
    function  EnsureAnimFilePath(anim: PAnimationDef): string;

    // btnOK click handler — saves all animations then closes
    procedure btnOKClick(Sender: TObject);
    procedure btnExportSprSetClick(Sender: TObject);
    procedure btnExportMskSetClick(Sender: TObject);
    procedure btnPreviewSpriteClick(Sender: TObject);
  end;

implementation

{$R *.frm}

uses
  jsonparser, uCutoutRenderer, uSpritesheetDialog;

procedure TCutoutAnimatorForm.FormCreate(Sender: TObject);
begin
  TDebugLogger.Debug('uCutoutAnimator FormCreate', {$I %CURRENTROUTINE%}, {$I %FILE%}, {$I %lineNum%});
  Caption := 'Cutout Animator';
  Position := poMainFormCenter;
  FAnimations := TList.Create;
  TDebugLogger.DebugFmt('FAnimations.Count; %d ',[FAnimations.Count],  {$I %CURRENTROUTINE%}, {$I %FILE%}, {$I %lineNum%});
  FBitmap := nil;
  FCurrentFrame := nil;
  FTileWidth := 32;
  FTileHeight := 32;
  FTileX := 0;
  FTileY := 0;
  FTileName := '';
  FImageFilename := '';
  FTotalFrames := 0;
  FTotalRows := 0;
  FCurrentAnimIndex := -1;
  FCurrentLayer := nil;
  FZoom := 1.0;
  FBackground := bgChecker;
  FFromTileset := False;
  FPlaying := False;
  FUpdating := False;
  FPendingDragLayer := nil;
  FStandalone := False;  // default: plugin mode. The .lpr sets True.
  // One-shot timer: fires once after drag-drop to rebuild the tree
  // once VST has finished its OLE drag cleanup. Disabled until needed.
  FDragRefreshTimer := TTimer.Create(Self);
  FDragRefreshTimer.Enabled := False;
  FDragRefreshTimer.Interval := 1;
  FDragRefreshTimer.OnTimer := @DragRefreshTimerTimer;
  TDebugLogger.Debug('uCutoutAnimator FormCreate', {$I %CURRENTROUTINE%}, {$I %FILE%}, {$I %lineNum%});
  // sgFrameTransforms is now a simple frame-ordinal list (frames are just
  // containers — the per-frame transform data moved to per-layer).
  sgFrameTransforms.ColCount := 1;
  sgFrameTransforms.FixedCols := 0;
  sgFrameTransforms.Cells[0, 0] := 'Frame';
  sgFrameTransforms.RowCount := 2;
  sgFrameTransforms.Options := sgFrameTransforms.Options + [goRowSelect];
  TDebugLogger.Debug('uCutoutAnimator FormCreate', {$I %CURRENTROUTINE%}, {$I %FILE%}, {$I %lineNum%});

  // Set up the layers tree + drag-drop on the animations listbox.
  // Done in code (not the .frm) so the .frm stays editable in Typhon —
  // if the user later wires the same events in the .frm, the assignments
  // below are simply redundant (the IDE-installed handler wins because
  // it runs through the same OnXxx property).
  EnsureLayersSetup;

  // seZIndex is display-only: ZIndex is derived from VST tree position
  // (see ResyncZIndices). Drag-drop is the only way to change draw
  // order. Disabling the spin edit greys it out so the user knows it
  // can't be edited — the value still updates programmatically via
  // UpdateLayerControls when the selection changes.
  if seZIndex <> nil then
    seZIndex.Enabled := False;
  // Pivot marker visible by default — user can uncheck cbPVis to hide it.
  if cbPVis <> nil then
    cbPVis.Checked := True;
end;

procedure TCutoutAnimatorForm.UpdateIconImage(ABmp: TBGRABitmap);
var
  W, H, SW, SH: Integer;
  ScaledBmp: TBGRABitmap;
begin
  W := iconImage.Width;
  H := iconImage.Height;
  if (W <= 0) or (H <= 0) then Exit;
  if (ABmp = nil) or (ABmp.Width <= 0) or (ABmp.Height <= 0) then Exit;

  iconImage.Picture.Bitmap.SetSize(W, H);

  // Fit tile into iconImage preserving aspect ratio
  SW := W;
  SH := H;
  if ABmp.Width / ABmp.Height > W / H then
    SH := Round(W * ABmp.Height / ABmp.Width)
  else
    SW := Round(H * ABmp.Width / ABmp.Height);

  ScaledBmp := ABmp.Resample(SW, SH) as TBGRABitmap;
  try
    ScaledBmp.Draw(iconImage.Picture.Bitmap.Canvas,
      (W - SW) div 2, (H - SH) div 2, False);
    iconImage.Invalidate;
  finally
    ScaledBmp.Free;
  end;
end;

procedure TCutoutAnimatorForm.ApplyTileFromPicker(Picker: TSpritePickerForm);
var
  TileBmp: TBGRABitmap;
  ATile: TTileDef;
  anim: PAnimationDef;
begin
  TileBmp := Picker.GetSelectedTileBitmap;
  if TileBmp = nil then
  begin
    ShowMessage('No tile selected.');
    Exit;
  end;

  ATile := Picker.GetSelectedTile;

  // Store tile bitmap
  if FBitmap <> nil then FBitmap.Free;
  FBitmap := TileBmp;

  // Tile geometry
  FTileWidth  := ATile.Width;
  FTileHeight := ATile.Height;
  FTileX      := ATile.X;
  FTileY      := ATile.Y;
  FTileName   := ATile.Name;
  FImageFilename := Picker.GetImagePath;

  seTileW.Value := FTileWidth;
  seTileH.Value := FTileHeight;
  seXorig.Value := FTileX;
  seYorig.Value := FTileY;

  FTotalFrames := 1;
  FTotalRows   := 1;
  FFromTileset := True;

  // Update icon image and name label
  UpdateIconImage(FBitmap);
  lblIconName.Caption := ATile.Name;

  // Create a default animation if none exist
  if FAnimations.Count = 0 then
  begin
    New(anim);
    anim^.Name       := ATile.Name;
    anim^.RowIndex   := 0;
    anim^.AnimFilePath := '';
    anim^.FrameCount := 1;
    anim^.SpeedMs    := 100;
    anim^.Transform  := ttNone;
    anim^.Preset     := '';
    anim^.FrameW     := ATile.Width;
    anim^.FrameH     := ATile.Height;
    SetLength(anim^.Frames, 1);
    anim^.Frames[0].Ordinal := 0;
    SetLength(anim^.Frames[0].Layers, 1);
    New(anim^.Frames[0].Layers[0]);
    anim^.Frames[0].Layers[0]^.Visible     := True;
    anim^.Frames[0].Layers[0]^.Name        := ATile.Name;
    anim^.Frames[0].Layers[0]^.OffsetX     := 0;
    anim^.Frames[0].Layers[0]^.OffsetY     := 0;
    anim^.Frames[0].Layers[0]^.Angle       := 0;
    anim^.Frames[0].Layers[0]^.ZIndex      := 0;
    anim^.Frames[0].Layers[0]^.PivotX      := 0;
    anim^.Frames[0].Layers[0]^.PivotY      := 0;
    anim^.Frames[0].Layers[0]^.SourceImage := Picker.GetImagePath;
    anim^.Frames[0].Layers[0]^.TilesetPath := edImage.Text;
    anim^.Frames[0].Layers[0]^.TileX       := ATile.X;
    anim^.Frames[0].Layers[0]^.TileY       := ATile.Y;
    anim^.Frames[0].Layers[0]^.TileW       := ATile.Width;
    anim^.Frames[0].Layers[0]^.TileH       := ATile.Height;
    anim^.Frames[0].Layers[0]^.TileName    := ATile.Name;
    SetLength(anim^.Frames[0].Layers[0]^.Children, 0);
    FAnimations.Add(anim);
    RefreshAnimationList;
  end;

  SelectAnimation(0);
end;

procedure TCutoutAnimatorForm.btnSaveAnimClick(Sender: TObject);
var
  SD: TSaveDialog;
  anim: PAnimationDef;
begin
  // No animation selected -> nothing to save. (We deliberately allow saving
  // even when FAnimations.Count == 1 so the user can export a single-row
  // animation as a starter .anim file.)
  if (FCurrentAnimIndex < 0) or (FCurrentAnimIndex >= FAnimations.Count) then
  begin
    ShowMessage('No animation selected.');
    Exit;
  end;

  // First, push any pending edits in the property panel back into the
  // animation record so what gets saved matches what's on screen.
  ApplyLayerEdits;

  anim := PAnimationDef(FAnimations[FCurrentAnimIndex]);

  SD := TSaveDialog.Create(Self);
  try
    SD.Title := 'Save animation';
    SD.Filter := 'Animation files|*.anim|JSON files|*.json|All files|*.*';
    SD.DefaultExt := 'anim';
    SD.FileName := anim^.Name;
    if not SD.Execute then Exit;
    SaveAnimationToFile(SD.FileName, anim);
    anim^.AnimFilePath := SD.FileName;
    // In standalone mode, use the saved file's directory as the base
    // path for future new animations.
    if FStandalone then
      FAnimBasePath := ExtractFilePath(SD.FileName);
    ShowMessage('Saved animation "' + anim^.Name + '" to ' + SD.FileName);
  finally
    SD.Free;
  end;
end;

procedure TCutoutAnimatorForm.btnLoadAnimClick(Sender: TObject);
var
  OD: TOpenDialog;
  loadedAnim: PAnimationDef;   // renamed from `loaded` to avoid clash with Forms.Loaded (TForm method)
  oldAnim: PAnimationDef;
  selAfter, i: integer;
begin
  OD := TOpenDialog.Create(Self);
  try
    OD.Title := 'Load animation';
    OD.Filter := 'Animation files|*.anim|JSON files|*.json|All files|*.*';
    if not OD.Execute then Exit;

    if not LoadAnimationFromFile(OD.FileName, loadedAnim) then
    begin
      ShowMessage('Failed to load animation from ' + OD.FileName);
      Exit;
    end;

    // In standalone mode, use the loaded file's directory as the base
    // path for new animations. In plugin mode, AnimBasePath is set by
    // the caller (EditAction).
    if FStandalone then
      FAnimBasePath := ExtractFilePath(OD.FileName);

    try
      // Loading replaces the currently selected animation in-place so the
      // row order is preserved. If nothing is selected (or the list is
      // empty) we just append.
      if (FCurrentAnimIndex >= 0) and (FCurrentAnimIndex < FAnimations.Count) then
      begin
        oldAnim := PAnimationDef(FAnimations[FCurrentAnimIndex]);
        Dispose(oldAnim);
        FAnimations[FCurrentAnimIndex] := loadedAnim;
        // Adopt the new animation's RowIndex to match its slot, so loading
        // a .anim file never disturbs the spritesheet row layout.
        loadedAnim^.RowIndex := FCurrentAnimIndex;
      end
      else
      begin
        loadedAnim^.RowIndex := FAnimations.Count;
        FAnimations.Add(loadedAnim);
      end;
      loadedAnim := nil;  // ownership transferred to FAnimations

      // Renumber rows so they stay contiguous.
      for i := 0 to FAnimations.Count - 1 do
        PAnimationDef(FAnimations[i])^.RowIndex := i;

      RefreshAnimationList;
      selAfter := FCurrentAnimIndex;
      if selAfter < 0 then selAfter := 0;
      if selAfter >= FAnimations.Count then selAfter := FAnimations.Count - 1;
      SelectAnimation(selAfter);
      ShowMessage('Loaded animation from ' + OD.FileName);
    except
      // If anything went wrong after we took ownership, free the loaded
      // animation record AND all its layers so we don't leak.
      if loadedAnim <> nil then DisposeAnimWithLayers(loadedAnim);
      raise;
    end;
  finally
    OD.Free;
  end;
end;

procedure TCutoutAnimatorForm.btnNewLayerClick(Sender: TObject);
var
  anim: PAnimationDef;
  frame: PFrameDef;
  OD: TOpenDialog;
  Picker: TSpritePickerForm;
  TilesetPath: string;
  ATile: TTileDef;
  NewLayerName: string;
  NewZ, idx: integer;
begin
  anim := CurrentAnimation;
  if anim = nil then
  begin
    ShowMessage('Select an animation first.');
    Exit;
  end;
  frame := CurrentFrame;
  if frame = nil then
  begin
    ShowMessage('Select a frame first.');
    Exit;
  end;

  // Resolve the tileset to pick from. Prefer the current frame's last
  // layer's source image, then fall back to the form's edImage, then
  // TOpenDialog. (In the new model layers live on the frame, so we look
  // at frame^.Layers — not anim^.Layers.)
  if (Length(frame^.Layers) > 0) and (frame^.Layers[High(frame^.Layers)]^.SourceImage <> '')
     and FileExists(frame^.Layers[High(frame^.Layers)]^.SourceImage) then
    TilesetPath := frame^.Layers[High(frame^.Layers)]^.TilesetPath
  else if (edImage.Text <> '') and FileExists(edImage.Text) then
    TilesetPath := edImage.Text
  else
  begin
    OD := TOpenDialog.Create(Self);
    try
      OD.Title := 'Pick tileset for new layer';
      OD.Filter := 'Tileset files|*.tileset;*.json|Image files|*.png;*.jpg;*.jpeg;*.bmp;*.gif|All files|*.*';
      if not OD.Execute then Exit;
      TilesetPath := OD.FileName;
    finally
      OD.Free;
    end;
  end;

  Picker := TSpritePickerForm.Create(Application);
  try
    LoadPickerFile(Picker, TilesetPath);
    Picker.Caption := 'Pick tile for new layer';
    if Picker.ShowModal <> mrOk then Exit;
    if Picker.SelectedIndex < 0 then
    begin
      ShowMessage('No tile selected.');
      Exit;
    end;
    ATile := Picker.GetSelectedTile;

    if ATile.Name <> '' then
      NewLayerName := ATile.Name
    else
      NewLayerName := 'layer_' + IntToStr(Length(frame^.Layers) + 1);

    // Default Z = one above the highest existing layer so new layers
    // appear on top by default. User can change via seZIndex afterwards.
    NewZ := Length(frame^.Layers);

    // Inline the layer creation (AddLayer has been removed). Append a
    // new heap-allocated PLayerDef to the current frame's Layers[] and
    // fill in its fields.
    idx := Length(frame^.Layers);
    SetLength(frame^.Layers, idx + 1);
    New(frame^.Layers[idx]);
    frame^.Layers[idx]^.Visible     := True;
    frame^.Layers[idx]^.Name        := NewLayerName;
    frame^.Layers[idx]^.OffsetX     := 0;
    frame^.Layers[idx]^.OffsetY     := 0;
    frame^.Layers[idx]^.Angle       := 0;
    frame^.Layers[idx]^.ZIndex      := NewZ;
    frame^.Layers[idx]^.PivotX      := 0;
    frame^.Layers[idx]^.PivotY      := 0;
    frame^.Layers[idx]^.SourceImage := Picker.GetImagePath;
    frame^.Layers[idx]^.TilesetPath := Picker.GetTilesetPath;  // actual tileset used (may differ from the initial TilesetPath if user loaded a different one inside the picker)
    TDebugLogger.DebugFmt('Picker.GetTilesetPath: %s',[Picker.GetTilesetPath], {$I %CURRENTROUTINE%}, {$I %FILE%}, {$I %lineNum%});
    frame^.Layers[idx]^.TileX       := ATile.X;
    frame^.Layers[idx]^.TileY       := ATile.Y;
    frame^.Layers[idx]^.TileW       := ATile.Width;
    frame^.Layers[idx]^.TileH       := ATile.Height;
    frame^.Layers[idx]^.TileName    := ATile.Name;
    SetLength(frame^.Layers[idx]^.Children, 0);

    RefreshLayersTree;
    SelectLayer(frame^.Layers[High(frame^.Layers)]);
    pbPreview.Invalidate;
  finally
    Picker.Free;
  end;
end;

procedure TCutoutAnimatorForm.btnEditLayerClick(Sender: TObject);
var
  anim: PAnimationDef;
  layer: PLayerDef;
  OD: TOpenDialog;
  Picker: TSpritePickerForm;
  TilesetPath: string;
  ATile: TTileDef;
begin
  anim := CurrentAnimation;
  if anim = nil then Exit;
  layer := CurrentLayer;
  if layer = nil then
  begin
    ShowMessage('Select a layer first.');
    Exit;
  end;

  // Prefer the layer's own tileset/source image; fall back to a file dialog.
  if (layer^.TilesetPath <> '') and FileExists(layer^.TilesetPath) then
    TilesetPath := layer^.TilesetPath
  else if (layer^.SourceImage <> '') and FileExists(layer^.SourceImage) then
    TilesetPath := layer^.SourceImage
  else if (edImage.Text <> '') and FileExists(edImage.Text) then
    TilesetPath := edImage.Text
  else
  begin
    OD := TOpenDialog.Create(Self);
    try
      OD.Title := 'Pick tileset for layer';
      OD.Filter := 'Tileset files|*.tileset;*.json|Image files|*.png;*.jpg;*.jpeg;*.bmp;*.gif|All files|*.*';
      if not OD.Execute then Exit;
      TilesetPath := OD.FileName;
    finally
      OD.Free;
    end;
  end;

  Picker := TSpritePickerForm.Create(Application);
  try
    LoadPickerFile(Picker, TilesetPath);
    Picker.Caption := 'Pick tile for layer "' + layer^.Name + '"';
    if Picker.ShowModal <> mrOk then Exit;
    if Picker.SelectedIndex < 0 then
    begin
      ShowMessage('No tile selected.');
      Exit;
    end;
    ATile := Picker.GetSelectedTile;

    layer^.SourceImage := Picker.GetImagePath;
    layer^.TilesetPath := Picker.GetTilesetPath;  // actual tileset used (may differ if user loaded a different one inside the picker)
    TDebugLogger.DebugFmt('Picker.GetTilesetPath: %s',[Picker.GetTilesetPath], {$I %CURRENTROUTINE%}, {$I %FILE%}, {$I %lineNum%});
    layer^.TileX := ATile.X;
    layer^.TileY := ATile.Y;
    layer^.TileW := ATile.Width;
    layer^.TileH := ATile.Height;
    layer^.TileName := ATile.Name;
    if ATile.Name <> '' then
      layer^.Name := ATile.Name;

    RefreshLayersTree;
    // Re-select the same layer (by pointer — survives RefreshLayersTree
    // because the PLayerDef heap allocation isn't touched, only the VST
    // nodes wrapping it are rebuilt).
    SelectLayer(FCurrentLayer);
    pbPreview.Invalidate;
  finally
    Picker.Free;
  end;
end;

procedure TCutoutAnimatorForm.btnDelLayerClick(Sender: TObject);
var
  frame: PFrameDef;
begin
  frame := CurrentFrame;
  if frame = nil then Exit;
  if FCurrentLayer = nil then
  begin
    ShowMessage('Select a layer to delete.');
    Exit;
  end;
  // Don't allow deleting the only TOP-LEVEL layer (a frame must keep at
  // least one root layer). Child layers can always be deleted — they're
  // sub-parts, not the frame itself. This matches the paper-doll model:
  // you can snap a limb off, but you can't remove the torso.
  if (Length(frame^.Layers) = 1) and (FCurrentLayer = frame^.Layers[0]) then
  begin
    ShowMessage('Cannot delete the only layer.');
    Exit;
  end;
  // Recursive delete — works for both top-level and child layers.
  // DeleteLayerByPtr walks Arr[i].Children too, so a limb pinned deep in
  // the hierarchy is found and removed correctly.
  DeleteLayerByPtr(frame^.Layers, FCurrentLayer);
  FCurrentLayer := nil;
  RefreshLayersTree;
  // Pick a sane new selection: first top-level layer (or nil if the
  // frame is somehow empty — shouldn't happen due to the guard above,
  // but defensive).
  if Length(frame^.Layers) > 0 then
    SelectLayer(frame^.Layers[0])
  else
    SelectLayer(nil);
end;

procedure TCutoutAnimatorForm.btnImgEditClick(Sender: TObject);
var
  Picker: TSpritePickerForm;
begin
  if not FileExists(edImage.Text) then
  begin
    ShowMessage('No tileset loaded. Use Browse first.');
    Exit;
  end;

  Picker := TSpritePickerForm.Create(Application);
  try
    LoadPickerFile(Picker, edImage.Text);
    if Picker.ShowModal <> mrOk then Exit;
    ApplyTileFromPicker(Picker);
  finally
    Picker.Free;
  end;
end;

procedure TCutoutAnimatorForm.btnAddFrameClick(Sender: TObject);
var
  anim: PAnimationDef;
  newIdx: integer;
begin
  anim := CurrentAnimation;
  if anim = nil then Exit;

  // Append a new TFrameDef with an empty Layers[] array. The user can
  // then add layers to it via btnNewLayer / drag-drop. Bump FrameCount
  // to match the new Frames[] length.
  newIdx := Length(anim^.Frames);
  SetLength(anim^.Frames, newIdx + 1);
  anim^.Frames[newIdx].Ordinal := newIdx;
  SetLength(anim^.Frames[newIdx].Layers, 0);
  anim^.FrameCount := Length(anim^.Frames);

  // Refresh dependent UI
  FUpdating := True;
  try
    seAnimFrameCount.Value := anim^.FrameCount;
    tbFrame.Max := anim^.FrameCount - 1;
    seFrame.MaxValue := anim^.FrameCount - 1;
    lblTotalFrames.Caption := Format('/%d', [anim^.FrameCount]);
  finally
    FUpdating := False;
  end;
  UpdateFrameList;
  RefreshAnimationList;
end;

procedure TCutoutAnimatorForm.btnDelFrameClick(Sender: TObject);
var
  anim: PAnimationDef;
  i, j, idx, newLen: integer;
begin
  anim := CurrentAnimation;
  if anim = nil then Exit;
  if anim^.FrameCount <= 1 then
  begin
    ShowMessage('Cannot delete the only frame.');
    Exit;
  end;

  // Delete the currently selected frame if any; otherwise delete the last.
  idx := FCurrentFrameIndex;
  if (idx < 0) or (idx >= anim^.FrameCount) then
    idx := anim^.FrameCount - 1;

  // Dispose all layers in the frame being deleted (each layer is
  // heap-allocated and may have its own Children tree).
  for j := 0 to High(anim^.Frames[idx].Layers) do
    DisposeLayerRecursive(anim^.Frames[idx].Layers[j]);

  // Shift the remaining frames down by one.
  for i := idx to anim^.FrameCount - 2 do
  begin
    anim^.Frames[i] := anim^.Frames[i + 1];
    anim^.Frames[i].Ordinal := i;  // renumber so ordinals stay contiguous
  end;
  newLen := anim^.FrameCount - 1;
  SetLength(anim^.Frames, newLen);
  anim^.FrameCount := newLen;

  FUpdating := True;
  try
    seAnimFrameCount.Value := anim^.FrameCount;
    tbFrame.Max := anim^.FrameCount - 1;
    seFrame.MaxValue := anim^.FrameCount - 1;
    lblTotalFrames.Caption := Format('/%d', [anim^.FrameCount]);
  finally
    FUpdating := False;
  end;
  if FCurrentFrameIndex >= anim^.FrameCount then
    FCurrentFrameIndex := anim^.FrameCount - 1;
  UpdateFrameList;
  SetFrameValue(FCurrentFrameIndex);
  RefreshAnimationList;
end;

procedure TCutoutAnimatorForm.btnDupFrameClick(Sender: TObject);
var
  anim: PAnimationDef;
  srcIdx, newIdx, j: integer;
  srcFrame: PFrameDef;
begin
  // Duplicate the current frame: append a new frame whose Layers[] is a
  // deep copy of the current frame's Layers[]. The user then tweaks the
  // copy for the next pose — this is the core workflow for cutout
  // animation (each frame is a slight variation of the previous one).
  //
  // We clone each layer via CloneLayerRecursive so the new frame owns
  // its own independent layer tree (no shared pointers). Edits to the
  // duplicated frame don't affect the source, and vice versa.
  anim := CurrentAnimation;
  if anim = nil then Exit;

  srcIdx := FCurrentFrameIndex;
  if (srcIdx < 0) or (srcIdx >= Length(anim^.Frames)) then
    srcIdx := Length(anim^.Frames) - 1;
  if (srcIdx < 0) or (srcIdx >= Length(anim^.Frames)) then Exit;

  srcFrame := @anim^.Frames[srcIdx];

  // Append a new frame and deep-copy every layer (with children) from
  // the source frame. CloneLayerRecursive allocates fresh PLayerDef
  // records for the entire subtree, so the new frame is fully
  // independent — disposing one frame's layers never touches the other.
  newIdx := Length(anim^.Frames);
  SetLength(anim^.Frames, newIdx + 1);
  anim^.Frames[newIdx].Ordinal := newIdx;
  SetLength(anim^.Frames[newIdx].Layers, Length(srcFrame^.Layers));
  for j := 0 to High(srcFrame^.Layers) do
    anim^.Frames[newIdx].Layers[j] := CloneLayerRecursive(srcFrame^.Layers[j]);
  anim^.FrameCount := Length(anim^.Frames);

  // Refresh dependent UI (same pattern as btnAddFrameClick)
  FUpdating := True;
  try
    seAnimFrameCount.Value := anim^.FrameCount;
    tbFrame.Max := anim^.FrameCount - 1;
    seFrame.MaxValue := anim^.FrameCount - 1;
    lblTotalFrames.Caption := Format('/%d', [anim^.FrameCount]);
  finally
    FUpdating := False;
  end;
  UpdateFrameList;
  // Switch to the newly-created frame so the user can immediately edit it.
  SetFrameValue(newIdx);
  RefreshAnimationList;
end;

procedure TCutoutAnimatorForm.btnFlipHClick(Sender: TObject);
var
  layer: PLayerDef;
begin
  // Toggle horizontal flip (mirror left/right) on the selected layer.
  // Flip is at the tile's center axis — no pivot involved. The flag is
  // applied during drawing: the tile bitmap is mirrored horizontally
  // before rotation/blit. FlipH + FlipV together = 180° rotation, but
  // keeping them as separate flags preserves the user's intent
  // ("mirrored" vs "rotated") and makes the UI state clear.
  layer := CurrentLayer;
  if layer = nil then
  begin
    ShowMessage('Select a layer first.');
    Exit;
  end;
  layer^.FlipH := not layer^.FlipH;
  pbPreview.Invalidate;
end;

procedure TCutoutAnimatorForm.btnFlipVClick(Sender: TObject);
var
  layer: PLayerDef;
begin
  // Toggle vertical flip (mirror up/down) on the selected layer.
  // Same center-axis flip as btnFlipHClick — see that handler for details.
  layer := CurrentLayer;
  if layer = nil then
  begin
    ShowMessage('Select a layer first.');
    Exit;
  end;
  layer^.FlipV := not layer^.FlipV;
  pbPreview.Invalidate;
end;

procedure TCutoutAnimatorForm.FormDestroy(Sender: TObject);
begin
  Timer.Enabled := False;
  FBitmap.Free;
  FCurrentFrame.Free;
  ClearAnimations(FAnimations);
  FAnimations.Free;
end;

procedure TCutoutAnimatorForm.btnBrowseClick(Sender: TObject);
var
  OD: TOpenDialog;
  Picker: TSpritePickerForm;
begin
  OD := TOpenDialog.Create(Self);
  try
    OD.Filter := 'Tileset files|*.tileset|JSON files|*.json|All files|*.*';
    if not OD.Execute then Exit;

    Picker := TSpritePickerForm.Create(Application);
    try
      LoadPickerFile(Picker, OD.FileName);
      if Picker.ShowModal <> mrOk then Exit;

      ApplyTileFromPicker(Picker);

      edImage.Text := OD.FileName;
    finally
      Picker.Free;
    end;
  finally
    OD.Free;
  end;
end;

procedure TCutoutAnimatorForm.btnRefreshClick(Sender: TObject);
begin
  UpdatePreview;
end;

procedure TCutoutAnimatorForm.pbPreviewPaint(Sender: TObject);
type
  // Flat entry for draw-ordered rendering. Carries the accumulated
  // transform from all ancestors so children are positioned relative
  // to their parent's transform, not the frame center. This is the
  // paper-doll model: a child limb's screen position = parent's
  // position + child's offset (rotated by parent's angle).
  //
  // Transform accumulation (Path 2 — transform stack):
  //   AccOffsetX/Y  — accumulated translation (already existed)
  //   AccAngle      — accumulated rotation (sum of ancestor angles + own)
  //   AccPivotX/Y   — the layer's pivot in FRAME coordinates (where
  //                   rotation happens on screen), accumulated through
  //                   the ancestor chain so a parent's rotation swings
  //                   the child's pivot point correctly.
  TLayerToDraw = record
    Layer: PLayerDef;
    AccOffsetX: integer;
    AccOffsetY: integer;
    AccAngle: double;
    AccPivotX: double;   // frame-coords (before centerX/Y + zoom)
    AccPivotY: double;
  end;
var
  destRect: TRect;
  bgBmp: TBGRABitmap;
  frame: PFrameDef;
  anim: PAnimationDef;
  i: integer;
  layer: PLayerDef;
  srcBmp, tileBmp, scaledBmp, flippedBmp, rotatedBmp: TBGRABitmap;
  ownScaledBmp: boolean;  // True if scaledBmp was allocated (not = tileBmp)
  centerX, centerY: integer;
  frameW, frameH: integer;
  frameLeft, frameTop, frameRight, frameBottom: integer;
  drawX, drawY: integer;
  drawW, drawH: integer;
  pivX, pivY: integer;           // pivot screen position (selected layer)
  sortedLayers: array of TLayerToDraw;
  rad: double;                   // rotation angle in radians
  localPivX, localPivY: double;  // pivot relative to tile top-left (scaled)
  newW, newH: integer;

  procedure CollectLayerWithDepth(L: PLayerDef;
    ParentAccX, ParentAccY: integer;
    ParentAngle: double;
    ParentPivotX, ParentPivotY: double;
    ParentVisible: boolean);
  var
    accAngle: double;
    effVisible: boolean;
    c: integer;
    CL: PLayerDef;
    // This layer's center in FRAME coordinates:
    //   - If root: (ParentAccX + OffsetX, ParentAccY + OffsetY)
    //   - If child: parent's pivot + (OffsetX, OffsetY) rotated by
    //     parent's accumulated angle. This is the key transform: a
    //     child's offset is in the parent's LOCAL frame, so when the
    //     parent rotates, the child's position rotates with it.
    accX, accY: double;
    pivLocalX, pivLocalY: double;
    pivFrameX, pivFrameY: double;
    rad, cosA, sinA: double;
    rotOffX, rotOffY: double;
  begin
    if L = nil then Exit;
    accAngle := ParentAngle + L^.Angle;
    effVisible := ParentVisible and L^.Visible;

    // Compute this layer's center in frame coords.
    // Root layers: simple addition (ParentAccX/Y = 0 for roots).
    // Children: the child's base position is (parentCenter + offset).
    // When the parent rotates, the child swings around the parent's PIVOT
    // (the joint), preserving its distance from the pivot. So we:
    //   1. Compute child's position relative to parent's pivot
    //   2. Rotate that by the parent's accumulated angle
    //   3. Add back the parent's pivot position
    // When ParentAngle = 0, this reduces to (ParentAccX + OffsetX) — same
    // as the old behavior, so existing animations are unaffected.
    if (ParentAngle = 0) then
    begin
      // No parent rotation — offset is straight from parent center
      accX := ParentAccX + L^.OffsetX;
      accY := ParentAccY + L^.OffsetY;
    end
    else
    begin
      // Parent is rotated — swing the child around the parent's pivot.
      // Child's position relative to parent pivot:
      //   relX = (parentCenter + offset) - parentPivot
      rad := ParentAngle * Pi / 180.0;
      cosA := Cos(rad);
      sinA := Sin(rad);
      rotOffX := (ParentAccX + L^.OffsetX) - ParentPivotX;
      rotOffY := (ParentAccY + L^.OffsetY) - ParentPivotY;
      // Rotate the relative position around the pivot
      accX := ParentPivotX + (rotOffX * cosA - rotOffY * sinA);
      accY := ParentPivotY + (rotOffX * sinA + rotOffY * cosA);
    end;

    // Compute this layer's pivot in frame coordinates.
    // The tile is drawn centered at (accX, accY). The pivot is at
    // (PivotX, PivotY) in tile-local coords (0,0 = top-left). So the
    // pivot relative to the tile center is (PivotX - TileW/2, PivotY - TileH/2).
    //
    // CRITICAL: use PARENT's angle (inherited), NOT accAngle. The pivot
    // is the fixed point that the layer rotates AROUND — it must be
    // computed BEFORE the layer's own rotation is applied. The tile's
    // local frame is already rotated by the parent's angle (inherited
    // transform), so the pivot offset is rotated by ParentAngle. The
    // layer's own Angle rotates the tile AROUND this pivot, so the
    // pivot itself doesn't move.
    //
    // Bug this fixes: using accAngle here made the pivot position
    // change when the layer's own angle changed, which made rotation
    // appear to always happen around the tile center regardless of
    // where PivotX/Y was set.
    pivLocalX := L^.PivotX - L^.TileW / 2.0;
    pivLocalY := L^.PivotY - L^.TileH / 2.0;
    rad := ParentAngle * Pi / 180.0;
    cosA := Cos(rad);
    sinA := Sin(rad);
    pivFrameX := accX + (pivLocalX * cosA - pivLocalY * sinA);
    pivFrameY := accY + (pivLocalX * sinA + pivLocalY * cosA);

    // 1. Behind-children first
    for c := 0 to High(L^.Children) do
    begin
      CL := L^.Children[c];
      if (CL <> nil) and CL^.DrawBehindParent then
        CollectLayerWithDepth(CL, Round(accX), Round(accY), accAngle, pivFrameX, pivFrameY, effVisible);
    end;

    // 2. L itself
    if effVisible and (L^.SourceImage <> '') and
       (L^.TileW > 0) and (L^.TileH > 0) and
       FileExists(L^.SourceImage) then
    begin
      SetLength(sortedLayers, Length(sortedLayers) + 1);
      sortedLayers[High(sortedLayers)].Layer := L;
      sortedLayers[High(sortedLayers)].AccOffsetX := Round(accX);
      sortedLayers[High(sortedLayers)].AccOffsetY := Round(accY);
      sortedLayers[High(sortedLayers)].AccAngle := accAngle;
      sortedLayers[High(sortedLayers)].AccPivotX := pivFrameX;
      sortedLayers[High(sortedLayers)].AccPivotY := pivFrameY;
    end;

    // 3. In-front children
    for c := 0 to High(L^.Children) do
    begin
      CL := L^.Children[c];
      if (CL <> nil) and not CL^.DrawBehindParent then
        CollectLayerWithDepth(CL, Round(accX), Round(accY), accAngle, pivFrameX, pivFrameY, effVisible);
    end;
  end;

  procedure CollectLayersRecursive(var Arr: TLayerDynArray;
    ParentAccX, ParentAccY: integer;
    ParentAngle: double;
    ParentPivotX, ParentPivotY: double;
    ParentVisible: boolean);
  var
    k: integer;
  begin
    for k := 0 to High(Arr) do
      CollectLayerWithDepth(Arr[k], ParentAccX, ParentAccY, ParentAngle,
        ParentPivotX, ParentPivotY, ParentVisible);
  end;

begin
  destRect := pbPreview.ClientRect;

  // Draw background
  if FBackground = bgChecker then
  begin
    bgBmp := GetCheckerPattern(destRect.Width);
    bgBmp.Draw(pbPreview.Canvas, destRect, True);
    bgBmp.Free;
  end
  else
  begin
    pbPreview.Canvas.Brush.Color := clGray;
    pbPreview.Canvas.FillRect(destRect);
  end;

  centerX := destRect.Left + destRect.Width div 2;
  centerY := destRect.Top + destRect.Height div 2;

  // Get frame dimensions from the current animation
  anim := CurrentAnimation;
  if anim <> nil then
  begin
    frameW := anim^.FrameW;
    frameH := anim^.FrameH;
    if frameW <= 0 then frameW := seAnimW.Value;
    if frameH <= 0 then frameH := seAnimH.Value;
  end
  else
  begin
    frameW := seAnimW.Value;
    frameH := seAnimH.Value;
  end;
  if frameW <= 0 then frameW := 64;
  if frameH <= 0 then frameH := 64;

  // Draw the frame box (the canvas where layers are composited)
  frameW := Round(frameW * FZoom);
  frameH := Round(frameH * FZoom);
  frameLeft := centerX - frameW div 2;
  frameTop := centerY - frameH div 2;
  frameRight := frameLeft + frameW;
  frameBottom := frameTop + frameH;

  pbPreview.Canvas.Brush.Style := bsClear;
  pbPreview.Canvas.Pen.Color := clYellow;
  pbPreview.Canvas.Pen.Width := 1;
  pbPreview.Canvas.Rectangle(frameLeft, frameTop, frameRight, frameBottom);
  pbPreview.Canvas.Brush.Style := bsSolid;

  frame := CurrentFrame;
  if frame = nil then
  begin
    if FCurrentFrame <> nil then
      FCurrentFrame.Draw(pbPreview.Canvas, destRect, False);
    Exit;
  end;

  // Collect ALL visible layers with accumulated transforms.
  // CollectLayersRecursive walks depth-first and computes each layer's
  // accumulated offset, angle, and pivot position in frame coordinates.
  SetLength(sortedLayers, 0);
  CollectLayersRecursive(frame^.Layers, 0, 0, 0, 0, 0, True);

  // Draw each layer's tile at its accumulated transform, in depth-first
  // tree order (parent before children, siblings in array order = VST).
  for i := 0 to High(sortedLayers) do
  begin
    layer := sortedLayers[i].Layer;
    try
      srcBmp := TBGRABitmap.Create(layer^.SourceImage);
    except
      Continue;
    end;
    try
      if (layer^.TileX < 0) or (layer^.TileY < 0) then Continue;
      if (layer^.TileX + layer^.TileW > srcBmp.Width) or
         (layer^.TileY + layer^.TileH > srcBmp.Height) then Continue;

      tileBmp := srcBmp.GetPart(Rect(layer^.TileX, layer^.TileY,
        layer^.TileX + layer^.TileW, layer^.TileY + layer^.TileH)) as TBGRABitmap;
      try
        drawW := Round(tileBmp.Width * FZoom);
        drawH := Round(tileBmp.Height * FZoom);
        if drawW <= 0 then drawW := 1;
        if drawH <= 0 then drawH := 1;

        // Step 1: scale (zoom). Track ownership so we know whether to free.
        if (drawW = tileBmp.Width) and (drawH = tileBmp.Height) then
        begin
          scaledBmp := tileBmp;
          ownScaledBmp := False;
        end
        else
        begin
          scaledBmp := tileBmp.Resample(drawW, drawH) as TBGRABitmap;
          ownScaledBmp := True;
        end;

        try
          // Step 2: flip (mirror at center axis). Creates a new bitmap
          // if either flip flag is set; otherwise reuse scaledBmp.
          // Flip is applied BEFORE rotation — so a flipped+rotated layer
          // mirrors first, then rotates around its pivot. This matches
          // the natural mental model: "flip the sprite, then pose it."
          //
          // Implementation: BGRA's in-place HorizontalFlip/VerticalFlip
          // procedures (documented in pl_BGRAbitmap). We copy scaledBmp
          // into flippedBmp first because the flips modify the bitmap
          // in-place — we don't want to mutate scaledBmp (which may be
          // shared with tileBmp when no zoom was needed).
          if layer^.FlipH or layer^.FlipV then
          begin
            flippedBmp := TBGRABitmap.Create(scaledBmp.Width, scaledBmp.Height);
            flippedBmp.PutImage(0, 0, scaledBmp, dmSet);
            if layer^.FlipH then
              flippedBmp.HorizontalFlip;
            if layer^.FlipV then
              flippedBmp.VerticalFlip;
            if ownScaledBmp then scaledBmp.Free;
            scaledBmp := flippedBmp;
            ownScaledBmp := True;
          end;

          if Abs(sortedLayers[i].AccAngle) < 0.01 then
          begin
            // No rotation: simple blit at accumulated offset.
            drawX := centerX + Round(sortedLayers[i].AccOffsetX * FZoom) - drawW div 2;
            drawY := centerY + Round(sortedLayers[i].AccOffsetY * FZoom) - drawH div 2;
            scaledBmp.Draw(pbPreview.Canvas, drawX, drawY, False);
          end
          else
          begin
            // Rotation: rotate the scaled tile around its pivot, then
            // position it so the pivot lands at AccPivotX/Y (frame coords).
            //
            // The pivot in the tile's local coords is (PivotX, PivotY).
            // After scaling, that's (PivotX*Zoom, PivotY*Zoom). We create
            // a temp bitmap large enough to hold the rotated image, use
            // Canvas2D to rotate around the pivot, then blit so the
            // rotated pivot aligns with the screen pivot position.
            rad := sortedLayers[i].AccAngle * Pi / 180.0;

            // Pivot in scaled-tile local coords
            localPivX := layer^.PivotX * FZoom;
            localPivY := layer^.PivotY * FZoom;

            // Size the temp bitmap to fit the rotated image regardless of
            // where the pivot is within the tile. The maximum distance from
            // any pivot point to any corner is the tile diagonal
            // (sqrt(W² + H²)). Using 2× the diagonal as both dimensions
            // guarantees the rotated tile fits with the pivot at center,
            // no matter where the pivot is. This wastes some memory (the
            // bitmap is larger than strictly needed) but prevents clipping
            // when the pivot is near a corner — which was causing layers
            // to appear cut off.
            newW := Round(Sqrt(drawW * drawW + drawH * drawH) * 2) + 2;
            newH := newW;  // square — diagonal is the same both ways

            rotatedBmp := TBGRABitmap.Create(newW, newH);
            try
              rotatedBmp.FillTransparent;
              // Canvas2D transform pipeline (applied in reverse order):
              //   1. translate(-localPivX, -localPivY)  — move pivot to origin
              //   2. rotate(rad)                         — rotate around origin
              //   3. translate(newW/2, newH/2)           — move to bitmap center
              // After these, drawing the scaled tile at (0,0) places its
              // pivot at the temp bitmap's center.
              rotatedBmp.Canvas2D.translate(newW / 2, newH / 2);
              rotatedBmp.Canvas2D.rotate(rad);
              rotatedBmp.Canvas2D.translate(-localPivX, -localPivY);
              rotatedBmp.Canvas2D.drawImage(scaledBmp, 0, 0);

              // Screen pivot position (frame coords → screen):
              pivX := centerX + Round(sortedLayers[i].AccPivotX * FZoom);
              pivY := centerY + Round(sortedLayers[i].AccPivotY * FZoom);

              // Blit so rotated bitmap's center lands on screen pivot.
              // The pivot in the rotated bitmap is at its center (newW/2, newH/2)
              // because of the translate pipeline above.
              drawX := pivX - newW div 2;
              drawY := pivY - newH div 2;
              rotatedBmp.Draw(pbPreview.Canvas, drawX, drawY, False);
            finally
              rotatedBmp.Free;
            end;
          end;
        finally
          // Free the scaled (and possibly flipped) bitmap if we allocated
          // it. If no zoom/flip was needed, scaledBmp = tileBmp and is
          // freed by the outer try/finally.
          if ownScaledBmp then
            scaledBmp.Free;
        end;
      finally
        tileBmp.Free;
      end;
    finally
      srcBmp.Free;
    end;
  end;

  // Draw a pivot marker (crosshair + circle) on the SELECTED layer.
  if (FCurrentLayer <> nil) and (cbPVis <> nil) and cbPVis.Checked then
  begin
    for i := 0 to High(sortedLayers) do
      if sortedLayers[i].Layer = FCurrentLayer then
      begin
        // Pivot screen position = accumulated pivot (frame coords) → screen
        pivX := centerX + Round(sortedLayers[i].AccPivotX * FZoom);
        pivY := centerY + Round(sortedLayers[i].AccPivotY * FZoom);
        // Pivot marker: white-filled circle with magenta outline +
        // magenta crosshair + magenta center dot.
        pbPreview.Canvas.Pen.Width := 1;
        pbPreview.Canvas.Pen.Color := clFuchsia;
        pbPreview.Canvas.Brush.Color := clWhite;
        pbPreview.Canvas.Ellipse(pivX - 6, pivY - 6, pivX + 7, pivY + 7);
        pbPreview.Canvas.Brush.Style := bsClear;
        pbPreview.Canvas.Line(pivX - 10, pivY, pivX - 8, pivY);
        pbPreview.Canvas.Line(pivX + 8, pivY, pivX + 10, pivY);
        pbPreview.Canvas.Line(pivX, pivY - 10, pivX, pivY - 8);
        pbPreview.Canvas.Line(pivX, pivY + 8, pivX, pivY + 10);
        pbPreview.Canvas.Brush.Color := clFuchsia;
        pbPreview.Canvas.Ellipse(pivX - 1, pivY - 1, pivX + 2, pivY + 2);
        pbPreview.Canvas.Brush.Style := bsSolid;
        Break;
      end;
  end;
end;

procedure TCutoutAnimatorForm.ClearAnimations(List: TList);
var
  i, j, f: integer;
  anim: PAnimationDef;
begin
  for i := 0 to List.Count - 1 do
  begin
    anim := PAnimationDef(List[i]);
    // Dispose all layers in all frames (and their children recursively).
    // Each frame owns its own Layers[] array; we must walk every frame.
    for f := 0 to High(anim^.Frames) do
      for j := 0 to High(anim^.Frames[f].Layers) do
        DisposeLayerRecursive(anim^.Frames[f].Layers[j]);
    Dispose(anim);
  end;
  List.Clear;
end;

// Recursive helper: disposes a layer and all its children
procedure TCutoutAnimatorForm.DisposeLayerRecursive(Layer: PLayerDef);
var
  i: integer;
begin
  if Layer = nil then Exit;
  for i := 0 to High(Layer^.Children) do
    DisposeLayerRecursive(Layer^.Children[i]);
  SetLength(Layer^.Children, 0);
  Dispose(Layer);
end;

procedure TCutoutAnimatorForm.DisposeAnimWithLayers(A: PAnimationDef);
var
  f, j: integer;
begin
  if A = nil then Exit;
  for f := 0 to High(A^.Frames) do
    for j := 0 to High(A^.Frames[f].Layers) do
      DisposeLayerRecursive(A^.Frames[f].Layers[j]);
  Dispose(A);
end;

// Recursive helper: creates a deep copy of a layer (new heap allocation
// for the layer and all its children)
function TCutoutAnimatorForm.CloneLayerRecursive(Src: PLayerDef): PLayerDef;
var
  i: integer;
begin
  if Src = nil then
  begin
    Result := nil;
    Exit;
  end;
  New(Result);
  Result^ := Src^;  // copy all scalar + string fields
  // Deep-copy children
  SetLength(Result^.Children, Length(Src^.Children));
  for i := 0 to High(Src^.Children) do
    Result^.Children[i] := CloneLayerRecursive(Src^.Children[i]);
end;

procedure TCutoutAnimatorForm.SortLayersByZIndex(var Arr: TLayerDynArray);
var
  i, j: integer;
  temp: PLayerDef;
begin
  // Bubble sort by ZIndex (ascending). Small arrays (dozens of layers
  // at most), so bubble sort is fine. Called once after loading to
  // convert old ZIndex-based ordering into array order — after this,
  // the VST displays layers in their correct draw order and ZIndex can
  // be reassigned to match position.
  for i := 0 to High(Arr) - 1 do
    for j := i + 1 to High(Arr) do
      if Arr[j]^.ZIndex < Arr[i]^.ZIndex then
      begin
        temp := Arr[i];
        Arr[i] := Arr[j];
        Arr[j] := temp;
      end;
  // Recurse into children so the entire tree is sorted by Z
  for i := 0 to High(Arr) do
    if Length(Arr[i]^.Children) > 0 then
      SortLayersByZIndex(Arr[i]^.Children);
end;

procedure TCutoutAnimatorForm.ResyncZIndices(var Arr: TLayerDynArray);
var
  i: integer;
begin
  // ZIndex = position within parent's children (0-based). Called after
  // every tree change (drag-drop, add, delete, refresh) to keep ZIndex
  // in sync with array order. The VST is now the single source of
  // truth for draw order — seZIndex is display-only.
  for i := 0 to High(Arr) do
  begin
    Arr[i]^.ZIndex := i;
    if Length(Arr[i]^.Children) > 0 then
      ResyncZIndices(Arr[i]^.Children);
  end;
end;

function TCutoutAnimatorForm.IsRootLayer(Layer: PLayerDef): boolean;
var
  frame: PFrameDef;
  i: integer;
begin
  // A root layer is one that lives directly in frame^.Layers[] (not
  // nested inside another layer's Children[]). Used to disable
  // cbBehindParent for root layers — they have no parent to draw behind.
  Result := False;
  frame := CurrentFrame;
  if frame = nil then Exit;
  for i := 0 to High(frame^.Layers) do
    if frame^.Layers[i] = Layer then
    begin
      Result := True;
      Exit;
    end;
end;

procedure TCutoutAnimatorForm.LoadAnimations(AnimList: TList);
var
  i, j, f: integer;
  src, dest: PAnimationDef;
begin
  ClearAnimations(FAnimations);
  for i := 0 to AnimList.Count - 1 do
  begin
    src := PAnimationDef(AnimList[i]);
    New(dest);
    dest^ := src^;
    // Deep-copy Frames[]. Each frame has its own Layers[] array of
    // heap-allocated PLayerDef — we must clone every layer recursively
    // so the destination owns its own tree (no shared pointers, no
    // double-free when either side is disposed).
    SetLength(dest^.Frames, Length(src^.Frames));
    for f := 0 to High(src^.Frames) do
    begin
      dest^.Frames[f].Ordinal := src^.Frames[f].Ordinal;
      SetLength(dest^.Frames[f].Layers, Length(src^.Frames[f].Layers));
      for j := 0 to High(src^.Frames[f].Layers) do
        dest^.Frames[f].Layers[j] := CloneLayerRecursive(src^.Frames[f].Layers[j]);
    end;
    FAnimations.Add(dest);
  end;
  // Convert old ZIndex-based ordering into array order: sort each
  // frame's layer tree by ZIndex (preserves existing visual order from
  // .anim files that predate the "VST = draw order" model), then
  // reassign ZIndex = position within parent's children. After this,
  // the VST order IS the draw order, and ZIndex is just a display
  // value derived from position.
  for i := 0 to FAnimations.Count - 1 do
  begin
    dest := PAnimationDef(FAnimations[i]);
    for f := 0 to High(dest^.Frames) do
    begin
      SortLayersByZIndex(dest^.Frames[f].Layers);
      ResyncZIndices(dest^.Frames[f].Layers);
    end;
  end;
  RefreshAnimationList;
  if FAnimations.Count > 0 then
    SelectAnimation(0);
end;

procedure TCutoutAnimatorForm.GetAnimations(AnimList: TList);
var
  i, j, f: integer;
  src, dest: PAnimationDef;
begin
  ClearAnimations(AnimList);
  for i := 0 to FAnimations.Count - 1 do
  begin
    src := PAnimationDef(FAnimations[i]);
    New(dest);
    dest^ := src^;
    // Deep-copy Frames[] (recursive clone — see LoadAnimations)
    SetLength(dest^.Frames, Length(src^.Frames));
    for f := 0 to High(src^.Frames) do
    begin
      dest^.Frames[f].Ordinal := src^.Frames[f].Ordinal;
      SetLength(dest^.Frames[f].Layers, Length(src^.Frames[f].Layers));
      for j := 0 to High(src^.Frames[f].Layers) do
        dest^.Frames[f].Layers[j] := CloneLayerRecursive(src^.Frames[f].Layers[j]);
    end;
    AnimList.Add(dest);
  end;
end;

procedure TCutoutAnimatorForm.UpdatePreview;
var
  i, j: integer;
  anim: PAnimationDef;
  placeholder: TBGRABitmap;
begin
  // When FBitmap came from a tileset it is already valid;
  // skip file-based loading and just refresh the current frame.
  if FFromTileset then
  begin
    if FBitmap <> nil then
    begin
      if (FCurrentAnimIndex < 0) or (FCurrentAnimIndex >= FAnimations.Count) then
        SelectAnimation(0)
      else
        ApplySelectedAnimation;
    end;
    Exit;
  end;

  // Ensure we have tile dimensions
  FTileWidth := seTileW.Value;
  FTileHeight := seTileH.Value;
  if (FTileWidth <= 0) or (FTileHeight <= 0) then
  begin
    FTileWidth := 64;
    FTileHeight := 64;
  end;
  // If image file is missing, create a placeholder
  if not FileExists(edImage.Text) then
  begin
    if FBitmap <> nil then FBitmap.Free;
    // Create a placeholder bitmap with red X
    placeholder := TBGRABitmap.Create(FTileWidth, FTileHeight);
    placeholder.Fill(BGRA(200, 200, 200));
    placeholder.DrawLineAntialias(0, 0, FTileWidth - 1, FTileHeight - 1, BGRA(255, 0, 0), 2);
    placeholder.DrawLineAntialias(FTileWidth - 1, 0, 0, FTileHeight - 1, BGRA(255, 0, 0), 2);
    FBitmap := placeholder;
    FTotalFrames := 1;
    FTotalRows := 1;
    if FAnimations.Count = 0 then
    begin
      New(anim);
      anim^.Name := 'default';
      anim^.RowIndex := 0;
      anim^.FrameCount := 1;
      anim^.SpeedMs := 100;
      anim^.Transform := ttNone;
      anim^.Preset := '';
      anim^.FrameW := FTileWidth;
      anim^.FrameH := FTileHeight;
      // New model: one frame with one default layer. The placeholder
      // path has no real image, so the layer's SourceImage stays empty
      // (it's a grouping layer until the user picks a tile).
      SetLength(anim^.Frames, 1);
      anim^.Frames[0].Ordinal := 0;
      SetLength(anim^.Frames[0].Layers, 1);
      New(anim^.Frames[0].Layers[0]);
      anim^.Frames[0].Layers[0]^.Visible     := True;
      anim^.Frames[0].Layers[0]^.Name        := 'layer_1';
      anim^.Frames[0].Layers[0]^.OffsetX     := 0;
      anim^.Frames[0].Layers[0]^.OffsetY     := 0;
      anim^.Frames[0].Layers[0]^.Angle       := 0;
      anim^.Frames[0].Layers[0]^.ZIndex      := 0;
      anim^.Frames[0].Layers[0]^.PivotX      := 0;
      anim^.Frames[0].Layers[0]^.PivotY      := 0;
      anim^.Frames[0].Layers[0]^.SourceImage := '';
      anim^.Frames[0].Layers[0]^.TilesetPath := '';
      anim^.Frames[0].Layers[0]^.TileX       := 0;
      anim^.Frames[0].Layers[0]^.TileY       := 0;
      anim^.Frames[0].Layers[0]^.TileW       := FTileWidth;
      anim^.Frames[0].Layers[0]^.TileH       := FTileHeight;
      anim^.Frames[0].Layers[0]^.TileName    := '';
      SetLength(anim^.Frames[0].Layers[0]^.Children, 0);
      FAnimations.Add(anim);
      RefreshAnimationList;
    end;
    for i := 0 to FAnimations.Count - 1 do
    begin
      anim := PAnimationDef(FAnimations[i]);
      if anim^.RowIndex >= FTotalRows then anim^.RowIndex := 0;
      if anim^.FrameCount > FTotalFrames then anim^.FrameCount := FTotalFrames;
      if anim^.FrameCount < 1 then anim^.FrameCount := 1;
      // Keep the Frames[] array length in sync with FrameCount. When
      // shrinking we must dispose all layers in the discarded frames;
      // when growing we just append empty frames (the user can populate
      // them via btnAddLayer / drag-drop).
      while Length(anim^.Frames) > anim^.FrameCount do
      begin
        for j := 0 to High(anim^.Frames[High(anim^.Frames)].Layers) do
          DisposeLayerRecursive(anim^.Frames[High(anim^.Frames)].Layers[j]);
        SetLength(anim^.Frames, Length(anim^.Frames) - 1);
      end;
      while Length(anim^.Frames) < anim^.FrameCount do
      begin
        SetLength(anim^.Frames, Length(anim^.Frames) + 1);
        anim^.Frames[High(anim^.Frames)].Ordinal := High(anim^.Frames);
        SetLength(anim^.Frames[High(anim^.Frames)].Layers, 0);
      end;
    end;
    if (FCurrentAnimIndex < 0) or (FCurrentAnimIndex >= FAnimations.Count) then
    begin
      SelectAnimation(0)
    end
    else
    begin
      ApplySelectedAnimation;
    end;
    Exit;
  end;

  // Normal case: file exists
  try
    if FBitmap <> nil then FBitmap.Free;
    FBitmap := TBGRABitmap.Create(edImage.Text);
    FTileWidth := seTileW.Value;
    FTileHeight := seTileH.Value;
    if (FTileWidth <= 0) or (FTileHeight <= 0) then Exit;
    if (FBitmap.Width < FTileWidth) or (FBitmap.Height < FTileHeight) then Exit;
    FTotalFrames := FBitmap.Width div FTileWidth;
    FTotalRows := FBitmap.Height div FTileHeight;

    if FAnimations.Count = 0 then
    begin
      New(anim);
      anim^.Name := 'default';
      anim^.RowIndex := 0;
      anim^.FrameCount := 1;
      anim^.SpeedMs := 100;
      anim^.Transform := ttNone;
      anim^.Preset := '';
      anim^.FrameW := FTileWidth;
      anim^.FrameH := FTileHeight;
      // New model: one frame with one default layer pointing at the
      // top-left tile of the sheet. (Old behaviour fanned out
      // FTotalFrames frames, but in the cutout model each frame is a
      // distinct pose the user builds by hand — so we start with one
      // frame and let them add more via btnAddFrame.)
      SetLength(anim^.Frames, 1);
      anim^.Frames[0].Ordinal := 0;
      SetLength(anim^.Frames[0].Layers, 1);
      New(anim^.Frames[0].Layers[0]);
      anim^.Frames[0].Layers[0]^.Visible     := True;
      anim^.Frames[0].Layers[0]^.Name        := 'layer_1';
      anim^.Frames[0].Layers[0]^.OffsetX     := 0;
      anim^.Frames[0].Layers[0]^.OffsetY     := 0;
      anim^.Frames[0].Layers[0]^.Angle       := 0;
      anim^.Frames[0].Layers[0]^.ZIndex      := 0;
      anim^.Frames[0].Layers[0]^.PivotX      := 0;
      anim^.Frames[0].Layers[0]^.PivotY      := 0;
      anim^.Frames[0].Layers[0]^.SourceImage := edImage.Text;
      anim^.Frames[0].Layers[0]^.TilesetPath := edImage.Text;
      anim^.Frames[0].Layers[0]^.TileX       := 0;
      anim^.Frames[0].Layers[0]^.TileY       := 0;
      anim^.Frames[0].Layers[0]^.TileW       := FTileWidth;
      anim^.Frames[0].Layers[0]^.TileH       := FTileHeight;
      anim^.Frames[0].Layers[0]^.TileName    := '';
      SetLength(anim^.Frames[0].Layers[0]^.Children, 0);
      FAnimations.Add(anim);
      RefreshAnimationList;
    end;

    for i := 0 to FAnimations.Count - 1 do
    begin
      anim := PAnimationDef(FAnimations[i]);
      if anim^.RowIndex >= FTotalRows then anim^.RowIndex := 0;
      if anim^.FrameCount > FTotalFrames then anim^.FrameCount := FTotalFrames;
      if anim^.FrameCount < 1 then anim^.FrameCount := 1;
      // Keep Frames[] length in sync with FrameCount (see placeholder
      // branch above for the dispose/append logic).
      while Length(anim^.Frames) > anim^.FrameCount do
      begin
        for j := 0 to High(anim^.Frames[High(anim^.Frames)].Layers) do
          DisposeLayerRecursive(anim^.Frames[High(anim^.Frames)].Layers[j]);
        SetLength(anim^.Frames, Length(anim^.Frames) - 1);
      end;
      while Length(anim^.Frames) < anim^.FrameCount do
      begin
        SetLength(anim^.Frames, Length(anim^.Frames) + 1);
        anim^.Frames[High(anim^.Frames)].Ordinal := High(anim^.Frames);
        SetLength(anim^.Frames[High(anim^.Frames)].Layers, 0);
      end;
    end;

    if (FCurrentAnimIndex < 0) or (FCurrentAnimIndex >= FAnimations.Count) then
      SelectAnimation(0)
    else
      ApplySelectedAnimation;
  except
    on E: Exception do
      TDebugLogger.DebugFmt('UpdatePreview exception: %s', [E.Message], {$I %CURRENTROUTINE%}, {$I %FILE%}, {$I %lineNum%});
  end;
end;

procedure TCutoutAnimatorForm.RefreshAnimationList;
var
  i: integer;
  anim: PAnimationDef;
begin
  lbAnimations.Clear;
  for i := 0 to FAnimations.Count - 1 do
  begin
    anim := PAnimationDef(FAnimations[i]);
    lbAnimations.Items.Add(Format('%s (row %d, %d frames)', [anim^.Name, anim^.RowIndex, anim^.FrameCount]));
  end;
end;

procedure TCutoutAnimatorForm.SelectAnimation(Index: integer);
begin
  if (Index < 0) or (Index >= FAnimations.Count) then Exit;
  FCurrentAnimIndex := Index;
  ApplySelectedAnimation;
  lbAnimations.ItemIndex := Index;
end;

procedure TCutoutAnimatorForm.ApplySelectedAnimation;
var
  anim: PAnimationDef;
begin
  if (FCurrentAnimIndex < 0) or (FCurrentAnimIndex >= FAnimations.Count) then Exit;
  anim := PAnimationDef(FAnimations[FCurrentAnimIndex]);
  FUpdating := True;
  try
    edAnimName.Text := anim^.Name;
    seAnimRow.Value := anim^.RowIndex;
    seAnimFrameCount.Value := anim^.FrameCount;
    seAnimSpeed.Value := anim^.SpeedMs;
    // Per-animation frame dimensions. Fall back to the form's tile size
    // (seTileW/H) when the animation doesn't specify one — this keeps
    // older .anim files that predate FrameW/H working.
    if anim^.FrameW > 0 then seAnimW.Value := anim^.FrameW
    else                      seAnimW.Value := seTileW.Value;
    if anim^.FrameH > 0 then seAnimH.Value := anim^.FrameH
    else                      seAnimH.Value := seTileH.Value;
    // Update preview
    FCurrentRow := anim^.RowIndex;
    if FCurrentRow >= FTotalRows then FCurrentRow := 0;
    tbSpeed.Position := anim^.SpeedMs;
    tbFrame.Max := anim^.FrameCount - 1;
    seFrame.MaxValue := anim^.FrameCount - 1;
    lblTotalFrames.Caption := Format('/%d', [anim^.FrameCount]);

    // New model: switch to frame 0 and refresh the per-frame UI. The
    // paint handler composites layers from CurrentFrame^.Layers, so the
    // preview stays correct without us touching FCurrentFrame here.
    FCurrentFrameIndex := 0;
    seFrame.Value := 0;
    tbFrame.Position := 0;
    UpdateFrameList;
  finally
    FUpdating := False;
  end;
  // Reset layer selection to the first layer of frame 0 (or nil if the
  // frame has no layers). RefreshLayersTree rebuilds the VST, then
  // SelectLayer walks it to find the node whose data points to that
  // layer — works for any layer (top-level or child) because the
  // pointer stays stable across the rebuild.
  if (Length(anim^.Frames) > 0) and (Length(anim^.Frames[0].Layers) > 0) then
    FCurrentLayer := anim^.Frames[0].Layers[0]
  else
    FCurrentLayer := nil;
  RefreshLayersTree;
  SelectLayer(FCurrentLayer);
  UpdatePreviewFromAnimation;
end;

procedure TCutoutAnimatorForm.UpdatePreviewFromAnimation;
begin
  if FCurrentAnimIndex >= 0 then
  begin
    FCurrentRow := PAnimationDef(FAnimations[FCurrentAnimIndex])^.RowIndex;
    UpdateFrame;
  end;
end;

procedure TCutoutAnimatorForm.UpdateFrame;
begin
  // New model: frames are composed from layers at paint time (see
  // pbPreviewPaint). There's no per-frame bitmap to extract from FBitmap
  // any more — the paint handler loads each layer's tile from its
  // SourceImage and composites them. All we need here is a repaint.
  pbPreview.Invalidate;
end;

procedure TCutoutAnimatorForm.SetFrameValue(AIndex: integer);
begin
  if FUpdating then Exit;
  FUpdating := True;
  try
    if FCurrentAnimIndex >= 0 then
    begin
      FCurrentFrameIndex := AIndex;
      seFrame.Value := AIndex;
      tbFrame.Position := AIndex;
      // Switching frames invalidates the layer selection — the old
      // FCurrentLayer pointed into the previous frame's Layers[] tree,
      // which is a different tree entirely. Reset to nil and let
      // RefreshLayersTree + SelectLayer re-establish a sane selection
      // for the new frame.
      FCurrentLayer := nil;
    end;
  finally
    FUpdating := False;
  end;
  RefreshLayersTree;
  // Pick the first top-level layer of the new frame (or nil if it has
  // none) and push its transforms into the spin edits. UpdateLayerControls
  // is called by SelectLayer, so the explicit call below is redundant —
  // kept as a no-op guard for clarity.
  if (CurrentFrame <> nil) and (Length(CurrentFrame^.Layers) > 0) then
    FCurrentLayer := CurrentFrame^.Layers[0]
  else
    FCurrentLayer := nil;
  SelectLayer(FCurrentLayer);
  pbPreview.Invalidate;
end;

procedure TCutoutAnimatorForm.UpdateFrameList;
var
  i: integer;
  anim: PAnimationDef;
begin
  // The string grid is now a simple frame-ordinal list (1 column:
  // "Frame" header + one row per frame, numbered 1..FrameCount). The
  // per-frame transform data moved onto individual layers, so this grid
  // is just a frame picker.
  if (FCurrentAnimIndex < 0) or (FCurrentAnimIndex >= FAnimations.Count) then Exit;
  anim := PAnimationDef(FAnimations[FCurrentAnimIndex]);
  sgFrameTransforms.RowCount := anim^.FrameCount + 1;
  for i := 0 to anim^.FrameCount - 1 do
    sgFrameTransforms.Cells[0, i+1] := IntToStr(i+1);
end;

procedure TCutoutAnimatorForm.UpdateLayerControls;
var
  layer: PLayerDef;
begin
  // Single source of truth for "selected layer → spin edits" sync.
  // Called from SelectLayer, VirtualStringTree1FocusChanged, and
  // SetFrameValue. FUpdating guards the OnChange handlers so they don't
  // fire and write back to the layer during the push.
  //
  // When no layer is selected, all spin edits are reset to 0 — this
  // avoids the old bug where stale values from a previously-selected
  // layer would linger in the UI and silently get written to the wrong
  // layer when the user clicked a different one.
  FUpdating := True;
  try
    layer := CurrentLayer;
    // Defensive nil-checks on every spin edit: if the .frm and .pas are
    // out of sync, the unlinked class field stays nil at runtime.
    if layer <> nil then
    begin
      if seOffsetX <> nil then seOffsetX.Value := layer^.OffsetX;
      if seOffsetY <> nil then seOffsetY.Value := layer^.OffsetY;
      if seAngle   <> nil then seAngle.Value   := layer^.Angle;
      if seZIndex  <> nil then seZIndex.Value  := layer^.ZIndex;
      if sePivotX  <> nil then sePivotX.Value  := layer^.PivotX;
      if sePivotY  <> nil then sePivotY.Value  := layer^.PivotY;
      // DrawBehindParent checkbox: reflects whether the selected layer
      // is drawn behind its parent. Disabled for root layers (they have
      // no parent, so the concept doesn't apply).
      if cbBehindParent <> nil then
      begin
        cbBehindParent.Checked := layer^.DrawBehindParent;
        // Determine if this is a root layer by checking if it's in the
        // current frame's top-level Layers[]. If root, disable the
        // checkbox — it has no parent to draw behind.
        cbBehindParent.Enabled := not IsRootLayer(layer);
      end;
    end
    else
    begin
      if seOffsetX <> nil then seOffsetX.Value := 0;
      if seOffsetY <> nil then seOffsetY.Value := 0;
      if seAngle   <> nil then seAngle.Value   := 0;
      if seZIndex  <> nil then seZIndex.Value  := 0;
      if sePivotX  <> nil then sePivotX.Value  := 0;
      if sePivotY  <> nil then sePivotY.Value  := 0;
      if cbBehindParent <> nil then
      begin
        cbBehindParent.Checked := False;
        cbBehindParent.Enabled := False;
      end;
    end;
  finally
    FUpdating := False;
  end;
end;

procedure TCutoutAnimatorForm.ApplyCurrentTransform;
var
  layer: PLayerDef;
begin
  // Write the spin edits back into the SELECTED LAYER (not the frame).
  // PivotX/Y are included so the rotation pivot round-trips through the
  // UI (SaveAnimationToFile already serializes them; without this
  // write-back the user could move a pivot, save, reload, and lose the
  // change).
  if (FCurrentAnimIndex < 0) or (FCurrentFrameIndex < 0) then Exit;
  layer := CurrentLayer;
  if layer = nil then Exit;
  // Same nil-guard pattern as UpdateLayerControls — protects against a
  // .frm/.pas desync where one of the spin edit fields is unlinked and
  // stays nil at runtime.
  if seOffsetX <> nil then layer^.OffsetX := seOffsetX.Value;
  if seOffsetY <> nil then layer^.OffsetY := seOffsetY.Value;
  if seAngle   <> nil then layer^.Angle   := seAngle.Value;
  // ZIndex is NOT written here — it's derived from VST tree position
  // (see ResyncZIndices). Drag-drop is the only way to change draw order.
  if sePivotX  <> nil then layer^.PivotX  := sePivotX.Value;
  if sePivotY  <> nil then layer^.PivotY  := sePivotY.Value;
  UpdateFrameList;          // frame ordinals unchanged, but keep grid in sync
  pbPreview.Invalidate;     // repaint with the updated transforms
end;

// Event handlers for new controls
procedure TCutoutAnimatorForm.seOffsetXChange(Sender: TObject);
begin
  if FUpdating then Exit;
  ApplyCurrentTransform;
end;

procedure TCutoutAnimatorForm.seOffsetYChange(Sender: TObject);
begin
  if FUpdating then Exit;
  ApplyCurrentTransform;
end;

procedure TCutoutAnimatorForm.seAngleChange(Sender: TObject);
begin
  if FUpdating then Exit;
  ApplyCurrentTransform;
end;

procedure TCutoutAnimatorForm.sePivotXChange(Sender: TObject);
begin
  if FUpdating then Exit;
  ApplyCurrentTransform;
end;

procedure TCutoutAnimatorForm.sePivotYChange(Sender: TObject);
begin
  if FUpdating then Exit;
  ApplyCurrentTransform;
end;

procedure TCutoutAnimatorForm.btnApplyFrameClick(Sender: TObject);
begin
  ApplyCurrentTransform;
end;

procedure TCutoutAnimatorForm.cbPVisClick(Sender: TObject);
begin
  // Toggling pivot-marker visibility just needs a repaint — no data
  // changes. The marker is drawn (or not) in pbPreviewPaint based on
  // cbPVis.Checked.
  pbPreview.Invalidate;
end;

procedure TCutoutAnimatorForm.cbBehindParentClick(Sender: TObject);
var
  layer: PLayerDef;
begin
  // Toggle DrawBehindParent on the selected layer. Changes draw order
  // (behind vs. in front of parent) but NOT transform inheritance —
  // the layer stays a child of its parent regardless.
  if FUpdating then Exit;
  layer := CurrentLayer;
  if layer = nil then Exit;
  layer^.DrawBehindParent := cbBehindParent.Checked;
  pbPreview.Invalidate;
end;

procedure TCutoutAnimatorForm.sgFrameTransformsClick(Sender: TObject);
var
  row: integer;
begin
  row := sgFrameTransforms.Row;
  if (row > 0) and (row-1 <> FCurrentFrameIndex) then
    SetFrameValue(row-1);
end;

// Existing event handlers (unchanged except added calls)
procedure TCutoutAnimatorForm.btnAddAnimClick(Sender: TObject);
var
  anim: PAnimationDef;
  newIdx: integer;
  LayerName, LayerSource, LayerTileset: string;
  LayerX, LayerY, LayerW, LayerH: integer;
begin
  // Compute the new row index = next sequential row. Each animation occupies
  // one row in the output spritesheet, so the new one goes after the last.
  newIdx := FAnimations.Count;

  New(anim);
  anim^.Name       := 'anim_' + IntToStr(newIdx);
  anim^.RowIndex   := newIdx;
  // New model: each new animation starts with exactly ONE frame (a single
  // pose). The user adds more frames via btnAddFrame. (Old behaviour
  // fanned out FTotalFrames frames, but in the cutout model frames are
  // hand-built poses, not tiles of a spritesheet.)
  anim^.FrameCount := 1;
  anim^.SpeedMs    := 100;
  anim^.Transform  := ttNone;
  anim^.Preset     := '';
  // Default per-animation frame size = the form's current tile size.
  anim^.FrameW     := seTileW.Value;
  anim^.FrameH     := seTileH.Value;

  // Seed with one default layer. If we have a tile currently loaded
  // (either via Browse or via SetTilesetTile from the Object Editor),
  // that tile becomes the layer's image — this matches the user's
  // requirement that "the first one will use the default icon we load
  // into iconImage". Otherwise the layer is created empty and the user
  // can pick its image later via btnNewLayer / btnEditLayer.
  if (FBitmap <> nil) and (FImageFilename <> '') then
  begin
    LayerName    := FTileName;
    if LayerName = '' then LayerName := 'layer_1';
    LayerSource  := FImageFilename;
    LayerTileset := edImage.Text;
    LayerX       := FTileX;
    LayerY       := FTileY;
    LayerW       := FTileWidth;
    LayerH       := FTileHeight;
  end
  else
  begin
    LayerName    := 'layer_1';
    LayerSource  := '';
    LayerTileset := '';
    LayerX       := 0;
    LayerY       := 0;
    LayerW       := seTileW.Value;
    if LayerW <= 0 then LayerW := 32;
    LayerH       := seTileH.Value;
    if LayerH <= 0 then LayerH := 32;
  end;

  // New model: Frames[0] holds the default layer. (No FrameTransforms,
  // no flat anim^.Layers array — both replaced by per-frame Layers[].)
  SetLength(anim^.Frames, 1);
  anim^.Frames[0].Ordinal := 0;
  SetLength(anim^.Frames[0].Layers, 1);
  New(anim^.Frames[0].Layers[0]);
  anim^.Frames[0].Layers[0]^.Visible     := True;
  anim^.Frames[0].Layers[0]^.Name        := LayerName;
  anim^.Frames[0].Layers[0]^.OffsetX     := 0;
  anim^.Frames[0].Layers[0]^.OffsetY     := 0;
  anim^.Frames[0].Layers[0]^.Angle       := 0;
  anim^.Frames[0].Layers[0]^.ZIndex      := 0;
  anim^.Frames[0].Layers[0]^.PivotX      := 0;
  anim^.Frames[0].Layers[0]^.PivotY      := 0;
  anim^.Frames[0].Layers[0]^.SourceImage := LayerSource;
  anim^.Frames[0].Layers[0]^.TilesetPath := LayerTileset;
  anim^.Frames[0].Layers[0]^.TileX       := LayerX;
  anim^.Frames[0].Layers[0]^.TileY       := LayerY;
  anim^.Frames[0].Layers[0]^.TileW       := LayerW;
  anim^.Frames[0].Layers[0]^.TileH       := LayerH;
  anim^.Frames[0].Layers[0]^.TileName    := LayerName;
  SetLength(anim^.Frames[0].Layers[0]^.Children, 0);

  FAnimations.Add(anim);
  RefreshAnimationList;
  newIdx := FAnimations.Count - 1;
  SelectAnimation(newIdx);
end;

procedure TCutoutAnimatorForm.btnDeleteAnimClick(Sender: TObject);
var
  idx, selAfter, i, j, f: integer;
  anim: PAnimationDef;
begin
  if FAnimations.Count = 0 then Exit;
  idx := lbAnimations.ItemIndex;
  if idx < 0 then idx := FCurrentAnimIndex;
  if idx < 0 then Exit;

  if FAnimations.Count <= 1 then
  begin
    ShowMessage('Cannot delete the only animation.');
    Exit;
  end;

  // Free the animation record. In the new model each frame owns a
  // heap-allocated Layers[] tree, so we must walk every frame and
  // dispose every layer (and its children) BEFORE disposing the record
  // itself — otherwise the layer memory leaks (FPC's reference counting
  // releases the dynamic-array storage but not the PLayerDef pointers
  // inside it).
  anim := PAnimationDef(FAnimations[idx]);
  for f := 0 to High(anim^.Frames) do
    for j := 0 to High(anim^.Frames[f].Layers) do
      DisposeLayerRecursive(anim^.Frames[f].Layers[j]);
  Dispose(anim);
  FAnimations.Delete(idx);

  // After deletion, renumber every remaining animation's RowIndex so
  // the rows are contiguous starting at 0 — this keeps the spritesheet
  // layout dense and matches the visual order in lbAnimations.
  for i := 0 to FAnimations.Count - 1 do
    PAnimationDef(FAnimations[i])^.RowIndex := i;

  RefreshAnimationList;

  // Pick a sane animation to select afterwards: the same visual slot
  // (now occupied by the next animation), or the new last one if we
  // deleted the tail.
  selAfter := idx;
  if selAfter >= FAnimations.Count then
    selAfter := FAnimations.Count - 1;
  SelectAnimation(selAfter);
end;

procedure TCutoutAnimatorForm.lbAnimationsClick(Sender: TObject);
begin
  if FUpdating then Exit;
  SelectAnimation(lbAnimations.ItemIndex);
end;

procedure TCutoutAnimatorForm.AnimPropChange(Sender: TObject);
var
  anim: PAnimationDef;
  j: integer;
begin
  if FUpdating or (FCurrentAnimIndex < 0) then Exit;
  anim := PAnimationDef(FAnimations[FCurrentAnimIndex]);
  anim^.Name := edAnimName.Text;
  anim^.RowIndex := seAnimRow.Value;
  anim^.FrameW := seAnimW.Value;
  anim^.FrameH := seAnimH.Value;
  // ZIndex is NO LONGER edited here — it's derived from the layer's
  // position in the VST tree (see ResyncZIndices). Drag-drop is the
  // only way to change draw order. seZIndex is display-only.
  //
  // BUG FIX: do NOT clamp seAnimFrameCount to FTotalFrames here.
  // FTotalFrames is a legacy variable from the old "spritesheet-as-tiles"
  // model (set to FBitmap.Width div FTileWidth when loading a tileset).
  // It has nothing to do with the cutout animation's actual frame count.
  // The old clamp `seAnimFrameCount.Value := FTotalFrames` was resetting
  // the frame count to 1 (FTotalFrames's typical value after a tileset
  // load) whenever the user changed seAnimW or seAnimH — destroying all
  // but one frame.
  //
  // The source of truth for frame count is Length(anim^.Frames). The
  // sync logic below grows/shrinks the Frames[] array to match
  // seAnimFrameCount.Value. If seAnimFrameCount.Value is wrong (e.g.
  // stale after a programmatic frame-count change elsewhere), the
  // sync would still corrupt the animation — but that's a different
  // bug, and the fix is to not fire AnimPropChange for seAnimW/H
  // changes when those spin edits aren't the frame count control.
  anim^.FrameCount := seAnimFrameCount.Value;
  if anim^.FrameCount < 1 then anim^.FrameCount := 1;
  anim^.SpeedMs := seAnimSpeed.Value;
  if anim^.SpeedMs < 20 then anim^.SpeedMs := 20;
  // Keep the Frames[] array length in sync with FrameCount. When
  // shrinking, dispose every layer in the discarded frames; when
  // growing, append empty frames (the user populates them via
  // btnNewLayer / drag-drop).
  while Length(anim^.Frames) > anim^.FrameCount do
  begin
    for j := 0 to High(anim^.Frames[High(anim^.Frames)].Layers) do
      DisposeLayerRecursive(anim^.Frames[High(anim^.Frames)].Layers[j]);
    SetLength(anim^.Frames, Length(anim^.Frames) - 1);
  end;
  while Length(anim^.Frames) < anim^.FrameCount do
  begin
    SetLength(anim^.Frames, Length(anim^.Frames) + 1);
    anim^.Frames[High(anim^.Frames)].Ordinal := High(anim^.Frames);
    SetLength(anim^.Frames[High(anim^.Frames)].Layers, 0);
  end;
  if FPlaying then
    Timer.Interval := anim^.SpeedMs
  else
    tbSpeed.Position := anim^.SpeedMs;
  RefreshAnimationList;
  lbAnimations.ItemIndex := FCurrentAnimIndex;
  tbFrame.Max := anim^.FrameCount - 1;
  seFrame.MaxValue := anim^.FrameCount - 1;
  lblTotalFrames.Caption := Format('/%d', [anim^.FrameCount]);
  if FCurrentFrameIndex >= anim^.FrameCount then
    SetFrameValue(anim^.FrameCount - 1)
  else
    UpdatePreviewFromAnimation;
  UpdateFrameList;
  RefreshLayersTree;
  pbPreview.Invalidate;
end;

procedure TCutoutAnimatorForm.tbFrameChange(Sender: TObject);
begin
  if FUpdating then Exit;
  if FPlaying then btnPlayClick(nil);
  SetFrameValue(tbFrame.Position);
end;

procedure TCutoutAnimatorForm.seFrameChange(Sender: TObject);
begin
  if FUpdating then Exit;
  if FPlaying then btnPlayClick(nil);
  SetFrameValue(seFrame.Value);
end;

procedure TCutoutAnimatorForm.btnPlayClick(Sender: TObject);
begin
  FPlaying := not FPlaying;
  if FPlaying then
  begin
    btnPlay.Caption := 'Stop';
    if FCurrentAnimIndex >= 0 then
      Timer.Interval := PAnimationDef(FAnimations[FCurrentAnimIndex])^.SpeedMs
    else
      Timer.Interval := tbSpeed.Position;
    Timer.Enabled := True;
  end
  else
  begin
    btnPlay.Caption := 'Play';
    Timer.Enabled := False;
  end;
end;

procedure TCutoutAnimatorForm.TimerTimer(Sender: TObject);
var
  NextIndex: integer;
  anim: PAnimationDef;
begin
  if FCurrentAnimIndex < 0 then Exit;
  anim := PAnimationDef(FAnimations[FCurrentAnimIndex]);
  NextIndex := (FCurrentFrameIndex + 1) mod anim^.FrameCount;
  SetFrameValue(NextIndex);
end;

procedure TCutoutAnimatorForm.tbSpeedChange(Sender: TObject);
begin
  lblSpeed.Caption := Format('%dms', [tbSpeed.Position]);
  if FPlaying then
    Timer.Interval := tbSpeed.Position
  else if FCurrentAnimIndex >= 0 then
    PAnimationDef(FAnimations[FCurrentAnimIndex])^.SpeedMs := tbSpeed.Position;
end;

procedure TCutoutAnimatorForm.tbZoomChange(Sender: TObject);
begin
  FZoom := tbZoom.Position / 100;
  lblZoom.Caption := Format('%d%%', [tbZoom.Position]);
  UpdateZoom;
  pbPreview.Invalidate;
end;

procedure TCutoutAnimatorForm.UpdateZoom;
var
  newW, newH, maxW, maxH: integer;
begin
  if FCurrentFrame = nil then Exit;
  newW := Round(FCurrentFrame.Width * FZoom);
  newH := Round(FCurrentFrame.Height * FZoom);
  maxW := 400;
  maxH := 400;
  if newW > maxW then
  begin
    newW := maxW;
    newH := Round(FCurrentFrame.Height * (maxW / FCurrentFrame.Width));
  end;
  if newH > maxH then
  begin
    newH := maxH;
    newW := Round(FCurrentFrame.Width * (maxH / FCurrentFrame.Height));
  end;
  pbPreview.SetBounds(pbPreview.Left, pbPreview.Top, newW, newH);
end;

procedure TCutoutAnimatorForm.cbBackgroundChange(Sender: TObject);
begin
  if cbBackground.ItemIndex = 0 then FBackground := bgSolid
  else
    FBackground := bgChecker;
  pbPreview.Invalidate;
end;

procedure TCutoutAnimatorForm.SetTilesetTile(const ATilesetPath, AImagePath: string;
  AX, AY, AW, AH: integer; const AName: string);
var
  Bmp: TBGRABitmap;
  TileBmp: TBGRABitmap;
begin
  if not FileExists(AImagePath) then Exit;
  try
    Bmp := TBGRABitmap.Create(AImagePath);
  except
    Exit;
  end;
  try
    if (AX < 0) or (AY < 0) then Exit;
    if (AX + AW > Bmp.Width) or (AY + AH > Bmp.Height) then Exit;
    TileBmp := Bmp.GetPart(Rect(AX, AY, AX + AW, AY + AH)) as TBGRABitmap;

    if FBitmap <> nil then FBitmap.Free;
    FBitmap := TileBmp;

    FTileWidth  := AW;
    FTileHeight := AH;
    FTileX      := AX;
    FTileY      := AY;
    FTileName   := AName;
    FImageFilename := AImagePath;
    FFromTileset := True;
    FTotalFrames := 1;
    FTotalRows   := 1;

    edImage.Text     := ATilesetPath;
    seTileW.Value    := AW;
    seTileH.Value    := AH;
    seXorig.Value    := AX;
    seYorig.Value    := AY;
    lblIconName.Caption := AName;
    UpdateIconImage(FBitmap);
  finally
    Bmp.Free;
  end;
end;

function TCutoutAnimatorForm.GetTilesetPath: string;
begin
  Result := edImage.Text;
end;

function TCutoutAnimatorForm.GetSourceImage: string;
begin
  Result := FImageFilename;
end;

function TCutoutAnimatorForm.GetTileX: Integer;
begin
  Result := FTileX;
end;

function TCutoutAnimatorForm.GetTileY: Integer;
begin
  Result := FTileY;
end;

function TCutoutAnimatorForm.GetTileName: string;
begin
  Result := FTileName;
end;

function TCutoutAnimatorForm.GetCheckerPattern(Size: integer): TBGRABitmap;
var
  bmp: TBGRABitmap;
  x, y, cell: integer;
begin
  cell := 16;
  bmp := TBGRABitmap.Create(Size, Size);
  for x := 0 to (Size div cell) do
    for y := 0 to (Size div cell) do
      if (x + y) mod 2 = 0 then
        bmp.FillRect(Rect(x * cell, y * cell, (x + 1) * cell, (y + 1) * cell), BGRA(200, 200, 200), dmSet)
      else
        bmp.FillRect(Rect(x * cell, y * cell, (x + 1) * cell, (y + 1) * cell), BGRA(150, 150, 150), dmSet);
  Result := bmp;
end;

{ ===================================================================== }
{ Picker helper                                                          }
{ ===================================================================== }

procedure TCutoutAnimatorForm.LoadPickerFile(Picker: TSpritePickerForm;
  const APath: string);
var
  Ext: string;
begin
  if not FileExists(APath) then Exit;
  Ext := LowerCase(ExtractFileExt(APath));
  // .tileset and .json are descriptor files that LoadTileset can parse.
  // Everything else (png, jpg, bmp, gif, ...) is a plain image — call
  // SetImage to avoid the "Invalid character at line 1, pos 1" JSON
  // parse error that LoadTileset would trigger on binary image data.
  if (Ext = '.tileset') or (Ext = '.json') then
    Picker.LoadTileset(APath)
  else
    Picker.SetImage(APath);
end;

{ ===================================================================== }
{ Layers + VST setup                                                     }
{ ===================================================================== }

procedure TCutoutAnimatorForm.EnsureLayersSetup;
begin
  // Configure the layers tree (VirtualStringTree1). Three columns:
  //   0: layer name (MainColumn — tree structure renders here)
  //   1: Z index
  //   2: source image file name (basename only, for readability)
  if VirtualStringTree1 <> nil then
  begin
    VirtualStringTree1.NodeDataSize := SizeOf(Pointer);

    // Tree structure options — toShowTreeLines + toShowButtons make the VST
    // render as a tree (indentation, lines, +/- icons). Note: not all VST
    // versions have toShowRootLines, so we only use the widely-available ones.
    VirtualStringTree1.TreeOptions.PaintOptions :=
      VirtualStringTree1.TreeOptions.PaintOptions
        + [toShowRoot, toShowTreeLines, toShowButtons];
    // SelectionOptions: REPLACE the entire set (don't just add to it) so
    // that any default options that might prevent child-node focus — like
    // toLevelSelectConstraint (restricts selection to one tree level) —
    // are cleared. toFullRowSelect lets the user click anywhere on a row
    // to select it; toExtendedFocus allows focus on non-main columns too
    // (harmless but keeps VST from refusing focus for column-related
    // reasons).
    VirtualStringTree1.TreeOptions.SelectionOptions := [toFullRowSelect, toExtendedFocus];

    VirtualStringTree1.Header.Columns.Clear;
    VirtualStringTree1.Header.Columns.Add;
    VirtualStringTree1.Header.Columns[0].Text := 'Layer';
    VirtualStringTree1.Header.Columns[0].Width := 120;
    VirtualStringTree1.Header.Columns.Add;
    VirtualStringTree1.Header.Columns[1].Text := 'Ord';
    VirtualStringTree1.Header.Columns[1].Width := 40;
    VirtualStringTree1.Header.Columns.Add;
    VirtualStringTree1.Header.Columns[2].Text := 'Source image';
    VirtualStringTree1.Header.Columns[2].Width := 200;

    // CRITICAL: MainColumn must be >= 0 for tree structure to render
    VirtualStringTree1.Header.MainColumn := 0;
    VirtualStringTree1.Header.Options :=
      VirtualStringTree1.Header.Options + [hoVisible, hoColumnResize, hoAutoResize];

    // Wire VST events
    VirtualStringTree1.OnGetText        := @VirtualStringTree1GetText;
    VirtualStringTree1.OnGetNodeDataSize:= @VirtualStringTree1GetNodeDataSize;
    VirtualStringTree1.OnFocusChanged   := @VirtualStringTree1FocusChanged;
    VirtualStringTree1.OnNodeClick      := @VirtualStringTree1NodeClick;
    VirtualStringTree1.OnFreeNode       := @VirtualStringTree1FreeNode;
    VirtualStringTree1.OnChecking       := @VirtualStringTree1Checking;

    // VST native drag-and-drop (OLE-based). Do NOT set DragMode := dmAutomatic
    // — the VST handles drag initiation via OnDragAllowed.
    VirtualStringTree1.OnDragAllowed := @VirtualStringTree1DragAllowed;
    VirtualStringTree1.OnDragOver    := @VirtualStringTree1DragOver;
    VirtualStringTree1.OnDragDrop    := @VirtualStringTree1DragDrop;
  end;

  // Enable drag-and-drop reordering on the animations listbox.
  if lbAnimations <> nil then
  begin
    lbAnimations.DragMode := dmAutomatic;
    lbAnimations.OnDragOver := @lbAnimationsDragOver;
    lbAnimations.OnDragDrop := @lbAnimationsDragDrop;
  end;

  // Wire btnOK to save all animations before closing
  if btnOK <> nil then
    btnOK.OnClick := @btnOKClick;
  // Wire export buttons to the spritesheet renderer
  if btnExportSprSet <> nil then
    btnExportSprSet.OnClick := @btnExportSprSetClick;
  if btnExportMskSet <> nil then
    btnExportMskSet.OnClick := @btnExportMskSetClick;
  if btnPreviewSprite <> nil then
    btnPreviewSprite.OnClick := @btnPreviewSpriteClick;

  // Wire seAnimW/seAnimH OnChange to AnimPropChange defensively
  if seAnimW <> nil then seAnimW.OnChange := @AnimPropChange;
  if seAnimH <> nil then seAnimH.OnChange := @AnimPropChange;
  // Wire cbPVis OnClick to repaint the preview when the pivot marker
  // visibility is toggled.
  if cbPVis <> nil then cbPVis.OnClick := @cbPVisClick;
  // Wire cbBehindParent OnClick to toggle DrawBehindParent on the
  // selected layer and repaint.
  if cbBehindParent <> nil then cbBehindParent.OnClick := @cbBehindParentClick;
end;

function TCutoutAnimatorForm.CurrentAnimation: PAnimationDef;
begin
  if (FCurrentAnimIndex < 0) or (FCurrentAnimIndex >= FAnimations.Count) then
    Result := nil
  else
    Result := PAnimationDef(FAnimations[FCurrentAnimIndex]);
end;

function TCutoutAnimatorForm.CurrentFrame: PFrameDef;
var
  anim: PAnimationDef;
begin
  Result := nil;
  anim := CurrentAnimation;
  if anim = nil then Exit;
  if (FCurrentFrameIndex < 0) or (FCurrentFrameIndex >= Length(anim^.Frames)) then Exit;
  Result := @anim^.Frames[FCurrentFrameIndex];
end;

function TCutoutAnimatorForm.CurrentLayer: PLayerDef;
begin
  // FCurrentLayer is a PLayerDef pointer (heap-allocated, stable across
  // SetLength on the parent array). It can point at a top-level layer OR
  // a child layer — that's the whole point of the refactor: child layers
  // (paper-doll limbs) can be selected and edited just like top-level ones.
  Result := FCurrentLayer;
end;

function TCutoutAnimatorForm.DeleteLayerByPtr(var Arr: TLayerDynArray;
  Layer: PLayerDef): boolean;
var
  i, j: integer;
begin
  // Recursively search Arr (and each element's Children) for Layer, then
  // dispose it (and its own children) and remove it from the parent
  // array. Returns True if found+removed, False if not in this subtree.
  // Replaces the old DeleteLayer(frame, Index) which only handled
  // top-level layers — child layers (limbs pinned to a torso) need a
  // recursive search because they live inside a parent's Children[].
  Result := False;
  for i := 0 to High(Arr) do
  begin
    if Arr[i] = Layer then
    begin
      DisposeLayerRecursive(Arr[i]);
      for j := i to High(Arr) - 1 do
        Arr[j] := Arr[j + 1];
      SetLength(Arr, Length(Arr) - 1);
      Result := True;
      Exit;
    end;
    if DeleteLayerByPtr(Arr[i]^.Children, Layer) then
    begin
      Result := True;
      Exit;
    end;
  end;
end;

procedure TCutoutAnimatorForm.RefreshLayersTree;
var
  frame: PFrameDef;
begin
  if VirtualStringTree1 = nil then Exit;
  VirtualStringTree1.BeginUpdate;
  try
    VirtualStringTree1.Clear;
    frame := CurrentFrame;
    if frame = nil then Exit;
    // Resync ZIndex = position within parent's children BEFORE building
    // the VST. This ensures the "Z" column in the tree and the seZIndex
    // spin edit always show the correct position after any tree change
    // (drag-drop, add, delete). The VST order is the single source of
    // truth for draw order — ZIndex is derived, not authored.
    ResyncZIndices(frame^.Layers);
    RefreshLayersRecursive(VirtualStringTree1, nil, frame^.Layers);
  finally
    VirtualStringTree1.EndUpdate;
  end;
  // After Clear + re-add, ALL nodes are collapsed by default — child
  // layers (Arm_R, Head, Leg_R under Body) would be invisible until
  // the user manually expands each parent. FullExpand makes every
  // node visible immediately after rebuild, which is what the user
  // expects after drag-drop, new layer, or edit layer.
  // (Switching animations worked because ApplySelectedAnimation's
  //  longer call chain happened to trigger enough repaint cycles to
  //  mask the collapsed state — but that was luck, not design.)
  VirtualStringTree1.FullExpand;
  VirtualStringTree1.Invalidate;
end;

procedure TCutoutAnimatorForm.RefreshLayersRecursive(Tree: TBaseVirtualTree;
  ParentNode: PVirtualNode; var Layers: TLayerDynArray);
var
  i: integer;
  Node: PVirtualNode;
  Data: PPointer;
begin
  for i := 0 to High(Layers) do
  begin
    Node := Tree.AddChild(ParentNode);
    Data := Tree.GetNodeData(Node);
    Data^ := Layers[i];  // store the PLayerDef pointer directly
    Node^.CheckType := ctCheckBox;
    if Layers[i]^.Visible then
      Node^.CheckState := csCheckedNormal
    else
      Node^.CheckState := csUncheckedNormal;
    if Length(Layers[i]^.Children) > 0 then
      RefreshLayersRecursive(Tree, Node, Layers[i]^.Children);
  end;
end;

procedure TCutoutAnimatorForm.SelectLayer(Layer: PLayerDef);
var
  Node, Ancestor: PVirtualNode;
  Data: PPointer;
begin
  FCurrentLayer := Layer;
  if VirtualStringTree1 = nil then
  begin
    UpdateLayerControls;
    pbPreview.Invalidate;
    Exit;
  end;
  if Layer = nil then
  begin
    VirtualStringTree1.ClearSelection;
    VirtualStringTree1.FocusedNode := nil;
    UpdateLayerControls;
    pbPreview.Invalidate;
    Exit;
  end;
  // Find the VST node whose data points to this layer. Walk the tree
  // depth-first via GetFirst/GetNext (NOT GetNextSibling — that would
  // skip child nodes, which is the bug this refactor fixes: child layers
  // are the "limbs" of the paper-doll and must be selectable).
  Node := VirtualStringTree1.GetFirst;
  while Node <> nil do
  begin
    Data := VirtualStringTree1.GetNodeData(Node);
    if (Data <> nil) and (Data^ = Layer) then Break;
    Node := VirtualStringTree1.GetNext(Node);
  end;
  if Node <> nil then
  begin
    // Expand all ancestors so the focused node is actually visible.
    // Stop at RootNode — its .Parent is NOT nil in VST (self-referential
    // or internal sentinel), so a `while Ancestor <> nil` loop would
    // walk past the root into invalid memory and crash.
    Ancestor := Node^.Parent;
    while (Ancestor <> nil) and (Ancestor <> VirtualStringTree1.RootNode) do
    begin
      VirtualStringTree1.Expanded[Ancestor] := True;
      Ancestor := Ancestor^.Parent;
    end;
    VirtualStringTree1.FocusedNode := Node;
    VirtualStringTree1.Selected[Node] := True;
  end;
  // OnFocusChanged (fired by setting FocusedNode) already calls
  // UpdateLayerControls, but call it directly as a fallback for the
  // nil-VST and node-not-found cases.
  UpdateLayerControls;
  // Repaint the preview so the pivot marker follows the new selection.
  // Without this, the marker stays on the previously-selected layer
  // until something else (like toggling visibility) triggers a repaint.
  pbPreview.Invalidate;
end;

procedure TCutoutAnimatorForm.ApplyLayerEdits;
var
  layer: PLayerDef;
begin
  // Push the current seZIndex value back into the selected layer (if any).
  // Called before save so the on-screen value matches what gets persisted.
  layer := CurrentLayer;
  if layer <> nil then
    layer^.ZIndex := seZIndex.Value;
end;

{ --------------------------------------------------------------------- }
{ VirtualStringTree1 events                                             }
{ --------------------------------------------------------------------- }

procedure TCutoutAnimatorForm.VirtualStringTree1GetNodeDataSize(
  Sender: TBaseVirtualTree; var NodeDataSize: Integer);
begin
  NodeDataSize := SizeOf(Pointer);
end;

procedure TCutoutAnimatorForm.VirtualStringTree1GetText(Sender: TBaseVirtualTree;
  Node: PVirtualNode; Column: TColumnIndex; TextType: TVSTTextType;
  var CellText: String);
var
  Data: PPointer;
  layer: PLayerDef;
begin
  CellText := '';
  if Node = nil then Exit;
  Data := Sender.GetNodeData(Node);
  if (Data = nil) or (Data^ = nil) then Exit;
  layer := PLayerDef(Data^);
  case Column of
    0: CellText := layer^.Name;
    1: CellText := IntToStr(layer^.ZIndex);
    2:
      begin
        if layer^.SourceImage <> '' then
          CellText := ExtractFileName(layer^.SourceImage)
        else
          CellText := '(no image)';
      end;
  end;
end;

procedure TCutoutAnimatorForm.VirtualStringTree1FocusChanged(
  Sender: TBaseVirtualTree; Node: PVirtualNode; Column: TColumnIndex);
var
  Data: PPointer;
  layer: PLayerDef;
begin
  // Read the PLayerDef directly from the node's data slot. This is what
  // makes child layers selectable: we don't need to map the node to an
  // index into frame^.Layers[] (which only contains top-level layers),
  // we just take whatever pointer RefreshLayersRecursive stored when it
  // built the tree. That pointer is the same heap-allocated PLayerDef
  // regardless of whether the layer is a root or a great-grandchild.
  if Node = nil then
  begin
    FCurrentLayer := nil;
    UpdateLayerControls;
    pbPreview.Invalidate;
    Exit;
  end;
  Data := Sender.GetNodeData(Node);
  if (Data = nil) or (Data^ = nil) then
  begin
    FCurrentLayer := nil;
    UpdateLayerControls;
    pbPreview.Invalidate;
    Exit;
  end;
  layer := PLayerDef(Data^);
  FCurrentLayer := layer;
  UpdateLayerControls;
  pbPreview.Invalidate;
end;

procedure TCutoutAnimatorForm.VirtualStringTree1NodeClick(Sender: TBaseVirtualTree;
  const HitInfo: THitInfo);
var
  Data: PPointer;
  layer: PLayerDef;
begin
  // OnNodeClick fires for EVERY node click — parent or child — regardless
  // of VST focus/selection options. This is the reliable backup for
  // OnFocusChanged, which may not fire for child nodes if the VST has
  // restrictive SelectionOptions (e.g. toLevelSelectConstraint in some
  // default sets prevents selecting nodes at different tree levels).
  //
  // HitInfo.HitNode is the actual node the mouse landed on. We read its
  // data slot directly, same as OnFocusChanged. If the click was on a
  // child node, HitNode IS the child — no ambiguity.
  if HitInfo.HitNode = nil then Exit;
  Data := Sender.GetNodeData(HitInfo.HitNode);
  if (Data = nil) or (Data^ = nil) then Exit;
  layer := PLayerDef(Data^);
  // Only update if the clicked layer is different from the current one,
  // to avoid redundant calls. This also prevents a click-to-deselect
  // race if the user clicks the already-selected node.
  if FCurrentLayer <> layer then
  begin
    FCurrentLayer := layer;
    UpdateLayerControls;
    pbPreview.Invalidate;
  end;
end;

procedure TCutoutAnimatorForm.VirtualStringTree1FreeNode(Sender: TBaseVirtualTree;
  Node: PVirtualNode);
var
  Data: PPointer;
begin
  // The node data is just a pointer into the animation's Layers[] array —
  // we don't own the memory, so nothing to free here. Reset to nil for
  // hygiene.
  Data := Sender.GetNodeData(Node);
  if Data <> nil then Data^ := nil;
end;

procedure TCutoutAnimatorForm.VirtualStringTree1Checking(Sender: TBaseVirtualTree;
  Node: PVirtualNode; var NewState: TCheckState; var Allowed: boolean);
var
  Data: PPointer;
  layer: PLayerDef;
begin
  Allowed := True;
  Data := Sender.GetNodeData(Node);
  if (Data = nil) or (Data^ = nil) then Exit;
  layer := PLayerDef(Data^);
  layer^.Visible := (NewState = csCheckedNormal) or (NewState = csCheckedPressed);
  pbPreview.Invalidate;
end;

{ --------------------------------------------------------------------- }
{ Drag-and-drop reordering of lbAnimations                              }
{ --------------------------------------------------------------------- }

procedure TCutoutAnimatorForm.lbAnimationsDragOver(Sender, Source: TObject;
  X, Y: Integer; State: TDragState; var Accept: Boolean);
begin
  // Only accept drops coming from the listbox itself.
  Accept := (Source = lbAnimations);
end;

procedure TCutoutAnimatorForm.lbAnimationsDragDrop(Sender, Source: TObject;
  X, Y: Integer);
var
  FromIdx, ToIdx, i: integer;
  MovedPtr: Pointer;
  DropIndex: integer;
begin
  if Source <> lbAnimations then Exit;
  FromIdx := lbAnimations.ItemIndex;
  if FromIdx < 0 then Exit;

  // Compute the destination index from the drop position. ItemAtPos returns
  // -1 when dropped past the end; in that case we move to the end of the list.
  DropIndex := lbAnimations.ItemAtPos(Point(X, Y), True);
  if DropIndex < 0 then
    DropIndex := lbAnimations.Items.Count - 1;
  ToIdx := DropIndex;
  if ToIdx = FromIdx then Exit;
  if (ToIdx < 0) or (ToIdx >= FAnimations.Count) then Exit;

  // Move the animation pointer inside FAnimations.
  MovedPtr := FAnimations[FromIdx];
  FAnimations.Delete(FromIdx);
  FAnimations.Insert(ToIdx, MovedPtr);

  // Renumber RowIndex for every animation so it matches the new visual
  // order. Each animation = one row in the output spritesheet, so the
  // row order is exactly the list order.
  for i := 0 to FAnimations.Count - 1 do
    PAnimationDef(FAnimations[i])^.RowIndex := i;

  RefreshAnimationList;
  SelectAnimation(ToIdx);
end;

{ ===================================================================== }
{ Save / load .anim JSON                                                }
{ ===================================================================== }

procedure TCutoutAnimatorForm.SaveAnimationToFile(const FileName: string;
  anim: PAnimationDef);

  procedure SerializeLayers(var Arr: TLayerDynArray; out JArr: TJSONArray);
  var
    i: integer;
    LayerObj: TJSONObject;
    ChildrenArr: TJSONArray;
  begin
    JArr := TJSONArray.Create;
    for i := 0 to High(Arr) do
    begin
      LayerObj := TJSONObject.Create;
      LayerObj.Add('name',        Arr[i]^.Name);
      LayerObj.Add('visible',     Arr[i]^.Visible);
      LayerObj.Add('sourceImage', Arr[i]^.SourceImage);
      LayerObj.Add('tilesetPath', Arr[i]^.TilesetPath);
      LayerObj.Add('tileX',       Arr[i]^.TileX);
      LayerObj.Add('tileY',       Arr[i]^.TileY);
      LayerObj.Add('tileW',       Arr[i]^.TileW);
      LayerObj.Add('tileH',       Arr[i]^.TileH);
      LayerObj.Add('tileName',    Arr[i]^.TileName);
      // Per-layer transform (new in the cutout model — layers carry
      // their own OffsetX/Y/Angle/ZIndex/PivotX/Y rather than sharing
      // a per-frame TFrameTransform).
      LayerObj.Add('offsetX',     Arr[i]^.OffsetX);
      LayerObj.Add('offsetY',     Arr[i]^.OffsetY);
      LayerObj.Add('angle',       Arr[i]^.Angle);
      LayerObj.Add('zIndex',      Arr[i]^.ZIndex);
      LayerObj.Add('pivotX',      Arr[i]^.PivotX);
      LayerObj.Add('pivotY',      Arr[i]^.PivotY);
      LayerObj.Add('drawBehindParent', Arr[i]^.DrawBehindParent);
      LayerObj.Add('flipH',           Arr[i]^.FlipH);
      LayerObj.Add('flipV',           Arr[i]^.FlipV);
      if Length(Arr[i]^.Children) > 0 then
      begin
        SerializeLayers(Arr[i]^.Children, ChildrenArr);
        LayerObj.Add('children', ChildrenArr);
      end;
      JArr.Add(LayerObj);
    end;
  end;

var
  JSON, FrameObj: TJSONObject;
  FramesArr, LayersArr: TJSONArray;
  i: integer;
  SL: TStringList;
begin
  if anim = nil then Exit;
  JSON := TJSONObject.Create;
  try
    JSON.Add('name',       anim^.Name);
    JSON.Add('rowIndex',   anim^.RowIndex);
    JSON.Add('frameCount', anim^.FrameCount);
    JSON.Add('frameW',     anim^.FrameW);
    JSON.Add('frameH',     anim^.FrameH);
    JSON.Add('speedMs',    anim^.SpeedMs);
    JSON.Add('transform',  Ord(anim^.Transform));
    JSON.Add('preset',     anim^.Preset);

    // New model: serialize Frames[]. Each frame is an object with an
    // ordinal + a nested layers[] array (recursive — each layer can
    // have children, serialized by the SerializeLayers helper above).
    FramesArr := TJSONArray.Create;
    for i := 0 to High(anim^.Frames) do
    begin
      FrameObj := TJSONObject.Create;
      FrameObj.Add('ordinal', anim^.Frames[i].Ordinal);
      SerializeLayers(anim^.Frames[i].Layers, LayersArr);
      FrameObj.Add('layers', LayersArr);
      FramesArr.Add(FrameObj);
    end;
    JSON.Add('frames', FramesArr);

    SL := TStringList.Create;
    try
      SL.Text := JSON.FormatJSON;
      SL.SaveToFile(FileName);
    finally
      SL.Free;
    end;
  finally
    JSON.Free;
  end;
end;

function TCutoutAnimatorForm.LoadAnimationFromFile(const FileName: string;
  out anim: PAnimationDef): boolean;

  procedure DeserializeLayers(JArr: TJSONArray; var Arr: TLayerDynArray);
  var
    i: integer;
    ItemObj: TJSONObject;
  begin
    SetLength(Arr, JArr.Count);
    for i := 0 to JArr.Count - 1 do
    begin
      New(Arr[i]);  // heap-allocate each layer
      ItemObj := JArr.Objects[i];
      Arr[i]^.Name        := ItemObj.Get('name',        'layer_' + IntToStr(i+1));
      Arr[i]^.Visible     := ItemObj.Get('visible',     True);
      Arr[i]^.SourceImage := ItemObj.Get('sourceImage', '');
      Arr[i]^.TilesetPath := ItemObj.Get('tilesetPath', '');
      Arr[i]^.TileX       := ItemObj.Get('tileX',       0);
      Arr[i]^.TileY       := ItemObj.Get('tileY',       0);
      Arr[i]^.TileW       := ItemObj.Get('tileW',       0);
      Arr[i]^.TileH       := ItemObj.Get('tileH',       0);
      Arr[i]^.TileName    := ItemObj.Get('tileName',    '');
      // Per-layer transform (new in the cutout model). Old .anim files
      // that predate these fields will get 0/false defaults — same as a
      // freshly-created layer — so they load cleanly.
      Arr[i]^.OffsetX     := ItemObj.Get('offsetX',     0);
      Arr[i]^.OffsetY     := ItemObj.Get('offsetY',     0);
      Arr[i]^.Angle       := ItemObj.Get('angle',       0.0);
      Arr[i]^.ZIndex      := ItemObj.Get('zIndex',      0);
      Arr[i]^.PivotX      := ItemObj.Get('pivotX',      0);
      Arr[i]^.PivotY      := ItemObj.Get('pivotY',      0);
      Arr[i]^.DrawBehindParent := ItemObj.Get('drawBehindParent', False);
      Arr[i]^.FlipH            := ItemObj.Get('flipH',           False);
      Arr[i]^.FlipV            := ItemObj.Get('flipV',           False);
      // Recursively deserialize children
      if ItemObj.Find('children') <> nil then
        DeserializeLayers(ItemObj.Arrays['children'], Arr[i]^.Children)
      else
        SetLength(Arr[i]^.Children, 0);
    end;
  end;

var
  SL: TStringList;
  JSON: TJSONObject;
  FramesArr: TJSONArray;
  FrameObj: TJSONObject;
  i: integer;
begin
  Result := False;
  anim := nil;
  if not FileExists(FileName) then Exit;

  SL := TStringList.Create;
  try
    SL.LoadFromFile(FileName);
    try
      JSON := GetJSON(SL.Text) as TJSONObject;
    except
      on E: Exception do
      begin
        TDebugLogger.ErrorFmt('LoadAnimationFromFile: parse error: %s', [E.Message]);
        Exit;
      end;
    end;
    try
      New(anim);
      anim^.Name       := JSON.Get('name',       '');
      anim^.RowIndex   := JSON.Get('rowIndex',   0);
      anim^.FrameCount := JSON.Get('frameCount', 1);
      anim^.FrameW     := JSON.Get('frameW',     0);
      anim^.FrameH     := JSON.Get('frameH',     0);
      anim^.SpeedMs    := JSON.Get('speedMs',    100);
      anim^.Transform  := TTransformType(JSON.Get('transform', 0));
      anim^.Preset     := JSON.Get('preset',     '');
      if anim^.FrameCount < 1 then anim^.FrameCount := 1;

      // New model: deserialize frames[]. Each frame is an object with
      // an ordinal + a nested layers[] array (recursive — each layer
      // can have children, deserialized by the DeserializeLayers helper).
      // If a legacy .anim file has no "frames" key we fall back to a
      // single empty frame so the rest of the editor doesn't choke on
      // a zero-length Frames[] array.
      if JSON.Find('frames') <> nil then
      begin
        FramesArr := JSON.Arrays['frames'];
        SetLength(anim^.Frames, FramesArr.Count);
        for i := 0 to FramesArr.Count - 1 do
        begin
          FrameObj := FramesArr.Objects[i];
          anim^.Frames[i].Ordinal := FrameObj.Get('ordinal', i);
          if FrameObj.Find('layers') <> nil then
            DeserializeLayers(FrameObj.Arrays['layers'], anim^.Frames[i].Layers)
          else
            SetLength(anim^.Frames[i].Layers, 0);
        end;
      end
      else
      begin
        // Legacy file (no "frames" key). Synthesize one empty frame so
        // FrameCount stays consistent with the Frames[] length. The
        // user can populate it via btnNewLayer afterwards.
        SetLength(anim^.Frames, anim^.FrameCount);
        for i := 0 to High(anim^.Frames) do
        begin
          anim^.Frames[i].Ordinal := i;
          SetLength(anim^.Frames[i].Layers, 0);
        end;
      end;

      Result := True;
    finally
      JSON.Free;
    end;
  finally
    SL.Free;
    if (not Result) and (anim <> nil) then
    begin
      // MUST use DisposeAnimWithLayers, not bare Dispose(anim). If the
      // load failed AFTER DeserializeLayers allocated PLayerDef records
      // (e.g. a type mismatch on a later field), those layers are
      // already in anim^.Frames[].Layers[] — Dispose only finalizes the
      // record's managed fields, not the heap-allocated pointers inside.
      // This was the source of the "huge leak" (104 unfreed blocks).
      DisposeAnimWithLayers(anim);
      anim := nil;
    end;
  end;
end;

{ ===================================================================== }
{ Layer reordering helpers (name-based, recursive)                       }
{ ===================================================================== }

function TCutoutAnimatorForm.RemoveLayerByName(var Arr: TLayerDynArray;
  const AName: string; out Removed: PLayerDef): boolean;
var
  i, j: integer;
begin
  Result := False;
  for i := 0 to High(Arr) do
  begin
    if Arr[i]^.Name = AName then
    begin
      Removed := Arr[i];
      for j := i to High(Arr) - 1 do
        Arr[j] := Arr[j + 1];
      SetLength(Arr, Length(Arr) - 1);
      Result := True;
      Exit;
    end;
    if RemoveLayerByName(Arr[i]^.Children, AName, Removed) then
    begin
      Result := True;
      Exit;
    end;
  end;
end;

function TCutoutAnimatorForm.InsertLayerNearName(var Arr: TLayerDynArray;
  const TargetName: string; const Source: PLayerDef;
  InsertAfter: boolean): boolean;
var
  i, j: integer;
begin
  Result := False;
  for i := 0 to High(Arr) do
  begin
    if Arr[i]^.Name = TargetName then
    begin
      SetLength(Arr, Length(Arr) + 1);
      if InsertAfter then
      begin
        for j := High(Arr) downto i + 2 do
          Arr[j] := Arr[j - 1];
        Arr[i + 1] := Source;
      end
      else
      begin
        for j := High(Arr) downto i + 1 do
          Arr[j] := Arr[j - 1];
        Arr[i] := Source;
      end;
      Result := True;
      Exit;
    end;
    if InsertLayerNearName(Arr[i]^.Children, TargetName, Source, InsertAfter) then
    begin
      Result := True;
      Exit;
    end;
  end;
end;

function TCutoutAnimatorForm.AddLayerAsChildByName(var Arr: TLayerDynArray;
  const TargetName: string; const Source: PLayerDef): boolean;
var
  i, idx: integer;
begin
  Result := False;
  for i := 0 to High(Arr) do
  begin
    if Arr[i]^.Name = TargetName then
    begin
      idx := Length(Arr[i]^.Children);
      SetLength(Arr[i]^.Children, idx + 1);
      Arr[i]^.Children[idx] := Source;
      Result := True;
      Exit;
    end;
    if AddLayerAsChildByName(Arr[i]^.Children, TargetName, Source) then
    begin
      Result := True;
      Exit;
    end;
  end;
end;

// Standalone helper: check if a name exists anywhere in a layer tree
function NameExistsInTree(var Arr: TLayerDynArray; const AName: string): boolean;
var
  i: integer;
begin
  Result := False;
  for i := 0 to High(Arr) do
  begin
    if Arr[i]^.Name = AName then
    begin
      Result := True;
      Exit;
    end;
    if NameExistsInTree(Arr[i]^.Children, AName) then
    begin
      Result := True;
      Exit;
    end;
  end;
end;

function TCutoutAnimatorForm.IsDescendantOfName(var Arr: TLayerDynArray;
  const DescName, AncName: string): boolean;
var
  i: integer;
begin
  Result := False;
  for i := 0 to High(Arr) do
  begin
    if Arr[i]^.Name = AncName then
    begin
      if NameExistsInTree(Arr[i]^.Children, DescName) then
        Result := True;
      Exit;
    end;
    if IsDescendantOfName(Arr[i]^.Children, DescName, AncName) then
    begin
      Result := True;
      Exit;
    end;
  end;
end;

{ ===================================================================== }
{ VST native drag-and-drop for layer reordering + hierarchy             }
{ ===================================================================== }

procedure TCutoutAnimatorForm.VirtualStringTree1DragAllowed(
  Sender: TBaseVirtualTree; Node: PVirtualNode; Column: TColumnIndex;
  var Allowed: boolean);
begin
  // Allow dragging any layer node
  Allowed := Node <> nil;
end;

procedure TCutoutAnimatorForm.VirtualStringTree1DragOver(Sender: TBaseVirtualTree;
  Source: TObject; Shift: TShiftState; State: TDragState; const Pt: TPoint;
  Mode: TDropMode; var Effect: LongWord; var Accept: boolean);
var
  TargetNode, SourceNode: PVirtualNode;
  SourceData, TargetData: PPointer;
  SourceLayer, TargetLayer: PLayerDef;
  frame: PFrameDef;
begin
  Accept := False;
  Effect := DROPEFFECT_NONE;

  // Only accept internal drags (from the same tree)
  if Source <> Sender then Exit;

  SourceNode := Sender.GetFirstSelected;
  TargetNode := Sender.DropTargetNode;
  if (SourceNode = nil) or (TargetNode = nil) then Exit;

  // Don't drop onto self
  if SourceNode = TargetNode then Exit;

  SourceData := Sender.GetNodeData(SourceNode);
  TargetData := Sender.GetNodeData(TargetNode);
  if (SourceData = nil) or (SourceData^ = nil) then Exit;
  if (TargetData = nil) or (TargetData^ = nil) then Exit;

  SourceLayer := PLayerDef(SourceData^);
  TargetLayer := PLayerDef(TargetData^);

  // Don't drop onto own descendant (cycle prevention). In the new model
  // the layer tree lives on the current frame, so we pass frame^.Layers
  // to the recursive name-based helpers.
  frame := CurrentFrame;
  if frame = nil then Exit;
  if IsDescendantOfName(frame^.Layers, TargetLayer^.Name, SourceLayer^.Name) then
    Exit;

  Accept := True;
  Effect := DROPEFFECT_MOVE;
end;

procedure TCutoutAnimatorForm.DragRefreshTimerTimer(Sender: TObject);
var
  layer: PLayerDef;
begin
  // One-shot: disable immediately so it doesn't fire again.
  FDragRefreshTimer.Enabled := False;
  layer := FPendingDragLayer;
  FPendingDragLayer := nil;
  // By now VST has finished its OLE drag-drop cleanup, so Clear +
  // re-add works cleanly. The moved layer reappears in its new position
  // immediately, without the user having to switch animations.
  RefreshLayersTree;
  if layer <> nil then
    SelectLayer(layer);
  pbPreview.Invalidate;
end;

procedure TCutoutAnimatorForm.VirtualStringTree1DragDrop(Sender: TBaseVirtualTree;
  Source: TObject; DataObject: IDataObject; Formats: TFormatArray;
  Shift: TShiftState; const Pt: TPoint; var Effect: LongWord; Mode: TDropMode);
var
  TargetNode, SourceNode: PVirtualNode;
  SourceData, TargetData: PPointer;
  SourceLayer, TargetLayer: PLayerDef;
  frame: PFrameDef;
  SourceName, TargetName: string;
  Removed: PLayerDef;
  Done: boolean;
begin
  if (Source <> Sender) or (Effect = DROPEFFECT_NONE) then Exit;

  SourceNode := Sender.GetFirstSelected;
  TargetNode := Sender.DropTargetNode;
  if (SourceNode = nil) or (TargetNode = nil) then Exit;

  SourceData := Sender.GetNodeData(SourceNode);
  TargetData := Sender.GetNodeData(TargetNode);
  if (SourceData = nil) or (SourceData^ = nil) then Exit;
  if (TargetData = nil) or (TargetData^ = nil) then Exit;

  SourceLayer := PLayerDef(SourceData^);
  TargetLayer := PLayerDef(TargetData^);
  SourceName := SourceLayer^.Name;
  TargetName := TargetLayer^.Name;

  // Don't drop onto self
  if SourceName = TargetName then Exit;

  // In the new model the layer tree lives on the current frame, so we
  // pass frame^.Layers to the recursive name-based helpers.
  frame := CurrentFrame;
  if frame = nil then Exit;

  // Don't drop onto own descendant
  if IsDescendantOfName(frame^.Layers, TargetName, SourceName) then
  begin
    ShowMessage('Cannot move a layer into its own descendant.');
    Exit;
  end;

  // Remove source from its current location
  if not RemoveLayerByName(frame^.Layers, SourceName, Removed) then Exit;

  // Insert at new position based on Mode:
  //   dmAbove  → insert as sibling BEFORE target
  //   dmOnNode → make CHILD of target (hierarchy change)
  //   dmBelow  → insert as sibling AFTER target
  Done := False;
  case Mode of
    dmAbove:
      Done := InsertLayerNearName(frame^.Layers, TargetName, Removed, False);
    dmOnNode:
      Done := AddLayerAsChildByName(frame^.Layers, TargetName, Removed);
    dmBelow:
      Done := InsertLayerNearName(frame^.Layers, TargetName, Removed, True);
    else
      Done := False;  // unknown drop mode — fallback below
  end;

  if not Done then
  begin
    // Fallback: add to root if something went wrong
    SetLength(frame^.Layers, Length(frame^.Layers) + 1);
    frame^.Layers[High(frame^.Layers)] := Removed;
  end;

  // After the move, SourceLayer still points to the same heap-allocated
  // PLayerDef (RemoveLayerByName + Insert/AddAsChild just shuffled which
  // array slot holds the pointer, the pointer itself is unchanged). So
  // we can re-select the dragged layer in its new tree position.
  //
  // DEFER the tree rebuild: VST's OLE drag-drop is still active when
  // DragDrop fires. Calling Clear + re-add inside the handler leaves
  // the tree in a half-rendered state — the moved node disappears
  // visually even though the data is correct. By stashing the layer
  // pointer and arming a 1ms timer, the rebuild runs on the next
  // message-pump cycle, after VST has finished its drag cleanup.
  FPendingDragLayer := SourceLayer;
  FDragRefreshTimer.Enabled := True;
end;

{ ===================================================================== }
{ Save all on OK                                                         }
{ ===================================================================== }

function TCutoutAnimatorForm.EnsureAnimFilePath(anim: PAnimationDef): string;
var
  BaseDir, SafeName: string;
  i: integer;
begin
  Result := '';
  if anim = nil then Exit;
  if anim^.AnimFilePath <> '' then
  begin
    Result := anim^.AnimFilePath;
    Exit;
  end;
  // Build a default path from AnimBasePath + Name + '.anim'
  BaseDir := FAnimBasePath;
  if BaseDir = '' then BaseDir := ExtractFilePath(ParamStr(0));
  if (BaseDir <> '') and (BaseDir[Length(BaseDir)] <> PathDelim) then
    BaseDir := BaseDir + PathDelim;
  SafeName := anim^.Name;
  // Sanitize: replace invalid filename chars
  for i := 1 to Length(SafeName) do
    if Pos(SafeName[i], '<>:"/\|?*') > 0 then
      SafeName[i] := '_';
  Result := BaseDir + SafeName + '.anim';
  anim^.AnimFilePath := Result;
end;

procedure TCutoutAnimatorForm.SaveAllAnimationsToFiles;
var
  i: integer;
  anim: PAnimationDef;
  Path: string;
begin
  // Called from btnOKClick. Save every animation to its .anim file.
  // Debug-log each save as requested by the user.
  for i := 0 to FAnimations.Count - 1 do
  begin
    anim := PAnimationDef(FAnimations[i]);
    ApplyCurrentTransform;
    Path := EnsureAnimFilePath(anim);
    try
      SaveAnimationToFile(Path, anim);
      TDebugLogger.DebugFmt('Saved animation "%s" to %s',
        [anim^.Name, Path], {$I %CURRENTROUTINE%}, {$I %FILE%}, {$I %lineNum%});
    except
      on E: Exception do
        TDebugLogger.ErrorFmt('Failed to save animation "%s" to %s: %s',
          [anim^.Name, Path, E.Message]);
    end;
  end;
end;

procedure TCutoutAnimatorForm.btnOKClick(Sender: TObject);
begin
  // Save every animation to its .anim file. In plugin mode (default),
  // close the dialog with mrOk so EditAction can read back the data.
  // In standalone mode, just save — the user stays in the editor.
  SaveAllAnimationsToFiles;
  if not FStandalone then
    ModalResult := mrOk;
end;

procedure TCutoutAnimatorForm.btnExportSprSetClick(Sender: TObject);
var
  SD: TSaveDialog;
  info: TSpritesheetInfo;
  sheetBmp: TBGRABitmap;
  basePath: string;
begin
  // Export full spritesheet (all layers composited) as PNG + .spritesheet JSON.
  // Each animation = one row (by RowIndex), each frame = one column.
  if FAnimations.Count = 0 then
  begin
    ShowMessage('No animations to export.');
    Exit;
  end;

  SD := TSaveDialog.Create(Self);
  try
    SD.Title := 'Export spritesheet';
    SD.Filter := 'Spritesheet PNG|*.png|All files|*.*';
    SD.DefaultExt := 'png';
    SD.FileName := 'spritesheet';
    if not SD.Execute then Exit;
    basePath := ChangeFileExt(SD.FileName, '');  // strip extension

    sheetBmp := RenderSpritesheet(FAnimations, rmFull,
      '', 0, 0, 0, 0, info);
    try
      SaveSpritesheet(basePath, sheetBmp, info);
      ShowMessage(Format('Exported %d animations (%dx%d sheet) to:'#10'%s.png'#10'%s.spritesheet',
        [Length(info.Animations), info.SheetW, info.SheetH, basePath, basePath]));
    finally
      sheetBmp.Free;
    end;
  finally
    SD.Free;
  end;
end;

procedure TCutoutAnimatorForm.btnExportMskSetClick(Sender: TObject);
var
  SD: TSaveDialog;
  info: TSpritesheetInfo;
  sheetBmp: TBGRABitmap;
  basePath: string;
  iconSource: string;
  iconTX, iconTY, iconTW, iconTH: integer;
begin
  // Export "action icon" spritesheet — render only the layer(s) matching
  // the action icon's tile, masked by overlapping layers on top. Useful
  // for generating item sprites that show only the item, cut out where
  // other layers cover it.
  //
  // The action icon is the tile currently loaded via SetTilesetTile
  // (stored in FImageFilename / FTileX/Y / FTileWidth/Height).
  if FAnimations.Count = 0 then
  begin
    ShowMessage('No animations to export.');
    Exit;
  end;

  iconSource := FImageFilename;
  iconTX := FTileX;
  iconTY := FTileY;
  iconTW := FTileWidth;
  iconTH := FTileHeight;
  if (iconSource = '') or (iconTW <= 0) or (iconTH <= 0) then
  begin
    ShowMessage('No action icon tile loaded. Use Browse or Edit to load a tile first.');
    Exit;
  end;

  SD := TSaveDialog.Create(Self);
  try
    SD.Title := 'Export action-icon spritesheet';
    SD.Filter := 'Spritesheet PNG|*.png|All files|*.*';
    SD.DefaultExt := 'png';
    SD.FileName := 'icon_spritesheet';
    if not SD.Execute then Exit;
    basePath := ChangeFileExt(SD.FileName, '');

    sheetBmp := RenderSpritesheet(FAnimations, rmActionIcon,
      iconSource, iconTX, iconTY, iconTW, iconTH, info);
    try
      SaveSpritesheet(basePath, sheetBmp, info);
      ShowMessage(Format('Exported %d animations (%dx%d sheet) to:'#10'%s.png'#10'%s.spritesheet',
        [Length(info.Animations), info.SheetW, info.SheetH, basePath, basePath]));
    finally
      sheetBmp.Free;
    end;
  finally
    SD.Free;
  end;
end;

procedure TCutoutAnimatorForm.btnPreviewSpriteClick(Sender: TObject);
var
  SD: TSaveDialog;
  info: TSpritesheetInfo;
  sheetBmp: TBGRABitmap;
  basePath: string;
  dlg: TSpritesheetDialog;
  tempPath: string;
begin
  // Export a full spritesheet to a temp location, then open the
  // spritesheet dialog to preview/play it. This lets the user verify
  // the export looks right before committing to a final path.
  //
  // We render to the system temp dir so we don't litter the project
  // folder with preview files. The dialog loads the PNG + JSON from
  // there and lets the user step through frames / play the animation.
  if FAnimations.Count = 0 then
  begin
    ShowMessage('No animations to preview.');
    Exit;
  end;

  // Render to temp
  tempPath := GetTempDir + PathDelim + 'cutout_preview';
  sheetBmp := RenderSpritesheet(FAnimations, rmFull,
    '', 0, 0, 0, 0, info);
  try
    SaveSpritesheet(tempPath, sheetBmp, info);
  finally
    sheetBmp.Free;
  end;

  // Open the dialog on the temp spritesheet
  dlg := TSpritesheetDialog.Create(Self);
  try
    dlg.LoadSpritesheet(tempPath);
    dlg.ShowModal;
  finally
    dlg.Free;
  end;
end;

end.
