unit uSpritesheetDialog;

{$mode objfpc}{$H+}

interface

// =====================================================================
// uSpritesheetDialog — Preview/play spritesheets exported by uCutoutRenderer
// =====================================================================
//
// Adapted from the old "tile grid" model to the new tightly-packed
// spritesheet format. Each animation has its own FrameW/FrameH and
// RowY (Y offset in the sheet). Frames are at (col * FrameW, RowY).
//
// Usage:
//   dlg := TSpritesheetDialog.Create(Self);
//   dlg.LoadSpritesheet('path_without_extension');
//   dlg.ShowModal;
//   dlg.Free;
//
// The dialog reads the .png + .spritesheet JSON, populates the
// animation list, and lets the user step through frames or play
// the animation at the recorded speed.

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, ExtCtrls, StdCtrls,
  Spin, ComCtrls, BGRABitmap, BGRABitmapTypes, uDebugLog, fpjson, jsonparser;

type
  TBackgroundStyle = (bgSolid, bgChecker);

  // Per-animation metadata (mirrors uCutoutRenderer.TSpritesheetAnim)
  TSheetAnim = record
    Name: string;
    Row: integer;
    FrameCount: integer;
    FrameW: integer;
    FrameH: integer;
    SpeedMs: integer;
    RowY: integer;
    FrameX: integer;
  end;
  PSheetAnim = ^TSheetAnim;

  { TSpritesheetDialog }

  TSpritesheetDialog = class(TForm)
    gbData: TGroupBox;
    gbPreview: TGroupBox;
    Label1: TLabel;
    Label14: TLabel;
    Label2: TLabel;
    Label3: TLabel;
    Label5: TLabel;
    Label6: TLabel;

    lblAction: TLabel;
    edAction: TEdit;
    edImage: TEdit;
    lblAnimName: TLabel;
    seTileW: TSpinEdit;
    seTileH: TSpinEdit;
    btnOK: TButton;
    btnCancel: TButton;
    btnBrowse: TButton;

    pbPreview: TPaintBox;
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
    Zoom: TLabel;

    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);

    procedure btnBrowseClick(Sender: TObject);
    procedure btnRefreshClick(Sender: TObject);
    procedure btnPlayClick(Sender: TObject);

    procedure pbPreviewPaint(Sender: TObject);

    procedure UpdatePreview;
    procedure LoadAnimations(AnimList: TList);
    procedure GetAnimations(AnimList: TList);

    procedure tbZoomChange(Sender: TObject);
    procedure cbBackgroundChange(Sender: TObject);
    procedure btnAddAnimClick(Sender: TObject);
    procedure btnDeleteAnimClick(Sender: TObject);
    procedure lbAnimationsClick(Sender: TObject);
    procedure AnimPropChange(Sender: TObject);
    procedure tbFrameChange(Sender: TObject);
    procedure seFrameChange(Sender: TObject);
    procedure TimerTimer(Sender: TObject);
    procedure tbSpeedChange(Sender: TObject);

  private
    FBitmap: TBGRABitmap;       // the full spritesheet PNG
    FCurrentFrame: TBGRABitmap; // extracted current frame
    FAnimations: TList;         // list of PSheetAnim
    FCurrentAnimIndex: integer;
    FCurrentFrameIndex: integer;
    FPlaying: boolean;
    FUpdating: boolean;
    FZoom: double;
    FBackground: TBackgroundStyle;
    FSheetPath: string;         // base path (no extension) of loaded sheet

    procedure UpdateFrame;
    procedure UpdateZoom;
    function GetCheckerPattern(Size: integer): TBGRABitmap;
    procedure SetFrameValue(AIndex: integer);
    procedure RefreshAnimationList;
    procedure SelectAnimation(Index: integer);
    procedure ApplySelectedAnimation;
    procedure UpdatePreviewFromAnimation;
    procedure ClearAnimations(List: TList);
  public
    // Load a tightly-packed spritesheet (PNG + .spritesheet JSON).
    // basePath = full path WITHOUT extension.
    procedure LoadSpritesheet(const basePath: string);
  end;

implementation

{$R *.frm}

procedure TSpritesheetDialog.FormCreate(Sender: TObject);
begin
  Caption := 'Spritesheet Preview';
  Position := poMainFormCenter;
  FAnimations := TList.Create;
  FBitmap := nil;
  FCurrentFrame := nil;
  FCurrentAnimIndex := -1;
  FCurrentFrameIndex := 0;
  FZoom := 1.0;
  FBackground := bgChecker;
  FPlaying := False;
  FUpdating := False;
  // Disable tile size edits — frame size comes from the JSON per
  // animation, not from a global tile size.
  seTileW.Enabled := False;
  seTileH.Enabled := False;
  btnBrowse.Enabled := False;  // loading is via LoadSpritesheet
end;

procedure TSpritesheetDialog.FormDestroy(Sender: TObject);
begin
  Timer.Enabled := False;
  FBitmap.Free;
  FCurrentFrame.Free;
  ClearAnimations(FAnimations);
  FAnimations.Free;
end;

procedure TSpritesheetDialog.btnBrowseClick(Sender: TObject);
begin
  // Disabled in the new model — loading is via LoadSpritesheet.
end;

procedure TSpritesheetDialog.btnRefreshClick(Sender: TObject);
begin
  pbPreview.Invalidate;
end;

// ---------------------------------------------------------------------
// LoadSpritesheet — read PNG + JSON, populate animation list
// ---------------------------------------------------------------------

procedure TSpritesheetDialog.LoadSpritesheet(const basePath: string);
var
  PNGPath, JSONPath: string;
  SL: TStringList;
  JSON: TJSONObject;
  AnimsArr: TJSONArray;
  i: integer;
  AnimObj: TJSONObject;
  anim: PSheetAnim;
begin
  FSheetPath := basePath;
  PNGPath := basePath + '.png';
  JSONPath := basePath + '.spritesheet';

  if not FileExists(PNGPath) then
  begin
    ShowMessage('Spritesheet PNG not found: ' + PNGPath);
    Exit;
  end;
  if not FileExists(JSONPath) then
  begin
    ShowMessage('Spritesheet metadata not found: ' + JSONPath);
    Exit;
  end;

  // Load PNG
  FBitmap.Free;
  try
    FBitmap := TBGRABitmap.Create(PNGPath);
  except
    on E: Exception do
    begin
      ShowMessage('Failed to load PNG: ' + E.Message);
      Exit;
    end;
  end;

  edImage.Text := PNGPath;

  // Load JSON metadata
  ClearAnimations(FAnimations);
  SL := TStringList.Create;
  try
    SL.LoadFromFile(JSONPath);
    JSON := GetJSON(SL.Text) as TJSONObject;
    try
      AnimsArr := JSON.Arrays['animations'];
      for i := 0 to AnimsArr.Count - 1 do
      begin
        AnimObj := AnimsArr.Objects[i];
        New(anim);
        anim^.Name       := AnimObj.Get('name', 'anim_' + IntToStr(i));
        anim^.Row        := AnimObj.Get('row', i);
        anim^.FrameCount := AnimObj.Get('frameCount', 1);
        anim^.FrameW     := AnimObj.Get('frameW', 64);
        anim^.FrameH     := AnimObj.Get('frameH', 64);
        anim^.SpeedMs    := AnimObj.Get('speedMs', 100);
        anim^.RowY       := AnimObj.Get('rowY', 0);
        anim^.FrameX     := AnimObj.Get('frameX', 0);
        FAnimations.Add(anim);
      end;
    finally
      JSON.Free;
    end;
  finally
    SL.Free;
  end;

  RefreshAnimationList;
  if FAnimations.Count > 0 then
    SelectAnimation(0);
end;

// ---------------------------------------------------------------------
// Animation list management
// ---------------------------------------------------------------------

procedure TSpritesheetDialog.ClearAnimations(List: TList);
var
  i: integer;
begin
  for i := 0 to List.Count - 1 do
    Dispose(PSheetAnim(List[i]));
  List.Clear;
end;

procedure TSpritesheetDialog.RefreshAnimationList;
var
  i: integer;
  anim: PSheetAnim;
begin
  lbAnimations.Clear;
  for i := 0 to FAnimations.Count - 1 do
  begin
    anim := PSheetAnim(FAnimations[i]);
    lbAnimations.Items.Add(Format('%s (row %d, %d frames, %dx%d)',
      [anim^.Name, anim^.Row, anim^.FrameCount, anim^.FrameW, anim^.FrameH]));
  end;
end;

procedure TSpritesheetDialog.SelectAnimation(Index: integer);
begin
  if (Index < 0) or (Index >= FAnimations.Count) then Exit;
  FCurrentAnimIndex := Index;
  ApplySelectedAnimation;
  lbAnimations.ItemIndex := Index;
end;

procedure TSpritesheetDialog.ApplySelectedAnimation;
var
  anim: PSheetAnim;
begin
  if (FCurrentAnimIndex < 0) or (FCurrentAnimIndex >= FAnimations.Count) then Exit;
  anim := PSheetAnim(FAnimations[FCurrentAnimIndex]);
  FUpdating := True;
  try
    edAnimName.Text := anim^.Name;
    seAnimRow.Value := anim^.Row;
    seAnimFrameCount.Value := anim^.FrameCount;
    seAnimSpeed.Value := anim^.SpeedMs;
    // Show this animation's frame size in the (disabled) tile edits
    seTileW.Value := anim^.FrameW;
    seTileH.Value := anim^.FrameH;
    tbSpeed.Position := anim^.SpeedMs;
    tbFrame.Max := anim^.FrameCount - 1;
    seFrame.MaxValue := anim^.FrameCount - 1;
    lblTotalFrames.Caption := Format('/%d', [anim^.FrameCount]);
    FCurrentFrameIndex := 0;
    SetFrameValue(0);
  finally
    FUpdating := False;
  end;
  UpdatePreviewFromAnimation;
end;

procedure TSpritesheetDialog.UpdatePreviewFromAnimation;
begin
  UpdateFrame;
end;

// ---------------------------------------------------------------------
// Frame extraction
// ---------------------------------------------------------------------

procedure TSpritesheetDialog.UpdateFrame;
var
  anim: PSheetAnim;
  x, y: integer;
begin
  if (FBitmap = nil) or (FCurrentAnimIndex < 0) then Exit;
  anim := PSheetAnim(FAnimations[FCurrentAnimIndex]);
  if (anim^.FrameW <= 0) or (anim^.FrameH <= 0) then Exit;
  if FCurrentFrameIndex >= anim^.FrameCount then
    FCurrentFrameIndex := anim^.FrameCount - 1;
  // Tightly-packed: frame j at (j * FrameW + FrameX, RowY)
  x := FCurrentFrameIndex * anim^.FrameW + anim^.FrameX;
  y := anim^.RowY;
  if (x + anim^.FrameW > FBitmap.Width) or
     (y + anim^.FrameH > FBitmap.Height) then Exit;
  FCurrentFrame.Free;
  FCurrentFrame := FBitmap.GetPart(Rect(x, y, x + anim^.FrameW, y + anim^.FrameH)) as TBGRABitmap;
  UpdateZoom;
  pbPreview.Invalidate;
end;

procedure TSpritesheetDialog.SetFrameValue(AIndex: integer);
begin
  if FUpdating then Exit;
  FUpdating := True;
  try
    if FCurrentAnimIndex >= 0 then
    begin
      FCurrentFrameIndex := AIndex;
      seFrame.Value := AIndex;
      tbFrame.Position := AIndex;
      UpdateFrame;
    end;
  finally
    FUpdating := False;
  end;
end;

// ---------------------------------------------------------------------
// Preview painting
// ---------------------------------------------------------------------

procedure TSpritesheetDialog.pbPreviewPaint(Sender: TObject);
var
  destRect: TRect;
  bgBmp: TBGRABitmap;
  scaledBmp: TBGRABitmap;
  drawW, drawH: integer;
begin
  destRect := pbPreview.ClientRect;
  // Background
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
  if FCurrentFrame = nil then Exit;
  // Scale frame by FZoom, center in the paintbox
  drawW := Round(FCurrentFrame.Width * FZoom);
  drawH := Round(FCurrentFrame.Height * FZoom);
  if drawW <= 0 then drawW := 1;
  if drawH <= 0 then drawH := 1;
  if (drawW = FCurrentFrame.Width) and (drawH = FCurrentFrame.Height) then
    FCurrentFrame.Draw(pbPreview.Canvas,
      (destRect.Width - drawW) div 2, (destRect.Height - drawH) div 2, False)
  else
  begin
    scaledBmp := FCurrentFrame.Resample(drawW, drawH) as TBGRABitmap;
    try
      scaledBmp.Draw(pbPreview.Canvas,
        (destRect.Width - drawW) div 2, (destRect.Height - drawH) div 2, False);
    finally
      scaledBmp.Free;
    end;
  end;
end;

procedure TSpritesheetDialog.UpdateZoom;
begin
  pbPreview.Invalidate;
end;

// ---------------------------------------------------------------------
// Event handlers
// ---------------------------------------------------------------------

procedure TSpritesheetDialog.btnAddAnimClick(Sender: TObject);
begin
  // Adding animations in the preview dialog is not meaningful —
  // animations come from the cutout animator. Disable.
end;

procedure TSpritesheetDialog.btnDeleteAnimClick(Sender: TObject);
begin
  // Same — deleting animations here would desync from the source.
end;

procedure TSpritesheetDialog.lbAnimationsClick(Sender: TObject);
begin
  if FUpdating then Exit;
  SelectAnimation(lbAnimations.ItemIndex);
end;

procedure TSpritesheetDialog.AnimPropChange(Sender: TObject);
var
  anim: PSheetAnim;
begin
  if FUpdating or (FCurrentAnimIndex < 0) then Exit;
  anim := PSheetAnim(FAnimations[FCurrentAnimIndex]);
  anim^.Name := edAnimName.Text;
  anim^.Row := seAnimRow.Value;
  anim^.FrameCount := seAnimFrameCount.Value;
  if anim^.FrameCount < 1 then anim^.FrameCount := 1;
  anim^.SpeedMs := seAnimSpeed.Value;
  if anim^.SpeedMs < 20 then anim^.SpeedMs := 20;
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
end;

procedure TSpritesheetDialog.tbFrameChange(Sender: TObject);
begin
  if FUpdating then Exit;
  if FPlaying then btnPlayClick(nil);
  SetFrameValue(tbFrame.Position);
end;

procedure TSpritesheetDialog.seFrameChange(Sender: TObject);
begin
  if FUpdating then Exit;
  if FPlaying then btnPlayClick(nil);
  SetFrameValue(seFrame.Value);
end;

procedure TSpritesheetDialog.btnPlayClick(Sender: TObject);
begin
  FPlaying := not FPlaying;
  if FPlaying then
  begin
    btnPlay.Caption := 'Stop';
    if FCurrentAnimIndex >= 0 then
      Timer.Interval := PSheetAnim(FAnimations[FCurrentAnimIndex])^.SpeedMs
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

procedure TSpritesheetDialog.TimerTimer(Sender: TObject);
var
  NextIndex: integer;
  anim: PSheetAnim;
begin
  if FCurrentAnimIndex < 0 then Exit;
  anim := PSheetAnim(FAnimations[FCurrentAnimIndex]);
  NextIndex := (FCurrentFrameIndex + 1) mod anim^.FrameCount;
  SetFrameValue(NextIndex);
end;

procedure TSpritesheetDialog.tbSpeedChange(Sender: TObject);
begin
  lblSpeed.Caption := Format('%dms', [tbSpeed.Position]);
  if FPlaying then
    Timer.Interval := tbSpeed.Position
  else if FCurrentAnimIndex >= 0 then
    PSheetAnim(FAnimations[FCurrentAnimIndex])^.SpeedMs := tbSpeed.Position;
end;

procedure TSpritesheetDialog.tbZoomChange(Sender: TObject);
begin
  FZoom := tbZoom.Position / 100;
  lblZoom.Caption := Format('%d%%', [tbZoom.Position]);
  pbPreview.Invalidate;
end;

procedure TSpritesheetDialog.cbBackgroundChange(Sender: TObject);
begin
  if cbBackground.ItemIndex = 0 then
    FBackground := bgSolid
  else
    FBackground := bgChecker;
  pbPreview.Invalidate;
end;

// ---------------------------------------------------------------------
// Legacy LoadAnimations / GetAnimations (kept for API compat, unused
// in the new tightly-packed model — LoadSpritesheet replaces them)
// ---------------------------------------------------------------------

procedure TSpritesheetDialog.LoadAnimations(AnimList: TList);
begin
  // No-op in the new model. Use LoadSpritesheet instead.
end;

procedure TSpritesheetDialog.GetAnimations(AnimList: TList);
begin
  // No-op in the new model.
end;

procedure TSpritesheetDialog.UpdatePreview;
begin
  pbPreview.Invalidate;
end;

// ---------------------------------------------------------------------
// Checker background
// ---------------------------------------------------------------------

function TSpritesheetDialog.GetCheckerPattern(Size: integer): TBGRABitmap;
var
  bmp: TBGRABitmap;
  x, y, cell: integer;
begin
  cell := 16;
  bmp := TBGRABitmap.Create(Size, Size);
  for x := 0 to (Size div cell) do
    for y := 0 to (Size div cell) do
      if (x + y) mod 2 = 0 then
        bmp.FillRect(Rect(x * cell, y * cell, (x + 1) * cell, (y + 1) * cell),
          BGRA(200, 200, 200), dmSet)
      else
        bmp.FillRect(Rect(x * cell, y * cell, (x + 1) * cell, (y + 1) * cell),
          BGRA(150, 150, 150), dmSet);
  Result := bmp;
end;

end.
