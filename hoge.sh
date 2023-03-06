#!/bin/sh

for j in asuka00 hoge
do
  load=`sudo -u guest /usr/bin/rsh $j uptime 2>/dev/null | awk '{print $NF}'`
  echo $load
done
