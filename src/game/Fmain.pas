unit Fmain;

{ TfrmMain: het hoofdvenster van Virtueel Zoetermeer. Het bevat het spelmodel
  (TSettings, TStatus, TWorld), de stadsweergave (TView) op het spritevak, en
  implementeert de hele gebruikersinterface: de gebouwknoppen ("knoppen") per
  pagina/tabblad, een gebouw naar de kaart slepen, hints, de dialoogsprites
  (uitlegmemo met de knoppen Start/Cancel/Ja/Nee), de criteriummeters,
  het jaarrapport, de niveau- en rondelogica, scrollen en zoomen, en opslaan
  en laden van een stad.
  Gedecompileerd uit ROS.exe v1.1, code 00479510-0047FD67. }

{$I zm.inc}

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, Dialogs,
  StdCtrls, uSurface, uSprite, uSpritebox, uTiming, cEditCtr, Sprbehav, Uctrl,
  Usett, Uworld, Uview, uAutos, fBack;

type
  { VMT 0047955C, instantiegrootte $48C }
  TfrmMain = class(TCtrlForm)
    sbStage: TSpriteBox;                 { +0x2D0 }
    memoMessages: TMemo;                 { +0x2D4 }
    butReady: TButton;                   { +0x2D8 }
    memoUitleg: TMemo;                   { +0x2DC }
    butStart: TButton;                   { +0x2E0 }
    butCancel: TButton;                  { +0x2E4 }
    spriteStart: TSprite;                { +0x2E8 }
    spriteCancel: TSprite;               { +0x2EC }
    spriteUitleg: TSprite;               { +0x2F0 }
    spriteUitlegBackground: TSprite;     { +0x2F4 }
    spriteKop: TSprite;                  { +0x2F8 }
    memoKop: TMemo;                      { +0x2FC }
    spriteGeld: TSprite;                 { +0x300 }
    spriteHint: TSprite;                 { +0x304 }
    spriteMessages: TSprite;             { +0x308 }
    spriteReady: TSprite;                { +0x30C }
    butStop: TButton;                    { +0x310 }
    spriteStop: TSprite;                 { +0x314 }
    spriteMeeuw: TSprite;                { +0x318 }
    timerMeeuw: TFastTimer;              { +0x31C }
    lblKnopOffset: TLabel;               { +0x320 }
    butAlgemeen: TButton;                { +0x324 }
    butWegenEnSpoor: TButton;            { +0x328 }
    butStadsvoorzieningen: TButton;      { +0x32C }
    timerKlachten: TFastTimer;           { +0x330 }
    spriteStoep: TSprite;                { +0x334 }
    butSportEnRecreatie: TButton;        { +0x338 }
    spriteAuto: TSprite;                 { +0x33C }
    butWijkvoorzieningen: TButton;       { +0x340 }
    lblCoo: TLabel;                      { +0x344 }
    lblVakje: TLabel;                    { +0x348 }
    lblVakjeCoo: TLabel;                 { +0x34C }
    Comment2: TComment;                  { +0x350 }
    lblGroen: TLabel;                    { +0x354 }
    lblVeiligheid: TLabel;               { +0x358 }
    lblVrijetijd: TLabel;                { +0x35C }
    lblCultuur: TLabel;                  { +0x360 }
    lblMobiliteit: TLabel;               { +0x364 }
    lblWerk: TLabel;                     { +0x368 }
    lblOverlast: TLabel;                 { +0x36C }
    Label1: TLabel;                      { +0x370 }
    spriteJa: TSprite;                   { +0x374 }
    spriteNee: TSprite;                  { +0x378 }
    butJa: TButton;                      { +0x37C }
    butNee: TButton;                     { +0x380 }
    butLoad: TButton;                    { +0x384 }
    butSave: TButton;                    { +0x388 }
    spriteLoad: TSprite;                 { +0x38C }
    spriteSave: TSprite;                 { +0x390 }
    SaveDialog: TSaveDialog;             { +0x394 }
    OpenDialog: TOpenDialog;             { +0x398 }
    lblContents: TLabel;                 { +0x39C }
    lblSubtype: TLabel;                  { +0x3A0 }
    lblWijk: TLabel;                     { +0x3A4 }
    spriteWijk: TSprite;                 { +0x3A8 }
    timerMain: TFastTimer;               { +0x3AC }
    spriteWijkvoorzieningen: TSprite;    { +0x3B0 }
    spriteAlgemeen: TSprite;             { +0x3B4 }
    spriteWegenEnSpoor: TSprite;         { +0x3B8 }
    spriteSportEnRecreatie: TSprite;     { +0x3BC }
    spriteStadsvoorzieningen: TSprite;   { +0x3C0 }
    timerRecalc: TFastTimer;             { +0x3C4  Tag: seconden tot de reistijden opnieuw worden berekend }
    Label2: TLabel;                      { +0x3C8 }
    lblRecalc: TLabel;                   { +0x3CC }
    lblTimers: TLabel;                   { +0x3D0 }
    spriteZoomuit: TSprite;              { +0x3D4 }
    spriteScrollup: TSprite;             { +0x3D8 }
    spriteZoomin: TSprite;               { +0x3DC }
    spriteScrollleft: TSprite;           { +0x3E0 }
    spriteScrolldown: TSprite;           { +0x3E4 }
    spriteScrollright: TSprite;          { +0x3E8 }
    butZoomuit: TButton;                 { +0x3EC }
    butScrollup: TButton;                { +0x3F0 }
    butScrollleft: TButton;              { +0x3F4 }
    butZoomin: TButton;                  { +0x3F8 }
    butScrolldown: TButton;              { +0x3FC }
    butScrollright: TButton;             { +0x400 }
    spriteLevel: TSprite;                { +0x404 }
    lblLevel: TLabel;                    { +0x408 }
    Memo1: TMemo;                        { +0x40C }
    Button1: TButton;                    { +0x410 }
    procedure sbStageStarted(Sender: TObject);
    procedure butPlaceSomethingClick(Sender: TObject);
    procedure sbStageMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure sbStageMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
    procedure butReadyClick(Sender: TObject);
    procedure butStartClick(Sender: TObject);
    procedure butCancelClick(Sender: TObject);
    procedure spriteHintAfterBlit(Sender: TObject; Surface: TSurface; X, Y: Integer;
      Where: TRect; Size: Real);
    procedure sbStageKeyPress(Sender: TObject; var Key: Char);
    procedure butSaveClick(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure butStopClick(Sender: TObject);
    procedure timerMeeuwTimer(Sender: TObject);
    procedure spriteMeeuwFinishSequence(Sender: TObject; var Herhalingen: Integer);
    procedure sbStageKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure tabClick(Sender: TObject);
    procedure timerKlachtenTimer(Sender: TObject);
    procedure Label1Click(Sender: TObject);
    procedure butJaClick(Sender: TObject);
    procedure butNeeClick(Sender: TObject);
    procedure butLoadClick(Sender: TObject);
    procedure timerMainTimer(Sender: TObject);
    procedure timerRecalcTimer(Sender: TObject);
    procedure butZoomuitClick(Sender: TObject);
    procedure butZoominClick(Sender: TObject);
    procedure butScrollupClick(Sender: TObject);
    procedure butScrollleftClick(Sender: TObject);
    procedure butScrolldownClick(Sender: TObject);
    procedure butScrollrightClick(Sender: TObject);
    procedure Button1Click(Sender: TObject);
  public
    { publiek in plaats van private, zodat het testharnas (src/tests) de spelstatus kan lezen;
      de zichtbaarheid heeft geen invloed op de indeling }
    FSjablonen: TSpriteList;             { +0x414  een sjabloonsprite per objecttype (Inhoud) }
    FKnoppen: TSpriteList;               { +0x418  de knopafbeeldingsprites 'k_<name>' }
    FSleepSprite: TSprite;                { +0x41C  gebouw dat naar de kaart wordt gesleept }
    FSleepNr: Integer;                 { +0x420  de index ervan in Inhoud }
    FWereld: TWorld;                      { +0x424 }
    FWeergave: TView;                        { +0x428 }
    FStatus: TStatus;                    { +0x42C }
    FInstellingen: TSettings;                { +0x430 }
    FNiveau: Integer;                     { +0x434 }
    FGereserveerd438: Integer;               { +0x438  door ZetSleep op 0 gezet, nooit gelezen }
    FGeldSprite: TSprite;                { +0x43C  toont het geld (Geld) }
    FDialoog: Boolean;                    { +0x440  het dialoogvenster (ToonDialoog) is zichtbaar }
    FHintZichtbaar: Boolean;               { +0x441 }
    FHintTekst: string;                   { +0x444  tekst die op spriteHint wordt getekend }
    FAchtergrond: TSurface;               { +0x448  kopie van het lege spritevak-plaatje }
    FGebeurtenis: string;                      { +0x44C  laatste gebeurtenis die aan Dialoog is doorgegeven }
    FBouwMelding: string;                    { +0x450  waarom het laatste gebouw niet geplaatst kon worden }
    FOudeGrootte: TPoint;                    { +0x454  schermgrootte voor ZetResolutie (X = 0: ongewijzigd) }
    FDirectX: Boolean;                   { +0x45C  schermmodus is ingesteld met DirectX }
    FGestart: Boolean;                   { +0x45D  het eerste niveau is gestart }
    FPages: TStringList;                 { +0x460  paginanaam -> aantal knoppen erop }
    FGeldOpschrift: TCaption;              { +0x464  tekst van FGeldSprite }
    FZwart: TfrmBlack;                   { +0x468 }
    FPagina: string;                       { +0x46C  pagina (tabblad) waarvan de knoppen worden getoond }
    FAutos: TAutoSprite;                 { +0x470 }
    FCriteriaSprites: array[0..5] of TSprite;  { +0x474  meters voor Criteria[0..5] }
    procedure WMEraseBkgnd(var Message: TWMEraseBkgnd); message WM_ERASEBKGND;
    procedure LeesSprites(Niveau: Integer);
    procedure MaakKnoppen(Niveau: Integer);
    procedure ToonLaden(Bericht: string);
    procedure ZetSleep(Naam: string; Nr: Integer);
    procedure ToonDialoog(Knoppen: Integer; Kop, Uitleg: string);
    procedure VerbergDialoog;
    procedure Rapport(Uitgebreid: Boolean);
    procedure Dialoog(Gebeurtenis: string);
    function CritNr(C: Byte): Integer;
    procedure VerversStatus;
    procedure StartNiveau(Niveau: Integer);
    procedure StatusWijziging(Sender: TObject);
    procedure ToonHintSprite(Tekst: string);
    procedure VerbergHintSprite;
    procedure ToonBouwHint(X, Y: Integer; Naam: string);
    procedure ToonKnopHint(X, Y: Integer);
    procedure ToonCelHint(X, Y: Integer);
    procedure ZetResolutie(Grootte: TPoint);
    procedure ToonPagina(Blad: string);
    procedure Afsluiten;
    procedure CritMuisBeweging(Sender: TObject; Shift: TShiftState; X, Y: Integer);
    function ComponentBestaat(Naam: string): Boolean;
  public
    function LeesWeergave: TView;
    property Weergave: TView read LeesWeergave;
  end;

var
  frmMain: TfrmMain;   { 0048B168 }

implementation

uses
  uString, uTool, uPixie, Uconst, Sprframe, uTrein, uResizeScreen, uQuickDirectX,
  fReport
  {$IFDEF FPC}, ZMRandom, ZMKlok{$ENDIF}  { PORT: Delphi's Random en GetTickCount };

{$IFNDEF FPC}
{$R *.dfm}  { Alleen Delphi: de draagbare build laadt formulieren uit de ROS.exe van de gebruiker }
{$ENDIF}

{$J+}
const
  GestartNiveau: string = '';   { 00489198: niveaunummer (als tekst) dat het laatst is gestart door butStartClick }
{$J-}

{ @00479F50 }
procedure TfrmMain.WMEraseBkgnd(var Message: TWMEraseBkgnd);
begin
end;

{ @00479F54 }
procedure TfrmMain.FormCreate(Sender: TObject);
var
  Antwoord: string;
  NieuweGrootte: TPoint;
  Gedrag: TBehavButton;
begin
  ProfStart := 0;
  ProfBeeld := 0;
  ProfAutos := 0;
  ProfSprites := 0;
  ProfOverig := 0;
  Randomize;
  Width := 1024;
  Height := 768;
  FGestart := False;
  FZwart := TfrmBlack.Create(nil);
  FZwart.SendToBack;
  FZwart.Top := 0;
  FZwart.Left := 0;
  FZwart.Width := Screen.Width;
  FZwart.Height := Screen.Height;
  FZwart.lblVersion.Left := FZwart.imgLoading.Left + 664 - 328;
  FZwart.lblVersion.Top := FZwart.imgLoading.Top + 408 - 160;
  FZwart.lblVersion.Caption := 'Versie 1.1';
  FZwart.Visible := True;
  ToonLaden('Started');
  FInstellingen := TSettings.Create('ZoetermeerLevels.ini');
  if Screen.Width < 1024 then
  begin
    case Application.MessageBox('Het scherm is niet ingesteld op de juiste grootte. ' +
      'Om dit spel te kunnen draaien, moeten de eigenschappen van het scherm worden ' +
      'aangepast. Zal ik deze verandering maken?', 'Scherminstellingen verkeerd',
      MB_OKCANCEL or MB_ICONQUESTION) of
      IDCANCEL: Antwoord := 'Quit';
      IDOK: Antwoord := 'Yes';
    end;
    FOudeGrootte.X := 0;
    FOudeGrootte.Y := 0;
    if Antwoord = 'Quit' then
      Afsluiten;
    if Antwoord = 'Yes' then
    begin
      FOudeGrootte.X := Screen.Width;
      FOudeGrootte.Y := Screen.Height;
      NieuweGrootte.X := 1024;
      NieuweGrootte.Y := 768;
      ZetResolutie(NieuweGrootte);
    end;
  end;
  FSjablonen := TSpriteList.Create;
  FKnoppen := TSpriteList.Create;
  spriteHint.Transparent := clGeenTransparant;
  FStatus := TStatus.Create;
  FWereld := TWorld.Create(FInstellingen, FStatus);
  FWeergave := TView.Create(FSjablonen, sbStage, FWereld, FInstellingen, FStatus);
  butLoad.Left := 829;
  butLoad.Top := 32;
  butSave.Left := 893;
  butSave.Top := 32;
  butStop.Left := 957;
  butStop.Top := 32;
  butAlgemeen.Left := 829;
  butAlgemeen.Top := 623;
  butWegenEnSpoor.Left := 893;
  butWegenEnSpoor.Top := 623;
  butWijkvoorzieningen.Left := 957;
  butWijkvoorzieningen.Top := 623;
  butSportEnRecreatie.Left := 829;
  butSportEnRecreatie.Top := 657;
  butStadsvoorzieningen.Left := 893;
  butStadsvoorzieningen.Top := 657;
  FPages := TStringList.Create;
  FPages.Values['Algemeen'] := '0';
  FPages.Values['Wijkvoorzieningen'] := '1';
  FPages.Values['WegenEnSpoor'] := '1';
  FPages.Values['Stadsvoorzieningen'] := '1';
  FPages.Values['SportEnRecreatie'] := '1';
  butZoomuit.Left := 846;
  butZoomuit.Top := 574;
  butZoomuit.Visible := True;
  butZoomin.Left := 975;
  butZoomin.Top := 574;
  butZoomin.Visible := True;
  butScrollup.Left := 911;
  butScrollup.Top := 559;
  butScrollup.Visible := True;
  butScrollleft.Left := 883;
  butScrollleft.Top := 587;
  butScrollleft.Visible := True;
  butScrolldown.Left := 911;
  butScrolldown.Top := 587;
  butScrolldown.Visible := True;
  butScrollright.Left := 939;
  butScrollright.Top := 587;
  butScrollright.Visible := True;
  LaadInhoud;
  LeesSprites(1);
  FAchtergrond := nil;
  MaakKnoppen(1);
  FGeldSprite := TSprite.Create(Self);
  with spriteGeld do
  begin
    MoveTo(916, 179);
    FrameIndex := 0;
    Visible := True;
  end;
  spriteHint.LeesOppervlak.SetSize(150, 100, False);
  Gedrag := TBehavButton.Create('Ja_up', 'Ja_dn', 'Ja_or');
  Gedrag.OnClick := butJaClick;
  spriteJa.VoegGedragToe('KNOP', Gedrag);
  spriteJa.LeesGedrag('KNOP').Active := True;
  Gedrag := TBehavButton.Create('Nee_up', 'Nee_dn', 'Nee_or');
  Gedrag.OnClick := butNeeClick;
  spriteNee.VoegGedragToe('KNOP', Gedrag);
  spriteNee.LeesGedrag('KNOP').Active := True;
  VoegTekstGedragToe(spriteWijk, '', 0, 0, lblWijk.Font);
  VoegTekstGedragToe(spriteLevel, '', 0, 0, lblLevel.Font);
  spriteWijk.VerplaatsMet(lblWijk.Left, lblWijk.Top, -5000);
  spriteWijk.MargeRechts := 200;
  spriteWijk.MargeOnder := 20;
  spriteWijk.FrameIndex := 0;
  spriteWijk.Visible := True;
  spriteLevel.VerplaatsMet(lblLevel.Left, lblLevel.Top, -5000);
  spriteLevel.MargeRechts := 200;
  spriteLevel.MargeOnder := 20;
  spriteLevel.FrameIndex := 0;
  spriteLevel.Visible := True;
  KoppelBesturingen(True, sbStage);
  Visible := True;
end;

{ @0047A904 }
procedure TfrmMain.sbStageStarted(Sender: TObject);
var
  Lettertype: TFont;
begin
  Lettertype := TFont.Create;
  Lettertype.Name := 'Arial';
  Lettertype.Color := clWhite;
  Lettertype.Size := 12;
  Lettertype.Style := [fsBold];
  with FGeldSprite do
  begin
    SpriteBox := sbStage;
    Transparent := clBlack;
    FrameList.VoegFrameToe('null', NieuwOppervlakGrootte(100, 20));
    FrameIndex := 0;
    FGeldOpschrift := VoegTekstGedragToe(FGeldSprite, '', 0, 0, Lettertype);
    MoveTo(868, 191);
    Visible := True;
  end;
  Lettertype.Free;
  FStatus.OnChange := StatusWijziging;
  FStatus.Taak := TTask.Create(0, 0);
  FAchtergrond := NieuwOppervlak;
  FAchtergrond.Assign(sbStage.Picture);
  FHintZichtbaar := False;
  if FInstellingen.AutosZichtbaar then
    FAutos := MaakAutos(sbStage, spriteAuto, FWereld, FWeergave, FInstellingen);
  Trein := TTrein.Create(FWeergave.TreinSprite, FWereld);
  timerMeeuw.Enabled := True;
  timerMain.Enabled := True;
  Dialoog('StartGame');
end;

{ @0047AC48 }
procedure TfrmMain.LeesSprites(Niveau: Integer);
var
  BestandsNaam: string;
  Bestanden: TStringList;
  Bmp: TSurface;
  Map: string;

  { @0047AACC }
  procedure LaadFrames(Sprite: TSprite; Voorvoegsel: string);
  var
    I: Integer;
    Deel: string;
  begin
    ToonLaden(Voorvoegsel);
    Voorvoegsel := KleinStr(Voorvoegsel);
    for I := 0 to Bestanden.Count - 1 do
    begin
      BestandsNaam := KleinStr(Bestanden[I]);
      if BegintMet(BestandsNaam, Voorvoegsel) then
      begin
        Bmp := NieuwOppervlak;
        Bmp.LoadFromFile(VoegPadToe(Map, BestandsNaam));
        Deel := SplitsEerste(BestandsNaam, '.');
        Sprite.FrameList.VoegFrameToe(Deel, Bmp);
        Bmp.Free;
      end;
    end;
  end;

var
  C: Byte;
  I, J, L: Integer;
  Naam: string;
  Sprite, Knop: TSprite;
  Deel: string;
begin
  Map := VoegPadToe(VoegPadToe(AppPad, 'images'), '8bits');
  Bestanden := TStringList.Create;
  ZoekBestanden(VoegPadToe(Map, '*.bmp'), $3F {faAnyFile}, Bestanden);
  if Niveau = 1 then
  begin
    LaadFrames(spriteStoep, 'Stoep');
    LaadFrames(FWeergave.TreinSprite, 'Trein');
    for C := 0 to 5 do
      if not ComponentBestaat(Criteria[C]) then
      begin
        FCriteriaSprites[C] := TSprite.Create(Self);
        FCriteriaSprites[C].SpriteBox := sbStage;
        FCriteriaSprites[C].Name := Criteria[C];
        LaadFrames(FCriteriaSprites[C], 'Cr_' + Criteria[C]);
        FCriteriaSprites[C].MoveTo(C * 100 + 225 - 1, 30);
        FCriteriaSprites[C].Visible := False;
        FCriteriaSprites[C].OnMouseMove := CritMuisBeweging;
      end;
  end;
  for I := 0 to AantalInhoud - 1 do
  begin
    Naam := Inhoud[I].Name;
    if not ComponentBestaat(Naam) then
    begin
      if (Copy(Naam, 1, 5) = 'Rails') or (Copy(Naam, 1, 4) = 'Snel') then
        L := 1
      else
        L := Inhoud[I].Speelniveau;
      if not Inhoud[I].SpritesGeladen and (L <= Niveau) then
      begin
        ToonLaden(Inhoud[I].Beschrijving);
        Sprite := TSprite.Create(Self);
        Sprite.Name := Naam;
        Sprite.SpriteBox := sbStage;
        FSjablonen.Add(Sprite);
        if Naam <> 'Onbereikbaar' then
        begin
          if not ComponentBestaat('k_' + Naam) then
          begin
            Knop := TSprite.Create(Self);
            Knop.Name := 'k_' + Naam;
            Knop.SpriteBox := sbStage;
            FKnoppen.Add(Knop);
          end;
          { LET OP: als 'k_<Name>' al bestaat, behoudt Knop zijn vorige waarde }
        end
        else
          Knop := nil;
        for J := 0 to Bestanden.Count - 1 do
        begin
          BestandsNaam := KleinStr(Bestanden[J]);
          if BegintMet(BestandsNaam, KleinStr(Naam)) then
          begin
            Bmp := NieuwOppervlak;
            Bmp.LoadFromFile(VoegPadToe(Map, BestandsNaam));
            with Sprite.FrameList do
            begin
              Deel := SplitsEerste(BestandsNaam, '.');
              VoegFrameToe(Deel, Bmp);
              Beelden[Count - 1].HotSpotX := Inhoud[I].GrondvlakX * TegelBreedte;
              Beelden[Count - 1].HotSpotY := Beelden[Count - 1].Height - 44;
            end;
            Bmp.Free;
          end
          else if BegintMet(BestandsNaam, 'k-' + KleinStr(Naam)) then
          begin
            Bmp := NieuwOppervlak;
            Bmp.LoadFromFile(VoegPadToe(Map, BestandsNaam));
            Deel := SplitsEerste(BestandsNaam, '.');
            BestandsNaam := VerwijderLinks(Deel, 2);
            if EindigtMet(BestandsNaam, '_ov') then
            begin
              Deel := SplitsEerste(BestandsNaam, '_');
              BestandsNaam := Deel + '_or';
            end;
            with Knop.FrameList do
            begin
              VoegFrameToe(BestandsNaam, Bmp);
              if EindigtMet(BestandsNaam, '_tr') then
              begin
                Beelden[Count - 1].HotSpotX := Inhoud[I].GrondvlakX * TegelBreedte;
                Beelden[Count - 1].HotSpotY := Beelden[Count - 1].Height - 44;
                if Inhoud[I].GrondvlakY = 5 then
                  Map := Map + '';   { LET OP: in het origineel een no-op (LStrCat met '') }
              end;
            end;
            Bmp.Free;
          end;
        end;
        if Sprite.FrameList.Count = 0 then
          Fout('ReadSprites: No images found for template sprite ' + Sprite.Name);
        if (Naam <> 'AndereStad') and (Naam <> 'Onbereikbaar') and
          (Knop.FrameList.Count = 0) then
          Fout('ReadSprites: No images found for knop sprite ' + Knop.Name);
        Inhoud[I].SpritesGeladen := True;
      end;
    end;
  end;
  Bestanden.Free;
end;

{ @0047B470 }
procedure TfrmMain.MaakKnoppen(Niveau: Integer);
var
  I: Integer;
  Plek: Integer;
  Gedrag: TBehavButton;
  Sprite: TSprite;
begin
  for I := 0 to AantalInhoud - 3 do
    if (Inhoud[I].Speelniveau <= Niveau) and not Inhoud[I].KnopGemaakt and
      not ComponentBestaat('KNOP' + IntToStr(I)) then
    begin
      Plek := StrNaarIntDef0(FPages.Values[Inhoud[I].Page]);
      Gedrag := TBehavButton.Create(Inhoud[I].Name + '_up', Inhoud[I].Name + '_dn',
        Inhoud[I].Name + '_or');
      Gedrag.OnClick := butPlaceSomethingClick;
      Sprite := FKnoppen.SpriteOpNaam('k_' + Inhoud[I].Name);
      if Sprite = nil then
        Fout('Could not find sprite ' + Inhoud[I].Name);
      Sprite := TSprite.MaakKopie(Sprite);
      Sprite.SpriteBox := sbStage;
      Sprite.Tag := I;
      Sprite.Z := -1000;
      Sprite.Name := 'KNOP' + IntToStr(I);
      Sprite.X := (Plek mod 3) * 64 + 829;
      Sprite.Y := (Plek div 3) * 64 + 228;
      FPages.Values[Inhoud[I].Page] := IntTekst(Plek + 1);
      Sprite.VoegGedragToe('KNOP', Gedrag);
      Sprite.LeesGedrag('KNOP').Active := True;
      Inhoud[I].KnopGemaakt := True;
    end;
  ToonPagina(Inhoud[0].Page);
end;

{ @0047B778 }
procedure TfrmMain.ToonLaden(Bericht: string);
var
  Deel: string;
begin
  if Pos('_', Bericht) > 0 then
    Deel := SplitsEerste(Bericht, '_');
  with FZwart.lblLoading do
  begin
    Caption := Bericht;
    Left := FZwart.imgLoading.Left + 12;
    Top := FZwart.imgLoading.Top + 120;
  end;
  Application.ProcessMessages;
end;

{ @0047B84C }
procedure TfrmMain.FormDestroy(Sender: TObject);
begin
  OntkoppelBesturingen(True, sbStage);
  timerMeeuw.Enabled := False;
  if FAchtergrond <> nil then
    FAchtergrond.Free;
  FWeergave.Free;
  FWereld.Free;
  FInstellingen.Free;
  FStatus.Free;
end;

{ @0047B8A8 }
procedure TfrmMain.ZetSleep(Naam: string; Nr: Integer);
var
  Beeldnaam: string;
  Sjabloon: TSprite;
begin
  Beeldnaam := Naam + '_tr';
  Naam := 'k_' + Naam;
  if FSleepSprite <> nil then
    FSleepSprite.Verwijder;
  Sjabloon := FKnoppen.SpriteOpNaam(Naam);
  if Sjabloon = nil then
    Fout('SetDrag: Sprite niet gevonden: ' + Naam);
  FSleepSprite := TSprite.MaakKopie(Sjabloon);
  if FSleepSprite.FrameList.IndexOf(Beeldnaam) = -1 then
    Fout('PaintCell: could not find frame ' + Beeldnaam + ' in sprite ' + FSleepSprite.Name);
  FSleepSprite.CurrentFrame := Beeldnaam;
  FSleepSprite.Schaalfactor := Zoom;
  FSleepNr := Nr;
  FGereserveerd438 := 0;
end;

{ @0047BAAC }
procedure TfrmMain.butPlaceSomethingClick(Sender: TObject);
begin
  if not FDialoog then
  begin
    if Sender is TBehaviour then
      Sender := (Sender as TBehaviour).Sprite;
    ZetSleep(Inhoud[(Sender as TSprite).Tag].Name, (Sender as TSprite).Tag);
  end;
end;

{ @0047BB08 }
procedure TfrmMain.sbStageMouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
var
  G, P: TPoint;
  Cell: TCell;
  Info: TInhoudInfo;
  Melding: string;
begin
  VerbergHintSprite;
  if FSleepSprite <> nil then
  begin
    P := Point(X, Y);
    if PtInRect(Rect(30, 81, 822, 686), P) then
    begin
      G := SchermNaarRaster(P);
      Cell := FWereld.LeesCel(G.X, G.Y);
      if Cell = nil then
      begin
        if not PtInRect(BeeldRect, Point(X, Y)) then
        begin
          FSleepSprite.Free;
          FSleepSprite := nil;
        end;
      end
      else
      begin
        Info := Inhoud[FSleepNr];
        Melding := Cell.KanBouwen(Info.Name);
        FBouwMelding := Melding;
        if FBouwMelding = '' then
        begin
          if Info.Uniek or (Info.GrondvlakX > 1) or (Info.GrondvlakY > 1) then
          begin
            FSleepSprite.Free;
            FSleepSprite := nil;
          end;
          Cell.Bouw(Info.Name);
          timerKlachtenTimer(timerKlachten);
          timerKlachten.Enabled := True;
          FWeergave.VerwerkWijzigingen;
          ToonPagina('');
        end;
        VerversStatus;
      end;
    end;
  end;
end;

{ @0047BCF4 }
procedure TfrmMain.sbStageMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
var
  G, P: TPoint;
  Cell: TCell;
  Wijk: TWijk;
begin
  if FGestart then
  begin
    P := Point(X, Y);
    G := SchermNaarRaster(P);
    if FSleepSprite <> nil then
    begin
      FSleepSprite.VerplaatsNaar3D(P.X, P.Y, -3000);
      FSleepSprite.Visible := PtInRect(BeeldRect, Point(X, Y));
      if FSleepSprite.Visible then
        ToonBouwHint(X, Y, Inhoud[FSleepNr].Name)
      else
        ToonKnopHint(X, Y);
    end
    else if PtInRect(BeeldRect, P) then
      ToonCelHint(X, Y)
    else
      ToonKnopHint(X, Y);
    Cell := FWereld.LeesCel(G.X, G.Y);
    if Cell = nil then
    begin
      (spriteWijk.LeesGedrag('CONTROL_BEHAV') as TBehavText).ZetOnderschrift('memobg', '--');
      spriteWijk.Redraw;
    end
    else
    begin
      Wijk := FWereld.Wijken[Cell.Wijk];
      if Cell.Wijk < FWereld.OpenWijken then
        (spriteWijk.LeesGedrag('CONTROL_BEHAV') as TBehavText).ZetOnderschrift('memobg', Wijk.Naam)
      else
        (spriteWijk.LeesGedrag('CONTROL_BEHAV') as TBehavText).ZetOnderschrift('memobg', '');
      spriteWijk.Redraw;
    end;
  end;
end;

{ @0047BEDC
  Buttons: 1 = Start, 4 = Ja, 8 = Nee. Regels van Uitleg zijn gescheiden door '\n'. }
procedure TfrmMain.ToonDialoog(Knoppen: Integer; Kop, Uitleg: string);
var
  Regel: string;
  Memo: TBehavMemo;
begin
  FDialoog := True;
  VerbergHintSprite;
  memoMessages.Lines.Clear;
  { LET OP: test de eigen Text van het formulier (het opschrift), niet Uitleg; is altijd waar }
  if Text <> '' then
  begin
    memoUitleg.Lines.Clear;
    while Uitleg <> '' do
    begin
      Regel := SplitsEerste(Uitleg, '\n');
      memoUitleg.Lines.Add(Regel);
    end;
  end;
  if Kop <> '' then
  begin
    memoKop.Lines.Clear;
    memoKop.Lines.Add(Kop);
  end;
  FSleepSprite.Free;
  FSleepSprite := nil;
  spriteKop.Z := -5101;
  spriteKop.Visible := True;
  spriteUitleg.Visible := True;
  spriteUitleg.Z := -5101;
  spriteStart.Z := -5101;
  spriteJa.Z := -5101;
  spriteNee.Z := -5101;
  spriteStart.Visible := (Knoppen and 1) > 0;
  spriteJa.Visible := (Knoppen and 4) > 0;
  spriteNee.Visible := (Knoppen and 8) > 0;
  with spriteUitlegBackground do
  begin
    Z := -5100;
    Visible := True;
    MoveTo(memoUitleg.Left - 24, memoUitleg.Top - 54);
  end;
  Memo := spriteUitleg.LeesGedrag('CONTROL_BEHAV') as TBehavMemo;
  if Memo <> nil then
    Memo.ScrollBar.Position := 0;
end;

{ @0047C11C }
procedure TfrmMain.VerbergDialoog;
begin
  FDialoog := False;
  spriteUitleg.Visible := False;
  spriteStart.Visible := False;
  spriteCancel.Visible := False;
  spriteJa.Visible := False;
  spriteNee.Visible := False;
  spriteKop.Visible := False;
  spriteUitlegBackground.Visible := False;
end;

{ @0047C184
  Toont het jaarrapport. Zonder Detail worden de jaarlijkse inkomsten en kosten
  geboekt (aan het einde van een ronde). }
procedure TfrmMain.Rapport(Uitgebreid: Boolean);
var
  Totaal, Opbrengst, Kosten: Integer;
  Rapportvenster: TfrmReport;
begin
  Totaal := 0;
  Rapportvenster := TfrmReport.Create(Self);
  FWereld.Rapport(Rapportvenster.Tabbladlijsten, Totaal, Opbrengst, Kosten, Uitgebreid);
  if not Uitgebreid then
    FStatus.Geld := FStatus.Geld - Kosten + Opbrengst;
  Rapportvenster.Execute(FWereld.OpenWijken + 1);
  Rapportvenster.Free;
  FStatus.Score := Totaal;
  ProfStart := GetTickCount;
  ProfBeeld := 0;
  ProfAutos := 0;
  ProfSprites := 0;
  ProfOverig := 0;
end;

{ @0047C368
  Gebeurtenissen: 'StartGame', 'Begin', 'Speelniveau <n>', 'NextLevel', 'EndGame...' }
procedure TfrmMain.Dialoog(Gebeurtenis: string);

  { @0047C240 }
  function ScoreTekst: string;
  var
    Punten: Integer;
    S: string;
  begin
    Punten := FStatus.Score;
    S := '';
    while Punten > 1000 do
    begin
      S := '.' + NulVul(IntTekst(Punten mod 1000), 3) + S;
      Punten := Punten div 1000;
    end;
    S := IntTekst(Punten) + S;
    Result := '\nDe door jou behaalde score is ' + S + '\n';
  end;

var
  Uitleg, Kop, Deel: string;
begin
  if Gebeurtenis = 'NextLevel' then
  begin
    if FNiveau < 11 then
      Gebeurtenis := 'Level ' + IntToStr(FNiveau + 1)
    else
      Gebeurtenis := 'Level ' + IntToStr(FNiveau);
  end;
  FGebeurtenis := Gebeurtenis;
  if (FNiveau = 11) and (LinksStr(Gebeurtenis, 7) <> 'EndGame') then
  begin
    memoUitleg.Lines.Clear;
    Uitleg := 'Het spel is afgelopen, bedankt voor het spelen.\nJe kunt nog doorspelen ' +
      'om je stad zo mooi mogelijk\nte maken';
    ToonDialoog(1, 'Einde Spel!', Uitleg);
  end
  else if Gebeurtenis = 'StartGame' then
  begin
    FWereld.Clear;
    FWeergave.VerwerkWijzigingen;
    VerversStatus;
    sbStage.Picture.TekenOppervlak(FAchtergrond, 0, 0);
    FStatus.Geld := FInstellingen.Startgeld;
    FStatus.Score := 0;
    FStatus.Taak.Clear;
    ToonDialoog(1, FInstellingen.IntroKop, FInstellingen.IntroTekst);
  end
  else if Gebeurtenis = 'Begin' then
    { LET OP: NiveauTekst (+0x14) wordt zowel als kop als tekst doorgegeven }
    ToonDialoog(1, FInstellingen.NiveauTekst, FInstellingen.NiveauTekst)
  else if LinksStr(Gebeurtenis, 5) = 'Level' then
  begin
    Kop := Gebeurtenis;
    Deel := SplitsEerste(Gebeurtenis, ' ');
    Uitleg := FInstellingen.Niveaus[StrToInt(Gebeurtenis)].Uitleg;
    if Gebeurtenis <> '1' then
      Uitleg := Uitleg + ScoreTekst;
    ToonDialoog(1, Kop, Uitleg);
  end
  else if LinksStr(Gebeurtenis, 7) = 'EndGame' then
    ToonDialoog(12, 'Einde Spel?', 'Wil je het spel nu verlaten?');
end;

{ @0047C77C }
procedure TfrmMain.butStartClick(Sender: TObject);
var
  Deel: string;
begin
  VerbergDialoog;
  if FGebeurtenis = 'StartGame' then
    Dialoog('Level 1')
  else if LinksStr(FGebeurtenis, 5) = 'Level' then
  begin
    Deel := SplitsEerste(FGebeurtenis, ' ');
    if FGebeurtenis <> GestartNiveau then
    begin
      GestartNiveau := FGebeurtenis;
      StartNiveau(StrToInt(FGebeurtenis));
    end;
  end
  else
    Dialoog('StartGame');
end;

{ @0047C89C }
procedure TfrmMain.butCancelClick(Sender: TObject);
begin
  VerbergDialoog;
  if FGebeurtenis = 'StartGame' then
    Afsluiten
  else if FGebeurtenis = 'Level 1' then
    Dialoog('StartGame')
  else if LinksStr(FGebeurtenis, 5) = 'Level' then
    Dialoog('EndGame(UserIntervention)')
  else
    Dialoog('StartGame');
end;

{ @0047C9A8
  Meter position 0..9 of criterion C. }
function TfrmMain.CritNr(C: Byte): Integer;
begin
  if (C = 4) or (C = 5) then
    Result := IMinimum(9, IMaximum(0, Round(((FWereld.Score(C) + 100) / 33.33) *
      ((FWereld.Score(C) + 100) / 33.33))))
  else
    Result := IMinimum(9, IMaximum(0, Round(((FWereld.Score(C) + 90) / 33.33) *
      ((FWereld.Score(C) + 90) / 33.33))));
  { LET OP: het origineel eindigt met een dode 'test eax,eax; je @@1; sub eax,0; @@1:'
    op het resultaat (een leeg case-statement?) }
end;

{ @0047CBA0 }
procedure TfrmMain.VerversStatus;

  { @0047CA90 }
  procedure VerversCrit(C: Byte);
  var
    Sprite: TSprite;
  begin
    Sprite := FCriteriaSprites[C];
    if FWereld.Score(C) <> 666 then
    begin
      Sprite.FrameIndex := Sprite.FrameList.IndexOf('Cr_' + Criteria[C] + '_' +
        LongNaarStr(CritNr(C)));
      Sprite.Visible := True;
    end
    else
      Sprite.Visible := False;
  end;

var
  Melding: string;
  C: Byte;
  R: Double;
begin
  if FStatus.Speelniveau <> 0 then
  begin
    if FDialoog then
      memoMessages.Lines.Clear
    else
    begin
      spriteReady.Left := 829;
      spriteReady.Top := 713;
      if timerRecalc.Tag <= 0 then
        spriteReady.Visible := FWereld.Bereikbaar(Melding)
      else
        spriteReady.Visible := False;
      if Melding <> '' then
      begin
        memoMessages.Lines.Clear;
        memoMessages.Lines.Add(Melding);
      end;
      for C := 0 to 5 do
        VerversCrit(C);
      R := FMin(1, FMax(0, FStatus.Geld / FInstellingen.Niveaus[FStatus.Speelniveau].Startgeld));
      if R < 0.25 then
        spriteGeld.FrameIndex := 3
      else if R < 0.5 then
        spriteGeld.FrameIndex := 2
      else if R < 0.75 then
        spriteGeld.FrameIndex := 1
      else
        spriteGeld.FrameIndex := 0;
      if (R < 0) and (FStatus.Speelniveau > 1) then   { LET OP: R is nooit < 0 }
        Dialoog('EndGame');
    end;
  end;
end;

{ @0047CDC0 }
procedure TfrmMain.StartNiveau(Niveau: Integer);
var
  SnelwegY, SpoorY: Integer;
  OudGeld: Integer;
  X: Integer;
begin
  FNiveau := Niveau;
  FStatus.Speelniveau := Niveau;
  if FNiveau > 1 then
  begin
    LeesSprites(FNiveau);
    MaakKnoppen(FNiveau);
  end;
  FStatus.Taak.Add(FInstellingen.Niveaus[Niveau].Taak);
  FStatus.Geld := FStatus.Geld + FInstellingen.Niveaus[Niveau].Startgeld;
  OudGeld := FStatus.Geld;
  FStatus.Geld := 1000000;
  FWereld.OpenWijk(FInstellingen.Niveaus[Niveau].OpenWijk);
  SnelwegY := 28;
  SpoorY := 31;
  if Niveau = 1 then
  begin
    for X := 1 to 43 do
    begin
      if InKaart(X, SnelwegY) then
        FWereld.LeesCel(X, SnelwegY).Bouw('Bakst')
      else
        FWereld.LeesCel(X, SnelwegY).Bouw('Snel');
      FWereld.LeesCel(X, SpoorY).Bouw('Rails10');
    end;
    FWereld.LeesCel(0, SnelwegY).Bouw('AndereStad');
    FWereld.LeesCel(44, SnelwegY).Bouw('AndereStad');
  end
  else if Niveau = 2 then
  begin
    for X := 1 to 43 do
      if InKaart(X, SnelwegY) and
        (FWereld.LeesCel(X, SnelwegY).Wijk > FInstellingen.Niveaus[Niveau].OpenWijk) then
        FWereld.LeesCel(X, SnelwegY).Bouw('Weg');
  end
  else if Niveau = 3 then
  begin
    for X := 1 to 43 do
      if InKaart(X, SnelwegY) and
        (FWereld.LeesCel(X, SnelwegY).Wijk > FInstellingen.Niveaus[Niveau].OpenWijk) then
      begin
        FWereld.LeesCel(X, SnelwegY).Bouw('Snel');
        FWereld.LeesCel(X, SnelwegY).Update;
      end;
  end;
  FStatus.Geld := OudGeld;
  ToonPagina('');
  FWeergave.VerwerkWijzigingen;
  (spriteLevel.LeesGedrag('CONTROL_BEHAV') as TBehavText).ZetOnderschrift('memobg',
    'Level ' + LongNaarStr(Niveau));
  spriteLevel.Redraw;
  sbStage.InvalidateRect(Rect(0, 0, 1024, 768));
  sbStage.Flip;
  VerversStatus;
  FGestart := True;
end;

{ @0047D164 }
procedure TfrmMain.StatusWijziging(Sender: TObject);
begin
  FGeldOpschrift.Text := 'Geld: '#128 + IntToStr((Sender as TStatus).Geld) + ',-';
  { dwing een hertekening af }
  FGeldSprite.Left := FGeldSprite.Left xor 1;
end;

{ @0047D20C }
procedure TfrmMain.butReadyClick(Sender: TObject);
begin
  if not FDialoog then
  begin
    Rapport(False);
    Dialoog('NextLevel');
  end;
end;

{ @0047D244
  LET OP: het tekenen van de hint in deze handler is in het origineel onbereikbaar: het
  begint met Exit, en de test van FHintZichtbaar daarna heeft een lege
  then-tak (losse puntkomma). De code is behouden zoals de compiler hem uitvoerde. }
procedure TfrmMain.spriteHintAfterBlit(Sender: TObject; Surface: TSurface; X, Y: Integer;
  Where: TRect; Size: Real);
var
  Breedte, Hoogte, Aantal: Integer;
  Lettertype: TFont;
  S, Regel: string;
  R: TRect;
  OudeKleur: TColor;
begin
  Exit;
  if FHintZichtbaar then;
  Lettertype := TFont.Create;
  Lettertype.Name := 'Arial';
  Lettertype.Color := clBlack;
  Lettertype.Size := 8;
  S := FHintTekst;
  Aantal := 0;
  Breedte := 0;
  while S <> '' do
  begin
    Regel := SplitsEerste(S, '\n');
    Inc(Aantal);
    Breedte := IMaximum(Breedte, Surface.TextWidth(Lettertype, ' ' + Regel));
  end;
  Hoogte := Surface.TextHeight(Lettertype, FHintTekst);
  R := Bounds(X, Y, Breedte + 4, Hoogte * Aantal + 4);
  Surface.FillRect(R, Surface.KleurNaarIndex(clBlack));
  OudeKleur := Surface.Canvas.Brush.Color;
  Surface.Canvas.Brush.Style := bsSolid;
  Surface.Canvas.Brush.Color := $A0FFFF;
  Surface.Canvas.FillRect(Bounds(X + 1, Y + 1, Breedte + 2, Hoogte * Aantal + 2));
  Surface.Canvas.Brush.Color := OudeKleur;
  Surface.Canvas.Brush.Style := bsClear;
  S := FHintTekst;
  Aantal := 0;
  while S <> '' do
  begin
    Regel := SplitsEerste(S, '\n');
    Surface.TextOut(X + 2, Y + 2 + Hoogte * Aantal, Lettertype, ' ' + Regel);
    Inc(Aantal);
  end;
  Surface.Canvas.Brush.Style := bsSolid;
  Lettertype.Free;
end;

{ @0047D794 }
procedure TfrmMain.ToonHintSprite(Tekst: string);

  { @0047D4D4
    Tekent de hinttekst (regels gescheiden door '\n') op de hintsprite. }
  procedure TekenHint(Surface: TSurface);
  var
    Breedte, Hoogte, Aantal: Integer;
    Lettertype: TFont;
    S, Regel: string;
    R: TRect;
    OudeKleur: TColor;
  begin
    S := Tekst;
    Lettertype := TFont.Create;
    Lettertype.Name := 'Arial';
    Lettertype.Color := clBlack;
    Lettertype.Size := 8;
    Aantal := 0;
    Breedte := 0;
    while S <> '' do
    begin
      Regel := SplitsEerste(S, '\n');
      Inc(Aantal);
      Breedte := IMaximum(Breedte, Surface.TextWidth(Lettertype, ' ' + Regel));
    end;
    Hoogte := Surface.TextHeight(Lettertype, Tekst);
    Surface.SetSize(Breedte + 4, Hoogte * Aantal + 4, False);
    Surface.Transparent := False;
    spriteHint.FrameList.Beelden[0].Width := Breedte + 4;
    spriteHint.FrameList.Beelden[0].Height := Hoogte * Aantal + 4;
    R := Bounds(0, 0, Breedte + 4, Hoogte * Aantal + 4);
    Surface.FillRect(R, Surface.KleurNaarIndex(clBlack));
    OudeKleur := Surface.Canvas.Brush.Color;
    Surface.Canvas.Brush.Style := bsSolid;
    Surface.Canvas.Brush.Color := $A0FFFF;
    Surface.Canvas.FillRect(Bounds(1, 1, Breedte + 2, Hoogte * Aantal + 2));
    Surface.Canvas.Brush.Color := OudeKleur;
    Surface.Canvas.Brush.Style := bsClear;
    S := Tekst;
    Aantal := 0;
    while S <> '' do
    begin
      Regel := SplitsEerste(S, '\n');
      Surface.TextOut(2, Hoogte * Aantal + 2, Lettertype, ' ' + Regel);
      Inc(Aantal);
    end;
    Surface.Canvas.Brush.Style := bsSolid;
    Lettertype.Free;
  end;

var
  P: TPoint;
begin
  if FDialoog then
    VerbergHintSprite
  else
  begin
    FHintZichtbaar := True;
    GetCursorPos(P);
    with spriteHint do
    begin
      MoveTo(P.X - 20 - Self.Left, P.Y - 45 - Self.Top);
      Z := -4000;
      Visible := True;
    end;
    if FHintTekst <> Tekst then
      TekenHint(spriteHint.LeesOppervlak);
    FHintTekst := Tekst;
  end;
end;

{ @0047D87C }
procedure TfrmMain.VerbergHintSprite;
var
  P: TPoint;
begin
  spriteHint.Visible := False;
  FHintZichtbaar := False;
  GetCursorPos(P);
  spriteHint.MoveTo(P.X - 20 - Left, P.Y - 45 - Top);
end;

{ @0047D8C0
  Hint terwijl gebouw Name over de kaart wordt gesleept: de prijs, of waarom het niet
  daar gebouwd kan worden. }
procedure TfrmMain.ToonBouwHint(X, Y: Integer; Naam: string);
var
  P, G: TPoint;
  Cell: TCell;
  Melding: string;
begin
  P := Point(X, Y);
  G := SchermNaarRaster(P);
  Cell := FWereld.LeesCel(G.X, G.Y);
  if Cell <> nil then
  begin
    Melding := Cell.KanBouwen(Naam);
    if Melding = '' then
    begin
      if Naam = 'Sloop' then
      begin
        if (Cell.Inhoud = 'AndereStad') or (Cell.Inhoud = 'Onbereikbaar') then
          ToonHintSprite('Slopen niet mogelijk')
        else
          ToonHintSprite('sloop terrein');
      end
      else
        ToonHintSprite(IntToStr(InhoudInfoOpNaam(Naam).Prijs) + ' euro');
    end
    else
      ToonHintSprite(Melding);
  end
  else
    VerbergHintSprite;
end;

{ @0047DA88
  Hint voor de gebouwknop onder de muis: omschrijving en prijs. }
procedure TfrmMain.ToonKnopHint(X, Y: Integer);
var
  Pixie: TPixie;
  Sprite: TSprite;
  S: string;
begin
  Pixie := sbStage.ZoekPixie(X, Y);
  if Pixie is TSprite then
  begin
    Sprite := Pixie as TSprite;
    if Sprite = nil then
      VerbergHintSprite
    else if BegintMet(Sprite.Name, 'KNOP') then
    begin
      S := Inhoud[Sprite.Tag].Beschrijving;
      if Inhoud[Sprite.Tag].Prijs <> 0 then
        S := S + ': ' + IntToStr(Inhoud[Sprite.Tag].Prijs) + ' euro';
      ToonHintSprite(S);
    end;
  end;
end;

{ @0047DBB8
  Hint voor het vakje onder de muis: wat er daar gebouwd is. }
procedure TfrmMain.ToonCelHint(X, Y: Integer);
var
  P, G: TPoint;
  Cell: TCell;
begin
  P := Point(X, Y);
  G := SchermNaarRaster(P);
  Cell := FWereld.LeesCel(G.X, G.Y);
  if Cell <> nil then
    ToonHintSprite(InhoudOmschrijving(Cell.Inhoud))
  else
    VerbergHintSprite;
end;

{ @0047DC4C }
procedure TfrmMain.sbStageKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  case Key of
    VK_RIGHT: butScrollrightClick(Sender);
    VK_LEFT: butScrollleftClick(Sender);
    VK_UP: butScrollupClick(Sender);
    VK_DOWN: butScrolldownClick(Sender);
  end;
end;

{ @0047DC88 }
procedure TfrmMain.sbStageKeyPress(Sender: TObject; var Key: Char);
begin
  if Key = #27 then
  begin
    if FDialoog then
      butCancelClick(butCancel)
    else
      butStopClick(spriteStop);
  end;
  case Key of
    '-', 'A', '_': butZoomuitClick(Sender);
  end;
  case Key of
    '+', '=', 'Z': butZoominClick(Sender);
  end;
  if FSleepSprite <> nil then
    FSleepSprite.Schaalfactor := Zoom;
end;

{ @0047DD1C }
procedure TfrmMain.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  if FOudeGrootte.X > 0 then
    ZetResolutie(FOudeGrootte);
end;

{ @0047DD34
  Schakelt het scherm naar Size (DirectX, anders ChangeDisplaySettings);
  aangeroepen met de bewaarde grootte herstelt het de oorspronkelijke modus. }
procedure TfrmMain.ZetResolutie(Grootte: TPoint);
var
  DC: HDC;
  Kleurdiepte: Integer;
begin
  if (FOudeGrootte.X = Grootte.X) and (FOudeGrootte.Y = Grootte.Y) then
  begin
    if FDirectX then
      DirectXStoppen
    else
      HerstelSchermModus;
  end
  else
  begin
    FDirectX := False;
    DC := GetDC(0);
    Kleurdiepte := GetDeviceCaps(DC, BITSPIXEL);
    ReleaseDC(0, DC);
    try
      DirectXStarten(Grootte.X, Grootte.Y);
      FDirectX := True;
    except
      ZetSchermModus(Grootte.X, Grootte.Y, Kleurdiepte);
      if not IsSchermGewijzigd then
      begin
        Application.MessageBox('Het scherm kan niet op de juiste grootte worden gezet. ' +
          'Het spel wordt niet gestart.', 'Scherminstellingen fout!', 0);
        FOudeGrootte.X := 0;
        FOudeGrootte.Y := 0;
        Afsluiten;
      end;
    end;
  end;
  BringToFront;
end;

{ @0047DEAC }
procedure TfrmMain.butStopClick(Sender: TObject);
begin
  if not FDialoog then
    Dialoog('EndGame(UserIntervention)');
end;

{ @0047DEE4 }
procedure TfrmMain.timerMeeuwTimer(Sender: TObject);
begin
  if not spriteMeeuw.Visible and (Random(4) < 1) then
    with spriteMeeuw do
    begin
      MoveTo(BeeldRect.Right + 200, BeeldRect.Top - 300 + Random(1200));
      Visible := True;
      Z := -5050;
      SpeelReeks('Vlieg', -1);
    end;
end;

{ @0047DF70 }
procedure TfrmMain.spriteMeeuwFinishSequence(Sender: TObject; var Herhalingen: Integer);
var
  Sprite: TSprite;
begin
  Sprite := Sender as TSprite;
  if Sprite.Left + Sprite.Width < 0 then
  begin
    Sprite.StopReeks;
    Sprite.Visible := False;
  end;
end;

{ @0047DFAC
  Toont de knoppen van Page ('' = de huidige pagina) die beschikbaar zijn in
  dit niveau. }
procedure TfrmMain.ToonPagina(Blad: string);
var
  I: Integer;
  Sprite: TSprite;
begin
  if Blad <> '' then
    FPagina := Blad;
  for I := 0 to AantalInhoud - 1 do
  begin
    Sprite := FindComponent('KNOP' + IntToStr(I)) as TSprite;
    if Sprite <> nil then
    begin
      Sprite.Visible := ((Inhoud[I].Page = FPagina) and
        (Inhoud[I].Speelniveau <= FStatus.Speelniveau)) or (Inhoud[I].Name = 'Sloop');
      if Sprite.Visible and Inhoud[I].Uniek and
        (FWereld.LeesAantal(Inhoud[I].Name) <> 0) then
        Sprite.Visible := False;
      if Sprite.Visible and (Inhoud[I].Name = 'Laagbouw') and
        (FWereld.Speelniveau.Laag.Count = 0) then
        Sprite.Visible := False;
      if Sprite.Visible and (Inhoud[I].Name = 'Middenbouw') and
        (FWereld.Speelniveau.Midden.Count = 0) then
        Sprite.Visible := False;
      if Sprite.Visible and (Inhoud[I].Name = 'Hoogbouw') and
        (FWereld.Speelniveau.Hoog.Count = 0) then
        Sprite.Visible := False;
    end;
  end;
end;

{ @0047E25C }
procedure TfrmMain.tabClick(Sender: TObject);
begin
  if Sender is TBehaviour then
    Sender := (Sender as TBehaviour).Sprite;
  ToonPagina(Copy((Sender as TSprite).Name, 7, 255));
end;

{ @0047E2E8 }
procedure TfrmMain.timerKlachtenTimer(Sender: TObject);
var
  S: string;
begin
  memoMessages.Lines.Clear;
  memoMessages.Font.Size := 10;
  FWereld.Advies(S);
  memoMessages.Lines.Add(S);
end;

{ @0047E368 }
function TfrmMain.LeesWeergave: TView;
begin
  Result := FWeergave;
end;

{ @0047E370 }
procedure TfrmMain.Label1Click(Sender: TObject);
begin
  Rapport(True);
end;

{ @0047E378 }
procedure TfrmMain.butJaClick(Sender: TObject);
begin
  VerbergDialoog;
  Afsluiten;
end;

{ @0047E38C }
procedure TfrmMain.butNeeClick(Sender: TObject);
begin
  VerbergDialoog;
end;

{ @0047E394
  Bestand opslaan (tekst, zie butSaveClick):
    Speelniveau <n>
    Geld <n>
    Centrum <x>,<y>
    Zoom <real>
    <TWorld.BewaarNaarRegels regels> }
procedure TfrmMain.butLoadClick(Sender: TObject);
var
  Regel: string;
  Melding: string;
  Geld: Integer;
  CX, CY: Integer;
  Z: Double;
  Regels: TStringList;
  Deel: string;
begin
  if not FDialoog and OpenDialog.Execute then
  begin
    Application.ProcessMessages;
    ToonDialoog(0, 'Je stad wordt geladen', 'Dit kan even duren...');
    sbStage.Flip;
    Regels := TStringList.Create;
    Regels.LoadFromFile(OpenDialog.FileName);
    Regel := Regels[0];
    Deel := SplitsEerste(Regel, ' ');
    if Deel <> 'Level' then
    begin
      Melding := 'Kan ' + OpenDialog.FileName + ' niet openen. Het is geen juist bestand.'#0;
      Application.MessageBox(@Melding[1], 'Oeps!', 0);
    end
    else
    begin
      FNiveau := StrNaarIntDef0(Regel);
      FStatus.Speelniveau := FNiveau;
      (spriteLevel.LeesGedrag('CONTROL_BEHAV') as TBehavText).ZetOnderschrift('memobg',
        'Level ' + LongNaarStr(FNiveau));
      spriteLevel.Redraw;
      Regels.Delete(0);
      LeesSprites(FNiveau);
      MaakKnoppen(FNiveau);
      Regel := Regels[0];
      Deel := SplitsEerste(Regel, ' ');
      Regels.Delete(0);
      Geld := StrNaarIntDef0(Regel);
      Regel := Regels[0];
      Deel := SplitsEerste(Regel, ' ');
      Regels.Delete(0);
      Deel := SplitsEerste(Regel, ',');
      CX := StrNaarIntDef0(Deel);
      CY := StrNaarIntDef0(Regel);
      Regel := Regels[0];
      Deel := SplitsEerste(Regel, ' ');
      Regels.Delete(0);
      Z := StrNaarFloatDef0(Regel);
      if Z = 0 then
        Z := StrNaarFloatDef0(VervangStr(Regel, '.', ','));
      FStatus.Geld := 10000000;
      FWereld.Clear;
      FWereld.OpenWijk(FInstellingen.Niveaus[FNiveau].OpenWijk);
      FWereld.LaadUitRegels(Regels);
      Regels.Destroy;
      FStatus.Geld := Geld;
      FWeergave.ScrollTo(CX, CY, Z);
      FWeergave.VerwerkWijzigingen;
      VerbergDialoog;
      VerversStatus;
    end;
    { LET OP: Lines wordt niet vrijgegeven als het bestand wordt geweigerd }
  end;
end;

{ @0047E7E0 }
procedure TfrmMain.butSaveClick(Sender: TObject);
var
  Regels: TStringList;
begin
  if not FDialoog and SaveDialog.Execute then
  begin
    Regels := TStringList.Create;
    Regels.Add('Level ' + IntTekst(FNiveau));
    Regels.Add('Geld ' + IntTekst(FStatus.Geld));
    Regels.Add('Centrum ' + IntTekst(FWeergave.LeesMidden.X) + ',' + IntTekst(FWeergave.LeesMidden.Y));
    Regels.Add('Zoom ' + RealNaarStr(Zoom));
    Regels.AddStrings(FWereld.BewaarNaarRegels);   { LET OP: de teruggegeven lijst wordt nooit vrijgegeven }
    Regels.SaveToFile(SaveDialog.FileName);
    Regels.Destroy;
  end;
end;

{ @0047E9CC }
procedure TfrmMain.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
begin
  if FStatus <> nil then
  begin
    butStopClick(Sender);
    CanClose := False;
  end;
end;

{ @0047E9E4 }
procedure TfrmMain.Afsluiten;
begin
  FZwart.Close;
  Close;
  Application.Terminate;
end;

{ @0047EA08 }
procedure TfrmMain.timerMainTimer(Sender: TObject);
var
  P: TPoint;
begin
  Trein.Tik;
  GetCursorPos(P);
  Dec(P.Y, Top);
  sbStage.InvalidateRect(BeeldRect);
  { LET OP: de deler (ProfStart - GetTickCount) is negatief }
  lblTimers.Caption := FloatNaarStrT(ProfBeeld / (ProfStart - GetTickCount)) + #13#10 +
    FloatNaarStrT(ProfAutos / (ProfStart - GetTickCount)) + #13#10 +
    FloatNaarStrT(ProfSprites / (ProfStart - GetTickCount)) + #13#10 +
    FloatNaarStrT(ProfOverig / (ProfStart - GetTickCount));
end;

{ @0047EBB8
  OnMouseMove van de criteriummeters: advies voor dat criterium. }
procedure TfrmMain.CritMuisBeweging(Sender: TObject; Shift: TShiftState; X, Y: Integer);
var
  S: string;
begin
  if Sender is TBehaviour then
    Sender := (Sender as TBehaviour).Sprite;
  { LET OP: hernoemt het formulier zelf (Self.Name); waarschijnlijk was een lokale variabele bedoeld }
  Name := (Sender as TSprite).Name;
  S := 'Advies\nover meerdere regels\nEn nog een paar';
  if Name = Criteria[2] then
    S := 'De veiligheid in Zoetermeer is ' +
      LongNaarStr(IMinimum(Round(FWereld.Score(2) + 90), 100)) + '%.\n\n' +
      'Veiligheid kan worden verbeterd door meer politiebureaus en brandweer-\n' +
      'kazernes aan te leggen. Ook andere voorzieningen zoals scholen,\n' +
      'het stadhuis, een gezondheidscentrum en een ziekenhuis vergroten\n' +
      'het gevoel van veiligheid van de burger.\n' +
      'Let op de plaats van de voorzieningen. Ze hebben een optimaal\n' +
      'effect als ze centraal in de wijk geplaatst zijn.'
  else if Name = Criteria[4] then
    S := 'De bereikbaarheid is ' +
      LongNaarStr(IMinimum(Round(FWereld.Score(4) + 100), 100)) + '%.\n\n' +
      'Je kunt de bereikbaarheid verbeteren door klinkerwegen te vervangen\n' +
      'door provinciale wegen en provinciale wegen door snelwegen. Je doet\n' +
      'dit door de oude weg af te breken en een nieuwe te plaatsen.\n' +
      'Je kunt ook de weg van Utrecht naar Den Haag verbreden. Veel mensen\n' +
      'gebruiken deze weg, dus dit helpt enorm.\n' +
      'Het aanleggen van een station op de lijn Utrecht-Den Haag helpt\n' +
      'bovendien. Dat geeft je ook de mogelijkheid een ringlijn voor de\n' +
      'Sprinter aan te leggen. Deze maatregelen ontlasten het wegennet.'
  else if Name = Criteria[1] then
    S := 'De groenvoorzieningen in Zoetermeer zijn ' +
      LongNaarStr(IMinimum(Round(FWereld.Score(1) + 90), 100)) + '%.\n\n' +
      'Het is belangrijk parken en meren te hebben in Zoetermeer.\n' +
      'Zoetermeerders houden van groen!'
  else if Name = Criteria[0] then
    S := 'De voorzieningen op het gebied van ontspanning zijn ' +
      LongNaarStr(IMinimum(Round(FWereld.Score(0) + 90), 100)) + '%. \n\n' +
      'Voorbeelden van dergelijke voorzieningen zijn een restaurant of een hotel. \n' +
      'Winkelen is ook belangrijk. Zorg voor winkelcentra in elke wijk.\n' +
      'Als je het stadshart kunt aanleggen, zul je meteen verbetering zien.\n' +
      'Ook sportieve voorzieningen zorgen voor onstpanning. Denk aan een\n' +
      'voetbalveld, een tennisbaan en een fietscrossbaan. Maar er zijn nog\n' +
      'meer mogelijkheden; kijk onder het tabje "sport en recreatie" wat\n' +
      'je allemaal kunt bouwen.'
  else if Name = Criteria[3] then
    S := 'De voorzieningen op het gebied van cultuur zijn ' +
      LongNaarStr(IMinimum(Round(FWereld.Score(3) + 90), 100)) + '%. \n\n' +
      'Voorbeelden van culturele voorzieningen zijn een cultureel centrum,\n' +
      'een theater of een disco.'
  else if Name = Criteria[5] then
    S := 'De werkgelegenheid is ' +
      LongNaarStr(IMinimum(Round(FWereld.Score(5) + 100), 100)) + '%.\n\n' +
      'Voor de economie (en dus jouw\n' +
      'belastinginkomsten), is voldoende\n' +
      'werkgelegenheid heel belangrijk.\n' +
      'Anders moeten de bewoners ver\n' +
      'reizen naar hun werk. Zorg\n' +
      'ervoor dat Zoetermeer ook een \n' +
      'aantrekkelijke stad is om te werken\n' +
      'door voldoende kantoren te bouwen.';
  ToonHintSprite(S);
end;

{ @0047F8C8 }
procedure TfrmMain.timerRecalcTimer(Sender: TObject);
begin
  if timerRecalc.Tag >= 0 then
  begin
    timerRecalc.Tag := timerRecalc.Tag - 1;
    lblRecalc.Caption := IntTekst(timerRecalc.Tag) + '        ';
    if timerRecalc.Tag = 0 then
    begin
      timerRecalc.Tag := -1;
      FWereld.BerekenReistijd;
      VerversStatus;
    end;
  end;
end;

{ @0047F974 }
procedure TfrmMain.butZoomuitClick(Sender: TObject);
begin
  FWeergave.ScrollTo(FWeergave.LeesMidden.X, FWeergave.LeesMidden.Y, 0.7937005259840998 * Zoom);
end;

{ @0047F9D4 }
procedure TfrmMain.butZoominClick(Sender: TObject);
begin
  FWeergave.ScrollTo(FWeergave.LeesMidden.X, FWeergave.LeesMidden.Y, Zoom / 0.7937005259840998);
end;

{ @0047FA34 }
procedure TfrmMain.butScrollupClick(Sender: TObject);
begin
  FWeergave.ScrollTo(FWeergave.LeesMidden.X, FWeergave.LeesMidden.Y + Round(25 / Zoom), Zoom);
end;

{ @0047FA98 }
procedure TfrmMain.butScrollleftClick(Sender: TObject);
begin
  FWeergave.ScrollTo(FWeergave.LeesMidden.X + Round(25 / Zoom), FWeergave.LeesMidden.Y, Zoom);
end;

{ @0047FAFC }
procedure TfrmMain.butScrolldownClick(Sender: TObject);
begin
  FWeergave.ScrollTo(FWeergave.LeesMidden.X, FWeergave.LeesMidden.Y - Round(25 / Zoom), Zoom);
end;

{ @0047FB60 }
procedure TfrmMain.butScrollrightClick(Sender: TObject);
begin
  FWeergave.ScrollTo(FWeergave.LeesMidden.X - Round(25 / Zoom), FWeergave.LeesMidden.Y, Zoom);
end;

{ @0047FBC4 }
function TfrmMain.ComponentBestaat(Naam: string): Boolean;
begin
  Result := FindComponent(Naam) <> nil;
end;

{ @0047FC18
  Debug: dumpt het midden van de kaart in Memo1 (verborgen). }
procedure TfrmMain.Button1Click(Sender: TObject);
var
  X, Y: Integer;
  S: string;
  Cell: TCell;
begin
  Memo1.Lines.Clear;
  for Y := 10 to 34 do
  begin
    S := '';
    for X := 10 to 34 do
    begin
      Cell := FWereld.LeesCel(X, Y);
      S := S + VulLinks(Copy(Cell.Inhoud, 1, 1), 1);
      S := S + VulLinks(Copy(Cell.Param, 1, 2), 2);
    end;
    Memo1.Lines.Add(S);
  end;
end;

end.
