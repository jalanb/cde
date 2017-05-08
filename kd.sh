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

export KD_DIR=$(dirname $(readlink -f $BASH_SOURCE))
PYTHON=${PYTHON:-python}
KD_PATH_ONLY=0

kd () {
    local _kd_script=$KD_DIR/kd.py
    local _kd_result=1
    local _kd_options=
    [[ $KD_PATH_ONLY == 1 ]] && _kd_options=--one
    if ! destination=$(PYTHONPATH=$KD_DIR $PYTHON $_kd_script $_kd_options "$@" 2>&1)
    then
        echo "$destination"
    elif [[ $destination =~ ^[uU]sage ]]; then
        PYTHONPATH=$KD_DIR $PYTHON $_kd_script "$@"
    else
        local real_destination=$(PYTHONPATH=$KD_DIR $PYTHON -c "import os; print os.path.realpath('$destination')")
        if [[ "$destination" != "$real_destination" ]]
        then
            echo "cd ($destination ->) $real_destination"
            destination="$real_destination"
        elif [[ "$destination" != $(readlink -f "$1") && $1 != "-" ]]
        then
            [[ -n $KD_QUIET ]] || echo "cd $destination"
        fi
       if [[ $KD_PATH_ONLY == 1 ]]; then
            echo "$destination"
        else
            same_path . "$destination" || pushd "$destination" >/dev/null 2>&1
        fi
        _kd_result=0
    fi
    unset destination
    return $_kd_result
}

kg ()
{
    local __doc__="Debug the kd function and script"
    set -x
    kd -U "$@"
    set +x
}

kp () {
    local __doc__="Show the path that kd would go to"
    KD_QUIET=1 KD_PATH_ONLY=1 kd "$@"; KD_PATH_ONLY=0
}

kpp () {
    if [[ -n "$1" ]]; then
        kp "$@"
    else
        kp .
    fi
}

same_path () {
    [[ $(readlink -f "$1") == $(readlink -f "$2") ]]
}

[[ -n $WELCOME_BYE ]] && echo Bye from $(basename "$BASH_SOURCE") in $(dirname $(readlink -f "$BASH_SOURCE")) on $(hostname -f)
