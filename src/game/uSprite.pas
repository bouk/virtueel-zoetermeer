unit uSprite;

{ TSprite: een geanimeerde bitmap op een TSpriteBox. Een sprite bezit een TFrameList (de
  beelden) en een TSequenceList (animaties); een TFastTimer doorloopt de
  huidige reeks. Alle wijzigingen van positie, frame, zichtbaarheid, marges en
  schaal lopen via WijzigToestand, dat ook OnMove en de trefcontrole aanroept.
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

  { De RTTI plaatst TTekenOptie/TPlotMode in Sprframe, dat ze niet declareert. }
  TTekenOptie = (BufferBackground, PlotTransparent);
  TPlotMode = set of TTekenOptie;

  { Wat een aanroep van WijzigToestand wijzigt terwijl er al een wijziging bezig is }
  TSpriteWijziging = (scX, scY, scZ, scMarginLeft, scMarginTop, scMarginRight,
    scMarginBottom, scFrameIndex, scVisible, scScale);
  TSpriteWijzigingen = set of TSpriteWijziging;

  TOnFinishSequence = procedure(Sender: TObject; var Herhalingen: Integer) of object;
  TOnVisibleEvent = procedure(Sender: TObject; var NewVisible: Boolean) of object;
  TOnMoveEvent = procedure(Sender: TObject; var X, Y, Z: Integer) of object;
  TOnHitEvent = procedure(Sender: TObject; HitWhom: TSprite) of object;
  TOnSkipFrameEvent = procedure(Sender: TObject; var Continue: Boolean) of object;
  TOnBlitEvent = procedure(Sender: TObject; Surface: TSurface; X, Y: Integer;
    Where: TRect; Size: Real) of object;

  TSprite = class(TPixie)
  private
    FVersie: string;                    { +0x68  gestreamde versie, bijv. '2.5c' }
    FSpriteVak: TSpriteBox;            { +0x6C }
    FFrameLijst: TFrameList;            { +0x70 }
    FReeksLijst: TSequenceList;      { +0x74 }
    FReeks: TSequence;              { +0x78  sequence being played }
    FGereserveerd7C: Integer;              { +0x7C  niet gebruikt }
    FTekenmodus: TPlotMode;              { +0x80 }
    FFrameNr: Integer;              { +0x84 }
    FKlok: TFastTimer;                { +0x88 }
    FHerhalingen: Integer;             { +0x8C  -1: voor altijd }
    FStep: Integer;                    { +0x90  stap binnen FReeks }
    FDynamisch: Boolean;                 { +0x94  gemaakt door MaakKopie: lijsten worden gedeeld }
    FVerwijderd: Boolean;                  { +0x95  vrijgeven bij de eerstvolgende gelegenheid }
    FTreffertest: THitTest;                { +0x96 }
    FGereserveerd98: Integer;              { +0x98  op 0 gezet, nooit gelezen }
    FSpiegelY: Boolean;                 { +0x9C }
    FSpiegelX: Boolean;                 { +0x9D }
    FGereserveerd9E: Boolean;              { +0x9E  gekopieerd door MaakKopie, nooit gelezen }
    FBevroren: Boolean;                  { +0x9F  animatie gepauzeerd }
    FGestopt: Boolean;                 { +0xA0  StopReeks is aangeroepen }
    FSchaal: Double;                    { +0xA8 }
    FData: TObject;                    { +0xB0  owned user object }
    FMargeLinks: Integer;              { +0xB4 }
    FMargeRechts: Integer;             { +0xB8 }
    FMargeBoven: Integer;               { +0xBC }
    FMargeOnder: Integer;            { +0xC0 }
    FVorigFrame: string;                { +0xC4  framenaam bij de laatste LeesWijziging }
    FMuisVast: Boolean;            { +0xC8 }
    FNieuwX: Integer;                    { +0xCC  pending state of WijzigToestand }
    FNieuwY: Integer;                    { +0xD0 }
    FNieuwZ: Integer;                    { +0xD4 }
    FNieuwFrameNr: Integer;           { +0xD8 }
    FNieuwZichtbaar: Boolean;              { +0xDC }
    FNieuwSchaal: Double;                 { +0xE0 }
    FNieuwMargeLinks: Integer;           { +0xE8 }
    FNieuwMargeRechts: Integer;          { +0xEC }
    FNieuwMargeBoven: Integer;            { +0xF0 }
    FNieuwMargeOnder: Integer;         { +0xF4 }
    FWijzigt: Boolean;                { +0xF8 }
    FForceerHertekenen: Boolean;             { +0xF9 }
    FGereserveerdFC: Integer;              { +0xFC  niet gebruikt }
    FOnZichtbaar: TOnVisibleEvent;       { +0x100 }
    FOnVerplaats: TOnMoveEvent;             { +0x108 }
    FOnReeksKlaar: TOnFinishSequence; { +0x110 }
    FOnRaak: TOnHitEvent;               { +0x118 }
    FOnVoorBlit: TOnBlitEvent;       { +0x120 }
    FOnNaBlit: TOnBlitEvent;        { +0x128 }
    FOnFrameOvergeslagen: TOnSkipFrameEvent; { +0x130 }
    FGedragingen: TBehaviourList;       { +0x138 }
    procedure KlokOverslaan(Sender: TObject);
    procedure KlokTik(Sender: TObject);
    function LeesVersie: string;
    function GetTransparent: TColor;
    procedure SetTransparent(Value: TColor);
    procedure ZetSpriteVak(Value: TSpriteBox);
    procedure ZetFrameLijst(Value: TFrameList);
    procedure ZetReeksLijst(Value: TSequenceList);
    function LeesHuidigFrame: TName;
    procedure ZetHuidigFrame(Value: TName);
    procedure ZetFrameNr(Value: Integer);
    procedure ZetSpiegelX(Value: Boolean);
    procedure ZetSpiegelY(Value: Boolean);
    procedure ZetPrioriteit(Value: Integer);
    function LeesPrioriteit: Integer;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    { TPixie }
    procedure SetVisible(Value: Boolean); override;
    procedure ZetX(Value: Integer); override;
    procedure ZetY(Value: Integer); override;
    procedure ZetZ(Value: Integer); override;
    function LeesX: Integer; override;
    function LeesY: Integer; override;
    procedure SetLeft(Value: Integer); override;
    procedure SetTop(Value: Integer); override;
    function GetWidth: Integer; override;
    function GetHeight: Integer; override;
    procedure Draw(Surface: TSurface; DX, DY: Integer; ClipRect: TRect;
      Schaalfactor: Double); override;
    procedure TekenDC(DC: HDC; DX, DY: Integer; ClipRect: TRect;
      Schaalfactor: Double); override;
    procedure LeesWijziging(var OldState, NewState: TPixieStaat); override;
    procedure MouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState;
      X, Y: Integer); override;
    procedure MouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState;
      X, Y: Integer); override;
    procedure MouseMove(Sender: TObject; Shift: TShiftState;
      X, Y: Integer); override;
    procedure MuisVerlaten; override;
    { nieuwe virtuele methoden }
    function LeesHotSpotX: Integer; virtual;                             { +0x88 }
    function LeesHotSpotY: Integer; virtual;                             { +0x8C }
    function LeesSchaal: Double; virtual;                                 { +0x90 }
    procedure VerwerkZichtbaar(var NewVisible: Boolean); virtual;              { +0x94 }
    procedure VerwerkVerplaatsing(var X, Y, Z: Integer); virtual;                    { +0x98 }
    procedure VerwerkReeksKlaar(var Herhalingen: Integer); virtual;      { +0x9C }
    procedure VerwerkRaak; virtual;                                           { +0xA0 }
    procedure VerwerkOvergeslagenFrame(var Continue: Boolean); virtual;           { +0xA4 }
    procedure VerwerkNaBlit(Surface: TSurface; X, Y: Integer; Where: TRect;
      Size: Real); virtual;                                             { +0xA8 }
    procedure VerwerkVoorBlit(Surface: TSurface; X, Y: Integer; Where: TRect;
      Size: Real); virtual;                                             { +0xAC }
    procedure WijzigToestand(AX, AY, AZ, AMarginLeft, AMarginTop, AMarginRight,
      AMargeOnder, AFrameNr: Integer; AVisible: Boolean; AScale: Double;
      Wijzigingen: TSpriteWijzigingen); virtual;                                { +0xB0 }
    constructor MaakKopie(Source: TSprite); virtual;                   { +0xB4 }
    { statische methoden }
    procedure Verwijder;
    procedure Redraw;
    procedure MoveTo(AX, AY: Integer);
    procedure VerplaatsNaar3D(AX, AY, AZ: Integer);
    procedure VerplaatsMet(DX, DY, DZ: Integer);
    procedure SpeelReeks(Name: string; Herhalingen: Integer);
    procedure SpeelReeksVanaf(Name: string; Herhalingen: Integer; DX, DY: Integer);
    procedure StopReeks;
    function LeesOppervlak: TSurface;
    function LeesReeks: TName;
    procedure ZetReeks(Value: TName);
    procedure SetMouseCapture(Value: Boolean);
    procedure SetZOrder(Value: Integer);
    procedure ZetMargeLinks(Value: Integer);
    procedure ZetMargeBoven(Value: Integer);
    procedure ZetMargeRechts(Value: Integer);
    procedure ZetMargeOnder(Value: Integer);
    procedure ZetSchaal(Value: Double);
    function LeesBevroren: Boolean;
    function LeesGedrag(Name: string): TBehaviour;
    procedure VoegGedragToe(Name: string; Behaviour: TBehaviour);
    property Versienummer: string read FVersie;
    property HuidigeReeks: TSequence read FReeks;
    property Animatiereeks: TName read LeesReeks write ZetReeks;
    property Timer: TFastTimer read FKlok;
    property Herhalingen: Integer read FHerhalingen write FHerhalingen;
    property Step: Integer read FStep write FStep;
    property Dynamic: Boolean read FDynamisch;
    property Verwijderd: Boolean read FVerwijderd;
    property Bevroren: Boolean read LeesBevroren write FBevroren;
    property Gestopt: Boolean read FGestopt write FGestopt;
    property Schaalfactor: Double read LeesSchaal write ZetSchaal;
    property Data: TObject read FData write FData;
    property MargeLinks: Integer read FMargeLinks write ZetMargeLinks;
    property MargeBoven: Integer read FMargeBoven write ZetMargeBoven;
    property MargeRechts: Integer read FMargeRechts write ZetMargeRechts;
    property MargeOnder: Integer read FMargeOnder write ZetMargeOnder;
    property MouseCapture: Boolean read FMuisVast write SetMouseCapture;
    property Showing: Boolean read FNieuwZichtbaar;
    property Changing: Boolean read FWijzigt;
    property Gedragslijst: TBehaviourList read FGedragingen;
  published
    property About: string read LeesVersie write FVersie;
    property Transparent: TColor read GetTransparent write SetTransparent;
    property HitTest: THitTest read FTreffertest write FTreffertest;
    property Plotmode: TPlotMode read FTekenmodus write FTekenmodus default [BufferBackground, PlotTransparent];
    property FrameList: TFrameList read FFrameLijst write ZetFrameLijst;
    property Priority: Integer read LeesPrioriteit write ZetPrioriteit;
    property SpriteBox: TSpriteBox read FSpriteVak write ZetSpriteVak;
    property SequenceList: TSequenceList read FReeksLijst write ZetReeksLijst;
    property CurrentFrame: TName read LeesHuidigFrame write ZetHuidigFrame;
    property FrameIndex: Integer read FFrameNr write ZetFrameNr;
    property MirrorX: Boolean read FSpiegelX write ZetSpiegelX;
    property MirrorY: Boolean read FSpiegelY write ZetSpiegelY;
    property HotSpotX: Integer read LeesHotSpotX;
    property HotSpotY: Integer read LeesHotSpotY;
    property OnMove: TOnMoveEvent read FOnVerplaats write FOnVerplaats;
    property OnFinishSequence: TOnFinishSequence read FOnReeksKlaar write FOnReeksKlaar;
    property OnHit: TOnHitEvent read FOnRaak write FOnRaak;
    property OnBeforeBlit: TOnBlitEvent read FOnVoorBlit write FOnVoorBlit;
    property OnAfterBlit: TOnBlitEvent read FOnNaBlit write FOnNaBlit;
    property OnVisible: TOnVisibleEvent read FOnZichtbaar write FOnZichtbaar;
    property OnFrameSkipped: TOnSkipFrameEvent read FOnFrameOvergeslagen write FOnFrameOvergeslagen;
  end;

  TSpriteList = class(TList)
  public
    function Add(Sprite: TSprite): TSprite;
    function SpriteOpNaam(Name: string): TSprite;
    function LeesSprite(Index: Integer): TSprite;
    property Sprites[Index: Integer]: TSprite read LeesSprite; default;
  end;

  { Gedrag gekoppeld aan een sprite: ontvangt de gebeurtenissen van de sprite (zolang
    Active waar is) voor de eigen gebeurtenis-handlers van de sprite. }
  TBehaviour = class(TObject)
  protected
    FName: string;                     { +0x04 }
    FSprite: TSprite;                  { +0x08 }
    FActive: Boolean;                  { +0x0C }
    FOnKlaar: TNotifyEvent;           { +0x10 }
    FVolgendGedrag: string;            { +0x18  geactiveerd door Afronden }
  public
    constructor Create;
    destructor Destroy; override;
    procedure ReeksKlaar(Sender: TObject; var Herhalingen: Integer); virtual;   { +0x00 }
    procedure Raak(Sender: TObject; HitWhom: TSprite); virtual;                      { +0x04 }
    procedure Move(Sender: TObject; var X, Y, Z: Integer); virtual;                 { +0x08 }
    procedure NaBlit(Sender: TObject; Surface: TSurface; X, Y: Integer;
      Where: TRect; Size: Real); virtual;                                           { +0x0C }
    procedure VoorBlit(Sender: TObject; Surface: TSurface; X, Y: Integer;
      Where: TRect; Size: Real); virtual;                                           { +0x10 }
    procedure ZichtbaarWijziging(Sender: TObject; var NewVisible: Boolean); virtual;     { +0x14 }
    procedure MouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState;
      X, Y: Integer); virtual;                                                      { +0x18 }
    procedure MouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState;
      X, Y: Integer); virtual;                                                      { +0x1C }
    procedure MouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer); virtual; { +0x20 }
    procedure MuisVerlaten(Sender: TObject); virtual;                                 { +0x24 }
    procedure ZetSprite(Value: TSprite); virtual;                                   { +0x28 }
    procedure Ontkoppel; virtual;                                                      { +0x2C }
    procedure Afronden; virtual;                                                      { +0x30 }
    procedure SetActive(Value: Boolean); virtual;                                   { +0x34 }
    property Name: string read FName write FName;
    property Sprite: TSprite read FSprite;
    property Active: Boolean read FActive write SetActive;
    property OnKlaar: TNotifyEvent read FOnKlaar write FOnKlaar;
    property VolgendGedrag: string read FVolgendGedrag write FVolgendGedrag;
  end;

  TBehaviourList = class(TList)
  public
    function Add(Behaviour: TBehaviour): TBehaviour;
    function LeesGedrag(Index: Integer): TBehaviour;
    function Find(Name: string): TBehaviour;
    function Remove(Behaviour: TBehaviour): Integer;
    procedure WisItem(Index: Integer);
    procedure Pack;
    function IsActief(Index: Integer): Boolean;
    property Items[Index: Integer]: TBehaviour read LeesGedrag; default;
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
  FGereserveerd98 := 0;
  FFrameLijst := TFrameList.Create(clBlack);
  FReeksLijst := TSequenceList.Create(Self);
  FTekenmodus := [BufferBackground, PlotTransparent];
  FBevroren := False;
  inherited ZetX(0);
  inherited ZetY(0);
  inherited ZetZ(0);
  FFrameNr := -1;
  SetVisible(False);
  FKlok := TFastTimer.Create(Self);
  FKlok.SynchroonRetrace := True;
  FReeks := nil;
  FKlok.Enabled := False;
  FKlok.OnTimer := KlokTik;
  FKlok.OnSkipTimer := KlokOverslaan;
  FDynamisch := False;
  FVerwijderd := False;
  FGereserveerd9E := False;
  FSchaal := 1.0;
  FVersie := '2.5c';
  SetTransparent(clBlue);
  FGedragingen := TBehaviourList.Create;
end;

{ @00469ECC  een sprite die de frames en reeksen van Source deelt }
constructor TSprite.MaakKopie(Source: TSprite);
var
  S: TName;
begin
  Create(Source.Owner);
  SetTransparent(Source.GetTransparent);
  FReeksLijst.Free;
  FFrameLijst.Free;
  FReeksLijst := Source.FReeksLijst;
  FFrameLijst := Source.FFrameLijst;
  FDynamisch := True;
  ZetSpriteVak(Source.FSpriteVak);
  inherited ZetX(Source.LeesX);
  inherited ZetY(Source.LeesY);
  SetZOrder(Source.LeesZ);
  FTreffertest := Source.FTreffertest;
  S := Source.LeesReeks;
  ZetReeks(S);
  FHerhalingen := Source.FHerhalingen;
  FVersie := Source.LeesVersie;
  ZetFrameNr(Source.FFrameNr);
  ZetSpiegelX(Source.FSpiegelX);
  ZetSpiegelY(Source.FSpiegelY);
  FTekenmodus := Source.FTekenmodus;
  FBevroren := Source.LeesBevroren;
  FGereserveerd9E := Source.FGereserveerd9E;
  ZetSchaal(Source.LeesSchaal);
  Tag := Source.Tag;
  ZetMargeLinks(Source.FMargeLinks);
  ZetMargeRechts(Source.FMargeRechts);
  ZetMargeBoven(Source.FMargeBoven);
  ZetMargeOnder(Source.FMargeOnder);
  FOnVerplaats := Source.FOnVerplaats;
  FOnReeksKlaar := Source.FOnReeksKlaar;
  FOnRaak := Source.FOnRaak;
  FOnVoorBlit := Source.FOnVoorBlit;
  FOnNaBlit := Source.FOnNaBlit;
  FOnZichtbaar := Source.FOnZichtbaar;
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
  FVerwijderd := False;
  if FSpriteVak <> nil then
    FSpriteVak.VerwijderPixie(Self);
  if FData <> nil then
    FData.Free;
  while FGedragingen.Count <> 0 do
  begin
    B := TBehaviour(TList(FGedragingen).Items[FGedragingen.Count - 1]);
    FGedragingen.WisItem(FGedragingen.Count - 1);
    FGedragingen.Pack;
    if B <> nil then
    begin
      B.Ontkoppel;
      B.Free;
    end;
  end;
  if not FDynamisch then
  begin
    FFrameLijst.Free;
    FReeksLijst.Clear;
    FReeksLijst.Free;
  end;
  FKlok.Enabled := False;
  FKlok.Free;
  inherited Destroy;
end;

{ @0046A220  de sprite geeft zichzelf vrij bij de volgende timertik of hertekening }
procedure TSprite.Verwijder;
begin
  FVerwijderd := True;
end;

{ @0046A228 }
procedure TSprite.Redraw;
begin
  if Visible then
  begin
    FForceerHertekenen := True;
    WijzigToestand(LeesX, LeesY, LeesZ, FMargeLinks, FMargeBoven, FMargeRechts,
      FMargeOnder, FFrameNr, Visible, LeesSchaal, []);
  end;
end;

{ @0046A2A4 }
procedure TSprite.MoveTo(AX, AY: Integer);
begin
  WijzigToestand(AX, AY, LeesZ, FMargeLinks, FMargeBoven, FMargeRechts,
    FMargeOnder, FFrameNr, Visible, LeesSchaal, [scX, scY]);
end;

{ @0046A30C }
procedure TSprite.VerplaatsNaar3D(AX, AY, AZ: Integer);
begin
  WijzigToestand(AX, AY, AZ, FMargeLinks, FMargeBoven, FMargeRechts,
    FMargeOnder, FFrameNr, Visible, LeesSchaal, [scX, scY, scZ]);
end;

{ @0046A374 }
procedure TSprite.VerplaatsMet(DX, DY, DZ: Integer);
begin
  VerplaatsNaar3D(LeesX + DX, LeesY + DY, LeesZ + DZ);
end;

{ @0046A3B0 }
procedure TSprite.SpeelReeks(Name: string; Herhalingen: Integer);
begin
  SpeelReeksVanaf(Name, Herhalingen, 0, 0);
end;

{ @0046A408  Name mag 'reeks:stap' zijn om bij een gegeven stap te starten;
  Herhalingen -1 herhaalt voor altijd; DX, DY verschuiven de sprite eenmalig. }
procedure TSprite.SpeelReeksVanaf(Name: string; Herhalingen: Integer; DX, DY: Integer);
var
  Rest: string;
  P, StartStep: Integer;
  NewFrame, SDX, SDY, SDZ: Integer;
  Delay: Double;
  BaseX, BaseY: Integer;
begin
  if FReeksLijst.IndexOf(Name) = -1 then
  begin
    P := Pos(':', Name);   { LET OP: resultaat wordt niet gebruikt }
    Rest := Name;
    Name := SplitsEerste(Rest, ':');
    StartStep := StrNaarIntDef0(Rest);
  end
  else
    StartStep := 0;
  ZetReeks(Name);
  FHerhalingen := Herhalingen;
  FStep := StartStep;
  FKlok.Enabled := True;
  { LET OP: de offsets van de stap worden hier niet gebruikt }
  FReeks.LeesStap(FStep, NewFrame, SDX, SDY, SDZ, Delay);
  if FWijzigt then
  begin
    BaseX := FNieuwX;
    BaseY := FNieuwY;
  end
  else
  begin
    BaseX := LeesX;
    BaseY := LeesY;
  end;
  WijzigToestand(DX + BaseX, DY + BaseY, LeesZ, FMargeLinks, FMargeBoven, FMargeRechts,
    FMargeOnder, NewFrame, Visible, LeesSchaal, [scX, scY, scFrameIndex]);
  FKlok.Interval := Round(Delay * 1000);
end;

{ @0046A5D4 }
procedure TSprite.StopReeks;
begin
  FGestopt := True;
  FKlok.Enabled := False;
end;

{ @0046A5EC }
procedure TSprite.VerwerkZichtbaar(var NewVisible: Boolean);
begin
  if Assigned(FOnZichtbaar) then
    FOnZichtbaar(Self, NewVisible);
end;

{ @0046A60C }
procedure TSprite.VerwerkVerplaatsing(var X, Y, Z: Integer);
var
  I: Integer;
begin
  for I := FGedragingen.Count - 1 downto 0 do
    if FGedragingen.IsActief(I) then
      FGedragingen[I].Move(Self, X, Y, Z);
  if Assigned(FOnVerplaats) then
    FOnVerplaats(Self, X, Y, Z);
  FGedragingen.Pack;
end;

{ @0046A69C }
procedure TSprite.VerwerkReeksKlaar(var Herhalingen: Integer);
var
  I: Integer;
begin
  for I := FGedragingen.Count - 1 downto 0 do
    if FGedragingen.IsActief(I) then
      FGedragingen[I].ReeksKlaar(Self, Herhalingen);
  if Assigned(FOnReeksKlaar) then
  begin
    FGestopt := False;
    FOnReeksKlaar(Self, FHerhalingen);
    if FGestopt then
      Exit;
  end;
  FGedragingen.Pack;
end;

{ @0046A720 }
procedure TSprite.VerwerkRaak;
var
  I: Integer;
  Other: TSprite;
  R: TRect;
begin
  if Assigned(FOnRaak) then
  begin
    if FTreffertest in [htRect, htPixel] then
      for I := 0 to FSpriteVak.Count - 1 do
      begin
        if I >= FSpriteVak.Count then
          Break;
        Other := FSpriteVak.Items[I] as TSprite;
        if (Self <> Other) and Other.Visible then
          if IntersectRect(R, GetBoundsRect, Other.GetBoundsRect) and
            (FTreffertest = htRect) then
            FOnRaak(Self, Other);
      end;
    FGedragingen.Pack;
  end;
end;

{ @0046A7EC }
procedure TSprite.VerwerkNaBlit(Surface: TSurface; X, Y: Integer; Where: TRect;
  Size: Real);
var
  I: Integer;
begin
  for I := FGedragingen.Count - 1 downto 0 do
    if FGedragingen.IsActief(I) then
      FGedragingen[I].NaBlit(Self, Surface, X, Y, Where, Size);
  if Assigned(FOnNaBlit) then
    FOnNaBlit(Self, Surface, X, Y,
      Rect(Where.Left + X, Where.Top + Y, Where.Left + X + Round(GetWidth * Size),
        Where.Top + Y + Round(GetHeight * Size)), Size);
  FGedragingen.Pack;
end;

{ @0046A924 }
procedure TSprite.VerwerkVoorBlit(Surface: TSurface; X, Y: Integer; Where: TRect;
  Size: Real);
var
  I: Integer;
begin
  for I := FGedragingen.Count - 1 downto 0 do
    if FGedragingen.IsActief(I) then
      FGedragingen[I].VoorBlit(Self, Surface, X, Y, Where, Size);
  if Assigned(FOnVoorBlit) then
    FOnVoorBlit(Self, Surface, X, Y, Where, Size);
  FGedragingen.Pack;
end;

{ @0046A9D4  zoals TPixie.LeesWijziging, maar een gewijzigd frame of Redraw telt ook mee }
procedure TSprite.LeesWijziging(var OldState, NewState: TPixieStaat);
var
  State: TPixieStaat;
begin
  OldState := FState;
  LeesStaat(State);
  FState := State;
  NewState := FState;
  if (NewState.Left = OldState.Left) and (NewState.Top = OldState.Top) and
    (NewState.Z = OldState.Z) and (NewState.Width = OldState.Width) and
    (NewState.Height = OldState.Height) and (FVorigFrame = LeesHuidigFrame) and
    (NewState.Visible = OldState.Visible) and not FForceerHertekenen then
  begin
    NewState.Visible := False;
    OldState.Visible := False;
  end;
  FForceerHertekenen := False;
  FVorigFrame := LeesHuidigFrame;
  if FVerwijderd then
    Free;
end;

{ @0046AAE8 }
procedure TSprite.VerwerkOvergeslagenFrame(var Continue: Boolean);
begin
  if Assigned(FOnFrameOvergeslagen) then
  begin
    Continue := True;
    FOnFrameOvergeslagen(Self, Continue);
    if Continue then
      ;   { LET OP: het resultaat wordt getest maar niet gebruikt }
  end;
end;

{ @0046AB14 }
procedure TSprite.MouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
var
  I: Integer;
begin
  for I := FGedragingen.Count - 1 downto 0 do
    if FGedragingen.IsActief(I) then
      FGedragingen[I].MouseMove(Self, Shift, X, Y);
  if Assigned(OnMouseMove) then
    OnMouseMove(Self, Shift, X, Y);
  FGedragingen.Pack;
end;

{ @0046AB94 }
procedure TSprite.MuisVerlaten;
var
  I: Integer;
begin
  for I := FGedragingen.Count - 1 downto 0 do
    if FGedragingen.IsActief(I) then
      FGedragingen[I].MuisVerlaten(Self);
  if Assigned(OnMouseLeave) then
    OnMouseLeave(Self);
  FGedragingen.Pack;
end;

{ @0046ABF0 }
procedure TSprite.MouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
var
  I: Integer;
begin
  for I := FGedragingen.Count - 1 downto 0 do
    if FGedragingen.IsActief(I) then
      FGedragingen[I].MouseDown(Self, Button, Shift, X, Y);
  if Assigned(OnMouseDown) then
    OnMouseDown(Self, Button, Shift, X, Y);
  FGedragingen.Pack;
end;

{ @0046AC78 }
procedure TSprite.MouseUp(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
var
  I: Integer;
begin
  for I := FGedragingen.Count - 1 downto 0 do
    if FGedragingen.IsActief(I) then
      FGedragingen[I].MouseUp(Self, Button, Shift, X, Y);
  if Assigned(OnMouseUp) then
    OnMouseUp(Self, Button, Shift, X, Y);
  FGedragingen.Pack;
end;

{ @0046AD00 }
procedure TSprite.TekenDC(DC: HDC; DX, DY: Integer; ClipRect: TRect; Schaalfactor: Double);
var
  X1, Y1, W, H: Integer;
begin
  Schaalfactor := LeesSchaal * Schaalfactor;
  X1 := DX + Round(FMargeLinks * Schaalfactor);
  Y1 := DY + Round(FMargeBoven * Schaalfactor);
  { LET OP: anders dan Draw worden alleen de rechter- en bovenmarge afgetrokken }
  W := Round((GetWidth - FMargeRechts) * Schaalfactor);
  H := Round((GetHeight - FMargeBoven) * Schaalfactor);
  if FFrameNr > -1 then
    FFrameLijst.Beelden[FFrameNr].TekenDC(DC,
      Rect(ClipRect.Left + X1, ClipRect.Top + Y1, ClipRect.Left + X1 + W,
        ClipRect.Top + Y1 + H),
      FSpiegelX, FSpiegelY, PlotTransparent in FTekenmodus);
end;

{ @0046AE50 }
procedure TSprite.Draw(Surface: TSurface; DX, DY: Integer; ClipRect: TRect;
  Schaalfactor: Double);
var
  X1, Y1, W, H: Integer;
begin
  Schaalfactor := LeesSchaal * Schaalfactor;
  X1 := DX + Round(FMargeLinks * Schaalfactor);
  Y1 := DY + Round(FMargeBoven * Schaalfactor);
  W := Round((GetWidth - FMargeRechts - FMargeLinks) * Schaalfactor);
  H := Round((GetHeight - FMargeBoven - FMargeOnder) * Schaalfactor);
  VerwerkVoorBlit(Surface, DX, DY, ClipRect, Schaalfactor);
  if FFrameNr > -1 then
    FFrameLijst.Beelden[FFrameNr].Draw(Surface,
      Rect(ClipRect.Left + X1, ClipRect.Top + Y1, ClipRect.Left + X1 + W,
        ClipRect.Top + Y1 + H),
      FSpiegelX, FSpiegelY, PlotTransparent in FTekenmodus);
  VerwerkNaBlit(Surface, DX, DY, ClipRect, Schaalfactor);
end;

{ @0046AFE8  OnSkipTimer van FKlok }
procedure TSprite.KlokOverslaan(Sender: TObject);
var
  Continue: Boolean;
begin
  VerwerkOvergeslagenFrame(Continue);
  KlokTik(Sender);
end;

{ @0046B008  OnTimer van FKlok: volgende stap van de huidige reeks }
procedure TSprite.KlokTik(Sender: TObject);
var
  OldWidth, OldHeight: Integer;
  OffsX, OffsY: Integer;
  NewFrame, SDX, SDY, SDZ: Integer;
  Delay: Double;
begin
  if FVerwijderd then
  begin
    FKlok.Enabled := False;
    FKlok.OnTimer := nil;
    Free;
  end
  else if not FBevroren then
  begin
    if FSpiegelX then
      OldWidth := GetWidth;
    if FSpiegelY then
      OldHeight := GetHeight;
    if FKlok.Enabled then
    begin
      FReeks.LeesStap(FStep, NewFrame, SDX, SDY, SDZ, Delay);
      if FSpiegelX then
        SDX := -SDX;
      if FSpiegelY then
        SDY := -SDY;
      WijzigToestand(LeesX + SDX, LeesY + SDY, LeesZ + SDZ, FMargeLinks, FMargeBoven,
        FMargeRechts, FMargeOnder, FFrameNr, Visible, LeesSchaal,
        [scX, scY, scZ]);
    end;
    Inc(FStep);
    if FReeks.Count = FStep then
    begin
      FStep := 0;
      if FHerhalingen <> -1 then
        Dec(FHerhalingen);
      VerwerkReeksKlaar(FHerhalingen);
      if FVerwijderd then
      begin
        FKlok.Enabled := False;
        FKlok.OnTimer := nil;
        Free;
        Exit;
      end;
      if FHerhalingen = 0 then
        FKlok.Enabled := False;
    end;
    if FKlok.Enabled then
    begin
      { LET OP: de offsets worden alleen hierboven toegepast, voor de zojuist afgeronde stap }
      FReeks.LeesStap(FStep, NewFrame, SDX, SDY, SDZ, Delay);
      if FSpiegelX then
        OffsX := FFrameLijst.Beelden[NewFrame].Width - OldWidth
      else
        OffsX := 0;
      if FSpiegelY then
        OffsY := FFrameLijst.Beelden[NewFrame].Height - OldHeight
      else
        OffsY := 0;
      WijzigToestand(LeesX - OffsX, LeesY - OffsY, LeesZ, FMargeLinks, FMargeBoven,
        FMargeRechts, FMargeOnder, NewFrame, Visible, LeesSchaal, [scFrameIndex]);
      FKlok.Interval := Round(Delay * 1000);
    end;
  end;
end;

{ @0046B2D0 }
function TSprite.LeesSchaal: Double;
begin
  Result := FSchaal;
end;

{ @0046B2EC  past een nieuwe toestand toe; geneste aanroepen (vanuit gebeurtenis-handlers)
  werken alleen de wachtende waarden bij die door Wijzigingen zijn geselecteerd }
procedure TSprite.WijzigToestand(AX, AY, AZ, AMarginLeft, AMarginTop, AMarginRight,
  AMargeOnder, AFrameNr: Integer; AVisible: Boolean; AScale: Double;
  Wijzigingen: TSpriteWijzigingen);
begin
  if csDesigning in ComponentState then
    Exit;
  if FWijzigt then
  begin
    if scX in Wijzigingen then
      FNieuwX := AX;
    if scY in Wijzigingen then
      FNieuwY := AY;
    if scZ in Wijzigingen then
      FNieuwZ := AZ;
    if scMarginLeft in Wijzigingen then
      FNieuwMargeLinks := AMarginLeft;
    if scMarginTop in Wijzigingen then
      FNieuwMargeBoven := AMarginTop;
    if scMarginRight in Wijzigingen then
      FNieuwMargeRechts := AMarginRight;
    if scMarginBottom in Wijzigingen then
      FNieuwMargeOnder := AMargeOnder;
    if scVisible in Wijzigingen then
      FNieuwZichtbaar := AVisible;
    if scScale in Wijzigingen then
      FNieuwSchaal := AScale;
    if scFrameIndex in Wijzigingen then
      FNieuwFrameNr := AFrameNr;
  end
  else
  begin
    FWijzigt := True;
    FNieuwX := AX;
    FNieuwY := AY;
    FNieuwZ := AZ;
    FNieuwFrameNr := AFrameNr;
    FNieuwZichtbaar := AVisible;
    FNieuwSchaal := AScale;
    FNieuwMargeLinks := AMarginLeft;
    FNieuwMargeBoven := AMarginTop;
    FNieuwMargeRechts := AMarginRight;
    FNieuwMargeOnder := AMargeOnder;
    { LET OP: het origineel leest hier de oude toestand zonder die te gebruiken }
    LeesLinks;
    LeesBoven;
    LeesX;
    LeesY;
    LeesZ;
    LeesSchaal;
    VerwerkVerplaatsing(FNieuwX, FNieuwY, FNieuwZ);
    if FVerwijderd then
      FNieuwZichtbaar := False;
    inherited SetVisible(FNieuwZichtbaar);
    FFrameNr := FNieuwFrameNr;
    inherited SetLeft(FNieuwX - Round(LeesHotSpotX * FNieuwSchaal));
    inherited SetTop(FNieuwY - Round(LeesHotSpotY * FNieuwSchaal));
    SetZOrder(FNieuwZ);
    FSchaal := FNieuwSchaal;
    FMargeLinks := FNieuwMargeLinks;
    FMargeBoven := FNieuwMargeBoven;
    FMargeRechts := FNieuwMargeRechts;
    FMargeOnder := FNieuwMargeOnder;
    if not FVerwijderd and Visible then
      VerwerkRaak;
    FWijzigt := False;
  end;
end;

{ @0046B5A4 }
function TSprite.LeesVersie: string;
begin
  Result := '2.5c';
end;

{ @0046B5C8  oppervlak met de frames van het huidige frame }
function TSprite.LeesOppervlak: TSurface;
begin
  if FFrameNr = -1 then
    Result := nil
  else
    Result := FFrameLijst.Beelden[FFrameNr].Surface;
end;

{ @0046B5F0 }
function TSprite.LeesReeks: TName;
begin
  if FReeks = nil then
    Result := ''
  else
    Result := FReeks.Name;
end;

{ @0046B614 }
procedure TSprite.ZetReeks(Value: TName);
begin
  if Value = '' then
    FReeks := nil
  else
    FReeks := FReeksLijst.ReeksOpNaam(Value);
  FStep := 0;
end;

{ @0046B65C }
procedure TSprite.SetMouseCapture(Value: Boolean);
begin
  if Value <> FMuisVast then
  begin
    FMuisVast := Value;
    if Value then
      FSpriteVak.ZetVastlegPixie(Self)
    else
      FSpriteVak.ZetVastlegPixie(nil);
  end;
end;

{ @0046B688 }
procedure TSprite.SetVisible(Value: Boolean);
var
  NewVisible: Boolean;
begin
  NewVisible := Value;
  VerwerkZichtbaar(NewVisible);
  if NewVisible <> Visible then
    WijzigToestand(LeesX, LeesY, LeesZ, FMargeLinks, FMargeBoven, FMargeRechts,
      FMargeOnder, FFrameNr, NewVisible, LeesSchaal, [scVisible]);
end;

{ @0046B710 }
procedure TSprite.ZetSpiegelX(Value: Boolean);
begin
  if Value <> FSpiegelX then
  begin
    FSpiegelX := Value;
    Redraw;
  end;
end;

{ @0046B724 }
procedure TSprite.ZetSpiegelY(Value: Boolean);
begin
  if Value <> FSpiegelY then
  begin
    FSpiegelY := Value;
    Redraw;
  end;
end;

{ @0046B738 }
procedure TSprite.ZetX(Value: Integer);
begin
  if Value <> LeesX then
    WijzigToestand(Value, LeesY, LeesZ, FMargeLinks, FMargeBoven, FMargeRechts,
      FMargeOnder, FFrameNr, Visible, LeesSchaal, [scX]);
end;

{ @0046B7AC }
procedure TSprite.ZetY(Value: Integer);
begin
  if Value <> LeesY then
    WijzigToestand(LeesX, Value, LeesZ, FMargeLinks, FMargeBoven, FMargeRechts,
      FMargeOnder, FFrameNr, Visible, LeesSchaal, [scY]);
end;

{ @0046B820 }
procedure TSprite.SetLeft(Value: Integer);
begin
  if Value <> LeesLinks then
    ZetX(LeesHotSpotX + Value);
end;

{ @0046B84C }
procedure TSprite.SetTop(Value: Integer);
begin
  if Value <> LeesBoven then
    ZetY(LeesHotSpotY + Value);
end;

{ @0046B878 }
procedure TSprite.ZetZ(Value: Integer);
begin
  if Value <> LeesZ then
  begin
    SetZOrder(Value);
    WijzigToestand(LeesX, LeesY, Value, FMargeLinks, FMargeBoven, FMargeRechts,
      FMargeOnder, FFrameNr, Visible, LeesSchaal, [scZ]);
  end;
end;

{ @0046B8F8  sets Z and keeps the sprite box sorted }
procedure TSprite.SetZOrder(Value: Integer);
begin
  if Value <> LeesZ then
  begin
    inherited ZetZ(Value);
    if FSpriteVak <> nil then
      FSpriteVak.VernieuwZVolgorde(Self);
  end;
end;

{ @0046B924 }
procedure TSprite.ZetMargeLinks(Value: Integer);
begin
  if Value <> FMargeLinks then
    WijzigToestand(LeesX, LeesY, LeesZ, Value, FMargeBoven, FMargeRechts,
      FMargeOnder, FFrameNr, Visible, LeesSchaal, [scMarginLeft]);
end;

{ @0046B998 }
procedure TSprite.ZetMargeBoven(Value: Integer);
begin
  if Value <> FMargeBoven then
    WijzigToestand(LeesX, LeesY, LeesZ, FMargeLinks, Value, FMargeRechts,
      FMargeOnder, FFrameNr, Visible, LeesSchaal, [scMarginTop]);
end;

{ @0046BA0C }
procedure TSprite.ZetMargeRechts(Value: Integer);
begin
  if Value <> FMargeRechts then
    WijzigToestand(LeesX, LeesY, LeesZ, FMargeLinks, FMargeBoven, Value,
      FMargeOnder, FFrameNr, Visible, LeesSchaal, [scMarginRight]);
end;

{ @0046BA80 }
procedure TSprite.ZetMargeOnder(Value: Integer);
begin
  if Value <> FMargeOnder then
    WijzigToestand(LeesX, LeesY, LeesZ, FMargeLinks, FMargeBoven, FMargeRechts,
      Value, FFrameNr, Visible, LeesSchaal, [scMarginBottom]);
end;

{ @0046BAF4  X is de positie van het hotspot-punt }
function TSprite.LeesX: Integer;
begin
  Result := LeesLinks + Round(LeesHotSpotX * LeesSchaal);
end;

{ @0046BB50 }
function TSprite.LeesY: Integer;
begin
  Result := LeesBoven + Round(LeesHotSpotY * LeesSchaal);
end;

{ @0046BBAC }
function TSprite.GetWidth: Integer;
begin
  Result := FMargeLinks + FMargeRechts;
  if FFrameNr <> -1 then
    Inc(Result, FFrameLijst.Beelden[FFrameNr].Width);
end;

{ @0046BBE0 }
function TSprite.GetHeight: Integer;
begin
  Result := FMargeBoven + FMargeOnder;
  if FFrameNr <> -1 then
    Inc(Result, FFrameLijst.Beelden[FFrameNr].Height);
end;

{ @0046BC14 }
function TSprite.LeesHotSpotX: Integer;
begin
  if (FFrameNr = -1) or (FFrameLijst.Count = 0) then
    Result := FMargeLinks
  else
    Result := FFrameLijst.Beelden[FFrameNr].HotSpotX + FMargeLinks;
end;

{ @0046BC50 }
function TSprite.LeesHotSpotY: Integer;
begin
  if (FFrameNr = -1) or (FFrameLijst.Count = 0) then
    Result := FMargeBoven
  else
    Result := FFrameLijst.Beelden[FFrameNr].HotSpotY + FMargeBoven;
end;

{ @0046BC8C }
function TSprite.GetTransparent: TColor;
begin
  Result := FFrameLijst.TransparentColor;
end;

{ @0046BC94 }
procedure TSprite.SetTransparent(Value: TColor);
begin
  FFrameLijst.SetTransparentColor(Value);
end;

{ @0046BCA0 }
procedure TSprite.ZetSpriteVak(Value: TSpriteBox);
begin
  try
    if FSpriteVak <> nil then
      FSpriteVak.VerwijderPixie(Self);
    FSpriteVak := Value;
    if FSpriteVak <> nil then
    begin
      FSpriteVak.VoegPixieToe(Self);
      FFrameLijst.Surface.ConverteerNaar(FSpriteVak.Picture);
    end;
  finally
  end;
end;

{ @0046BD08 }
procedure TSprite.ZetFrameLijst(Value: TFrameList);
begin
  FFrameLijst.Assign(Value);
end;

{ @0046BD18 }
procedure TSprite.ZetReeksLijst(Value: TSequenceList);
begin
  FReeksLijst.Assign(Value);
end;

{ @0046BD24 }
function TSprite.LeesHuidigFrame: TName;
begin
  if FFrameNr = -1 then
    Result := ''
  else
    Result := FFrameLijst.Beelden[FFrameNr].Name;
end;

{ @0046BD58 }
procedure TSprite.ZetHuidigFrame(Value: TName);
var
  Index: Integer;
begin
  if (Value = '') and (csDesigning in ComponentState) then
    ZetFrameNr(-1)
  else if (Value <> '') and (Value <> 'None') then
  begin
    Index := FFrameLijst.IndexOf(Value);
    if Index <> -1 then
      ZetFrameNr(Index)
    else
      raise ESprite.Create('Frame not found: ' + Value);
  end;
end;

{ @0046BE60  LET OP: tijdens het uitvoeren wordt FrameIndex -1 genegeerd }
procedure TSprite.ZetFrameNr(Value: Integer);
begin
  if csDesigning in ComponentState then
  begin
    if (Value >= -1) and (Value < FFrameLijst.Count) then
      FFrameNr := Value
    else
      raise ESprite.Create('Frameindex should be between -1 and ' +
        IntToStr(FFrameLijst.Count - 1));
  end
  else if Value <> -1 then
    WijzigToestand(LeesX, LeesY, LeesZ, FMargeLinks, FMargeBoven, FMargeRechts,
      FMargeOnder, Value, Visible, LeesSchaal, [scFrameIndex]);
end;

{ @0046BF94 }
procedure TSprite.ZetSchaal(Value: Double);
begin
  if LeesSchaal <> Value then
    WijzigToestand(LeesX, LeesY, LeesZ, FMargeLinks, FMargeBoven, FMargeRechts,
      FMargeOnder, FFrameNr, Visible, Value, [scScale]);
end;

{ @0046C010 }
function TSprite.LeesBevroren: Boolean;
begin
  Result := FBevroren;
end;

{ @0046C018 }
procedure TSprite.ZetPrioriteit(Value: Integer);
begin
  FKlok.Priority := Value;
end;

{ @0046C024 }
function TSprite.LeesPrioriteit: Integer;
begin
  Result := FKlok.Priority;
end;

{ @0046C030 }
function TSprite.LeesGedrag(Name: string): TBehaviour;
begin
  Result := FGedragingen.Find(Name);
end;

{ @0046C084 }
procedure TSprite.VoegGedragToe(Name: string; Behaviour: TBehaviour);
begin
  if Behaviour <> nil then
  begin
    Behaviour.FName := Name;
    Behaviour.ZetSprite(Self);
    FGedragingen.Add(Behaviour);
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
function TSpriteList.SpriteOpNaam(Name: string): TSprite;
var
  I: Integer;
begin
  for I := 0 to Count - 1 do
    if GelijkTekst2(LeesSprite(I).Name, Name) then
    begin
      Result := LeesSprite(I);
      Exit;
    end;
  Result := nil;
end;

{ @0046C180 }
function TSpriteList.LeesSprite(Index: Integer): TSprite;
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
    Ontkoppel;
  inherited Destroy;
end;

{ @0046C218 }
procedure TBehaviour.ReeksKlaar(Sender: TObject; var Herhalingen: Integer);
begin
end;

{ @0046C21C }
procedure TBehaviour.Raak(Sender: TObject; HitWhom: TSprite);
begin
end;

{ @0046C220 }
procedure TBehaviour.Move(Sender: TObject; var X, Y, Z: Integer);
begin
end;

{ @0046C228 }
procedure TBehaviour.NaBlit(Sender: TObject; Surface: TSurface; X, Y: Integer;
  Where: TRect; Size: Real);
begin
end;

{ @0046C248 }
procedure TBehaviour.VoorBlit(Sender: TObject; Surface: TSurface; X, Y: Integer;
  Where: TRect; Size: Real);
begin
end;

{ @0046C268 }
procedure TBehaviour.MouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
begin
end;

{ @0046C270 }
procedure TBehaviour.MuisVerlaten(Sender: TObject);
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
procedure TBehaviour.ZichtbaarWijziging(Sender: TObject; var NewVisible: Boolean);
begin
end;

{ @0046C288 }
procedure TBehaviour.ZetSprite(Value: TSprite);
begin
  FSprite := Value;
end;

{ @0046C28C }
procedure TBehaviour.Ontkoppel;
begin
  SetActive(False);
  FSprite.FGedragingen.Remove(Self);
end;

{ @0046C2AC }
procedure TBehaviour.SetActive(Value: Boolean);
begin
  FActive := Value;
end;

{ @0046C2B0  deactiveert zichzelf en activeert VolgendGedrag }
procedure TBehaviour.Afronden;
begin
  SetActive(False);
  if Assigned(FOnKlaar) then
    FOnKlaar(Self);
  if FVolgendGedrag <> '' then
    FSprite.LeesGedrag(FVolgendGedrag).SetActive(True);
end;

{ ------------------------------------------------------------- TBehaviourList }

{ @0046C2E8 }
function TBehaviourList.Add(Behaviour: TBehaviour): TBehaviour;
begin
  inherited Add(Behaviour);
  Result := Behaviour;
end;

{ @0046C2F8 }
function TBehaviourList.LeesGedrag(Index: Integer): TBehaviour;
begin
  Result := TObject(Get(Index)) as TBehaviour;
end;

{ @0046C318  hoofdlettergevoelig }
function TBehaviourList.Find(Name: string): TBehaviour;
var
  I: Integer;
begin
  for I := 0 to Count - 1 do
    if LeesGedrag(I) <> nil then
      if LeesGedrag(I).FName = Name then
      begin
        Result := LeesGedrag(I);
        Exit;
      end;
  Result := nil;
end;

{ @0046C3A0  wist alleen de plek; Pack verwijdert hem }
function TBehaviourList.Remove(Behaviour: TBehaviour): Integer;
begin
  Result := IndexOf(Behaviour);
  if Result <> -1 then
    WisItem(Result);
end;

{ @0046C3C0 }
procedure TBehaviourList.WisItem(Index: Integer);
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
    if LeesGedrag(I) = nil then
      Delete(I);
end;

{ @0046C400 }
function TBehaviourList.IsActief(Index: Integer): Boolean;
begin
  Result := (LeesGedrag(Index) <> nil) and LeesGedrag(Index).FActive;
end;

{ De finalization bij @0046C42C geeft SpriteMotto en SpriteMotto2 vrij. }

end.
