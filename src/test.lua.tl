@*=
new_ns = vim.api.nvim_buf_set_virtual_text(9, 0, 0, {{ " | User 0101", "Special" }, { " | User 0202", "Special" }}, {})
print("new namespace " .. new_ns)
