# Virtueel Zoetermeer als gewoon programma (Linux, macOS), gebouwd met Free Pascal uit de
# gedecompileerde bron, met SDL3 als platformlaag en de spelbestanden van archive.org.
# Op macOS komt er ook een .app-bundel in $out/Applications.
{ lib, stdenv, fpc, sdl3, makeWrapper, spelData }:

stdenv.mkDerivation {
  pname = "virtueel-zoetermeer";
  version = "1.1";

  src = lib.fileset.toSource {
    root = ../.;
    fileset = lib.fileset.unions [ ../src/zm.inc ../src/game ../src/compat ];
  };

  nativeBuildInputs = [ fpc makeWrapper ];

  buildPhase = ''
    runHook preBuild
    mkdir -p build
    fpc -Mdelphi -O2 -Xs -Fisrc -Fusrc/game -Fusrc/compat -Fusrc/compat/sdl3 \
        -FUbuild -FEbuild src/game/Ros.dpr
    runHook postBuild
  '';

  # Op Linux staat het programma in libexec. Op macOS staat het in de .app-bundel (Contents/MacOS):
  # het proces moet zelf in de bundel draaien, anders vindt macOS (NSBundle.mainBundle) de
  # Info.plist niet (naam in de menubalk, NSHighResolutionCapable). Een symbolische koppeling naar
  # $out/bin volstaat daarvoor niet: die wordt opgelost en wijst naar een script buiten de bundel.
  installPhase = ''
    runHook preInstall
    wrapperOpties=(
      --set-default ZM_DATA ${spelData}/game
      --set-default ZM_EXE ${spelData}/ROS.exe
      --set-default ZM_SDL3_LIB ${lib.getLib sdl3}/lib/${if stdenv.hostPlatform.isDarwin then "libSDL3.0.dylib" else "libSDL3.so.0"}
    )
    mkdir -p $out/bin
  '' + lib.optionalString (!stdenv.hostPlatform.isDarwin) ''
    install -Dm755 build/Ros $out/libexec/virtueel-zoetermeer/zoetermeer
    makeWrapper $out/libexec/virtueel-zoetermeer/zoetermeer $out/bin/virtueel-zoetermeer "''${wrapperOpties[@]}"
  '' + lib.optionalString stdenv.hostPlatform.isDarwin ''
    app="$out/Applications/Virtueel Zoetermeer.app/Contents"
    install -Dm755 build/Ros "$app/MacOS/zoetermeer"
    # CFBundleExecutable: een wrapper in de bundel die de variabelen zet en het programma ernaast start.
    makeWrapper "$app/MacOS/zoetermeer" "$app/MacOS/virtueel-zoetermeer" "''${wrapperOpties[@]}"
    makeWrapper "$app/MacOS/zoetermeer" $out/bin/virtueel-zoetermeer "''${wrapperOpties[@]}"
    cat > "$app/Info.plist" <<PLIST
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0"><dict>
      <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
      <key>CFBundleName</key><string>Virtueel Zoetermeer</string>
      <key>CFBundleDisplayName</key><string>Virtueel Zoetermeer</string>
      <key>CFBundleIdentifier</key><string>nl.zoetermeer.virtueel</string>
      <key>CFBundleExecutable</key><string>virtueel-zoetermeer</string>
      <key>CFBundlePackageType</key><string>APPL</string>
      <key>CFBundleShortVersionString</key><string>1.1</string>
      <key>CFBundleVersion</key><string>1.1</string>
      <key>LSMinimumSystemVersion</key><string>11.0</string>
      <key>NSHighResolutionCapable</key><true/>
    </dict></plist>
    PLIST
  '' + ''
    runHook postInstall
  '';

  meta = {
    description = "Virtueel Zoetermeer (2003), gedecompileerd en opnieuw gebouwd met Free Pascal";
    mainProgram = "virtueel-zoetermeer";
    platforms = lib.platforms.linux ++ lib.platforms.darwin;
  };
}
