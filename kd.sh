#! /bin/cat

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

kd ()
{
    local kd_script=$KD_DIR/kd.py
    kd_result=1
    if ! destination=$(PYTHONPATH=$KD_DIR $PYTHON $kd_script "$@" 2>&1)
    then
        echo "$destination"
    elif [[ $destination =~ ^[uU]sage ]]; then
        PYTHONPATH=$KD_DIR $PYTHON $kd_script "$@"
    else
        local real_destination=$(PYTHONPATH=$KD_DIR $PYTHON -c "import os; print os.path.realpath('$destination')")
        if [[ $destination != $real_destination ]]
        then
            echo "cd ($destination ->) $real_destination"
            destination=$real_destination
        elif [[ $destination != $1 && $1 != "-" ]]
        then
            echo "cd $destination"
        fi
        cd "$destination"
        kd_result=0
    fi
    unset destination
    return $kd_result
}

kg ()
{
    local __doc__="Debug the kd function and script"
    set -x
    kd -U "$@"
    set +x
}

# echo from kd.sh
