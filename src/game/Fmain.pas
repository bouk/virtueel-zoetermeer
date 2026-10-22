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
    procedure spriteMeeuwFinishSequence(Sender: TObject; var RepeatCount: Integer);
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
    FTemplates: TSpriteList;             { +0x414  een sjabloonsprite per objecttype (Contents) }
    FKnoppen: TSpriteList;               { +0x418  de knopafbeeldingsprites 'k_<name>' }
    FDragSprite: TSprite;                { +0x41C  gebouw dat naar de kaart wordt gesleept }
    FDragIndex: Integer;                 { +0x420  de index ervan in Contents }
    FWorld: TWorld;                      { +0x424 }
    FView: TView;                        { +0x428 }
    FStatus: TStatus;                    { +0x42C }
    FSettings: TSettings;                { +0x430 }
    FLevel: Integer;                     { +0x434 }
    FReserved438: Integer;               { +0x438  door SetDrag op 0 gezet, nooit gelezen }
    FGeldSprite: TSprite;                { +0x43C  toont het geld (Geld) }
    FDialog: Boolean;                    { +0x440  het dialoogvenster (ShowDialog) is zichtbaar }
    FHintVisible: Boolean;               { +0x441 }
    FHintText: string;                   { +0x444  tekst die op spriteHint wordt getekend }
    FBackground: TSurface;               { +0x448  kopie van het lege spritevak-plaatje }
    FEvent: string;                      { +0x44C  laatste gebeurtenis die aan Dialog is doorgegeven }
    FBouwMsg: string;                    { +0x450  waarom het laatste gebouw niet geplaatst kon worden }
    FOldSize: TPoint;                    { +0x454  schermgrootte voor SetResolution (X = 0: ongewijzigd) }
    FDirectX: Boolean;                   { +0x45C  schermmodus is ingesteld met DirectX }
    FStarted: Boolean;                   { +0x45D  het eerste niveau is gestart }
    FPages: TStringList;                 { +0x460  paginanaam -> aantal knoppen erop }
    FGeldCaption: TCaption;              { +0x464  tekst van FGeldSprite }
    FBlack: TfrmBlack;                   { +0x468 }
    FPage: string;                       { +0x46C  pagina (tabblad) waarvan de knoppen worden getoond }
    FAutos: TAutoSprite;                 { +0x470 }
    FCritSprites: array[0..5] of TSprite;  { +0x474  meters voor Criteria[0..5] }
    procedure WMEraseBkgnd(var Message: TWMEraseBkgnd); message WM_ERASEBKGND;
    procedure ReadSprites(Niveau: Integer);
    procedure CreateKnoppen(Niveau: Integer);
    procedure ShowLoading(Bericht: string);
    procedure SetDrag(Naam: string; Nr: Integer);
    procedure ShowDialog(Knoppen: Integer; Kop, Uitleg: string);
    procedure HideDialog;
    procedure Rapport(Uitgebreid: Boolean);
    procedure Dialog(Gebeurtenis: string);
    function CritIndex(C: Byte): Integer;
    procedure UpdateStatus;
    procedure StartLevel(Niveau: Integer);
    procedure StatusChange(Sender: TObject);
    procedure ShowHintSprite(Tekst: string);
    procedure HideHintSprite;
    procedure ShowBouwHint(X, Y: Integer; Naam: string);
    procedure ShowKnopHint(X, Y: Integer);
    procedure ShowCellHint(X, Y: Integer);
    procedure SetResolution(Grootte: TPoint);
    procedure ShowPage(Blad: string);
    procedure Quit;
    procedure CritMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
    function ComponentExists(Naam: string): Boolean;
  public
    function GetView: TView;
    property View: TView read GetView;
  end;

var
  frmMain: TfrmMain;   { 0048B168 }

implementation

uses
  uString, uTool, uPixie, Uconst, Sprframe, uTrein, uResizeScreen, uQuickDirectX,
  fReport
  {$IFDEF FPC}, ZMRandom{$ENDIF}  { PORT: Delphi's Random };

{$IFNDEF FPC}
{$R *.dfm}  { Alleen Delphi: de draagbare build laadt formulieren uit de ROS.exe van de gebruiker }
{$ENDIF}

{$J+}
const
  StartedLevel: string = '';   { 00489198: niveaunummer (als tekst) dat het laatst is gestart door butStartClick }
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
  PerfStart := 0;
  PerfView := 0;
  PerfAutos := 0;
  PerfSprites := 0;
  PerfOther := 0;
  Randomize;
  Width := 1024;
  Height := 768;
  FStarted := False;
  FBlack := TfrmBlack.Create(nil);
  FBlack.SendToBack;
  FBlack.Top := 0;
  FBlack.Left := 0;
  FBlack.Width := Screen.Width;
  FBlack.Height := Screen.Height;
  FBlack.lblVersion.Left := FBlack.imgLoading.Left + 664 - 328;
  FBlack.lblVersion.Top := FBlack.imgLoading.Top + 408 - 160;
  FBlack.lblVersion.Caption := 'Versie 1.1';
  FBlack.Visible := True;
  ShowLoading('Started');
  FSettings := TSettings.Create('ZoetermeerLevels.ini');
  if Screen.Width < 1024 then
  begin
    case Application.MessageBox('Het scherm is niet ingesteld op de juiste grootte. ' +
      'Om dit spel te kunnen draaien, moeten de eigenschappen van het scherm worden ' +
      'aangepast. Zal ik deze verandering maken?', 'Scherminstellingen verkeerd',
      MB_OKCANCEL or MB_ICONQUESTION) of
      IDCANCEL: Antwoord := 'Quit';
      IDOK: Antwoord := 'Yes';
    end;
    FOldSize.X := 0;
    FOldSize.Y := 0;
    if Antwoord = 'Quit' then
      Quit;
    if Antwoord = 'Yes' then
    begin
      FOldSize.X := Screen.Width;
      FOldSize.Y := Screen.Height;
      NieuweGrootte.X := 1024;
      NieuweGrootte.Y := 768;
      SetResolution(NieuweGrootte);
    end;
  end;
  FTemplates := TSpriteList.Create;
  FKnoppen := TSpriteList.Create;
  spriteHint.Transparent := clNoTransparent;
  FStatus := TStatus.Create;
  FWorld := TWorld.Create(FSettings, FStatus);
  FView := TView.Create(FTemplates, sbStage, FWorld, FSettings, FStatus);
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
  LoadContents;
  ReadSprites(1);
  FBackground := nil;
  CreateKnoppen(1);
  FGeldSprite := TSprite.Create(Self);
  with spriteGeld do
  begin
    MoveTo(916, 179);
    FrameIndex := 0;
    Visible := True;
  end;
  spriteHint.GetSurface.SetSize(150, 100, False);
  Gedrag := TBehavButton.Create('Ja_up', 'Ja_dn', 'Ja_or');
  Gedrag.OnClick := butJaClick;
  spriteJa.AddBehaviour('KNOP', Gedrag);
  spriteJa.GetBehaviour('KNOP').Active := True;
  Gedrag := TBehavButton.Create('Nee_up', 'Nee_dn', 'Nee_or');
  Gedrag.OnClick := butNeeClick;
  spriteNee.AddBehaviour('KNOP', Gedrag);
  spriteNee.GetBehaviour('KNOP').Active := True;
  AddTextBehaviour(spriteWijk, '', 0, 0, lblWijk.Font);
  AddTextBehaviour(spriteLevel, '', 0, 0, lblLevel.Font);
  spriteWijk.MoveBy(lblWijk.Left, lblWijk.Top, -5000);
  spriteWijk.MarginRight := 200;
  spriteWijk.MarginBottom := 20;
  spriteWijk.FrameIndex := 0;
  spriteWijk.Visible := True;
  spriteLevel.MoveBy(lblLevel.Left, lblLevel.Top, -5000);
  spriteLevel.MarginRight := 200;
  spriteLevel.MarginBottom := 20;
  spriteLevel.FrameIndex := 0;
  spriteLevel.Visible := True;
  AttachControls(True, sbStage);
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
    FrameList.AddFrame('null', NewSurfaceSize(100, 20));
    FrameIndex := 0;
    FGeldCaption := AddTextBehaviour(FGeldSprite, '', 0, 0, Lettertype);
    MoveTo(868, 191);
    Visible := True;
  end;
  Lettertype.Free;
  FStatus.OnChange := StatusChange;
  FStatus.Task := TTask.Create(0, 0);
  FBackground := NewSurface;
  FBackground.Assign(sbStage.Picture);
  FHintVisible := False;
  if FSettings.AutosVisible then
    FAutos := CreateAutos(sbStage, spriteAuto, FWorld, FView, FSettings);
  Trein := TTrein.Create(FView.TreinSprite, FWorld);
  timerMeeuw.Enabled := True;
  timerMain.Enabled := True;
  Dialog('StartGame');
end;

{ @0047AC48 }
procedure TfrmMain.ReadSprites(Niveau: Integer);
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
    ShowLoading(Voorvoegsel);
    Voorvoegsel := LowStr(Voorvoegsel);
    for I := 0 to Bestanden.Count - 1 do
    begin
      BestandsNaam := LowStr(Bestanden[I]);
      if StartsWith(BestandsNaam, Voorvoegsel) then
      begin
        Bmp := NewSurface;
        Bmp.LoadFromFile(AddPath(Map, BestandsNaam));
        Deel := SplitFirst(BestandsNaam, '.');
        Sprite.FrameList.AddFrame(Deel, Bmp);
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
  Map := AddPath(AddPath(AppPath, 'images'), '8bits');
  Bestanden := TStringList.Create;
  FindFiles(AddPath(Map, '*.bmp'), $3F {faAnyFile}, Bestanden);
  if Niveau = 1 then
  begin
    LaadFrames(spriteStoep, 'Stoep');
    LaadFrames(FView.TreinSprite, 'Trein');
    for C := 0 to 5 do
      if not ComponentExists(Criteria[C]) then
      begin
        FCritSprites[C] := TSprite.Create(Self);
        FCritSprites[C].SpriteBox := sbStage;
        FCritSprites[C].Name := Criteria[C];
        LaadFrames(FCritSprites[C], 'Cr_' + Criteria[C]);
        FCritSprites[C].MoveTo(C * 100 + 225 - 1, 30);
        FCritSprites[C].Visible := False;
        FCritSprites[C].OnMouseMove := CritMouseMove;
      end;
  end;
  for I := 0 to ContentsCount - 1 do
  begin
    Naam := Contents[I].Name;
    if not ComponentExists(Naam) then
    begin
      if (Copy(Naam, 1, 5) = 'Rails') or (Copy(Naam, 1, 4) = 'Snel') then
        L := 1
      else
        L := Contents[I].Level;
      if not Contents[I].SpritesLoaded and (L <= Niveau) then
      begin
        ShowLoading(Contents[I].Description);
        Sprite := TSprite.Create(Self);
        Sprite.Name := Naam;
        Sprite.SpriteBox := sbStage;
        FTemplates.Add(Sprite);
        if Naam <> 'Onbereikbaar' then
        begin
          if not ComponentExists('k_' + Naam) then
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
          BestandsNaam := LowStr(Bestanden[J]);
          if StartsWith(BestandsNaam, LowStr(Naam)) then
          begin
            Bmp := NewSurface;
            Bmp.LoadFromFile(AddPath(Map, BestandsNaam));
            with Sprite.FrameList do
            begin
              Deel := SplitFirst(BestandsNaam, '.');
              AddFrame(Deel, Bmp);
              Frames[Count - 1].HotSpotX := Contents[I].GrondvlakX * TileW;
              Frames[Count - 1].HotSpotY := Frames[Count - 1].Height - 44;
            end;
            Bmp.Free;
          end
          else if StartsWith(BestandsNaam, 'k-' + LowStr(Naam)) then
          begin
            Bmp := NewSurface;
            Bmp.LoadFromFile(AddPath(Map, BestandsNaam));
            Deel := SplitFirst(BestandsNaam, '.');
            BestandsNaam := DelLeft(Deel, 2);
            if EndsWith(BestandsNaam, '_ov') then
            begin
              Deel := SplitFirst(BestandsNaam, '_');
              BestandsNaam := Deel + '_or';
            end;
            with Knop.FrameList do
            begin
              AddFrame(BestandsNaam, Bmp);
              if EndsWith(BestandsNaam, '_tr') then
              begin
                Frames[Count - 1].HotSpotX := Contents[I].GrondvlakX * TileW;
                Frames[Count - 1].HotSpotY := Frames[Count - 1].Height - 44;
                if Contents[I].GrondvlakY = 5 then
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
        Contents[I].SpritesLoaded := True;
      end;
    end;
  end;
  Bestanden.Free;
end;

{ @0047B470 }
procedure TfrmMain.CreateKnoppen(Niveau: Integer);
var
  I: Integer;
  Plek: Integer;
  Gedrag: TBehavButton;
  Sprite: TSprite;
begin
  for I := 0 to ContentsCount - 3 do
    if (Contents[I].Level <= Niveau) and not Contents[I].KnopGemaakt and
      not ComponentExists('KNOP' + IntToStr(I)) then
    begin
      Plek := StrToIntDef0(FPages.Values[Contents[I].Page]);
      Gedrag := TBehavButton.Create(Contents[I].Name + '_up', Contents[I].Name + '_dn',
        Contents[I].Name + '_or');
      Gedrag.OnClick := butPlaceSomethingClick;
      Sprite := FKnoppen.SpriteByName('k_' + Contents[I].Name);
      if Sprite = nil then
        Fout('Could not find sprite ' + Contents[I].Name);
      Sprite := TSprite.CreateCopy(Sprite);
      Sprite.SpriteBox := sbStage;
      Sprite.Tag := I;
      Sprite.Z := -1000;
      Sprite.Name := 'KNOP' + IntToStr(I);
      Sprite.X := (Plek mod 3) * 64 + 829;
      Sprite.Y := (Plek div 3) * 64 + 228;
      FPages.Values[Contents[I].Page] := IntStr(Plek + 1);
      Sprite.AddBehaviour('KNOP', Gedrag);
      Sprite.GetBehaviour('KNOP').Active := True;
      Contents[I].KnopGemaakt := True;
    end;
  ShowPage(Contents[0].Page);
end;

{ @0047B778 }
procedure TfrmMain.ShowLoading(Bericht: string);
var
  Deel: string;
begin
  if Pos('_', Bericht) > 0 then
    Deel := SplitFirst(Bericht, '_');
  with FBlack.lblLoading do
  begin
    Caption := Bericht;
    Left := FBlack.imgLoading.Left + 12;
    Top := FBlack.imgLoading.Top + 120;
  end;
  Application.ProcessMessages;
end;

{ @0047B84C }
procedure TfrmMain.FormDestroy(Sender: TObject);
begin
  DetachControls(True, sbStage);
  timerMeeuw.Enabled := False;
  if FBackground <> nil then
    FBackground.Free;
  FView.Free;
  FWorld.Free;
  FSettings.Free;
  FStatus.Free;
end;

{ @0047B8A8 }
procedure TfrmMain.SetDrag(Naam: string; Nr: Integer);
var
  Beeldnaam: string;
  Sjabloon: TSprite;
begin
  Beeldnaam := Naam + '_tr';
  Naam := 'k_' + Naam;
  if FDragSprite <> nil then
    FDragSprite.Kill;
  Sjabloon := FKnoppen.SpriteByName(Naam);
  if Sjabloon = nil then
    Fout('SetDrag: Sprite niet gevonden: ' + Naam);
  FDragSprite := TSprite.CreateCopy(Sjabloon);
  if FDragSprite.FrameList.IndexOf(Beeldnaam) = -1 then
    Fout('PaintCell: could not find frame ' + Beeldnaam + ' in sprite ' + FDragSprite.Name);
  FDragSprite.CurrentFrame := Beeldnaam;
  FDragSprite.Scale := Zoom;
  FDragIndex := Nr;
  FReserved438 := 0;
end;

{ @0047BAAC }
procedure TfrmMain.butPlaceSomethingClick(Sender: TObject);
begin
  if not FDialog then
  begin
    if Sender is TBehaviour then
      Sender := (Sender as TBehaviour).Sprite;
    SetDrag(Contents[(Sender as TSprite).Tag].Name, (Sender as TSprite).Tag);
  end;
end;

{ @0047BB08 }
procedure TfrmMain.sbStageMouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
var
  G, P: TPoint;
  Cell: TCell;
  Info: TContentsInfo;
  Melding: string;
begin
  HideHintSprite;
  if FDragSprite <> nil then
  begin
    P := Point(X, Y);
    if PtInRect(Rect(30, 81, 822, 686), P) then
    begin
      G := ScreenToGrid(P);
      Cell := FWorld.GetCell(G.X, G.Y);
      if Cell = nil then
      begin
        if not PtInRect(ViewRect, Point(X, Y)) then
        begin
          FDragSprite.Free;
          FDragSprite := nil;
        end;
      end
      else
      begin
        Info := Contents[FDragIndex];
        Melding := Cell.KanBouwen(Info.Name);
        FBouwMsg := Melding;
        if FBouwMsg = '' then
        begin
          if Info.Singleton or (Info.GrondvlakX > 1) or (Info.GrondvlakY > 1) then
          begin
            FDragSprite.Free;
            FDragSprite := nil;
          end;
          Cell.Bouw(Info.Name);
          timerKlachtenTimer(timerKlachten);
          timerKlachten.Enabled := True;
          FView.ProcessChanges;
          ShowPage('');
        end;
        UpdateStatus;
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
  if FStarted then
  begin
    P := Point(X, Y);
    G := ScreenToGrid(P);
    if FDragSprite <> nil then
    begin
      FDragSprite.MoveTo3D(P.X, P.Y, -3000);
      FDragSprite.Visible := PtInRect(ViewRect, Point(X, Y));
      if FDragSprite.Visible then
        ShowBouwHint(X, Y, Contents[FDragIndex].Name)
      else
        ShowKnopHint(X, Y);
    end
    else if PtInRect(ViewRect, P) then
      ShowCellHint(X, Y)
    else
      ShowKnopHint(X, Y);
    Cell := FWorld.GetCell(G.X, G.Y);
    if Cell = nil then
    begin
      (spriteWijk.GetBehaviour('CONTROL_BEHAV') as TBehavText).SetCaption('memobg', '--');
      spriteWijk.Redraw;
    end
    else
    begin
      Wijk := FWorld.Wijken[Cell.Wijk];
      if Cell.Wijk < FWorld.OpenWijken then
        (spriteWijk.GetBehaviour('CONTROL_BEHAV') as TBehavText).SetCaption('memobg', Wijk.Naam)
      else
        (spriteWijk.GetBehaviour('CONTROL_BEHAV') as TBehavText).SetCaption('memobg', '');
      spriteWijk.Redraw;
    end;
  end;
end;

{ @0047BEDC
  Buttons: 1 = Start, 4 = Ja, 8 = Nee. Regels van Uitleg zijn gescheiden door '\n'. }
procedure TfrmMain.ShowDialog(Knoppen: Integer; Kop, Uitleg: string);
var
  Regel: string;
  Memo: TBehavMemo;
begin
  FDialog := True;
  HideHintSprite;
  memoMessages.Lines.Clear;
  { LET OP: test de eigen Text van het formulier (het opschrift), niet Uitleg; is altijd waar }
  if Text <> '' then
  begin
    memoUitleg.Lines.Clear;
    while Uitleg <> '' do
    begin
      Regel := SplitFirst(Uitleg, '\n');
      memoUitleg.Lines.Add(Regel);
    end;
  end;
  if Kop <> '' then
  begin
    memoKop.Lines.Clear;
    memoKop.Lines.Add(Kop);
  end;
  FDragSprite.Free;
  FDragSprite := nil;
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
  Memo := spriteUitleg.GetBehaviour('CONTROL_BEHAV') as TBehavMemo;
  if Memo <> nil then
    Memo.ScrollBar.Position := 0;
end;

{ @0047C11C }
procedure TfrmMain.HideDialog;
begin
  FDialog := False;
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
  FWorld.Rapport(Rapportvenster.Lists, Totaal, Opbrengst, Kosten, Uitgebreid);
  if not Uitgebreid then
    FStatus.Geld := FStatus.Geld - Kosten + Opbrengst;
  Rapportvenster.Execute(FWorld.OpenWijken + 1);
  Rapportvenster.Free;
  FStatus.Score := Totaal;
  PerfStart := GetTickCount;
  PerfView := 0;
  PerfAutos := 0;
  PerfSprites := 0;
  PerfOther := 0;
end;

{ @0047C368
  Gebeurtenissen: 'StartGame', 'Begin', 'Level <n>', 'NextLevel', 'EndGame...' }
procedure TfrmMain.Dialog(Gebeurtenis: string);

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
      S := '.' + ZeroPad(IntStr(Punten mod 1000), 3) + S;
      Punten := Punten div 1000;
    end;
    S := IntStr(Punten) + S;
    Result := '\nDe door jou behaalde score is ' + S + '\n';
  end;

var
  Uitleg, Kop, Deel: string;
begin
  if Gebeurtenis = 'NextLevel' then
  begin
    if FLevel < 11 then
      Gebeurtenis := 'Level ' + IntToStr(FLevel + 1)
    else
      Gebeurtenis := 'Level ' + IntToStr(FLevel);
  end;
  FEvent := Gebeurtenis;
  if (FLevel = 11) and (LeftStr(Gebeurtenis, 7) <> 'EndGame') then
  begin
    memoUitleg.Lines.Clear;
    Uitleg := 'Het spel is afgelopen, bedankt voor het spelen.\nJe kunt nog doorspelen ' +
      'om je stad zo mooi mogelijk\nte maken';
    ShowDialog(1, 'Einde Spel!', Uitleg);
  end
  else if Gebeurtenis = 'StartGame' then
  begin
    FWorld.Clear;
    FView.ProcessChanges;
    UpdateStatus;
    sbStage.Picture.DrawSurface(FBackground, 0, 0);
    FStatus.Geld := FSettings.Startgeld;
    FStatus.Score := 0;
    FStatus.Task.Clear;
    ShowDialog(1, FSettings.IntroKop, FSettings.IntroTekst);
  end
  else if Gebeurtenis = 'Begin' then
    { LET OP: NiveauTekst (+0x14) wordt zowel als kop als tekst doorgegeven }
    ShowDialog(1, FSettings.NiveauTekst, FSettings.NiveauTekst)
  else if LeftStr(Gebeurtenis, 5) = 'Level' then
  begin
    Kop := Gebeurtenis;
    Deel := SplitFirst(Gebeurtenis, ' ');
    Uitleg := FSettings.Levels[StrToInt(Gebeurtenis)].Uitleg;
    if Gebeurtenis <> '1' then
      Uitleg := Uitleg + ScoreTekst;
    ShowDialog(1, Kop, Uitleg);
  end
  else if LeftStr(Gebeurtenis, 7) = 'EndGame' then
    ShowDialog(12, 'Einde Spel?', 'Wil je het spel nu verlaten?');
end;

{ @0047C77C }
procedure TfrmMain.butStartClick(Sender: TObject);
var
  Deel: string;
begin
  HideDialog;
  if FEvent = 'StartGame' then
    Dialog('Level 1')
  else if LeftStr(FEvent, 5) = 'Level' then
  begin
    Deel := SplitFirst(FEvent, ' ');
    if FEvent <> StartedLevel then
    begin
      StartedLevel := FEvent;
      StartLevel(StrToInt(FEvent));
    end;
  end
  else
    Dialog('StartGame');
end;

{ @0047C89C }
procedure TfrmMain.butCancelClick(Sender: TObject);
begin
  HideDialog;
  if FEvent = 'StartGame' then
    Quit
  else if FEvent = 'Level 1' then
    Dialog('StartGame')
  else if LeftStr(FEvent, 5) = 'Level' then
    Dialog('EndGame(UserIntervention)')
  else
    Dialog('StartGame');
end;

{ @0047C9A8
  Meter position 0..9 of criterion C. }
function TfrmMain.CritIndex(C: Byte): Integer;
begin
  if (C = 4) or (C = 5) then
    Result := IMin(9, IMax(0, Round(((FWorld.Score(C) + 100) / 33.33) *
      ((FWorld.Score(C) + 100) / 33.33))))
  else
    Result := IMin(9, IMax(0, Round(((FWorld.Score(C) + 90) / 33.33) *
      ((FWorld.Score(C) + 90) / 33.33))));
  { LET OP: het origineel eindigt met een dode 'test eax,eax; je @@1; sub eax,0; @@1:'
    op het resultaat (een leeg case-statement?) }
end;

{ @0047CBA0 }
procedure TfrmMain.UpdateStatus;

  { @0047CA90 }
  procedure VerversCrit(C: Byte);
  var
    Sprite: TSprite;
  begin
    Sprite := FCritSprites[C];
    if FWorld.Score(C) <> 666 then
    begin
      Sprite.FrameIndex := Sprite.FrameList.IndexOf('Cr_' + Criteria[C] + '_' +
        LongToStr(CritIndex(C)));
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
  if FStatus.Level <> 0 then
  begin
    if FDialog then
      memoMessages.Lines.Clear
    else
    begin
      spriteReady.Left := 829;
      spriteReady.Top := 713;
      if timerRecalc.Tag <= 0 then
        spriteReady.Visible := FWorld.Bereikbaar(Melding)
      else
        spriteReady.Visible := False;
      if Melding <> '' then
      begin
        memoMessages.Lines.Clear;
        memoMessages.Lines.Add(Melding);
      end;
      for C := 0 to 5 do
        VerversCrit(C);
      R := FMin(1, FMax(0, FStatus.Geld / FSettings.Levels[FStatus.Level].StartGeld));
      if R < 0.25 then
        spriteGeld.FrameIndex := 3
      else if R < 0.5 then
        spriteGeld.FrameIndex := 2
      else if R < 0.75 then
        spriteGeld.FrameIndex := 1
      else
        spriteGeld.FrameIndex := 0;
      if (R < 0) and (FStatus.Level > 1) then   { LET OP: R is nooit < 0 }
        Dialog('EndGame');
    end;
  end;
end;

{ @0047CDC0 }
procedure TfrmMain.StartLevel(Niveau: Integer);
var
  SnelwegY, SpoorY: Integer;
  OudGeld: Integer;
  X: Integer;
begin
  FLevel := Niveau;
  FStatus.Level := Niveau;
  if FLevel > 1 then
  begin
    ReadSprites(FLevel);
    CreateKnoppen(FLevel);
  end;
  FStatus.Task.Add(FSettings.Levels[Niveau].Task);
  FStatus.Geld := FStatus.Geld + FSettings.Levels[Niveau].StartGeld;
  OudGeld := FStatus.Geld;
  FStatus.Geld := 1000000;
  FWorld.OpenWijk(FSettings.Levels[Niveau].OpenWijk);
  SnelwegY := 28;
  SpoorY := 31;
  if Niveau = 1 then
  begin
    for X := 1 to 43 do
    begin
      if InMap(X, SnelwegY) then
        FWorld.GetCell(X, SnelwegY).Bouw('Bakst')
      else
        FWorld.GetCell(X, SnelwegY).Bouw('Snel');
      FWorld.GetCell(X, SpoorY).Bouw('Rails10');
    end;
    FWorld.GetCell(0, SnelwegY).Bouw('AndereStad');
    FWorld.GetCell(44, SnelwegY).Bouw('AndereStad');
  end
  else if Niveau = 2 then
  begin
    for X := 1 to 43 do
      if InMap(X, SnelwegY) and
        (FWorld.GetCell(X, SnelwegY).Wijk > FSettings.Levels[Niveau].OpenWijk) then
        FWorld.GetCell(X, SnelwegY).Bouw('Weg');
  end
  else if Niveau = 3 then
  begin
    for X := 1 to 43 do
      if InMap(X, SnelwegY) and
        (FWorld.GetCell(X, SnelwegY).Wijk > FSettings.Levels[Niveau].OpenWijk) then
      begin
        FWorld.GetCell(X, SnelwegY).Bouw('Snel');
        FWorld.GetCell(X, SnelwegY).Update;
      end;
  end;
  FStatus.Geld := OudGeld;
  ShowPage('');
  FView.ProcessChanges;
  (spriteLevel.GetBehaviour('CONTROL_BEHAV') as TBehavText).SetCaption('memobg',
    'Level ' + LongToStr(Niveau));
  spriteLevel.Redraw;
  sbStage.InvalidateRect(Rect(0, 0, 1024, 768));
  sbStage.Flip;
  UpdateStatus;
  FStarted := True;
end;

{ @0047D164 }
procedure TfrmMain.StatusChange(Sender: TObject);
begin
  FGeldCaption.Text := 'Geld: '#128 + IntToStr((Sender as TStatus).Geld) + ',-';
  { dwing een hertekening af }
  FGeldSprite.Left := FGeldSprite.Left xor 1;
end;

{ @0047D20C }
procedure TfrmMain.butReadyClick(Sender: TObject);
begin
  if not FDialog then
  begin
    Rapport(False);
    Dialog('NextLevel');
  end;
end;

{ @0047D244
  LET OP: het tekenen van de hint in deze handler is in het origineel onbereikbaar: het
  begint met Exit, en de test van FHintVisible daarna heeft een lege
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
  if FHintVisible then;
  Lettertype := TFont.Create;
  Lettertype.Name := 'Arial';
  Lettertype.Color := clBlack;
  Lettertype.Size := 8;
  S := FHintText;
  Aantal := 0;
  Breedte := 0;
  while S <> '' do
  begin
    Regel := SplitFirst(S, '\n');
    Inc(Aantal);
    Breedte := IMax(Breedte, Surface.TextWidth(Lettertype, ' ' + Regel));
  end;
  Hoogte := Surface.TextHeight(Lettertype, FHintText);
  R := Bounds(X, Y, Breedte + 4, Hoogte * Aantal + 4);
  Surface.FillRect(R, Surface.ColorToIndex(clBlack));
  OudeKleur := Surface.Canvas.Brush.Color;
  Surface.Canvas.Brush.Style := bsSolid;
  Surface.Canvas.Brush.Color := $A0FFFF;
  Surface.Canvas.FillRect(Bounds(X + 1, Y + 1, Breedte + 2, Hoogte * Aantal + 2));
  Surface.Canvas.Brush.Color := OudeKleur;
  Surface.Canvas.Brush.Style := bsClear;
  S := FHintText;
  Aantal := 0;
  while S <> '' do
  begin
    Regel := SplitFirst(S, '\n');
    Surface.TextOut(X + 2, Y + 2 + Hoogte * Aantal, Lettertype, ' ' + Regel);
    Inc(Aantal);
  end;
  Surface.Canvas.Brush.Style := bsSolid;
  Lettertype.Free;
end;

{ @0047D794 }
procedure TfrmMain.ShowHintSprite(Tekst: string);

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
      Regel := SplitFirst(S, '\n');
      Inc(Aantal);
      Breedte := IMax(Breedte, Surface.TextWidth(Lettertype, ' ' + Regel));
    end;
    Hoogte := Surface.TextHeight(Lettertype, Tekst);
    Surface.SetSize(Breedte + 4, Hoogte * Aantal + 4, False);
    Surface.Transparent := False;
    spriteHint.FrameList.Frames[0].Width := Breedte + 4;
    spriteHint.FrameList.Frames[0].Height := Hoogte * Aantal + 4;
    R := Bounds(0, 0, Breedte + 4, Hoogte * Aantal + 4);
    Surface.FillRect(R, Surface.ColorToIndex(clBlack));
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
      Regel := SplitFirst(S, '\n');
      Surface.TextOut(2, Hoogte * Aantal + 2, Lettertype, ' ' + Regel);
      Inc(Aantal);
    end;
    Surface.Canvas.Brush.Style := bsSolid;
    Lettertype.Free;
  end;

var
  P: TPoint;
begin
  if FDialog then
    HideHintSprite
  else
  begin
    FHintVisible := True;
    GetCursorPos(P);
    with spriteHint do
    begin
      MoveTo(P.X - 20 - Self.Left, P.Y - 45 - Self.Top);
      Z := -4000;
      Visible := True;
    end;
    if FHintText <> Tekst then
      TekenHint(spriteHint.GetSurface);
    FHintText := Tekst;
  end;
end;

{ @0047D87C }
procedure TfrmMain.HideHintSprite;
var
  P: TPoint;
begin
  spriteHint.Visible := False;
  FHintVisible := False;
  GetCursorPos(P);
  spriteHint.MoveTo(P.X - 20 - Left, P.Y - 45 - Top);
end;

{ @0047D8C0
  Hint terwijl gebouw Name over de kaart wordt gesleept: de prijs, of waarom het niet
  daar gebouwd kan worden. }
procedure TfrmMain.ShowBouwHint(X, Y: Integer; Naam: string);
var
  P, G: TPoint;
  Cell: TCell;
  Melding: string;
begin
  P := Point(X, Y);
  G := ScreenToGrid(P);
  Cell := FWorld.GetCell(G.X, G.Y);
  if Cell <> nil then
  begin
    Melding := Cell.KanBouwen(Naam);
    if Melding = '' then
    begin
      if Naam = 'Sloop' then
      begin
        if (Cell.Contents = 'AndereStad') or (Cell.Contents = 'Onbereikbaar') then
          ShowHintSprite('Slopen niet mogelijk')
        else
          ShowHintSprite('sloop terrein');
      end
      else
        ShowHintSprite(IntToStr(ContentsInfoByContents(Naam).Prijs) + ' euro');
    end
    else
      ShowHintSprite(Melding);
  end
  else
    HideHintSprite;
end;

{ @0047DA88
  Hint voor de gebouwknop onder de muis: omschrijving en prijs. }
procedure TfrmMain.ShowKnopHint(X, Y: Integer);
var
  Pixie: TPixie;
  Sprite: TSprite;
  S: string;
begin
  Pixie := sbStage.FindPixie(X, Y);
  if Pixie is TSprite then
  begin
    Sprite := Pixie as TSprite;
    if Sprite = nil then
      HideHintSprite
    else if StartsWith(Sprite.Name, 'KNOP') then
    begin
      S := Contents[Sprite.Tag].Description;
      if Contents[Sprite.Tag].Prijs <> 0 then
        S := S + ': ' + IntToStr(Contents[Sprite.Tag].Prijs) + ' euro';
      ShowHintSprite(S);
    end;
  end;
end;

{ @0047DBB8
  Hint voor het vakje onder de muis: wat er daar gebouwd is. }
procedure TfrmMain.ShowCellHint(X, Y: Integer);
var
  P, G: TPoint;
  Cell: TCell;
begin
  P := Point(X, Y);
  G := ScreenToGrid(P);
  Cell := FWorld.GetCell(G.X, G.Y);
  if Cell <> nil then
    ShowHintSprite(ContentsDescription(Cell.Contents))
  else
    HideHintSprite;
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
    if FDialog then
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
  if FDragSprite <> nil then
    FDragSprite.Scale := Zoom;
end;

{ @0047DD1C }
procedure TfrmMain.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  if FOldSize.X > 0 then
    SetResolution(FOldSize);
end;

{ @0047DD34
  Schakelt het scherm naar Size (DirectX, anders ChangeDisplaySettings);
  aangeroepen met de bewaarde grootte herstelt het de oorspronkelijke modus. }
procedure TfrmMain.SetResolution(Grootte: TPoint);
var
  DC: HDC;
  Kleurdiepte: Integer;
begin
  if (FOldSize.X = Grootte.X) and (FOldSize.Y = Grootte.Y) then
  begin
    if FDirectX then
      StopDirectX
    else
      RestoreScreenMode;
  end
  else
  begin
    FDirectX := False;
    DC := GetDC(0);
    Kleurdiepte := GetDeviceCaps(DC, BITSPIXEL);
    ReleaseDC(0, DC);
    try
      StartDirectX(Grootte.X, Grootte.Y);
      FDirectX := True;
    except
      SetScreenMode(Grootte.X, Grootte.Y, Kleurdiepte);
      if not IsScreenChanged then
      begin
        Application.MessageBox('Het scherm kan niet op de juiste grootte worden gezet. ' +
          'Het spel wordt niet gestart.', 'Scherminstellingen fout!', 0);
        FOldSize.X := 0;
        FOldSize.Y := 0;
        Quit;
      end;
    end;
  end;
  BringToFront;
end;

{ @0047DEAC }
procedure TfrmMain.butStopClick(Sender: TObject);
begin
  if not FDialog then
    Dialog('EndGame(UserIntervention)');
end;

{ @0047DEE4 }
procedure TfrmMain.timerMeeuwTimer(Sender: TObject);
begin
  if not spriteMeeuw.Visible and (Random(4) < 1) then
    with spriteMeeuw do
    begin
      MoveTo(ViewRect.Right + 200, ViewRect.Top - 300 + Random(1200));
      Visible := True;
      Z := -5050;
      PlaySequence('Vlieg', -1);
    end;
end;

{ @0047DF70 }
procedure TfrmMain.spriteMeeuwFinishSequence(Sender: TObject; var RepeatCount: Integer);
var
  Sprite: TSprite;
begin
  Sprite := Sender as TSprite;
  if Sprite.Left + Sprite.Width < 0 then
  begin
    Sprite.StopSequence;
    Sprite.Visible := False;
  end;
end;

{ @0047DFAC
  Toont de knoppen van Page ('' = de huidige pagina) die beschikbaar zijn in
  dit niveau. }
procedure TfrmMain.ShowPage(Blad: string);
var
  I: Integer;
  Sprite: TSprite;
begin
  if Blad <> '' then
    FPage := Blad;
  for I := 0 to ContentsCount - 1 do
  begin
    Sprite := FindComponent('KNOP' + IntToStr(I)) as TSprite;
    if Sprite <> nil then
    begin
      Sprite.Visible := ((Contents[I].Page = FPage) and
        (Contents[I].Level <= FStatus.Level)) or (Contents[I].Name = 'Sloop');
      if Sprite.Visible and Contents[I].Singleton and
        (FWorld.GetAantal(Contents[I].Name) <> 0) then
        Sprite.Visible := False;
      if Sprite.Visible and (Contents[I].Name = 'Laagbouw') and
        (FWorld.Level.Laag.Count = 0) then
        Sprite.Visible := False;
      if Sprite.Visible and (Contents[I].Name = 'Middenbouw') and
        (FWorld.Level.Midden.Count = 0) then
        Sprite.Visible := False;
      if Sprite.Visible and (Contents[I].Name = 'Hoogbouw') and
        (FWorld.Level.Hoog.Count = 0) then
        Sprite.Visible := False;
    end;
  end;
end;

{ @0047E25C }
procedure TfrmMain.tabClick(Sender: TObject);
begin
  if Sender is TBehaviour then
    Sender := (Sender as TBehaviour).Sprite;
  ShowPage(Copy((Sender as TSprite).Name, 7, 255));
end;

{ @0047E2E8 }
procedure TfrmMain.timerKlachtenTimer(Sender: TObject);
var
  S: string;
begin
  memoMessages.Lines.Clear;
  memoMessages.Font.Size := 10;
  FWorld.Advies(S);
  memoMessages.Lines.Add(S);
end;

{ @0047E368 }
function TfrmMain.GetView: TView;
begin
  Result := FView;
end;

{ @0047E370 }
procedure TfrmMain.Label1Click(Sender: TObject);
begin
  Rapport(True);
end;

{ @0047E378 }
procedure TfrmMain.butJaClick(Sender: TObject);
begin
  HideDialog;
  Quit;
end;

{ @0047E38C }
procedure TfrmMain.butNeeClick(Sender: TObject);
begin
  HideDialog;
end;

{ @0047E394
  Bestand opslaan (tekst, zie butSaveClick):
    Level <n>
    Geld <n>
    Centrum <x>,<y>
    Zoom <real>
    <TWorld.SaveToStrings regels> }
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
  if not FDialog and OpenDialog.Execute then
  begin
    Application.ProcessMessages;
    ShowDialog(0, 'Je stad wordt geladen', 'Dit kan even duren...');
    sbStage.Flip;
    Regels := TStringList.Create;
    Regels.LoadFromFile(OpenDialog.FileName);
    Regel := Regels[0];
    Deel := SplitFirst(Regel, ' ');
    if Deel <> 'Level' then
    begin
      Melding := 'Kan ' + OpenDialog.FileName + ' niet openen. Het is geen juist bestand.'#0;
      Application.MessageBox(@Melding[1], 'Oeps!', 0);
    end
    else
    begin
      FLevel := StrToIntDef0(Regel);
      FStatus.Level := FLevel;
      (spriteLevel.GetBehaviour('CONTROL_BEHAV') as TBehavText).SetCaption('memobg',
        'Level ' + LongToStr(FLevel));
      spriteLevel.Redraw;
      Regels.Delete(0);
      ReadSprites(FLevel);
      CreateKnoppen(FLevel);
      Regel := Regels[0];
      Deel := SplitFirst(Regel, ' ');
      Regels.Delete(0);
      Geld := StrToIntDef0(Regel);
      Regel := Regels[0];
      Deel := SplitFirst(Regel, ' ');
      Regels.Delete(0);
      Deel := SplitFirst(Regel, ',');
      CX := StrToIntDef0(Deel);
      CY := StrToIntDef0(Regel);
      Regel := Regels[0];
      Deel := SplitFirst(Regel, ' ');
      Regels.Delete(0);
      Z := StrToFloatDef0(Regel);
      if Z = 0 then
        Z := StrToFloatDef0(ReplaceStr(Regel, '.', ','));
      FStatus.Geld := 10000000;
      FWorld.Clear;
      FWorld.OpenWijk(FSettings.Levels[FLevel].OpenWijk);
      FWorld.LoadFromStrings(Regels);
      Regels.Destroy;
      FStatus.Geld := Geld;
      FView.ScrollTo(CX, CY, Z);
      FView.ProcessChanges;
      HideDialog;
      UpdateStatus;
    end;
    { LET OP: Lines wordt niet vrijgegeven als het bestand wordt geweigerd }
  end;
end;

{ @0047E7E0 }
procedure TfrmMain.butSaveClick(Sender: TObject);
var
  Regels: TStringList;
begin
  if not FDialog and SaveDialog.Execute then
  begin
    Regels := TStringList.Create;
    Regels.Add('Level ' + IntStr(FLevel));
    Regels.Add('Geld ' + IntStr(FStatus.Geld));
    Regels.Add('Centrum ' + IntStr(FView.GetCenter.X) + ',' + IntStr(FView.GetCenter.Y));
    Regels.Add('Zoom ' + RealToStr(Zoom));
    Regels.AddStrings(FWorld.SaveToStrings);   { LET OP: de teruggegeven lijst wordt nooit vrijgegeven }
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
procedure TfrmMain.Quit;
begin
  FBlack.Close;
  Close;
  Application.Terminate;
end;

{ @0047EA08 }
procedure TfrmMain.timerMainTimer(Sender: TObject);
var
  P: TPoint;
begin
  Trein.Tick;
  GetCursorPos(P);
  Dec(P.Y, Top);
  sbStage.InvalidateRect(ViewRect);
  { LET OP: de deler (PerfStart - GetTickCount) is negatief }
  lblTimers.Caption := FloatToStrT(PerfView / (PerfStart - GetTickCount)) + #13#10 +
    FloatToStrT(PerfAutos / (PerfStart - GetTickCount)) + #13#10 +
    FloatToStrT(PerfSprites / (PerfStart - GetTickCount)) + #13#10 +
    FloatToStrT(PerfOther / (PerfStart - GetTickCount));
end;

{ @0047EBB8
  OnMouseMove van de criteriummeters: advies voor dat criterium. }
procedure TfrmMain.CritMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
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
      LongToStr(IMin(Round(FWorld.Score(2) + 90), 100)) + '%.\n\n' +
      'Veiligheid kan worden verbeterd door meer politiebureaus en brandweer-\n' +
      'kazernes aan te leggen. Ook andere voorzieningen zoals scholen,\n' +
      'het stadhuis, een gezondheidscentrum en een ziekenhuis vergroten\n' +
      'het gevoel van veiligheid van de burger.\n' +
      'Let op de plaats van de voorzieningen. Ze hebben een optimaal\n' +
      'effect als ze centraal in de wijk geplaatst zijn.'
  else if Name = Criteria[4] then
    S := 'De bereikbaarheid is ' +
      LongToStr(IMin(Round(FWorld.Score(4) + 100), 100)) + '%.\n\n' +
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
      LongToStr(IMin(Round(FWorld.Score(1) + 90), 100)) + '%.\n\n' +
      'Het is belangrijk parken en meren te hebben in Zoetermeer.\n' +
      'Zoetermeerders houden van groen!'
  else if Name = Criteria[0] then
    S := 'De voorzieningen op het gebied van ontspanning zijn ' +
      LongToStr(IMin(Round(FWorld.Score(0) + 90), 100)) + '%. \n\n' +
      'Voorbeelden van dergelijke voorzieningen zijn een restaurant of een hotel. \n' +
      'Winkelen is ook belangrijk. Zorg voor winkelcentra in elke wijk.\n' +
      'Als je het stadshart kunt aanleggen, zul je meteen verbetering zien.\n' +
      'Ook sportieve voorzieningen zorgen voor onstpanning. Denk aan een\n' +
      'voetbalveld, een tennisbaan en een fietscrossbaan. Maar er zijn nog\n' +
      'meer mogelijkheden; kijk onder het tabje "sport en recreatie" wat\n' +
      'je allemaal kunt bouwen.'
  else if Name = Criteria[3] then
    S := 'De voorzieningen op het gebied van cultuur zijn ' +
      LongToStr(IMin(Round(FWorld.Score(3) + 90), 100)) + '%. \n\n' +
      'Voorbeelden van culturele voorzieningen zijn een cultureel centrum,\n' +
      'een theater of een disco.'
  else if Name = Criteria[5] then
    S := 'De werkgelegenheid is ' +
      LongToStr(IMin(Round(FWorld.Score(5) + 100), 100)) + '%.\n\n' +
      'Voor de economie (en dus jouw\n' +
      'belastinginkomsten), is voldoende\n' +
      'werkgelegenheid heel belangrijk.\n' +
      'Anders moeten de bewoners ver\n' +
      'reizen naar hun werk. Zorg\n' +
      'ervoor dat Zoetermeer ook een \n' +
      'aantrekkelijke stad is om te werken\n' +
      'door voldoende kantoren te bouwen.';
  ShowHintSprite(S);
end;

{ @0047F8C8 }
procedure TfrmMain.timerRecalcTimer(Sender: TObject);
begin
  if timerRecalc.Tag >= 0 then
  begin
    timerRecalc.Tag := timerRecalc.Tag - 1;
    lblRecalc.Caption := IntStr(timerRecalc.Tag) + '        ';
    if timerRecalc.Tag = 0 then
    begin
      timerRecalc.Tag := -1;
      FWorld.BerekenReistijd;
      UpdateStatus;
    end;
  end;
end;

{ @0047F974 }
procedure TfrmMain.butZoomuitClick(Sender: TObject);
begin
  FView.ScrollTo(FView.GetCenter.X, FView.GetCenter.Y, 0.7937005259840998 * Zoom);
end;

{ @0047F9D4 }
procedure TfrmMain.butZoominClick(Sender: TObject);
begin
  FView.ScrollTo(FView.GetCenter.X, FView.GetCenter.Y, Zoom / 0.7937005259840998);
end;

{ @0047FA34 }
procedure TfrmMain.butScrollupClick(Sender: TObject);
begin
  FView.ScrollTo(FView.GetCenter.X, FView.GetCenter.Y + Round(25 / Zoom), Zoom);
end;

{ @0047FA98 }
procedure TfrmMain.butScrollleftClick(Sender: TObject);
begin
  FView.ScrollTo(FView.GetCenter.X + Round(25 / Zoom), FView.GetCenter.Y, Zoom);
end;

{ @0047FAFC }
procedure TfrmMain.butScrolldownClick(Sender: TObject);
begin
  FView.ScrollTo(FView.GetCenter.X, FView.GetCenter.Y - Round(25 / Zoom), Zoom);
end;

{ @0047FB60 }
procedure TfrmMain.butScrollrightClick(Sender: TObject);
begin
  FView.ScrollTo(FView.GetCenter.X - Round(25 / Zoom), FView.GetCenter.Y, Zoom);
end;

{ @0047FBC4 }
function TfrmMain.ComponentExists(Naam: string): Boolean;
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
      Cell := FWorld.GetCell(X, Y);
      S := S + PadLeft(Copy(Cell.Contents, 1, 1), 1);
      S := S + PadLeft(Copy(Cell.Param, 1, 2), 2);
    end;
    Memo1.Lines.Add(S);
  end;
end;

end.
