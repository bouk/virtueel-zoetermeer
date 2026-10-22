unit uLog;

{ Decompiled from ROS.exe v1.1, code 004615D4-004616A7.

  NOTE: the unit name is provisional (taken from the PACKAGEINFO unit list by position).
  The only routine that survived smart linking is a one-message pump used by
  uTiming's wait loops; nothing in it is related to logging. }

{$I zm.inc}

interface

function ProcessMessage: Boolean;

implementation

uses
  Windows, Messages, Forms;

{ @004615E8  Handles one pending message. Returns True when WM_QUIT is waiting
  (it is left in the queue). }
function ProcessMessage: Boolean;
var
  Handled: Boolean;
  Msg: TMsg;
begin
  Result := False;
  if PeekMessage(Msg, 0, 0, 0, PM_NOREMOVE) then
  begin
    if Msg.message = WM_QUIT then
      Result := True
    else
    begin
      { NOTE: Handled is passed to OnMessage uninitialized and ignored afterwards }
      if Assigned(Application.OnMessage) then
        Application.OnMessage(Msg, Handled);
      if PeekMessage(Msg, 0, 0, 0, PM_REMOVE) then
      begin
        TranslateMessage(Msg);
        DispatchMessage(Msg);
      end;
    end;
  end;
end;

end.
