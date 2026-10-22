program a;
{$mode delphi}
uses SysUtils;
function host_wait(ms: Integer): Integer; external 'zm' name 'wait';
var i, r: Integer;
begin
  for i := 1 to 3 do
  begin
    r := host_wait(50 * i);
    Writeln('tik ', i, ' kreeg ', r);
  end;
  try
    raise Exception.Create('na async');
  except on E: Exception do Writeln('gevangen ', E.Message); end;
end.
