#!/bin/bash
TYPE=$1
NAME=$2
STATE=$3

echo $STATE > /run/keepalived.state
