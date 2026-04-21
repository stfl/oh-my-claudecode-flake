{
  description = "oh-my-claudecode (oh-my-claude-sisyphus) packaged for NixOS";

  inputs.nixpkgs.url = "https://flakehub.com/f/NixOS/nixpkgs/0.1";

  outputs = {
    self,
    nixpkgs,
  }: let
    system = "x86_64-linux";

    mkOmcPkg = pkgs:
      pkgs.stdenv.mkDerivation rec {
        pname = "oh-my-claude-sisyphus";
        version = "4.13.1";

        src = pkgs.fetchurl {
          url = "https://registry.npmjs.org/oh-my-claude-sisyphus/-/oh-my-claude-sisyphus-${version}.tgz";
          hash = "sha256-S4T0TOrbJuJX37FS9j8Q7rH6yw08QlYU2GPU8yCbHlc=";
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
    pkgs = nixpkgs.legacyPackages.${system};

    updateScript = pkgs.writeShellApplication {
      name = "update-oh-my-claudecode";
      runtimeInputs = [pkgs.curl pkgs.jq pkgs.nix];
      text = builtins.readFile ./update.sh;
    };
  in {
    packages.${system} = {
      default = mkOmcPkg pkgs;
      omc = mkOmcPkg pkgs;
      update = updateScript;
    };

    apps.${system}.update = {
      type = "app";
      program = "${updateScript}/bin/update-oh-my-claudecode";
    };

    overlays.default = final: prev: {
      oh-my-claudecode = {
        omc = mkOmcPkg final;
      };
    };

    homeManagerModules = {
      default = ./modules/home-manager.nix;
      oh-my-claudecode = ./modules/home-manager.nix;
    };
  };
}
