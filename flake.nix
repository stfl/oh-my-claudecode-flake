{
  description = "oh-my-claudecode (oh-my-claude-sisyphus) packaged for NixOS";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = {
    self,
    nixpkgs,
  }: let
    system = "x86_64-linux";

    mkOmcPkg = pkgs:
      pkgs.stdenv.mkDerivation rec {
        pname = "oh-my-claude-sisyphus";
        version = "4.11.2";

        src = pkgs.fetchurl {
          url = "https://registry.npmjs.org/oh-my-claude-sisyphus/-/oh-my-claude-sisyphus-${version}.tgz";
          hash = "sha256-eu5sA2ron8Tdtz/5Ll3COAYfzEAGnPtA1nAdm4E8H8Q=";
        };

        nativeBuildInputs = [pkgs.makeWrapper];

        dontConfigure = true;
        dontBuild = true;

        installPhase = ''
          runHook preInstall

          mkdir -p $out/lib/oh-my-claudecode
          cp -r . $out/lib/oh-my-claudecode/

          mkdir -p $out/bin

          # omc CLI (bridge/cli.cjs is a self-contained bundle)
          makeWrapper ${pkgs.nodejs}/bin/node $out/bin/omc \
            --add-flags "$out/lib/oh-my-claudecode/bridge/cli.cjs"
          ln -s $out/bin/omc $out/bin/oh-my-claudecode
          ln -s $out/bin/omc $out/bin/omc-cli

          # HUD statusline binary
          makeWrapper ${pkgs.nodejs}/bin/node $out/bin/omc-hud \
            --add-flags "$out/lib/oh-my-claudecode/dist/hud/index.js"

          runHook postInstall
        '';

        meta = with pkgs.lib; {
          description = "Multi-agent orchestration layer for Claude Code";
          homepage = "https://github.com/Yeachan-Heo/oh-my-claudecode";
          license = licenses.mit;
          mainProgram = "omc";
        };
      };
  in {
    packages.${system} = {
      default = mkOmcPkg nixpkgs.legacyPackages.${system};
      omc = mkOmcPkg nixpkgs.legacyPackages.${system};
    };

    overlays.default = final: prev: {
      oh-my-claudecode = {
        omc = mkOmcPkg final;
      };
    };
  };
}
