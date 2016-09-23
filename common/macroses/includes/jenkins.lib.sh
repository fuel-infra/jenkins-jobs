#!/bin/bash
# FIXME: add docs
inject () {
    export "$1=$2"
    echo "$1=$2" >> inject-with-bash.envfile
}