#! /bin/cat

colours_script () {
    local __doc__="""Expect colours.sh in same dir as this"""
    local my_source_=$(readlink -f $BASH_SOURCE)
    local my_dir_=$(dirname $my_source_)
    echo "$my_dir_/colours.sh"
}

[[ $OTHER_NO_COLOUR ]] || source $(colours_script)

# xxxxxxxx

show_red () {
    show_colour ${RED} "$*"
}

# xxxxxxxxxx

show_error () {
    show_red_line "$@" >&2
    return 1
}

show_green () {
    show_colour $GREEN "$*"
}

# xxxxxxxxxxx

show_colour () {
    local line_=
    if [[ $1 =~ -n ]]; then
        line_="\n"
        shift
    fi
    local colour_=$1
    shift
    if [[ "$@" ]];
    then printf "${colour_}$*""${NO_COLOUR}${line_}"
    else printf "${colour_}$(cat)${NO_COLOUR}${line_}"
    fi
}

# xxxxxxxxxxxx

show_command () {
    show_blue_line '$ '"$*"
}

# xxxxxxxxxxxxx

show_red_line () {
    show_colour_line $RED "$*"
}
alias red_line=show_red_line
alias show_fail=show_red_line

# xxxxxxxxxxxxxxx

show_blue_line () {
    show_colour_line $LIGHT_BLUE "$*"
}
alias blue_line=show_blue_line
# xxxxxxxxxxxxxxx

show_green_line () {
    show_colour_line $GREEN "$*"
}
alias green_line=show_green_line
alias show_pass=show_green_line

# xxxxxxxxxxxxxxxx

show_colour_line () {
    show_colour -n "$@"
}

show_run_command () {
    show_command "$@"
    "$@"
}

show_this_branch () {
    local branch_=$(git rev-parse --abbrev-ref HEAD)
    git branch $1 | grep --colour -B3 -A 3 $branch_
}
