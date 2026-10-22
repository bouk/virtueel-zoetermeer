{
  description = "Virtueel Zoetermeer (2003): decompilatie van ROS.exe (Delphi 5), opnieuw gebouwd voor macOS, Linux en de browser";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      lib = nixpkgs.lib;
      systemen = [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" "x86_64-darwin" ];
      perSysteem = f: lib.genAttrs systemen (system: f system (import nixpkgs { inherit system; }));
    in
    {
      packages = perSysteem (system: pkgs:
        let
          spelData = pkgs.callPackage ./nix/spel-data.nix { };
          zoetermeer = pkgs.callPackage ./nix/zoetermeer.nix { inherit spelData; };
        in
        {
          inherit zoetermeer;
          spel-data = spelData;
          default = zoetermeer;
        } // lib.optionalAttrs (system == "x86_64-linux") (
          let fpc-wasm = pkgs.callPackage ./nix/fpc-wasm.nix { };
          in {
            # De WebAssembly-compiler (FPC trunk) wordt alleen op x86_64-linux gebouwd.
            inherit fpc-wasm;
            web = pkgs.callPackage ./nix/web.nix { inherit spelData fpc-wasm; };
          }));

      apps = perSysteem (system: pkgs: {
        default = {
          type = "app";
          program = "${self.packages.${system}.zoetermeer}/bin/virtueel-zoetermeer";
        };
      });

      # Ontwikkelomgeving voor het decompileren (Ghidra, Wine, ...): alleen x86_64-linux.
      devShells.x86_64-linux.default =
        let
          pkgs = import nixpkgs { system = "x86_64-linux"; };
          python = pkgs.python3.withPackages (ps: with ps; [
            pefile      # PE-headers, secties en resources lezen
            capstone    # x86-disassembly voor de analysetools
            unicorn     # originele routines emuleren
            lief        # PE-indeling inspecteren
            playwright  # headless-browsertests van de webversie (tools/test-web.py)
            pillow      # bitmapfonts renderen voor de compat-laag (tools/gen-fonts.py)
          ]);
        in
        pkgs.mkShell {
          packages = with pkgs; [
            # Uitpakken van de originele distributie
            unzip
            p7zip      # NSIS-installer
            innoextract

            # Binaire bestanden inspecteren
            binutils   # objdump, strings, nm
            file
            icoutils   # wrestool: PE-resources (DFM-formulieren, PACKAGEINFO, bitmaps)
            xxd
            upx

            # Disassembleren en decompileren
            ghidra
            rizin

            # Het origineel draaien (Wine) voor de differentiële tests
            wineWow64Packages.stable
            xvfb-run     # X-server zonder scherm
            xdotool      # gescripte invoer
            imagemagick  # screenshots en beeldvergelijking

            # De herbouw met Free Pascal en de platformlaag
            fpc
            self.packages.x86_64-linux.fpc-wasm   # wasm32-wasip1-crosscompiler (fpc-wasm)
            wasmtime
            binaryen   # wasm-opt --asyncify voor de browserversie
            sdl3
            liberation_ttf  # vrije, metrisch gelijke vervangers van Arial/Times/Courier
            pkg-config

            # Scripts
            python
            jq
            git
          ];

          shellHook = ''
            export WINEPREFIX="$PWD/.wine"
            export WINEDEBUG=-all
            export PLAYWRIGHT_BROWSERS_PATH=${pkgs.playwright-driver.browsers}
            export PLAYWRIGHT_SKIP_VALIDATE_HOST_REQUIREMENTS=true
          '';
        };
    };
}
