#! /bin/bash

# This script is intended to be sourced, not run
if [[ $0 == $BASH_SOURCE ]]
then
    echo "This file should be run as"
    echo "  source $0"
    echo "and should not be run as"
    echo "  sh $0"
fi

kd ()
{ 
	local kd_source_dir=$(dirname $BASH_SOURCE)
	local kd_script=$kd_source_dir/kd.py
	value=1
	if ! destination=$(PYTHONPATH=$kd_source_dir python $kd_script "$@" 2>&1)
	then
		echo "$destination"
	else
		local real_destination=$(PYTHONPATH=$kd_source_dir python -c "import os; print os.path.realpath('$destination')")
		if [[ $destination != $real_destination ]]
		then
			echo "cd ($destination ->) $real_destination"
			destination=$real_destination
		elif [[ $destination != $1 && $1 != "-" ]]
		then
			echo "cd $destination"
		fi
		cd "$destination"
		value=0
	fi
	unset destination
	return $value
}

kg ()
{
	local kd_source_dir=$(dirname $BASH_SOURCE)
	local kd_script=$kd_source_dir/kd.py
	PYTHONPATH=$kd_source_dir python $kd_script -U "$@"
}
