# De spelbestanden van Virtueel Zoetermeer, vrij beschikbaar op archive.org
# (https://archive.org/details/virtueel-zoetermeer). Uitgepakt zoals tools/extract-orig.sh doet:
#   $out/game         installatie (images/, *.Ini, Objecten.csv, wijken.dat)
#   $out/ROS.exe      versie 1.1 uit de Wise-update (update.exe)
{ stdenvNoCC, fetchurl, unzip, p7zip, python3 }:

stdenvNoCC.mkDerivation {
  pname = "virtueel-zoetermeer-data";
  version = "1.1";

  src = fetchurl {
    name = "virtueel-zoetermeer.zip";
    url = "https://archive.org/download/virtueel-zoetermeer/Virtueel%20Zoetermeer.zip";
    hash = "sha256-tRfkr0jDHWwuoWiggcTxOfGwtraqQuK1/uG7JKAmroc=";
  };

  nativeBuildInputs = [ unzip p7zip python3 ];
  dontUnpack = true;

  installPhase = ''
    runHook preInstall
    mkdir -p zip $out/game
    unzip -q $src -d zip
    7z x -y -o$out/game zip/installatie.exe >/dev/null
    rm -rf "$out/game/\$PLUGINSDIR" $out/game/Uninstall.exe $out/game/Stub.exe $out/game/ROS.exe
    python3 ${../tools/wise-extract.py} zip/update.exe $out/ROS.exe
    runHook postInstall
  '';
}
