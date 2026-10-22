{
  description = "Matching decompilation of Virtueel Zoetermeer (ROS.exe, Delphi 5)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };

      python = pkgs.python3.withPackages (ps: with ps; [
        pefile    # PE header / section / resource parsing
        capstone  # x86 disassembly for diff tooling
        unicorn   # emulating original routines for differential tests
        lief      # PE rewriting / layout inspection
      ]);
    in
    {
      devShells.${system}.default = pkgs.mkShell {
        packages = with pkgs; [
          # Unpacking the original distribution
          unzip
          p7zip      # NSIS installer extraction
          innoextract

          # Binary inspection
          binutils   # objdump, strings, nm
          file
          icoutils   # wrestool: PE resources (DFM forms, PACKAGEINFO, bitmaps)
          xxd
          upx

          # Disassembly / decompilation
          ghidra
          rizin

          # Running the Windows toolchain (Delphi 5 dcc32.exe) and the game itself
          wineWow64Packages.stable
          xvfb-run     # headless X for running the original under Wine
          xdotool      # scripted input for differential tests
          imagemagick  # screenshots (import) and image diffs

          # Portable rebuild (Free Pascal) and its platform layer
          fpc
          sdl3
          pkg-config

          # Scripting: splitting, symbol maps, byte-for-byte diffing
          python
          jq
          git
        ];

        shellHook = ''
          export WINEPREFIX="$PWD/.wine"
          export WINEDEBUG=-all
        '';
      };
    };
}
