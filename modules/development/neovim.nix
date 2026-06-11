{
  flake.modules.homeManager.development = { pkgs, lib, ... }:
    let
      # nixpkgs' nvim-treesitter is now the `main` branch rewrite. It reads
      # parsers from `install_dir/parser` and queries from `install_dir/queries`
      # (default ~/.local/share/nvim/site) and, when a parser is missing, tries
      # to compile it at runtime — which needs a C compiler + the tree-sitter
      # CLI we don't ship, so LazyVim errors out. Instead we point it at a
      # Nix-built dir holding the prebuilt grammars and their matching queries,
      # so every parser is seen as already installed and nothing is compiled.
      treesitterParsers = pkgs.symlinkJoin {
        name = "treesitter-parsers";
        paths = (pkgs.vimPlugins.nvim-treesitter.withPlugins (p: with p; [
          bash
          c
          diff
          html
          javascript
          jsdoc
          json
          lua
          luadoc
          luap
          markdown
          markdown_inline
          printf
          python
          query
          regex
          toml
          tsx
          typescript
          vim
          vimdoc
          xml
          yaml
          nix
        ])).dependencies;
      };
      treesitterInstallDir = pkgs.runCommand "nvim-treesitter-install-dir" { } ''
        mkdir -p $out
        ln -s ${treesitterParsers}/parser $out/parser
        ln -s ${pkgs.vimPlugins.nvim-treesitter}/runtime/queries $out/queries
      '';
    in
    {
    programs.neovim = {
      enable = true;
      defaultEditor = true;
      vimAlias = true;
      viAlias = true;

      # 26.05 flipped these defaults to false; adopt the new default
      # explicitly (LazyVim is lua-only, no ruby/python3 provider needed).
      withRuby = false;
      withPython3 = false;

      extraPackages = with pkgs; [
        lua-language-server
        stylua
        ripgrep
        fd
        shellcheck
        shfmt
        nil
        nixpkgs-fmt
      ];

      plugins = with pkgs.vimPlugins; [
        lazy-nvim
      ];

      initLua =
        let
          plugins = with pkgs.vimPlugins; [
            LazyVim
            snacks-nvim

            { name = "mini.ai"; path = mini-nvim; }
            { name = "mini.icons"; path = mini-nvim; }
            { name = "mini.pairs"; path = mini-nvim; }

            flash-nvim
            grug-far-nvim
            gitsigns-nvim
            todo-comments-nvim
            trouble-nvim
            which-key-nvim

            ts-comments-nvim
            lazydev-nvim

            nvim-treesitter
            nvim-treesitter-textobjects
            nvim-ts-autotag

            bufferline-nvim
            lualine-nvim
            noice-nvim
            nui-nvim

            persistence-nvim

            tokyonight-nvim
            { name = "catppuccin"; path = catppuccin-nvim; }

            nvim-lspconfig
            conform-nvim
            nvim-lint

            blink-cmp
            friendly-snippets

            neo-tree-nvim
            plenary-nvim
          ];

          mkEntryFromDrv = drv:
            if lib.isDerivation drv
            then { name = "${lib.getName drv}"; path = drv; }
            else drv;

          lazyPath = pkgs.linkFarm "lazy-plugins"
            (builtins.map mkEntryFromDrv plugins);
        in
        ''
          require("lazy").setup({
            defaults = { lazy = true },
            dev = {
              path = "${lazyPath}",
              patterns = { "" },
              fallback = false,
            },
            spec = {
              -- Catppuccin Mocha instead of LazyVim's default tokyonight
              -- (whose background reads as blue); matches the rest of the desktop.
              { "LazyVim/LazyVim", import = "lazyvim.plugins", opts = { colorscheme = "catppuccin" } },
              { "catppuccin/nvim", name = "catppuccin", opts = { flavour = "mocha" } },
              { import = "lazyvim.plugins.extras.editor.neo-tree" },
              { import = "lazyvim.plugins.extras.coding.blink" },

              { "mason-org/mason.nvim", enabled = false },
              { "mason-org/mason-lspconfig.nvim", enabled = false },
              { "hrsh7th/nvim-cmp", enabled = false },

              { "nvim-treesitter/nvim-treesitter", opts = { install_dir = "${treesitterInstallDir}", ensure_installed = {} } },
            },
            checker = { enabled = false },
            change_detection = { enabled = false },
          })
        '';
    };
  };
}
