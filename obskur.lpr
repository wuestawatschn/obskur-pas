program obskur;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}cthreads,{$ENDIF}
  Interfaces, Forms, Controls, Graphics, Dialogs, ExtCtrls, StdCtrls,
  ComCtrls, Classes, SysUtils, Math, DateUtils;

const
  CANVAS_W = 800;
  CANVAS_H = 600;
  MAX_GRID = 1025;
  MARGIN = 24.0;
  NUM_MODES = 28;
  NUM_PALETTES = 5;

  PALETTE_NAMES: array[0..NUM_PALETTES - 1] of string = (
    '0: Klassik (Einfarbig)',
    '1: Lava & Glut',
    '2: Tiefsee & Ozean',
    '3: Nordlicht (Aurora)',
    '4: Spektrum-Verlauf'
  );

  FORMULA_NAMES: array[0..NUM_MODES - 1] of string = (
    '0: Sinus-Kosinus-Wellen', '1: Mexikanerhut (Gedämpft)', '2: Kreuzwellen',
    '3: Interferenz-Gitter', '4: Radial-Welle (Sinc)', '5: Asymmetrische Düne',
    '6: Diagonal-Muster', '7: Ring-Modulation', '8: Hyperbel-Sattel',
    '9: Kamm-Wellen', '10: Gauss-Impuls', '11: Klassik-Mix',
    '12: Spiralgalaxie', '13: Vulkankrater', '14: Eierkarton',
    '15: 4-blättrige Blüte', '16: Konzentrische Ringe', '17: Verwirbelte Dünen',
    '18: Pyramiden-Spitzen', '19: Wirbelsturm',
    '20: Mandelbrot-Fraktal', '21: Quasikristall (5-fach)',
    '22: Korbflecht-Knoten', '23: 3-Quellen-Interferenz',
    '24: Stufen-Pyramide', '25: Plasma-Turbulenz',
    '26: Wurmloch-Trichter', '27: Polar-Kartesisches Chaos'
  );

  FORMULA_NAMES_EN: array[0..NUM_MODES - 1] of string = (
    '0: Sine-Cosine Waves', '1: Mexican Hat (Damped)', '2: Cross Waves',
    '3: Interference Grid', '4: Radial Wave (Sinc)', '5: Asymmetric Dune',
    '6: Diagonal Pattern', '7: Ring Modulation', '8: Hyperbolic Saddle',
    '9: Comb Waves', '10: Gaussian Pulse', '11: Classic Mix',
    '12: Spiral Galaxy', '13: Volcanic Crater', '14: Egg Carton',
    '15: 4-Petal Flower', '16: Concentric Rings', '17: Swirled Dunes',
    '18: Pyramid Peaks', '19: Tornado Vortex',
    '20: Mandelbrot Fractal', '21: Quasicrystal (5-fold)',
    '22: Basketweave Knot', '23: 3-Source Interference',
    '24: Stepped Pyramid', '25: Plasma Turbulence',
    '26: Wormhole Funnel', '27: Polar-Cartesian Chaos'
  );

  PALETTE_NAMES_EN: array[0..NUM_PALETTES - 1] of string = (
    '0: Classic (Monochrome)', '1: Lava & Embers', '2: Deep Sea & Ocean',
    '3: Northern Lights (Aurora)', '4: Rainbow Spectrum'
  );

type
  TQuadItem = record
    r, c: Integer;
    mirror: Boolean;
    depth: Double;
  end;

  TObskurForm = class(TForm)
  private
    PaintBox: TPaintBox;
    BufferBmp: TBitmap;
    SidePanel: TPanel;
    Timer: TTimer;

    BtnRandom, BtnRedraw, BtnPause, BtnSave: TButton;
    LblStatus, LblGrid, LblSpeed, LblLang, LblFormula, LblPalette, LblStep, LblWidth, LblAmp, LblHue, LblYaw, LblPitch: TLabel;
    ChkAuto, ChkMirror, ChkSphere, ChkWaveAnim: TCheckBox;
    CmbLang, CmbFormula, CmbPalette: TComboBox;
    TrkSpeed, TrkGrid, TrkStep, TrkWidth, TrkAmp, TrkHue, TrkYaw, TrkPitch: TTrackBar;

    Heights: array[0..MAX_GRID - 1, 0..MAX_GRID - 1] of Double;
    QuadList: array of TQuadItem;
    MinZ, MaxZ, FitScale, FitOx, FitOy: Double;

    FMode, FPalette, FStep, FDx, FSpeedMs, FCycle, FGridSize: Integer;
    FAmp, FHue, FYaw, FPitch, FPhase: Double;
    FDoubleMirror, FAutoCycle, FPaused, FFinished, FSphereMode, FWaveAnim: Boolean;
    CurRow, CurCol: Integer;
    FinishedAt: TDateTime;
    QuadCount, CurQuadIdx: Integer;
    IsDragging, UpdatingUI, FIsEnglish: Boolean;
    LastMouse: TPoint;

    procedure QuickSortQuads(L, R_idx: Integer);
    procedure BuildUI;
    procedure ApplyLanguage;
    procedure SyncControlsFromParams;
    procedure RandomizeParams;
    procedure ComputeHeights;
    procedure Project3D(r, c: Integer; h: Double; out sx, sy, sz: Double);
    procedure ComputeFit;
    function ProjectPoint(r, c: Integer; sign: Double): TPoint;
    function GetQuadColor(norm: Double; isMirror, isBorder: Boolean): TColor;
    procedure RestartDrawing(InstantComplete: Boolean; KeepProgress: Boolean = False);
    procedure DrawNextQuad;
    procedure PrepareQuads;
    procedure DrawAllQuads;

    procedure OnPaintCanvas(Sender: TObject);
    procedure OnTimerTick(Sender: TObject);
    procedure OnCanvasMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure OnCanvasMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
    procedure OnCanvasMouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure OnBtnRandomClick(Sender: TObject);
    procedure OnBtnRedrawClick(Sender: TObject);
    procedure OnBtnPauseClick(Sender: TObject);
    procedure OnBtnSaveClick(Sender: TObject);
    procedure OnParamChanged(Sender: TObject);
  public
    constructor CreateNew(AOwner: TComponent; Num: Integer = 0); override;
    destructor Destroy; override;
  end;

function HsvToTColor(Hue, Sat, Val: Double): TColor;
var
  h, s, v, c, x, m, r1, g1, b1: Double;
begin
  h := Hue - 360.0 * Floor(Hue / 360.0);
  s := EnsureRange(Sat, 0.0, 1.0);
  v := EnsureRange(Val, 0.0, 1.0);
  c := v * s;
  x := c * (1.0 - Abs((h / 60.0) - 2.0 * Floor((h / 60.0) / 2.0) - 1.0));
  m := v - c;
  case Trunc(h) div 60 of
    0: begin r1 := c; g1 := x; b1 := 0; end;
    1: begin r1 := x; g1 := c; b1 := 0; end;
    2: begin r1 := 0; g1 := c; b1 := x; end;
    3: begin r1 := 0; g1 := x; b1 := c; end;
    4: begin r1 := x; g1 := 0; b1 := c; end;
  else
    begin r1 := c; g1 := 0; b1 := x; end;
  end;
  Result := RGBToColor(Round((r1 + m) * 255), Round((g1 + m) * 255), Round((b1 + m) * 255));
end;
function TObskurForm.GetQuadColor(norm: Double; isMirror, isBorder: Boolean): TColor;
var
  t, h, s, v: Double;
begin
  t := EnsureRange(norm, 0.0, 1.0);
  if isMirror then t := 1.0 - t;

  case FPalette of
    1: begin // Lava & Glut (Dunkelrot -> Orange -> Gelb -> Weiß)
         h := (FHue * 0.15) + t * 52.0;
         s := 1.0 - Power(t, 3.0) * 0.55;
         v := 0.15 + Power(t, 0.75) * 0.85;
       end;
    2: begin // Tiefsee & Ozean (Tiefblau -> Türkis -> Schaumweiß)
         h := 235.0 - t * 65.0 + (FHue * 0.1);
         s := 0.95 - Power(t, 2.5) * 0.65;
         v := 0.22 + t * 0.78;
       end;
    3: begin // Nordlicht (Violett -> Grün -> Cyan)
         h := 280.0 - t * 140.0 + (FHue * 0.15);
         s := 0.88;
         v := 0.25 + Sin(t * Pi * 0.85) * 0.75;
       end;
    4: begin // Spektrum-Verlauf (Regenbogen ab FHue)
         h := FHue + t * 260.0;
         s := 0.88;
         v := 0.35 + t * 0.65;
       end;
  else
    begin // 0: Klassik (Einfarbig mit 3D-Schattierung)
      if not isMirror then h := FHue else h := FHue + 150.0;
      s := 0.85;
      v := 0.30 + t * 0.68;
    end;
  end;

  if isBorder then
  begin
    s := s * 0.50;
    v := Min(1.0, v + 0.18);
  end;
  Result := HsvToTColor(h, s, v);
end;

procedure TObskurForm.RandomizeParams;
begin
  FDx := (Random(5) + 2) * 2;
  FMode := Random(NUM_MODES);
  FPalette := Random(NUM_PALETTES);
  FAmp := 350.0 + Random(550);
  FStep := Max(1, (FGridSize - 1) div 32);
  FDoubleMirror := (FCycle mod 2 = 0);
  FHue := Random(360);
  SyncControlsFromParams;
end;

procedure TObskurForm.ComputeHeights;
var
  i, j: Integer;
  nx, ny, r, angle, val, h, half, zx, zy, zt, d1, d2, d3: Double;
  iter: Integer;
begin
  MinZ := 1e30; MaxZ := -1e30;
  half := (FGridSize - 1) * 0.5;
  for i := 0 to FGridSize - 1 do
  begin
    nx := (i - half) / half * Pi + FPhase * 0.35;
    for j := 0 to FGridSize - 1 do
    begin
      ny := (j - half) / half * Pi + FPhase * 0.25;
      r := Sqrt(nx * nx + ny * ny);
      angle := ArcTan2(ny, nx);
      case FMode mod NUM_MODES of
        0: val := Sin(nx * 2.0) * Cos(ny * 2.0);
        1: val := Cos(r * 2.5) * Exp(-r * 0.35);
        2: val := Sin(nx * 1.5) + Sin(ny * 1.5);
        3: val := (Sin(nx * 2.0) * Sin(ny * 2.0)) * Cos(r * 1.2);
        4: val := Sin(r * 3.0) / (r + 0.5);
        5: val := Cos(nx * 3.0) * Sin(ny * 2.0) - Sin(r * 1.5) * 0.5;
        6: val := Sin((nx + ny) * 2.0) * Cos((nx - ny) * 2.0);
        7: val := Cos(r * 4.0) * 0.6 + Sin(nx * 2.0) * 0.4;
        8: val := Sin(nx * nx - ny * ny) * 0.7;
        9: val := Sin(r * 2.0) * Cos(nx * 2.0) + Sin(ny * 2.0) * 0.5;
        10: val := Exp(-0.5 * (nx * nx + ny * ny)) * Cos(r * 5.0) * 1.5;
        11: val := Sin(nx * 2.5) * Cos(ny * 2.5) + Sin(r * 2.0) * 0.5;
        12: val := Sin(r * 3.0 - angle * 2.0) * Exp(-r * 0.25);
        13: val := Sin(r * 1.8) * 1.4 - Exp(-r * r * 1.2) * 1.8;
        14: val := (Cos(nx * 3.0) + Cos(ny * 3.0)) * 0.5;
        15: val := Cos(angle * 4.0) * Sin(r * 2.0) * 0.9;
        16: val := Cos((nx * nx + ny * ny) * 0.8) / (1.0 + 0.3 * r * r);
        17: val := Sin(nx * 2.0 + Sin(ny * 2.0)) * Cos(ny * 1.5);
        18: val := Power(Cos(nx * 1.5) * Cos(ny * 1.5), 3) * 1.5;
        19: val := Cos(r * 4.5 + angle * 3.0) * (r / (r + 1.0));
        20: begin // Mandelbrot-Fraktal
              zx := 0.0; zy := 0.0; iter := 0;
              while (zx * zx + zy * zy <= 4.0) and (iter < 24) do
              begin
                zt := zx * zx - zy * zy + (nx * 0.65 - 0.5);
                zy := 2.0 * zx * zy + (ny * 0.65);
                zx := zt;
                Inc(iter);
              end;
              val := (iter / 12.0) - 1.0;
            end;
        21: begin // Quasikristall (5-fach Symmetrie)
              val := (Cos(nx * 3.0)
                    + Cos(nx * 0.927 + ny * 2.853)
                    + Cos(-nx * 2.427 + ny * 1.763)
                    + Cos(-nx * 2.427 - ny * 1.763)
                    + Cos(nx * 0.927 - ny * 2.853)) * 0.35;
            end;
        22: val := Sin(angle * 6.0 + r * 2.5) * Cos(angle * 3.0 - r * 3.0); // Korbflecht-Knoten
        23: begin // 3-Quellen-Schockwellen
              d1 := Sqrt(Sqr(nx - 1.5) + Sqr(ny + 1.0));
              d2 := Sqrt(Sqr(nx + 1.5) + Sqr(ny + 1.0));
              d3 := Sqrt(Sqr(nx) + Sqr(ny - 1.6));
              val := (Sin(d1 * 5.0) + Sin(d2 * 5.0) + Sin(d3 * 5.0)) * 0.45;
            end;
        24: val := Round(Sin(r * 2.2) * Cos(nx * 1.2) * 5.0) / 4.0; // Stufen-Pyramide
        25: val := Sin(nx * 2.0 + FPhase + Sin(ny * 2.5 - FPhase * 1.3 + Sin(nx * 3.0 + FPhase))) * Cos(ny * 2.0 + Cos(nx * 2.5 - FPhase)); // Plasma
        26: val := -2.2 / (r * r + 0.45) + 0.35 * Sin(r * 6.0 + angle * 4.0); // Wurmloch-Trichter
      else
        val := Sin(nx * ny * 1.3) * Cos(r * 4.0) + 0.3 * Sin(angle * 7.0); // Polar-Kartesisches Chaos
      end;
      h := val * (FAmp / 8.0);
      Heights[i, j] := h;
      if h < MinZ then MinZ := h;
      if h > MaxZ then MaxZ := h;
    end;
  end;
end;

procedure TObskurForm.Project3D(r, c: Integer; h: Double; out sx, sy, sz: Double);
var
  x, y, z, yawRad, pitchRad, x1, y1, z1, theta, phi, rad, scaleFactor: Double;
begin
  if FSphereMode then
  begin
    theta := (r / (FGridSize - 1)) * Pi;
    phi := (c / (FGridSize - 1)) * 2.0 * Pi;
    rad := Max(20.0, (FDx * 28.0) + h * 0.85);
    x := rad * Sin(theta) * Cos(phi);
    y := rad * Cos(theta);
    z := rad * Sin(theta) * Sin(phi);
  end
  else
  begin
    scaleFactor := FDx * 64.0 / (FGridSize - 1);
    x := (c - (FGridSize - 1) * 0.5) * scaleFactor;
    y := h;
    z := (r - (FGridSize - 1) * 0.5) * scaleFactor;
  end;

  yawRad := DegToRad(FYaw);
  pitchRad := DegToRad(FPitch);
  x1 := x * Cos(yawRad) - z * Sin(yawRad);
  z1 := x * Sin(yawRad) + z * Cos(yawRad);
  y1 := y * Cos(pitchRad) - z1 * Sin(pitchRad);
  sz := y * Sin(pitchRad) + z1 * Cos(pitchRad);
  sx := x1;
  sy := -y1;
end;

procedure TObskurForm.ComputeFit;
var
  r, c, maxIdx, sampleStep: Integer;
  minX, maxX, minY, maxY, sx, sy, sz, mx, my, mz, h: Double;
begin
  minX := 1e30; maxX := -1e30; minY := 1e30; maxY := -1e30;
  sampleStep := Max(FStep, (FGridSize - 1) div 64);
  maxIdx := ((FGridSize - 1) div sampleStep) * sampleStep;
  r := 0;
  while r <= maxIdx do
  begin
    c := 0;
    while c <= maxIdx do
    begin
      h := Heights[r, c];
      Project3D(r, c, h, sx, sy, sz);
      if sx < minX then minX := sx; if sx > maxX then maxX := sx;
      if sy < minY then minY := sy; if sy > maxY then maxY := sy;
      if FDoubleMirror then
      begin
        Project3D(r, c, -h, mx, my, mz);
        if mx < minX then minX := mx; if mx > maxX then maxX := mx;
        if my < minY then minY := my; if my > maxY then maxY := my;
      end;
      Inc(c, sampleStep);
    end;
    Inc(r, sampleStep);
  end;
  FitScale := Min((CANVAS_W - 2.0 * MARGIN) / Max(1.0, maxX - minX),
                  (CANVAS_H - 2.0 * MARGIN) / Max(1.0, maxY - minY));
  if FitScale > 1.0 then FitScale := 1.0;
  FitOx := (CANVAS_W * 0.5) - (minX + maxX) * 0.5 * FitScale;
  FitOy := (CANVAS_H * 0.5) - (minY + maxY) * 0.5 * FitScale;
end;

function TObskurForm.ProjectPoint(r, c: Integer; sign: Double): TPoint;
var
  sx, sy, sz: Double;
begin
  Project3D(r, c, -sign * Heights[r, c], sx, sy, sz);
  Result.X := Round(sx * FitScale + FitOx);
  Result.Y := Round(sy * FitScale + FitOy);
end;

procedure TObskurForm.QuickSortQuads(L, R_idx: Integer);
var
  ii, jj: Integer;
  pivot: Double;
  t: TQuadItem;
begin
  ii := L; jj := R_idx;
  pivot := QuadList[(L + R_idx) div 2].depth;
  repeat
    while QuadList[ii].depth < pivot do Inc(ii);
    while QuadList[jj].depth > pivot do Dec(jj);
    if ii <= jj then
    begin
      t := QuadList[ii]; QuadList[ii] := QuadList[jj]; QuadList[jj] := t;
      Inc(ii); Dec(jj);
    end;
  until ii > jj;
  if L < jj then QuickSortQuads(L, jj);
  if ii < R_idx then QuickSortQuads(ii, R_idx);
end;

procedure TObskurForm.PrepareQuads;
var
  r, col, step, cells: Integer;
  sx, sy, sz: Double;
begin
  step := FStep;
  cells := (FGridSize - 1) div step;
  SetLength(QuadList, (cells + 1) * (cells + 1) * 2);
  QuadCount := 0;
  CurQuadIdx := 0;
  r := 0;
  while r + step < FGridSize do
  begin
    col := 0;
    while col + step < FGridSize do
    begin
      Project3D(r + step div 2, col + step div 2, Heights[r, col], sx, sy, sz);
      QuadList[QuadCount].r := r; QuadList[QuadCount].c := col;
      QuadList[QuadCount].mirror := False; QuadList[QuadCount].depth := sz;
      Inc(QuadCount);
      if FDoubleMirror then
      begin
        Project3D(r + step div 2, col + step div 2, -Heights[r, col], sx, sy, sz);
        QuadList[QuadCount].r := r; QuadList[QuadCount].c := col;
        QuadList[QuadCount].mirror := True; QuadList[QuadCount].depth := sz;
        Inc(QuadCount);
      end;
      Inc(col, step);
    end;
    Inc(r, step);
  end;
  if FSphereMode and (QuadCount > 1) then
    QuickSortQuads(0, QuadCount - 1);
end;

procedure TObskurForm.DrawNextQuad;
var
  r, col, step: Integer;
  avgH, norm, mHue: Double;
  pts: array[0..3] of TPoint;
begin
  if FFinished then Exit;
  if CurQuadIdx >= QuadCount then
  begin
    FFinished := True;
    FinishedAt := Now;
    Exit;
  end;

  step := FStep;
  r := QuadList[CurQuadIdx].r;
  col := QuadList[CurQuadIdx].c;
  avgH := (Heights[r, col] + Heights[r, col + step] + Heights[r + step, col + step] + Heights[r + step, col]) / 4.0;
  norm := EnsureRange((avgH - MinZ) / Max(1.0, MaxZ - MinZ), 0.0, 1.0);

  if not QuadList[CurQuadIdx].mirror then
  begin
    pts[0] := ProjectPoint(r, col, -1.0);
    pts[1] := ProjectPoint(r, col + step, -1.0);
    pts[2] := ProjectPoint(r + step, col + step, -1.0);
    pts[3] := ProjectPoint(r + step, col, -1.0);
    BufferBmp.Canvas.Brush.Color := GetQuadColor(norm, False, False);
    BufferBmp.Canvas.Pen.Color := GetQuadColor(norm, False, True);
  end
  else
  begin
    mHue := FHue + 150.0;
    pts[0] := ProjectPoint(r, col, 1.0);
    pts[1] := ProjectPoint(r, col + step, 1.0);
    pts[2] := ProjectPoint(r + step, col + step, 1.0);
    pts[3] := ProjectPoint(r + step, col, 1.0);
    BufferBmp.Canvas.Brush.Color := GetQuadColor(norm, True, False);
    BufferBmp.Canvas.Pen.Color := GetQuadColor(norm, True, True);
  end;
  BufferBmp.Canvas.Polygon(pts);

  Inc(CurQuadIdx);
  if CurQuadIdx >= QuadCount then
  begin
    FFinished := True;
    FinishedAt := Now;
  end;
end;

procedure TObskurForm.DrawAllQuads;
begin
  while not FFinished do DrawNextQuad;
end;

procedure TObskurForm.RestartDrawing(InstantComplete: Boolean; KeepProgress: Boolean);
var
  prevRatio: Double;
  targetIdx: Integer;
begin
  if KeepProgress and (QuadCount > 0) then
    prevRatio := CurQuadIdx / QuadCount
  else
    prevRatio := 0.0;

  BufferBmp.Canvas.Brush.Color := clBlack;
  BufferBmp.Canvas.FillRect(0, 0, CANVAS_W, CANVAS_H);
  ComputeHeights;
  ComputeFit;
  PrepareQuads;
  FFinished := False;

  if KeepProgress and (prevRatio < 1.0) and (FSpeedMs < 100) then
  begin
    targetIdx := Round(prevRatio * QuadCount);
    while (CurQuadIdx < targetIdx) and not FFinished do
      DrawNextQuad;
  end
  else if InstantComplete or (FSpeedMs >= 100) then
    DrawAllQuads;

  PaintBox.Invalidate;
end;

procedure TObskurForm.ApplyLanguage;
var
  i, savedFormula, savedPalette: Integer;
begin
  UpdatingUI := True;
  savedFormula := FMode;
  savedPalette := FPalette;
  CmbFormula.Items.Clear;
  CmbPalette.Items.Clear;

  if FIsEnglish then
  begin
    LblLang.Caption := 'Language / Sprache:';
    BtnRandom.Caption := 'Random & New';
    BtnRedraw.Caption := 'Redraw';
    if FPaused then BtnPause.Caption := 'Resume' else BtnPause.Caption := 'Pause';
    BtnSave.Caption := 'Save as PNG';
    ChkAuto.Caption := 'Auto-Cycle';
    ChkWaveAnim.Caption := 'Live Waves';
    LblSpeed.Caption := Format('Speed: %d (1 = slow .. 100 = instant)', [FSpeedMs]);
    LblFormula.Caption := '3D Formula:';
    LblPalette.Caption := 'Color Palette:';
    LblGrid.Caption := Format('Resolution: %d x %d', [FGridSize - 1, FGridSize - 1]);
    LblStep.Caption := 'Grid Step (1 = fine):';
    LblWidth.Caption := 'Grid Width / Radius:';
    LblAmp.Caption := 'Height (Amplitude):';
    LblHue.Caption := 'Hue / Base Offset:';
    ChkMirror.Caption := 'Mirror';
    ChkSphere.Caption := 'Sphere Mode';
    LblYaw.Caption := 'Rotation (or drag mouse):';
    LblPitch.Caption := 'Tilt (Pitch):';
    for i := 0 to NUM_MODES - 1 do CmbFormula.Items.Add(FORMULA_NAMES_EN[i]);
    for i := 0 to NUM_PALETTES - 1 do CmbPalette.Items.Add(PALETTE_NAMES_EN[i]);
  end
  else
  begin
    LblLang.Caption := 'Sprache / Language:';
    BtnRandom.Caption := 'Zufall & Neu';
    BtnRedraw.Caption := 'Neu zeichnen';
    if FIsEnglish then begin if FPaused then BtnPause.Caption := 'Resume' else BtnPause.Caption := 'Pause'; end else begin if FPaused then BtnPause.Caption := 'Weiter' else BtnPause.Caption := 'Pause'; end;
    BtnSave.Caption := 'Als PNG speichern';
    ChkAuto.Caption := 'Auto-Wechsel';
    ChkWaveAnim.Caption := 'Live-Wellen';
    if FIsEnglish then LblSpeed.Caption := Format('Speed: %d (1 = slow .. 100 = instant)', [FSpeedMs]) else LblSpeed.Caption := Format('Tempo: %d (1 = Zeitlupe .. 100 = sofort)', [FSpeedMs]);
    LblFormula.Caption := '3D-Formel:';
    LblPalette.Caption := 'Farbpalette:';
    if FIsEnglish then LblGrid.Caption := Format('Resolution: %d x %d', [FGridSize - 1, FGridSize - 1]) else LblGrid.Caption := Format('Auflösung: %d x %d', [FGridSize - 1, FGridSize - 1]);
    LblStep.Caption := 'Raster-Schritt (1 = fein):';
    LblWidth.Caption := 'Gitter-Breite / Radius:';
    LblAmp.Caption := 'Höhe (Amplitude):';
    LblHue.Caption := 'Farbton / Basis-Offset:';
    ChkMirror.Caption := 'Spiegelung';
    ChkSphere.Caption := 'Kugel-Modus';
    LblYaw.Caption := 'Drehung (oder Maus ziehen):';
    LblPitch.Caption := 'Kippung:';
    for i := 0 to NUM_MODES - 1 do CmbFormula.Items.Add(FORMULA_NAMES[i]);
    for i := 0 to NUM_PALETTES - 1 do CmbPalette.Items.Add(PALETTE_NAMES[i]);
  end;

  CmbFormula.ItemIndex := savedFormula;
  CmbPalette.ItemIndex := savedPalette;
  UpdatingUI := False;
end;

procedure TObskurForm.BuildUI;
var
  yPos: Integer;
  function AddLabel(const Cap: string; Y: Integer): TLabel;
  begin
    Result := TLabel.Create(Self); Result.Parent := SidePanel;
    Result.Left := 12; Result.Top := Y; Result.Caption := Cap;
  end;
  function AddTrack(MinV, MaxV, PosV, Y: Integer): TTrackBar;
  begin
    Result := TTrackBar.Create(Self); Result.Parent := SidePanel;
    Result.SetBounds(10, Y, 230, 26); Result.Min := MinV; Result.Max := MaxV;
    Result.Position := PosV; Result.TickStyle := tsNone; Result.OnChange := @OnParamChanged;
  end;
begin
  UpdatingUI := True;
  Width := 1060; Height := 790;
  Caption := 'OBSKUR Studio (1990 - 2026)';
  Position := poScreenCenter;

  SidePanel := TPanel.Create(Self); SidePanel.Parent := Self;
  SidePanel.Align := alRight; SidePanel.Width := 255;

  PaintBox := TPaintBox.Create(Self); PaintBox.Parent := Self;
  PaintBox.Align := alClient; PaintBox.OnPaint := @OnPaintCanvas;
  PaintBox.OnMouseDown := @OnCanvasMouseDown;
  PaintBox.OnMouseMove := @OnCanvasMouseMove;
  PaintBox.OnMouseUp := @OnCanvasMouseUp;

  yPos := 8;
  LblLang := AddLabel('Sprache / Language:', yPos);
  CmbLang := TComboBox.Create(Self); CmbLang.Parent := SidePanel;
  CmbLang.SetBounds(135, yPos - 3, 107, 25); CmbLang.Style := csDropDownList;
  CmbLang.Items.Add('Deutsch'); CmbLang.Items.Add('English');
  CmbLang.ItemIndex := 0; CmbLang.OnChange := @OnParamChanged; Inc(yPos, 30);

  BtnRandom := TButton.Create(Self); BtnRandom.Parent := SidePanel;
  BtnRandom.SetBounds(12, yPos, 230, 26); BtnRandom.OnClick := @OnBtnRandomClick; Inc(yPos, 30);

  BtnRedraw := TButton.Create(Self); BtnRedraw.Parent := SidePanel;
  BtnRedraw.SetBounds(12, yPos, 112, 26); BtnRedraw.OnClick := @OnBtnRedrawClick;

  BtnPause := TButton.Create(Self); BtnPause.Parent := SidePanel;
  BtnPause.SetBounds(130, yPos, 112, 26); BtnPause.OnClick := @OnBtnPauseClick; Inc(yPos, 30);

  BtnSave := TButton.Create(Self); BtnSave.Parent := SidePanel;
  BtnSave.SetBounds(12, yPos, 230, 26); BtnSave.OnClick := @OnBtnSaveClick; Inc(yPos, 28);

  LblStatus := AddLabel('', yPos); Inc(yPos, 20);

  ChkAuto := TCheckBox.Create(Self); ChkAuto.Parent := SidePanel;
  ChkAuto.SetBounds(12, yPos, 115, 22); ChkAuto.Checked := FAutoCycle; ChkAuto.OnChange := @OnParamChanged;

  ChkWaveAnim := TCheckBox.Create(Self); ChkWaveAnim.Parent := SidePanel;
  ChkWaveAnim.SetBounds(130, yPos, 115, 22); ChkWaveAnim.Checked := FWaveAnim; ChkWaveAnim.OnChange := @OnParamChanged; Inc(yPos, 24);

  LblSpeed := AddLabel('', yPos); Inc(yPos, 16);
  TrkSpeed := AddTrack(1, 100, FSpeedMs, yPos); Inc(yPos, 28);

  LblFormula := AddLabel('', yPos); Inc(yPos, 16);
  CmbFormula := TComboBox.Create(Self); CmbFormula.Parent := SidePanel;
  CmbFormula.SetBounds(12, yPos, 230, 26); CmbFormula.Style := csDropDownList; CmbFormula.OnChange := @OnParamChanged; Inc(yPos, 30);

  LblPalette := AddLabel('', yPos); Inc(yPos, 16);
  CmbPalette := TComboBox.Create(Self); CmbPalette.Parent := SidePanel;
  CmbPalette.SetBounds(12, yPos, 230, 26); CmbPalette.Style := csDropDownList; CmbPalette.OnChange := @OnParamChanged; Inc(yPos, 30);

  LblGrid := AddLabel('', yPos); Inc(yPos, 16);
  TrkGrid := AddTrack(64, 1024, FGridSize - 1, yPos); Inc(yPos, 28);

  LblStep := AddLabel('', yPos); Inc(yPos, 16);
  TrkStep := AddTrack(1, 16, FStep, yPos); Inc(yPos, 28);

  LblWidth := AddLabel('', yPos); Inc(yPos, 16);
  TrkWidth := AddTrack(2, 14, FDx, yPos); Inc(yPos, 28);

  LblAmp := AddLabel('', yPos); Inc(yPos, 16);
  TrkAmp := AddTrack(50, 1200, Round(FAmp), yPos); Inc(yPos, 28);

  LblHue := AddLabel('', yPos); Inc(yPos, 16);
  TrkHue := AddTrack(0, 360, Round(FHue), yPos); Inc(yPos, 28);

  ChkMirror := TCheckBox.Create(Self); ChkMirror.Parent := SidePanel;
  ChkMirror.SetBounds(12, yPos, 115, 22); ChkMirror.Checked := FDoubleMirror; ChkMirror.OnChange := @OnParamChanged;

  ChkSphere := TCheckBox.Create(Self); ChkSphere.Parent := SidePanel;
  ChkSphere.SetBounds(130, yPos, 115, 22); ChkSphere.Checked := FSphereMode; ChkSphere.OnChange := @OnParamChanged; Inc(yPos, 24);

  LblYaw := AddLabel('', yPos); Inc(yPos, 16);
  TrkYaw := AddTrack(0, 360, Round(FYaw), yPos); Inc(yPos, 28);

  LblPitch := AddLabel('', yPos); Inc(yPos, 16);
  TrkPitch := AddTrack(-85, 85, Round(FPitch), yPos);
  ApplyLanguage;
end;

procedure TObskurForm.SyncControlsFromParams;
begin
  if UpdatingUI then Exit;
  UpdatingUI := True;
  ChkAuto.Checked := FAutoCycle;
  ChkWaveAnim.Checked := FWaveAnim;
  ChkMirror.Checked := FDoubleMirror;
  ChkSphere.Checked := FSphereMode;
  CmbFormula.ItemIndex := FMode;
  CmbPalette.ItemIndex := FPalette;
  TrkGrid.Position := FGridSize - 1;
  if FIsEnglish then LblGrid.Caption := Format('Resolution: %d x %d', [FGridSize - 1, FGridSize - 1]) else LblGrid.Caption := Format('Auflösung: %d x %d', [FGridSize - 1, FGridSize - 1]);
  TrkStep.Position := FStep;
  TrkWidth.Position := FDx;
  TrkAmp.Position := Round(FAmp);
  TrkHue.Position := Round(FHue);
  TrkYaw.Position := Round(FYaw);
  TrkPitch.Position := Round(FPitch);
  UpdatingUI := False;
end;

constructor TObskurForm.CreateNew(AOwner: TComponent; Num: Integer);
begin
  inherited CreateNew(AOwner, Num);
  Randomize;
  BufferBmp := TBitmap.Create; BufferBmp.SetSize(CANVAS_W, CANVAS_H);
  FCycle := 1; FSpeedMs := 25; FAutoCycle := True; FPaused := False;
  FGridSize := 129; FSphereMode := False; FWaveAnim := False;
  FYaw := 45.0; FPitch := 30.0; FPhase := 0.0;
  BuildUI;
  RandomizeParams;
  RestartDrawing(False);
  Timer := TTimer.Create(Self); Timer.Interval := 16; Timer.OnTimer := @OnTimerTick; Timer.Enabled := True;
end;

destructor TObskurForm.Destroy;
begin
  BufferBmp.Free;
  inherited Destroy;
end;

procedure TObskurForm.OnPaintCanvas(Sender: TObject);
begin
  PaintBox.Canvas.StretchDraw(Rect(0, 0, PaintBox.Width, PaintBox.Height), BufferBmp);
end;

procedure TObskurForm.OnTimerTick(Sender: TObject);
var
  k: Integer;
begin
  if FPaused then Exit;
  if not FFinished then
  begin
    Timer.Interval := 16;
    for k := 1 to Max(1, Round(Power(FSpeedMs / 25.0, 2.2) * Max(1.0, QuadCount / 150.0))) do
      if not FFinished then DrawNextQuad;
    PaintBox.Invalidate;
  end
  else if FWaveAnim then
  begin
    Timer.Interval := 30;
    FPhase := FPhase + 0.08;
    RestartDrawing(True, False);
  end
  else if FAutoCycle and (MilliSecondsBetween(Now, FinishedAt) >= 2000) then
  begin
    Inc(FCycle); RandomizeParams; RestartDrawing(False);
  end;
end;

procedure TObskurForm.OnCanvasMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  if Button = mbLeft then begin IsDragging := True; LastMouse := Point(X, Y); end;
end;

procedure TObskurForm.OnCanvasMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
begin
  if IsDragging then
  begin
    FAutoCycle := False;
    FYaw := FYaw + (X - LastMouse.X) * 0.5;
    if FYaw < 0 then FYaw := FYaw + 360.0;
    if FYaw >= 360.0 then FYaw := FYaw - 360.0;
    FPitch := EnsureRange(FPitch + (Y - LastMouse.Y) * 0.5, -85.0, 85.0);
    LastMouse := Point(X, Y);
    SyncControlsFromParams; RestartDrawing(True, True);
  end;
end;

procedure TObskurForm.OnCanvasMouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  if Button = mbLeft then IsDragging := False;
end;

procedure TObskurForm.OnBtnRandomClick(Sender: TObject);
begin
  Inc(FCycle); RandomizeParams; RestartDrawing(False);
end;

procedure TObskurForm.OnBtnRedrawClick(Sender: TObject);
begin
  RestartDrawing(False);
end;

procedure TObskurForm.OnBtnPauseClick(Sender: TObject);
begin
  FPaused := not FPaused;
  if FIsEnglish then begin if FPaused then BtnPause.Caption := 'Resume' else BtnPause.Caption := 'Pause'; end else begin if FPaused then BtnPause.Caption := 'Weiter' else BtnPause.Caption := 'Pause'; end;
end;

procedure TObskurForm.OnBtnSaveClick(Sender: TObject);
var
  png: TPortableNetworkGraphic;
  fname: string;
begin
  fname := Format('obskur_%d.png', [DateTimeToUnix(Now)]);
  png := TPortableNetworkGraphic.Create;
  try
    png.Assign(BufferBmp); png.SaveToFile(fname);
    if FIsEnglish then LblStatus.Caption := 'Saved: ' + fname else LblStatus.Caption := 'Gespeichert: ' + fname;
  finally
    png.Free;
  end;
end;

procedure TObskurForm.OnParamChanged(Sender: TObject);
begin
  if UpdatingUI then Exit;
  FSpeedMs := TrkSpeed.Position;
  if FIsEnglish then LblSpeed.Caption := Format('Speed: %d (1 = slow .. 100 = instant)', [FSpeedMs]) else LblSpeed.Caption := Format('Tempo: %d (1 = Zeitlupe .. 100 = sofort)', [FSpeedMs]);
  if Sender = CmbLang then begin FIsEnglish := (CmbLang.ItemIndex = 1); ApplyLanguage; Exit; end;
  if Sender = TrkSpeed then Exit;
  if Sender = ChkAuto then begin FAutoCycle := ChkAuto.Checked; Exit; end;
  if Sender = ChkWaveAnim then
  begin
    FWaveAnim := ChkWaveAnim.Checked;
    if FWaveAnim then begin FAutoCycle := False; ChkAuto.Checked := False; end;
    Exit;
  end;

  FAutoCycle := False; ChkAuto.Checked := False;
  FMode := CmbFormula.ItemIndex;
  FPalette := CmbPalette.ItemIndex;
  FGridSize := TrkGrid.Position + 1;
  if FIsEnglish then LblGrid.Caption := Format('Resolution: %d x %d', [FGridSize - 1, FGridSize - 1]) else LblGrid.Caption := Format('Auflösung: %d x %d', [FGridSize - 1, FGridSize - 1]);
  FStep := TrkStep.Position;
  FDx := TrkWidth.Position;
  FAmp := TrkAmp.Position;
  FHue := TrkHue.Position;
  FDoubleMirror := ChkMirror.Checked;
  FSphereMode := ChkSphere.Checked;
  FYaw := TrkYaw.Position;
  FPitch := TrkPitch.Position;
  RestartDrawing(True, True);
end;

var
  MainForm: TObskurForm;

begin
  Application.Scaled := True;
  Application.Initialize;
  Application.CreateForm(TObskurForm, MainForm);
  Application.Run;
end.
