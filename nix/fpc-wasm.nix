# Free Pascal trunk cross compiler for wasm32-wasip1 (FPC 3.2.2 has no WebAssembly target).
# Pinned to the commit of a known-good official snapshot build; bootstrapped with nixpkgs' fpc.
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

  # -CTbfexceptions: branchful exceptions, so Delphi try/except/finally works without the
  # WebAssembly exception-handling proposal.
  makeFlags = [
    "OS_TARGET=wasip1"
    "CPU_TARGET=wasm32"
    "BINUTILSPREFIX="
    "OPT=-O-"
    "CROSSOPT=-CTbfexceptions"
    "PP=fpc"
  ];

  # The build links native helpers (fpmake) with the freshly built trunk compiler, which only
  # knows FHS paths; point it at Nix's glibc and dynamic linker, as nixpkgs' fpc does.
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
    # ppcrosswasm32 with the target, exception model and RTL unit paths preset.
    export PATH=${lld}/bin:\$PATH
    exec $out/lib/fpc/3.3.1/ppcrosswasm32 -Twasip1 -CTbfexceptions -XP \$(for d in $units/*/; do printf -- '-Fu%s ' "\$d"; done) "\$@"
    SH
    chmod +x $out/bin/fpc-wasm
    runHook postInstall
  '';

  dontStrip = true;
  meta.description = "Free Pascal cross compiler targeting wasm32-wasip1";
}
