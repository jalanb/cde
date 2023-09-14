"""cde.py knows where you are going because it knows where you've been"""


import os
import sys
from fnmatch import fnmatch
import csv
from typing import Callable
from typing import List
from typing import Optional


from boltons.iterutils import unique
from pysyte.types import paths
from pysyte.types.numbers import as_int
from pysyte.iteration import first_that

from cde import timings
from cde.types import PossiblePaths
from cde.types import UniquePaths
from cde.types import Roots
from cde import __version__


class ToDo(NotImplementedError):
    """Errors raised by this script"""

    pass


class TryAgain(ValueError):
    """Warnings raised by this script"""

    def __init__(self, possibles):
        self.possibles = sorted(possibles)
        super().__init__(
            "\n".join(("Too many possiblities", f"{as_menu_string(possibles)}"))
        )

    def trimmed(self):
        return trim(self.possibles)


def trim(possibles):
    shortest_first = sorted(possibles)
    previous_ = shortest_first[0]
    result = [previous_]
    for possible in shortest_first[1:]:
        if possible in previous_:
            continue
        result.append(possible)
        previous_ = possible
    return result


class RangeError(ToDo):
    def __init__(self, i, matched):
        string = as_menu_string(matched)
        ToDo.__init__(self, f"Your choice of {i} is out of range:\n\t{string}")


class FoundParent(ValueError):
    def __init__(self, parent):
        super(FoundParent, self).__init__("Found a parent directory")
        self.parent = parent


def matching_sub_directories(path_to_dir: str, pattern: str) -> List[paths.StringPath]:
    """A list of all sub-directories named with the given pattern

    If the pattern ends with "/" then look for an exact match only
    Otherwise look for "pattern*"
        If that gives one exact match, prefer that
    """
    pattern_glob = pattern.endswith("/") and pattern.rstrip("/") or f"*{pattern}*"
    sub_directories = paths.list_sub_directories(path_to_dir, pattern_glob)

    if len(sub_directories) < 2:
        return sub_directories
    exacts = [_ for _ in sub_directories if _.basename() == pattern]
    if exacts:
        return exacts
    return sub_directories


def as_menu_items(strings):
    return [""] + [f"{i:2} {p}" for i, p in enumerate(strings)]


def as_menu_string(strings):
    return "\n\t".join(as_menu_items(strings))


def take_first_integer(items):
    """Take the first item as an integer, or None

    >>> items = ['1', '2']
    >>> i = take_first_integer(items)
    >>> i == 1 and items == ['2']
    True
    >>> items = ['one', '2']
    >>> i = take_first_integer(items)
    >>> i == 2 and items == ['one']
    True
    """
    i = first_integer(items)
    if i is not None:
        try:
            items.remove(i)
        except ValueError:
            items.remove(str(i))
    return i


def first_integer(items):
    """Return the int value of the first item

    >>> assert first_integer(['3', '2']) == 3
    >>> assert first_integer(['three', '2']) == 2
    >>> assert first_integer(['three', 'two']) is None
    """
    try:
        return first_that(lambda x: x is not None, [as_int(i) for i in items])
    except KeyError:
        return None


def possibles_under_directory(
    cde_path: paths.StringPath, sub_dirs: List[str]
) -> PossiblePaths:
    """Look under the given directory for matching sub-directories

    Sub-directories match if they are prefixed with given sub_dirs
    If no sub-directories match, but a file matches
        then use the directory
    """
    if not sub_dirs:
        return PossiblePaths([cde_path])
    possibles = PossiblePaths()
    prefix, sub_dirs = sub_dirs[0], sub_dirs[1:]
    paths_to_match = matching_sub_directories(cde_path, prefix)
    if not paths_to_match:
        found = []
        if paths.contains_file(cde_path, f"{prefix}*"):
            found = [cde_path]
        else:
            path_to_prefix = cde_path / prefix
            if path_to_prefix.isdir():
                found = [path_to_prefix]
        possibles.extend(found)
        return possibles
    for path_to_match in paths_to_match:
        possibles.extend(possibles_under_directory(path_to_match, sub_dirs))
    if possibles:
        return possibles
    try:
        i = first_integer(sub_dirs)
        possibles.append(paths_to_match[i])
    except TypeError:
        pass
    except IndexError:
        raise RangeError(i, paths_to_match)
    return possibles


def find_under_directory(cde_path: str, sub_dirs: List[str]):
    """Find one directory under cde_path, matching sub_dirs

    Try any prefixed sub-directories
        then any prefixed files

    Can give None (no matches), or the match, or an Exception
    """
    possibles = possibles_under_directory(cde_path, sub_dirs)
    return first_possible(possibles)


def find_python_root_dir(possibles):
    """Find a python root in a list of dirs

    If all dirs have the same name, and one of them has setup.py
    then it is probably common Python project tree, like
        /path/to/projects/cd
        /path/to/projects/cd/cd
    Or, if all dirs are the same,
        except that one has an egg suffix, like
            /path/to/dotsite/dotsite
            /path/to/dotsite/dotsite.egg-info
    then ignore the egg
    """
    names = {_.basename() for _ in possibles}
    if len(names) == 1:
        for possible in possibles:
            setup = possible / "setup.py"
            if setup.isfile():
                return possible
    eggless = {paths.path(p.replace(".egg-info", "")) for p in possibles}
    if len(eggless) == 1:
        return eggless.pop()
    return None


def first_possible(possibles):
    if len(possibles) < 2:
        purge()
    if not possibles:
        return None
    if len(possibles) == 1:
        return possibles[0]
    if len(possibles) == 2:
        python_path = find_python_root_dir(possibles)
        if python_path:
            return python_path
    raise TryAgain(possibles)


def find_under_here(*args):
    """Look for some other directories under current directory"""
    try:
        return find_under_directory(paths.pwd(), *args)
    except OSError:
        return []


def find_in_environment_path(filename_):
    """Return the first directory in $PATH with a file called filename_

    This is equivalent to "which" command for executable files
    """
    if not filename_:
        return None
    for cde_path in paths.environ_paths("PATH"):
        if not cde_path:
            continue
        path_to_file = cde_path / filename_
        if path_to_file.isfile():
            return cde_path
    return None


def find_at_home(dir_: str, sub_dirs: List[str]):
    """Return the first directory under the home directory matching the dir_

    Match on sub-directories first, then files
        Might return home directory itself

    >>> import random
    >>> a_home_dir = random.choice(paths.home().dirs())
    >>> name = a_home_dir.name
    >>> assert find_at_home(name, []) == a_home_dir
    """
    if dir_ in sub_dirs:
        subdirs = sub_dirs
    else:
        subdirs = [dir_] + sub_dirs
    return find_under_directory(paths.home(), subdirs)


def hidden(path_name):
    return path_name[0] == "."


def build_dir(directory):
    return ".egg" in directory or directory in (
        "htmlcov",
        "build",
    )


def ignorable_dir(directory):
    return hidden(directory) or build_dir(directory)


def find_path_to_dir(dir_: str) -> paths.StringPath:
    """Find the path to the given dir_

    Either the directory itself, or directory of the file itself, or nothing
    """

    def select_sub_dir(
        parent: paths.StringPath, patterned_sub_dirs: List[paths.StringPath]
    ) -> paths.StringPath:
        python_dir = (
            lambda x: not ignorable_dir(x)
            if find_python_root_dir(patterned_sub_dirs)
            else lambda x: True
        )
        python_dirs = [f for f in patterned_sub_dirs if python_dir(f)]
        result_dirs = python_dirs if python_dirs else patterned_sub_dirs
        longest_last = sorted(result_dirs, key=lambda x: len(x))
        try:
            longest_last.pop()
        except IndexError:
            return paths.path(None)

    def trailing_slash(p):
        return p[-1] == "/"

    def find_cde_path(dir_: str) -> paths.StringPath:
        user_says_its_a_directory = trailing_slash(dir_)
        if user_says_its_a_directory:
            dir_ = dir_.rstrip("/")
            if not dir_:
                return paths.root()
        path_ = paths.path(dir_)
        if path_.isdir():
            return path_
        if user_says_its_a_directory:
            return path_
        parent = path_.parent
        if path_.isfile():
            return parent
        if path_.islink():
            if parent.isdir():
                # FIXME - follow the link
                return parent
        if not parent:
            # return path_
            parent = paths.path(".")
        # Tried the full path, let's try just the name
        name = path_.basename()
        pattern = f"{name}*"
        if paths.contains_directory(parent, pattern):
            patterned_sub_dirs = parent.dirs(pattern)
            return select_sub_dir(parent, patterned_sub_dirs)
        elif paths.contains_glob(parent, pattern):
            return parent
        if parent.isdir():
            raise FoundParent(parent)
        return paths.path(None)

    try:
        return find_cde_path(dir_)
    except FoundParent:
        return paths.path(None)


def find_directory(dir_: str, sub_dirs: List[str]):
    """Find a relevant directory relative to the dir_, and using sub_dirs

    dir_ can be
        empty (use home directory)
        "-" (use $OLDPWD)

    Return dir_ if it is a directory,
        or its parent if it is a file
        or one of its sub-directories (if they match sub_dirs)
        or a directory in $PATH
        or an dir_ in history (if any)
        or a directory under $HOME
    Otherwise look for sub_dirs as a partial match
    """
    cde_path = find_path_to_dir(dir_)
    if cde_path:
        if not sub_dirs:
            return cde_path
        path_to_prefix = find_under_directory(cde_path, sub_dirs)
        if path_to_prefix:
            return path_to_prefix
        path_to_history = find_in_history(dir_, sub_dirs)
        if path_to_history:
            return path_to_history
    else:
        args = ([dir_] if dir_ else []) + sub_dirs
        cde_path = find_under_here(args)
    if cde_path:
        return cde_path
    cde_path = find_in_history(dir_, sub_dirs)
    if cde_path:
        return cde_path
    cde_path = find_in_environment_path(dir_)
    if cde_path:
        return cde_path
    cde_path = find_at_home(dir_, sub_dirs)
    if cde_path:
        return cde_path
    raise ToDo("could not use %r as a directory" % " ".join([dir_] + sub_dirs))


def stdout(fred: str):
    fred = fred if fred else ""
    sys.stdout.write(f"{fred}\n")


def stderr(fred: str):
    fred = fred if fred else ""
    sys.stderr.write(f"{fred}\n")


def version(_args):
    """Show version of the script"""
    stdout(f"{sys.argv[0]} {__version__}")
    raise SystemExit(os.EX_OK)


def filename(_args):
    """Show filename of the script"""
    stdout(f"{__file__}".replace(".pyc", "py"))
    raise SystemExit(os.EX_OK)


def unused(args):
    used = ["-u", "--unused", args.dirname] + args.sub_dirs
    unused_args = [_ for _ in sys.argv[1:] if _ not in used]
    stdout(" ".join(unused_args))
    raise SystemExit(os.EX_OK)


def test(_args):
    """Run all doctests based on this file

    Tell any bash-runners not to use any output by saying "Error" first

    >>> assert 'cde.py' in __file__
    """
    stem = paths.path(__file__).namebase
    from doctest import testfile, testmod, ELLIPSIS, NORMALIZE_WHITESPACE

    options = ELLIPSIS | NORMALIZE_WHITESPACE
    failed, _ = testfile(f"{stem}.tests", optionflags=options)
    if failed:
        return
    failed, _ = testfile(f"{stem}.test", optionflags=options)
    if failed:
        return
    failed, _ = testmod(optionflags=options)
    if failed:
        return
    stdout("All tests passed")


def makedir(args):
    """Make the directory in the args unless it exists"""
    path_to_dirname = paths.path(args.dirname)
    if path_to_dirname.isdir():
        return True
    return path_to_dirname.makedirs()


def old(args):
    if args.dirname:
        show_path_to_historical_dir(args.dirname, args.sub_dirs)
    else:
        show_paths()
    raise SystemExit(os.EX_OK)


def complete(_args=None):
    """Show all paths in history"""
    history_items = read_history()
    for _rank, path, _time in history_items:
        stdout(path)
    raise SystemExit(os.EX_OK)


def existing(_args=None):
    """Show all existing paths in history"""
    history_items = read_history()
    for _rank, path, _time in history_items:
        if os.path.exists(path):
            stdout(path)
    raise SystemExit(os.EX_OK)


def lost(_args=None):
    lost_paths = [p for r, p, t in read_history() if not os.path.isdir(p)]
    for path in lost_paths:
        stdout(path)
    raise SystemExit(os.EX_OK)


def delete(args):
    if args.dirname:
        delete_path_to_historical_dir(args.dirname, args.sub_dirs)
    else:
        show_paths()


def add(args):
    """Add the dirname in args to the history"""
    try:
        path_to_dirname = paths.path(args.dirnames)
        path = path_to_dirname.realpath()
        s = path.slashpath()
        add_path(s)
        error = 0
    except OSError as e:
        error = str(e)
    raise SystemExit(error)


def run_args(args):
    """Run any methods eponymous with args"""
    if not args:
        return False
    g = globals()
    true_args = {k for k, v in args.items() if v}
    args_in_globals = {g[k] for k in g if k in true_args}
    methods = {a for a in args_in_globals if callable(a)}
    for method in methods:
        method(args)
    return True


def previous():
    """Where we were (in bash) before this directory"""
    try:
        return os.environ["OLDPWD"]
    except KeyError:
        return "~"


def set_args_directory(args):
    if not args.dirname:
        args.sub_dirs = []
        if args.add:
            return "."
        if not args.old:
            return paths.home()
    if args.dirname == "-":
        return previous()
    return args.dirname


def _path_to_config():
    """Path where our config files are kept"""
    stem = paths.path(__file__).namebase
    config = paths.home() / f".config/{stem}"
    if not config.isdir():
        os.makedirs(str(config))
    return config


def _path_to_history():
    """Path to where history of paths is stored"""
    path_to_config = _path_to_config()
    return path_to_config / "history"


def read_history():
    """Recall remembered paths"""
    path = _path_to_history()
    if not path.isfile():
        return []
    with open(path, "r") as stream:
        reader = csv.reader(
            stream, delimiter=",", quotechar='"', quoting=csv.QUOTE_MINIMAL
        )
        return [_ for _ in reader if _]


def sort_history(history):
    def as_key(arg):
        rank, path, time = arg
        return (rank, time, path)

    return sorted(history, key=as_key)


def sorted_history():
    """A list of history items

    Sorted by ascending rank, descending time
    """
    history = read_history()
    return sort_history(history)


def frecent_history():
    """A list of paths from history

    Sorted by descending rank, ascending time
    """
    return reversed(sorted_history())


def frecent_history_paths():
    """A list of paths, sorted from history"""
    return [paths.path(p) for _rank, p, _time in frecent_history()]


def increment(string):
    """Add 1 to the int in that string

    >>> increment('1') == '2'
    True
    """
    return str(int(string) + 1)


def include_new_path_in_items(history_items, new_path):
    """Add the given path to the existing history

    Or update it if already present"""
    new_time = timings.now()
    found = False
    for old_rank, old_path, old_time in history_items:
        if old_path == new_path:
            yield increment(old_rank), old_path, new_time
            found = True
        else:
            yield old_rank, old_path, old_time
    if not found:
        yield 1, paths.path(new_path), new_time


def add_path(path_to_add):
    path_to_add = find_path_to_dir(path_to_add)
    history_items = read_history()
    items = include_new_path_in_items(history_items, path_to_add)
    write_paths(items)


def write_paths(paths_to_remember):
    """Write the given paths to the history file"""
    with open(str(_path_to_history()), "w") as stream:
        writer = csv.writer(
            stream, delimiter=",", quotechar='"', quoting=csv.QUOTE_MINIMAL
        )
        writer.writerows(paths_to_remember)


def quietly(_args=None):
    global stderr
    stderr = lambda x: ""


def Quietly(_args=None):
    global stdout
    stdout = lambda x: ""


def QUIETLY(_args=None):
    """Bash readers like this one"""
    Quietly
    quietly


def purge(_args=None):
    """Delete the given path from the history"""
    history_items = read_history()
    new_items, changed = keep_existing_paths(history_items)
    if changed:
        write_paths(new_items)


def keep_existing_paths(history_items):
    new_items = []
    changed = False
    for rank, path, time in history_items:
        if not os.path.exists(path):
            changed = True
        else:
            new_items.append((rank, path, time))
    return new_items, changed


def rewrite_history_without_path(cde_path):
    """Delete the given path from the history"""
    history_items = read_history()
    new_items, changed = exclude_path_from_items(history_items, cde_path)
    if changed:
        write_paths(new_items)


def exclude_path_from_items(history_items, cde_path):
    new_items = []
    changed = False
    for rank, path, time in history_items:
        if path == cde_path:
            changed = True
        else:
            new_items.append((rank, path, time))
    return new_items, changed


def find_in_history(dir_: str, sub_dirs: List[str]):
    """If the given dir_ and sub_dirs are in the history return that path

    Otherwise None
    """
    frecent_paths = unique(frecent_history_paths())
    try:
        return frecent_paths[int(dir_) - 1]
    except ValueError:
        return _find_in_paths(dir_, sub_dirs, frecent_paths)


def frecent_matchers(dir_: str) -> List[Callable[[str], bool]]:
    """Make a list of matchers for that dir_"""

    def globbed(p):
        return fnmatch(str(p), f"{dir_}*")

    def glob_match(path):
        for p in path.split(os.path.sep):
            if globbed(p):
                return True
        return False

    def same(p):
        return dir_ == p

    def within(p):
        return dir_ in str(p)

    def same_base(p):
        return dir_ == p.basename()

    def glob_base(p):
        return globbed(p.basename())

    def glob_base_glob(p):
        return globbed(f"*{p.basename()}")

    def ancestor(p):
        return dir_ in p.split(os.path.sep)

    def with_path(p):
        if os.path.sep in dir_:
            return dir_ in p
        return False

    result = [
        same,
        same_base,
        glob_base,
        ancestor,
        glob_match,
        glob_base_glob,
        with_path,
        within,
    ]
    return result


def frecently_matched(dir_: str, frecent_paths):
    for matcher in frecent_matchers(dir_):
        paths = [_ for _ in frecent_paths if matcher(_)]
        if paths:
            return UniquePaths(paths)
    return UniquePaths([])


def possible_i(possibilities, i):
    try:
        return possibilities[i]
    except IndexError:
        raise RangeError(i, possibilities)
    except TypeError:
        pass


def _find_in_paths(
    dir_: str, sub_dirs: List[str], frecent_paths: List[str]
) -> Optional[paths.StringPath]:
    """Get the first of those paths which meets one of the criteria:

    1. has any substring that matches (as long as the dir_ contains a "/")
    2. is same as dir_
    3. has same basename as dir_
    4. has same basename as "dir_*"
    5. has a parent with same basename as dir_
    6. has a parent with same basename as "dir_*"

    paths are assumed to be ordered, so first matching path wins
    """
    possibles = UniquePaths([])
    matched = frecently_matched(dir_, frecent_paths)
    i = take_first_integer(sub_dirs)
    if not sub_dirs:
        possibles.extend(matched)
    elif len(matched) == 1:
        if i:
            raise RangeError(i, matched)
        possibles.extend(possibles_under_directory(matched[0], sub_dirs))
    if matched and i is not None:
        try:
            match_ = matched[i]
        except IndexError:
            raise RangeError(i, matched)
        possibles.extend(possibles_under_directory(match_, sub_dirs))
    elif len(matched) > 1:
        [possibles.extend(possibles_under_directory(_, sub_dirs)) for _ in set(matched)]
    possibilities = PossiblePaths(possibles)
    if not possibilities:
        return None
    if len(possibilities) == 1:
        return possibilities.pop()
    if i is not None:
        return possible_i(possibilities, i)
    name = sub_dirs[-1] if sub_dirs else dir_
    named = [p for p in possibilities if name == p.name]
    if len(named) == 1:
        return named.pop()
    roots = Roots(named)
    if len(roots) == 1:
        return roots.pop()
    if named:
        ordered = sorted(named, key=lambda x: -len(x))
        shorter, *more = [str(_) for _ in ordered]
        for longer in more:
            if longer.startswith(shorter):
                return shorter
            shorter = longer
        return shorter
    globbed_ = [p for p in possibilities if name in p.name]
    if len(globbed_) == 1:
        return globbed_.pop()
    elif globbed_:
        possibilities = PossiblePaths(globbed_)
    if sub_dirs:
        raise TryAgain(possibilities)
    raise TryAgain(named)


def show_path_to_historical_dir(dir_: str, sub_dirs: List[str]):
    """Get a path for the given dir_ from history and show it"""
    cde_path = find_in_history(dir_, sub_dirs)
    return show_found_item(cde_path)


def delete_path_to_historical_dir(dir_: str, sub_dirs: List[str]):
    """Get a path for the given dir_ from history and remove it from history"""
    cde_path = find_in_history(dir_, sub_dirs)
    delete_found_item(cde_path)


def show_found_item(cde_path) -> bool:
    """Show the path to the user, and the history"""
    if not cde_path:
        return False
    add_path(cde_path)
    stdout(str(cde_path))
    return True


def delete_found_item(cde_path):
    """Delete the path from the history"""
    if cde_path:
        rewrite_history_without_path(cde_path)


def cd(string: str) -> None:
    os.chdir(cde(string, []))


def cde(dir_: str, sub_dirs: List[str]):
    """Don't blink!  This is where the cde's code gets run.

    >>> _ = cde('/', ['us', 'lo'])
    /usr/local
    """
    cde_path = find_directory(dir_, sub_dirs)
    return show_found_item(cde_path)


def show_paths():
    """Show all paths in history in user-terminology"""
    old_rank = None
    for order, (rank, p, atime) in enumerate(frecent_history()):
        if old_rank != rank:
            stdout("      %s time%s:" % (rank, int(rank) > 1 and "s" or ""))
            old_rank = rank
        stdout("%3d: %s, %s ago" % (order + 1, p, timings.time_since(atime)))


def previous():
    return cde.previous()


def args_directory(args):
    breakpoint()
    dirname, dirnames = args.dirnames
    if dirname:
        return previous() if dirname == "-" else dirname
    if args.add:
        return "."
    if not args.old:
        return paths.home()
    return args.dirnames


def valued_args(args, valuer: Callable):
    cde = vars(valued_args)
    breakpoint()
    if not args:
        return False
    args_ = args.get_args()
    result = {k for k, v in args_.items() if v}
    cde_args = {getattr(cde, _, None) for _ in dir(cde) if _ in result}
    cde_methods = {a for a in cde_args if callable(a)}
    return cde_methods
    for method in cde_methods:
        method(args)
