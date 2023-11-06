#!/bin/sh

CURRENT_DIR=`dirname "$0"`

. $CURRENT_DIR/_common.sh

exe toys server stop

exe git checkout $1
exe git pull origin $1

exe $CURRENT_DIR/setup.sh "$@"

exe toys server start
