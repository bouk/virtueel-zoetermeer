# Compileercontrole voor macOS op Apple Silicon (aarch64-darwin), uitvoerbaar op Linux: compileer
# src/game/Ros.dpr met de cross-compiler (nix/fpc-aarch64-darwin.nix) tot Mach-O-objectbestanden
# (-Cn: niet linken) en link die daarna met LLVM's ld64.lld tegen de .tbd-stubs van de macOS-SDK
# (dezelfde SDK die nixpkgs op macOS gebruikt; alleen de bron, die ook op Linux te halen is).
#
# Dit bewijst dat de broncode voor aarch64-darwin compileert en dat elk symbool bij het linken
# gevonden wordt (alleen libSystem; SDL3 wordt tijdens het draaien geladen). Draaien kan hier niet.
# Het resultaat ($out/bin/Ros, een arm64-Mach-O met ad-hoc-handtekening van lld) is niet bedoeld
# om te verspreiden: de echte macOS-build is packages.aarch64-darwin.zoetermeer.
{ lib, stdenvNoCC, fpc-aarch64-darwin, llvmPackages, file, apple-sdk }:

let
  # Alleen de SDK-boom (usr/lib/libSystem.tbd, ...); apple-sdk zelf is alleen voor darwin.
  sdk = apple-sdk.src;
in
stdenvNoCC.mkDerivation {
  pname = "virtueel-zoetermeer-macos-compileert";
  version = "1.1";

  src = lib.fileset.toSource {
    root = ../.;
    fileset = lib.fileset.unions [ ../src/zm.inc ../src/game ../src/compat ];
  };

  nativeBuildInputs = [ fpc-aarch64-darwin llvmPackages.lld llvmPackages.llvm file ];

  buildPhase = ''
    runHook preBuild
    mkdir -p build
    # Dezelfde opties als nix/zoetermeer.nix, plus -Cn (stop na het assembleren).
    fpc-macos -Mdelphi -O2 -Xs -Cn -Fisrc -Fusrc/game -Fusrc/compat -Fusrc/compat/sdl3 \
        -FUbuild -FEbuild -vewn src/game/Ros.dpr
    # FPC schrijft de objectlijst voor Apple's ld naar linkfiles*.res; link die met ld64.lld.
    lijst=$(ls build/linkfiles*.res)
    ld64.lld -arch arm64 -platform_version macos 11.0 14.4 -syslibroot ${sdk} -x \
        -order_file build/symbol_order.fpc -o build/Ros -filelist "$lijst" -lSystem
    runHook postBuild
  '';

  doCheck = true;
  checkPhase = ''
    runHook preCheck
    file build/Ros
    file build/Ros | grep -q 'Mach-O 64-bit arm64 executable'
    llvm-objdump --macho --private-headers build/Ros > koppen.txt
    grep -q LC_MAIN koppen.txt
    grep -q LC_CODE_SIGNATURE koppen.txt
    echo "Gebruikte dylibs:"; grep -A2 'cmd LC_LOAD_DYLIB' koppen.txt | grep name
    runHook postCheck
  '';

  installPhase = ''
    runHook preInstall
    install -Dm755 build/Ros $out/bin/Ros
    runHook postInstall
  '';

  dontFixup = true;
}
