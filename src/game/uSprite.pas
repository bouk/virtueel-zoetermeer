unit uSprite;

{ TSprite: een geanimeerde bitmap op een TSpriteBox. Een sprite bezit een TFrameList (de
  beelden) en een TSequenceList (animaties); een TFastTimer doorloopt de
  huidige reeks. Alle wijzigingen van positie, frame, zichtbaarheid, marges en
  schaal lopen via ChangeState, dat ook OnMove en de trefcontrole aanroept.
  TBehaviour-objecten die aan een sprite zijn gekoppeld, krijgen eerst de
  gebeurtenissen van de sprite.
  Gedecompileerd uit ROS.exe v1.1, code 0046956C-0046C478. }

{$I zm.inc}
{$R+}   { het origineel is gecompileerd met bereikcontrole aan (@BoundErr na Round) }

interface

uses
  Windows, SysUtils, Classes, Graphics, Controls,
  uSurface, uPixie, Sprframe, uSequence, uSpritebox, uTiming;

type
  ESprite = class(Exception);

  TSprite = class;
  TBehaviour = class;
  TBehaviourList = class;

  THitTest = (htNone, htRect, htPixel);

  { De RTTI plaatst TPlot/TPlotMode in Sprframe, dat ze niet declareert. }
  TPlot = (BufferBackground, PlotTransparent);
  TPlotMode = set of TPlot;

  { Wat een aanroep van ChangeState wijzigt terwijl er al een wijziging bezig is }
  TSpriteChange = (scX, scY, scZ, scMarginLeft, scMarginTop, scMarginRight,
    scMarginBottom, scFrameIndex, scVisible, scScale);
  TSpriteChanges = set of TSpriteChange;

  TOnFinishSequence = procedure(Sender: TObject; var RepeatCount: Integer) of object;
  TOnVisibleEvent = procedure(Sender: TObject; var NewVisible: Boolean) of object;
  TOnMoveEvent = procedure(Sender: TObject; var X, Y, Z: Integer) of object;
  TOnHitEvent = procedure(Sender: TObject; HitWhom: TSprite) of object;
  TOnSkipFrameEvent = procedure(Sender: TObject; var Continue: Boolean) of object;
  TOnBlitEvent = procedure(Sender: TObject; Surface: TSurface; X, Y: Integer;
    Where: TRect; Size: Real) of object;

  TSprite = class(TPixie)
  private
    FAbout: string;                    { +0x68  gestreamde versie, bijv. '2.5c' }
    FSpriteBox: TSpriteBox;            { +0x6C }
    FFrameList: TFrameList;            { +0x70 }
    FSequenceList: TSequenceList;      { +0x74 }
    FSequence: TSequence;              { +0x78  sequence being played }
    FReserved7C: Integer;              { +0x7C  niet gebruikt }
    FPlotmode: TPlotMode;              { +0x80 }
    FFrameIndex: Integer;              { +0x84 }
    FTimer: TFastTimer;                { +0x88 }
    FRepeatCount: Integer;             { +0x8C  -1: voor altijd }
    FStep: Integer;                    { +0x90  stap binnen FSequence }
    FDynamic: Boolean;                 { +0x94  gemaakt door CreateCopy: lijsten worden gedeeld }
    FKilled: Boolean;                  { +0x95  vrijgeven bij de eerstvolgende gelegenheid }
    FHitTest: THitTest;                { +0x96 }
    FReserved98: Integer;              { +0x98  op 0 gezet, nooit gelezen }
    FMirrorY: Boolean;                 { +0x9C }
    FMirrorX: Boolean;                 { +0x9D }
    FReserved9E: Boolean;              { +0x9E  gekopieerd door CreateCopy, nooit gelezen }
    FFrozen: Boolean;                  { +0x9F  animatie gepauzeerd }
    FStopped: Boolean;                 { +0xA0  StopSequence is aangeroepen }
    FScale: Double;                    { +0xA8 }
    FData: TObject;                    { +0xB0  owned user object }
    FMarginLeft: Integer;              { +0xB4 }
    FMarginRight: Integer;             { +0xB8 }
    FMarginTop: Integer;               { +0xBC }
    FMarginBottom: Integer;            { +0xC0 }
    FLastFrame: string;                { +0xC4  framenaam bij de laatste GetChange }
    FMouseCapture: Boolean;            { +0xC8 }
    FNewX: Integer;                    { +0xCC  pending state of ChangeState }
    FNewY: Integer;                    { +0xD0 }
    FNewZ: Integer;                    { +0xD4 }
    FNewFrameIndex: Integer;           { +0xD8 }
    FNewVisible: Boolean;              { +0xDC }
    FNewScale: Double;                 { +0xE0 }
    FNewMarginLeft: Integer;           { +0xE8 }
    FNewMarginRight: Integer;          { +0xEC }
    FNewMarginTop: Integer;            { +0xF0 }
    FNewMarginBottom: Integer;         { +0xF4 }
    FChanging: Boolean;                { +0xF8 }
    FForceRedraw: Boolean;             { +0xF9 }
    FReservedFC: Integer;              { +0xFC  niet gebruikt }
    FOnVisible: TOnVisibleEvent;       { +0x100 }
    FOnMove: TOnMoveEvent;             { +0x108 }
    FOnFinishSequence: TOnFinishSequence; { +0x110 }
    FOnHit: TOnHitEvent;               { +0x118 }
    FOnBeforeBlit: TOnBlitEvent;       { +0x120 }
    FOnAfterBlit: TOnBlitEvent;        { +0x128 }
    FOnFrameSkipped: TOnSkipFrameEvent; { +0x130 }
    FBehaviours: TBehaviourList;       { +0x138 }
    procedure TimerSkip(Sender: TObject);
    procedure TimerTick(Sender: TObject);
    function GetAbout: string;
    function GetTransparent: TColor;
    procedure SetTransparent(Value: TColor);
    procedure SetSpriteBox(Value: TSpriteBox);
    procedure SetFrameList(Value: TFrameList);
    procedure SetSequenceList(Value: TSequenceList);
    function GetCurrentFrame: TName;
    procedure SetCurrentFrame(Value: TName);
    procedure SetFrameIndex(Value: Integer);
    procedure SetMirrorX(Value: Boolean);
    procedure SetMirrorY(Value: Boolean);
    procedure SetPriority(Value: Integer);
    function GetPriority: Integer;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    { TPixie }
    procedure SetVisible(Value: Boolean); override;
    procedure SetX(Value: Integer); override;
    procedure SetY(Value: Integer); override;
    procedure SetZ(Value: Integer); override;
    function GetX: Integer; override;
    function GetY: Integer; override;
    procedure SetLeft(Value: Integer); override;
    procedure SetTop(Value: Integer); override;
    function GetWidth: Integer; override;
    function GetHeight: Integer; override;
    procedure Draw(Surface: TSurface; DX, DY: Integer; ClipRect: TRect;
      Scale: Double); override;
    procedure DrawDC(DC: HDC; DX, DY: Integer; ClipRect: TRect;
      Scale: Double); override;
    procedure GetChange(var OldState, NewState: TPixieState); override;
    procedure MouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState;
      X, Y: Integer); override;
    procedure MouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState;
      X, Y: Integer); override;
    procedure MouseMove(Sender: TObject; Shift: TShiftState;
      X, Y: Integer); override;
    procedure MouseLeave; override;
    { nieuwe virtuele methoden }
    function GetHotSpotX: Integer; virtual;                             { +0x88 }
    function GetHotSpotY: Integer; virtual;                             { +0x8C }
    function GetScale: Double; virtual;                                 { +0x90 }
    procedure DoVisible(var NewVisible: Boolean); virtual;              { +0x94 }
    procedure DoMove(var X, Y, Z: Integer); virtual;                    { +0x98 }
    procedure DoFinishSequence(var RepeatCount: Integer); virtual;      { +0x9C }
    procedure DoHit; virtual;                                           { +0xA0 }
    procedure DoFrameSkipped(var Continue: Boolean); virtual;           { +0xA4 }
    procedure DoAfterBlit(Surface: TSurface; X, Y: Integer; Where: TRect;
      Size: Real); virtual;                                             { +0xA8 }
    procedure DoBeforeBlit(Surface: TSurface; X, Y: Integer; Where: TRect;
      Size: Real); virtual;                                             { +0xAC }
    procedure ChangeState(AX, AY, AZ, AMarginLeft, AMarginTop, AMarginRight,
      AMarginBottom, AFrameIndex: Integer; AVisible: Boolean; AScale: Double;
      Changes: TSpriteChanges); virtual;                                { +0xB0 }
    constructor CreateCopy(Source: TSprite); virtual;                   { +0xB4 }
    { statische methoden }
    procedure Kill;
    procedure Redraw;
    procedure MoveTo(AX, AY: Integer);
    procedure MoveTo3D(AX, AY, AZ: Integer);
    procedure MoveBy(DX, DY, DZ: Integer);
    procedure PlaySequence(Name: string; RepeatCount: Integer);
    procedure PlaySequenceAt(Name: string; RepeatCount: Integer; DX, DY: Integer);
    procedure StopSequence;
    function GetSurface: TSurface;
    function GetSequence: TName;
    procedure SetSequence(Value: TName);
    procedure SetMouseCapture(Value: Boolean);
    procedure SetZOrder(Value: Integer);
    procedure SetMarginLeft(Value: Integer);
    procedure SetMarginTop(Value: Integer);
    procedure SetMarginRight(Value: Integer);
    procedure SetMarginBottom(Value: Integer);
    procedure SetScale(Value: Double);
    function GetFrozen: Boolean;
    function GetBehaviour(Name: string): TBehaviour;
    procedure AddBehaviour(Name: string; Behaviour: TBehaviour);
    property Version: string read FAbout;
    property CurSequence: TSequence read FSequence;
    property Sequence: TName read GetSequence write SetSequence;
    property Timer: TFastTimer read FTimer;
    property RepeatCount: Integer read FRepeatCount write FRepeatCount;
    property Step: Integer read FStep write FStep;
    property Dynamic: Boolean read FDynamic;
    property Killed: Boolean read FKilled;
    property Frozen: Boolean read GetFrozen write FFrozen;
    property Stopped: Boolean read FStopped write FStopped;
    property Scale: Double read GetScale write SetScale;
    property Data: TObject read FData write FData;
    property MarginLeft: Integer read FMarginLeft write SetMarginLeft;
    property MarginTop: Integer read FMarginTop write SetMarginTop;
    property MarginRight: Integer read FMarginRight write SetMarginRight;
    property MarginBottom: Integer read FMarginBottom write SetMarginBottom;
    property MouseCapture: Boolean read FMouseCapture write SetMouseCapture;
    property Showing: Boolean read FNewVisible;
    property Changing: Boolean read FChanging;
    property Behaviours: TBehaviourList read FBehaviours;
  published
    property About: string read GetAbout write FAbout;
    property Transparent: TColor read GetTransparent write SetTransparent;
    property HitTest: THitTest read FHitTest write FHitTest;
    property Plotmode: TPlotMode read FPlotmode write FPlotmode default [BufferBackground, PlotTransparent];
    property FrameList: TFrameList read FFrameList write SetFrameList;
    property Priority: Integer read GetPriority write SetPriority;
    property SpriteBox: TSpriteBox read FSpriteBox write SetSpriteBox;
    property SequenceList: TSequenceList read FSequenceList write SetSequenceList;
    property CurrentFrame: TName read GetCurrentFrame write SetCurrentFrame;
    property FrameIndex: Integer read FFrameIndex write SetFrameIndex;
    property MirrorX: Boolean read FMirrorX write SetMirrorX;
    property MirrorY: Boolean read FMirrorY write SetMirrorY;
    property HotSpotX: Integer read GetHotSpotX;
    property HotSpotY: Integer read GetHotSpotY;
    property OnMove: TOnMoveEvent read FOnMove write FOnMove;
    property OnFinishSequence: TOnFinishSequence read FOnFinishSequence write FOnFinishSequence;
    property OnHit: TOnHitEvent read FOnHit write FOnHit;
    property OnBeforeBlit: TOnBlitEvent read FOnBeforeBlit write FOnBeforeBlit;
    property OnAfterBlit: TOnBlitEvent read FOnAfterBlit write FOnAfterBlit;
    property OnVisible: TOnVisibleEvent read FOnVisible write FOnVisible;
    property OnFrameSkipped: TOnSkipFrameEvent read FOnFrameSkipped write FOnFrameSkipped;
  end;

  TSpriteList = class(TList)
  public
    function Add(Sprite: TSprite): TSprite;
    function SpriteByName(Name: string): TSprite;
    function GetSprite(Index: Integer): TSprite;
    property Sprites[Index: Integer]: TSprite read GetSprite; default;
  end;

  { Gedrag gekoppeld aan een sprite: ontvangt de gebeurtenissen van de sprite (zolang
    Active waar is) voor de eigen gebeurtenis-handlers van de sprite. }
  TBehaviour = class(TObject)
  protected
    FName: string;                     { +0x04 }
    FSprite: TSprite;                  { +0x08 }
    FActive: Boolean;                  { +0x0C }
    FOnFinish: TNotifyEvent;           { +0x10 }
    FNextBehaviour: string;            { +0x18  geactiveerd door Finish }
  public
    constructor Create;
    destructor Destroy; override;
    procedure FinishSequence(Sender: TObject; var RepeatCount: Integer); virtual;   { +0x00 }
    procedure Hit(Sender: TObject; HitWhom: TSprite); virtual;                      { +0x04 }
    procedure Move(Sender: TObject; var X, Y, Z: Integer); virtual;                 { +0x08 }
    procedure AfterBlit(Sender: TObject; Surface: TSurface; X, Y: Integer;
      Where: TRect; Size: Real); virtual;                                           { +0x0C }
    procedure BeforeBlit(Sender: TObject; Surface: TSurface; X, Y: Integer;
      Where: TRect; Size: Real); virtual;                                           { +0x10 }
    procedure VisibleChange(Sender: TObject; var NewVisible: Boolean); virtual;     { +0x14 }
    procedure MouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState;
      X, Y: Integer); virtual;                                                      { +0x18 }
    procedure MouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState;
      X, Y: Integer); virtual;                                                      { +0x1C }
    procedure MouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer); virtual; { +0x20 }
    procedure MouseLeave(Sender: TObject); virtual;                                 { +0x24 }
    procedure SetSprite(Value: TSprite); virtual;                                   { +0x28 }
    procedure Detach; virtual;                                                      { +0x2C }
    procedure Finish; virtual;                                                      { +0x30 }
    procedure SetActive(Value: Boolean); virtual;                                   { +0x34 }
    property Name: string read FName write FName;
    property Sprite: TSprite read FSprite;
    property Active: Boolean read FActive write SetActive;
    property OnFinish: TNotifyEvent read FOnFinish write FOnFinish;
    property NextBehaviour: string read FNextBehaviour write FNextBehaviour;
  end;

  TBehaviourList = class(TList)
  public
    function Add(Behaviour: TBehaviour): TBehaviour;
    function GetBehaviour(Index: Integer): TBehaviour;
    function Find(Name: string): TBehaviour;
    function Remove(Behaviour: TBehaviour): Integer;
    procedure ClearItem(Index: Integer);
    procedure Pack;
    function IsActive(Index: Integer): Boolean;
    property Items[Index: Integer]: TBehaviour read GetBehaviour; default;
  end;

implementation

uses
  uString;

{$J+}
const
  SpriteMotto: string = 'odi et amo';    { 00488E70  nooit gebruikt }
  SpriteMotto2: string = 'dmo';          { 00488E74  nooit gebruikt }
{$J-}

{ -------------------------------------------------------------------- TSprite }

{ @00469D70 }
constructor TSprite.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FReserved98 := 0;
  FFrameList := TFrameList.Create(clBlack);
  FSequenceList := TSequenceList.Create(Self);
  FPlotmode := [BufferBackground, PlotTransparent];
  FFrozen := False;
  inherited SetX(0);
  inherited SetY(0);
  inherited SetZ(0);
  FFrameIndex := -1;
  SetVisible(False);
  FTimer := TFastTimer.Create(Self);
  FTimer.SyncRetrace := True;
  FSequence := nil;
  FTimer.Enabled := False;
  FTimer.OnTimer := TimerTick;
  FTimer.OnSkipTimer := TimerSkip;
  FDynamic := False;
  FKilled := False;
  FReserved9E := False;
  FScale := 1.0;
  FAbout := '2.5c';
  SetTransparent(clBlue);
  FBehaviours := TBehaviourList.Create;
end;

{ @00469ECC  een sprite die de frames en reeksen van Source deelt }
constructor TSprite.CreateCopy(Source: TSprite);
var
  S: TName;
begin
  Create(Source.Owner);
  SetTransparent(Source.GetTransparent);
  FSequenceList.Free;
  FFrameList.Free;
  FSequenceList := Source.FSequenceList;
  FFrameList := Source.FFrameList;
  FDynamic := True;
  SetSpriteBox(Source.FSpriteBox);
  inherited SetX(Source.GetX);
  inherited SetY(Source.GetY);
  SetZOrder(Source.GetZ);
  FHitTest := Source.FHitTest;
  S := Source.GetSequence;
  SetSequence(S);
  FRepeatCount := Source.FRepeatCount;
  FAbout := Source.GetAbout;
  SetFrameIndex(Source.FFrameIndex);
  SetMirrorX(Source.FMirrorX);
  SetMirrorY(Source.FMirrorY);
  FPlotmode := Source.FPlotmode;
  FFrozen := Source.GetFrozen;
  FReserved9E := Source.FReserved9E;
  SetScale(Source.GetScale);
  Tag := Source.Tag;
  SetMarginLeft(Source.FMarginLeft);
  SetMarginRight(Source.FMarginRight);
  SetMarginTop(Source.FMarginTop);
  SetMarginBottom(Source.FMarginBottom);
  FOnMove := Source.FOnMove;
  FOnFinishSequence := Source.FOnFinishSequence;
  FOnHit := Source.FOnHit;
  FOnBeforeBlit := Source.FOnBeforeBlit;
  FOnAfterBlit := Source.FOnAfterBlit;
  FOnVisible := Source.FOnVisible;
  OnMouseDown := Source.OnMouseDown;
  OnMouseUp := Source.OnMouseUp;
  OnMouseMove := Source.OnMouseMove;
  OnMouseLeave := Source.OnMouseLeave;
end;

{ @0046A150 }
destructor TSprite.Destroy;
var
  B: TBehaviour;
begin
  FKilled := False;
  if FSpriteBox <> nil then
    FSpriteBox.RemovePixie(Self);
  if FData <> nil then
    FData.Free;
  while FBehaviours.Count <> 0 do
  begin
    B := TBehaviour(TList(FBehaviours).Items[FBehaviours.Count - 1]);
    FBehaviours.ClearItem(FBehaviours.Count - 1);
    FBehaviours.Pack;
    if B <> nil then
    begin
      B.Detach;
      B.Free;
    end;
  end;
  if not FDynamic then
  begin
    FFrameList.Free;
    FSequenceList.Clear;
    FSequenceList.Free;
  end;
  FTimer.Enabled := False;
  FTimer.Free;
  inherited Destroy;
end;

{ @0046A220  de sprite geeft zichzelf vrij bij de volgende timertik of hertekening }
procedure TSprite.Kill;
begin
  FKilled := True;
end;

{ @0046A228 }
procedure TSprite.Redraw;
begin
  if Visible then
  begin
    FForceRedraw := True;
    ChangeState(GetX, GetY, GetZ, FMarginLeft, FMarginTop, FMarginRight,
      FMarginBottom, FFrameIndex, Visible, GetScale, []);
  end;
end;

{ @0046A2A4 }
procedure TSprite.MoveTo(AX, AY: Integer);
begin
  ChangeState(AX, AY, GetZ, FMarginLeft, FMarginTop, FMarginRight,
    FMarginBottom, FFrameIndex, Visible, GetScale, [scX, scY]);
end;

{ @0046A30C }
procedure TSprite.MoveTo3D(AX, AY, AZ: Integer);
begin
  ChangeState(AX, AY, AZ, FMarginLeft, FMarginTop, FMarginRight,
    FMarginBottom, FFrameIndex, Visible, GetScale, [scX, scY, scZ]);
end;

{ @0046A374 }
procedure TSprite.MoveBy(DX, DY, DZ: Integer);
begin
  MoveTo3D(GetX + DX, GetY + DY, GetZ + DZ);
end;

{ @0046A3B0 }
procedure TSprite.PlaySequence(Name: string; RepeatCount: Integer);
begin
  PlaySequenceAt(Name, RepeatCount, 0, 0);
end;

{ @0046A408  Name mag 'reeks:stap' zijn om bij een gegeven stap te starten;
  RepeatCount -1 herhaalt voor altijd; DX, DY verschuiven de sprite eenmalig. }
procedure TSprite.PlaySequenceAt(Name: string; RepeatCount: Integer; DX, DY: Integer);
var
  Rest: string;
  P, StartStep: Integer;
  NewFrame, SDX, SDY, SDZ: Integer;
  Delay: Double;
  BaseX, BaseY: Integer;
begin
  if FSequenceList.IndexOf(Name) = -1 then
  begin
    P := Pos(':', Name);   { LET OP: resultaat wordt niet gebruikt }
    Rest := Name;
    Name := SplitFirst(Rest, ':');
    StartStep := StrToIntDef0(Rest);
  end
  else
    StartStep := 0;
  SetSequence(Name);
  FRepeatCount := RepeatCount;
  FStep := StartStep;
  FTimer.Enabled := True;
  { LET OP: de offsets van de stap worden hier niet gebruikt }
  FSequence.GetStep(FStep, NewFrame, SDX, SDY, SDZ, Delay);
  if FChanging then
  begin
    BaseX := FNewX;
    BaseY := FNewY;
  end
  else
  begin
    BaseX := GetX;
    BaseY := GetY;
  end;
  ChangeState(DX + BaseX, DY + BaseY, GetZ, FMarginLeft, FMarginTop, FMarginRight,
    FMarginBottom, NewFrame, Visible, GetScale, [scX, scY, scFrameIndex]);
  FTimer.Interval := Round(Delay * 1000);
end;

{ @0046A5D4 }
procedure TSprite.StopSequence;
begin
  FStopped := True;
  FTimer.Enabled := False;
end;

{ @0046A5EC }
procedure TSprite.DoVisible(var NewVisible: Boolean);
begin
  if Assigned(FOnVisible) then
    FOnVisible(Self, NewVisible);
end;

{ @0046A60C }
procedure TSprite.DoMove(var X, Y, Z: Integer);
var
  I: Integer;
begin
  for I := FBehaviours.Count - 1 downto 0 do
    if FBehaviours.IsActive(I) then
      FBehaviours[I].Move(Self, X, Y, Z);
  if Assigned(FOnMove) then
    FOnMove(Self, X, Y, Z);
  FBehaviours.Pack;
end;

{ @0046A69C }
procedure TSprite.DoFinishSequence(var RepeatCount: Integer);
var
  I: Integer;
begin
  for I := FBehaviours.Count - 1 downto 0 do
    if FBehaviours.IsActive(I) then
      FBehaviours[I].FinishSequence(Self, RepeatCount);
  if Assigned(FOnFinishSequence) then
  begin
    FStopped := False;
    FOnFinishSequence(Self, FRepeatCount);
    if FStopped then
      Exit;
  end;
  FBehaviours.Pack;
end;

{ @0046A720 }
procedure TSprite.DoHit;
var
  I: Integer;
  Other: TSprite;
  R: TRect;
begin
  if Assigned(FOnHit) then
  begin
    if FHitTest in [htRect, htPixel] then
      for I := 0 to FSpriteBox.Count - 1 do
      begin
        if I >= FSpriteBox.Count then
          Break;
        Other := FSpriteBox.Items[I] as TSprite;
        if (Self <> Other) and Other.Visible then
          if IntersectRect(R, GetBoundsRect, Other.GetBoundsRect) and
            (FHitTest = htRect) then
            FOnHit(Self, Other);
      end;
    FBehaviours.Pack;
  end;
end;

{ @0046A7EC }
procedure TSprite.DoAfterBlit(Surface: TSurface; X, Y: Integer; Where: TRect;
  Size: Real);
var
  I: Integer;
begin
  for I := FBehaviours.Count - 1 downto 0 do
    if FBehaviours.IsActive(I) then
      FBehaviours[I].AfterBlit(Self, Surface, X, Y, Where, Size);
  if Assigned(FOnAfterBlit) then
    FOnAfterBlit(Self, Surface, X, Y,
      Rect(Where.Left + X, Where.Top + Y, Where.Left + X + Round(GetWidth * Size),
        Where.Top + Y + Round(GetHeight * Size)), Size);
  FBehaviours.Pack;
end;

{ @0046A924 }
procedure TSprite.DoBeforeBlit(Surface: TSurface; X, Y: Integer; Where: TRect;
  Size: Real);
var
  I: Integer;
begin
  for I := FBehaviours.Count - 1 downto 0 do
    if FBehaviours.IsActive(I) then
      FBehaviours[I].BeforeBlit(Self, Surface, X, Y, Where, Size);
  if Assigned(FOnBeforeBlit) then
    FOnBeforeBlit(Self, Surface, X, Y, Where, Size);
  FBehaviours.Pack;
end;

{ @0046A9D4  zoals TPixie.GetChange, maar een gewijzigd frame of Redraw telt ook mee }
procedure TSprite.GetChange(var OldState, NewState: TPixieState);
var
  State: TPixieState;
begin
  OldState := FState;
  GetState(State);
  FState := State;
  NewState := FState;
  if (NewState.Left = OldState.Left) and (NewState.Top = OldState.Top) and
    (NewState.Z = OldState.Z) and (NewState.Width = OldState.Width) and
    (NewState.Height = OldState.Height) and (FLastFrame = GetCurrentFrame) and
    (NewState.Visible = OldState.Visible) and not FForceRedraw then
  begin
    NewState.Visible := False;
    OldState.Visible := False;
  end;
  FForceRedraw := False;
  FLastFrame := GetCurrentFrame;
  if FKilled then
    Free;
end;

{ @0046AAE8 }
procedure TSprite.DoFrameSkipped(var Continue: Boolean);
begin
  if Assigned(FOnFrameSkipped) then
  begin
    Continue := True;
    FOnFrameSkipped(Self, Continue);
    if Continue then
      ;   { LET OP: het resultaat wordt getest maar niet gebruikt }
  end;
end;

{ @0046AB14 }
procedure TSprite.MouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
var
  I: Integer;
begin
  for I := FBehaviours.Count - 1 downto 0 do
    if FBehaviours.IsActive(I) then
      FBehaviours[I].MouseMove(Self, Shift, X, Y);
  if Assigned(OnMouseMove) then
    OnMouseMove(Self, Shift, X, Y);
  FBehaviours.Pack;
end;

{ @0046AB94 }
procedure TSprite.MouseLeave;
var
  I: Integer;
begin
  for I := FBehaviours.Count - 1 downto 0 do
    if FBehaviours.IsActive(I) then
      FBehaviours[I].MouseLeave(Self);
  if Assigned(OnMouseLeave) then
    OnMouseLeave(Self);
  FBehaviours.Pack;
end;

{ @0046ABF0 }
procedure TSprite.MouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
var
  I: Integer;
begin
  for I := FBehaviours.Count - 1 downto 0 do
    if FBehaviours.IsActive(I) then
      FBehaviours[I].MouseDown(Self, Button, Shift, X, Y);
  if Assigned(OnMouseDown) then
    OnMouseDown(Self, Button, Shift, X, Y);
  FBehaviours.Pack;
end;

{ @0046AC78 }
procedure TSprite.MouseUp(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
var
  I: Integer;
begin
  for I := FBehaviours.Count - 1 downto 0 do
    if FBehaviours.IsActive(I) then
      FBehaviours[I].MouseUp(Self, Button, Shift, X, Y);
  if Assigned(OnMouseUp) then
    OnMouseUp(Self, Button, Shift, X, Y);
  FBehaviours.Pack;
end;

{ @0046AD00 }
procedure TSprite.DrawDC(DC: HDC; DX, DY: Integer; ClipRect: TRect; Scale: Double);
var
  X1, Y1, W, H: Integer;
begin
  Scale := GetScale * Scale;
  X1 := DX + Round(FMarginLeft * Scale);
  Y1 := DY + Round(FMarginTop * Scale);
  { LET OP: anders dan Draw worden alleen de rechter- en bovenmarge afgetrokken }
  W := Round((GetWidth - FMarginRight) * Scale);
  H := Round((GetHeight - FMarginTop) * Scale);
  if FFrameIndex > -1 then
    FFrameList.Frames[FFrameIndex].DrawDC(DC,
      Rect(ClipRect.Left + X1, ClipRect.Top + Y1, ClipRect.Left + X1 + W,
        ClipRect.Top + Y1 + H),
      FMirrorX, FMirrorY, PlotTransparent in FPlotmode);
end;

{ @0046AE50 }
procedure TSprite.Draw(Surface: TSurface; DX, DY: Integer; ClipRect: TRect;
  Scale: Double);
var
  X1, Y1, W, H: Integer;
begin
  Scale := GetScale * Scale;
  X1 := DX + Round(FMarginLeft * Scale);
  Y1 := DY + Round(FMarginTop * Scale);
  W := Round((GetWidth - FMarginRight - FMarginLeft) * Scale);
  H := Round((GetHeight - FMarginTop - FMarginBottom) * Scale);
  DoBeforeBlit(Surface, DX, DY, ClipRect, Scale);
  if FFrameIndex > -1 then
    FFrameList.Frames[FFrameIndex].Draw(Surface,
      Rect(ClipRect.Left + X1, ClipRect.Top + Y1, ClipRect.Left + X1 + W,
        ClipRect.Top + Y1 + H),
      FMirrorX, FMirrorY, PlotTransparent in FPlotmode);
  DoAfterBlit(Surface, DX, DY, ClipRect, Scale);
end;

{ @0046AFE8  OnSkipTimer van FTimer }
procedure TSprite.TimerSkip(Sender: TObject);
var
  Continue: Boolean;
begin
  DoFrameSkipped(Continue);
  TimerTick(Sender);
end;

{ @0046B008  OnTimer van FTimer: volgende stap van de huidige reeks }
procedure TSprite.TimerTick(Sender: TObject);
var
  OldWidth, OldHeight: Integer;
  OffsX, OffsY: Integer;
  NewFrame, SDX, SDY, SDZ: Integer;
  Delay: Double;
begin
  if FKilled then
  begin
    FTimer.Enabled := False;
    FTimer.OnTimer := nil;
    Free;
  end
  else if not FFrozen then
  begin
    if FMirrorX then
      OldWidth := GetWidth;
    if FMirrorY then
      OldHeight := GetHeight;
    if FTimer.Enabled then
    begin
      FSequence.GetStep(FStep, NewFrame, SDX, SDY, SDZ, Delay);
      if FMirrorX then
        SDX := -SDX;
      if FMirrorY then
        SDY := -SDY;
      ChangeState(GetX + SDX, GetY + SDY, GetZ + SDZ, FMarginLeft, FMarginTop,
        FMarginRight, FMarginBottom, FFrameIndex, Visible, GetScale,
        [scX, scY, scZ]);
    end;
    Inc(FStep);
    if FSequence.Count = FStep then
    begin
      FStep := 0;
      if FRepeatCount <> -1 then
        Dec(FRepeatCount);
      DoFinishSequence(FRepeatCount);
      if FKilled then
      begin
        FTimer.Enabled := False;
        FTimer.OnTimer := nil;
        Free;
        Exit;
      end;
      if FRepeatCount = 0 then
        FTimer.Enabled := False;
    end;
    if FTimer.Enabled then
    begin
      { LET OP: de offsets worden alleen hierboven toegepast, voor de zojuist afgeronde stap }
      FSequence.GetStep(FStep, NewFrame, SDX, SDY, SDZ, Delay);
      if FMirrorX then
        OffsX := FFrameList.Frames[NewFrame].Width - OldWidth
      else
        OffsX := 0;
      if FMirrorY then
        OffsY := FFrameList.Frames[NewFrame].Height - OldHeight
      else
        OffsY := 0;
      ChangeState(GetX - OffsX, GetY - OffsY, GetZ, FMarginLeft, FMarginTop,
        FMarginRight, FMarginBottom, NewFrame, Visible, GetScale, [scFrameIndex]);
      FTimer.Interval := Round(Delay * 1000);
    end;
  end;
end;

{ @0046B2D0 }
function TSprite.GetScale: Double;
begin
  Result := FScale;
end;

{ @0046B2EC  past een nieuwe toestand toe; geneste aanroepen (vanuit gebeurtenis-handlers)
  werken alleen de wachtende waarden bij die door Changes zijn geselecteerd }
procedure TSprite.ChangeState(AX, AY, AZ, AMarginLeft, AMarginTop, AMarginRight,
  AMarginBottom, AFrameIndex: Integer; AVisible: Boolean; AScale: Double;
  Changes: TSpriteChanges);
begin
  if csDesigning in ComponentState then
    Exit;
  if FChanging then
  begin
    if scX in Changes then
      FNewX := AX;
    if scY in Changes then
      FNewY := AY;
    if scZ in Changes then
      FNewZ := AZ;
    if scMarginLeft in Changes then
      FNewMarginLeft := AMarginLeft;
    if scMarginTop in Changes then
      FNewMarginTop := AMarginTop;
    if scMarginRight in Changes then
      FNewMarginRight := AMarginRight;
    if scMarginBottom in Changes then
      FNewMarginBottom := AMarginBottom;
    if scVisible in Changes then
      FNewVisible := AVisible;
    if scScale in Changes then
      FNewScale := AScale;
    if scFrameIndex in Changes then
      FNewFrameIndex := AFrameIndex;
  end
  else
  begin
    FChanging := True;
    FNewX := AX;
    FNewY := AY;
    FNewZ := AZ;
    FNewFrameIndex := AFrameIndex;
    FNewVisible := AVisible;
    FNewScale := AScale;
    FNewMarginLeft := AMarginLeft;
    FNewMarginTop := AMarginTop;
    FNewMarginRight := AMarginRight;
    FNewMarginBottom := AMarginBottom;
    { LET OP: het origineel leest hier de oude toestand zonder die te gebruiken }
    GetLeft;
    GetTop;
    GetX;
    GetY;
    GetZ;
    GetScale;
    DoMove(FNewX, FNewY, FNewZ);
    if FKilled then
      FNewVisible := False;
    inherited SetVisible(FNewVisible);
    FFrameIndex := FNewFrameIndex;
    inherited SetLeft(FNewX - Round(GetHotSpotX * FNewScale));
    inherited SetTop(FNewY - Round(GetHotSpotY * FNewScale));
    SetZOrder(FNewZ);
    FScale := FNewScale;
    FMarginLeft := FNewMarginLeft;
    FMarginTop := FNewMarginTop;
    FMarginRight := FNewMarginRight;
    FMarginBottom := FNewMarginBottom;
    if not FKilled and Visible then
      DoHit;
    FChanging := False;
  end;
end;

{ @0046B5A4 }
function TSprite.GetAbout: string;
begin
  Result := '2.5c';
end;

{ @0046B5C8  oppervlak met de frames van het huidige frame }
function TSprite.GetSurface: TSurface;
begin
  if FFrameIndex = -1 then
    Result := nil
  else
    Result := FFrameList.Frames[FFrameIndex].Surface;
end;

{ @0046B5F0 }
function TSprite.GetSequence: TName;
begin
  if FSequence = nil then
    Result := ''
  else
    Result := FSequence.Name;
end;

{ @0046B614 }
procedure TSprite.SetSequence(Value: TName);
begin
  if Value = '' then
    FSequence := nil
  else
    FSequence := FSequenceList.SequenceByName(Value);
  FStep := 0;
end;

{ @0046B65C }
procedure TSprite.SetMouseCapture(Value: Boolean);
begin
  if Value <> FMouseCapture then
  begin
    FMouseCapture := Value;
    if Value then
      FSpriteBox.SetCapturePixie(Self)
    else
      FSpriteBox.SetCapturePixie(nil);
  end;
end;

{ @0046B688 }
procedure TSprite.SetVisible(Value: Boolean);
var
  NewVisible: Boolean;
begin
  NewVisible := Value;
  DoVisible(NewVisible);
  if NewVisible <> Visible then
    ChangeState(GetX, GetY, GetZ, FMarginLeft, FMarginTop, FMarginRight,
      FMarginBottom, FFrameIndex, NewVisible, GetScale, [scVisible]);
end;

{ @0046B710 }
procedure TSprite.SetMirrorX(Value: Boolean);
begin
  if Value <> FMirrorX then
  begin
    FMirrorX := Value;
    Redraw;
  end;
end;

{ @0046B724 }
procedure TSprite.SetMirrorY(Value: Boolean);
begin
  if Value <> FMirrorY then
  begin
    FMirrorY := Value;
    Redraw;
  end;
end;

{ @0046B738 }
procedure TSprite.SetX(Value: Integer);
begin
  if Value <> GetX then
    ChangeState(Value, GetY, GetZ, FMarginLeft, FMarginTop, FMarginRight,
      FMarginBottom, FFrameIndex, Visible, GetScale, [scX]);
end;

{ @0046B7AC }
procedure TSprite.SetY(Value: Integer);
begin
  if Value <> GetY then
    ChangeState(GetX, Value, GetZ, FMarginLeft, FMarginTop, FMarginRight,
      FMarginBottom, FFrameIndex, Visible, GetScale, [scY]);
end;

{ @0046B820 }
procedure TSprite.SetLeft(Value: Integer);
begin
  if Value <> GetLeft then
    SetX(GetHotSpotX + Value);
end;

{ @0046B84C }
procedure TSprite.SetTop(Value: Integer);
begin
  if Value <> GetTop then
    SetY(GetHotSpotY + Value);
end;

{ @0046B878 }
procedure TSprite.SetZ(Value: Integer);
begin
  if Value <> GetZ then
  begin
    SetZOrder(Value);
    ChangeState(GetX, GetY, Value, FMarginLeft, FMarginTop, FMarginRight,
      FMarginBottom, FFrameIndex, Visible, GetScale, [scZ]);
  end;
end;

{ @0046B8F8  sets Z and keeps the sprite box sorted }
procedure TSprite.SetZOrder(Value: Integer);
begin
  if Value <> GetZ then
  begin
    inherited SetZ(Value);
    if FSpriteBox <> nil then
      FSpriteBox.UpdateZOrder(Self);
  end;
end;

{ @0046B924 }
procedure TSprite.SetMarginLeft(Value: Integer);
begin
  if Value <> FMarginLeft then
    ChangeState(GetX, GetY, GetZ, Value, FMarginTop, FMarginRight,
      FMarginBottom, FFrameIndex, Visible, GetScale, [scMarginLeft]);
end;

{ @0046B998 }
procedure TSprite.SetMarginTop(Value: Integer);
begin
  if Value <> FMarginTop then
    ChangeState(GetX, GetY, GetZ, FMarginLeft, Value, FMarginRight,
      FMarginBottom, FFrameIndex, Visible, GetScale, [scMarginTop]);
end;

{ @0046BA0C }
procedure TSprite.SetMarginRight(Value: Integer);
begin
  if Value <> FMarginRight then
    ChangeState(GetX, GetY, GetZ, FMarginLeft, FMarginTop, Value,
      FMarginBottom, FFrameIndex, Visible, GetScale, [scMarginRight]);
end;

{ @0046BA80 }
procedure TSprite.SetMarginBottom(Value: Integer);
begin
  if Value <> FMarginBottom then
    ChangeState(GetX, GetY, GetZ, FMarginLeft, FMarginTop, FMarginRight,
      Value, FFrameIndex, Visible, GetScale, [scMarginBottom]);
end;

{ @0046BAF4  X is de positie van het hotspot-punt }
function TSprite.GetX: Integer;
begin
  Result := GetLeft + Round(GetHotSpotX * GetScale);
end;

{ @0046BB50 }
function TSprite.GetY: Integer;
begin
  Result := GetTop + Round(GetHotSpotY * GetScale);
end;

{ @0046BBAC }
function TSprite.GetWidth: Integer;
begin
  Result := FMarginLeft + FMarginRight;
  if FFrameIndex <> -1 then
    Inc(Result, FFrameList.Frames[FFrameIndex].Width);
end;

{ @0046BBE0 }
function TSprite.GetHeight: Integer;
begin
  Result := FMarginTop + FMarginBottom;
  if FFrameIndex <> -1 then
    Inc(Result, FFrameList.Frames[FFrameIndex].Height);
end;

{ @0046BC14 }
function TSprite.GetHotSpotX: Integer;
begin
  if (FFrameIndex = -1) or (FFrameList.Count = 0) then
    Result := FMarginLeft
  else
    Result := FFrameList.Frames[FFrameIndex].HotSpotX + FMarginLeft;
end;

{ @0046BC50 }
function TSprite.GetHotSpotY: Integer;
begin
  if (FFrameIndex = -1) or (FFrameList.Count = 0) then
    Result := FMarginTop
  else
    Result := FFrameList.Frames[FFrameIndex].HotSpotY + FMarginTop;
end;

{ @0046BC8C }
function TSprite.GetTransparent: TColor;
begin
  Result := FFrameList.TransparentColor;
end;

{ @0046BC94 }
procedure TSprite.SetTransparent(Value: TColor);
begin
  FFrameList.SetTransparentColor(Value);
end;

{ @0046BCA0 }
procedure TSprite.SetSpriteBox(Value: TSpriteBox);
begin
  try
    if FSpriteBox <> nil then
      FSpriteBox.RemovePixie(Self);
    FSpriteBox := Value;
    if FSpriteBox <> nil then
    begin
      FSpriteBox.AddPixie(Self);
      FFrameList.Surface.ConvertTo(FSpriteBox.Picture);
    end;
  finally
  end;
end;

{ @0046BD08 }
procedure TSprite.SetFrameList(Value: TFrameList);
begin
  FFrameList.Assign(Value);
end;

{ @0046BD18 }
procedure TSprite.SetSequenceList(Value: TSequenceList);
begin
  FSequenceList.Assign(Value);
end;

{ @0046BD24 }
function TSprite.GetCurrentFrame: TName;
begin
  if FFrameIndex = -1 then
    Result := ''
  else
    Result := FFrameList.Frames[FFrameIndex].Name;
end;

{ @0046BD58 }
procedure TSprite.SetCurrentFrame(Value: TName);
var
  Index: Integer;
begin
  if (Value = '') and (csDesigning in ComponentState) then
    SetFrameIndex(-1)
  else if (Value <> '') and (Value <> 'None') then
  begin
    Index := FFrameList.IndexOf(Value);
    if Index <> -1 then
      SetFrameIndex(Index)
    else
      raise ESprite.Create('Frame not found: ' + Value);
  end;
end;

{ @0046BE60  LET OP: tijdens het uitvoeren wordt FrameIndex -1 genegeerd }
procedure TSprite.SetFrameIndex(Value: Integer);
begin
  if csDesigning in ComponentState then
  begin
    if (Value >= -1) and (Value < FFrameList.Count) then
      FFrameIndex := Value
    else
      raise ESprite.Create('Frameindex should be between -1 and ' +
        IntToStr(FFrameList.Count - 1));
  end
  else if Value <> -1 then
    ChangeState(GetX, GetY, GetZ, FMarginLeft, FMarginTop, FMarginRight,
      FMarginBottom, Value, Visible, GetScale, [scFrameIndex]);
end;

{ @0046BF94 }
procedure TSprite.SetScale(Value: Double);
begin
  if GetScale <> Value then
    ChangeState(GetX, GetY, GetZ, FMarginLeft, FMarginTop, FMarginRight,
      FMarginBottom, FFrameIndex, Visible, Value, [scScale]);
end;

{ @0046C010 }
function TSprite.GetFrozen: Boolean;
begin
  Result := FFrozen;
end;

{ @0046C018 }
procedure TSprite.SetPriority(Value: Integer);
begin
  FTimer.Priority := Value;
end;

{ @0046C024 }
function TSprite.GetPriority: Integer;
begin
  Result := FTimer.Priority;
end;

{ @0046C030 }
function TSprite.GetBehaviour(Name: string): TBehaviour;
begin
  Result := FBehaviours.Find(Name);
end;

{ @0046C084 }
procedure TSprite.AddBehaviour(Name: string; Behaviour: TBehaviour);
begin
  if Behaviour <> nil then
  begin
    Behaviour.FName := Name;
    Behaviour.SetSprite(Self);
    FBehaviours.Add(Behaviour);
  end;
end;

{ ---------------------------------------------------------------- TSpriteList }

{ @0046C0F0 }
function TSpriteList.Add(Sprite: TSprite): TSprite;
begin
  inherited Add(Sprite);
  Result := Sprite;
end;

{ @0046C100 }
function TSpriteList.SpriteByName(Name: string): TSprite;
var
  I: Integer;
begin
  for I := 0 to Count - 1 do
    if SameText2(GetSprite(I).Name, Name) then
    begin
      Result := GetSprite(I);
      Exit;
    end;
  Result := nil;
end;

{ @0046C180 }
function TSpriteList.GetSprite(Index: Integer): TSprite;
begin
  Result := TObject(Get(Index)) as TSprite;
end;

{ ----------------------------------------------------------------- TBehaviour }

{ @0046C1A0 }
constructor TBehaviour.Create;
begin
  FName := '';
  FActive := False;
  inherited Create;
end;

{ @0046C1E4 }
destructor TBehaviour.Destroy;
begin
  if FSprite <> nil then
    Detach;
  inherited Destroy;
end;

{ @0046C218 }
procedure TBehaviour.FinishSequence(Sender: TObject; var RepeatCount: Integer);
begin
end;

{ @0046C21C }
procedure TBehaviour.Hit(Sender: TObject; HitWhom: TSprite);
begin
end;

{ @0046C220 }
procedure TBehaviour.Move(Sender: TObject; var X, Y, Z: Integer);
begin
end;

{ @0046C228 }
procedure TBehaviour.AfterBlit(Sender: TObject; Surface: TSurface; X, Y: Integer;
  Where: TRect; Size: Real);
begin
end;

{ @0046C248 }
procedure TBehaviour.BeforeBlit(Sender: TObject; Surface: TSurface; X, Y: Integer;
  Where: TRect; Size: Real);
begin
end;

{ @0046C268 }
procedure TBehaviour.MouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
begin
end;

{ @0046C270 }
procedure TBehaviour.MouseLeave(Sender: TObject);
begin
end;

{ @0046C274 }
procedure TBehaviour.MouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
end;

{ @0046C27C }
procedure TBehaviour.MouseUp(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
end;

{ @0046C284 }
procedure TBehaviour.VisibleChange(Sender: TObject; var NewVisible: Boolean);
begin
end;

{ @0046C288 }
procedure TBehaviour.SetSprite(Value: TSprite);
begin
  FSprite := Value;
end;

{ @0046C28C }
procedure TBehaviour.Detach;
begin
  SetActive(False);
  FSprite.FBehaviours.Remove(Self);
end;

{ @0046C2AC }
procedure TBehaviour.SetActive(Value: Boolean);
begin
  FActive := Value;
end;

{ @0046C2B0  deactiveert zichzelf en activeert NextBehaviour }
procedure TBehaviour.Finish;
begin
  SetActive(False);
  if Assigned(FOnFinish) then
    FOnFinish(Self);
  if FNextBehaviour <> '' then
    FSprite.GetBehaviour(FNextBehaviour).SetActive(True);
end;

{ ------------------------------------------------------------- TBehaviourList }

{ @0046C2E8 }
function TBehaviourList.Add(Behaviour: TBehaviour): TBehaviour;
begin
  inherited Add(Behaviour);
  Result := Behaviour;
end;

{ @0046C2F8 }
function TBehaviourList.GetBehaviour(Index: Integer): TBehaviour;
begin
  Result := TObject(Get(Index)) as TBehaviour;
end;

{ @0046C318  hoofdlettergevoelig }
function TBehaviourList.Find(Name: string): TBehaviour;
var
  I: Integer;
begin
  for I := 0 to Count - 1 do
    if GetBehaviour(I) <> nil then
      if GetBehaviour(I).FName = Name then
      begin
        Result := GetBehaviour(I);
        Exit;
      end;
  Result := nil;
end;

{ @0046C3A0  wist alleen de plek; Pack verwijdert hem }
function TBehaviourList.Remove(Behaviour: TBehaviour): Integer;
begin
  Result := IndexOf(Behaviour);
  if Result <> -1 then
    ClearItem(Result);
end;

{ @0046C3C0 }
procedure TBehaviourList.ClearItem(Index: Integer);
begin
  if (Index >= 0) and (Index < Count) then
    Put(Index, nil);
end;

{ @0046C3D4  verwijdert de gewiste plekken }
procedure TBehaviourList.Pack;
var
  I: Integer;
begin
  for I := Count - 1 downto 0 do
    if GetBehaviour(I) = nil then
      Delete(I);
end;

{ @0046C400 }
function TBehaviourList.IsActive(Index: Integer): Boolean;
begin
  Result := (GetBehaviour(Index) <> nil) and GetBehaviour(Index).FActive;
end;

{ De finalization bij @0046C42C geeft SpriteMotto en SpriteMotto2 vrij. }

end.
