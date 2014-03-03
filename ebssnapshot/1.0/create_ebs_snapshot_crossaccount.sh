#!/bin/bash

volume_id=$1
generation=$2
role_arn=$3

day=$(date '+%Y%m%d')
logdir=$PWD/log
logfile=${logdir}/$(basename $0)_${day}.log
ruby_ver="default"

if [ -d ${logdir} ]; then
  true
else
  mkdir -p ${logdir}
fi

source $PWD/.rvm/scripts/rvm 
#rvm use 2.0.0 > /dev/null
cd $PWD
$HOME/.rvm/rubies/${ruby_ver}/bin/ruby ./create_ebs_snapshot_crossaccount.rb -v $volume_id -g $generation -r $role_arn \
>> ${logfile} 2>&1
