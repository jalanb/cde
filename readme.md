kd
==

kd is a [Python](https://github.com/jalanb/kd/blob/master/kd.py#L758)ised version of [Bash(https://github.com/jalanb/kd/blob/master/kd.sh#L12)'s cd command.

It knows where you are going because it knows where you've been.

The script gets a close match to a directory from command line arguments then prints that to stdout which allows a usage in at the shell like

    $ cd $(python kd.py /usr local bin)
    $ cd $(python kd.py /bin/ls)

Setup
-----

For convenience a bash function is also provided, which can be set up like

    $ git clone https://github.com/jalanb/kd
    $ source [kd/kd.sh](https://github.com/jalanb/kd/blob/master/kd.sh)

Then one can use `kd` as a replacement for cd

    $ cd /usr/local/lib/python2.7/site-packages
    $ [kd](https://github.com/jalanb/kd/blob/master/kd.py#L3) /usr lo li py si

Use
---

First argument is a directory, subsequent arguments are prefixes of sub-directories. For example:

    $ [kd](https://github.com/jalanb/kd/blob/master/kd.py#L698) /usr/local bi

is equivalent to

    $ cd /usr/local/bin

Or first argument is ([stem](https://github.com/jalanb/kd/blob/master/kd.py#L624) of) a [directory](https://github.com/jalanb/kd/blob/master/kd.py#L302) you have been to. For example, given that we have kd'd to it already, you can get back to /usr/local/bin (from anywhere else) by

    $ [kd](https://github.com/jalanb/kd/blob/master/kd.py#L758) b

Or first argument is a file (cd'ing to a file can be very handy in conjuction with copy-and-paste of filenames), for example

    $ [kd](https://github.com/jalanb/kd/blob/master/kd.py#L758) /bin/ls
    
is equivalent to

	$ cd /bin

Or the first argument is a stem of a directory/file. [kd](https://github.com/jalanb/kd/blob/master/kd.py#L758).py [will add `*` on to such a stem](https://github.com/jalanb/kd/blob/master/kd.py#L108), and cd [to whatever that matches](https://github.com/jalanb/kd/blob/master/kd.sh#L30) (see below). For example, `/bin/l*` matches `/bin/ls`, which is an existing file, whose parent is `/bin`. This can be handy when tab-completion only finds part of a filename

    $ [kd](https://github.com/jalanb/kd/blob/master/kd.py#L310) /bin/l

If nothing matches then it [tries directories in $PATH which have matching executables](https://github.com/jalanb/kd/blob/master/kd.py#L261). For example, this will give `/bin`:

    $ [kd](https://github.com/jalanb/kd/blob/master/kd.py#L261) ls

When looking for partial names kd will [look for each of these in turn](https://github.com/jalanb/kd/blob/master/kd.py#L649), stopping as soon as it gets some match

1. directories with the same name
2. directories that start with the given part
3. files that start with the given part
4. directories with the part in their name
4. files with the part in their name


[![Stories in Ready](https://badge.waffle.io/jalanb/kd.png?label=ready)](http://waffle.io/jalanb/kd) 
