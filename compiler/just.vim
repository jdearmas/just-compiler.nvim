" Vim compiler file for just (task runner, with Rust/cargo output support)
" Compiler: just
" Part of: just-compiler.nvim
"
" This file is loaded by `compiler just`.  The Lua module overrides makeprg
" and errorformat with the full env-var + target + sed-strip configuration.

if exists("current_compiler")
  finish
endif
let current_compiler = "just"

" Default makeprg: plain just.  The Lua module replaces this with the full
" env-var + target + sed-strip pipeline via vim.opt_local.makeprg.
CompilerSet makeprg=just

" Errorformat for Rust/cargo output AFTER the '|| ' prefix has been stripped.
"
" Multi-line strategy:
"   %E  = error start        (error[E...]: message)
"   %W  = warning start      (warning: message)
"   %I  = note/info          (note: message)
"   %C  = continuation line  ('   --> file:line:col' sets the entry location)
"   %-G = ignore line
"
" Note: entries close automatically when the next %E/%W/%I starts.
"
CompilerSet errorformat=
  \%-G,
  \%-Gerror:\ could\ not\ compile%.%#,
  \%-Gerror:\ aborting\ due\ to%.%#,
  \%-GSome\ errors\ have\ detailed%.%#,
  \%-GFor\ more\ information\ about%.%#,
  \%-G%#=\ note:%.%#,
  \%-G%#=\ help:%.%#,
  \%-GAlready\ up\ to\ date.,
  \%-GCompiling\ %.%#,
  \%-GFinished\ %.%#,
  \%-Gcargo%.%#,
  \%-Gmkdir%.%#,
  \%Eerror[E%n]:\ %m,
  \%Eerror:\ %m,
  \%Wwarning[W%n]:\ %m,
  \%Wwarning:\ %m,
  \%Inote:\ %m,
  \%C\ %#-->\ %f:%l:%c,
  \%C%.%#,
  \%-G%.%#
