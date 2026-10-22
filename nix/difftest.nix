# CI-check in equivalentiemodus (zie docs/DIFFTEST.md): bouw het testprogramma RosTest (het spel
# plus het testharnas), speel elk invoerscript uit tests/scripts zonder venster af en vergelijk
# elke speltoestand die het schrijft met de verwachte toestand in tests/verwacht/<script>/. Die
# verwachte toestanden komen van het originele ROS.exe onder Wine (tools/ververs-verwacht.sh).
#
# Het harnas werkt in echte tijd (de timers van het spel lopen mee), dus de check duurt een paar
# minuten. Wijkt een script af, dan wordt het nog één keer gedraaid: een zwaar belaste
# bouwmachine kan de timing verstoren (zie "Aandachtspunten" in docs/DIFFTEST.md).
{ lib, stdenv, fpc, diffutils, spelData }:

stdenv.mkDerivation {
  pname = "virtueel-zoetermeer-difftest";
  version = "1.1";

  src = lib.fileset.toSource {
    root = ../.;
    fileset = lib.fileset.unions [
      ../src/zm.inc ../src/game ../src/compat ../src/tests ../tests/scripts ../tests/verwacht
    ];
  };

  nativeBuildInputs = [ fpc diffutils ];

  buildPhase = ''
    runHook preBuild
    mkdir -p build
    fpc -Mdelphi -O1 -Fisrc -Fusrc/game -Fusrc/compat -Fusrc/compat/sdl3 -Fusrc/tests \
        -FUbuild -FEbuild -vewn src/tests/RosTest.dpr
    runHook postBuild
  '';

  doCheck = true;
  checkPhase = ''
    runHook preCheck
    # Opslag- en schaduwmappen van compat (ZMData) onder de tijdelijke bouwmap.
    export HOME=$TMPDIR/home
    mkdir -p $HOME

    speel() {  # speel <script> <uitmap>
      rm -rf "$2"
      ZM_HEADLESS=1 ZM_DATA=${spelData}/game ZM_EXE=${spelData}/ROS.exe \
        ZM_TESTSCRIPT="$1" ZM_TESTOUT="$2" timeout 600 build/RosTest > "$2.log" 2>&1
    }
    vergelijk() {  # vergelijk <naam> <uitmap>: 0 als alle verwachte toestanden gelijk zijn
      local ok=0 v
      for v in tests/verwacht/$1/*.state; do
        if ! cmp -s "$v" "$2/$(basename "$v")"; then
          echo "  VERSCHIL $1/$(basename "$v")"
          diff "$v" "$2/$(basename "$v")" | head -20 || true
          ok=1
        fi
      done
      return $ok
    }

    mislukt=()
    aantal=0
    mkdir -p uit
    for script in tests/scripts/*.zms; do
      naam=$(basename "$script" .zms)
      if ! ls tests/verwacht/$naam/*.state >/dev/null 2>&1; then
        echo "FOUT: geen verwachte toestanden voor $naam (draai tools/ververs-verwacht.sh)"
        mislukt+=("$naam")
        continue
      fi
      echo "== $naam"
      speel "$script" "uit/$naam" || echo "  RosTest eindigde met code $?"
      if ! vergelijk "$naam" "uit/$naam"; then
        echo "  opnieuw: $naam"
        speel "$script" "uit/$naam" || echo "  RosTest eindigde met code $?"
        if ! vergelijk "$naam" "uit/$naam"; then
          tail -20 "uit/$naam.log" || true
          mislukt+=("$naam")
          continue
        fi
      fi
      n=$(ls tests/verwacht/$naam/*.state | wc -l)
      aantal=$((aantal + n))
      echo "  $n toestand(en) gelijk aan het origineel"
    done
    if [ ''${#mislukt[@]} -gt 0 ]; then
      echo "Afwijkend van het origineel: ''${mislukt[*]}"
      exit 1
    fi
    echo "Alle $aantal toestanden gelijk aan het origineel."
    runHook postCheck
  '';

  installPhase = ''
    runHook preInstall
    # De toestanden en logboeken van de port (geen schermafdrukken), voor nazoeken.
    mkdir -p $out
    (cd uit && find . \( -name '*.state' -o -name '*.log' \) -exec cp --parents {} $out \;)
    runHook postInstall
  '';
}
