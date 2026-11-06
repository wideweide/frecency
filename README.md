# frecency

A navigation-history manager for [vifm](https://vifm.info) with true frecency
scoring (event clock + exponential moving sum), powered by bash, SQLite and
[fzf](https://github.com/junegunn/fzf).

It tracks **directories and files** in one database, ranks them by a
time-decayed usage score, and lets you jump to any of them from a modal fzf
UI with live preview — inside vifm, from your shell, or over a tmux popup.

## Why not zoxide?

| | zoxide | **frecency** |
|---|---|---|
| Tracks | directories only | **any topic** (dirs, files, shell commands, ...) |
| Ranking | stepwise time buckets + global aging | event clock + EMS exponential decay |
| Matching | substring | ordered / any-order **multi-word** + match-quality grading |
| UI | terminal prompt | modal fzf (NORMAL/SEARCH, Vim keys) with live preview |
| Curation | none | delete with undo, keyword bookmarks, keep-history unbookmark |
| Preview | none | dirs / text / binary / command, 4-way branch |

The scoring model was inspired by [ze](https://github.com/jghub/ze) and the
design was iterated in [fzf#4789](https://github.com/junegunn/fzf/issues/4789).

```
every navigation ticks a global event clock:
    score = score * exp(-LAMBDA * (tick_now - tick_last)) + 1
half-life = ln(2)/LAMBDA ≈ 69 navigations (LAMBDA = 0.01)
```

Old entries fade out naturally; a vacation won't wipe your history (the clock
only ticks on real navigation events, not on wall time).

## Requirements

- bash 4.4+
- sqlite3 >= 3.35 built with `SQLITE_ENABLE_MATH_FUNCTIONS` (for `exp()`);
  static fallback binaries for x86_64 / aarch64 are bundled
- fzf >= 0.48 (`--accept-nth` / `change-footer` / `rebind`)
- gawk recommended (mawk counts CJK paths in bytes and abbreviates too early)
- optional: eza / bat / highlight (nicer previews), wl-copy / xclip (clipboard)

## Install

```bash
git clone https://github.com/<you>/frecency.git
cd frecency
./install.sh            # installs into ~/.config/vifm/scripts/
./install.sh --dry-run  # preview
./install.sh --uninstall
```

The installer never touches your `vifmrc`. Copy the printed snippet into
`~/.config/vifm/vifmrc`:

```vim
" --- frecency: commands (silent, async, non-blocking) ---
command! trackPath !frecency file add "%d" %a >/dev/null 2>&1 &
command! trackFile
    \ ! [ ! -d "%d/%f" ] && frecency file add "%d/%f" %a >/dev/null 2>&1 &
command! removeRecord
    \ !frecency file remove "%d/%f" >/dev/null 2>&1 &
command! Bmark : execute '!bmark.sh %d/%f %a &'

" record every directory you enter
autocmd DirEnter *,.* trackPath

" record on open / remove record on delete / bookmark with keyword
nnoremap <silent> l    :trackFile<cr>l
nnoremap <silent> <cr> :trackFile<cr><cr>
nnoremap <silent> dd   :removeRecord<cr>dd
nnoremap          M    :Bmark<space>

" o = jump from history (EMS + match grade), O = browse current tree
source ~/.config/vifm/scripts/frecency.vifm
```

> **Why not a vifm plugin?** vifm's `plugins/` directory only loads Lua
> plugins (`plugins/<name>/init.lua`); a `.vifm` script there is never sourced
> and shows up as `[failed]` in `:plugins`. The whole integration is two
> recording hooks and two mappings — a `:source`d file next to the script is
> the thinnest possible glue, and matches the approach vifm's author
> recommends for zoxide integration (Q2A #949).

## Keys

In vifm:

| key | action |
|---|---|
| `o` | jump from history: type words to jump to the best match directly, empty input opens fzf |
| `O` | browse the current directory tree with fzf (`--walker`), complements `o`'s global history |
| `M` | bookmark current entry with a keyword |

Inside the frecency fzf UI:

| key | action |
|---|---|
| `/` | enter SEARCH mode (prompt turns blue, Vim keys unbound) |
| `Esc` | SEARCH -> NORMAL, NORMAL -> quit |
| `j k h l g G` | Vim navigation (NORMAL mode) |
| `c` / `x` | clear query and start searching |
| `d` | delete entry (trash table, undoable) |
| `r` | remove keyword bookmark, keep path and EMS history |
| `u` | undo last delete |
| `s` | toggle ordered / any-order multi-word matching |
| `C` | run cleanup now |
| `Enter` | jump |

## Shell integration (fish)

```fish
# z-like jump: words jump straight to the best match, empty opens fzf
function j --description "z-like jump from frecency history"
    set -l cmd (frecency file jump-handler "$argv")
    if test -n "$cmd"
        eval $cmd
    end
end

# record PWD changes
function __frecency_pwd_handler --on-variable PWD
    if not string match -qr "^(/tmp/|/run/|/sys/|/proc/)" "$PWD"
        nohup frecency file add "$PWD" >/dev/null 2>&1 & disown
    end
end

# Alt-T / Alt-J: pick a path from history, insert at cursor and copy it
function __frecency_pick
    set -l sel (frecency file query | string trim)
    if test -n "$sel"
        commandline -i -- $sel
        if command -q wl-copy
            printf %s "$sel" | wl-copy
        else if command -q xclip
            printf %s "$sel" | xclip -selection clipboard
        end
    end
end
bind \et __frecency_pick
bind \ej __frecency_pick
```

Directories and files share one database (topic `file`), so `j` works for both.

## Configuration

Per-topic overrides live in `~/.local/share/frecency/<topic>.config` and are
sourced by the script on start. Defaults:

```bash
SEARCH_MODE=sqlite        # sqlite: per-keystroke SQL query (default)
                          # fzf:    load all at once, zero-latency local filter
GRADE_MODE=on             # rank by match quality (keyword/last-segment grades)
MULTIWORD_MODE=ordered    # ordered (foo bar matches foo*bar) or any-order
LAMBDA=0.01               # decay constant; half-life = ln(2)/LAMBDA navigations
MAX_ENTRIES=10000         # cleanup threshold
MAX_DAYS=300              # entries untouched for this long are cleaned up
MAX_PATH_CHARS=60         # weighted display width before list paths abbreviate
START_MODE=search         # 'search' starts with prompt ready, 'normal' with Vim keys
```

Data lives in `~/.local/share/frecency/` (one SQLite database per topic, WAL
mode, `flock`-protected migration). `frecency file cleanup` runs maintenance
manually; deleting entries is undoable (`u`) and can be confirmed with `C`.

## CLI

```bash
frecency <topic> init                       # init / migrate schema
frecency <topic> add <content> [keyword]    # record an entry
frecency <topic> unbook <content>           # drop keyword, keep EMS history
frecency <topic> query [term]               # open the fzf UI
frecency <topic> jump-handler [term]        # best match / fzf picker -> cd command
frecency <topic> jump-handler-vifm [term]   # same, vifm flavour (goto)
frecency <topic> remove <content>           # delete (undoable in the UI)
frecency <topic> cleanup                    # prune by MAX_ENTRIES / MAX_DAYS
```

## License

MIT — see [LICENSE](LICENSE).
