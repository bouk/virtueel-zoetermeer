# Free Pascal trunk-cross-compiler voor wasm32-wasip1 (FPC 3.2.2 heeft geen WebAssembly-doel).
# Vastgezet op de commit van een bekende officiele snapshot-build; opgestart met nixpkgs' fpc.
{ stdenv, lib, fetchFromGitLab, fpc, lld, glibc }:

stdenv.mkDerivation rec {
  pname = "fpc-wasm32-wasip1";
  version = "3.3.1-unstable-2026-10-22";

  src = fetchFromGitLab {
    owner = "freepascal.org/fpc";
    repo = "source";
    rev = "82197d8f98e073779c633fc7ef5b9592bb93016b";
    hash = "sha256-CZMO3vO6s4FaUSlDvVhYkamV87dgXgKxXBVpWTrgWq8=";
  };

  nativeBuildInputs = [ fpc lld ];

  # -CTbfexceptions: branchful exceptions, zodat Delphi try/except/finally werkt zonder het
  # WebAssembly exception-handling-voorstel.
  makeFlags = [
    "OS_TARGET=wasip1"
    "CPU_TARGET=wasm32"
    "BINUTILSPREFIX="
    "OPT=-O-"
    "CROSSOPT=-CTbfexceptions"
    "PP=fpc"
  ];

  # De build linkt native hulpprogramma's (fpmake) met de net gebouwde trunk-compiler, die alleen
  # FHS-paden kent; wijs hem naar Nix' glibc en dynamische linker, zoals nixpkgs' fpc doet.
  postPatch = ''
    substituteInPlace compiler/systems/t_linux.pas \
      --replace-fail "const defdynlinker='/lib64/ld-linux-x86-64.so.2';" \
                     "const defdynlinker='$(cat $NIX_CC/nix-support/dynamic-linker)';" \
      --replace-fail "LibrarySearchPath.AddLibraryPath(sysrootpath,'=/lib64',true);" \
                     "LibrarySearchPath.AddLibraryPath(sysrootpath,'=/lib64;${glibc}/lib',true);"
  '';

  buildPhase = ''
    runHook preBuild
    make clean all $makeFlags
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    make crossinstall $makeFlags INSTALL_PREFIX=$out
    mkdir -p $out/bin
    units=$out/lib/fpc/3.3.1/units/wasm32-wasip1
    cat > $out/bin/fpc-wasm <<SH
    #!${stdenv.shell}
    # ppcrosswasm32 met het doel, het exceptiemodel en de RTL-unitpaden vooraf ingesteld.
    export PATH=${lld}/bin:\$PATH
    exec $out/lib/fpc/3.3.1/ppcrosswasm32 -Twasip1 -CTbfexceptions -XP \$(for d in $units/*/; do printf -- '-Fu%s ' "\$d"; done) "\$@"
    SH
    chmod +x $out/bin/fpc-wasm
    runHook postInstall
  '';

  dontStrip = true;
  meta.description = "Free Pascal-cross-compiler voor wasm32-wasip1";
}
