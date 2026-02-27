" just-compiler.nvim - Plugin entry point
" Loads automatically when Neovim starts (if plugin is in runtimepath)

if exists('g:loaded_just_compiler')
  finish
endif
let g:loaded_just_compiler = 1

" The compiler file is registered via the compiler/ directory automatically.
" Lua setup is done by the user calling require('just-compiler').setup(...)
