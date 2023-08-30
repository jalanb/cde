#! /usr/bin/env bat

export RED="\033[0;31m"
export GREEN="\033[0;32m"
export BLUE="\033[0;34m"
export LIGHT_RED="\033[1;31m"
export LIGHT_GREEN="\033[1;32m"
export LIGHT_BLUE="\033[1;34m"

if [[ $0 == "$BASH_SOURCE" ]]
then
    printf "$GREEN"
    printf "This file should be sourced like this"
    printf "$ . cde.sh"
    printf "$ source cde.sh"
    printf "$ whyp_source cde.sh"
    printf
    printf "$RED"
    printf "It should not be run like this" >&2
    printf "$ sh cde.sh" >&2
    printf "$ bash cde.sh" >&2
    exit 1
fi

export CDE_SOURCE=$(readlink -f "$BASH_SOURCE")  # .../cde.sh
export CDE_NAME=$(basename "$CDE_SOURCE")  # cde.sh
export CDE_DIR=$(dirname "$CDE_SOURCE")  # /.../



# x
# xx

., () {
    local destination_=$HOME
    local top_level_=$(quietly git rev-parse --show-toplevel)
    [[ $top_level_ ]] && destination_=$top_level_
}


alias ..=cdup

# xxx

cdd () {
    local __doc__="""cde here"""
    cde $(here)
}

# rule 1: Leave system commands alone
# So this uses the next key up from "cd"

cde () {
    local __doc__="""find a dir and handle it"""
    if [[ ! "$@" ]]; then (
        cde -q "$CDE_DIR"
        cde -
        cde --show-known
    )
        return 0
    fi
    if [[ $1 =~ ^-$ ]]; then
        cd -
        cde .
        return 0
    fi
    local quietly_=
    [[ $1 =~ -h ]] && cde_help && return 0
    [[ $1 =~ -a ]] && python_cde "$@" && return 0
    [[ $1 =~ -q ]] && quietly_=-q && shift
    if [[ $1 =~ ^[.]$ ]]; then
        cde $(here);
        return $?
    fi
    pre_cdpy $quietly_
    cdpy "$@" || return 1
    [[ -d . ]] || return 1
    post_cdpy $quietly_
}
#
# This one is way out-of-order
#    Put here to catch the eye of anyone looking at `cde ()`
#    Which eventually runs `cdpy` above here
#       And runs lotsa checks before reaching
#       $ run_cde python3 "$@"
#
# So, to debug:
#     1. Show any bash debugging tips
#     2. Ignore all the checks
#     3. Change the interpreter for cde from `python3` to `pudb3`
#
gde () {
    local __doc__="Run cde in pudb"
    (
        set -x;
        run_cde pudb "$@"
    )
}

cdg () {
    [[ -z "$1" ]] && qt whyp && whyp cdg && return $?
    (set -x
        local __doc__="""debug cde"""
        [[ $1 =~ -h ]] && cde_help >&2 && return 1
        [[ $1 =~ -q ]] && echo 👿 >&2 && shift
        [[ $1 =~ ^[.]$ ]] && cdu $(readlink -f .)
        pre_cdpy
        cdpu "$@" || echo "Fail" >&2
        # [[ -d . ]] && post_cdpy || echo ". is not a dir! 😳" >&2
    )
}

cdl () {
    local __doc__="""cde $1; ls [-a]"""
    local dir_="$@"
    [[ $dir_ ]] || dir_=.
    shift
    local ls_options_="$@"
    [[ $ls_options_ ]] || ls_options_=" -a "
    cde $dir_
    ls --color $_ls_options
}

cdq () {
    QUIETLY cde -q "$@"
}

cdr () {
    cde "$@"
    show_green_line $(readlink -f .)
}

cdu () {
    (set -x
        local __doc__="""debug cde"""
        [[ $1 =~ -h ]] && cde_help >&2 && return 1
        [[ $1 =~ -q ]] && echo 👿 >&2 && shift
        [[ $1 =~ ^[.]$ ]] && cdu $(readlink -f .)
        pre_cdpy
        cdpu "$@" || echo "Fail" >&2
        # [[ -d . ]] && post_cdpy || echo ". is not a dir! 😳" >&2 
    )
}

cdv () {
    cde "$1" || return 1
    shift
    local files_=$(basename "$@")
    [[ $files_ ]] || files_=$(ls -1a)
    [[ $files_ ]] || files_=$PWD
    [[ "$@" ]] && files_="$@"
    [[ $files_ ]] && $EDITOR -p $files_
}

cpp () {
    local __doc__="""Show where any args would cde to"""
    if [[ -n "$1" ]]; then
        python_cde "$@"
    else
        python_cde .
    fi | grep -v -- '->'
}

cls () {
    local __doc__="clean, clear, ls"
    clear
    cl "$@"
    [[ "$@" ]] || echo
}

ind () {
    local cd_=cd
    if [[ $1 == "ind" ]]; then
        cd_="cde -q"
        shift
    fi
    local destination_=$(python_cde "$1")
    [[ -d "$destination_" ]] || return 1
    shift
    (
        cd "$destination_"
        "$@"
    )
}

mkc () {
    local destination_=$(cde_first "$@")
    [[ -d "$destination_" ]] || mkdir -p "$destination_"
    cde "$destination_"
}

alias ...="cdup 2"

# xxxx

cdpy () {
    local __doc__="""pushd to cde.py's destination"""
    [[ $1 == -h || $1 == --help ]] && python_cde --help && return 0
    local no_stderr_= no_stdout_=
    [[ $1 =~ -q ]] && no_stdout_=-q && shift
    [[ $1 =~ -Q ]] && no_stdout_=-Q && no_stderr_=-Q && shift
    local cde_error_= cde_output_=$(python_cde "$@")
    local cde_return_=$?
    [[ $cde_return_ == 0 ]] || cde_error_="cde error: $cde_return_"
    if [[ $cde_error_ ]]; then
        if [[ $cde_output_ =~ (^$|^Error|Try.again|^[uU]sage) ]]; then
            q_echo $no_stderr_ "$cde_output_"
            return 1
        fi
        [[ $cde_output_ =~ ^[uU]sage ]] && q_echo $no_stderr_ $(python_cde --help)
        [[ "$@" =~  -[lp] ]] && q_echo $no_stderr_ "$cde_output_"
        return 0
    fi
    [[ $cde_output_ ]] || return $?
    python_cde --add $cde_output_
    same_path . "$cde_output_" && return 0
    local cde_directory_="$cde_output_" readlink_directory_=$(readlink -f $cde_output_)
    same_path . "$readlink_directory_" && return 0
    local cdpy_output_="cd $cde_output_"
    [[ "$cde_directory_" != "$readlink_directory_" ]] && cdpy_output_="cd ($cde_directory_ ->) $readlink_directory_"
    [[ $no_stdout_ ]] || echo $cdpy_output_
    pusq "$cde_directory_"
    return 0
}

cdrl () {
    cdq "$@" || return 1
    green_line $(rlf)
    lo 
}

cdrr () {
    cdq "$@" || return 1
    green_line $(rlf .)
    llr
}


cdup () {
    local __doc__="""cde up a few levels, 'cdup' goes up 1 level, 'cdup 2' goes up 2"""
    local level_=1
    if [[ $1 =~ [1-9] ]]; then
        level_=$1
        shift
    fi
    local dir_=$(readlink -f ..)
    pushd >/dev/null 2>&1
    while true; do
        level_=$(( $level_ - 1 ))
        [[ $level_ -le 0 ]] && break
        cd ..
        dir_=$(readlink -f .)
    done
    popd >/dev/null 2>&1
    cde $dir_ "$@"
}

here () {
    readlink -f .
}

popq () {
    QUIETLY popd
}

pusq () {
    QUIETLY pushd "$@"
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

q_echo () {
    [[ $1 =~ -[qQ] ]] && return 0 || shift
    echo "$@"
}

# xxxxxxx

is_type () {
    QUIETLY type "$@"
}

whichly () {
    quietly which "$@"
}

quietly () {
    "$@" 2>/dev/null
}

QUIETLY () {
    "$@" >/dev/null 2>&1
}

vim_cde () {
    local dot_cd_=
    [[ -f .cd ]] && dot_cd_=.cd
    [[ -f .cd.sh ]] && dot_cd_="$dot_cd_ .cd.sh"
    vim -p $dot_cd_ "$CDE_SOURCE" "${CDE_DIR}" "$@"
    . $CDE_SOURCE
    . $dot_cd_
    [[ -f .cd.sh ]] && bash .cd.sh
}

_active () {
    local __doc__="""Whether the $ACTIVATE script is in same dir as current python or virtualenv"""
    local activate_dir_=$(_dirnames $ACTIVATE)
    local python_dir_=$(_dirnames $(readlink -f $(command -v python)))
    same_path $activate_dir_ $python_dir_ && return 0
    local venv_bin_="$VIRTUAL_ENV/bin"
    same_path $activate_dir_ $venv_bin_
}

# xxxxxxxx

pre_cdpy () {
    cde_deactivate
    [[ -n $CDE_header ]] && echo $CDE_header
}

Quietly () {
    "$@" >/dev/null
}

quietly () {
    "$@" 2>/dev/null
}

QUIETLY () {
    "$@" >/dev/null 2>/dev/null
}

qt () {
    QUIETLY type "$1"
}

cl () {
    local dir_=.
    test -d "$1" && dir_="$1"
    local cmd_=ls
    qt l && cmd_="l"
    $cmd_ "$dir_"
}

cde_help () {
    echo "cd to a dir and react to it"
    echo
    cdpy -h
    return 0
}

headline () {
    [[ $1 ]] && head -n 1 "$1" || cat | head -n 1
}

is_command () {
    qt "$1"
}

try_command () {
    is_command $1 || return 1
    "$@"
}

pudb_cde () {
    local __doc__="""Debug the cde program"""
    local debugger_=$(venv_app pudb)
    [[ $debugger_ ]] || debugger_=$(venv_app pudb3)
    [[ -e $debugger_ ]] || return 1
    run_cde $debugger_ "$@"
}

# xxxxxxxxx

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
    local dirs_=
    for dir in "$@"; do
        [[ -d $dir ]] && dirs_="$dirs_ $dir"
    done
    [[ $dirs_ ]] || return 1
    echo $dirs_
    return 0
}

new_dot () {
    [[ -f .cd ]] && return 0
    echo "#! /usr/bin/env bash" > .cd
    echo "" >> .cd
    [[ -d bin ]] && echo "cde_dot_bin" >> .cd
    [[ -d .git ]] && echo "cde_dot_git" >> .cd
    cde_dot_python && echo "cde_dot_venv" >> .cd
    echo "cde_dot_ls && cde_dot_clean" >> .cd

    echo "#! /usr/bin/env bash" > .cd.sh
    echo "" >> .cd.sh
    echo "readlink -f ." >> .cd.sh
}

dot_cd () {
    local __doc__="""Look for .cd here and source it if found"""
    local dot_cd_= cd_sh_=
    [[ -f .cd ]] && dot_cd_=.cd
    [[ -f .cd.sh ]] && cd_sh_=".cd.sh"
    [[ -f $dot_cd_ ]] || return 1
    grep -q activate $dot_cd_ && cde_deactivate
    . $dot_cd_
    [[ -f $cd_sh_ ]] && bash $cd_sh_
}

post_cdpy () {
    [[ $1 =~ -q ]] && shift || say_path $path_
    new_dot
    dot_cd
}

quiet_out () {
    "$@" >/dev/null
}

same_path () {
    [[ $1 ]] && [[ ! $2 ]] && return 1
    [[ ! $1 ]] && [[ $2 ]] && return 2
    [[ $(readlink -f "$1") == $(readlink -f "$2") ]]
}

cde_bash () {
    show_command "$@"
    local cde_="$CDE_DIR" cde_out_="$cde_/std.out" cde_err_=$cde_/std.err
    local result_=0
    "$@" > $cde_out 2> $cde_err && result_=$?
    show_pass $(cat $cde_out)
    show_fail $(cat $cde_err)
    return $result_
}

# xxxxxxxxxx

_activate () {
    unhash_python_handlers
    [[ -f $ACTIVATE ]] && . $ACTIVATE
}

_dirnames () {
    local __doc__="""show dirnames for all args that are paths"""
    local result_=1
    for arg_ in "$@"; do
        [[ -e "$arg_" ]] || continue
        dirname "$arg_"
        result_=0
    done
    return $result_
}

cde_dot_venv () {
    local active_venv_="$VIRTUAL_ENV"
    local active_bin_="$active_venv_/bin"
    cde_activate_here && return 0
    local venvs_=$HOME/.virtualenvs
    [[ -d $venvs_ ]] || return 0
    local here_=$(readlink -f $(pwd))
    local name_="not_a_name"
    [[ -e $here_ ]] && name_=$(basename $here_)
    [[ $name_ == "not_a_name" ]] && return 1
    local venv_=
    for venv_ in $venvs_/*; do
        [[ -d "$venv_" ]] || continue
        local venv_name_=$(basename "$venv_")
        if [[ $venv_name_ == $name_ ]]; then
            local venv_activate_="$venv_/bin/activate"
            [[ -f "$venv_activate_" ]] || return 1
            . "$venv_activate_"
            return 0
        fi
    done
    return 0
}

find_cde_python () {
    [[ $1 ]] || return 1
    venv_or_which "$1"
    shift
    local python_path_="$cde_root_" command_="\"$python_\" \"$CDE_PYTHON\" $@"
    [[ $PYTHONPATH ]] && python_path_="$CDE_DIR:$PYTHONPATH"
}

run_cde () {
    local __doc__="""Run the cde script, setting PYTHONPATH"""
    local runner_=$(find_cde_python "$1") || return 1
    shift
    [[ $runner_ ]] || return 1
    local python_="$runner_"
    [[ -e $python_ ]] || python_="$(venv_or_which "$runner_")"
    is_type $python_ || return 1
    local cde_root_="$CDE_DIR"
    local python_path_="$cde_root_" command_="\"$python_\" \"$CDE_PYTHON\" $@"
    [[ $PYTHONPATH ]] && python_path_="$CDE_DIR:$PYTHONPATH"
    if [[ $python_ =~ venv[/] ]]; then
        (
        source "$(dirname $python_)/activate"
        PYTHONPATH="$python_path_" "$python_" -m cde "$@"
        )
    else
        PYTHONPATH="$python_path_" "$python_" -m cde "$@"
    fi
}

python_cde () {
    local __doc__="""Run the cde program"""
    run_cde python3 "$@"
}

cde_dot_clean () {
    for path in $(find . -type f -name '*.sw*'); do
        ls -l $path 2> ~/bash/fd/2
        rm -f $path && continue
        [[ $? == 0 ]] || break
    done
}

# xxxxxxxxxxx

_deactivate () {
    # Thanks to @nxnev at https://unix.stackexchange.com/a/443256/32775
    cde_deactivate
    if [[ $ACTIVE_PYTHON ]]; then
        ACTIVATE="${ACTIVE_PYTHON/%python/activate}"
        _activate
    fi
}

cde_template () {
    echo -n "$1/cd "
    return 0
}

# xxxxxxxxxxxx

cde_dot_python () {
    any_python_scripts_here || return 0
    local dir_=$(readlink -f .)
    local dir_name_=$(basename $dir_)
    python_project_here $dir_name_ || return 0
    prune_python_here
    cde_activate_here
    local egg_info=${dir_name_}.egg-info
    if [[ -d $egg_info ]]; then
        (set -x;
        echo  $egg_info
        ri $egg_info)
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

venv_or_which () {
    local __doc__="""find an executable in cde's virtualenv, or which, or which with our PATH"""
    [[ "$1" ]] || return 1
    local name_="$1"; shift
    local app_="${CDE_DIR}/.venv/bin/$name_"
    [[ -x "$app_" ]] || app_=$(quietly which $name_)
    [[ -x "$app_" ]] || app_=$(PATH=~/bin:/usr/local/bin:/bin:/usr/bin quietly which $name_)
    [[ -e "$app_" ]] || return 1
    echo $app_
    return 0
}

# xxxxxxxxxxxxxx

venv_dirs_here () {
    echo_dirs .venv/bin venv/bin bin
}

rld () {
    [[ -e "$1" ]] || return 1
    quietly dirname $( rlf "$1" )
}

rlf () {
    local path_=.
    [[ -e "$1" ]] && path_="$1"
    quietly readlink -f "$path_"
}

echo_venv_directory_from () {
    if echo_dir "$1" || echo_dir "~/.virtualenvs/$1"; then
        return 0
    fi
    return 1
}

# xxxxxxxxxxxxxxx

python_template () {
    local python_template_="$1/python"
    local echo_template=
    [[ $(find . -maxdepth 7 -name  __init__.py | wc -l) -gt 3 ]] && echo_template="$python_template_"
    [[ $(find . -maxdepth 2 -name  activate | wc -l) -gt 1 ]] && echo_template="$python_template_"
    [[ $echo_template ]] || return 1
    echo -n "$echo_template "
    return 0
}

unhash_handlers () {
    # Thanks to @nxnev at https://unix.stackexchange.com/a/443256/32775
    local result_=1
    for arg in "$@"; do
        quietly hash -d $arg && result_=0
    done
    return $result_
}

# xxxxxxxxxxxxxxxx

cat_cde_templates () {
    local _template_dir="$CDE_DIR/templates"
    cat $(cde_template "$_template_dir")
    local _template=
    for method in bin git python ; do
        template_=$(${method}template_ "$template_dir_")
        [[ $template_ ]] || continue
        local cat_=cat
        head -n 1 $template_ | grep -q '^#!' && cat_="tail -n +2 "
        $cat_ $template_ | grep -v ^$
    done
}

# xxxxxxxxxxxxxxxxx

project_venv_dirs () {
    local top_dirs_=
    local git_top_=$(quietly git rev-parse --show-toplevel . | head -n 1)
    [[ -d $git_top_ ]] && top_dirs_="$git_top_/venv/bin $git_top_/.venv/bin $git_top_/bin"
    echo_dirs $top_dirs_
}

prune_python_here () {
    local here_=$(rlf .)
    local home_=$(rlf $HOME)
    [[ ${here_:0:${#home_}} == $home_ ]] || return 1
    [[ ${#here_} == ${#home_} ]] && return 1
    rf -qpr
    return 0
}

unhash_deactivate () {
    unhash_python_handlers
    [[ $VIRTUAL_ENV ]] && deactivate
}

# xxxxxxxxxxxxxxxxxx
# xxxxxxxxxxxxxxxxxxx

python_project_here () {
    local __doc__="""Recognise python project dir by presence of known files/dirs"""
    local dirname_="$1"
    [[ -f setup.py || -f requirements.txt || -f bin/activate || -d ./$dir_name_ || -d .venv || -d .idea ]]
}

# xxxxxxxxxxxxxxxxxxxx

unhash_file_handlers () {
    unhash_handlers  rm cp mv cat
}

# xxxxxxxxxxxxxxxxxxxxx
# xxxxxxxxxxxxxxxxxxxxxx

unhash_python_handlers () {
    # Thanks to @nxnev at https://unix.stackexchange.com/a/443256/32775
    unhash_handlers python python2 python3 ipython ipython2 ipython3 pudb pudb3 pdb ipdb pip pip2 pip3
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
    local __doc__="""find an activate script in $1 (path to venv, or activate)"""
    local python_roots_=  activate_=
    if [[ -f "$1" && $(basename "$1") == "activate" ]]; then
        activate_="$1"
    else
        [[ "$@" ]] && python_roots_=$(echo_venv_directory_from "$@" )
        [[ $python_roots_ ]] || python_roots_="$(pwd) $(venv_dirs_here) $(project_venv_dirs)"
        [[ $python_roots_ ]] || echo "No dirs available to find activate scripts" >&2
        [[ $python_roots_ ]] || return 1
        local activate_=$(cde_test_activate_scripts $python_roots_) || return 1
    fi
    # [[ -f $activate_ ]] || return 1
    ACTIVATE="$(rlf $activate_)"
    export ACTIVATE
}

#
# After here functions are intended for use in .cd scripts
#

cde_dot_activate () {
    cde_activate_venv
}

cde_activate_venv () {
    local bin_=.venv/bin
    [[ -d $bin_ ]] || return 1
    cde_deactivate
    [[ -e bin ]] || ln -s .venv/bin bin
    . $bin_/activate
    $bin_/python -V
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

cde_deactivate () {
    try_command deactivate 2>&1 | grep -q "deactivate must be sourced" && source deactivate 2>/dev/null
    unhash_python_handlers
}

cde_dot_git () {
    [[ -d ./.git ]] || return 0
    blue_line "$(git remote get-url origin) <$(git config user.name) $(git config user.email)>\n"
    git status .
    # git rev-parse --abbrev-ref HEAD
    echo
    [[ -f ".bumpversion.cfg" ]] && grep ^current_version .bumpversion.cfg | grep --colour '\d[0-9a-z.]\+$'
    echo
    git log -n 8 --color=always --decorate --oneline --graph --abbrev-commit --date=relative --pretty=format:'%Cgreen%cr%Creset, %C(blue)%aN%Creset,%C(auto)%d%Creset %C(auto)%h "%s"'
    return 0
}

cde_dot_bin () {
    local __doc__="""Adds .cd/../bin to PATH"""
    local bin_path_=$(quietly cd bin && pwd)
    [[ -d "$1" ]] && bin_path_="$1"
    [[ -d "$bin_path_" ]] || return 2
    [[ $PATH =~ "${bin_path_//\//.}" ]] && return 0
    PATH="$bin_path_:$PATH"
    export PATH
}

cde_PYTHONPATH () {
    local __doc__="""Adds .cd/.. to PYTHONPATH"""
    local here_=$(pwd)
    [[ $PYTHONPATH =~ ${here_//\//.} ]] && return 0
    [[ $PYTHONPATH ]] && PYTHONPATH="$PYTHONPATH:$here_" || PYTHONPATH="$here_"
    export PYTHONPATH
}

cde_clean_eggs () {
    rm -rf *.egg-info
}
