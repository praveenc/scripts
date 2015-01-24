#!/bin/bash

sudo su debug <<RES
cd /home/debug
if [ -e 'get_ci_results.sh' ]; then
  ./get_ci_results.sh
else
  echo "Cannot find script on $hostname"
fi
RES