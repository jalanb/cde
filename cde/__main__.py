#! /usr/bin/env python3
"""cde knows where you are going because it knows where you've been"""
import bdb

from pysyte.types import lists
from pysyte.types import paths
from pysyte.cli import arguments
from pysyte.cli.main import run

from cde import cde


def add_args(parser: arguments.ArgumentsParser):
    """Set the arguments, options for the command line.

    Insist on at least one empty string"""
    parser.positionals("dirnames", default=".", help="fuzzy directory names")

    parser.opt("0", "first", help="Only show first path")
    parser.opt("1", "second", help="Only show second path")
    parser.opt("2", "third", help="Only show third path")

    # From here argument names correspend to methods in the cde module
    parser.opt("a", "add", help="add a path to history")
    parser.opt("c", "complete", help="show all paths in history")
    parser.opt("d", "delete", help="delete a path from history")
    parser.opt("e", "existing", help="show all real paths in history")
    parser.opt("f", "filename", help="show filename of the script")
    parser.opt("l", "lost", help="show all unreal paths in history")
    parser.opt("m", "makedir", help="Ensure the given directory exists")
    parser.opt("o", "old", help="look for paths in history")
    parser.opt("p", "purge", help="remove all non-existent paths from history")
    parser.opt("q", "quietly", help="do not write to stderr")
    #   parser.opt(" ", "Quietly", help="do not write to stdout")
    parser.opt("Q", "QUIETLY", help="do not write to stdout, nor stderr")
    parser.opt("t", "test", help="test the script")
    parser.opt("u", "unused", help="show unused args")
    parser.opt("v", "version", help="show version of the script")
    return parser


def run_args(args, dirnames_):
    """Run any methods in cde module that are eponymous with args"""
    if not args:
        return False
    args_ = args.get_args()
    valued_args = {k for k, v in args_.items() if v}
    cde_args = {getattr(cde, _, None) for _ in dir(cde) if _ in valued_args}
    cde_methods = {a for a in cde_args if callable(a)}
    for method in cde_methods:
        method(args)


def dirnames(names):
    result = {"~": paths.home()}
    for dirname in names:
        if dirname == "-":
            dirname = previous()
        path = paths.path(dirname)
        if path.isdir():
            result[dirname] = path
    return result


def post_parse(args):
    digits = lambda x: x.isdigit()
    numbers, names = lists.splits(digits, args.dirnames)
    if numbers:
        args.index = min(numbers)
    if getattr(args, "third", False):
        args.index = 2
    if getattr(args, "second", False):
        args.index = 1
    if getattr(args, "first", False):
        args.index = 0

    dirnames_ = dirnames(names)
    if dirnames_:
        run_args(args, dirnames_)
    elif args.old:
        return paths.home()
    return args


def main(args):
    """Show a directory from the command line arguments (or some derivative)"""
    try:
        if args.unused:
            pass
        dir_, *sub_dirs = args.dirnames
        return cde.cde(dir_, sub_dirs)
    except bdb.BdbQuit:
        return True
    except SystemExit as e:
        return e.code
    except AttributeError as e:
        go_away = "attribute 'path'\" in <function _remove"
        if go_away not in str(e):
            raise
    except cde.TryAgain as e:
        if any([p.isfile() for p in e.possibles]):
            raise
        if args.index is not None:
            try:
                one = e.possibles[args.index]
                cde.stdout(one)
                return True
            except IndexError:
                pass
        cde.stderr("Try again:", e)
        return False
    except cde.ToDo as e:
        cde.stderr("Error:", e)
        return False


run(main, add_args, post_parse, usage="%(prog)s [dirname [subdirname ...]")
