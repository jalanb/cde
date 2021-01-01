cde
===

`cde` is a shell function that needs a `cde.py` to find out how to get to a directory, but knows what to do once it gets there.

`cde.py` knows where you are going because it knows where you've been, and what directory structures look like.

Naming
------

In an older version of this project the shell function was called `kd`.

`cde` could be an acronym for "cd evolved/extra/egg salad/extended", but really it's just easier than `kd` on a `qwerty` keyboard.

Install
=======

This package does *not* change the `cd` command, and trys not to hurt your system in silly ways.

We cool?

OK, clone the repo, and source the bash functions:
```shell
$ git clone https://github.com/jalanb/cde/cde.git
$ . cde/cde.sh
```

And add similar to your `bashrc` if needed.

Usage
=====

You just added a bash function called `cde` which is intended as a drop-in replacement for the `cd` command.
```shell
$ cde -h
cd to a dir and react to it

cde [dirname [subdirname ...]]

$ cde /usr/local/bin; pwd
/usr/local/bin
```

(Examples will work depending on system layout, please allow reasonable defaults, and no history yet)

A dirname can abbreviate a path, e.g.
```shell
$ cd /; cd /usr/local/bin; pwd
/usr/local/bin
$ cd /; cde /u loc bi; pwd
/usr/local/bin
```

`cde` can be [abbreviated](https://github.com/jalanb/cde/blob/v0.7.27/cde.sh#L19) to just `c`, e.g.
```shell
$ c ..; pwd
/usr/local
```

And sometimes can be [abbreviated](https://github.com/jalanb/cde/blob/v0.7.27/cde.sh#L90) away entirely, e.g.
```shell
$ c /u l b; pwd
/usr/local/bin
$ ...; pwd
/usr
```

args
----

The first argument to `c` is a `dirname`, further arguments are `subdirnames`. This makes it easier to leave out all those annoying "/"s, e.g.
```shell
$ cd /usr/local/bin; pwd
/usr/local/bin
$ c /usr local bin; pwd
/usr/local/bin
```

A full path to a directory works as a `dirname`
```shell
$ c /usr/local/bin; pwd
/usr/local/bin
```

A full path to a file can also be a dirname `dirname` (`c` will use the parent directory).
```shell
$ c /usr/local/bin/python; pwd
/usr/local/bin
```

A globbed path to a file or directory can also be a `dirname` (`c` will take the first match). For example, `/bin/l*` matches `/bin/ls`, which is an existing file, whose parent is `/bin`, so
```shell
$ c /bin/l*; pwd
/bin
```

A "dirname" can be a short name for a directory, and a "subdirname" can be a prefix for a sub-directory. Names can be shortened as much as you like while keeping them unique

```shell
$ cd /usr/local/bin; pwd
/usr/local/bin
$ c /u lo b; pwd
/usr/local/bin
```

If you abbreviate too much, `c` will refuse to guess, unless told to
```shell
$ c /u l
Try again: Too many possiblities
	 0: /usr/lib
	 1: /usr/libexec
	 2: /usr/local
$ c -1 /u l; pwd
/usr/lbexec
```

History
-------

`c` keeps a history of everywhere it has been to, and so a `dirname` can just use the old directory's name (not path). For example, given that we have `cde`'d to it already, we can get back to /usr/local/bin (from anywhere else) by simply
```shell
$ c b
```

If nothing matches then `c` [tries directories in $PATH which have matching executables](https://github.com/jalanb/cde/blob/v0.7.27/cde.py#L261). For example, this will give `/bin`:

```shell
$ c python; pwd
/usr/local/bin
```

Biases
------

When looking for partial names `c` will [look for each of these in turn](https://github.com/jalanb/cde/blob/v0.7.27/cde.py#L649), stopping as soon as it gets some match

1. directories with the same name
2. directories that start with the given part
3. files that start with the given part
4. directories with the part in their name
5. files with the part in their name

