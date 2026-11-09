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
| Bookmarks | none | **arbitrary keyword tags** — `M <tag>` records; shell `j <tag>` jumps directly (grade 0); unbook keeps the history |
| UI | terminal prompt (fzf picker via `zi`) | modal fzf (NORMAL/SEARCH, Vim keys) with live preview |
| Curation | `zoxide delete` / `remove` | delete with undo, keyword bookmarks, keep-history unbookmark |
| Preview | via `ZO_FZF_OPTS` customization | built-in: dirs / text / binary / command; missing paths are struck through and flagged for cleanup |

Keyword bookmarks are the biggest day-to-day difference: a bookmark is an
**arbitrary word** stored with the entry's full usage history — not one of 52
single letters. In the shell, `j <tag>` selects a keyword match directly. In
vifm, `M` also creates a vifm bookmark via `vifm --remote`; `o` opens the
history picker, where you can search for the tag. Dropping the tag never throws
away the data.

## 30-second start

From a clone of this repository, install and register integrations:

```bash
./install.sh --register
```

Open a new Bash or fish shell (or source the installed integration in the
current shell), visit a few directories so they enter history, then jump to a
known directory by a path fragment:

```bash
j project
```

The installer runs its self-check and initializes the shared `file` database.
The complete install options are below.

## Typical use

These examples show the current behavior; history results depend on paths
already recorded in your `file` topic.

```text
# Bash or fish: multi-word path search. A directory match changes directory;
# a file match changes to its parent and copies the path when wl-copy/xclip exists.
$ j src parser

# Vifm: mark the current file or directory with a keyword. This also creates
# a regular vifm bookmark. `o` opens the shared history picker; search `notes`.
vifm> M notes
vifm> o

# Bash or fish: jump straight to the best history match for that keyword.
$ j notes
```

For an arbitrary history entry, `j` uses query-aware match grading followed by
the decayed usage score (EMS); the fzf history picker also previews files and
directories. The path itself is recorded when visited/opened, while selecting
it in the picker does not add a visit.

### Integration behavior

All integrations use the shared `file` topic, so directory and file records
can appear in the same history list. Recording differs by host:

| Host | What records history | How it jumps or displays a `file` topic entry |
|---|---|---|
| Bash | `PROMPT_COMMAND` records changed directories; opening files through Bash is not automatically tracked. | `j` changes to a directory; for a file it changes to the parent and copies the file path when `wl-copy` or `xclip` is available. `Alt-T` inserts a selected history path. |
| Fish | `PWD` hook records changed directories; opening files through Fish is not automatically tracked. | `j` has the same directory/file behavior as Bash. `Alt-T` inserts a selected history path. |
| Vifm | `DirEnter` records directories; `l`/`Enter` records opened files; `M` records a keyword bookmark. | `o` opens the shared history picker and goes to a selected directory or file. `O` browses the current tree and does not use history. |
| Neovim | `BufReadPost` records file buffers and `BufNewFile` records new files; a recent exact-path Vifm record is deduplicated. | No jump command or picker is provided by this integration; it records files into the shared topic. |

In Bash and fish, `j` on a file positions in its parent directory and copies
the file path to the clipboard when `wl-copy` or `xclip` is available. In
Vifm, the picker goes to the selected file. Neovim has no `j` integration.

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

To add ignored path patterns, put Bash array syntax in the topic config, for
example `~/.local/share/frecency/file.config`:

```bash
IGNORE_PATTERNS+=("*/node_modules/*" "*/vendor/*")
```

The config is sourced by the Bash script, so use trusted local configuration
files only. Ignore patterns are checked when entries are added.

## Data and maintenance

Topic databases and their configuration live in
`~/.local/share/frecency/`; for example, `file` uses
`~/.local/share/frecency/file.db`. The script currently uses this fixed
location under `$HOME` and has no data-directory override.

To back up or move history safely, stop shells and applications that may write
to frecency, then copy the **entire** directory, including any SQLite `-wal`
and `-shm` files, to the same relative location under the destination home. For
example, with `backup_dir` set to a safe backup location:

```bash
mkdir -p "$backup_dir"
cp -a "$HOME/.local/share/frecency" "$backup_dir/"
```

On the destination, after stopping writers, restore it only if
`~/.local/share/frecency/` does not already exist:

```bash
mkdir -p "$HOME/.local/share"
cp -a "$backup_dir/frecency" "$HOME/.local/share/"
```

Frecency has no database merge command. Back up any existing destination data
separately and keep both backups until the destination has been opened
successfully. On first use, frecency initializes or migrates a topic database
as needed; `frecency file init` explicitly runs initialization for the `file`
topic. Do not discard or replace an existing user database to upgrade the
program.

Use `frecency file query` to inspect and search the `file` history. Replace
`file` with another topic name for that topic. `frecency <topic> cleanup` prunes
old unbookmarked entries using that topic's `MAX_DAYS` and `MAX_ENTRIES`
settings; bookmarked entries are retained. Individual entries can be deleted
with `frecency <topic> remove <content>` or from the UI with undo available.
There is currently no supported command to reset or list all entries for a
topic in the CLI. Do not delete a database file as a reset shortcut; that can
discard history and leave related SQLite state behind.

Databases use SQLite WAL mode, and schema initialization/migration is protected
by `flock`. `frecency <topic> init` initializes or migrates a topic explicitly;
the UI's `C` key runs cleanup immediately, while `u` restores the latest
deleted entry.

Maintainers can use the [regression checklist](docs/REGRESSION.md) before
releasing changes.

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
