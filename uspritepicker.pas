unit uSpritePicker;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, ExtCtrls, uDebugLog,
  ExtDlgs, Spin, ComCtrls, OpenGLContext, uPathUtils,
  BGRABitmap, BGRABitmapTypes;

type
  TTileDef = record
    Name: string;
    X: Integer;
    Y: Integer;
    Width: Integer;
    Height: Integer;
  end;
  PTileDef = ^TTileDef;

  { TSpritePickerForm }

  TSpritePickerForm = class(TForm)
    btnOk: TButton;
    btnCancel: TButton;
    btnLoadSet: TButton;
    btnNewTile: TButton;
    btnDelTile: TButton;
    btnSaveSet: TButton;
    btnChange: TButton;
    btnBgColor: TButton;
    ColorDlg: TColorDialog;
    edTileName: TEdit;
    imgSample: TImage;
    Label1: TLabel;
    Label2: TLabel;
    Label3: TLabel;
    Label4: TLabel;
    Label5: TLabel;
    lbTiles: TListBox;
    GLControl: TOpenGLControl;
    OpenPictureDialog1: TOpenPictureDialog;
    seX: TSpinEdit;
    seY: TSpinEdit;
    seW: TSpinEdit;
    seH: TSpinEdit;
    TrackBar1: TTrackBar;

    procedure btnBgColorClick(Sender: TObject);
    procedure edTileNameChange(Sender: TObject);
    procedure TrackBar1Change(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure btnChangeClick(Sender: TObject);
    procedure btnNewTileClick(Sender: TObject);
    procedure btnDelTileClick(Sender: TObject);
    procedure btnSaveSetClick(Sender: TObject);
    procedure btnLoadSetClick(Sender: TObject);
    procedure btnOkClick(Sender: TObject);  // offer to save modified tiles before closing
    procedure lbTilesClick(Sender: TObject);
    procedure GLControlPaint(Sender: TObject);
    procedure GLControlResize(Sender: TObject);
    procedure GLControlMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure GLControlMouseMove(Sender: TObject; Shift: TShiftState;
      X, Y: Integer);
    procedure GLControlMouseUp(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure seXChange(Sender: TObject);
    procedure seYChange(Sender: TObject);
    procedure seWChange(Sender: TObject);
    procedure seHChange(Sender: TObject);

  private
    FBitmap: TBGRABitmap;
    FGLTexture: Cardinal;
    FTextureValid: Boolean;
    FTiles: array of TTileDef;
    FSelectedIndex: Integer;
    FDrawingMode: Boolean;
    FIsDrawing: Boolean;
    FDrawStartX, FDrawStartY: Integer;
    FDrawCurrX, FDrawCurrY: Integer;
    FZoom: Double;
    FImgOffX, FImgOffY: Double;
    FImagePath: string;
    FTilesetPath: string;      // the .tileset/.json descriptor file (empty for plain images)
    FTilesModified: boolean;   // true if tiles were added/deleted/edited since load
    FUpdating: Boolean;
    FNeedsTextureUpdate: Boolean;
    FBgColor: TColor;  // user-chosen background for GL + sample
    FFitZoom: Double;       // zoom level that fits image in viewport
    FPanning: Boolean;      // middle-button panning active?
    FPanStartX, FPanStartY: Integer;
    FPanOffX, FPanOffY: Double;

    // Runtime-created labels (not in .frm)
    lblSpinX, lblSpinY, lblSpinW, lblSpinH: TLabel;
    lblNoImage: TLabel;

    procedure InitLabels;
    procedure InitEvents;
    procedure CalculateFit;
    procedure UpdateTexture;
    procedure UpdateTileList;
    procedure UpdateSpinEditsFromTile;
    procedure ApplySpinEditsToTile;
    procedure UpdateSampleImage;
    procedure RenderGL;
    procedure ScreenToImage(SX, SY: Integer; out IX, IY: Integer);
    function  FindTileAt(IX, IY: Integer): Integer;
    procedure NormalizeRect(var AX, AY, AW, AH: Integer);
    procedure SelectTile(Index: Integer);

    // NOTE: MakeRelativePath + ResolveRelativePath have been extracted to
    // the shared uPathUtils unit. Call them as bare functions:
    //   MakeRelativePath(BaseFile, TargetPath)
    //   ResolveRelativePath(BaseFile, RelativePath)
    // uPathUtils is in the uses clause so the unqualified calls resolve
    // to the unit-level functions.

  public
    destructor Destroy; override;
    procedure SetImage(const APath: string);
    procedure LoadTileset(const APath: string);
    function  GetSelectedTile: TTileDef;
    function  GetSelectedTileBitmap: TBGRABitmap;
    function  GetImagePath: string;
    function  GetTilesetPath: string;  // returns the .tileset/.json descriptor, or '' for plain images
    procedure ClearTilesetPath;        // clears FTilesetPath (call before SetImage for plain images)
    property SelectedIndex: Integer read FSelectedIndex;
  end;

var
  SpritePickerForm: TSpritePickerForm;

implementation

{$R *.frm}

uses
  GL, FPJSON, JSONParser, Math;

{============================================================================}
{ TSpritePickerForm - Creation / Destruction                                }
{============================================================================}

procedure TSpritePickerForm.FormCreate(Sender: TObject);
begin
  Caption := 'Sprite Picker';

  FBitmap       := nil;
  FGLTexture    := 0;
  FTextureValid := False;
  FSelectedIndex:= -1;
  FDrawingMode  := False;
  FIsDrawing    := False;
  FZoom         := 1.0;
  FImgOffX      := 0;
  FImgOffY      := 0;
  FImagePath    := '';
  FTilesetPath  := '';
  FTilesModified := False;
  FUpdating     := False;
  FNeedsTextureUpdate := False;
  FBgColor := clGray;  // default dark grey (matches old glClearColor 0.15)
  FFitZoom      := 1.0;
  FPanning      := False;
  FPanStartX    := 0;
  FPanStartY    := 0;
  FPanOffX      := 0;
  FPanOffY      := 0;

  // Modal results so OK / Cancel close the dialog automatically.
  // btnOk also gets an OnClick handler to offer saving modified tiles.
  btnOk.ModalResult     := mrOk;
  btnCancel.ModalResult := mrCancel;
  btnOk.OnClick := @btnOkClick;

  // Spin edit ranges  (X, Y can be 0;  W, H minimum 1)
  seX.MinValue := 0;    seX.MaxValue := 8192;
  seY.MinValue := 0;    seY.MaxValue := 8192;
  seW.MinValue := 1;    seW.MaxValue := 8192;
  seH.MinValue := 1;    seH.MaxValue := 8192;

  InitLabels;
  InitEvents;
end;

procedure TSpritePickerForm.btnBgColorClick(Sender: TObject);
begin
  ColorDlg.Color := FBgColor;
  if ColorDlg.Execute then
  begin
    FBgColor := ColorDlg.Color;
    btnBgColor.Color := FBgColor;
    GLControl.Invalidate;
    UpdateSampleImage;
  end;
end;

procedure TSpritePickerForm.edTileNameChange(Sender: TObject);
begin
  if FUpdating then Exit;
  if (FSelectedIndex < 0) or (FSelectedIndex > High(FTiles)) then Exit;
  FTiles[FSelectedIndex].Name := edTileName.Text;
  FTilesModified := True;
  UpdateTileList;
  GLControl.Invalidate;
end;


procedure TSpritePickerForm.FormDestroy(Sender: TObject);
begin
  // Clean up GL texture while context is still alive.
  //
  // CRITICAL: check GLControl.HandleAllocated before MakeCurrent. When
  // the form is closing, the LCL may have already destroyed the GLControl's
  // window handle — calling MakeCurrent on a handleless control crashes
  // inside glwin32wglcontext.pas (SIGSEGV / access violation). In the
  // plugin DLL this AV was silently swallowed by the host's exception
  // handler; in the standalone exe it's fatal.
  //
  // If the handle is gone, the GL texture leaks (a few KB of GPU memory).
  // That's acceptable — the OS reclaims all GPU resources when the
  // context is destroyed, which happens during form teardown anyway.
  TDebugLogger.Debug('FormDestroy', {$I %CURRENTROUTINE%}, {$I %FILE%}, {$I %lineNum%});
  if FTextureValid and (FGLTexture <> 0) then
  begin
    if (GLControl <> nil) and GLControl.HandleAllocated and GLControl.MakeCurrent then
      glDeleteTextures(1, @FGLTexture);
  end;
  FTextureValid := False;
  FGLTexture := 0;
  FBitmap.Free;
  FBitmap := nil;  // prevent double-free in Destroy
  TDebugLogger.Debug('FormDestroy', {$I %CURRENTROUTINE%}, {$I %FILE%}, {$I %lineNum%});
end;

destructor TSpritePickerForm.Destroy;
begin
  // Safety net: if FormDestroy (OnDestroy event) didn't fire (e.g. the
  // .frm doesn't wire OnDestroy), FBitmap would leak. Free is a no-op
  // on nil, so this is safe even if FormDestroy already freed it.
  FBitmap.Free;
  inherited Destroy;
end;

procedure TSpritePickerForm.InitLabels;
begin

  // --- "no image" hint overlaid on the GL control ---
  lblNoImage := TLabel.Create(Self);
  lblNoImage.Parent      := Self;
  lblNoImage.Caption     := 'Click "Change img" to load a spritesheet';
  lblNoImage.Font.Size   := 12;
  lblNoImage.Font.Color  := clWhite;
  lblNoImage.Color       := clNone;
  lblNoImage.Transparent := True;
  lblNoImage.AutoSize    := True;
  lblNoImage.Left        := GLControl.Left + (GLControl.Width  div 2) - (lblNoImage.Width  div 2);
  lblNoImage.Top         := GLControl.Top  + (GLControl.Height div 2) - (lblNoImage.Height div 2);
  lblNoImage.BringToFront;

  ColorDlg.Color := FBgColor;

end;

{----------------------------------------------------------------------------}
{ Event wiring (not assigned in .frm)                                       }
{----------------------------------------------------------------------------}

procedure TSpritePickerForm.InitEvents;
begin
  // GL control

end;

{============================================================================}
{ Image loading                                                              }
{============================================================================}

procedure TSpritePickerForm.SetImage(const APath: string);
begin
  if not FileExists(APath) then Exit;
  try
    FBitmap.Free;
    FBitmap    := TBGRABitmap.Create(APath);
    FImagePath := APath;
    // NOTE: Do NOT clear FTilesetPath here. When SetImage is called from
    // LoadTileset (which sets FTilesetPath first), clearing it here would
    // wipe the tileset path we just stored. FTilesetPath is cleared by
    // ClearTilesetPath, called by code that loads a plain image directly.
    CalculateFit;
    TrackBar1.Position := 50;  // reset to fit-zoom
    // Defer texture upload — GL context may not exist yet
    // (e.g. when called before ShowModal). The upload will happen
    // on the first GLControlPaint once the context is ready.
    FNeedsTextureUpdate := True;
    FTextureValid := False;
    lblNoImage.Visible := False;
    GLControl.Invalidate;
  except
    on E: Exception do
    begin
      FBitmap       := nil;
      FImagePath    := '';
      FTilesetPath  := '';
      FTextureValid := False;
      FNeedsTextureUpdate := False;
      lblNoImage.Visible := True;
    end;
  end;
end;

{============================================================================}
{ Path helpers — now in uPathUtils unit                                     }
{============================================================================}

procedure TSpritePickerForm.LoadTileset(const APath: string);
var
  SL: TStringList;
  JSON, TileObj: TJSONObject;
  Arr: TJSONArray;
  i: Integer;
  ImgPath: string;
begin
  if not FileExists(APath) then Exit;
  SL := TStringList.Create;
  try
    SL.LoadFromFile(APath);
    JSON := GetJSON(SL.Text) as TJSONObject;
    try
      // Track the tileset descriptor path so callers can retrieve it
      // via GetTilesetPath after the picker closes.
      FTilesetPath := APath;

      // Load the source image referenced by the tileset.
      // The image path in the .tileset file is stored RELATIVE to the
      // .tileset file's directory (see btnSaveSetClick). ResolveRelativePath
      // converts it back to absolute. It also accepts already-absolute
      // paths (legacy .tileset files) so existing files keep loading.
      ImgPath := ResolveRelativePath(APath, JSON.Get('image', ''));
      if (ImgPath <> '') and FileExists(ImgPath) then
        SetImage(ImgPath);

      // Load tile definitions
      if JSON.Find('tiles') <> nil then
      begin
        Arr := JSON.Arrays['tiles'];
        SetLength(FTiles, Arr.Count);
        for i := 0 to Arr.Count - 1 do
        begin
          TileObj := Arr.Objects[i];
          FTiles[i].Name   := TileObj.Get('name',   Format('tile_%d', [i + 1]));
          FTiles[i].X      := TileObj.Get('x',      0);
          FTiles[i].Y      := TileObj.Get('y',      0);
          FTiles[i].Width  := TileObj.Get('width',  32);
          FTiles[i].Height := TileObj.Get('height', 32);
        end;
      end;

      UpdateTileList;
      if Length(FTiles) > 0 then
        SelectTile(0)
      else
        SelectTile(-1);

    finally
      JSON.Free;
    end;
  finally
    SL.Free;
  end;
end;

procedure TSpritePickerForm.btnChangeClick(Sender: TObject);
begin
  if OpenPictureDialog1.Execute then
  begin
    ClearTilesetPath;  // plain image — no descriptor file
    SetImage(OpenPictureDialog1.FileName);
  end;
end;


{============================================================================}
{ OpenGL helpers                                                             }
{============================================================================}

procedure TSpritePickerForm.CalculateFit;
var
  scaleX, scaleY: Double;
begin
  if (FBitmap = nil) or (GLControl.Width <= 0) or (GLControl.Height <= 0) then
    Exit;
  scaleX := GLControl.Width  / FBitmap.Width;
  scaleY := GLControl.Height / FBitmap.Height;
  FFitZoom := Min(scaleX, scaleY) * 0.95;   // 95 % to leave a small margin
  FZoom    := FFitZoom;  // Start at fit
  FImgOffX:= (GLControl.Width  - FBitmap.Width  * FZoom) / 2;
  FImgOffY:= (GLControl.Height - FBitmap.Height * FZoom) / 2;
end;

procedure TSpritePickerForm.UpdateTexture;
begin
  if (GLControl = nil) or not GLControl.HandleAllocated or not GLControl.MakeCurrent then Exit;

  if FGLTexture = 0 then
    glGenTextures(1, @FGLTexture);

  glBindTexture(GL_TEXTURE_2D, FGLTexture);

  if (FBitmap <> nil) and (FBitmap.Width > 0) and (FBitmap.Height > 0) then
  begin
    glPixelStorei(GL_UNPACK_ALIGNMENT, 4);
    // BGRA bitmap data is uploaded as-is.
    // OpenGL stores the first row at the *bottom* of the texture,
    // so we compensate with flipped texture coordinates in RenderGL.
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA,
                 FBitmap.Width, FBitmap.Height,
                 0, $80E1, GL_UNSIGNED_BYTE, FBitmap.Data);

    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, $812F);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, $812F);

    FTextureValid := True;
  end
  else
    FTextureValid := False;
end;

{============================================================================}
{ OpenGL rendering                                                           }
{============================================================================}

procedure TSpritePickerForm.TrackBar1Change(Sender: TObject);
var
  OldZoom, NewZoom, Factor: Double;
  CX, CY: Double;
begin
  if FBitmap = nil then Exit;
  if FFitZoom <= 0 then Exit;

  OldZoom := FZoom;
  // Logarithmic mapping: position 50 = fit, each 10 steps = 2x factor
  //   pos 0  -> 2^-5 = 0.03125x  (very zoomed out)
  //   pos 50 -> 2^0  = 1x        (fit)
  //   pos 100-> 2^5  = 32x       (very zoomed in)
  Factor := Power(2, (TrackBar1.Position - 50) / 10.0);
  NewZoom := FFitZoom * Factor;

  if NewZoom < 0.001 then NewZoom := 0.001;
  if NewZoom > 200.0 then NewZoom := 200.0;

  // Keep the center of the viewport pinned to the same image point
  CX := (GLControl.Width  / 2 - FImgOffX) / OldZoom;
  CY := (GLControl.Height / 2 - FImgOffY) / OldZoom;

  FZoom    := NewZoom;
  FImgOffX := GLControl.Width  / 2 - CX * NewZoom;
  FImgOffY := GLControl.Height / 2 - CY * NewZoom;

  GLControl.Invalidate;
end;

procedure TSpritePickerForm.GLControlResize(Sender: TObject);
var
  SavedPos: Integer;
begin
  if FBitmap = nil then Exit;
  SavedPos := TrackBar1.Position;
  CalculateFit;  // recalculate FFitZoom for new size, reset to fit
  TrackBar1.Position := SavedPos;  // re-apply the user's zoom level
  // TrackBar1Change fires and adjusts zoom from FFitZoom
  if not FNeedsTextureUpdate then
    GLControl.Invalidate;
end;

procedure TSpritePickerForm.GLControlPaint(Sender: TObject);
begin
  RenderGL;
end;

procedure TSpritePickerForm.RenderGL;
var
  i       : Integer;
  r       : TTileDef;
  sx,sy   : Double;
  sw,sh   : Double;
  rx,ry,rw,rh: Integer;
begin
  if (GLControl = nil) or not GLControl.HandleAllocated or not GLControl.MakeCurrent then Exit;

  // Upload texture now that we know the GL context is alive
  if FNeedsTextureUpdate then
  begin
    UpdateTexture;
    FNeedsTextureUpdate := False;
  end;

  // --- projection: screen pixels, origin top-left ---
  glViewport(0, 0, GLControl.Width, GLControl.Height);
  glMatrixMode(GL_PROJECTION);
  glLoadIdentity;
  glOrtho(0, GLControl.Width, GLControl.Height, 0, -1, 1);
  glMatrixMode(GL_MODELVIEW);
  glLoadIdentity;

  // --- background (use FBgColor converted to 0..1 float components) ---
  glClearColor(
    Red(FBgColor)   / 255.0,
    Green(FBgColor) / 255.0,
    Blue(FBgColor)  / 255.0,
    1.0);
  glClear(GL_COLOR_BUFFER_BIT or GL_DEPTH_BUFFER_BIT);

  if FBitmap = nil then
  begin
    GLControl.SwapBuffers;
    Exit;
  end;

  // --- draw source image as textured quad ---
  if FTextureValid then
  begin
    glEnable(GL_TEXTURE_2D);
    glEnable(GL_BLEND);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);

    glBindTexture(GL_TEXTURE_2D, FGLTexture);
    glColor4f(1, 1, 1, 1);

    // Texture coords are flipped on V because OpenGL's first data row
    // becomes the bottom of the texture, but our data starts at top.
    glBegin(GL_QUADS);
      glTexCoord2f(0, 1);
      glVertex2f(FImgOffX,
                 FImgOffY);
      glTexCoord2f(1, 1);
      glVertex2f(FImgOffX + FBitmap.Width  * FZoom,
                 FImgOffY);
      glTexCoord2f(1, 0);
      glVertex2f(FImgOffX + FBitmap.Width  * FZoom,
                 FImgOffY + FBitmap.Height * FZoom);
      glTexCoord2f(0, 0);
      glVertex2f(FImgOffX,
                 FImgOffY + FBitmap.Height * FZoom);
    glEnd;

    glDisable(GL_TEXTURE_2D);
  end;

  // --- blending for rectangles ---
  glEnable(GL_BLEND);
  glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);

  // --- draw defined tile rectangles ---
  for i := 0 to High(FTiles) do
  begin
    r  := FTiles[i];
    sx := FImgOffX + r.X * FZoom;
    sy := FImgOffY + r.Y * FZoom;
    sw := r.Width  * FZoom;
    sh := r.Height * FZoom;

    if i = FSelectedIndex then
    begin
      // selected: yellow fill + thicker border
      glColor4f(1.0, 1.0, 0.0, 0.25);
      glBegin(GL_QUADS);
        glVertex2f(sx,      sy);
        glVertex2f(sx + sw, sy);
        glVertex2f(sx + sw, sy + sh);
        glVertex2f(sx,      sy + sh);
      glEnd;
      glColor4f(1.0, 1.0, 0.0, 1.0);
      glLineWidth(2.0);
    end
    else
    begin
      // normal: green fill + thin border
      glColor4f(0.0, 1.0, 0.0, 0.15);
      glBegin(GL_QUADS);
        glVertex2f(sx,      sy);
        glVertex2f(sx + sw, sy);
        glVertex2f(sx + sw, sy + sh);
        glVertex2f(sx,      sy + sh);
      glEnd;
      glColor4f(0.0, 1.0, 0.0, 0.6);
      glLineWidth(1.0);
    end;

    glBegin(GL_LINE_LOOP);
      glVertex2f(sx,      sy);
      glVertex2f(sx + sw, sy);
      glVertex2f(sx + sw, sy + sh);
      glVertex2f(sx,      sy + sh);
    glEnd;
  end;

  // --- draw the rectangle the user is currently dragging ---
  if FDrawingMode and FIsDrawing then
  begin
    rx := FDrawStartX;
    ry := FDrawStartY;
    rw := FDrawCurrX - FDrawStartX;
    rh := FDrawCurrY - FDrawStartY;
    NormalizeRect(rx, ry, rw, rh);

    sx := FImgOffX + rx * FZoom;
    sy := FImgOffY + ry * FZoom;
    sw := rw * FZoom;
    sh := rh * FZoom;

    // semi-transparent white fill
    glColor4f(1.0, 1.0, 1.0, 0.2);
    glBegin(GL_QUADS);
      glVertex2f(sx,      sy);
      glVertex2f(sx + sw, sy);
      glVertex2f(sx + sw, sy + sh);
      glVertex2f(sx,      sy + sh);
    glEnd;

    // white border
    glColor4f(1.0, 1.0, 1.0, 0.9);
    glLineWidth(1.0);
    glBegin(GL_LINE_LOOP);
      glVertex2f(sx,      sy);
      glVertex2f(sx + sw, sy);
      glVertex2f(sx + sw, sy + sh);
      glVertex2f(sx,      sy + sh);
    glEnd;
  end;

  glLineWidth(1.0);      // restore default
  glDisable(GL_BLEND);
  GLControl.SwapBuffers;
end;

{============================================================================}
{ Coordinate helpers                                                         }
{============================================================================}

procedure TSpritePickerForm.ScreenToImage(SX, SY: Integer;
  out IX, IY: Integer);
begin
  IX := Round((SX - FImgOffX) / FZoom);
  IY := Round((SY - FImgOffY) / FZoom);
end;

function TSpritePickerForm.FindTileAt(IX, IY: Integer): Integer;
var
  i: Integer;
  r: TTileDef;
begin
  Result := -1;
  // Search top-most (last) first so overlapping tiles pick correctly
  for i := High(FTiles) downto 0 do
  begin
    r := FTiles[i];
    if (IX >= r.X) and (IX < r.X + r.Width) and
       (IY >= r.Y) and (IY < r.Y + r.Height) then
    begin
      Result := i;
      Exit;
    end;
  end;
end;

procedure TSpritePickerForm.NormalizeRect(var AX, AY, AW, AH: Integer);
begin
  if AW < 0 then
  begin
    Inc(AX, AW);
    AW := -AW;
  end;
  if AH < 0 then
  begin
    Inc(AY, AH);
    AH := -AH;
  end;
end;

{============================================================================}
{ GL mouse events                                                            }
{============================================================================}

procedure TSpritePickerForm.GLControlMouseDown(Sender: TObject;
  Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  IX, IY: Integer;
  TileIdx: Integer;
begin
  if FBitmap = nil then Exit;

  // --- Middle button: start panning ---
  if Button = mbMiddle then
  begin
    FPanning    := True;
    FPanStartX  := X;
    FPanStartY  := Y;
    FPanOffX    := FImgOffX;
    FPanOffY    := FImgOffY;
    GLControl.Cursor := crSizeAll;
    Exit;
  end;

  if Button <> mbLeft then Exit;

  ScreenToImage(X, Y, IX, IY);

  if FDrawingMode then
  begin
    // Begin drawing a new-tile rectangle
    FIsDrawing  := True;
    FDrawStartX := IX;
    FDrawStartY := IY;
    FDrawCurrX  := IX;
    FDrawCurrY  := IY;
  end
  else
  begin
    // Try to pick an existing tile
    TileIdx := FindTileAt(IX, IY);
    if TileIdx >= 0 then
      SelectTile(TileIdx);
  end;
end;

procedure TSpritePickerForm.GLControlMouseMove(Sender: TObject;
  Shift: TShiftState; X, Y: Integer);
var
  IX, IY: Integer;
begin
  // --- Middle-button panning ---
  if FPanning then
  begin
    FImgOffX := FPanOffX + (X - FPanStartX);
    FImgOffY := FPanOffY + (Y - FPanStartY);
    GLControl.Invalidate;
    Exit;
  end;

  if not (FDrawingMode and FIsDrawing) then Exit;
  ScreenToImage(X, Y, IX, IY);
  FDrawCurrX := IX;
  FDrawCurrY := IY;
  GLControl.Invalidate;
end;

procedure TSpritePickerForm.GLControlMouseUp(Sender: TObject;
  Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  IX, IY, TW, TH: Integer;
  NewIdx: Integer;
begin
  // --- Middle button: stop panning ---
  if Button = mbMiddle then
  begin
    FPanning := False;
    GLControl.Cursor := crDefault;
    Exit;
  end;

  if not (FDrawingMode and FIsDrawing) then Exit;
  if Button <> mbLeft then Exit;

  FIsDrawing := False;
  ScreenToImage(X, Y, IX, IY);
  FDrawCurrX := IX;
  FDrawCurrY := IY;

  // Build rectangle in image space
  TW := FDrawCurrX - FDrawStartX;
  TH := FDrawCurrY - FDrawStartY;
  IX := FDrawStartX;
  IY := FDrawStartY;
  NormalizeRect(IX, IY, TW, TH);

  // Discard tiny rectangles
  if (TW < 2) or (TH < 2) then
  begin
    FDrawingMode := False;
    GLControl.Cursor := crDefault;
    GLControl.Invalidate;
    Exit;
  end;

  // Clamp to image bounds
  if IX < 0 then
    IX := 0;
  if IY < 0 then
    IY := 0;
  if IX + TW > FBitmap.Width then
    TW := FBitmap.Width - IX;
  if IY + TH > FBitmap.Height then
    TH := FBitmap.Height - IY;

  // Add the new tile
  NewIdx := Length(FTiles);
  SetLength(FTiles, NewIdx + 1);
  FTiles[NewIdx].Name   := Format('tile_%d', [NewIdx + 1]);
  FTiles[NewIdx].X      := IX;
  FTiles[NewIdx].Y      := IY;
  FTiles[NewIdx].Width  := TW;
  FTiles[NewIdx].Height := TH;
  FTilesModified := True;

  SelectTile(NewIdx);

  // Leave drawing mode
  FDrawingMode := False;
  GLControl.Cursor := crDefault;
  GLControl.Invalidate;
end;

{============================================================================}
{ Tile management                                                            }
{============================================================================}

procedure TSpritePickerForm.SelectTile(Index: Integer);
begin
  if (Index < -1) or (Index > High(FTiles)) then Exit;
  FSelectedIndex := Index;
  UpdateTileList;
  UpdateSpinEditsFromTile;
  UpdateSampleImage;
  GLControl.Invalidate;
end;

procedure TSpritePickerForm.btnNewTileClick(Sender: TObject);
begin
  if FBitmap = nil then
  begin
    ShowMessage('Load an image first.');
    Exit;
  end;
  FDrawingMode := True;
  GLControl.Cursor := crCross;
end;

procedure TSpritePickerForm.btnDelTileClick(Sender: TObject);
var
  i, idx: Integer;
begin
  if FSelectedIndex < 0 then
  begin
    ShowMessage('Select a tile to delete.');
    Exit;
  end;

  idx := FSelectedIndex;

  // Shift remaining tiles down
  for i := idx to High(FTiles) - 1 do
    FTiles[i] := FTiles[i + 1];
  SetLength(FTiles, Length(FTiles) - 1);
  FTilesModified := True;

  // Keep a sensible selection
  if Length(FTiles) = 0 then
    SelectTile(-1)
  else if idx >= Length(FTiles) then
    SelectTile(Length(FTiles) - 1)
  else
    SelectTile(idx);
end;

procedure TSpritePickerForm.lbTilesClick(Sender: TObject);
begin
  if lbTiles.ItemIndex >= 0 then
    SelectTile(lbTiles.ItemIndex);
end;

{============================================================================}
{ Spin-edit handling                                                         }
{============================================================================}

procedure TSpritePickerForm.UpdateSpinEditsFromTile;
var
  r: TTileDef;
begin
  FUpdating := True;
  try
    if (FSelectedIndex >= 0) and (FSelectedIndex <= High(FTiles)) then
    begin
      r := FTiles[FSelectedIndex];
      seX.Value := r.X;
      seY.Value := r.Y;
      seW.Value := r.Width;
      seH.Value := r.Height;
      edTileName.Text := r.Name;
    end
    else
    begin
      seX.Value := 0;
      seY.Value := 0;
      seW.Value := 1;
      seH.Value := 1;
      edTileName.Text := '';
    end;
  finally
    FUpdating := False;
  end;
end;

procedure TSpritePickerForm.ApplySpinEditsToTile;
begin
  if FUpdating then Exit;
  if (FSelectedIndex < 0) or (FSelectedIndex > High(FTiles)) then Exit;

  FTiles[FSelectedIndex].X      := seX.Value;
  FTiles[FSelectedIndex].Y      := seY.Value;
  FTiles[FSelectedIndex].Width  := seW.Value;
  FTiles[FSelectedIndex].Height := seH.Value;
  FTilesModified := True;

  UpdateTileList;
  UpdateSampleImage;
  GLControl.Invalidate;
end;

procedure TSpritePickerForm.seXChange(Sender: TObject);
begin
  ApplySpinEditsToTile;
end;

procedure TSpritePickerForm.seYChange(Sender: TObject);
begin
  ApplySpinEditsToTile;
end;

procedure TSpritePickerForm.seWChange(Sender: TObject);
begin
  ApplySpinEditsToTile;
end;

procedure TSpritePickerForm.seHChange(Sender: TObject);
begin
  ApplySpinEditsToTile;
end;

{============================================================================}
{ UI refresh helpers                                                         }
{============================================================================}

procedure TSpritePickerForm.UpdateTileList;
var
  i: Integer;
begin
  FUpdating := True;
  try
    lbTiles.Clear;
    for i := 0 to High(FTiles) do
      lbTiles.Items.Add(Format('%s (%d,%d %dx%d)',
        [FTiles[i].Name, FTiles[i].X, FTiles[i].Y,
         FTiles[i].Width, FTiles[i].Height]));
    if (FSelectedIndex >= 0) and (FSelectedIndex < lbTiles.Items.Count) then
      lbTiles.ItemIndex := FSelectedIndex;
  finally
    FUpdating := False;
  end;
end;

procedure TSpritePickerForm.UpdateSampleImage;
var
  ATile: TTileDef;
  TileBmp, ScaledBmp, BgBmp: TBGRABitmap;
  W, H: Integer;
begin
  W := imgSample.Width;
  H := imgSample.Height;
  if (W <= 0) or (H <= 0) then Exit;

  // Size the picture bitmap explicitly — Picture.Clear leaves it 0×0
  imgSample.Picture.Bitmap.SetSize(W, H);

  // Fill sample with the background color
  BgBmp := TBGRABitmap.Create(W, H, ColorToBGRA(FBgColor, 255));
  try
    BgBmp.Draw(imgSample.Picture.Bitmap.Canvas, 0, 0, False);
  finally
    BgBmp.Free;
  end;

  if (FSelectedIndex < 0) or (FSelectedIndex > High(FTiles)) then
  begin
    imgSample.Invalidate;
    Exit;
  end;
  if FBitmap = nil then
  begin
    imgSample.Invalidate;
    Exit;
  end;

  ATile := FTiles[FSelectedIndex];
  if (ATile.Width <= 0) or (ATile.Height <= 0) then Exit;
  if (ATile.X < 0) or (ATile.Y < 0) then Exit;
  if ATile.X + ATile.Width  > FBitmap.Width  then Exit;
  if ATile.Y + ATile.Height > FBitmap.Height then Exit;

  TileBmp := FBitmap.GetPart(
    Rect(ATile.X, ATile.Y, ATile.X + ATile.Width, ATile.Y + ATile.Height)
  ) as TBGRABitmap;
  try
    // Fit into imgSample (128x128) preserving aspect ratio
    W := imgSample.Width;
    H := imgSample.Height;
    if (ATile.Width > 0) and (ATile.Height > 0) then
    begin
      if ATile.Width / ATile.Height > W / H then
        H := Round(W * ATile.Height / ATile.Width)
      else
        W := Round(H * ATile.Width / ATile.Height);
    end;
    ScaledBmp := TileBmp.Resample(W, H) as TBGRABitmap;
    try
      // Center the tile on the existing background fill
      ScaledBmp.Draw(imgSample.Picture.Bitmap.Canvas,
        (imgSample.Width - W) div 2, (imgSample.Height - H) div 2, False);
      imgSample.Invalidate;
    finally
      ScaledBmp.Free;
    end;
  finally
    TileBmp.Free;
  end;
end;

{============================================================================}
{ Save / Load tileset (JSON)                                                }
{============================================================================}

procedure TSpritePickerForm.btnSaveSetClick(Sender: TObject);
var
  SD: TSaveDialog;
  JSON, TileObj: TJSONObject;
  Arr: TJSONArray;
  i: Integer;
  SL: TStringList;
  SavePath: string;
begin
  SD := TSaveDialog.Create(Self);
  try
    SD.Filter := 'Tileset files|*.tileset|JSON files|*.json|All files|*.*';
    SD.DefaultExt := 'tileset';
    SD.Title := 'Save tileset';
    // Pre-fill with the current tileset path if we have one, or
    // derive a default from the image filename (e.g. "hero.png" → "hero.tileset")
    if FTilesetPath <> '' then
      SD.FileName := FTilesetPath
    else if FImagePath <> '' then
      SD.FileName := ChangeFileExt(FImagePath, '.tileset');
    if not SD.Execute then Exit;

    SavePath := SD.FileName;

    JSON := TJSONObject.Create;
    try
      // Store the image path RELATIVE to the .tileset file's directory
      // so the .tileset file is self-contained and portable — the whole
      // bundle (.tileset + image) can be moved/zipped without breaking
      // the reference. FImagePath is absolute in memory; MakeRelativePath
      // converts it against SavePath (the .tileset file path).
      //
      // On load, LoadTileset / btnLoadSetClick call ResolveRelativePath
      // to convert it back to absolute before SetImage.
      JSON.Add('image', MakeRelativePath(SavePath, FImagePath));

      Arr := TJSONArray.Create;
      for i := 0 to High(FTiles) do
      begin
        TileObj := TJSONObject.Create;
        TileObj.Add('name',   FTiles[i].Name);
        TileObj.Add('x',      FTiles[i].X);
        TileObj.Add('y',      FTiles[i].Y);
        TileObj.Add('width',  FTiles[i].Width);
        TileObj.Add('height', FTiles[i].Height);
        Arr.Add(TileObj);
      end;
      JSON.Add('tiles', Arr);

      SL := TStringList.Create;
      try
        SL.Text := JSON.FormatJSON;
        SL.SaveToFile(SavePath);
      finally
        SL.Free;
      end;

      // Update FTilesetPath so GetTilesetPath returns the saved file.
      // This is important — when the picker closes with mrOk, the caller
      // reads GetTilesetPath to store on the layer. If the user just
      // saved a new tileset, we want that path to be stored.
      FTilesetPath := SavePath;
      FTilesModified := False;  // tiles are now saved

      ShowMessage('Tileset saved to ' + SavePath + ' (' + IntToStr(Length(FTiles)) + ' tiles).');
    finally
      JSON.Free;
    end;
  finally
    SD.Free;
  end;
end;

procedure TSpritePickerForm.btnOkClick(Sender: TObject);
begin
  // If tiles were modified (added/deleted/edited) but not saved, offer
  // to save them before closing. This prevents losing work when the user
  // draws new tiles and clicks OK without remembering to save first.
  if FTilesModified and (Length(FTiles) > 0) then
  begin
    if MessageDlg('Save tileset?',
      'You have unsaved tile definitions. Save them now?',
      mtConfirmation, [mbYes, mbNo], 0) = mrYes then
    begin
      btnSaveSetClick(Self);
    end;
  end;
  // The ModalResult := mrOk on the button will close the form after
  // this handler returns.
end;

procedure TSpritePickerForm.btnLoadSetClick(Sender: TObject);
var
  OD: TOpenDialog;
  SL: TStringList;
  JSON, TileObj: TJSONObject;
  Arr: TJSONArray;
  i: Integer;
  ImgPath: string;
begin
  OD := TOpenDialog.Create(Self);
  try
    OD.Filter := 'Tileset files|*.tileset|JSON files|*.json|All files|*.*';
    if not OD.Execute then Exit;

    SL := TStringList.Create;
    try
      SL.LoadFromFile(OD.FileName);
      JSON := GetJSON(SL.Text) as TJSONObject;
      try
        // Track the tileset descriptor path so callers can retrieve it
        // via GetTilesetPath after the picker closes.
        FTilesetPath := OD.FileName;

        // Load the source image.
        // The image path in the .tileset file is stored RELATIVE to the
        // .tileset file's directory (see btnSaveSetClick). ResolveRelativePath
        // converts it back to absolute. It also accepts already-absolute
        // paths (legacy .tileset files) so existing files keep loading.
        ImgPath := ResolveRelativePath(OD.FileName, JSON.Get('image', ''));
        if (ImgPath <> '') and FileExists(ImgPath) then
          SetImage(ImgPath);

        // Load tile definitions
        if JSON.Find('tiles') <> nil then
        begin
          Arr := JSON.Arrays['tiles'];
          SetLength(FTiles, Arr.Count);
          for i := 0 to Arr.Count - 1 do
          begin
            TileObj := Arr.Objects[i];
            FTiles[i].Name   := TileObj.Get('name',   Format('tile_%d', [i + 1]));
            FTiles[i].X      := TileObj.Get('x',      0);
            FTiles[i].Y      := TileObj.Get('y',      0);
            FTiles[i].Width  := TileObj.Get('width',  32);
            FTiles[i].Height := TileObj.Get('height', 32);
          end;
        end;

        UpdateTileList;
        if Length(FTiles) > 0 then
          SelectTile(0)
        else
          SelectTile(-1);

      finally
        JSON.Free;
      end;
    finally
      SL.Free;
    end;
  finally
    OD.Free;
  end;
end;

{============================================================================}
{ Public getters (caller reads these after ShowModal = mrOk)                }
{============================================================================}

function TSpritePickerForm.GetSelectedTile: TTileDef;
begin
  if (FSelectedIndex >= 0) and (FSelectedIndex <= High(FTiles)) then
    Result := FTiles[FSelectedIndex]
  else
  begin
    Result.Name   := '';
    Result.X      := 0;
    Result.Y      := 0;
    Result.Width  := 0;
    Result.Height := 0;
  end;
end;

function TSpritePickerForm.GetSelectedTileBitmap: TBGRABitmap;
var
  ATile: TTileDef;
begin
  Result := nil;
  if (FSelectedIndex < 0) or (FSelectedIndex > High(FTiles)) then Exit;
  if FBitmap = nil then Exit;

  ATile := FTiles[FSelectedIndex];
  if (ATile.Width <= 0) or (ATile.Height <= 0) then Exit;
  if ATile.X + ATile.Width  > FBitmap.Width  then Exit;
  if ATile.Y + ATile.Height > FBitmap.Height then Exit;

  Result := FBitmap.GetPart(
    Rect(ATile.X, ATile.Y, ATile.X + ATile.Width, ATile.Y + ATile.Height)
  ) as TBGRABitmap;
end;

function TSpritePickerForm.GetImagePath: string;
begin
  Result := FImagePath;
end;

function TSpritePickerForm.GetTilesetPath: string;
begin
  Result := FTilesetPath;
end;

procedure TSpritePickerForm.ClearTilesetPath;
begin
  FTilesetPath := '';
end;

end.



