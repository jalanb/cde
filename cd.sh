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

c () {
    local __doc__="""https://old.reddit.com/r/linux/comments/2k1qz5/post_something_that_makes_your_linux_life_easier/clhjky9/?context=1"""
    cde "$@"
}

# _
# xx
# _x
# xxx

cdd () {
    local __doc__"""call cde() here"""
    cde .
}

# rule 1: Always leave system commands alone
# So this is called "cde", not "cd"

cde () {
    local __doc__="""cd to a dir and react to it"""
    [[ $1 == "-h" ]] && cde_help && return 0
    _pre_cd
    CD_QUIET=1 py_cd "$@" || return 1
    [[ -d . ]] || return 1
    _post_cd
}

cdl () {
    local __doc__="""cde and ls"""
    cde "$@"
    ls
}

cls () {
    local __doc__="clean, clear, ls"
    clean
    clear
    if [[ -n "$@" ]]; then
        ls "$@"
    else
        ls .
        echo
    fi
}

cpp () {
    local __doc__="""Show where any args would cde to"""
    if [[ -n "$1" ]]; then
        py_pp "$@"
    else
        py_pp .
    fi | grep -v -- '->'
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
    while true; do
        _level=$( $level - 1 )
        [[ $_level -le 0 ]] && break
        cd ..
    done
    cde .. "$@"
}
alias ..=cdup
alias ...="cdup 2"
alias ....="cdup 3"
# xxxxx

cdupp () {
    local """cd up 2 levels"""
    cdup 2 "$@"
}

py_cd () {
    local __doc__="""Ask cd.py for a destination"""
    local _debug=
    [[ $1 == "-U" ]] && _debug=1
    [[ $_debug == 1 ]] && set -x
    local _cd_dir=$(dirname $(readlink -f $BASH_SOURCE))
    local _cd_script=$_cd_dir/cd.py
    local _cd_result=1
    local _cd_options=
    [[ $CD_PATH_ONLY == 1 ]] && _cd_options=--one
    local _python=$(head -n 1 $_cd_script | cut -d' ' -f3)
    local _interpreter=$_python
    [[ $_debug == 1 ]] && _interpreter=pudb
    if ! destination=$(PYTHONPATH=$_cd_dir $_interpreter $_cd_script $_cd_options "$@" 2>&1)
    then
        echo "$destination"
    elif [[ "$@" =~ -[lp] ]]; then
        echo "$destination"
    elif [[ $destination =~ ^[uU]sage ]]; then
        PYTHONPATH=$_cd_dir $_python $_cd_script "$@"
    else
        local real_destination=$(PYTHONPATH=$_cd_dir $_python -c "import os; print(os.path.realpath('$destination'))")
        if [[ "$destination" != "$real_destination" ]]
        then
            echo "cd ($destination ->) $real_destination"
            destination="$real_destination"
        else
            [[ $1 =~ '--' ]] && shift
            if [[ "$destination" != $(readlink -f "$1") && $1 != "-" ]]
            then
                [[ -n $CD_QUIET ]] || echo "cd $destination"
            fi
        fi
        if [[ $CD_PATH_ONLY == 1 ]]; then
            echo "$destination"
        else
            same_path . "$destination" || pushd "$destination" >/dev/null 2>&1
        fi
        _cd_result=0
    fi
    unset destination
    [[ $_debug == 1 ]] && set +x
    return $_cd_result
}

py_cg () {
    local __doc__="Debug the py_cd function and script"
    py_cd -U "$@"
}

py_pp () {
    local __doc__="Show the path that py_cd would go to"
    CD_QUIET=1 CD_PATH_ONLY=1 py_cd "$@";
    local _result=$?
    CD_PATH_ONLY=0
    return $_result
}
# xxxxxx

cduppp () {
    local """cd up ... etc, you get the idea"""
    cdup 3 "$@"
}
# xxxxxxx
# _xxxxxx

_active () {
    local __doc__"""Whether the $ACTIVATE script is in same dir as current python or virtualenv"""
    local _activate_dir=$(dirname_ $ACTIVATE)
    local _python_dir=$(dirname_ $(readlink -f $(command -v python)))
    local _venv_dir="$VIRTUAL_ENV/bin"
    [[ $_activate_dir == $_python_dir ]] || [[ $_activate_dir == $_venv_dir ]]
}

_pre_cd () {
    [[ -z $CDE_header ]] && return
    echo $CDE_header
}
# xxxxxxxx

cde_help () {
    echo "cd to a dir and react to it"
    echo
    echo "cde [dirname [subdirname ...]]"
}
# _xxxxxxx
_here_ls () {
    ls 2> ~/bash/null
}

_post_cd () {
    local _path=$(~/jab/bin/short_dir $PWD)
    [[ $_path == "~" ]] && _path=HOME
    [[ $_path =~ "wwts" ]] && _path="${_path/wwts/dub dub t s}"
    # set -x
    # echo $_path
    local _tildless=${_path/~/home} # ; echo t $_tildless
    local _homele=$(echo $_tildless | sed -e "s:$HOME:home:")
    local _homeles=${_homele/home\//} # ; echo 1 $_homeles
    local _homeless=${_homeles/home/} # ; echo 2 $_homeless
    local _rootless=$(echo $_homeless | sed -e "s:^/:root :" )
    local _said=$(echo $_rootless | sed -e "s:/: :g")
    sai $_said
    # echo "said $_said"
    # set +x
    _here_show_todo && echo
    # set -x
    _here_bash
    _here_bin
    _here_git
    # set -x
    _here_python && _here_venv
    # set +x
    [[ -n $1 ]] &&
    _here_ls && _here_clean
    # set +x
}
# xxxxxxxxx

same_path () {
    [[ $(readlink -f "$1") == $(readlink -f "$2") ]]
}
# _xxxxxxxx

_activate () {
    # Thanks to @nxnev at https://unix.stackexchange.com/a/443256/32775
    hash -d python ipython pip pudb >/dev/null 2>&1
    . $ACTIVATE
}

_here_bin () {
    [[ -d ./bin ]] && add_to_a_path PATH ./bin
}

_here_git () {
    [[ -d ./.git ]] || return 0
    show_git_time . | head -n $LOG_LINES_ON_CD_GIT_DIR
    local _branch=$(git rev-parse --abbrev-ref HEAD)
    echo $_branch
    git_simple_status .
    show_version_here
    gl11
    return 0
}

# _xxxxxxxxx

_here_bash () {
    local __doc__="""LOok for __init__.sh here or below and source it if found"""
    local _init=./__init__.sh
    [[ -f $_init ]] || _init=bash/__init__.sh
    [[ -f $_init ]] || _init=src/bash/__init__.sh
    [[ -f $_init ]] && . $_init
    return 0
}

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
    [[ -e $_here ]] && _name=$(basename_ $_here)
    local _venv_path=
    for _venv_path in $_venvs/*; do
        local _venv_dir="$_venv_path"
        [[ -d "$_venv_dir" ]] || continue
        local _venv_name=$(basename_ $_venv_dir)
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
    local _dir_name=$(basename_ $_dir)
    python_project_here $_dir_name || return 0
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
    local config=./.bumpversion.cfg
    if [[ -f $config ]]; then
        bump show
        return
    fi
    echo "[bumpversion]" > $config
    echo "commit = True" >> $config
    echo "tag = True" >> $config
    echo "current_version = 0.0.0" >> $config
    git add $config
    echo "git commit -m\"v0.0.0\""
    echo bump
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

any_python_scripts_here () {
    local _found=$(find . -type f -name "*.py" -exec echo 1 \; -quit)
    [[ $_found == 1 ]] && rf -qpr
}

find_activate_script () {
    local _pwd=$(pwd)
    local _project_activate=
    local _local_activate=
    for _activate_dir in .venv/bin bin .; do
        local _activate=$_activate_dir/activate
        local _project_root=$(git rev-parse --git-dir . 2>/dev/null)
        [[ -n $_project_root ]] && _project_activate="$_project_root/$_activate"
        if [[ -f $_project_activate ]]; then
            ACTIVATE=$_project_activate
        else:
            _local_activate="$(readlink -f $_activate)"
            [[ -f "$_local_activate" ]] && ACTIVATE=$_local_activate
        fi
        [[ -f $ACTIVATE ]] || continue
        export ACTIVATE
        return 0
    done
    ACTIVATE=
    export ACTIVATE
    return 1
}

[[ -n $WELCOME_BYE ]] && echo Bye from $(basename "$BASH_SOURCE") in $(dirname $(readlink -f "$BASH_SOURCE")) on $(hostname -f)

