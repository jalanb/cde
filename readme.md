cde
===

`cde` is a shell function that uses `cd.py` (a more [python](https://github.com/jalanb/kd/blob/v0.5.0/cd.sh#L101)onic version of [Bash](https://github.com/jalanb/kd/blob/v0.5.0/cd.sh#L36)'s `cd` command) to find out how to get to a directory, but knows what to do once it gets there.

`cd.py` knows where you are going because it knows where you've been, and what directory structures looked like when you were there the last time.


Install
=======

This package does *not* change the `cd` command, and trys not to hurt your system in silly ways.

We cool?

OK, clone the repo, and source the bash functions
```shell
$ git clone https://github.com/jalanb/kd/kd.git
$ . kd/cd.sh
```

Add `. .../kd/cd.sh` to your `~/.bashrc`, or try the next repo.

Usage
=====

You just got a bash function called `cde()` which is intended as a drop-in replacement for the `cd` command.
```shell
cde -h
cd to a dir and react to it

cde [dirname [subdirname ...]]
```

(Examples will work depending on system layout, please allow reasonable defaults, and no history yet)

A dirname can abbreviate a path, e.g.
```shell
$ cd /
$ cde /u loc bi && pwd
/usr/local/bin
$ cd /
$ cd /usr/local && pwd
/usr/local
```

`cde` can be abbreviated to just `c`, e.g.
```
$ c .. && pwd
/usr
```

And sometimes can be abbreviated away entirely, e.g.
```shell
$ c /u l b && pwd
/usr/local/bin
$ ... && pwd
/usr
```

args
----

(If `c` doesn't understand args they get passed on to `cd`, so options like `-@` might still work.)

$ cd /usr/local/bin/..
$ pwd
/usr/local
$ cd bin; pwd
/usr/local/bin
$ cd -
$ c b; pwd
/usr/local/bin
```

The first argument to `c` is a `dirname`, further arguments are `subdirnames`. This makes it easier to leave out all those annoying "/"s, e.g.
```
$ cd /
$ c usr lo b; pwd
/usr/local/bin
```

Although full paths work too, e.g.
```shell
$ c /usr/local/bin; pwd
/usr/local/bin
```
If you give `c` a path to a file, it will go to the parent directory (very handy with "/path/to/file.txt" in the clipboard)
```shell
$ c /usr/local/bin/python; pwd
/usr/local/bin
```

First argument is a directory, subsequent arguments are prefixes of sub-directories. For example:

    $ [kd](https://github.com/jalanb/kd/blob/v0.5.0/cd.py#L698) /usr/local bi

is equivalent to

    $ cd /usr/local/bin

Or first argument is ([stem](https://github.com/jalanb/kd/blob/v0.5.0/cd.py#L624) of) a [directory](https://github.com/jalanb/kd/blob/v0.5.0/cd.py#L302) you have been to. For example, given that we have kd'd to it already, you can get back to /usr/local/bin (from anywhere else) by

    $ [kd](https://github.com/jalanb/kd/blob/v0.5.0/cd.py#L758) b

Or first argument is a file (cd'ing to a file can be very handy in conjuction with copy-and-paste of filenames), for example

    $ [kd](https://github.com/jalanb/kd/blob/v0.5.0/cd.py#L758) /bin/ls

is equivalent to

    $ cd /bin

Or the first argument is a stem of a directory/file. [kd](https://github.com/jalanb/kd/blob/v0.5.0/cd.py#L758).py [will add `*` on to such a stem](https://github.com/jalanb/kd/blob/v0.5.0/cd.py#L108), and cd [to whatever that matches](https://github.com/jalanb/kd/blob/v0.5.0/cd.sh#L30) (see below). For example, `/bin/l*` matches `/bin/ls`, which is an existing file, whose parent is `/bin`. This can be handy when tab-completion only finds part of a filename

    $ [kd](https://github.com/jalanb/kd/blob/v0.5.0/cd.py#L310) /bin/l

If nothing matches then it [tries directories in $PATH which have matching executables](https://github.com/jalanb/kd/blob/v0.5.0/cd.py#L261). For example, this will give `/bin`:

    $ [kd](https://github.com/jalanb/kd/blob/v0.5.0/cd.py#L261) ls

When looking for partial names kd will [look for each of these in turn](https://github.com/jalanb/kd/blob/v0.5.0/cd.py#L649), stopping as soon as it gets some match

1. directories with the same name
2. directories that start with the given part
3. files that start with the given part
4. directories with the part in their name
4. files with the part in their name


[![Stories in Ready](https://badge.waffle.io/jalanb/kd.png?label=ready)](http://waffle.io/jalanb/kd)
