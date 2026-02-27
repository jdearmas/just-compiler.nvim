# just-compiler.nvim

Neovim quickfix compiler for [just](https://github.com/casey/just) with Rust/cargo output support.

Parses `just` recipe output (which is prefixed with `|| `) and populates the quickfix list with navigable errors and warnings from `rustc`/`cargo`.

## Installation

### lazy.nvim 

```lua
{
  "jdearmas/just-compiler.nvim",
  config = function()
    require('just-compiler').setup({
      env = {
        RUST_BACKTRACE  = "full",
        LIBAFL_QEMU_DIR = "/Users/a/code/git/qemu-libafl-bridge",
      },
      target        = "target",
      open_quickfix = true,
      jump_to_first = false,
    })
  end,
}

```
### lazy.nvim (from local directory)

```lua
{
  dir = "~/code/git/just-compiler.nvim",
  config = function()
    require('just-compiler').setup({
      env = {
        RUST_BACKTRACE  = "full",
        LIBAFL_QEMU_DIR = "/Users/a/code/git/qemu-libafl-bridge",
      },
      target        = "target",
      open_quickfix = true,
      jump_to_first = false,
    })
  end,
}
```

## Commands

| Command | Description |
|---|---|
| `:JustBuild [target]` | Run `just`; uses `:Make` (async) if [vim-dispatch](https://github.com/tpope/vim-dispatch) is loaded, otherwise `:make!` (sync) |
| `:JustCompiler [target]` | Configure `makeprg` + `errorformat` + `b:dispatch` without building |
| `:make` / `:Make` | Re-run the build (sync / async via vim-dispatch) |
| `:Dispatch` | Re-run asynchronously using `b:dispatch` (set by `:JustBuild`/`:JustCompiler`) |
| `:Copen` | Open quickfix (dispatch-aware) |
| `:cn` / `:cp` | Next / previous error |
| `:cc N` | Jump to error N |
