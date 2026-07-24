{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.programs.oh-my-claudecode;
  jsonFormat = pkgs.formats.json {};

  # Defaults mirror what `/omc-setup` writes to `~/.claude/.omc-config.json`
  # when the user picks the recommended options. See
  # skills/omc-setup/phases/02-configure.md for the source of truth.
  defaultSettings = {
    defaultExecutionMode = "ultrawork";
    taskTool = "builtin";
    taskToolConfig = {
      injectInstructions = true;
      useMcp = false;
    };
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
        keeps `taskTool` and `taskToolConfig` intact.

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

    runtimeConfig = lib.mkOption {
      inherit (jsonFormat) type;
      default = {};
      description = ''
        Contents of `~/.config/claude-omc/config.jsonc`, the file read by
        OMC's runtime configuration loader (`config/loader.js`).

        This is a **separate config surface** from
        {option}`programs.oh-my-claudecode.settings`, which writes
        `~/.claude/.omc-config.json` (the setup/installer/auto-update
        config: `taskTool`, `defaultExecutionMode`, `notifications`, …).
        The two files are read by different code paths; a key placed in the
        wrong file is ignored (and flagged by `omc doctor`).

        Use `runtimeConfig` for runtime/feature configuration. Several keys
        live **only** here and are not valid in `.omc-config.json`:
        `autopilot` (e.g. `autopilot.execution = "team"` to run autopilot's
        execution stage through the tmux CLI team runtime by default),
        `companyContext`, `planOutput`, `teleport`, `startupCodebaseMap`,
        `taskSizeDetection`, and `promptPrerequisites`. Keys such as
        `agents` (per-agent model overrides), `routing`, `features`,
        `mcpServers`, `permissions`, `magicKeywords`, and `team` are also
        honoured here.

        The loader deep-merges this over its built-in defaults at runtime,
        so specify only the keys you want to change. Unlike `settings`, the
        module supplies no defaults — the value is written verbatim, and
        when left empty no file is written (the loader's built-in defaults
        apply). Emitted as strict JSON, which is valid JSONC.

        See the upstream reference for the full schema:
        <https://github.com/Yeachan-Heo/oh-my-claudecode/blob/main/docs/REFERENCE.md>
      '';
      example = lib.literalExpression ''
        {
          autopilot.execution = "team";
          companyContext.onError = "warn";
          routing.defaultTier = "HIGH";
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

    # Runtime loader config (`config/loader.js`) — resolved via
    # `XDG_CONFIG_HOME`, which `xdg.configFile` targets. Only written when the
    # user sets something, so an empty config leaves the loader on its
    # built-in defaults instead of shadowing them with an empty file.
    xdg.configFile."claude-omc/config.jsonc" = lib.mkIf (cfg.runtimeConfig != {}) {
      source = jsonFormat.generate "claude-omc-config.jsonc" cfg.runtimeConfig;
    };
  };
}
