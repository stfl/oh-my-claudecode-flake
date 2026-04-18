{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.programs.oh-my-claudecode;
  jsonFormat = pkgs.formats.json {};

  # Defaults mirror what `/omc-setup` writes to `~/.claude/.omc-config.json`
  # when the user picks the recommended options:
  #   - skills/omc-setup/phases/02-configure.md (defaultExecutionMode, taskTool,
  #     taskToolConfig)
  #   - scripts/setup-progress.sh (setupVersion — marks the config as
  #     configured without needing a non-reproducible setupCompleted timestamp)
  defaultSettings = {
    defaultExecutionMode = "ultrawork";
    taskTool = "builtin";
    taskToolConfig = {
      injectInstructions = true;
      useMcp = false;
    };
    setupVersion = cfg.package.version or "";
  };
in {
  options.programs.oh-my-claudecode = {
    enable = lib.mkEnableOption "oh-my-claudecode (omc) plugin for Claude Code";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.oh-my-claudecode.omc;
      defaultText = lib.literalExpression "pkgs.oh-my-claudecode.omc";
      description = "The oh-my-claudecode package to use.";
    };

    enableStatusLine = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Whether to configure the Claude Code statusLine to use `omc-hud`.
      '';
    };

    enablePlugin = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Whether to register the oh-my-claudecode plugin directory with
        {option}`programs.claude-code.plugins`.
      '';
    };

    enableSkills = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Whether to register the bundled `omc-reference` skill with
        {option}`programs.claude-code.skills`.
      '';
    };

    enableRules = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Whether to register the bundled OMC rules file (`docs/CLAUDE.md`)
        with {option}`programs.claude-code.rules`.
      '';
    };

    settings = lib.mkOption {
      inherit (jsonFormat) type;
      default = {};
      defaultText = lib.literalExpression (
        lib.generators.toPretty {multiline = true;} defaultSettings
      );
      description = ''
        Contents of `~/.claude/.omc-config.json`. The module supplies the
        defaults `/omc-setup` would write (see `defaultText`) via
        `mkDefault` in the module's `config`, so user-supplied attributes
        merge on top at the *top level* — overriding `defaultExecutionMode`
        keeps `taskTool`, `taskToolConfig`, and `setupVersion` intact.

        Nested attrsets (e.g. `taskToolConfig`) are opaque values in
        `pkgs.formats.json`, so overriding them replaces the whole block;
        re-specify the inner keys you want to keep.

        See the upstream reference for the full list of supported keys:
        <https://github.com/Yeachan-Heo/oh-my-claudecode/blob/main/docs/REFERENCE.md>
      '';
      example = lib.literalExpression ''
        {
          team.maxAgents = 5;
          taskToolConfig = { injectInstructions = true; useMcp = true; };
        }
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [cfg.package];

    programs.claude-code = {
      enable = lib.mkDefault true;

      plugins = lib.mkIf cfg.enablePlugin [
        "${cfg.package}/lib/oh-my-claudecode"
      ];

      skills = lib.mkIf cfg.enableSkills {
        omc-reference = "${cfg.package}/lib/oh-my-claudecode/skills/omc-reference";
      };

      rules = lib.mkIf cfg.enableRules {
        omc = "${cfg.package}/lib/oh-my-claudecode/docs/CLAUDE.md";
      };

      settings = lib.mkIf cfg.enableStatusLine {
        statusLine = {
          type = "command";
          command = "omc-hud";
        };
      };
    };

    programs.oh-my-claudecode.settings = lib.mapAttrs (_: lib.mkDefault) defaultSettings;

    home.file.".claude/.omc-config.json".source =
      jsonFormat.generate "omc-config.json" cfg.settings;
  };
}
