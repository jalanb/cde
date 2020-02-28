#! /bin/cat

export CDE_SOURCE="$BASH_SOURCE"
export CDE_NAME=$(basename "$CDE_SOURCE")
export CDE_SOURCE_PATH=$(readlink -f "$CDE_SOURCE")
export CDE_DIR=$(dirname "$CDE_SOURCE_PATH")

announce () {
    set -x
    local _host=$(hostname -f)
    echo "$@" $CDE_NAME in $CDE_DIR on $_host
    set +x
}

[[ $WELCOME_BYE ]] && announce Welcome to


# This script is intended to be sourced, not run
if [[ $0 == "$CDE_SOURCE" ]]
then
    echo "This file should be run as"
    echo "  source $0"
    echo "and should not be run as"
    echo "  sh $0"
fi

# _
# x

# _x

., () {
    local _destination=$HOME
    local _top_level=$(git rev-parse --show-toplevel 2>/dev/null)
    [[ $_top_level ]] && _destination=$_top_level
}

# xx

alias ..=cdup

# xxx

cdd () {
    local __doc__"""cde here"""
    cde .
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
    pre_cdpy
    cdpy "$@" || return 1
    [[ -d . ]] || return 1
    post_cdpy $_say_quiet
}

cdi () {
    local _index=0
    if [[ $1 =~ [0-2] ]]; then
        _index=$1
        shift
    fi
    cde -$_index "$@"
}

cdi () {
    local _index=0
    if [[ $1 =~ [0-2] ]]; then
        _index=$1
        shift
    fi
    cde -$_index "$@"
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

venv_or_which () {
    local __doc__="""find an executable in cde's virtualenv, or which, or which with our PATH"""
    [[ "$1" ]] || return 1 
    local _name="$1"; shift
    local _app="${CDE_DIR}/.venv/bin/$_name"
    [[ -e "$_app" ]] || _app=$(which $_name 2>/dev/null)
    [[ -e "$_app" ]] || _app=$(PATH=~/bin:/usr/local/bin:/bin which $_name 2>/dev/null)
    [[ -e "$_app" ]] && echo $_app
    [[ -e "$_app" ]]
}

venv_or_shebang () {
    local _app=$1 _file=$2 
    [[ "$_app" ]] || return 1
    _app="${_app/%2/3}"
    if [[ -e $_file ]]; then
        local _language=$(echo $_app | sed -e "s:[0-9]*$::" )
        local _shebang=$(headline "$_file")
        if [[ $_shebang =~ $_language ]]; then
            if [[ $_shebang =~ usr.bin.env ]]; then
                _interpreter=$_app
            else
                _interpreter=$_shebang
            fi
        fi
    fi
    local _interpreter=$(venv_or_which $_app)
    if [[ ! -e $_interpreter ]]; then
        echo "Could not find $_app" >&2
        return 1
    fi
    echo $_interpreter
    return 0
}

bin_cde () {
    echo "${CDE_DIR}/bin/cde"
}

cde_pudb () {
    local __doc__="""Debug the cde program, with PATH/PYTHONPATH"""
    local _cde_dir="$CDE_DIR" _interpreter=$(venv_or_shebang pudb)
    [[ $? == 0 ]] || return 1
    set -x
    PYTHONPATH="$_cde_dir":$PYTHONPATH $_interpreter "$(bin_cde)" "$@"
    set +x
}

cde_python () {
    local __doc__="""Run the cde python program, with PATH/PYTHONPATH"""
    local _bin_cde="$(bin_cde)"
    local _interpreter=$(venv_or_shebang python3 "$_bin_cde")
    [[ $? == 0 ]] || return 1
    PYTHONPATH=${CDE_DIR}:$PYTHONPATH $_interpreter "$_bin_cde" "$@"
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

ind () {
    local _old=$PWD _cd=cd
    if [[ $1 == "ind" ]]; then
        _cd="cde -q"
        shift
    fi
    local _destination=$(cde_first "$@")
    if [[ -d "$_destination" ]]; then
        $_cd "$_destination"
        shift
        "$@"
    else
        "$@"
    fi
    cd $_old
}

mkc () {
    local _destination=$(cde_first "$@")
    [[ -d "$_destination" ]] || mkdir -p "$_destination"
    cde "$_destination"
}

alias ...="cdup 2"

# xxxx

alias cdee='c .'

cdll () {
    local __doc__="""cde $1; ls -l"""
    local _dir="$@"
    [[ $_dir ]] || _dir=.
    cdl $_dir -lhtra
}

cdpu () {
    local __doc__="Debug the cdpy function and script"
    PUDB_CD=1 cdpy "$@"
}

cdpy () {
    local __doc__="""pushd to cde.py's destination"""
    local _quiet= _Quiet=
    if [[ $1 == -h || $1 == --help ]]; then
        cde_python --help
        return 0
    fi
    if [[ $1 =~ -q ]]; then
        _quiet=1
        shift
    fi
    if [[ $1 =~ -Q ]]; then
        _quiet=1
        _Quiet=1
        shift
    fi
    # set +x
    if [[ $PUDB || $PUDB_CD ]]; then
        local _errors=0
        cde_pudb "$@" || _errors=1
        export PUDB_CD=
        return $_errors
    fi
    local _cde_error= _cde_output=$(cde_python "$@")
    [[ $? == 0 ]] || _cde_error=1
    if [[ $? != 0 || $_cde_output =~ (^$|^Error|Try.again|^[uU]sage) ]]; then
        [[ $_Quiet ]] || echo "$_cde_output" >&2
        return 1
    elif [[ $_cde_output =~ ^[uU]sage ]]; then
        [[ $_Quiet ]] || cde_python --help
        return 0
    elif [[ "$@" =~  -[lp] ]]; then
        [[ $_Quiet ]] || echo "$_cde_output"
        return 0
    fi
    local _cde_directory="$_cde_output"
    same_path . "$_cde_directory" && return 0
    local _linked_directory=$(readlink -f $_cde_directory)
    local _cdpy_output="cd $_cde_output"
    if [[ "$_cde_directory" != "$_linked_directory" ]]
    then
        _cdpy_output="cd ($_cde_output ->) $_linked_directory"
    fi
    same_path . "$_linked_directory" && return 0
    [[ $_quiet ]] || echo $_cdpy_output
    pushd "$_cde_directory" >/dev/null 2>&1
    return 0
}

cdll () {
    local __doc__="""cde $1; ls -l"""
    local _dir="$@"
    [[ $_dir ]] || _dir=.
    cdl $_dir -lhtra
}

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

alias indd="ind ind"

inde () {
    ind -e "$@"
}

pycd () {
    # Adapted from https://news.ycombinator.com/item?id=18898898
    local __doc__="""cde to directory of a iven Python module"""
    cde $(python -c "import os.path, $1; print(os.path.dirname($1.__file__))");
}

alias ....="cdup 3"

# xxxxx

cdupp () {
    local """cd up 2 levels"""
    cdup 2 "$@"
}

alias .....="cdup 4"

# xxxxxx

cde_ok () {
    local __doc__="""Whether cde would go anywhere"""
    [[ -z "$@" ]] && return 1
    [[ -d $(cde_first "$@") ]]
}

cduppp () {
    local """cd up ... etc, you get the idea"""
    cdup 3 "$@"
}
# xxxxxxx

vim_cde () {
    local _files=
    [[ -f .cd ]] && _files=.cd
    v $_files $CDE_SOURCE_PATH ${CDE_DIR} "$@"
    . $CDE.sh
    [[ $_files ]] && . $_files
}

# _xxxxxx

_active () {
    local __doc__="""Whether the $ACTIVATE script is in same dir as current python or virtualenv"""
    local _activate_dir=$(_dirnames $ACTIVATE)
    local _python_dir=$(_dirnames $(readlink -f $(command -v python)))
    same_path $_activate_dir $_python_dir && return 0
    local _venv_dir="$VIRTUAL_ENV/bin"
    same_path $_activate_dir $_venv_dir
}

_dot_cd () {
    local __doc__="""Look for .cd here and source it if found"""
    local _cd_here=./.cd
    [[ -f $_cd_here ]] || cat_cd_templates > $_cd_here
    grep -q activate $_cd_here && unhash_python_handlers
    . $_cd_here
    return 0
}

# xxxxxxxx

headline () {
    head -n 1 "$1"
}

cde_help () {
    echo "cd to a dir and react to it"
    echo
    cdpy -h
    return 0
}
# _xxxxxxx

_here_ls () {
    ls 2> ~/bash/null
}

# xxxxxxxx

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

# xxxxxxxxx

cde_first () {
    local __doc__="Show the first path that cdpy would go to"
    cde -0 "$@"
}

pre_cdpy () {
    # cde_deactivate
    [[ -n $CDE_header ]] && echo $CDE_header
}

echo_dirs () {
    local _echoed=
    for dir in "$@"; do
        [[ -d $dir ]] || continue
        echo -n "$dir "
        _echoed=1
    done
    [[ $_echoed ]] || return 1
    echo
    return 0
}

same_path () {
    [[ $(readlink -f "$1") == $(readlink -f "$2") ]]
}

# _xxxxxxxx

_deactivate () {
    # Thanks to @nxnev at https://unix.stackexchange.com/a/443256/32775
    unhash_python_handlers
    deactivate
    if [[ $ACTIVE_PYTHON ]]; then
        ACTIVATE="${ACTIVE_PYTHON/%python/activate}"
        _activate
    fi
}

_activate () {
    # Thanks to @nxnev at https://unix.stackexchange.com/a/443256/32775
    unhash_python_handlers
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

_add_source_bin_to_PATH() {
    [[ -d ./bin ]] && add_to_PATH ./bin
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
    cde_activate_here && return 0
    # set -x
    local _venvs=$HOME/.virtualenvs
    [[ -d $_venvs ]] || return 0
    local _here=$(readlink -f $(pwd))
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

_reactivate () {
    _activate
}


# _xxxxxxxxxxx

_here_python () {
    any_python_scripts_here || return 0
    local _dir=$(readlink -f .)
    local _dir_name=$(basename $_dir)
    python_project_here $_dir_name || return 0
    prune_python_here
    cde_activate_here
    local egg_info=${_dir_name}.egg-info
    if [[ -d $egg_info ]]; then
        ri $egg_info
    fi
    return 0
}

# xxxxxxxxxx

post_cdpy () {
    local _path=$(short_dir $PWD)
    [[ $_path == "~" ]] && _path=HOME
    [[ $_path =~ "wwts" ]] && _path="${_path/wwts/dub dub t s}"
    [[ $1 =~ quiet ]] && shift || say_path $_path
    _dot_cd && return 0
    _add_source_bin_to_PATH
    cde_show_git_was_here
    _here_python && _here_venv
    [[ -n $1 ]] &&
    _here_ls && here_clean
}

here_clean () {
    for path in $(find . -type f -name '*.sw*'); do
        ls -l $path 2> ~/bash/fd/2
        rm -i $path && continue
        [[ $? == 0 ]] || break
    done
}

# xxxxxxxxxxx

cd_template () {
    echo -n "$1/cd "
    return 0
}

# xxxxxxxxxxxx

bin_template () {
    [[ -d bin ]] || return 1
    echo -n "$1/bin "
    return 0
}

git_template () {
    [[ -d .git ]] || return 1
    echo -n "$1/git "
    return 0
}

# xxxxxxxxxxxxx
# xxxxxxxxxxxxxx

venv_dirs_here () {
    echo_dirs .venv/bin venv/bin bin
}

venv_directory () {
    local _one=
    [[ "$1" ]] && _one="$1"
    [[ $_one ]] && shift
    local _path_to_one=
    [[ $_one ]] && _path_to_one=$(readlink -f $_one)
    [[ -f "$_path_to_one" ]] && _path_to_one=$(dirname "$_path_to_one")
    local _path_at_home=
    [[ $_one ]] && _path_at_home=$(readlink -f ~/.virtualenvs/$_one)
    local _venv_dir=
    if [[ -d "$_path_to_one" ]]; then
        _venv_dir="$_path_to_one"
    else
        if [[ -d "$_path_at_home" ]]; then
            _venv_dir="$_path_at_home"
        else
            echo "Not a directory: '$_path_to_one'" >&2
            echo "Not a directory: '$_path_at_home'" >&2
            return 1
        fi
    fi
    [[ -d "$_venv_dir" ]] || return 1
    echo_dirs "$_venv_dir"
    return 0
}

# xxxxxxxxxxxxxxx

# xxxxxxxxxxxxxxx

python_template () {
    local _python_template="$1/python"
    local echo_template=
    [[ $(find . -maxdepth 7 -name  __init__.py | wc -l) -gt 3 ]] && echo_template="$_python_template"
    [[ $(find . -maxdepth 2 -name  activate | wc -l) -gt 1 ]] && echo_template="$_python_template"
    [[ $echo_template ]] || return 1
    echo -n "$echo_template "
    return 0
}

unhash_handlers () {
    local _dehash=
    for arg in "$@"; do
        if hash -l | grep " $arg[$]"; then
            hash -d $arg
            _dehash=1
        fi
    done
    [[ $_dehash ]] || return 0
    return 0
}

# xxxxxxxxxxxxxxxx

cat_cd_templates () {
    local _template_dir="${CDE_DIR}/templates"
    cat $(cd_template "$_template_dir")
    local _template=
    for method in bin git python ; do
        _template=$(${method}_template "$_template_dir")
        [[ $_template ]] || continue
        local _cat=cat
        head -n 1 $_template | grep -q '^#!' && _cat="tail -n +2 "
        $_cat $_template | grep -v ^$
    done
}

# xxxxxxxxxxxxxxxxx
project_venv_dirs () {
    local _top_dirs=
    local _git_top=$(git rev-parse --show-toplevel . 2>/dev/null | head -n 1)
    [[ -d $_git_top ]] && _top_dirs="$_git_top/venv/bin $_git_top/.venv/bin $_git_top/bin"
    echo_dirs $_top_dirs
}

prune_python_here () {
    local _here=$(readlink -f .)
    local _home=$(readlink -f $HOME)
    [[ ${_here:0:${#_home}} == $_home ]] || return 1
    [[ ${#_here} == ${#_home} ]] && return 1
    rf -qpr
    return 0
}

show_version_here () {
    local _config=./.bumpversion.cfg
    if [[ -f $_config ]]; then
        bump show
        return
    fi
}

# xxxxxxxxxxxxxxxxxx
# xxxxxxxxxxxxxxxxxxx

python_project_here () {
    local __doc__="""Recognise python project dir by presence of known files/dirs"""
    local _dirname="$1"
    [[ -f setup.py || -f requirements.txt || -f bin/activate || -d ./$_dir_name || -d .venv || -d .idea ]]
}

# xxxxxxxxxxxxxxxxxxxx

unhash_file_handlers () {
    unhash_handlers  rm cp mv cat
}

# xxxxxxxxxxxxxxxxxxxxxx

unhash_python_handlers () {
    unhash_handlers '[ib]*python' 'pip[23]*' 'ipython[23]*' pdb ipdb pudb
}

# xxxxxxxxxxxxxxxxxxxxxxx

any_python_scripts_here () {
    [[ $(find . -type f -name "*.py" -exec echo 1 \; -quit) == 1 ]]
}

#
# cde_activate functions
#
# These names should be used in /dir/.cd files
# They rely on: $(dirname .cd) == $PWD
#

cde_find_activate_script () {
    local _here=$(pwd)
    local _activate_dirs=$(venv_directory "$@")
    [[ $_activate_dirs ]] || _activate_dirs="$_here $(venv_dirs_here) $(project_venv_dirs)"
    [[ $_activate_dirs ]] || echo "No dirs available to find activate scripts" >&2
    [[ $_activate_dirs ]] || return 1
    local _activate_dir=
    local _activate_script=
    for _activate_dir in $_activate_dirs; do
        [[ -f $_activate_dir/bin/activate ]] && _activate_script=$_activate_dir/bin/activate
        [[ -f $_activate_dir/activate ]] && _activate_script=$_activate_dir/activate
        [[ -f "$_activate_script" ]] && break
    done
    [[ -f $_activate_script ]] && ACTIVATE="$(readlink -f $_activate_script)"
    export ACTIVATE
    [[ -f $_activate_script ]]
}

cde_activate_here () {
    cde_find_activate_script || return 1
    _active && cde_deactivate
    _activate
}

cde_activate_home () {
    cde_activate_there ~/.virtualenvs/$1
}

cde_activate_there () {
    cde_find_activate_script "$@" || return 1
    _active && cde_deactivate
    _activate
}

cde_activate_venv () {
    [[ "$@" ]] && cde_activate_there "$@" || cde_activate_here
}

cde_deactivate () {
    deactivate >/dev/null 2>&1
    unhash_python_handlers
}

cde_show_git_was_here () {
    [[ -d ./.git ]] || return 0
    show_git_time . | head -n ${LOG_LINES_ON_CD_GIT_DIR:-7}
    local _branch=$(git rev-parse --abbrev-ref HEAD)
    echo $_branch
    git status .
    show_version_here
    gl11
    return 0
}

cde_bin_PATH () {
    local __doc__="""Adds .cd/../bin to PATH"""
    local _bin_path=$(readlink -f bin)
    [[ -d "$1" ]] && _bin_path="$1"
    [[ -d "$_bin_path" ]] || return 2
    [[ $PATH =~ "$_bin_path" ]] && return 0
    PATH="$_bin_path:$PATH"
    export PATH
}

cde_PYTHONPATH () {
    local __doc__="""Adds . to PATH"""
    local _here_path=$(readlink -f .)
    [[ -d "$1" ]] && _here_path="$1"
    [[ -d "$_here_path" ]] || return 2
    [[ $PYTHONPATH =~ "$_here_path" ]] && return 0
    PYTHONPATH="$_here_path:$PYTHONPATH"
    export PYTHONPATH
}

cde_PYTHONPATH () {
    local __doc__="""Adds .cd/.. to PYTHONPATH"""
    local _here=$(pwd)
    [[ $PYTHONPATH =~ ${_here//\//.} ]] && return 0
    [[ PYTHONPATH ]] && PYTHONPATH="$PYTHONPATH:$_here" || PYTHONPATH="$_here"
    export PYTHONPATH
}

[[ $WELCOME_BYE ]] && announce Bye from
