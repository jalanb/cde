kd
==

kd is intended to make cd'ing easier

The script gets a close match to a directory from command line arguments then prints that to stdout which allows a usage in bash like

    $ cd $(python kd.py /usr local bin)
    $ cd $(python kd.py /bin/ls)

Setup
-----

For convenience a bash function is also provided, which can be set up like

    $ source kd.sh

Then one can use "kd" as a replacement for cd

    $ cd /usr/local/lib/python2.7/site-packages
    $ kd /usr lo li py si

Use
---

First argument is a directory, subsequent arguments are prefixes of sub-directories. For example:

    $ kd /usr/local bi
    /usr/local/bi

Or first argument is a file

    $ kd /bin/ls
    /bin

Or first argument is a stem of a directory/file. kd.py will add `*` on to such a stem, and will always find directories first, looking for files only if there are no such directories. In this example, kd looks for `/bin/l*`, and finds `/bin/ls`, which is a file, so the directory is again `/bin`

    $ kd /bin/l
    /bin

If nothing matches then give directories in $PATH which have matching executables

    $ kd ls
    /bin

When looking for partial names kd will look for each of these in turn, stopping as soon as it gets some match

1. directories with the same name
2. directories that start with the given part
3. files that start with the given part
4. directories with the part in their name
4. files with the part in their name
