# frecency

A navigation-history manager with true frecency scoring (event clock +
exponential moving sum), powered by bash, SQLite and
[fzf](https://github.com/junegunn/fzf).

It tracks **directories and files** in one database, ranks them by a
time-decayed usage score, and lets you search their unified history or use
directory-only and file-only jumps. It integrates with vifm, fish, bash and Neovim, works over
a tmux popup, and is equally usable as a standalone CLI.

## Why not zoxide?

| | zoxide | **frecency** |
|---|---|---|
| Tracks | directories only | **any topic** (dirs, files, shell commands, ...) |
| Ranking | frecency score + global aging | event clock + EMS exponential decay |
| Matching | substring | ordered / any-order **multi-word** + match-quality grading |
| Bookmarks | none | **arbitrary keyword tags** — `M <tag>` records; shell `j <tag>` or `J <tag>` searches the matching type; unbook keeps the history |
| UI | terminal prompt (fzf picker via `zi`) | modal fzf (NORMAL/SEARCH, Vim keys) with live preview |
| Curation | `zoxide delete` / `remove` | delete with undo, keyword bookmarks, keep-history unbookmark |
| Preview | via `ZO_FZF_OPTS` customization | built-in: dirs / text / binary / command; missing paths are struck through and flagged for cleanup |

Keyword bookmarks are the biggest day-to-day difference: a bookmark is an
**arbitrary word** stored with the entry's full usage history — not one of 52
single letters. In the shell, `j <tag>` or `J <tag>` selects a directory or
file keyword match directly. In
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
# Bash or fish: directory-only jump
$ j src parser

# Bash or fish: file-only jump (copies the file path and enters its parent)
$ J notes report

# Bash or fish: unified directory/file history
$ o notes

# Vifm: unified history is o; type-specific command-line commands preserve
# vifm's built-in j movement key.
:j src parser
:J notes report

# Vifm: mark the current file or directory with a keyword. This also creates
# a regular vifm bookmark. `o` opens the shared history picker; search `notes`.
vifm> M notes
vifm> o

# Bash or fish: jump straight to the best history match for that keyword.
$ j notes
```

`j` searches only directory history; `J` searches only file history. Both use
query-aware match grading followed by the decayed usage score (EMS). The `o`
picker remains the unified view and previews files and directories. Selecting
an entry does not add a visit; directories and files are recorded when
explicitly navigated to or opened.

### Integration behavior

All integrations can record to the unified history and to the matching
type-specific history. These histories share `file.db` but have independent
tables and event clocks. Recording differs by host:

| Host | What records history | How it jumps or displays a `file` topic entry |
|---|---|---|
| Bash | `PROMPT_COMMAND` records changed directories; opening files through Bash is not automatically tracked. | `o` searches unified history; `j` jumps to a directory; `J` selects a file, copies its path when `wl-copy` or `xclip` is available, and enters its parent. `Alt-T` inserts a unified history path. |
| Fish | `PWD` hook records changed directories; opening files through Fish is not automatically tracked. | `o`, `j`, and `J` provide the same unified, directory, and file behavior as Bash. `Alt-T` inserts a unified history path. |
| Vifm | `DirEnter` records directories; `l`/`Enter` records opened files; `M` records a keyword bookmark. | `o` opens unified history; `O` browses the current tree; `:j` and `:J` query directory and file history without overriding vifm's built-in `j` motion. |
| Neovim | `BufReadPost` records file buffers and `BufNewFile` records new files; a recent exact-path Vifm record is deduplicated. | No jump command or picker is provided by this integration; it records to unified and file-specific history. |

The integrations track explicit navigation and file opens. They do not monitor
system-wide file-open events from unrelated applications.

The scoring model was inspired by [ze](https://github.com/jghub/ze) and the
design was iterated in [fzf#4789](https://github.com/junegunn/fzf/issues/4789).

```
every navigation ticks that history's event clock:
    score = score * exp(-LAMBDA * (tick_now - tick_last)) + 1
half-life = ln(2)/LAMBDA navigation events
unified `file` history:       LAMBDA = 0.005  -> about 139 events
directory/file-only history:  LAMBDA = 0.01   -> about 69 events
```

The unified clock counts both directory visits and file opens, so its LAMBDA is
halved to keep a similar decay per wall-clock day. Half-lives are counted in
navigation events, not days; convert with your own event rate.

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

- `o` — jump from unified directory/file history
- `j` — jump to the best matching directory-history entry; `j -` behaves like
  `cd -`
- `J` — select a file-history entry, copy its path when a clipboard tool is
  available, and enter its parent directory
- `j`, `J`, and `o` also accept an existing path (a directory for `j`, a file
  for `J`, either for `o`) and act on it directly, before consulting history.
  Existing paths win over history matches; multi-word arguments are always
  treated as history queries.
- automatic recording of changed directories to unified and directory history.
  The Bash hook only writes when `$PWD` actually changes; filtered directories
  still update the remembered value, so returning from one is recorded.
- `Alt-T` inserts a history path at the command line and copies it
  (fish and bash; in bash it overrides the default `M-t` transpose-words)

In the shell, `o` searches unified history while `j` and `J` query
type-specific history. They only need `frecency` on `PATH` — the `~/.local/bin` symlink created by
`--register` / `--bin-link` covers this.

With a single argument, `j` first checks `-` and an existing directory, and
`J`/`o` first check for an existing file (or directory, for `o`). Bare `j`,
`J`, and `o` still open the fzf picker. A non-empty query that matches nothing
prints `frecency: no history match for: <query>` to stderr and exits non-zero,
so `alias cd=j` covers ordinary `cd <dir>` navigation. The alias also makes
bare `cd` open the picker; use `command cd` when you want the shell's built-in
behavior, such as going home with no argument.

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

It records opened files into unified and file-specific history. vifm already
records a file when `l`/`<CR>` opens it, so before adding an entry the
integration checks whether **this exact path** was recorded in the last 5
seconds in either history and skips the record in that case, preventing the
same navigation from being counted twice while unrelated writes (such as a
directory change) do not suppress it. New files (`BufNewFile`) are always
recorded since vifm cannot have seen them.

## Configuration

Per-topic overrides live in `~/.local/share/frecency/<topic>.config` and are
sourced by the script on start. Defaults:

```bash
SEARCH_MODE=sqlite        # sqlite: per-keystroke SQL query (default)
                          # fzf:    load all at once, zero-latency local filter
GRADE_MODE=on             # rank by match quality (keyword/last-segment grades)
MULTIWORD_MODE=ordered    # ordered (foo bar matches foo*bar) or any-order
LAMBDA=0.01               # decay per navigation event; the unified `file`
                          # history defaults to 0.005
MAX_ENTRIES=10000         # cleanup threshold
MAX_DAYS=300              # entries untouched for this long are cleaned up
MAX_PATH_CHARS=60         # weighted display width before list paths abbreviate
START_MODE=search         # 'search' starts with prompt ready, 'normal' with Vim keys
START_DATA=all            # 'all' loads everything, 'last' only the LAST_LIMIT recent entries
UNDO_KEEP=200             # how many deleted entries are kept for undo
RECORD_UNIFIED=1          # also write to the unified `entries` history
RECORD_SPLIT=1            # also write to the matching typed history
IGNORE_PATTERNS=("*/fuse" "*/.git" "*/tmp/*" ... )  # globs never recorded
```

The unified `file` history defaults to `LAMBDA=0.005` because its clock also
counts file events; `file_dir`, `file_file`, and other topics default to
`0.01`. A `LAMBDA` set in a topic config overrides the default for every
destination that topic writes.

Legacy entries remain in unified `entries` after upgrade. Split histories start
accumulating when those directories and files are next visited or opened; the
migration does not guess types for old or missing paths.

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
frecency <topic> add [--route unified[,dir][,file]] <content> [keyword]
                                             # write to selected history destinations
frecency <topic> unbook <content>           # drop keyword, keep EMS history
frecency <topic> query [term]               # open the fzf UI
frecency <topic> jump-handler [term]        # best match / fzf picker -> cd command
frecency <topic> jump-handler-vifm [term]   # same, vifm flavour (goto)
frecency <topic> remove <content>           # delete (undoable in the UI)
frecency <topic> recent <seconds> [content] # exit 0 if content (or anything) changed recently
frecency <topic> cleanup                    # prune by MAX_ENTRIES / MAX_DAYS
```

For the shared `file.db`, logical topics `file`, `file_dir`, and `file_file`
select unified, directory-only, and file-only history. `add --route` selects
write destinations; for example, `--route unified,dir` records a directory in
both unified and directory history. Existing comma-separated topic arguments
retain their meaning of operating on multiple topics.

With a non-empty query, a `file`, `file_dir`, or `file_file` `jump-handler`
that finds no match prints an error to stderr and exits non-zero; the
`jump-handler-vifm` flavour keeps its previous silent behavior.

The integrations default to recording each event in unified and matching
type-specific history. Set `RECORD_UNIFIED=0` in `file.config` to disable the
unified destination, or `RECORD_SPLIT=0` to disable type-specific destinations;
both may be enabled together. Type-specific history has independent event
clocks, so file opens do not decay directory scores and directory visits do not
decay file scores. This keeps three tables in one database file; the split
tables are for distinct history semantics, not a claimed query-performance win.

## License

MIT — see [LICENSE](LICENSE).
