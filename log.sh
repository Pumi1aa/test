#!/bin/sh
#logファイルをコピー
#1時間に1度実行される。
#/var/spool/cron/web

pass=`openssl rsautl -decrypt -inkey ~/.ssh/id_rsa -in /home/web/.ssh/password.rsa`
/usr/bin/sshpass -p $pass ssh root@$j 2>/dev/null << EOF
