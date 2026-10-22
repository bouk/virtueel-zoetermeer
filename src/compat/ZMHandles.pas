unit ZMHandles;

{ Handletabel voor de geëmuleerde Win32-objecten (GDI-objecten, vensters, timers, ...).
  Handles zijn kleine gehele getallen (System.THandle is op elk FPC-doel 32 bits), dus ze
  passen in de Integer/Longint-velden waar Delphi-code ze gewoonlijk bewaart. }

{$MODE DELPHI}{$H+}

interface

const
  ZM_HANDLE_BASE = $10000;

function ZMAllocHandle(Obj: TObject): System.THandle;
procedure ZMFreeHandle(H: System.THandle);
function ZMHandleObj(H: System.THandle): TObject;

implementation

var
  Table: array of TObject;
  FreeList: array of Integer;
  FreeCount: Integer;

function ZMAllocHandle(Obj: TObject): System.THandle;
var
  I: Integer;
begin
  if FreeCount > 0 then
  begin
    Dec(FreeCount);
    I := FreeList[FreeCount];
  end
  else
  begin
    I := Length(Table);
    SetLength(Table, I + 1);
  end;
  Table[I] := Obj;
  Result := ZM_HANDLE_BASE + I;
end;

procedure ZMFreeHandle(H: System.THandle);
var
  I: Integer;
begin
  I := Integer(H) - ZM_HANDLE_BASE;
  if (I < 0) or (I >= Length(Table)) or (Table[I] = nil) then Exit;
  Table[I] := nil;
  if FreeCount >= Length(FreeList) then SetLength(FreeList, FreeCount * 2 + 16);
  FreeList[FreeCount] := I;
  Inc(FreeCount);
end;

function ZMHandleObj(H: System.THandle): TObject;
var
  I: Integer;
begin
  I := Integer(H) - ZM_HANDLE_BASE;
  if (I < 0) or (I >= Length(Table)) then Exit(nil);
  Result := Table[I];
end;

end.
