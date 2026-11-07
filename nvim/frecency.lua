-- ============================================================================
-- frecency.lua - Neovim integration for frecency
-- ============================================================================
-- #frecency for nvim
--
-- Loaded from init.lua via a marked dofile() line:
--     -- #frecency for nvim
--     dofile("<absolute path to this file>")
--
-- Records opened files into the shared `file` topic, the same database the
-- vifm and shell integrations use.
--
-- Deduplication: vifm records a file when it is opened with l/<CR>. When the
-- database was updated within the last 5 seconds, this visit is assumed to be
-- the same navigation and is skipped instead of counted twice
-- ("frecency file recent 5" performs the check).
--
-- Requires `frecency` on PATH (normally ~/.config/vifm/scripts).

local track_group = vim.api.nvim_create_augroup("FrecencyTrack", { clear = true })

local function absolute_input_path(path)
    if not path or path == "" then return "" end

    -- Neovim may resolve symlinks in the buffer name before BufReadPost.
    -- Only complete relative paths here; never call :p / fs_realpath, so the
    -- path form typed by the user is preserved.
    if path == "~" then
        return vim.env.HOME or path
    elseif path:sub(1, 2) == "~/" then
        return (vim.env.HOME or "~") .. path:sub(2)
    elseif path:sub(1, 1) == "/" or path:match("^%a:[/\\\\]")
        or path:match("^[/\\\\][/\\\\]") then
        return path
    end

    local cwd = vim.fn.getcwd()
    local pwd = vim.env.PWD
    if pwd and pwd:sub(1, 1) == "/" then
        -- Vifm can start Neovim with a relative %c while the process cwd is the
        -- physical directory and PWD still contains the user's symlink path.
        -- Trust PWD only if both names resolve to the same directory inode.
        local cwd_stat = vim.loop.fs_stat(cwd)
        local pwd_stat = vim.loop.fs_stat(pwd)
        if cwd_stat and pwd_stat and cwd_stat.dev == pwd_stat.dev
            and cwd_stat.ino == pwd_stat.ino then
            cwd = pwd
        end
    end
    return cwd .. "/" .. path
end

-- Record a file unless the database was updated recently, which means vifm
-- already logged this navigation through its l/<CR> mappings.
local function record(path)
    vim.fn.jobstart({ "frecency", "file", "recent", "5" }, {
        on_exit = function(_, code)
            if code ~= 0 then
                vim.fn.jobstart({ "frecency", "file", "add", path })
            end
        end,
    })
end

vim.api.nvim_create_autocmd("BufReadPre", {
    group = track_group,
    callback = function(ev)
        -- ev.file is still the path as passed by the user; the BufReadPost
        -- buffer name may already have symlinks resolved.
        vim.b[ev.buf].frecency_input_path = absolute_input_path(ev.file)
    end,
})

vim.api.nvim_create_autocmd({ "BufReadPost", "BufNewFile" }, {
    group = track_group,
    callback = function(ev)
        local path
        if ev.event == "BufNewFile" then
            path = absolute_input_path(ev.file)
            vim.b[ev.buf].frecency_input_path = path
        else
            path = vim.b[ev.buf].frecency_input_path or absolute_input_path(ev.file)
        end
        local buftype = vim.bo[ev.buf].buftype

        -- Skip empty buffers, non-file buffers and URIs (NvimTree, help,
        -- plugin buffers).
        if path == "" or buftype ~= "" or path:match("^%a[%w+.-]*://") then
            return
        end

        if ev.event == "BufNewFile" then
            -- A brand-new file cannot have been recorded by vifm; add directly.
            vim.fn.jobstart({ "frecency", "file", "add", path })
        else
            record(path)
        end
    end,
})
