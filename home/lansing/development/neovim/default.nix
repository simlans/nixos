{ pkgs, lib, ... }:
{
  programs.neovim = {
    enable = true;
    defaultEditor = true;
    vimAlias = true;
    viAlias = true;

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

    extraLuaConfig =
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
            { "LazyVim/LazyVim", import = "lazyvim.plugins" },
            { import = "lazyvim.plugins.extras.editor.neo-tree" },
            { import = "lazyvim.plugins.extras.coding.blink" },

            { "mason-org/mason.nvim", enabled = false },
            { "mason-org/mason-lspconfig.nvim", enabled = false },
            { "hrsh7th/nvim-cmp", enabled = false },

            { "nvim-treesitter/nvim-treesitter", opts = { ensure_installed = {} } },
          },
          checker = { enabled = false },
          change_detection = { enabled = false },
        })
      '';
  };

  xdg.configFile."nvim/parser".source =
    let
      parsers = pkgs.symlinkJoin {
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
    in
    "${parsers}/parser";
}
