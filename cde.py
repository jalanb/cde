#! /usr/local/bin/python

"""cde.py knows where you are going because it knows where you've been"""


from __future__ import print_function
import os
import bdb
import sys
from fnmatch import fnmatch
import argparse
import csv


import timings


from pysyte import paths

__version__ = '0.7.1'


class ToDo(NotImplementedError):
    """Errors raised by this script"""
    pass


class TryAgain(ValueError):
    """Warnings raised by this script"""
    pass


class RangeError(ToDo):
    def __init__(self, i, matched):
        ToDo.__init__(
            self,
            f'Your choice of {i} is out of range:\n\t%s' %
            as_menu_string(matched))


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
    prefix_glob = prefix.endswith('/') and prefix.rstrip('/') or f'{prefix}*'
    sub_directories = paths.list_sub_directories(
        path_to_directory, prefix_glob)

    if len(sub_directories) < 2:
        return sub_directories
    exacts = [_ for _ in sub_directories if _.basename() == prefix]
    if exacts:
        return exacts
    return sub_directories


def as_menu_items(strings):
    return [f'{i:2} {p}' for i, p in enumerate(strings)]


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


def look_under_directory(path_to_directory, subdirnames):
    """Look under the given directory for matching sub-directories

    Sub-directories match if they are prefixed with given subdirnames
    If no sub-directories match, but a file matches
        then use the directory
    """
    if not subdirnames:
        return [path_to_directory]
    prefix, subdirnames = subdirnames[0], subdirnames[1:]
    result = []
    matched_sub_directories = matching_sub_directories(
        path_to_directory, prefix)
    path_to_sub_directory = path_to_directory / prefix
    if not matched_sub_directories:
        if paths.contains_file(path_to_directory, f'{prefix}*'):
            return [path_to_directory]
        if path_to_sub_directory.isdir():
            return [path_to_sub_directory]
        return []
    i = first_integer(subdirnames)
    for path_to_sub_directory in matched_sub_directories:
        paths_under = look_under_directory(path_to_sub_directory, subdirnames)
        result.extend(paths_under)
    if not result:
        if i is not None:
            try:
                return [matched_sub_directories[i]]
            except IndexError:
                raise ToDo(f'Your choice of {i} is not in range:\n\t%s' % (
                    as_menu_string(matched_sub_directories)))
        if paths.contains_file(path_to_directory, f'{prefix}*'):
            result = [path_to_directory]
    return result


def find_under_directory(path_to_directory, subdirnames):
    """Find one directory under path_to_directory, matching subdirnames

    Try any prefixed sub-directories
        then any prefixed files

    Can give None (no matches), or the match, or an Exception
    """
    possibles = look_under_directory(path_to_directory, subdirnames)
    if not possibles:
        return None
    if len(possibles) == 1:
        return possibles[0]
    return too_many_possibles(possibles)


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
            setup = possible / 'setup.py'
            if setup.isfile():
                return possible
    eggless = {paths.path(p.replace('.egg-info', '')) for p in possibles}
    if len(eggless) == 1:
        return eggless.pop()
    return None


def too_many_possibles(possibles):
    possibles = [_ for _ in possibles if _.exists()]
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


def find_under_here(subdirnames):
    """Look for some other directories under current directory """
    try:
        return find_under_directory(paths.here(), subdirnames)
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


def find_at_home(item, subdirnames):
    """Return the first directory under the home directory matching the item

    Match on sub-directories first, then files
        Might return home directory itself

    >>> print(find_at_home('bin', []))
    /.../bin
    """
    if item in subdirnames:
        return find_under_directory(paths.home(), subdirnames)
    return find_under_directory(paths.home(), [item] + subdirnames)


def find_path_to_item(item):
    """Find the path to the given item

    Either the directory itself, or directory of the file itself, or nothing
    """
    def user_says_its_a_directory(p):
        return p[-1] == '/'

    if user_says_its_a_directory(item):
        if item[0] == '/':
            return paths.path(item)
        return item.rstrip('/')
    path_to_item = paths.path(item)
    if path_to_item.isdir():
        return path_to_item
    parent = path_to_item.dirname()
    if path_to_item.isfile():
        return parent
    elif os.path.islink(item):
        parent = os.path.dirname(item)
        if os.path.isdir(parent):
            return paths.makepath(parent)
    pattern = f'{path_to_item.basename()}*'
    if paths.contains_directory(parent, pattern):
        found = parent.dirs(pattern)
        ordered = sorted(found, key=lambda x: len(x), reverse=True)
        return ordered.pop()
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
    try:
        path_to_item = find_path_to_item(item)
    except FoundParent:
        path_to_item = None
    if path_to_item:
        if not subdirnames:
            return path_to_item
        path_to_prefix = find_under_directory(path_to_item, subdirnames)
        if path_to_prefix:
            return path_to_prefix
    else:
        if item:
            args = [item] + subdirnames
        else:
            args = subdirnames
        if args:
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
    raise ToDo('could not use %r as a directory' % ' '.join([item] + subdirnames))


def run_args(args, methods):
    """Run any methods eponymous with args"""
    if not args:
        return False
    valuable_args = {k for k, v in args.__dict__.items() if v}
    arg_methods = {methods[_] for _ in valuable_args if _ in methods}
    for method in arg_methods:
        method(args)


def version(_args):
    """Show version of the script"""
    print(f'{sys.argv[0]} {__version__}')
    raise SystemExit(os.EX_OK)


def unused(args):
    used = ['-u', '--unused', args.dirname] + args.subdirnames
    unused_args = [_ for _ in sys.argv[1:] if _ not in used]
    print(' '.join(unused_args))
    raise SystemExit(os.EX_OK)


def parse_args():
    return parse_my_args(globals())


def parse_my_args(methods):
    """Get the arguments from the command line.

    Insist on at least one empty string"""
    usage = '%(prog)s [dirname [subdirname ...]'
    parser = argparse.ArgumentParser(description=__doc__, usage=usage)
    pa = parser.add_argument
    pa('-0', '--first', action='store_true', help='Only show first path')
    pa('-1', '--second', action='store_true', help='Only show second path')
    pa('-2', '--third', action='store_true', help='Only show third path')
    pa('-a', '--add', action='store_true', help='add a path to history')
    pa('-d', '--delete', action='store_true', help='delete a path from history')  # noqa
    pa('-l', '--lost', action='store_true', help='show all non-existent paths in history')  # noqa
    pa('-m', '--makedir', action='store_true', help='Make sure the given directory exists')  # noqa
    pa('-o', '--old', action='store_true', help='look for paths in history')
    pa('-p', '--purge', action='store_true', help='remove all non-existent paths from history')  # noqa
    pa('-t', '--test', action='store_true', help='test the script')
    pa('-u', '--unused', action='store_true', help='show unused args')  # noqa
    pa('-v', '--version', action='store_true', help='show version of the script')  # noqa
    pa('dirname', metavar='item', nargs='?', default='', help='(partial) directory name')  # noqa
    pa('subdirnames', nargs='*', help='(partial) sub directory names')
    args = parser.parse_args()
    args.index = None
    args.index = None
    if args.first:
        args.index = 0
    if args.second:
        args.index = 1
    if args.third:
        args.index = 2
    run_args(args, methods)
    args.dirname = set_args_directory(args)
    return args


def set_args_directory(args):
    if not args.dirname:
        args.subdirnames = []
        if args.add:
            return '.'
        if not args.old:
            return paths.home()
    if args.dirname == '-':
        return previous_directory()
    return args.dirname


def test(_args):
    """Run all doctests based on this file

    Tell any bash-runners not to use any output by saying "Error" first

    >>> assert 'cde.py' in __file__
    """
    stem = paths.path(__file__).namebase
    from doctest import testfile, testmod, ELLIPSIS, NORMALIZE_WHITESPACE
    options = ELLIPSIS | NORMALIZE_WHITESPACE
    failed, _ = testfile(f'{stem}.tests', optionflags=options)
    if failed:
        return
    failed, _ = testfile(f'{stem}.test', optionflags=options)
    if failed:
        return
    failed, _ = testmod(optionflags=options)
    if failed:
        return
    print('All tests passed')


def _path_to_config():
    """Path where our config files are kept"""
    stem = paths.path(__file__).namebase
    config = paths.home() / f'.config/{stem}'
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
    with open(path, 'r') as stream:
        reader = csv.reader(
            stream, delimiter=',', quotechar='"', quoting=csv.QUOTE_MINIMAL)
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


def add(args):
    """Remember the given path for later use"""
    try:
        path_to_dirname = paths.path(args.dirname)
    except OSError as e:
        raise SystemExit(str(e))
    add_path(path_to_dirname)


def add_path(path_to_add):
    path_to_add = find_path_to_item(path_to_add)
    history_items = read_history()
    items = include_new_path_in_items(history_items, path_to_add)
    write_paths(items)


def write_paths(paths_to_remember):
    """Write the given paths to the history file"""
    with open(_path_to_history(), 'w') as stream:
        writer = csv.writer(stream, delimiter=',', quotechar='"',
                            quoting=csv.QUOTE_MINIMAL)
        writer.writerows(paths_to_remember)


def makedir(args):
    """Make the directory in the args unless it exists"""
    path_to_dirname = paths.path(args.dirname)
    if path_to_dirname.isdir():
        return True
    return path_to_dirname.make_directory_exist()


def lost(_args=None):
    history_items = read_history()
    for _rank, path, _time in history_items:
        if not os.path.exists(path):
            print(path)
    raise SystemExit(os.EX_OK)


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
    frecent_paths = frecent_history_paths()
    try:
        return frecent_paths[int(item) - 1]
    except ValueError:
        return _find_in_paths(item, subdirnames, frecent_paths)


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
    # pylint: disable=too-many-branches
    def double_globbed(p):
        return fnmatch(p, f'*{item}*')

    def globbed(p):
        return fnmatch(p, f'{item}*')

    def glob_match(path):
        for p in path.split(os.path.sep):
            if globbed(p):
                return True
        return False

    matchers = [
        lambda p: item == p,
        lambda p: item == p.basename(),
        lambda p: globbed(p.basename()),
        lambda p: item in p.split(os.path.sep),
        #  pylint: disable=unnecessary-lambda
        #  (lambda *is* necessary (stops E0601: "using path before assign..."))
        lambda p: glob_match(p),
        lambda p: double_globbed(p.basename()),
    ]
    if os.path.sep in item:
        matchers.insert(0, lambda p: item in p)
    i = take_first_integer(subdirnames)
    for match in matchers:
        matched = [_ for _ in frecent_paths if match(_)]
        if not matched:
            continue
        if len(matched) == 1:
            if i:
                raise RangeError(i, matched)
            return find_under_directory(matched[0], subdirnames)
        if i is not None:
            try:
                result = matched[i]
            except IndexError:
                raise RangeError(i, matched)
            return find_under_directory(result, subdirnames)
        elif len(matched) > 1:
            found = [find_under_directory(_, subdirnames) for _ in matched]
            found = [_ for _ in found if _]
            unique = set(found)
            if len(unique) == 1:
                return unique.pop()
            return too_many_possibles(found)
        raise TryAgain('Too many possiblities\n\t%s' % as_menu_string(matched))


def show_path_to_historical_item(item, subdirnames):
    """Get a path for the given item from history and show it"""
    path_to_item = find_in_history(item, subdirnames)
    show_found_item(path_to_item)


def delete_path_to_historical_item(item, subdirnames):
    """Get a path for the given item from history and remove it from history"""
    path_to_item = find_in_history(item, subdirnames)
    delete_found_item(path_to_item)


def show_path_to_item(item, subdirnames):
    """Get a path for the given item and show it

    >>> _ = show_path_to_item('/', ['us', 'lo'])
    /usr/local
    """
    path_to_item = find_directory(item, subdirnames)
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


def cd(string):

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
    if args.dirname:
        show_path_to_historical_item(args.dirname, args.subdirnames)
    else:
        show_paths()
    raise SystemExit(os.EX_OK)


def delete(args):
    if args.dirname:
        delete_path_to_historical_item(args.dirname, args.subdirnames)
    else:
        show_paths()


def main():
    """Show a directory from the command line arguments (or some derivative)"""
    # pylint: disable=too-many-branches
    # Of course there are too many branches - it's an event dispatcher
    not_EX_OK = 1
    try:
        args = parse_args()
        if args.unused:
            pass
        status = show_path_to_item(args.dirname, args.subdirnames)
        return os.EX_OK if status else not_EX_OK
    except (bdb.BdbQuit, SystemExit):
        return os.EX_OK
    except AttributeError as e:
        go_away = 'attribute \'path\'" in <function _remove'
        if go_away not in str(e):
            raise
    except TryAgain as e:
        if args.index is not None:
            separator = '%d:' % args.index
            seperable = [l for l in str(e).splitlines() if separator in l]
            lines = [s.split(separator)[-1].strip() for s in seperable]
            if lines:
                print(lines[0])
                return os.EX_OK
        print('Try again:', e)
        return not_EX_OK
    except ToDo as e:
        print('Error:', e)
        return not_EX_OK


if __name__ == '__main__':
    sys.exit(main())
