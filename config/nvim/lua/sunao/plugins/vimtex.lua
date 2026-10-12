local status, vimtex = pcall(require, "vimtex")
if not status then
  return
end

vimtex.setup({
  tex_flavor = "latex",          -- Default tex file format
  vimtex_view_method = "skim",   -- Choose which program to use to view PDF file
  vimtex_view_skim_sync = 1,     -- Value 1 allows forward search after every successful compilation
  vimtex_view_skim_activate = 1, -- Value 1 allows change focus to skim after command `:VimtexView` is given
})
