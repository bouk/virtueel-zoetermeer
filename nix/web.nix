# De webversie: een statische site (index.html, zoetermeer.js, zoetermeer.wasm en het
# datapakket met de spelbestanden van archive.org). Serveer $out met een willekeurige webserver.
{ lib, stdenvNoCC, fpc-wasm, binaryen, python3, spelData }:

stdenvNoCC.mkDerivation {
  pname = "virtueel-zoetermeer-web";
  version = "1.1";

  src = lib.fileset.toSource {
    root = ../.;
    fileset = lib.fileset.unions [
      ../src/zm.inc ../src/game ../src/compat ../src/web ../web
      ../tools/bouw-web.sh ../tools/maak-datapakket.py
    ];
  };

  nativeBuildInputs = [ fpc-wasm binaryen python3 ];

  buildPhase = ''
    runHook preBuild
    patchShebangs tools
    tools/bouw-web.sh ${spelData}/game ${spelData}/ROS.exe
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out
    cp build/web/{index.html,zoetermeer.js,zoetermeer.wasm,data.json,data.pack} $out/
    runHook postInstall
  '';
}
