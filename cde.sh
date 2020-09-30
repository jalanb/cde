#! /bin/cat

export RED="\033[0;31m"
export GREEN="\033[0;32m"
export BLUE="\033[0;34m"
export LIGHT_RED="\033[1;31m"
export LIGHT_GREEN="\033[1;32m"
export LIGHT_BLUE="\033[1;34m"
export CDE_SOURCE="$BASH_SOURCE"
export CDE_NAME=$(basename "$CDE_SOURCE")
export CDE_SOURCE_PATH=$(readlink -f "$CDE_SOURCE")
export CDE_DIR=$(dirname "$CDE_SOURCE_PATH")
export CDE_SCRIPT="$CDE_DIR"/bin/cde

# This script is intended to be sourced, not run
if [[ $0 == "$CDE_SOURCE" ]]
then
    echo "This file should be run as"
    echo "  source $0"
    echo "and should not be run as"
    echo "  sh $0"
fi

export CDE_SOURCE=$BASH_SOURCE
export CDE_NAME=$(basename $CDE_SOURCE)
export CDE_DIR=$(dirname $(readlink -f $CDE_SOURCE))

# x
# xx

., () {
    local destination_=$HOME
    local top_level_=$(git rev-parse --show-toplevel 2>/dev/null)
    [[ $top_level_ ]] && destination_=$top_level_
}


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
    [[ $1 =~ ^[.]$ ]] && cde $(readlink -f .) && return $?
    local quietly_=
    [[ $1 =~ -q ]] && quietly_=-q && shift
    pre_cdpy $quietly_
    cdpy "$@" || return 1
    [[ -d . ]] || return 1
    post_cdpy $quietly_
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

cpp () {
    local __doc__="""Show where any args would cde to"""
    if [[ -n "$1" ]]; then
        cde_python "$@"
    else
        cde_python .
    fi | grep -v -- '->'
}

cls () {
    local __doc__="clean, clear, ls" dir_=.
    [[ "$@" ]] && dir_="$1"
    clear
    lo "$dir_"
    [[ "$@" ]] || echo
}

ind () {
    local _old=$PWD _cd=cd
    if [[ $1 == "ind" ]]; then
        _cd="cde -q"
        shift
    fi
    local _destination=$(cde_python "$1")
    [[ -d "$_destination" ]] || return 1
    (
        $_cd "$_destination"
        shift
        "$@"
    )
}

mkc () {
    local _destination=$(cde_first "$@")
    [[ -d "$_destination" ]] || mkdir -p "$_destination"
    cde "$_destination"
}

red () {
    coloured "$RED""$@"
}

alias ...="cdup 2"

# xxxx

blue () {
    coloured "$BLUE""$@"
}

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
    local Quiet_= quietly_=
    [[ $1 =~ -q ]] && quietly_=-q && shift
    [[ $1 =~ -Q ]] && quietly_=-q && Quiet_=1 && shift
    [[ $1 == -h || $1 == --help ]] && cde_python --help && return 0
    if [[ $1 =~ -Q ]]; then
        quietly_=1
        Quiet_=1
        shift
    fi
    # set +x
    if [[ $PUDB || $PUDB_CD ]]; then
        local errors_=0
        cde_pudb "$@" || errors_=1
        export PUDB_CD=
        return $errors_
    fi
    local cde_error_= cde_output_=$(cde_python "$@")
    [[ $? == 0 ]] || cde_error_=1
    if [[ $? != 0 || $cde_output_ =~ (^$|^Error|Try.again|^[uU]sage) ]]; then
        [[ $Quiet_ ]] || echo "$cde_output_" >&2
        return 1
    elif [[ $cde_output_ =~ ^[uU]sage ]]; then
        [[ $Quiet_ ]] || cde_python --help
        return 0
    elif [[ "$@" =~  -[lp] ]]; then
        [[ $Quiet_ ]] || echo "$cde_output_"
        return 0
    fi
    local cde_directory_="$cde_output_"
    same_path . "$cde_directory_" && return 0
    local linked_directory_=$(readlink -f $cde_directory_)
    local cdpy_output_="cd $cde_output_"
    if [[ "$cde_directory_" != "$linked_directory_" ]]
    then
        cdpy_output_="cd ($cde_output_ ->) $linked_directory_"
    fi
    same_path . "$linked_directory_" && return 0
    [[ $quietly_ ]] || echo $cdpy_output_
    pushd "$cde_directory_" >/dev/null 2>&1
    return 0
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

green () {
    coloured "$GREEN""$@"
}

lblue () {
    coloured "$LIGHT_BLUE""$@"
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
    [[ -f $_cd_here ]] || return 1
    grep -q activate $_cd_here && unhash_python_handlers
    . $_cd_here
    return 0
}

# xxxxxxxx

_here_ls () {
    ls . 2>/dev/null
}

cde_pudb () {
    local __doc__="""Debug the cde program"""
    # set -x
    local _interpreter=$(venv_or_which pudb3 2>/dev/null)
    interpret_cde "$_interpreter" "$@"
    # set +x
}

cde_help () {
    echo "cd to a dir and react to it"
    echo
    cdpy -h
    return 0
}

coloured () {
    printf "$@""${NO_COLOUR}"
}

headline () {
    head -n 1 "$1"
}

show_cmd () {
    lblue "$@"
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

# xxxxxxxxx

pre_cdpy () {
    cde_deactivate
    [[ -n $CDE_header ]] && echo $CDE_header
}

echo_dir () {
    if [[ -d "$1" ]]; then
        echo $1
    elif [[ -f "$1" ]]; then
        rld "$1"
    else
        return 1
    fi
    return 0
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

post_cdpy () {
    local _path=$(short_dir $PWD)
    [[ $_path == "~" ]] && _path=HOME
    [[ $_path =~ "wwts" ]] && _path="${_path/wwts/dub dub t s}"
    [[ $1 =~ -q ]] && shift || say_path $_path
    _dot_cd && return 0
    cde_bin_PATH
    cde_show_git_was_here
    _here_python && _here_venv
    [[ -n $1 ]] &&
    _here_ls && here_clean
}

same_path () {
    [[ $(readlink -f "$1") == $(readlink -f "$2") ]]
}

show_pass () {
    green "$@"
}

show_fail () {
    red "$@"
}

show_bash () {
    show_cmd "$@"
    local cde_="$CDE_DIR"
    "$@" > $cde_/std.out 2> $cde_/std.err
    show_pass $(cat $cde_/std.out)
    show_fail $(cat $cde_/std.err)
}

# xxxxxxxxxx

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

_here_venv () {
    local _active_venv="$VIRTUAL_ENV"
    local _active_bin="$_active_venv/bin"
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

cde_python () {
    local __doc__="""Run the cde program"""
    local _interpreter=$(venv_or_shebang python3 "$CDE_SCRIPT")
    interpret_cde "$_interpreter" "$@"
}

here_clean () {
    for path in $(find . -type f -name '*.sw*'); do
        ls -l $path 2> ~/bash/fd/2
        rm -i $path && continue
        [[ $? == 0 ]] || break
    done
}

# xxxxxxxxxxx

_deactivate () {
    # Thanks to @nxnev at https://unix.stackexchange.com/a/443256/32775
    unhash_python_handlers
    deactivate
    if [[ $ACTIVE_PYTHON ]]; then
        ACTIVATE="${ACTIVE_PYTHON/%python/activate}"
        _activate
    fi
}

cd_template () {
    echo -n "$1/cd "
    return 0
}

# xxxxxxxxxxxx

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

interpret_cde () {
    local __doc__="""Interpret the cde script, setting PYTHONPATH"""
    local _interpreter="$1"; shift
    # set -x
    [[ $_interpreter ]] || return 1
    PYTHONPATH=${CDE_DIR}:$PYTHONPATH $_interpreter "$CDE_SCRIPT" "$@"
    # set +x
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

# xxxxxxxxxxxxxx

venv_dirs_here () {
    echo_dirs .venv/bin venv/bin bin
}

rld () {
    dirname $( rlf "$1" ) 2>/dev/null
}

rlf () {
    readlink -f "$1" 2>/dev/null
}

echo_venv_directory_from () {
    if echo_dir "$1" || echo_dir "~/.virtualenvs/$1"; then
        return 0
    fi
    echo "Not a directory: '$1'" >&2
    return 1
}

# xxxxxxxxxxxxxxx

venv_or_shebang () {
    local _app=$1 _file=$2
    [[ "$_app" && "$_file" ]] || return 1
    _app="${_app/%2/3}"  # Change (e.g) python2 to python3
    if [[ -f $_file ]]; then
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
    local _template_dir="$CDE_DIR/templates"
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
    local _here=$(rlf .)
    local _home=$(rlf $HOME)
    [[ ${_here:0:${#_home}} == $_home ]] || return 1
    [[ ${#_here} == ${#_home} ]] && return 1
    rf -qpr
    return 0
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

# xxxxxxxxxxxxxxxxxxxxx
# xxxxxxxxxxxxxxxxxxxxxx

unhash_python_handlers () {
    unhash_handlers '[ib]*python' 'pip[23]*' 'ipython[23]*' pdb ipdb pudb
}

# xxxxxxxxxxxxxxxxxxxxxxx

any_python_scripts_here () {
    [[ $(find . -type f -name "*.py" -exec echo 1 \; -quit) == 1 ]]
}

# xxxxxxxxxxxxxxxxxxxxxxxx

cde_test_activate_scripts () {
    for python_root_ in "$@"; do
        [[ -f ${python_root_}/bin/activate ]] && activate_=${python_root_}/bin/activate
        [[ -f ${python_root_}/activate ]] && activate_=${python_root_}/activate
        if [[ -f "$activate_" ]]; then
            echo "$activate_"
            return 0
        fi
    done
    return 1
}

cde_find_activate_script () {
    local python_roots_= _here=$(pwd)
    [[ "$@" ]] && python_roots_=$(echo_venv_directory_from "$@" 2>/dev/null)
    [[ $python_roots_ ]] || python_roots_="$_here $(venv_dirs_here) $(project_venv_dirs)"
    [[ $python_roots_ ]] || echo "No dirs available to find activate scripts" >&2
    [[ $python_roots_ ]] || return 1
    local activate_=$(cde_test_activate_scripts $python_roots_) || return 1
    # [[ -f $activate_ ]] || return 1
    ACTIVATE="$(rlf $activate_)"
    export ACTIVATE
}

# 
# After here functions are intended for use in .cd scripts
#
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
    lblue "$(git config --local user.email), $(git remote get-url origin)\n"
    [[ -f ".bumpversion.cfg" ]] && grep ^current_version .bumpversion.cfg | grep --colour '\d[0-9a-z.]\+$'
    git status .
    git rev-parse --abbrev-ref HEAD
    git lg -n 8
    return 0
}

cde_bin_PATH () {
    local __doc__="""Adds .cd/../bin to PATH"""
    local _bin_path=$(cd bin 2>/dev/null && pwd)
    [[ -d "$1" ]] && _bin_path="$1"
    [[ -d "$_bin_path" ]] || return 2
    [[ $PATH =~ "${_bin_path//\//.}" ]] && return 0
    PATH="$_bin_path:$PATH"
    export PATH
}

cde_PYTHONPATH () {
    local __doc__="""Adds .cd/.. to PYTHONPATH"""
    local _here=$(pwd)
    [[ $PYTHONPATH =~ ${_here//\//.} ]] && return 0
    [[ $PYTHONPATH ]] && PYTHONPATH="$PYTHONPATH:$_here" || PYTHONPATH="$_here"
    export PYTHONPATH
}

cde_clean_eggs () {
    rm -rf *.egg-info
}
