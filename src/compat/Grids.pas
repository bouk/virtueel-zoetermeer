unit Grids;

{ Delphi 5-subset van de Grids-unit: TCustomGrid, TDrawGrid en TStringGrid met tekenen,
  selectie, scrollen en eenvoudig tekstbewerken op de cel. Alleen gebruikt door de
  spriteditor-formulieren van ROS.exe. }

{$MODE DELPHI}{$H+}

interface

uses Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, StdCtrls, ZMDraw;

type
  TGridOption = (goFixedVertLine, goFixedHorzLine, goVertLine, goHorzLine, goRangeSelect,
    goDrawFocusSelected, goRowSizing, goColSizing, goRowMoving, goColMoving, goEditing,
    goTabs, goRowSelect, goAlwaysShowEditor, goThumbTracking);
  TGridOptions = set of TGridOption;
  TGridDrawState = set of (gdSelected, gdFocused, gdFixed);
  TGridScrollDirection = set of (sdLeft, sdRight, sdUp, sdDown);
  TGridCoord = record
    X: Longint;
    Y: Longint;
  end;
  TGridRect = record
    case Integer of
      0: (Left, Top, Right, Bottom: Longint);
      1: (TopLeft, BottomRight: TGridCoord);
  end;
  TGridState = (gsNormal, gsSelecting, gsRowSizing, gsColSizing, gsRowMoving, gsColMoving);
  TEditStyle = (esSimple, esEllipsis, esPickList);

  TSelectCellEvent = procedure(Sender: TObject; ACol, ARow: Longint; var CanSelect: Boolean) of object;
  TDrawCellEvent = procedure(Sender: TObject; ACol, ARow: Longint; Rect: TRect; State: TGridDrawState) of object;
  TGetEditEvent = procedure(Sender: TObject; ACol, ARow: Longint; var Value: string) of object;
  TSetEditEvent = procedure(Sender: TObject; ACol, ARow: Longint; const Value: string) of object;
  TMovedEvent = procedure(Sender: TObject; FromIndex, ToIndex: Longint) of object;

  TCustomGrid = class(TCustomControl)
  private
    FBorderStyle: TBorderStyle;
    FColCount: Longint;
    FRowCount: Longint;
    FFixedCols: Integer;
    FFixedRows: Integer;
    FDefaultColWidth: Integer;
    FDefaultRowHeight: Integer;
    FColWidths: array of Integer;
    FRowHeights: array of Integer;
    FFixedColor: TColor;
    FGridLineWidth: Integer;
    FOptions: TGridOptions;
    FScrollBars: TScrollStyle;
    FCurrent: TGridCoord;
    FAnchor: TGridCoord;
    FTopLeft: TGridCoord;
    FDefaultDrawing: Boolean;
    FEditorMode: Boolean;
    FEditor: TEdit;
    FOnTopLeftChanged: TNotifyEvent;
    function GetColWidths(Index: Longint): Integer;
    function GetRowHeights(Index: Longint): Integer;
    function GetSelection: TGridRect;
    function GetVisibleColCount: Integer;
    function GetVisibleRowCount: Integer;
    procedure SetBorderStyle(Value: TBorderStyle);
    procedure SetCol(Value: Longint);
    procedure SetColCount(Value: Longint);
    procedure SetColWidths(Index: Longint; Value: Integer);
    procedure SetDefaultColWidth(Value: Integer);
    procedure SetDefaultRowHeight(Value: Integer);
    procedure SetEditorMode(Value: Boolean);
    procedure SetFixedColor(Value: TColor);
    procedure SetFixedCols(Value: Integer);
    procedure SetFixedRows(Value: Integer);
    procedure SetGridLineWidth(Value: Integer);
    procedure SetLeftCol(Value: Longint);
    procedure SetOptions(Value: TGridOptions);
    procedure SetRow(Value: Longint);
    procedure SetRowCount(Value: Longint);
    procedure SetRowHeights(Index: Longint; Value: Integer);
    procedure SetScrollBars(Value: TScrollStyle);
    procedure SetSelection(Value: TGridRect);
    procedure SetTopRow(Value: Longint);
    procedure ReadColWidths(Reader: TReader);
    procedure ReadRowHeights(Reader: TReader);
    procedure WriteColWidths(Writer: TWriter);
    procedure WriteRowHeights(Writer: TWriter);
    procedure WMGetDlgCode(var Msg: TWMGetDlgCode); message WM_GETDLGCODE;
    procedure WMMouseWheel(var Message: TWMMouseWheel); message WM_MOUSEWHEEL;
    procedure EditorKeyPress(Sender: TObject; var Key: Char);
    procedure EditorExit(Sender: TObject);
  protected
    FGridState: TGridState;
    function CanEditShow: Boolean; virtual;
    procedure ColWidthsChanged; dynamic;
    procedure CreateParams(var Params: TCreateParams); override;
    procedure DefineProperties(Filer: TFiler); override;
    procedure DrawCell(ACol, ARow: Longint; ARect: TRect; AState: TGridDrawState); virtual; abstract;
    function GetEditText(ACol, ARow: Longint): string; dynamic;
    procedure SetEditText(ACol, ARow: Longint; const Value: string); dynamic;
    procedure KeyDownDefault(var Message: TWMKey); override;
    procedure KeyPress(var Key: Char); override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MoveColRow(ACol, ARow: Longint; MoveAnchor, Show: Boolean);
    procedure Paint; override;
    procedure RowHeightsChanged; dynamic;
    function SelectCell(ACol, ARow: Longint): Boolean; virtual;
    procedure SizeChanged(OldColCount, OldRowCount: Longint); dynamic;
    procedure TopLeftChanged; dynamic;
    procedure HideEditor;
    procedure ShowEditor;
    property BorderStyle: TBorderStyle read FBorderStyle write SetBorderStyle default bsSingle;
    property Col: Longint read FCurrent.X write SetCol;
    property Color default clWindow;
    property ColCount: Longint read FColCount write SetColCount default 5;
    property ColWidths[Index: Longint]: Integer read GetColWidths write SetColWidths;
    property DefaultColWidth: Integer read FDefaultColWidth write SetDefaultColWidth default 64;
    property DefaultDrawing: Boolean read FDefaultDrawing write FDefaultDrawing default True;
    property DefaultRowHeight: Integer read FDefaultRowHeight write SetDefaultRowHeight default 24;
    property EditorMode: Boolean read FEditorMode write SetEditorMode;
    property FixedColor: TColor read FFixedColor write SetFixedColor default clBtnFace;
    property FixedCols: Integer read FFixedCols write SetFixedCols default 1;
    property FixedRows: Integer read FFixedRows write SetFixedRows default 1;
    property GridHeight: Integer read GetVisibleRowCount;
    property GridLineWidth: Integer read FGridLineWidth write SetGridLineWidth default 1;
    property GridWidth: Integer read GetVisibleColCount;
    property LeftCol: Longint read FTopLeft.X write SetLeftCol;
    property Options: TGridOptions read FOptions write SetOptions
      default [goFixedVertLine, goFixedHorzLine, goVertLine, goHorzLine, goRangeSelect];
    property ParentColor default False;
    property Row: Longint read FCurrent.Y write SetRow;
    property RowCount: Longint read FRowCount write SetRowCount default 5;
    property RowHeights[Index: Longint]: Integer read GetRowHeights write SetRowHeights;
    property ScrollBars: TScrollStyle read FScrollBars write SetScrollBars default ssBoth;
    property Selection: TGridRect read GetSelection write SetSelection;
    property TopRow: Longint read FTopLeft.Y write SetTopRow;
    property VisibleColCount: Integer read GetVisibleColCount;
    property VisibleRowCount: Integer read GetVisibleRowCount;
    property OnTopLeftChanged: TNotifyEvent read FOnTopLeftChanged write FOnTopLeftChanged;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    function CellRect(ACol, ARow: Longint): TRect;
    procedure MouseToCell(X, Y: Integer; var ACol, ARow: Longint);
    function MouseCoord(X, Y: Integer): TGridCoord;
    property Canvas;
    property TabStop default True;
  end;

  TCustomDrawGrid = class(TCustomGrid)
  private
    FOnDrawCell: TDrawCellEvent;
    FOnGetEditText: TGetEditEvent;
    FOnSetEditText: TSetEditEvent;
    FOnSelectCell: TSelectCellEvent;
    FOnColumnMoved: TMovedEvent;
    FOnRowMoved: TMovedEvent;
  protected
    procedure DrawCell(ACol, ARow: Longint; ARect: TRect; AState: TGridDrawState); override;
    function GetEditText(ACol, ARow: Longint): string; override;
    procedure SetEditText(ACol, ARow: Longint; const Value: string); override;
    function SelectCell(ACol, ARow: Longint): Boolean; override;
    property OnColumnMoved: TMovedEvent read FOnColumnMoved write FOnColumnMoved;
    property OnDrawCell: TDrawCellEvent read FOnDrawCell write FOnDrawCell;
    property OnGetEditText: TGetEditEvent read FOnGetEditText write FOnGetEditText;
    property OnRowMoved: TMovedEvent read FOnRowMoved write FOnRowMoved;
    property OnSelectCell: TSelectCellEvent read FOnSelectCell write FOnSelectCell;
    property OnSetEditText: TSetEditEvent read FOnSetEditText write FOnSetEditText;
  public
    property Col;
    property ColWidths;
    property EditorMode;
    property GridHeight;
    property GridWidth;
    property LeftCol;
    property Selection;
    property Row;
    property RowHeights;
    property TopRow;
  end;

  TDrawGrid = class(TCustomDrawGrid)
  published
    property Align;
    property Anchors;
    property BorderStyle;
    property Color;
    property ColCount;
    property Constraints;
    property Ctl3D;
    property DefaultColWidth;
    property DefaultRowHeight;
    property DefaultDrawing;
    property Enabled;
    property FixedColor;
    property FixedCols;
    property RowCount;
    property FixedRows;
    property Font;
    property GridLineWidth;
    property Options;
    property ParentColor;
    property ParentCtl3D;
    property ParentFont;
    property ParentShowHint;
    property PopupMenu;
    property ScrollBars;
    property ShowHint;
    property TabOrder;
    property TabStop;
    property Visible;
    property VisibleColCount;
    property VisibleRowCount;
    property OnClick;
    property OnColumnMoved;
    property OnDblClick;
    property OnDrawCell;
    property OnEnter;
    property OnExit;
    property OnGetEditText;
    property OnKeyDown;
    property OnKeyPress;
    property OnKeyUp;
    property OnMouseDown;
    property OnMouseMove;
    property OnMouseUp;
    property OnRowMoved;
    property OnSelectCell;
    property OnSetEditText;
    property OnTopLeftChanged;
  end;

  TStringGrid = class(TDrawGrid)
  private
    FCells: array of array of string;
    FObjects: array of array of TObject;
    FCols, FRows: array of TStringList;
    function GetCells(ACol, ARow: Integer): string;
    function GetObjects(ACol, ARow: Integer): TObject;
    function GetCols(Index: Integer): TStrings;
    function GetRows(Index: Integer): TStrings;
    procedure SetCells(ACol, ARow: Integer; const Value: string);
    procedure SetObjects(ACol, ARow: Integer; Value: TObject);
    procedure SetCols(Index: Integer; Value: TStrings);
    procedure SetRows(Index: Integer; Value: TStrings);
    procedure EnsureSize;
  protected
    procedure DrawCell(ACol, ARow: Longint; ARect: TRect; AState: TGridDrawState); override;
    function GetEditText(ACol, ARow: Longint): string; override;
    procedure SetEditText(ACol, ARow: Longint; const Value: string); override;
    procedure SizeChanged(OldColCount, OldRowCount: Longint); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    property Cells[ACol, ARow: Integer]: string read GetCells write SetCells;
    property Cols[Index: Integer]: TStrings read GetCols write SetCols;
    property Objects[ACol, ARow: Integer]: TObject read GetObjects write SetObjects;
    property Rows[Index: Integer]: TStrings read GetRows write SetRows;
  end;

implementation

uses Math;

{ ---------------------------------------------------------------- TCustomGrid }

constructor TCustomGrid.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := [csCaptureMouse, csOpaque, csDoubleClicks];
  Width := 320;
  Height := 120;
  TabStop := True;
  ParentColor := False;
  Color := clWindow;
  FBorderStyle := bsSingle;
  FColCount := 5;
  FRowCount := 5;
  FFixedCols := 1;
  FFixedRows := 1;
  FDefaultColWidth := 64;
  FDefaultRowHeight := 24;
  FFixedColor := clBtnFace;
  FGridLineWidth := 1;
  FOptions := [goFixedVertLine, goFixedHorzLine, goVertLine, goHorzLine, goRangeSelect];
  FScrollBars := ssBoth;
  FDefaultDrawing := True;
  FCurrent.X := 1;
  FCurrent.Y := 1;
  FAnchor := FCurrent;
  FTopLeft := FCurrent;
end;

destructor TCustomGrid.Destroy;
begin
  inherited Destroy;
end;

procedure TCustomGrid.CreateParams(var Params: TCreateParams);
begin
  inherited CreateParams(Params);
  if FBorderStyle = bsSingle then Params.ExStyle := Params.ExStyle or WS_EX_CLIENTEDGE;
end;

procedure TCustomGrid.ReadColWidths(Reader: TReader);
var
  I: Integer;
begin
  Reader.ReadListBegin;
  I := 0;
  while not Reader.EndOfList do
  begin
    SetColWidths(I, Reader.ReadInteger);
    Inc(I);
  end;
  Reader.ReadListEnd;
end;

procedure TCustomGrid.ReadRowHeights(Reader: TReader);
var
  I: Integer;
begin
  Reader.ReadListBegin;
  I := 0;
  while not Reader.EndOfList do
  begin
    SetRowHeights(I, Reader.ReadInteger);
    Inc(I);
  end;
  Reader.ReadListEnd;
end;

procedure TCustomGrid.WriteColWidths(Writer: TWriter);
var
  I: Integer;
begin
  Writer.WriteListBegin;
  for I := 0 to ColCount - 1 do Writer.WriteInteger(ColWidths[I]);
  Writer.WriteListEnd;
end;

procedure TCustomGrid.WriteRowHeights(Writer: TWriter);
var
  I: Integer;
begin
  Writer.WriteListBegin;
  for I := 0 to RowCount - 1 do Writer.WriteInteger(RowHeights[I]);
  Writer.WriteListEnd;
end;

procedure TCustomGrid.DefineProperties(Filer: TFiler);
begin
  inherited DefineProperties(Filer);
  Filer.DefineProperty('ColWidths', ReadColWidths, WriteColWidths, Length(FColWidths) > 0);
  Filer.DefineProperty('RowHeights', ReadRowHeights, WriteRowHeights, Length(FRowHeights) > 0);
end;

function TCustomGrid.GetColWidths(Index: Longint): Integer;
begin
  if (Index >= 0) and (Index < Length(FColWidths)) and (FColWidths[Index] >= 0) then
    Result := FColWidths[Index]
  else
    Result := FDefaultColWidth;
end;

function TCustomGrid.GetRowHeights(Index: Longint): Integer;
begin
  if (Index >= 0) and (Index < Length(FRowHeights)) and (FRowHeights[Index] >= 0) then
    Result := FRowHeights[Index]
  else
    Result := FDefaultRowHeight;
end;

procedure TCustomGrid.SetColWidths(Index: Longint; Value: Integer);
var
  I, Old: Integer;
begin
  if Index < 0 then Exit;
  if Index >= Length(FColWidths) then
  begin
    Old := Length(FColWidths);
    SetLength(FColWidths, Max(Index + 1, FColCount));
    for I := Old to High(FColWidths) do FColWidths[I] := -1;
  end;
  FColWidths[Index] := Value;
  ColWidthsChanged;
end;

procedure TCustomGrid.SetRowHeights(Index: Longint; Value: Integer);
var
  I, Old: Integer;
begin
  if Index < 0 then Exit;
  if Index >= Length(FRowHeights) then
  begin
    Old := Length(FRowHeights);
    SetLength(FRowHeights, Max(Index + 1, FRowCount));
    for I := Old to High(FRowHeights) do FRowHeights[I] := -1;
  end;
  FRowHeights[Index] := Value;
  RowHeightsChanged;
end;

procedure TCustomGrid.ColWidthsChanged;
begin
  Invalidate;
end;

procedure TCustomGrid.RowHeightsChanged;
begin
  Invalidate;
end;

procedure TCustomGrid.SizeChanged(OldColCount, OldRowCount: Longint);
begin
end;

procedure TCustomGrid.SetColCount(Value: Longint);
var
  Old: Longint;
begin
  if Value < 1 then Value := 1;
  if FColCount <> Value then
  begin
    Old := FColCount;
    FColCount := Value;
    if FFixedCols >= Value then FFixedCols := Value - 1;
    if FCurrent.X >= Value then FCurrent.X := Value - 1;
    SizeChanged(Old, FRowCount);
    Invalidate;
  end;
end;

procedure TCustomGrid.SetRowCount(Value: Longint);
var
  Old: Longint;
begin
  if Value < 1 then Value := 1;
  if FRowCount <> Value then
  begin
    Old := FRowCount;
    FRowCount := Value;
    if FFixedRows >= Value then FFixedRows := Value - 1;
    if FCurrent.Y >= Value then FCurrent.Y := Value - 1;
    SizeChanged(FColCount, Old);
    Invalidate;
  end;
end;

procedure TCustomGrid.SetFixedCols(Value: Integer);
begin
  if (Value >= 0) and (Value < FColCount) then
  begin
    FFixedCols := Value;
    if FCurrent.X < Value then FCurrent.X := Value;
    if FTopLeft.X < Value then FTopLeft.X := Value;
    Invalidate;
  end;
end;

procedure TCustomGrid.SetFixedRows(Value: Integer);
begin
  if (Value >= 0) and (Value < FRowCount) then
  begin
    FFixedRows := Value;
    if FCurrent.Y < Value then FCurrent.Y := Value;
    if FTopLeft.Y < Value then FTopLeft.Y := Value;
    Invalidate;
  end;
end;

procedure TCustomGrid.SetDefaultColWidth(Value: Integer);
begin
  FDefaultColWidth := Value;
  Invalidate;
end;

procedure TCustomGrid.SetDefaultRowHeight(Value: Integer);
begin
  FDefaultRowHeight := Value;
  Invalidate;
end;

procedure TCustomGrid.SetFixedColor(Value: TColor);
begin
  FFixedColor := Value;
  Invalidate;
end;

procedure TCustomGrid.SetGridLineWidth(Value: Integer);
begin
  FGridLineWidth := Value;
  Invalidate;
end;

procedure TCustomGrid.SetOptions(Value: TGridOptions);
begin
  FOptions := Value;
  Invalidate;
end;

procedure TCustomGrid.SetScrollBars(Value: TScrollStyle);
begin
  FScrollBars := Value;
  Invalidate;
end;

procedure TCustomGrid.SetBorderStyle(Value: TBorderStyle);
begin
  if FBorderStyle <> Value then
  begin
    FBorderStyle := Value;
    if HandleAllocated then RecreateWnd;
  end;
end;

procedure TCustomGrid.SetCol(Value: Longint);
begin
  MoveColRow(Value, FCurrent.Y, True, True);
end;

procedure TCustomGrid.SetRow(Value: Longint);
begin
  MoveColRow(FCurrent.X, Value, True, True);
end;

procedure TCustomGrid.SetLeftCol(Value: Longint);
begin
  if Value < FFixedCols then Value := FFixedCols;
  if Value >= FColCount then Value := FColCount - 1;
  if FTopLeft.X <> Value then
  begin
    FTopLeft.X := Value;
    TopLeftChanged;
    Invalidate;
  end;
end;

procedure TCustomGrid.SetTopRow(Value: Longint);
begin
  if Value < FFixedRows then Value := FFixedRows;
  if Value >= FRowCount then Value := FRowCount - 1;
  if FTopLeft.Y <> Value then
  begin
    FTopLeft.Y := Value;
    TopLeftChanged;
    Invalidate;
  end;
end;

procedure TCustomGrid.TopLeftChanged;
begin
  if Assigned(FOnTopLeftChanged) then FOnTopLeftChanged(Self);
end;

function TCustomGrid.GetSelection: TGridRect;
begin
  Result.Left := Min(FCurrent.X, FAnchor.X);
  Result.Right := Max(FCurrent.X, FAnchor.X);
  Result.Top := Min(FCurrent.Y, FAnchor.Y);
  Result.Bottom := Max(FCurrent.Y, FAnchor.Y);
  if goRowSelect in FOptions then
  begin
    Result.Left := FFixedCols;
    Result.Right := FColCount - 1;
  end;
end;

procedure TCustomGrid.SetSelection(Value: TGridRect);
begin
  FAnchor := Value.TopLeft;
  FCurrent := Value.BottomRight;
  Invalidate;
end;

function TCustomGrid.GetVisibleColCount: Integer;
var
  X, I: Integer;
begin
  X := 0;
  for I := 0 to FFixedCols - 1 do Inc(X, ColWidths[I] + FGridLineWidth);
  Result := 0;
  I := FTopLeft.X;
  while (I < FColCount) and (X + ColWidths[I] <= ClientWidth) do
  begin
    Inc(X, ColWidths[I] + FGridLineWidth);
    Inc(I);
    Inc(Result);
  end;
end;

function TCustomGrid.GetVisibleRowCount: Integer;
var
  Y, I: Integer;
begin
  Y := 0;
  for I := 0 to FFixedRows - 1 do Inc(Y, RowHeights[I] + FGridLineWidth);
  Result := 0;
  I := FTopLeft.Y;
  while (I < FRowCount) and (Y + RowHeights[I] <= ClientHeight) do
  begin
    Inc(Y, RowHeights[I] + FGridLineWidth);
    Inc(I);
    Inc(Result);
  end;
end;

function TCustomGrid.CellRect(ACol, ARow: Longint): TRect;
var
  X, Y, I: Integer;
begin
  Result := Rect(0, 0, 0, 0);
  if (ACol < 0) or (ARow < 0) or (ACol >= FColCount) or (ARow >= FRowCount) then Exit;
  if (ACol >= FFixedCols) and (ACol < FTopLeft.X) then Exit;
  if (ARow >= FFixedRows) and (ARow < FTopLeft.Y) then Exit;
  X := 0;
  for I := 0 to Min(ACol, FFixedCols) - 1 do Inc(X, ColWidths[I] + FGridLineWidth);
  if ACol >= FFixedCols then
    for I := FTopLeft.X to ACol - 1 do Inc(X, ColWidths[I] + FGridLineWidth);
  Y := 0;
  for I := 0 to Min(ARow, FFixedRows) - 1 do Inc(Y, RowHeights[I] + FGridLineWidth);
  if ARow >= FFixedRows then
    for I := FTopLeft.Y to ARow - 1 do Inc(Y, RowHeights[I] + FGridLineWidth);
  Result := Rect(X, Y, X + ColWidths[ACol], Y + RowHeights[ARow]);
end;

procedure TCustomGrid.MouseToCell(X, Y: Integer; var ACol, ARow: Longint);
var
  C: TGridCoord;
begin
  C := MouseCoord(X, Y);
  ACol := C.X;
  ARow := C.Y;
end;

function TCustomGrid.MouseCoord(X, Y: Integer): TGridCoord;
var
  I: Integer;
  R: TRect;
begin
  Result.X := -1;
  Result.Y := -1;
  for I := 0 to FColCount - 1 do
  begin
    R := CellRect(I, Max(FFixedRows, FTopLeft.Y));
    if (R.Right > R.Left) and (X >= R.Left) and (X < R.Right + FGridLineWidth) then Result.X := I;
  end;
  for I := 0 to FRowCount - 1 do
  begin
    R := CellRect(Max(FFixedCols, FTopLeft.X), I);
    if (R.Bottom > R.Top) and (Y >= R.Top) and (Y < R.Bottom + FGridLineWidth) then Result.Y := I;
  end;
end;

function TCustomGrid.SelectCell(ACol, ARow: Longint): Boolean;
begin
  Result := True;
end;

function TCustomGrid.CanEditShow: Boolean;
begin
  Result := goEditing in FOptions;
end;

function TCustomGrid.GetEditText(ACol, ARow: Longint): string;
begin
  Result := '';
end;

procedure TCustomGrid.SetEditText(ACol, ARow: Longint; const Value: string);
begin
end;

procedure TCustomGrid.MoveColRow(ACol, ARow: Longint; MoveAnchor, Show: Boolean);
begin
  if ACol < FFixedCols then ACol := FFixedCols;
  if ARow < FFixedRows then ARow := FFixedRows;
  if ACol >= FColCount then ACol := FColCount - 1;
  if ARow >= FRowCount then ARow := FRowCount - 1;
  if not SelectCell(ACol, ARow) then Exit;
  HideEditor;
  FCurrent.X := ACol;
  FCurrent.Y := ARow;
  if MoveAnchor then FAnchor := FCurrent;
  if Show then
  begin
    if ACol < FTopLeft.X then LeftCol := ACol
    else if ACol >= FTopLeft.X + Max(1, VisibleColCount) then LeftCol := ACol - Max(1, VisibleColCount) + 1;
    if ARow < FTopLeft.Y then TopRow := ARow
    else if ARow >= FTopLeft.Y + Max(1, VisibleRowCount) then TopRow := ARow - Max(1, VisibleRowCount) + 1;
  end;
  Invalidate;
end;

procedure TCustomGrid.Paint;
var
  C, R: Integer;
  Rc: TRect;
  State: TGridDrawState;
begin
  Canvas.Font := Font;
  Canvas.Brush.Color := Color;
  Canvas.FillRect(ClientRect);
  for R := 0 to FRowCount - 1 do
    for C := 0 to FColCount - 1 do
    begin
      Rc := CellRect(C, R);
      if (Rc.Right <= Rc.Left) or (Rc.Left >= ClientWidth) or (Rc.Top >= ClientHeight) then Continue;
      State := [];
      if (C < FFixedCols) or (R < FFixedRows) then
        Include(State, gdFixed)
      else
      begin
        with GetSelection do
          if (C >= Left) and (C <= Right) and (R >= Top) and (R <= Bottom) then
            if not ((C = FCurrent.X) and (R = FCurrent.Y)) or (goRowSelect in FOptions) or
              (goDrawFocusSelected in FOptions) then
              Include(State, gdSelected);
        if (C = FCurrent.X) and (R = FCurrent.Y) and Focused then Include(State, gdFocused);
      end;
      if FDefaultDrawing then
      begin
        if gdFixed in State then Canvas.Brush.Color := FFixedColor
        else if gdSelected in State then Canvas.Brush.Color := clHighlight
        else Canvas.Brush.Color := Color;
        Canvas.FillRect(Rc);
        if gdSelected in State then Canvas.Font.Color := clHighlightText else Canvas.Font.Color := Font.Color;
      end;
      DrawCell(C, R, Rc, State);
      if FDefaultDrawing and (gdFixed in State) then
        ZMFrame3D(Canvas, Rect(Rc.Left, Rc.Top, Rc.Right + 1, Rc.Bottom + 1), clBtnHighlight, clBtnShadow);
      if gdFocused in State then Canvas.DrawFocusRect(Rc);
      { rasterlijnen }
      if FGridLineWidth > 0 then
      begin
        Canvas.Pen.Color := clSilver;
        if (gdFixed in State) then Canvas.Pen.Color := clBlack;
        if ((gdFixed in State) and (goFixedVertLine in FOptions)) or (not (gdFixed in State) and (goVertLine in FOptions)) then
        begin
          Canvas.MoveTo(Rc.Right, Rc.Top);
          Canvas.LineTo(Rc.Right, Rc.Bottom + 1);
        end;
        if ((gdFixed in State) and (goFixedHorzLine in FOptions)) or (not (gdFixed in State) and (goHorzLine in FOptions)) then
        begin
          Canvas.MoveTo(Rc.Left, Rc.Bottom);
          Canvas.LineTo(Rc.Right + 1, Rc.Bottom);
        end;
      end;
    end;
end;

procedure TCustomGrid.WMGetDlgCode(var Msg: TWMGetDlgCode);
begin
  Msg.Result := DLGC_WANTARROWS or DLGC_WANTCHARS;
  if goTabs in FOptions then Msg.Result := Msg.Result or DLGC_WANTTAB;
end;

procedure TCustomGrid.WMMouseWheel(var Message: TWMMouseWheel);
begin
  if Message.WheelDelta > 0 then TopRow := TopRow - 1 else TopRow := TopRow + 1;
  Message.Result := 1;
end;

procedure TCustomGrid.KeyDownDefault(var Message: TWMKey);
begin
  case Message.CharCode of
    VK_UP: MoveColRow(FCurrent.X, FCurrent.Y - 1, True, True);
    VK_DOWN: MoveColRow(FCurrent.X, FCurrent.Y + 1, True, True);
    VK_LEFT: MoveColRow(FCurrent.X - 1, FCurrent.Y, True, True);
    VK_RIGHT: MoveColRow(FCurrent.X + 1, FCurrent.Y, True, True);
    VK_PRIOR: MoveColRow(FCurrent.X, FCurrent.Y - Max(1, VisibleRowCount), True, True);
    VK_NEXT: MoveColRow(FCurrent.X, FCurrent.Y + Max(1, VisibleRowCount), True, True);
    VK_HOME: MoveColRow(FFixedCols, FCurrent.Y, True, True);
    VK_END: MoveColRow(FColCount - 1, FCurrent.Y, True, True);
    VK_F2: if CanEditShow then ShowEditor;
  else
    inherited KeyDownDefault(Message);
  end;
end;

procedure TCustomGrid.KeyPress(var Key: Char);
begin
  inherited KeyPress(Key);
  if (Key >= ' ') and CanEditShow then
  begin
    ShowEditor;
    if FEditor <> nil then
    begin
      FEditor.Text := Key;
      FEditor.SelStart := 1;
    end;
    Key := #0;
  end;
end;

procedure TCustomGrid.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  Cell: TGridCoord;
begin
  if CanFocus and not Focused then SetFocus;
  Cell := MouseCoord(X, Y);
  if (Button = mbLeft) and (Cell.X >= FFixedCols) and (Cell.Y >= FFixedRows) then
  begin
    if (ssDouble in Shift) and CanEditShow then
      ShowEditor
    else
      MoveColRow(Cell.X, Cell.Y, not (ssShift in Shift) or not (goRangeSelect in FOptions), True);
  end;
  inherited MouseDown(Button, Shift, X, Y);
end;

procedure TCustomGrid.SetEditorMode(Value: Boolean);
begin
  if Value then ShowEditor else HideEditor;
end;

procedure TCustomGrid.ShowEditor;
var
  R: TRect;
begin
  if not CanEditShow then Exit;
  if FEditor = nil then
  begin
    FEditor := TEdit.Create(Self);
    FEditor.BorderStyle := bsNone;
    FEditor.OnKeyPress := EditorKeyPress;
    FEditor.OnExit := EditorExit;
    FEditor.Parent := Self;
  end;
  R := CellRect(FCurrent.X, FCurrent.Y);
  FEditor.SetBounds(R.Left, R.Top, R.Right - R.Left, R.Bottom - R.Top);
  FEditor.Font := Font;
  FEditor.Text := GetEditText(FCurrent.X, FCurrent.Y);
  FEditor.Visible := True;
  FEditor.SetFocus;
  FEditorMode := True;
end;

procedure TCustomGrid.HideEditor;
begin
  if FEditorMode and (FEditor <> nil) then
  begin
    FEditorMode := False;
    SetEditText(FCurrent.X, FCurrent.Y, FEditor.Text);
    FEditor.Visible := False;
    if CanFocus then SetFocus;
  end;
end;

procedure TCustomGrid.EditorKeyPress(Sender: TObject; var Key: Char);
begin
  if Key = #13 then
  begin
    HideEditor;
    Key := #0;
  end
  else if Key = #27 then
  begin
    FEditorMode := False;
    FEditor.Visible := False;
    if CanFocus then SetFocus;
    Key := #0;
  end;
end;

procedure TCustomGrid.EditorExit(Sender: TObject);
begin
  HideEditor;
end;

{ ---------------------------------------------------------------- TCustomDrawGrid }

procedure TCustomDrawGrid.DrawCell(ACol, ARow: Longint; ARect: TRect; AState: TGridDrawState);
begin
  if Assigned(FOnDrawCell) then FOnDrawCell(Self, ACol, ARow, ARect, AState);
end;

function TCustomDrawGrid.GetEditText(ACol, ARow: Longint): string;
begin
  Result := '';
  if Assigned(FOnGetEditText) then FOnGetEditText(Self, ACol, ARow, Result);
end;

procedure TCustomDrawGrid.SetEditText(ACol, ARow: Longint; const Value: string);
begin
  if Assigned(FOnSetEditText) then FOnSetEditText(Self, ACol, ARow, Value);
end;

function TCustomDrawGrid.SelectCell(ACol, ARow: Longint): Boolean;
begin
  Result := True;
  if Assigned(FOnSelectCell) then FOnSelectCell(Self, ACol, ARow, Result);
end;

{ ---------------------------------------------------------------- TStringGrid }

constructor TStringGrid.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  EnsureSize;
end;

destructor TStringGrid.Destroy;
var
  I: Integer;
begin
  for I := 0 to High(FCols) do FCols[I].Free;
  for I := 0 to High(FRows) do FRows[I].Free;
  inherited Destroy;
end;

procedure TStringGrid.EnsureSize;
var
  I: Integer;
begin
  if Length(FCells) <> ColCount then SetLength(FCells, ColCount);
  for I := 0 to High(FCells) do
    if Length(FCells[I]) <> RowCount then SetLength(FCells[I], RowCount);
  if Length(FObjects) <> ColCount then SetLength(FObjects, ColCount);
  for I := 0 to High(FObjects) do
    if Length(FObjects[I]) <> RowCount then SetLength(FObjects[I], RowCount);
end;

procedure TStringGrid.SizeChanged(OldColCount, OldRowCount: Longint);
begin
  EnsureSize;
end;

function TStringGrid.GetCells(ACol, ARow: Integer): string;
begin
  EnsureSize;
  if (ACol >= 0) and (ACol < ColCount) and (ARow >= 0) and (ARow < RowCount) then
    Result := FCells[ACol][ARow]
  else
    Result := '';
end;

procedure TStringGrid.SetCells(ACol, ARow: Integer; const Value: string);
begin
  EnsureSize;
  if (ACol >= 0) and (ACol < ColCount) and (ARow >= 0) and (ARow < RowCount) then
  begin
    FCells[ACol][ARow] := Value;
    Invalidate;
  end;
end;

function TStringGrid.GetObjects(ACol, ARow: Integer): TObject;
begin
  EnsureSize;
  if (ACol >= 0) and (ACol < ColCount) and (ARow >= 0) and (ARow < RowCount) then
    Result := FObjects[ACol][ARow]
  else
    Result := nil;
end;

procedure TStringGrid.SetObjects(ACol, ARow: Integer; Value: TObject);
begin
  EnsureSize;
  if (ACol >= 0) and (ACol < ColCount) and (ARow >= 0) and (ARow < RowCount) then
    FObjects[ACol][ARow] := Value;
end;

function TStringGrid.GetCols(Index: Integer): TStrings;
var
  I: Integer;
begin
  if Length(FCols) < ColCount then SetLength(FCols, ColCount);
  if FCols[Index] = nil then FCols[Index] := TStringList.Create;
  FCols[Index].Clear;
  for I := 0 to RowCount - 1 do FCols[Index].AddObject(Cells[Index, I], Objects[Index, I]);
  Result := FCols[Index];
end;

function TStringGrid.GetRows(Index: Integer): TStrings;
var
  I: Integer;
begin
  if Length(FRows) < RowCount then SetLength(FRows, RowCount);
  if FRows[Index] = nil then FRows[Index] := TStringList.Create;
  FRows[Index].Clear;
  for I := 0 to ColCount - 1 do FRows[Index].AddObject(Cells[I, Index], Objects[I, Index]);
  Result := FRows[Index];
end;

procedure TStringGrid.SetCols(Index: Integer; Value: TStrings);
var
  I: Integer;
begin
  for I := 0 to Min(Value.Count, RowCount) - 1 do Cells[Index, I] := Value[I];
end;

procedure TStringGrid.SetRows(Index: Integer; Value: TStrings);
var
  I: Integer;
begin
  for I := 0 to Min(Value.Count, ColCount) - 1 do Cells[I, Index] := Value[I];
end;

procedure TStringGrid.DrawCell(ACol, ARow: Longint; ARect: TRect; AState: TGridDrawState);
begin
  if DefaultDrawing then
  begin
    Canvas.Brush.Style := bsClear;
    Canvas.TextRect(ARect, ARect.Left + 2, ARect.Top + 2, Cells[ACol, ARow]);
    Canvas.Brush.Style := bsSolid;
  end;
  inherited DrawCell(ACol, ARow, ARect, AState);
end;

function TStringGrid.GetEditText(ACol, ARow: Longint): string;
begin
  Result := Cells[ACol, ARow];
  if Assigned(OnGetEditText) then OnGetEditText(Self, ACol, ARow, Result);
end;

procedure TStringGrid.SetEditText(ACol, ARow: Longint; const Value: string);
begin
  Cells[ACol, ARow] := Value;
  inherited SetEditText(ACol, ARow, Value);
end;

initialization
  RegisterClasses([TDrawGrid, TStringGrid]);
end.
