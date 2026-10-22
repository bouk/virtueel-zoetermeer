unit ZMHandles;

{ Handletabel voor de geëmuleerde Win32-objecten (GDI-objecten, vensters, timers, ...).
  Handles zijn kleine gehele getallen (System.THandle is op elk FPC-doel 32 bits), dus ze
  passen in de Integer/Longint-velden waar Delphi-code ze gewoonlijk bewaart. }

{$MODE DELPHI}{$H+}

interface

const
  ZM_GREEP_BASIS = $10000;

function ZMReserveerGreep(Voorwerp: TObject): System.THandle;
procedure ZMGeefGreepVrij(Greep: System.THandle);
function ZMGreepVoorwerp(Greep: System.THandle): TObject;

implementation

var
  Table: array of TObject;
  FreeList: array of Integer;
  FreeCount: Integer;

function ZMReserveerGreep(Voorwerp: TObject): System.THandle;
var
  Index: Integer;
begin
  if FreeCount > 0 then
  begin
    Dec(FreeCount);
    Index := FreeList[FreeCount];
  end
  else
  begin
    Index := Length(Table);
    SetLength(Table, Index + 1);
  end;
  Table[Index] := Voorwerp;
  Result := ZM_GREEP_BASIS + Index;
end;

procedure ZMGeefGreepVrij(Greep: System.THandle);
var
  Index: Integer;
begin
  Index := Integer(Greep) - ZM_GREEP_BASIS;
  if (Index < 0) or (Index >= Length(Table)) or (Table[Index] = nil) then Exit;
  Table[Index] := nil;
  if FreeCount >= Length(FreeList) then SetLength(FreeList, FreeCount * 2 + 16);
  FreeList[FreeCount] := Index;
  Inc(FreeCount);
end;

function ZMGreepVoorwerp(Greep: System.THandle): TObject;
var
  Index: Integer;
begin
  Index := Integer(Greep) - ZM_GREEP_BASIS;
  if (Index < 0) or (Index >= Length(Table)) then Exit(nil);
  Result := Table[Index];
end;

end.
