#!/bin/bash

cd `dirname $0`/tests

exitcode=0

box stop name="extensiontests"
box start directory="./" serverConfigFile="./test-server-config.json"
box testbox run verbose=false || exitcode=1
box stop name="extensiontests"

exit $exitcode
