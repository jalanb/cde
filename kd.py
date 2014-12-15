"""kd is a better cd

Usage: kd [options] [items]

Arguments:
    items are strings which indicate a path to a directory or file
    The first item might be a full path
    Second and other items are used to choose under that path

Options:
  -h, --help     show this help message and exit
  -a, --add      add a path to history
  -d, --delete   delete a path from history
  -p, --purge    remove all non-existent paths from history
  -o, --old      look for paths in history
  -t, --test     test the script
  -v, --version  show version of the script
  -U, --Use_debugger      For developer: debug with pdb (pudb if available)



Explanation:

It gets a close match to a directory from command line arguments
    Then prints that to stdout
    which allows a usage in bash like
        $ cd $(python kd.py /usr local bin)
    or
        $ cd $(python kd.py /bin/ls)

First argument is a directory
    subsequent arguments are prefixes of sub-directories
    For example:
        $ python kd.py /usr/local bi
        /usr/local/bin

Or first argument is a file
    $ python kd.py /bin/ls
    /bin

Or first argument is a stem of a directory/file
    kd.py will add * on to such a stem,
    and will always find directories first,
        looking for files only if there are no such directories
    $ python kd.py /bin/l
    /bin

Or first argument is part of a directory that kd has seen before
    "part of" means the name or
    the start of the name or
    the name of a parent or
    the start of a name of a parent
    (or any part of the full path if you include a "/")

If no matches then give directories in $PATH which have matching executables
    $ python kd.py ls
    /bin
"""


from __future__ import print_function
import os
import bdb
import sys
from fnmatch import fnmatch
import argparse
import csv


import timings


from dotsite import paths

__version__ = '0.3.4'


class ToDo(NotImplementedError):
    """Errors raised by this script"""
    pass


class TryAgain(NotImplementedError):
    """Warnings raised by this script"""
    pass


class RangeError(ToDo):
    def __init__(self, i, matched):
        template = 'Your choice of "%s" is out of range:\n\t%s'
        message = template % (i, as_menu_string(matched))
        ToDo.__init__(self, message)


class FoundParent(ValueError):
    def __init__(self, parent):
        super(FoundParent, self).__init__('Found a parent directory')
        self.parent = parent


def matching_sub_directories(path_to_directory, prefix):
    """A list of all sub-directories named with the given prefix

    If the prefix ends with "/" then look for an exact match only
    Otherwise look for "prefix*"
        If that gives one exact match, prefer that
    """
    prefix_glob = prefix.endswith('/') and prefix.rstrip('/') or '%s*' % prefix
    sub_directories = paths.list_sub_directories(
        path_to_directory, prefix_glob)

    if len(sub_directories) < 2:
        return sub_directories
    exacts = [directory
              for directory in sub_directories
              if directory.basename() == prefix]
    if exacts:
        return exacts
    return sub_directories


def as_menu_items(strings):
    return [str('%2d: %s' % (i, p)) for i, p in enumerate(strings)]


def as_menu_string(strings):
    return '\n\t'.join(as_menu_items(strings))


def take_first_integer(items):
    """Take the first item as an integer, or None

    >>> items = ['1', '2']
    >>> i = take_first_integer(items)
    >>> i == 1 and items == ['2']
    True
    >>> items = ['one', '2']
    >>> i = take_first_integer(items)
    >>> i is None and items == ['one', '2']
    True
    """
    i = first_integer(items)
    if i is not None:
        del items[0]
    return i


def first_integer(items):
    """Return the int value of the first item

    >>> first_integer(['3', '2']) == 3
    True
    >>> first_integer(['three', '2']) is None
    True
    """
    try:
        return int(items[0])
    except (ValueError, IndexError):
        return None


def look_under_directory(path_to_directory, prefixes):
    """Look under the given directory for matching sub-directories

    Sub-directories match if they are prefixed with given prefixes
    If no sub-directories match, but a file matches
        then use the directory
    """
    if not prefixes:
        return [path_to_directory]
    prefix, prefixes = prefixes[0], prefixes[1:]
    result = []
    matched_sub_directories = matching_sub_directories(
        path_to_directory, prefix)
    path_to_sub_directory = path_to_directory / prefix
    if not matched_sub_directories:
        if paths.contains_file(path_to_directory, '%s*' % prefix):
            return [path_to_directory]
        if path_to_sub_directory.isdir():
            return [path_to_sub_directory]
        return []
    i = first_integer(prefixes)
    for path_to_sub_directory in matched_sub_directories:
        paths_under = look_under_directory(path_to_sub_directory, prefixes)
        result.extend(paths_under)
    if not result:
        if i is not None:
            try:
                return [matched_sub_directories[i]]
            except IndexError:
                raise ToDo('Your choice of "%s" is not in range:\n\t%s' % (
                    i, as_menu_string(matched_sub_directories)))
        if paths.contains_file(path_to_directory, '%s*' % prefix):
            result = [path_to_directory]
    return result


def find_under_directory(path_to_directory, prefixes):
    """Find one directory under path_to_directory, matching prefixes

    Try any prefixed sub-directories
        then any prefixed files

    Can give None (no matches), or the match, or an Exception
    """
    possibles = look_under_directory(path_to_directory, prefixes)
    if not possibles:
        return None
    if len(possibles) == 1:
        return possibles[0]
    return too_many_possibles(possibles)


def find_python_root_dir(possibles):
    """Find a python root in a list of dirs

    If all dirs have the same name, and one of them has setup.py
    then it is probably common Python project tree, like
        /path/to/projects/kd
        /path/to/projects/kd/kd
    Or, if all dirs are the same,
        except that one has an egg suffix, like
            /path/to/dotsite/dotsite
            /path/to/dotsite/dotsite.egg-info
    then ignore the egg
    """
    names = {p.basename() for p in possibles}
    if len(names) == 1:
        for possible in possibles:
            setup = possible / 'setup.py'
            if setup.isfile():
                return possible
    eggless = {paths.makepath(p.replace('.egg-info', '')) for p in possibles}
    if len(eggless) == 1:
        return eggless.pop()


def too_many_possibles(possibles):
    possibles = [p for p in possibles if p.exists()]
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
    raise TryAgain('Too many possiblities\n\t%s' % as_menu_string(possibles))


def find_under_here(prefixes):
    """Look for some other directories under current directory """
    try:
        return find_under_directory(paths.here(), prefixes)
    except OSError:
        return []


def find_in_environment_path(filename):
    """Return the first directory in $PATH with a file called filename

    This is equivalent to "which" command for executable files
    """
    if not filename:
        return None
    for path_to_directory in paths.environ_paths('PATH'):
        if not path_to_directory:
            continue
        path_to_file = path_to_directory / filename
        if path_to_file.isfile():
            return path_to_directory
    return None


def find_at_home(item, prefixes):
    """Return the first directory under the home directory matching the item

    Match on sub-directories first, then files
        Might return home directory itself

    >>> print(find_at_home('bin', []))
    /.../bin
    """
    if item in prefixes:
        return find_under_directory(paths.home(), prefixes)
    return find_under_directory(paths.home(), [item] + prefixes)


def find_path_to_item(item):
    """Find the path to the given item

    Either the directory itself, or directory of the file itself, or nothing
    """
    user_says_its_a_directory = lambda x: x[-1] == '/'
    if user_says_its_a_directory(item):
        if len(item) > 1:
            item = item.rstrip('/')
        return item
    path_to_item = paths.makepath(item)
    if path_to_item.isdir():
        return path_to_item
    parent = path_to_item.dirname()
    if path_to_item.isfile():
        return parent
    pattern = '%s*' % path_to_item.basename()
    if paths.contains_directory(parent, pattern):
        return parent.dirs(pattern).pop()
    elif paths.contains_glob(parent, pattern):
        return parent
    if parent.isdir():
        raise FoundParent(parent)
    return None


def previous_directory():
    """Where we were (in bash) before this directory"""
    try:
        return os.environ['OLDPWD']
    except KeyError:
        return '~'


def find_directory(item, prefixes):
    """Find a relevant directory relative to the item, and using prefixes

    item can be
        empty (use home directory)
        "-" (use $OLDPWD)

    Return item if it is a directory,
        or its parent if it is a file
        or one of its sub-directories (if they match prefixes)
        or a directory in $PATH
        or an item in history (if any)
        or a directory under $HOME
    Otherwise look for prefixes as a partial match
    """
    try:
        path_to_item = find_path_to_item(item)
    except FoundParent:
        path_to_item = None
    if path_to_item:
        if not prefixes:
            return path_to_item
        path_to_prefix = find_under_directory(path_to_item, prefixes)
        if path_to_prefix:
            return path_to_prefix
    else:
        if item:
            args = [item] + prefixes
        else:
            args = prefixes
        if args:
            path_to_item = find_under_here(args)
    if path_to_item:
        return path_to_item
    path_to_item = find_in_history(item, prefixes)
    if path_to_item:
        return path_to_item
    path_to_item = find_in_environment_path(item)
    if path_to_item:
        return path_to_item
    path_to_item = find_at_home(item, prefixes)
    if path_to_item:
        return path_to_item
    raise ToDo('could not use %r as a directory' % ' '.join([item] + prefixes))


def run_args(args, methods):
    """Run any methods eponymous with args"""
    if not args:
        return False
    valuable_args = {k for k, v in args.__dict__.items() if v}
    arg_methods = {methods[a] for a in valuable_args if a in methods}
    for method in arg_methods:
        method(args)


def version(_args):
    """Show version of the script"""
    print('kd %s' % __version__)
    raise SystemExit


def Use_debugger(_args):
    try:
        import pudb as pdb
    except ImportError:
        import pdb
    pdb.set_trace()


def parse_args(methods):
    """Get the arguments from the command line.

    Insist on at least one empty string"""
    usage = '''usage: kd directory prefix ...

    %s''' % __doc__
    parser = argparse.ArgumentParser(
        description='Find a directory to cd to', usage=usage)
    parser.add_argument('-a', '--add', action='store_true',
                        help='add a path to history')
    parser.add_argument('-d', '--delete', action='store_true',
                        help='delete a path from history')
    parser.add_argument('-p', '--purge', action='store_true',
                        help='remove all non-existent paths from history')
    parser.add_argument('-o', '--old', action='store_true',
                        help='look for paths in history')
    parser.add_argument('-t', '--test', action='store_true',
                        help='test the script')
    parser.add_argument('-v', '--version', action='store_true',
                        help='show version of the script')
    parser.add_argument('-U', '--Use_debugger', action='store_true',
                        help='debug with pdb (pudb if available)')
    parser.add_argument('directory', metavar='item', nargs='?', default='',
                        help='(partial) directory name')
    parser.add_argument('prefixes', nargs='*',
                        help='(partial) sub directory names')
    args = parser.parse_args()
    run_args(args, methods)
    args.directory = set_args_directory(args)
    return args


def set_args_directory(args):
    if not args.directory:
        args.prefixes = []
        if args.add:
            return '.'
        if not args.old:
            return paths.home()
    if args.directory == '-':
        return previous_directory()
    return args.directory


def test(_args):
    """Run all doctests based on this file

    Tell any bash-runners not to use any output by saying "Error" first

    >>> 'kd' in __file__
    True
    """
    stem = paths.makepath(__file__).namebase
    from doctest import testfile, testmod, ELLIPSIS, NORMALIZE_WHITESPACE
    options = ELLIPSIS | NORMALIZE_WHITESPACE
    failed, _ = testfile('%s.tests' % stem, optionflags=options)
    if failed:
        return
    failed, _ = testfile('%s.test' % stem, optionflags=options)
    if failed:
        return
    failed, _ = testmod(optionflags=options)
    if failed:
        return
    print('All tests passed')


def _path_to_config():
    """Path where our config files are kept"""
    stem = paths.makepath(__file__).namebase
    config = paths.home() / str('.config/%s' % stem)
    if not config.isdir():
        os.makedirs(config)
    return config


def _path_to_history():
    """Path to where history of paths is stored"""
    path_to_config = _path_to_config()
    return path_to_config / 'history'


def read_history():
    """Recall remembered paths"""
    path = _path_to_history()
    if not path.isfile():
        return []
    with open(path, 'rb') as stream:
        reader = csv.reader(stream, delimiter=',', quotechar='"',
                            quoting=csv.QUOTE_MINIMAL)
        return [row for row in reader]


def sort_history(history):
    def compare(one, two):
        rank1, path1, time1 = one
        rank2, path2, time2 = two
        diff = cmp(int(rank1), int(rank2))
        if diff:
            return diff
        diff = cmp(float(time2), float(time1))
        if diff:
            return -diff
        return cmp(path1, path2)
    return sorted(history, cmp=compare)


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
    return [paths.makepath(p) for _rank, p, _time in frecent_history()]


def increment(string):
    """Add 1 to the int in that string

    >>> increment('1') == '2'
    True
    """
    return str(int(string) + 1)


def include_new_path_in_items(history_items, new_path):
    """Add the given path to the existing history

    Or update it if already present"""
    is_new_path = True
    result = []
    new_time = timings.now()
    for old_rank, old_path, old_time in history_items:
        if new_path == old_path:
            result.append((increment(old_rank), new_path, new_time))
            is_new_path = False
        else:
            result.append((old_rank, old_path, old_time))
    if is_new_path:
        new_rank = 1
        result.append((new_rank, new_path, new_time))
    return sorted(result)


def add(args):
    """Remember the given path for later use"""
    arg_path = paths.makepath(args.directory)
    add_path(arg_path)


def add_path(path_to_add):
    path_to_add = find_path_to_item(path_to_add)
    history_items = read_history()
    items = include_new_path_in_items(history_items, path_to_add)
    write_paths(items)


def write_paths(paths_to_remember):
    """Write the given paths to the history file"""
    with open(_path_to_history(), 'wb') as stream:
        writer = csv.writer(stream, delimiter=',', quotechar='"',
                            quoting=csv.QUOTE_MINIMAL)
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


def find_in_history(item, prefixes):
    """If the given item and prefixes are in the history return that path

    Otherwise None
    """
    frecent_paths = frecent_history_paths()
    try:
        return frecent_paths[int(item) - 1]
    except ValueError:
        return _find_in_paths(item, prefixes, frecent_paths)


def _find_in_paths(item, prefixes, frecent_paths):
    """Get the first of those paths which meets one of the criteria:

    1. has any substring that matches (as long as the item contains a "/")
    2. is same as item
    3. has same basename as item
    4. has same basename as "item*"
    5. has a parent with same basename as item
    6. has a parent with same basename as "item*"

    paths are assumed to be ordered, so first matching path wins
    """
    # pylint: disable=too-many-branches
    def double_globbed(p):
        return fnmatch(p, '*%s*' % item)

    def globbed(p):
        return fnmatch(p, '%s*' % item)

    def glob_match(path):
        for p in path.split(os.path.sep):
            if globbed(p):
                return True
        return False

    matchers = [
        lambda path: item == path,
        lambda path: item == path.basename(),
        lambda path: globbed(path.basename()),
        lambda path: item in path.split(os.path.sep),
        #  (lambda *is* necessary (to stop E0601 using path before assignment))
        #  pylint: disable=unnecessary-lambda
        lambda path: glob_match(path),
        lambda path: double_globbed(path.basename()),
    ]
    if os.path.sep in item:
        matchers.insert(0, lambda path: item in path)
    i = take_first_integer(prefixes)
    for match in matchers:
        matched = [path for path in frecent_paths if match(path)]
        if not matched:
            continue
        if len(matched) == 1:
            if i:
                raise RangeError(i, matched)
            return find_under_directory(matched[0], prefixes)
        if i is not None:
            try:
                result = matched[i]
            except IndexError:
                raise RangeError(i, matched)
            return find_under_directory(result, prefixes)
        elif len(matched) > 1:
            found = [find_under_directory(m, prefixes) for m in matched]
            found = [f for f in found if f]
            unique = set(found)
            if len(unique) == 1:
                return unique.pop()
            return too_many_possibles(found)
        raise TryAgain('Too many possiblities\n\t%s' % as_menu_string(matched))


def show_path_to_historical_item(item, prefixes):
    """Get a path for the given item from history and show it"""
    path_to_item = find_in_history(item, prefixes)
    show_found_item(path_to_item)


def delete_path_to_historical_item(item, prefixes):
    """Get a path for the given item from history and remove it from history"""
    path_to_item = find_in_history(item, prefixes)
    delete_found_item(path_to_item)


def show_path_to_item(item, prefixes):
    """Get a path for the given item and show it

    >>> _ = show_path_to_item('/', ['us', 'lo'])
    /usr/local
    """
    path_to_item = find_directory(item, prefixes)
    return show_found_item(path_to_item)


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


def kd(string):

    def chdir_found_item(path_to_item):
        os.chdir(path_to_item)

    global show_found_item  # pylint: disable=global-variable-undefined
    show_found_item = chdir_found_item
    sys.argv = [__file__] + string.split()
    main()


def show_paths():
    """Show all paths in history in user-terminology"""
    old_rank = None
    for order, (rank, p, atime) in enumerate(frecent_history()):
        if old_rank != rank:
            print('      %s time%s:' % (rank, int(rank) > 1 and 's' or ''))
            old_rank = rank
        print('%3d: %s, %s ago' % (order + 1, p, timings.time_since(atime)))


def old(args):
    if args.directory:
        show_path_to_historical_item(args.directory, args.prefixes)
    else:
        show_paths()


def delete(args):
    if args.directory:
        delete_path_to_historical_item(args.directory, args.prefixes)
    else:
        show_paths()


def main():
    """Show a directory from the command line arguments (or some derivative)"""
    # pylint: disable=too-many-branches
    # Of course there are too many branches - it's an event dispatcher
    try:
        args = parse_args(globals())
        status = show_path_to_item(args.directory, args.prefixes)
        return os.EX_OK if status else not os.EX_OK
    except (bdb.BdbQuit, SystemExit):
        return os.EX_OK
    except AttributeError as e:
        go_away = 'attribute \'path\'" in <function _remove'
        if go_away not in str(e):
            raise
    except TryAgain, e:
        print('Try again:', e)
        return not os.EX_OK
    except ToDo, e:
        print('Error:', e)
        return not os.EX_OK


if __name__ == '__main__':
    sys.exit(main())
