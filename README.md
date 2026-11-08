# frecency

A navigation-history manager with true frecency scoring (event clock +
exponential moving sum), powered by bash, SQLite and
[fzf](https://github.com/junegunn/fzf).

It tracks **directories and files** in one database, ranks them by a
time-decayed usage score, and lets you jump to any of them from a modal fzf UI
with live preview. It integrates with vifm, fish, bash and Neovim, works over
a tmux popup, and is equally usable as a standalone CLI.

## Why not zoxide?

| | zoxide | **frecency** |
|---|---|---|
| Tracks | directories only | **any topic** (dirs, files, shell commands, ...) |
| Ranking | frecency score + global aging | event clock + EMS exponential decay |
| Matching | substring | ordered / any-order **multi-word** + match-quality grading |
| Bookmarks | none | **arbitrary keyword tags** — `M <tag>` records, `o <tag>` jumps directly (grade 0, zero interaction), unbook keeps the history |
| UI | terminal prompt (fzf picker via `zi`) | modal fzf (NORMAL/SEARCH, Vim keys) with live preview |
| Curation | `zoxide delete` / `remove` | delete with undo, keyword bookmarks, keep-history unbookmark |
| Preview | via `ZO_FZF_OPTS` customization | built-in: dirs / text / binary / command, 4-way branch |

Keyword bookmarks are the biggest day-to-day difference: a bookmark is an
**arbitrary word** stored with the entry's full usage history — not one of 52
single letters. Because a keyword hit is grade 0, `o <tag>` lands on it in
one step with no interaction, which makes it an effective replacement for
vifm's `marks` (in vifm, `M` also syncs the vifm bookmark via
`vifm --remote`, so marks-based navigation keeps working). Dropping the tag
never throws away the data.

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
- file (MIME detection for previews), flock (util-linux, migration locking)
- gawk recommended (mawk counts CJK paths in bytes and abbreviates too early)
- optional: eza / bat / highlight (nicer previews), wl-copy / xclip (clipboard)

## Layout

```
scripts/            frecency, frecency-test, bmark.sh  -> ~/.config/vifm/scripts/
frecency.vifm       vifm integration                   -> ~/.config/vifm/frecency.vifm
shell/frecency.fish fish integration                   -> ~/.config/fish/frecency.fish
shell/frecency.bash bash integration                    -> ~/.config/frecency/frecency.bash
nvim/frecency.lua   neovim integration                  -> ~/.config/nvim/frecency/frecency.lua
bundled/            static sqlite3 binaries            -> native-arch binary into vifm scripts/ (when needed)
scripts/frecency    symlink                             -> ~/.local/bin/frecency (opt-in)
```

## Install

```bash
git clone <repo-url> frecency
cd frecency
./install.sh                 # interactive menu on a TTY; files-only install otherwise
./install.sh --register      # install and register everything (incl. the bin symlink)
./install.sh --no-register   # install files only
./install.sh --bin-link      # also create the ~/.local/bin symlink
./install.sh --dry-run       # preview every action
./install.sh --vifm-dir DIR  # custom vifm directory (default: $XDG_CONFIG_HOME/vifm)
./install.sh --unregister    # show and remove registered source lines
./install.sh --uninstall     # remove registration lines and installed files
```

Run without arguments on a terminal, the installer shows a menu:

```
frecency installer
==================
  vifm dir: ~/.config/vifm

  1) Install and register everything (recommended)
  2) Install, choosing each integration individually
  3) Install files only (skip registration)
  4) Unregister (remove source lines)
  5) Uninstall (remove installed files)
  6) Dry-run: preview install + register
  q) Quit
Choice [1]:
```

Without a TTY (e.g. `curl ... | bash`), the installer only copies files and
touches nothing else; every write is opt-in via `--register` / `--bin-link`.

The bundled static sqlite3 is only installed when the system sqlite3 does not
already qualify (>= 3.35 with `exp()`), and only for the native architecture.
After installing, the self-check runs and the shared `file` database is
initialized (`frecency file init`); failure there is non-fatal — a topic
database is also created lazily on first use.
The installer can also create a `~/.local/bin/frecency` symlink so the script
is reachable from any shell (bash, fish, zsh, ...) without further `PATH`
setup; vifm itself adds its `scripts/` directory to `PATH` automatically, so
`bmark.sh` needs no configuration.

The installer registers a marked `source` line in `vifmrc`:

```vim
" #frecency for vifm
source ~/.config/vifm/frecency.vifm
```

The rest of the integration lives in `frecency.vifm`. Registration is
idempotent: if `#frecency for vifm` already exists, the installer leaves the
file untouched and tells you to compare it manually — or delete the old block
and run `--register` again. `--unregister` prints the exact lines it will
remove before changing anything.

Fish, bash and Neovim integrations are installed and registered when the
corresponding shell or `init.lua` is detected (menu choice 2 lets you pick
each one individually), using the same marker mechanism (a marked `source`
line for the shells, a marked `dofile()` for Neovim). Before registering
vifm, the installer also scans `vifmrc` for existing mappings of the keys
`frecency.vifm` redefines and prints a non-blocking warning for each conflict.

> **Why not a vifm plugin?** vifm's `plugins/` directory only loads Lua
> plugins (`plugins/<name>/init.lua`); a `.vifm` script there is never sourced
> and shows up as `[failed]` in `:plugins`. A `:source`d file is the thinnest
> possible glue and matches the approach vifm's author recommends for zoxide
> integration (Q2A #949).

## Keys

In vifm (defined in `frecency.vifm`):

| key | action |
|---|---|
| `l` / `<CR>` | open and record the file |
| `dd` | delete the file and remove its record |
| `M` | bookmark the current entry with a keyword |
| `o` | jump from history: type words to jump to the best match directly, empty input opens fzf |
| `O` | browse the current directory tree with fzf (`--walker`), complements `o`'s global history |

Inside the frecency fzf UI:

| key | action |
|---|---|
| `/` | enter SEARCH mode (prompt turns blue, Vim keys unbound) |
| `Esc` | SEARCH -> NORMAL, NORMAL -> quit |
| `q` | quit (NORMAL mode) |
| `j k h l g G` | Vim navigation (NORMAL mode) |
| `c` / `x` | clear query and start searching |
| `d` | delete entry (trash table, undoable) |
| `r` | remove keyword bookmark, keep path and EMS history |
| `u` | undo last delete |
| `s` | toggle ordered / any-order multi-word matching |
| `C` | run cleanup now |
| `Enter` | jump |

### Key conflicts

`l`, `<CR>`, `dd`, `o`, `O`, `M` are common keys. Because `frecency.vifm` is
sourced last, its mappings override any earlier definition in `vifmrc`. The
installer scans `vifmrc` at registration time and warns about conflicting
user mappings (it cannot see vifm defaults, other sourced files or runtime
`:map` commands). If you already use one of these keys:

1. edit the corresponding `nnoremap` in `frecency.vifm` to a key you prefer, or
2. delete the mapping line and call the commands directly instead:
   `:trackFile`, `:removeRecord`, `:Bmark`, `:frecency file query`.

## Shell integration

Both integrations are installed by `install.sh` and provide:

- `j` — z-like jump: a directory is `cd`'d into, a file opens its parent
  directory and copies the path to the clipboard
- automatic recording of every directory change in the `file` topic
- `Alt-T` inserts a history path at the command line and copies it
  (fish and bash; in bash it overrides the default `M-t` transpose-words)

Directories and files share one database (topic `file`), so `j` works for both.
They only need `frecency` on `PATH` — the `~/.local/bin` symlink created by
`--register` / `--bin-link` covers this.

Load manually if needed:

```fish
source ~/.config/fish/frecency.fish
```

```bash
source ~/.config/frecency/frecency.bash
```

## Neovim integration

`nvim/frecency.lua` is installed to `~/.config/nvim/frecency/frecency.lua` and
registered in `init.lua` with a marked `dofile()` line:

```lua
-- #frecency for nvim
dofile("/home/youruser/.config/nvim/frecency/frecency.lua")
```

It records opened files into the shared `file` topic. vifm already records a
file when `l`/`<CR>` opens it, so before adding an entry the integration asks
the database whether **this exact path** was recorded in the last 5 seconds
(`frecency file recent 5 <path>`) and skips the record in that case,
preventing the same navigation from being counted twice while unrelated
writes (such as a directory change) do not suppress it. New files
(`BufNewFile`) are always recorded since vifm cannot have seen them.

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
START_DATA=all            # 'all' loads everything, 'last' only the LAST_LIMIT recent entries
UNDO_KEEP=200             # how many deleted entries are kept for undo
IGNORE_PATTERNS=("*/fuse" "*/.git" "*/tmp/*" ... )  # globs never recorded
```

Data lives in `~/.local/share/frecency/` (one SQLite database per topic, WAL
mode, `flock`-protected migration). A topic database is created lazily on
first use — copying the script by hand and running `frecency file add ...`
is enough; `frecency <topic> init` initializes or migrates explicitly.
`frecency file cleanup` runs maintenance manually; deleting entries is
undoable (`u`) and can be confirmed with `C`.

## CLI

```bash
frecency <topic> init                       # init / migrate schema (optional; lazily done on first use)
frecency <topic> add <content> [keyword]    # record an entry
frecency <topic> unbook <content>           # drop keyword, keep EMS history
frecency <topic> query [term]               # open the fzf UI
frecency <topic> jump-handler [term]        # best match / fzf picker -> cd command
frecency <topic> jump-handler-vifm [term]   # same, vifm flavour (goto)
frecency <topic> remove <content>           # delete (undoable in the UI)
frecency <topic> recent <seconds> [content] # exit 0 if content (or anything) changed recently
frecency <topic> cleanup                    # prune by MAX_ENTRIES / MAX_DAYS
```

## License

MIT — see [LICENSE](LICENSE).
