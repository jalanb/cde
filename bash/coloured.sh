#! /bin/cat

# xxxxxxx

_colour () {
    printf "$*""${NO_COLOUR}" >&2
}
# xxxxxxxx

show_red () {
    _colour "${RED}""$*"
}

# xxxxxxxxxx

error_line () {
    red_line "$@" >&2 && return 1
}

show_green () {
    _colour "${GREEN}""$*"
}

# xxxxxxxxxxx

# xxxxxxxxxxxx

show_command () {
    green_line "$ ""$*"
}

# xxxxxxxxxxxxx

red_line () {
    colour_line "${RED}""$*"
}
alias red_line=red_line
alias fail_line=red_line

# xxxxxxxxxxxxxxx

green_line () {
    colour_line "${GREEN}""$*"
}
alias green_line=green_line
alias pass_line=green_line

# xxxxxxxxxxxxxxxx

colour_line () {
    printf "$*""${NO_COLOUR}\n" >&2
}

show_run_command () {
    show_command "$@"
    "$@"
}

show_this_branch () {
    git branch $1 | grep --colour -B3 -A 3 $(current_branch)
}
