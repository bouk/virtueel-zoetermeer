unit ZMAsyncStack;

{ Geheugen voor Asyncify: hierin bewaart de browserhost de opgeschorte WebAssembly-stack
  (zie web/zoetermeer.js en docs/WASM.md). Het is een statische buffer in het
  datasegment, zodat de heap van FPC er nooit overheen groeit.

  Deze unit staat als eerste in de uses van RosWeb.dpr, zodat de buffer bij de host
  bekend is voordat andere units bij hun initialisatie kunnen gaan wachten. }

{$MODE DELPHI}

interface

implementation

const
  StackGrootte = 4 * 1024 * 1024;

var
  AsyncifyStapel: array[0..StackGrootte - 1] of Byte;

procedure zm_zet_async_buffer(Geheugen: Pointer; Grootte: Integer); external 'zm' name 'set_async_buffer';

initialization
  zm_zet_async_buffer(@AsyncifyStapel[0], SizeOf(AsyncifyStapel));
end.
