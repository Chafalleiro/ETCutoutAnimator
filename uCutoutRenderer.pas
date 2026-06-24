unit uCutoutRenderer;

{$mode objfpc}{$H+}

interface

// =====================================================================
// uCutoutRenderer — Portable cutout animation → spritesheet renderer
// =====================================================================
//
// This unit is intentionally independent of TCutoutAnimatorForm and
// VirtualTrees. It works directly with PAnimationDef / PFrameDef /
// PLayerDef (from uCutoutAnimator) and TBGRABitmap, so it can be
// compiled into the game runtime without pulling in the editor form.
//
// For full engine-agnostic portability, the type definitions
// (TLayerDef, TFrameDef, TAnimationDef) should eventually be extracted
// to a separate uCutoutTypes unit. Until then, this unit only uses
// uCutoutAnimator for its types — no form methods are called.
//
// Two render modes:
//   rmFull        — composite ALL layers (the complete character/effect)
//   rmActionIcon  — render only the layer(s) matching the action icon's
//                   source image + tile coords, masked by overlapping
//                   layers drawn on top. Useful for generating item
//                   sprites that show only the item, cut out where
//                   other layers (hands, equipment) cover it.
//
// Spritesheet layout:
//   - One row per animation (sorted by RowIndex)
//   - One column per frame (left to right, frame 0..N-1)
//   - Cell size = max(FrameW, FrameH) across all animations
//   - Each frame centered in its cell
//   - JSON metadata records actual frame size, count, speed, and
//     centering offset per animation

uses
  Classes, SysUtils, BGRABitmap, BGRABitmapTypes, Types, Math,
  uCutoutAnimator;

type
  TRenderMode = (rmFull, rmActionIcon);

  // Per-animation metadata stored in the .spritesheet JSON
  TSpritesheetAnim = record
    Name: string;
    Row: integer;           // row index in the spritesheet (0-based)
    FrameCount: integer;
    FrameW: integer;        // this animation's frame width (pixels)
    FrameH: integer;        // this animation's frame height (pixels)
    SpeedMs: integer;       // milliseconds per frame
    RowY: integer;          // Y offset of this row in the sheet (pixels)
    FrameX: integer;        // X offset of first frame (always 0, kept for clarity)
  end;

  // Overall spritesheet metadata. Tightly-packed layout: each animation
  // occupies one row, frames placed edge-to-edge at (col * FrameW, RowY).
  // Different animations can have different FrameW/FrameH — the sheet
  // width = max(FrameW * FrameCount) across all animations, height =
  // sum of all FrameH. The reader uses per-animation FrameW/H + RowY
  // to locate frames, like reading a fixed-stride sequential file.
  TSpritesheetInfo = record
    CellW: integer;         // kept for compatibility (max frameW)
    CellH: integer;         // kept for compatibility (max frameH)
    Columns: integer;       // max frame count across all animations
    Rows: integer;          // number of animation rows
    SheetW: integer;        // total bitmap width
    SheetH: integer;        // total bitmap height
    Animations: array of TSpritesheetAnim;
  end;

// Render a single frame to a bitmap of the given size.
//   anim       — the animation containing the frame
//   frameIdx   — which frame to render (0-based)
//   outW/H     — output bitmap dimensions (frame is centered)
//   mode       — rmFull (all layers) or rmActionIcon (icon only, masked)
//   iconSource — source image path of the action icon (rmActionIcon only)
//   iconTileX/Y/W/H — tile coords within iconSource (rmActionIcon only)
// A layer "is the icon" if its SourceImage matches iconSource AND its
// TileX/Y/W/H match iconTileX/Y/W/H. Returns a new TBGRABitmap (caller frees).
function RenderFrame(anim: PAnimationDef; frameIdx: integer;
  outW, outH: integer; mode: TRenderMode;
  const iconSource: string;
  iconTileX, iconTileY, iconTileW, iconTileH: integer): TBGRABitmap;

// Render all animations into a single spritesheet bitmap.
//   animations — TList of PAnimationDef (one per animation)
//   mode       — rmFull or rmActionIcon
//   iconSource / iconTileX/Y/W/H — icon identification (rmActionIcon only)
//   info       — receives metadata for the .spritesheet JSON
// Returns a new TBGRABitmap (caller frees).
function RenderSpritesheet(animations: TList; mode: TRenderMode;
  const iconSource: string;
  iconTileX, iconTileY, iconTileW, iconTileH: integer;
  out info: TSpritesheetInfo): TBGRABitmap;

// Save a spritesheet bitmap (PNG) + metadata (JSON) to disk.
//   basePath — full path WITHOUT extension; ".png" and ".spritesheet" are appended
procedure SaveSpritesheet(const basePath: string;
  bmp: TBGRABitmap; const info: TSpritesheetInfo);

implementation

uses
  fpjson, jsonparser;

type
  // Flat render entry — one per visible layer, in draw order.
  // Carries the accumulated transform from the ancestor chain.
  TRenderEntry = record
    Layer: PLayerDef;
    AccX: double;          // layer center in frame coords
    AccY: double;
    AccAngle: double;      // accumulated rotation (degrees)
    AccPivotX: double;     // pivot in frame coords
    AccPivotY: double;
  end;
  TRenderArray = array of TRenderEntry;

// ---------------------------------------------------------------------
// Transform accumulation (extracted from pbPreviewPaint's
// CollectLayerWithDepth — same logic, standalone, no editor deps)
// ---------------------------------------------------------------------

procedure CollectLayerWithDepth(L: PLayerDef;
  ParentAccX, ParentAccY: double;
  ParentAngle: double;
  ParentPivotX, ParentPivotY: double;
  ParentVisible: boolean;
  var entries: TRenderArray);
var
  accAngle: double;
  effVisible: boolean;
  c: integer;
  CL: PLayerDef;
  accX, accY: double;
  pivLocalX, pivLocalY: double;
  pivFrameX, pivFrameY: double;
  rad, cosA, sinA: double;
  rotOffX, rotOffY: double;
begin
  if L = nil then Exit;
  accAngle := ParentAngle + L^.Angle;
  effVisible := ParentVisible and L^.Visible;

  // Compute layer center in frame coords.
  // Root: simple addition. Child: swing around parent's pivot.
  if ParentAngle = 0 then
  begin
    accX := ParentAccX + L^.OffsetX;
    accY := ParentAccY + L^.OffsetY;
  end
  else
  begin
    rad := ParentAngle * Pi / 180.0;
    cosA := Cos(rad);
    sinA := Sin(rad);
    rotOffX := (ParentAccX + L^.OffsetX) - ParentPivotX;
    rotOffY := (ParentAccY + L^.OffsetY) - ParentPivotY;
    accX := ParentPivotX + (rotOffX * cosA - rotOffY * sinA);
    accY := ParentPivotY + (rotOffX * sinA + rotOffY * cosA);
  end;

  // Compute pivot in frame coords (using PARENT angle, not accAngle —
  // the pivot is the fixed point the layer rotates AROUND, so it's
  // computed before the layer's own rotation).
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
      CollectLayerWithDepth(CL, accX, accY, accAngle, pivFrameX, pivFrameY,
        effVisible, entries);
  end;

  // 2. L itself
  if effVisible and (L^.SourceImage <> '') and
     (L^.TileW > 0) and (L^.TileH > 0) and
     FileExists(L^.SourceImage) then
  begin
    SetLength(entries, Length(entries) + 1);
    entries[High(entries)].Layer := L;
    entries[High(entries)].AccX := accX;
    entries[High(entries)].AccY := accY;
    entries[High(entries)].AccAngle := accAngle;
    entries[High(entries)].AccPivotX := pivFrameX;
    entries[High(entries)].AccPivotY := pivFrameY;
  end;

  // 3. In-front children
  for c := 0 to High(L^.Children) do
  begin
    CL := L^.Children[c];
    if (CL <> nil) and not CL^.DrawBehindParent then
      CollectLayerWithDepth(CL, accX, accY, accAngle, pivFrameX, pivFrameY,
        effVisible, entries);
  end;
end;

function CollectEntries(frame: PFrameDef): TRenderArray;
var
  k: integer;
begin
  Result := nil;
  if frame = nil then Exit;
  for k := 0 to High(frame^.Layers) do
    CollectLayerWithDepth(frame^.Layers[k], 0, 0, 0, 0, 0, True, Result);
end;

// ---------------------------------------------------------------------
// Check if a layer matches the action icon
// ---------------------------------------------------------------------

function IsIconLayer(L: PLayerDef;
  const iconSource: string;
  iconTileX, iconTileY, iconTileW, iconTileH: integer): boolean;
begin
  Result := (L^.SourceImage = iconSource) and
            (L^.TileX = iconTileX) and
            (L^.TileY = iconTileY) and
            (L^.TileW = iconTileW) and
            (L^.TileH = iconTileH);
end;

// ---------------------------------------------------------------------
// Draw a single layer onto a canvas at the given frame center
// ---------------------------------------------------------------------

procedure DrawLayer(canvas: TBGRABitmap; entry: TRenderEntry;
  centerX, centerY: integer; zoom: double);
var
  L: PLayerDef;
  srcBmp, tileBmp, scaledBmp, flippedBmp, rotatedBmp: TBGRABitmap;
  ownScaledBmp: boolean;
  drawW, drawH: integer;
  drawX, drawY: integer;
  rad: double;
  localPivX, localPivY: double;
  newW, newH: integer;
begin
  L := entry.Layer;
  try
    srcBmp := TBGRABitmap.Create(L^.SourceImage);
  except
    Exit;
  end;
  try
    if (L^.TileX < 0) or (L^.TileY < 0) then Exit;
    if (L^.TileX + L^.TileW > srcBmp.Width) or
       (L^.TileY + L^.TileH > srcBmp.Height) then Exit;

    tileBmp := srcBmp.GetPart(Rect(L^.TileX, L^.TileY,
      L^.TileX + L^.TileW, L^.TileY + L^.TileH)) as TBGRABitmap;
    try
      drawW := Round(tileBmp.Width * zoom);
      drawH := Round(tileBmp.Height * zoom);
      if drawW <= 0 then drawW := 1;
      if drawH <= 0 then drawH := 1;

      // Step 1: scale
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
        // Step 2: flip
        if L^.FlipH or L^.FlipV then
        begin
          flippedBmp := TBGRABitmap.Create(scaledBmp.Width, scaledBmp.Height);
          flippedBmp.PutImage(0, 0, scaledBmp, dmSet);
          if L^.FlipH then flippedBmp.HorizontalFlip;
          if L^.FlipV then flippedBmp.VerticalFlip;
          if ownScaledBmp then scaledBmp.Free;
          scaledBmp := flippedBmp;
          ownScaledBmp := True;
        end;

        // Step 3: rotate + blit
        if Abs(entry.AccAngle) < 0.01 then
        begin
          drawX := centerX + Round(entry.AccX * zoom) - drawW div 2;
          drawY := centerY + Round(entry.AccY * zoom) - drawH div 2;
          scaledBmp.Draw(canvas.Canvas, drawX, drawY, False);
        end
        else
        begin
          rad := entry.AccAngle * Pi / 180.0;
          localPivX := L^.PivotX * zoom;
          localPivY := L^.PivotY * zoom;
          newW := Round(Sqrt(drawW * drawW + drawH * drawH) * 2) + 2;
          newH := newW;

          rotatedBmp := TBGRABitmap.Create(newW, newH);
          try
            rotatedBmp.FillTransparent;
            rotatedBmp.Canvas2D.translate(newW / 2, newH / 2);
            rotatedBmp.Canvas2D.rotate(rad);
            rotatedBmp.Canvas2D.translate(-localPivX, -localPivY);
            rotatedBmp.Canvas2D.drawImage(scaledBmp, 0, 0);

            drawX := centerX + Round(entry.AccPivotX * zoom) - newW div 2;
            drawY := centerY + Round(entry.AccPivotY * zoom) - newH div 2;
            rotatedBmp.Draw(canvas.Canvas, drawX, drawY, False);
          finally
            rotatedBmp.Free;
          end;
        end;
      finally
        if ownScaledBmp then scaledBmp.Free;
      end;
    finally
      tileBmp.Free;
    end;
  finally
    srcBmp.Free;
  end;
end;

// ---------------------------------------------------------------------
// RenderFrame — render one frame to a bitmap
// ---------------------------------------------------------------------

function RenderFrame(anim: PAnimationDef; frameIdx: integer;
  outW, outH: integer; mode: TRenderMode;
  const iconSource: string;
  iconTileX, iconTileY, iconTileW, iconTileH: integer): TBGRABitmap;
var
  frame: PFrameDef;
  entries: TRenderArray;
  i: integer;
  centerX, centerY: integer;
  maskBmp: TBGRABitmap;
  foundIcon: boolean;
  iconFirstIdx: integer;
  mx, my: integer;
  maskPx, resPx: TBGRAPixel;
begin
  Result := TBGRABitmap.Create(outW, outH);
  Result.FillTransparent;
  centerX := outW div 2;
  centerY := outH div 2;

  if (anim = nil) or (frameIdx < 0) or (frameIdx >= Length(anim^.Frames)) then
    Exit;

  frame := @anim^.Frames[frameIdx];
  entries := CollectEntries(frame);
  if Length(entries) = 0 then Exit;

  if mode = rmFull then
  begin
    // Simple: draw all layers in order
    for i := 0 to High(entries) do
      DrawLayer(Result, entries[i], centerX, centerY, 1.0);
  end
  else
  begin
    // rmActionIcon: render only icon layers, masked by layers on top.
    // 1. Find the first icon layer in the draw list
    // 2. Draw icon layers to Result
    // 3. Draw non-icon layers that come AFTER the icon to a mask bitmap
    // 4. Use Canvas2D destination-out to cut mask holes from Result

    foundIcon := False;
    iconFirstIdx := -1;
    for i := 0 to High(entries) do
    begin
      if IsIconLayer(entries[i].Layer, iconSource,
                     iconTileX, iconTileY, iconTileW, iconTileH) then
      begin
        foundIcon := True;
        iconFirstIdx := i;
        Break;
      end;
    end;

    if not foundIcon then Exit;

    // Draw all icon layers to Result
    for i := 0 to High(entries) do
      if IsIconLayer(entries[i].Layer, iconSource,
                     iconTileX, iconTileY, iconTileW, iconTileH) then
        DrawLayer(Result, entries[i], centerX, centerY, 1.0);

    // Build mask from non-icon layers drawn AFTER the first icon
    maskBmp := TBGRABitmap.Create(outW, outH);
    try
      maskBmp.FillTransparent;
      for i := iconFirstIdx + 1 to High(entries) do
        if not IsIconLayer(entries[i].Layer, iconSource,
                           iconTileX, iconTileY, iconTileW, iconTileH) then
          DrawLayer(maskBmp, entries[i], centerX, centerY, 1.0);

      // Cut mask holes from Result: where maskBmp is opaque, reduce
      // Result's alpha by the mask's alpha. This is the "destination-out"
      // compositing operation — implemented as a manual pixel loop because
      // this BGRA version's Canvas2D doesn't expose globalCompositeOperation.
      // Frame bitmaps are small (64×64 typical), so the loop is fast enough.
      for my := 0 to maskBmp.Height - 1 do
        for mx := 0 to maskBmp.Width - 1 do
        begin
          maskPx := maskBmp.GetPixel(mx, my);
          if maskPx.alpha > 0 then
          begin
            resPx := Result.GetPixel(mx, my);
            if resPx.alpha > 0 then
            begin
              if resPx.alpha <= maskPx.alpha then
                resPx.alpha := 0
              else
                resPx.alpha := resPx.alpha - maskPx.alpha;
              Result.SetPixel(mx, my, resPx);
            end;
          end;
        end;
    finally
      maskBmp.Free;
    end;
  end;
end;

// ---------------------------------------------------------------------
// RenderSpritesheet — all animations into one bitmap
// ---------------------------------------------------------------------

function RenderSpritesheet(animations: TList; mode: TRenderMode;
  const iconSource: string;
  iconTileX, iconTileY, iconTileW, iconTileH: integer;
  out info: TSpritesheetInfo): TBGRABitmap;
var
  i, j: integer;
  anim: PAnimationDef;
  maxFrameW, maxFrameH: integer;
  maxFrames: integer;
  frameBmp: TBGRABitmap;
  rowY: integer;
  rowWidth: integer;
  fw, fh: integer;
begin
  // Tightly-packed layout: each animation = one row, frames edge-to-edge.
  // - Sheet width  = max(FrameW * FrameCount) across all animations
  // - Sheet height = sum of all FrameH
  // - Frame [j] of animation [i] is at (j * FrameW_i, RowY_i)
  // No gaps, no centering, no wasted pixels. The reader uses per-animation
  // FrameW/H + RowY from the JSON to locate frames — like a fixed-stride
  // sequential register file, one stride per animation.
  maxFrameW := 0;
  maxFrameH := 0;
  maxFrames := 0;
  for i := 0 to animations.Count - 1 do
  begin
    anim := PAnimationDef(animations[i]);
    fw := anim^.FrameW; if fw < 1 then fw := 64;
    fh := anim^.FrameH; if fh < 1 then fh := 64;
    if fw > maxFrameW then maxFrameW := fw;
    if fh > maxFrameH then maxFrameH := fh;
    if Length(anim^.Frames) > maxFrames then maxFrames := Length(anim^.Frames);
  end;
  if maxFrames < 1 then maxFrames := 1;

  // First pass: compute sheet dimensions and per-animation RowY
  info.CellW := maxFrameW;
  info.CellH := maxFrameH;
  info.Columns := maxFrames;
  info.Rows := animations.Count;
  info.SheetW := 0;
  info.SheetH := 0;
  SetLength(info.Animations, animations.Count);

  rowY := 0;
  for i := 0 to animations.Count - 1 do
  begin
    anim := PAnimationDef(animations[i]);
    fw := anim^.FrameW; if fw < 1 then fw := 64;
    fh := anim^.FrameH; if fh < 1 then fh := 64;

    info.Animations[i].Name := anim^.Name;
    info.Animations[i].Row := i;
    info.Animations[i].FrameCount := Length(anim^.Frames);
    info.Animations[i].FrameW := fw;
    info.Animations[i].FrameH := fh;
    info.Animations[i].SpeedMs := anim^.SpeedMs;
    info.Animations[i].RowY := rowY;
    info.Animations[i].FrameX := 0;

    // Row width = this animation's frame count × frame width
    rowWidth := Length(anim^.Frames) * fw;
    if rowWidth > info.SheetW then info.SheetW := rowWidth;
    info.SheetH := info.SheetH + fh;
    rowY := rowY + fh;
  end;

  // Create the sheet bitmap
  if info.SheetW < 1 then info.SheetW := maxFrameW;
  if info.SheetH < 1 then info.SheetH := maxFrameH;
  Result := TBGRABitmap.Create(info.SheetW, info.SheetH);
  Result.FillTransparent;

  // Second pass: render frames, tightly packed
  for i := 0 to animations.Count - 1 do
  begin
    anim := PAnimationDef(animations[i]);
    fw := info.Animations[i].FrameW;
    fh := info.Animations[i].FrameH;
    rowY := info.Animations[i].RowY;

    for j := 0 to High(anim^.Frames) do
    begin
      frameBmp := RenderFrame(anim, j, fw, fh, mode,
        iconSource, iconTileX, iconTileY, iconTileW, iconTileH);
      try
        // Tightly packed: frame j at (j * fw, rowY). No gaps.
        Result.PutImage(j * fw, rowY, frameBmp, dmDrawWithTransparency);
      finally
        frameBmp.Free;
      end;
    end;
  end;
end;

// ---------------------------------------------------------------------
// SaveSpritesheet — write PNG + JSON
// ---------------------------------------------------------------------

procedure SaveSpritesheet(const basePath: string;
  bmp: TBGRABitmap; const info: TSpritesheetInfo);
var
  JSON: TJSONObject;
  AnimsArr: TJSONArray;
  AnimObj: TJSONObject;
  i: integer;
  SL: TStringList;
begin
  // Save PNG
  bmp.SaveToFileUTF8(basePath + '.png');

  // Build JSON metadata
  JSON := TJSONObject.Create;
  try
    JSON.Add('cellW', info.CellW);
    JSON.Add('cellH', info.CellH);
    JSON.Add('columns', info.Columns);
    JSON.Add('rows', info.Rows);
    JSON.Add('sheetW', info.SheetW);
    JSON.Add('sheetH', info.SheetH);
    JSON.Add('image', ExtractFileName(basePath) + '.png');

    AnimsArr := TJSONArray.Create;
    for i := 0 to High(info.Animations) do
    begin
      AnimObj := TJSONObject.Create;
      AnimObj.Add('name', info.Animations[i].Name);
      AnimObj.Add('row', info.Animations[i].Row);
      AnimObj.Add('frameCount', info.Animations[i].FrameCount);
      AnimObj.Add('frameW', info.Animations[i].FrameW);
      AnimObj.Add('frameH', info.Animations[i].FrameH);
      AnimObj.Add('speedMs', info.Animations[i].SpeedMs);
      AnimObj.Add('rowY', info.Animations[i].RowY);
      AnimObj.Add('frameX', info.Animations[i].FrameX);
      AnimsArr.Add(AnimObj);
    end;
    JSON.Add('animations', AnimsArr);

    SL := TStringList.Create;
    try
      SL.Text := JSON.FormatJSON;
      SL.SaveToFile(basePath + '.spritesheet');
    finally
      SL.Free;
    end;
  finally
    JSON.Free;
  end;
end;

end.
