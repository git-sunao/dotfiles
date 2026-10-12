local status, markdown = pcall(require, "markdown-preview")
if not status then
	print("Markdown preview not installed.")
	return
end

markdown.setup({
	mkdp_filetypes = { "markdown" },
	mkdp_port = 9956,
	mkdp_echo_preview_url = true,
})
