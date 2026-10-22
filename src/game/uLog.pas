unit uLog;

{ Gedecompileerd uit ROS.exe v1.1, code 004615D4-004616A7.

  LET OP: de unitnaam is voorlopig (overgenomen uit de PACKAGEINFO-unitlijst op positie).
  De enige routine die de smart linking overleefde is een berichtenpomp die gebruikt
  wordt in de wachtlussen van uTiming; niets daarin heeft met logging te maken. }

{$I zm.inc}

interface

function ProcessMessage: Boolean;

implementation

uses
  Windows, Messages, Forms;

{ @004615E8  Verwerkt een wachtend bericht. Geeft True terug wanneer WM_QUIT wacht
  (die blijft in de wachtrij staan). }
function ProcessMessage: Boolean;
var
  Afgehandeld: Boolean;
  Bericht: TMsg;
begin
  Result := False;
  if PeekMessage(Bericht, 0, 0, 0, PM_NOREMOVE) then
  begin
    if Bericht.message = WM_QUIT then
      Result := True
    else
    begin
      { LET OP: Afgehandeld wordt ongeinitialiseerd aan OnMessage doorgegeven en daarna genegeerd }
      if Assigned(Application.OnMessage) then
        Application.OnMessage(Bericht, Afgehandeld);
      if PeekMessage(Bericht, 0, 0, 0, PM_REMOVE) then
      begin
        TranslateMessage(Bericht);
        DispatchMessage(Bericht);
      end;
    end;
  end;
end;

end.
