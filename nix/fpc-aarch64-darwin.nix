# Free Pascal 3.2.2-cross-compiler voor aarch64-darwin (macOS op Apple Silicon), gebouwd op Linux
# uit dezelfde broncode als nixpkgs' fpc en daarmee opgestart. Bedoeld voor een compileercontrole
# van de macOS-versie zonder Mac: compileren en assembleren tot objectbestanden (-Cn), niet linken
# (daarvoor zijn Apple's ld en de macOS-SDK nodig).
#
# FPC assembleert voor aarch64-darwin met 'clang -target <triple>'; de ongewrapte clang van LLVM
# kan dat op Linux (geïntegreerde assembler, Mach-O-uitvoer), zonder SDK.
{ stdenv, lib, fpc, llvmPackages }:

stdenv.mkDerivation {
  pname = "fpc-aarch64-darwin";
  inherit (fpc) version src;

  # Dezelfde patches als nixpkgs' fpc: de net gebouwde native compiler linkt tijdens de build
  # hulpprogramma's (fpmake) en moet daarvoor Nix' glibc en dynamische linker kennen.
  inherit (fpc) patches postPatch;

  nativeBuildInputs = [ fpc llvmPackages.clang-unwrapped ];

  makeFlags = [
    "OS_TARGET=darwin"
    "CPU_TARGET=aarch64"
    "BINUTILSPREFIX="
    "PP=fpc"
  ];

  buildPhase = ''
    runHook preBuild
    make -C fpcsrc crossall $makeFlags
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    make -C fpcsrc crossinstall $makeFlags INSTALL_PREFIX=$out
    mkdir -p $out/bin
    units=$out/lib/fpc/${fpc.version}/units/aarch64-darwin
    cat > $out/bin/fpc-macos <<SH
    #!${stdenv.shell}
    # ppcrossa64 voor aarch64-darwin met de RTL- en pakket-unitpaden; clang assembleert.
    # De pakketpaden komen NA de eigen opties: FPC zoekt de paden op volgorde af, en univint en
    # fv bevatten units met dezelfde naam als compat (Forms, Dialogs, Menus, ...).
    export PATH=${llvmPackages.clang-unwrapped}/bin:\$PATH
    exec $out/lib/fpc/${fpc.version}/ppcrossa64 -Tdarwin -XP "\$@" \$(for d in $units/*/; do printf -- '-Fu%s ' "\$d"; done)
    SH
    chmod +x $out/bin/fpc-macos
    runHook postInstall
  '';

  dontStrip = true;
  dontFixup = true;
  meta.description = "Free Pascal-cross-compiler voor aarch64-darwin (alleen compileren en assembleren)";
}
