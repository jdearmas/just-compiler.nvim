local M = {}

-- Default configuration
M.config = {
  -- The just binary to use
  makeprg = "just",
  -- Environment variables prepended to the just command (key=value table)
  env = {},
  -- Default just target/recipe to build (empty = run just with no target)
  target = "",
  -- Open quickfix automatically after build
  open_quickfix = true,
  -- Jump to first error automatically after build
  jump_to_first = false,
}

-- Errorformat for Rust/cargo output.
--
-- Two code paths produce output with different prefixes:
--
--   :Make / :make   → makeprg includes `sed 's/^|| *//'`  → raw cargo output
--   :Dispatch       → b:dispatch has no sed               → just-prefixed output
--
-- just prefixes every recipe line with "|| ":
--   || error[E0061]: message
--   ||    --> src/fuzzer.rs:136:28
--
-- We handle BOTH formats in a single errorformat so that :Make and :Dispatch
-- work interchangeably.
--
-- Multi-line strategy:
--   %E  = error start
--   %W  = warning start
--   %I  = informational note
--   %C  = continuation line; the '   --> file:line:col' variant sets location
--   %-G = ignore line
--
-- Entries close automatically when the next %E/%W/%I starts.
local errorformat = table.concat({
  -- ── Noise ─────────────────────────────────────────────────────────────
  "%-G",
  -- prefixed variants
  "%-G|| error: could not compile%.%#",
  "%-G|| error: aborting due to%.%#",
  "%-G|| Some errors have detailed%.%#",
  "%-G|| For more information about%.%#",
  "%-G||%#= note:%.%#",
  "%-G||%#= help:%.%#",
  "%-G|| Already up to date.",
  "%-G|| Compiling %.%#",
  "%-G|| Finished %.%#",
  "%-G|| Blocking %.%#",
  "%-G|| Downloading %.%#",
  "%-G|| Updating %.%#",
  "%-G|| Locking %.%#",
  "%-G|| cargo%.%#",
  "%-G|| mkdir%.%#",
  -- stripped variants (after sed)
  "%-Gerror: could not compile%.%#",
  "%-Gerror: aborting due to%.%#",
  "%-GSome errors have detailed%.%#",
  "%-GFor more information about%.%#",
  "%-G%#= note:%.%#",
  "%-G%#= help:%.%#",
  "%-GAlready up to date.",
  "%-GCompiling %.%#",
  "%-GFinished %.%#",
  "%-GBlocking %.%#",
  "%-GDownloading %.%#",
  "%-GUpdating %.%#",
  "%-GLocking %.%#",
  "%-Gcargo%.%#",
  "%-Gmkdir%.%#",

  -- ── Error / warning START lines — prefixed (|| ) ──────────────────────
  "%E|| error[E%n]: %m",
  "%E|| error: %m",
  "%W|| warning[W%n]: %m",
  "%W|| warning: %m",
  "%I|| note: %m",

  -- ── Error / warning START lines — stripped (no prefix) ────────────────
  "%Eerror[E%n]: %m",
  "%Eerror: %m",
  "%Wwarning[W%n]: %m",
  "%Wwarning: %m",
  "%Inote: %m",

  -- ── Location continuation — prefixed: "||    --> file:line:col" ───────
  "%C|| %#--> %f:%l:%c",

  -- ── Location continuation — stripped: "   --> file:line:col" ──────────
  "%C %#--> %f:%l:%c",

  -- ── Other continuation lines ──────────────────────────────────────────
  "%C%.%#",

  -- ── Catch-all ─────────────────────────────────────────────────────────
  "%-G%.%#",
}, ",")

--- Build the base env-var prefix string (e.g. "FOO=bar BAZ=qux ").
local function build_env_str(cfg)
  local parts = {}
  for k, v in pairs(cfg.env) do
    table.insert(parts, k .. "=" .. v)
  end
  return #parts > 0 and (table.concat(parts, " ") .. " ") or ""
end

--- Build the makeprg string used by :make / :Make.
-- Pipes through sed to strip just's "|| " prefix so the errorformat sees
-- standard cargo/rustc output.
local function build_makeprg(cfg)
  local env_str = build_env_str(cfg)
  local target_str = cfg.target ~= "" and (" " .. cfg.target) or ""
  return env_str .. cfg.makeprg .. target_str .. " 2>&1 | sed 's/^|| *//'"
end

--- Build the b:dispatch command used by :Dispatch.
-- No sed pipe here — dispatch (especially with tmux/screen backends) runs in a
-- real terminal where shell pipelines can behave unexpectedly.  Instead we:
--   • add CARGO_TERM_COLOR=never to prevent ANSI escape codes
--   • let the errorformat handle the raw "|| "-prefixed just output directly.
local function build_dispatch_cmd(cfg)
  local env_str = build_env_str(cfg)
  local target_str = cfg.target ~= "" and (" " .. cfg.target) or ""
  -- CARGO_TERM_COLOR=never prevents cargo from emitting ANSI colour codes that
  -- would confuse the errorformat when running in a terminal backend.
  local color = "CARGO_TERM_COLOR=never "
  return env_str .. color .. cfg.makeprg .. target_str
end

--- Returns true when vim-dispatch is loaded and its :Make command exists.
local function has_dispatch()
  return vim.fn.exists(":Make") == 2
end

--- Configure the just compiler for the current window.
-- Sets makeprg, errorformat, and b:dispatch (for vim-dispatch) without running make.
function M.setup_compiler(opts)
  local cfg = vim.tbl_deep_extend("force", M.config, opts or {})

  -- Load compiler/just.vim from runtimepath for basic defaults
  vim.cmd("compiler just")

  -- makeprg (for :make / :Make): full pipeline with sed strip
  vim.opt_local.makeprg = build_makeprg(cfg)

  -- errorformat: handles both raw "|| "-prefixed output (Dispatch) and
  -- sed-stripped output (make/Make) in one combined pattern set.
  vim.opt_local.errorformat = errorformat

  -- b:dispatch (for :Dispatch): raw command without sed pipe.
  -- dispatch (especially tmux/screen backends) runs in a real terminal; we
  -- avoid the sed pipe and instead handle the "|| " prefix in errorformat.
  -- CARGO_TERM_COLOR=never is baked into build_dispatch_cmd() to suppress
  -- ANSI colour codes that would break parsing in terminal backends.
  vim.b.dispatch = build_dispatch_cmd(cfg)
end

--- Run a build and optionally open quickfix.
-- Uses vim-dispatch's :Make (async) when available, falls back to :make! (sync).
function M.build(opts)
  local cfg = vim.tbl_deep_extend("force", M.config, opts or {})
  M.setup_compiler(opts)

  if has_dispatch() then
    -- :Make is vim-dispatch's async make; it reads makeprg + errorformat from
    -- the current buffer (already set above) and populates quickfix when done.
    -- vim-dispatch fires QuickFixCmdPost itself, so we skip manual copen here
    -- (use :Copen — dispatch's async-aware version — in your own mappings).
    vim.cmd("Make")
  else
    -- Synchronous fallback
    vim.cmd("make!")

    if cfg.open_quickfix then
      vim.defer_fn(function()
        local qflist = vim.fn.getqflist()
        local has_valid = false
        for _, entry in ipairs(qflist) do
          if entry.valid == 1 then
            has_valid = true
            break
          end
        end
        if has_valid then
          vim.cmd("copen")
          if cfg.jump_to_first then
            vim.cmd("cfirst")
          end
        end
      end, 200)
    end
  end
end

--- Plugin setup — call once in your init.lua.
--
-- Example for a Rust/LibAFL project:
--
--   require('just-compiler').setup({
--     env = {
--       RUST_BACKTRACE     = "full",
--       LIBAFL_QEMU_DIR    = "/Users/a/code/git/qemu-libafl-bridge",
--     },
--     target        = "target",
--     open_quickfix = true,
--     jump_to_first = true,
--   })
--
-- Available commands after setup:
--
--   :JustBuild [target]    Run just; uses :Make (async) if vim-dispatch is
--                          loaded, otherwise falls back to :make! (sync)
--   :JustCompiler [target] Configure compiler without building.
--                          Also sets b:dispatch, so bare :Dispatch / :Make
--                          will use the configured just command.
--   :make / :Make          Re-run the build (sync / async)
--   :Dispatch              Re-run via vim-dispatch using b:dispatch
--   :Copen                 Open quickfix (dispatch-aware)
--   :cn / :cp              Next / previous error
--   :cc N                  Jump to error N
function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})

  -- :JustBuild [target]
  vim.api.nvim_create_user_command("JustBuild", function(args)
    local build_opts = {}
    if args.args and args.args ~= "" then
      build_opts.target = args.args
    end
    M.build(build_opts)
  end, {
    nargs = "?",
    desc = "Run just and load errors into quickfix",
  })

  -- :JustCompiler [target]
  vim.api.nvim_create_user_command("JustCompiler", function(args)
    local setup_opts = {}
    if args.args and args.args ~= "" then
      setup_opts.target = args.args
    end
    M.setup_compiler(setup_opts)
    local cfg = vim.tbl_deep_extend("force", M.config, setup_opts)
    vim.notify(
      string.format(
        "[just-compiler]\n  makeprg   = %s\n  b:dispatch = %s",
        build_makeprg(cfg),
        build_dispatch_cmd(cfg)
      ),
      vim.log.levels.INFO
    )
  end, {
    nargs = "?",
    desc = "Configure just as the compiler (sets makeprg + errorformat)",
  })
end

return M
