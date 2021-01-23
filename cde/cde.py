"""cde.py knows where you are going because it knows where you've been"""


import os
import sys
from fnmatch import fnmatch
import csv
from typing import Callable
from typing import List


from boltons.iterutils import unique
from pysyte.types import paths
from pysyte.types.numbers import as_int
from pysyte.iteration import first_that

from cde import timings
from cde.types import PossiblePaths
from cde.types import UniquePaths
from cde import __version__


class ToDo(NotImplementedError):
    """Errors raised by this script"""

    pass


class TryAgain(ValueError):
    """Warnings raised by this script"""

    def __init__(self, possibles):
        self.possibles = sorted(possibles)
        super().__init__(
            "\n".join(
                ("Too many possiblities", f"{as_menu_string(possibles)}")
            )
        )

    def trimmed(self):
        return trim(self.possibles)


def trim(possibles):
    shortest_first = sorted(possibles)
    previous = shortest_first[0]
    result = [previous]
    for possible in shortest_first[1:]:
        if possible in previous:
            continue
        result.append(possible)
        previous = possible
    return result


class RangeError(ToDo):
    def __init__(self, i, matched):
        string = as_menu_string(matched)
        ToDo.__init__(self, f"Your choice of {i} is out of range:\n\t{string}")


class FoundParent(ValueError):
    def __init__(self, parent):
        super(FoundParent, self).__init__("Found a parent directory")
        self.parent = parent


def matching_sub_directories(path_to_directory, prefix):
    """A list of all sub-directories named with the given prefix

    If the prefix ends with "/" then look for an exact match only
    Otherwise look for "prefix*"
        If that gives one exact match, prefer that
    """
    prefix_glob = prefix.endswith("/") and prefix.rstrip("/") or f"{prefix}*"
    sub_directories = paths.list_sub_directories(
        path_to_directory, prefix_glob
    )

    if len(sub_directories) < 2:
        return sub_directories
    exacts = [_ for _ in sub_directories if _.basename() == prefix]
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


def possibles_under_directory(path_to_directory, subdirnames):
    """Look under the given directory for matching sub-directories

    Sub-directories match if they are prefixed with given subdirnames
    If no sub-directories match, but a file matches
        then use the directory
    """
    if not subdirnames:
        return PossiblePaths([path_to_directory])
    possibles = PossiblePaths()
    prefix, subdirnames = subdirnames[0], subdirnames[1:]
    paths_to_match = matching_sub_directories(path_to_directory, prefix)
    if not paths_to_match:
        found = []
        if paths.contains_file(path_to_directory, f"{prefix}*"):
            found = [path_to_directory]
        else:
            path_to_prefix = path_to_directory / prefix
            if path_to_prefix.isdir():
                found = [path_to_prefix]
        possibles.extend(found)
        return possibles
    for path_to_match in paths_to_match:
        possibles.extend(possibles_under_directory(path_to_match, subdirnames))
    if possibles:
        return possibles
    try:
        i = first_integer(subdirnames)
        possibles.append(paths_to_match[i])
    except TypeError:
        pass
    except IndexError:
        raise RangeError(i, paths_to_match)
    return possibles


def find_under_directory(path_to_directory, subdirnames):
    """Find one directory under path_to_directory, matching subdirnames

    Try any prefixed sub-directories
        then any prefixed files

    Can give None (no matches), or the match, or an Exception
    """
    possibles = possibles_under_directory(path_to_directory, subdirnames)
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
    """Look for some other directories under current directory """
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
    for path_to_directory in paths.environ_paths("PATH"):
        if not path_to_directory:
            continue
        path_to_file = path_to_directory / filename_
        if path_to_file.isfile():
            return path_to_directory
    return None


def find_at_home(item, subdirnames):
    """Return the first directory under the home directory matching the item

    Match on sub-directories first, then files
        Might return home directory itself

    >>> import random
    >>> a_home_dir = random.choice(paths.home().dirs())
    >>> name = a_home_dir.name
    >>> assert find_at_home(name, []) == a_home_dir
    """
    if item in subdirnames:
        subdirs = subdirnames
    else:
        subdirs = [item] + subdirnames
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


def find_path_to_item(item):
    """Find the path to the given item

    Either the directory itself, or directory of the file itself, or nothing
    """

    def user_says_its_a_directory(p):
        return p[-1] == "/"

    def find_path_to_item_():
        if user_says_its_a_directory(item):
            if item[0] == "/":
                return paths.path(item)
            return item.rstrip("/")
        path_to_item = paths.path(item)
        if not path_to_item:
            return None
        if path_to_item.isdir():
            return path_to_item
        parent = path_to_item.dirname()
        if path_to_item.isfile():
            return parent
        elif os.path.islink(item):
            parent = os.path.dirname(item)
            if os.path.isdir(parent):
                return paths.makepath(parent)
        pattern = f"{path_to_item.basename()}*"
        if paths.contains_directory(parent, pattern):
            patterned_sub_dirs = parent.dirs(pattern)
            python_dir = (
                lambda x: not ignorable_dir(x)
                if find_python_root_dir(patterned_sub_dirs)
                else lambda x: True
            )
            python_dirs = [f for f in patterned_sub_dirs if python_dir(f)]
            longest_first = sorted(
                python_dirs, key=lambda x: len(x), reverse=True
            )
            longest_named_python_sub_dir = longest_first.pop()
            return longest_named_python_sub_dir
        elif paths.contains_glob(parent, pattern):
            return parent
        if parent.isdir():
            raise FoundParent(parent)
        return None

    try:
        return find_path_to_item_()
    except FoundParent:
        return None


def find_directory(item, subdirnames):
    """Find a relevant directory relative to the item, and using subdirnames

    item can be
        empty (use home directory)
        "-" (use $OLDPWD)

    Return item if it is a directory,
        or its parent if it is a file
        or one of its sub-directories (if they match subdirnames)
        or a directory in $PATH
        or an item in history (if any)
        or a directory under $HOME
    Otherwise look for subdirnames as a partial match
    """
    path_to_item = find_path_to_item(item)
    if path_to_item:
        if not subdirnames:
            return path_to_item
        path_to_prefix = find_under_directory(path_to_item, subdirnames)
        if path_to_prefix:
            return path_to_prefix
    else:
        args = ([item] if item else []) + subdirnames
        path_to_item = find_under_here(args)
    if path_to_item:
        return path_to_item
    path_to_item = find_in_history(item, subdirnames)
    if path_to_item:
        return path_to_item
    path_to_item = find_in_environment_path(item)
    if path_to_item:
        return path_to_item
    path_to_item = find_at_home(item, subdirnames)
    if path_to_item:
        return path_to_item
    raise ToDo(
        "could not use %r as a directory" % " ".join([item] + subdirnames)
    )


def version(_args):
    """Show version of the script"""
    print(f"{sys.argv[0]} {__version__}")
    raise SystemExit(os.EX_OK)


def filename(_args):
    """Show filename of the script"""
    print(f"{__file__}".replace(".pyc", "py"))
    raise SystemExit(os.EX_OK)


def unused(args):
    used = ["-u", "--unused", args.dirname] + args.subdirnames
    unused_args = [_ for _ in sys.argv[1:] if _ not in used]
    print(" ".join(unused_args))
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
    print("All tests passed")


def makedir(args):
    """Make the directory in the args unless it exists"""
    path_to_dirname = paths.path(args.dirname)
    if path_to_dirname.isdir():
        return True
    return path_to_dirname.makedirs()


def old(args):
    if args.dirname:
        show_path_to_historical_item(args.dirname, args.subdirnames)
    else:
        show_paths()
    raise SystemExit(os.EX_OK)


def complete(_args=None):
    """Show all paths in history"""
    history_items = read_history()
    for _rank, path, _time in history_items:
        print(path)
    raise SystemExit(os.EX_OK)


def existing(_args=None):
    """Show all existing paths in history"""
    history_items = read_history()
    for _rank, path, _time in history_items:
        if os.path.exists(path):
            print(path)
    raise SystemExit(os.EX_OK)


def lost(_args=None):
    lost_paths = [p for r, p, t in read_history() if not os.path.isdir(p)]
    for path in lost_paths:
        print(path)
    raise SystemExit(os.EX_OK)


def delete(args):
    if args.dirname:
        delete_path_to_historical_item(args.dirname, args.subdirnames)
    else:
        show_paths()


def add(args):
    """Add the dirname in args to the history"""
    try:
        path_to_dirname = paths.path(args["dirname"])
        add_path(path_to_dirname)
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


def previous_directory():
    """Where we were (in bash) before this directory"""
    try:
        return os.environ["OLDPWD"]
    except KeyError:
        return "~"


def set_args_directory(args):
    if not args.dirname:
        args.subdirnames = []
        if args.add:
            return "."
        if not args.old:
            return paths.home()
    if args.dirname == "-":
        return previous_directory()
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
    def as_key(item):
        rank, path, time = item
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
    path_to_add = find_path_to_item(path_to_add)
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


def rewrite_history_without_path(path_to_item):
    """Delete the given path from the history"""
    history_items = read_history()
    new_items, changed = exclude_path_from_items(history_items, path_to_item)
    if changed:
        write_paths(new_items)


def exclude_path_from_items(history_items, path_to_item):
    new_items = []
    changed = False
    for rank, path, time in history_items:
        if path == path_to_item:
            changed = True
        else:
            new_items.append((rank, path, time))
    return new_items, changed


def find_in_history(item, subdirnames):
    """If the given item and subdirnames are in the history return that path

    Otherwise None
    """
    frecent_paths = unique(frecent_history_paths())
    try:
        return frecent_paths[int(item) - 1]
    except ValueError:
        return _find_in_paths(item, subdirnames, frecent_paths)


def frecent_matchers(item: str) -> List[Callable[[str], bool]]:
    """Make a list of matchers for that item"""

    def globbed(p):
        return fnmatch(str(p), f"{item}*")

    def glob_match(path):
        for p in path.split(os.path.sep):
            if globbed(p):
                return True
        return False

    def same(p):
        return item == p

    def within(p):
        return item in p

    def same_base(p):
        return item == p.basename()

    def glob_base(p):
        return globbed(p.basename())

    def glob_base_glob(p):
        return globbed(f"*{p.basename()}")

    def ancestor(p):
        return item in p.split(os.path.sep)

    def with_path(p):
        if os.path.sep in item:
            return item in p
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


def frecently_matched(item, frecent_paths):
    for matcher in frecent_matchers(item):
        paths = [_ for _ in frecent_paths if matcher(_)]
        if paths:
            return UniquePaths(paths)
    return UniquePaths([])


def _find_in_paths(item, subdirnames, frecent_paths):
    """Get the first of those paths which meets one of the criteria:

    1. has any substring that matches (as long as the item contains a "/")
    2. is same as item
    3. has same basename as item
    4. has same basename as "item*"
    5. has a parent with same basename as item
    6. has a parent with same basename as "item*"

    paths are assumed to be ordered, so first matching path wins
    """
    possibles = UniquePaths([])
    matched = frecently_matched(item, frecent_paths)
    i = take_first_integer(subdirnames)
    if not subdirnames:
        possibles.extend(matched)
    elif len(matched) == 1:
        if i:
            raise RangeError(i, matched)
        possibles.extend(possibles_under_directory(matched[0], subdirnames))
    if i is not None:
        try:
            match_ = matched[i]
        except IndexError:
            raise RangeError(i, matched)
        possibles.extend(possibles_under_directory(match_, subdirnames))
    elif len(matched) > 1:
        [
            possibles.extend(possibles_under_directory(_, subdirnames))
            for _ in set(matched)
        ]
    possibilities = PossiblePaths(possibles)
    if not possibilities:
        return None
    if len(possibilities) > 1:
        if i is not None:
            try:
                return possibilities[i]
            except IndexError:
                raise RangeError(i, possibilities)
            except TypeError:
                pass
        if not subdirnames:
            named = [p for p in possibilities if item == p.name]
            if len(named) == 1:
                return named.pop()
            if not named:
                globbed_ = [p for p in possibilities if item in p.name]
                if len(globbed_) == 1:
                    return globbed_.pop()
                if globbed_:
                    possibilities = globbed_
        raise TryAgain(possibilities)
    return possibilities.pop()


def show_path_to_historical_item(item, subdirnames):
    """Get a path for the given item from history and show it"""
    path_to_item = find_in_history(item, subdirnames)
    return show_found_item(path_to_item)


def delete_path_to_historical_item(item, subdirnames):
    """Get a path for the given item from history and remove it from history"""
    path_to_item = find_in_history(item, subdirnames)
    delete_found_item(path_to_item)


def show_found_item(path_to_item):
    """Show the path to the user, and the history"""
    if not path_to_item:
        return False
    add_path(path_to_item)
    print(str(path_to_item))
    return True


def delete_found_item(path_to_item):
    """Delete the path from the history"""
    if path_to_item:
        rewrite_history_without_path(path_to_item)


def cd(string):
    os.chdir(cde(string), [])


def cde(item, subdirnames):
    """Don't blink!  This is where the cde's code gets run.

    >>> _ = cde('/', ['us', 'lo'])
    /usr/local
    """
    path_to_item = find_directory(item, subdirnames)
    return show_found_item(path_to_item)


def show_paths():
    """Show all paths in history in user-terminology"""
    old_rank = None
    for order, (rank, p, atime) in enumerate(frecent_history()):
        if old_rank != rank:
            print("      %s time%s:" % (rank, int(rank) > 1 and "s" or ""))
            old_rank = rank
        print("%3d: %s, %s ago" % (order + 1, p, timings.time_since(atime)))
