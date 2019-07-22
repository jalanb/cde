#! /bin/cat

[[ -n $WELCOME_BYE ]] && echo Welcome to $(basename "$BASH_SOURCE") in $(dirname $(readlink -f "$BASH_SOURCE")) on $(hostname -f)

# This script is intended to be sourced, not run
if [[ $0 == $BASH_SOURCE ]]
then
    echo "This file should be run as"
    echo "  source $0"
    echo "and should not be run as"
    echo "  sh $0"
fi

CD_PATH_ONLY=0
export CDE_SOURCE=$(basename $BASH_SOURCE)

# x
# _
# xx

alias cc='c .'
alias cq="cde -q"

# _x
# xxx


cdd () {
    local __doc__"""cde here"""
    cde .
}

ind () {
    local _destination=$(py_cp "$1")
    [[ -d "$_destination" ]] || return 1
    (
        cde -q "$_destination"
        shift 
        "$@"
    )
}

# rule 1: Leave system commands alone
# So this uses the next key up from "cd"

cde () {
    local __doc__="""find a dir and handle it"""
    [[ $1 =~ -h ]] && cde_help && return 0
    local _say_quiet=
    if [[ $1 =~ -q ]]; then
        _say_quiet=quiet
        shift
    fi
    cdpy_pre_
    cdpy quiet "$@" || return 1
    [[ -d . ]] || return 1
    cdpy_post_ $_say_quiet
}

cdl () {
    local __doc__="""cde $1; ls -1"""
    local _dir="$@"
    [[ $_dir ]] || _dir=.
    cde $_dir
    shift
    local _ls_options="$@"
    [[ $_ls_options ]] || _ls_options=" -1 "
    green_line $PWD
    ls --color $_ls_options
}

cdr () {
    cde "$@"
    green_line $PWD
}

cdv () {
    cde "$@"
    local _dir=
    [[ "$@" ]] || _dir=$PWD
    local _files=
    _files=$(basename "$@")
    [[ $_files ]] || _files=$_dir
    [[ $_files ]] || _files=$(ls -1a)
    $EDITOR $_files
}

cdpy () {
    local __doc__="""Ask cde.py for a destination"""
    local _stdout=1
    if [[ $1 =~ quiet ]]; then
        _stdout=
        shift
    fi
    local _cde_dir=$(dirname $(readlink -f $BASH_SOURCE))
    local _cde_python=$_cde_dir/cde.py
    local _cde_options=
    [[ $CD_PATH_ONLY == 1 ]] && _cde_options=--first
    local _python=$(which python 2>/dev/null)
    [[ -z $_python ]] && _python=$(PATH=~/bin:/usr/local/bin:/bin which python)
    # set +x
    local _headline=$(head -n 1 $_cde_python)
    [[ $_headline =~ python ]] && _python=
    local _python_command="$_python $_cde_python $_cde_options"
    local _cde_result=1
    if [[ -n $PUDB_CD ]]; then
        PYTHONPATH=$_cde_dir pudb $_cde_python $_cde_options "$@"
    elif ! destination=$(PYTHONPATH=$_cde_dir $_python_command "$@" 2>&1)
    then
        echo "$destination"
    elif [[ "$@" =~ ' -[lp]' ]]; then
        echo "$destination"
    elif [[ $destination =~ ^[uU]sage ]]; then
        PYTHONPATH=$_cde_dir $_python_command --help
    else
        local real_destination=$(python -c "import os; print(os.path.realpath('$destination'))")
        if [[ "$destination" != "$real_destination" ]]
        then
            echo "cd ($destination ->) $real_destination"
            destination="$real_destination"
        else
            while [[ $1 =~ ^- ]]; do
                shift
            done
            if [[ "$destination" != $(readlink -f "$1") ]]; then
                [[ -n $_stdout ]] && echo "cd $destination"
            fi
        fi
        if [[ $CD_PATH_ONLY == 1 ]]; then
            echo "$destination"
        else
            same_path . "$destination" || pushd "$destination" >/dev/null 2>&1
        fi
        _cde_result=0
    fi
    unset destination
    PUDB_CD=
    return $_cde_result
}

cls () {
    local __doc__="clean, clear, ls"
    clean
    clear
    if [[ -n "$@" ]]; then
        l "$@"
    else
        l .
        echo
    fi
}

cpp () {
    local __doc__="""Show where any args would cde to"""
    if [[ -n "$1" ]]; then
        py_cp "$@"
    else
        py_cp .
    fi | grep -v -- '->'
}

cdll () {
    local __doc__="""cde $1; ls -l"""
    local _dir="$@"
    [[ $_dir ]] || _dir=.
    cdl $_dir -lhtra 
}

mkc () {
    local _destination=$(py_cp "$1")
    [[ -d "$_destination" ]] || mkdir -p "$_destination"
    cde "$_destination"
}

# _xx
# xxxx

cdup () {
    local __doc__="""cde up a few levels, 'cdup' goes up 1 level, 'cdup 2' goes up 2"""
    local _level=1
    if [[ $1 =~ [1-9] ]]; then
        _level=$1
        shift
    fi
    local _dir=$(readlink -f ..)
    pushd >/dev/null 2>&1
    while true; do
        _level=$(( $_level - 1 ))
        [[ $_level -le 0 ]] && break
        cd ..
        _dir=$(readlink -f .)
    done
    popd >/dev/null 2>&1
    cde $_dir "$@"
}
alias ..=cdup
alias ...="cdup 2"
alias ....="cdup 3"
alias .....="cdup 4"
# xxxxx

cdupp () {
    local """cd up 2 levels"""
    cdup 2 "$@"
}

pycd () {
    # Adapted from https://news.ycombinator.com/item?id=18898898
    local __doc__="""cde to directory of a iven Python module"""
    cde $(python -c "import os.path, $1; print(os.path.dirname($1.__file__))");
}

py_cg () {
    local __doc__="Debug the cdpy function and script"
    PUDB_CD=1 cdpy "$@"
}

py_cp () {
    local __doc__="Show the path that cdpy would go to"
    CD_PATH_ONLY=1 cdpy quiet "$@"
    local _result=$?
    CD_PATH_ONLY=0
    return $_result
}
# xxxxxx

cde_ok () {
    local __doc__="""Whether cde would go to a directory"""
    [[ -z "$@" ]] && return 1
    [[ -d $(py_cp "$@") ]]
}

cduppp () {
    local """cd up ... etc, you get the idea"""
    cdup 3 "$@"
}
# xxxxxxx
# _xxxxxx

_active () {
    local __doc__="""Whether the $ACTIVATE script is in same dir as current python or virtualenv"""
    local _activate_dir=$(_dirnames $ACTIVATE)
    local _python_dir=$(_dirnames $(readlink -f $(command -v python)))
    same_path $_activate_dir $_python_dir && return 0
    local _venv_dir="$VIRTUAL_ENV/bin"
    same_path $_activate_dir $_venv_dir
}

cdpy_pre_ () {
    deactivate 2>/dev/null
    [[ -n $CDE_header ]] && echo $CDE_header
}
# xxxxxxxx

cde_help () {
    echo "cd to a dir and react to it"
    echo
    cdpy -h
    return 0
}
# _xxxxxxx

_here_cd () {
    local __doc__="""Look for .cd here and source it if found"""
    local _cde_here=./.cd
    [[ -f $_cde_here ]] || return 1
    grep -q activate $_cde_here && unhash_python
    . $_cde_here
    return 0
}

_here_ls () {
    ls 2> ~/bash/null
}

say_path () {
    local _said=$(python << EOP
# coding=utf8
import os, sys
path=os.path.expanduser(os.path.expandvars('$1'))
home='%s/' % os.path.expanduser('~')
if path.startswith(home):
    out=path.replace(home, 'home ')
elif path[0] == '/':
    out='root %s' % path[1:]
else:
    out=path
replacements = (
    ('/wwts', '/dub dub t s'),
    ('/䷃ ZatSo ?', '/is that so?'),
)
for old, new in replacements:
    out = out.replace(old, new)
sys.stdout.write(out.replace('/', ' '))
EOP
)
    type sai >/dev/null 2>&1 && sai "$_said"
}

cdpy_post_ () {
    local _path=$(short_dir $PWD)
    [[ $_path == "~" ]] && _path=HOME
    [[ $_path =~ "wwts" ]] && _path="${_path/wwts/dub dub t s}"
    [[ $1 =~ quiet ]] && shift || say_path $_path
    _here_show_todo && echo
    _here_bash && return 0
    _here_bin
    _here_git
    _here_python && _here_venv
    [[ -n $1 ]] &&
    _here_ls && _here_clean
}
# xxxxxxxxx

same_path () {
    [[ $(readlink -f "$1") == $(readlink -f "$2") ]]
}
# _xxxxxxxx

unhash_python () {
    hash -d python ipython pip pudb >/dev/null 2>&1
}

_activate () {
    # Thanks to @nxnev at https://unix.stackexchange.com/a/443256/32775
    unhash_python
    [[ -f $ACTIVATE ]] && . $ACTIVATE
}

_dirnames () {
    local __doc__="""show dirnames for all args that are paths"""
    local _result=1
    for _arg in "$@"; do
        [[ -e "$_arg" ]] || continue
        dirname "$_arg"
        _result=0
    done
    return $_result
}

_here_bin () {
    [[ -d ./bin ]] && add_to_a_path PATH ./bin
}

_here_git () {
    [[ -d ./.git ]] || return 0
    show_git_time . | head -n ${LOG_LINES_ON_CD_GIT_DIR:-7}
    local _branch=$(git rev-parse --abbrev-ref HEAD)
    echo $_branch
    git_simple_status .
    show_version_here
    gl11
    return 0
}

# _xxxxxxxxx

_here_venv () {
    local _active_venv="$VIRTUAL_ENV"
    local _active_bin="$_active_venv/bin"
    if [[ -e $_active_bin/ipython ]]; then
        alias ipy="$_active_bin/ipython"
    else
        unalias ipy >/dev/null
    fi > /dev/null 2>&1
    activate_python_here && return 0
    # set -x
    local _venvs=$HOME/.virtualenvs
    [[ -d $_venvs ]] || return 0
    local _here=$(realpath $(pwd))
    local _name="not_a_name"
    [[ -e $_here ]] && _name=$(basename $_here)
    local _venv_path=
    for _venv_path in $_venvs/*; do
        local _venv_dir="$_venv_path"
        [[ -d "$_venv_dir" ]] || continue
        local _venv_name=$(basename $_venv_dir)
        if [[ $_venv_name == $_name ]]; then
            local _venv_activate="$_venv_dir/bin/activate"
            [[ -f $_venv_activate ]] || return 1
            . $_venv_activate
            return 0
        fi
    done
    return 0
    # set +x
}

# _xxxxxxxxxx

_here_clean () {
    for path in $(find . -type f -name '*.sw*'); do
        ls -l $path 2> ~/bash/fd/2
        rri $path && continue
        [[ $? == 1 ]] && break
    done
}

# _xxxxxxxxxxx

_here_python () {
    any_python_scripts_here || return 0
    local _dir=$(realpath .)
    local _dir_name=$(basename $_dir)
    python_project_here $_dir_name || return 0
    prune_python_here
    activate_python_here
    local egg_info=${_dir_name}.egg-info
    if [[ -d $egg_info ]]; then
        ri $egg_info
    fi
    return 0
}

# _xxxxxxxxxxxxxx

_here_show_todo () {
    if [[ -f todo.txt ]]; then
        todo_show
        return 0
    fi
    return 1
}

# xxxxxxxxxxxxxxxxx

show_version_here () {
    local _config=./.bumpversion.cfg
    if [[ -f $_config ]]; then
        bump show
        return
    fi
}

# xxxxxxxxxxxxxxxxxxx

python_project_here () {
    local __doc__="""Recognise python project dir by presence of known files/dirs"""
    local _dirname="$1"
    [[ -f setup.py || -f requirements.txt || -f bin/activate || -d ./$_dir_name || -d .venv || -d .idea ]]
}

# xxxxxxxxxxxxxxxxxxxxxxx

activate_python_here () {
    find_activate_script || return 1
    _active || _activate
    PYTHON_VERSION=$(python --version 2>&1 | head -n 1 | cut -d' ' -f 2)
}

prune_python_here () {
    local _here=$(readlink -f .)
    local _home=$(readlink -f $HOME)
    [[ ${_here:0:${#_home}} == $_home ]] || return 1
    [[ ${#_here} == ${#_home} ]] && return 1
    rf -qpr
    return 0
}

any_python_scripts_here () {
    [[ $(find . -type f -name "*.py" -exec echo 1 \; -quit) == 1 ]]
}

find_activate_script () {
    local _activate_here=
    local _dirs="venv/bin .venv/bin bin ."
    local _top=$(git rev-parse --show-toplevel . 2>/dev/null | head -n 1)
    [[ -d $_top ]] && _dirs="$_dirs $_top/venv/bin $_top/.venv/bin $_top/bin $top"
    for _activate_bin in $_dirs; do
        local _activate=$_activate_bin/activate
        if [[ -f $_activate ]]; then
            . $_activate
            _activate_here="$(readlink -f $_activate)"
            break
        fi
    done
    [[ -f $_activate_here ]] && ACTIVATE="$_activate_here"
    export ACTIVATE
    [[ -f $ACTIVATE ]]
}

[[ -n $WELCOME_BYE ]] && echo Bye from $(basename "$BASH_SOURCE") in $(dirname $(readlink -f "$BASH_SOURCE")) on $(hostname -f)

