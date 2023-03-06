#!/bin/sh
# 各ユーザーの使用率を取得
# 毎日3時に1度実行される。使用率の統計量は月初めにリセットされる。

stat=`mktemp`
trap "rm $stat" 0 1 2 3 15 
declare -a users=(`ls -l /home/|grep users|awk '$1 ~ /d/ {print $3}'`)
for i in `cat /etc/hosts.equiv`
do
  if [ $i == "asuka11" ]; then
    continue
  fi
  sudo -u guest /usr/bin/rsh $i "/sbin/sa -m" 1>>$stat 2>/dev/null
done
wait

db="oprate"
table="statuser"
user="root"
pass=`openssl rsautl -decrypt -inkey ~/.ssh/id_rsa -in /home/web/.ssh/password.rsa`
Insert="Insert into $db.$table (User,time) values"
n=$(( ${#users[*]} - 1 ))
for i in `seq 0 $n`
do
  tot=`grep -w ${users[$i]} $stat|awk '{total+=$4} END {printf "%4.2f\n", total}'`
  Insert+="(\"${users[$i]}\",$tot),"
done
Insert=`echo $Insert|rev|cut -c 2- |rev`
Insert+=" on duplicate key update user = values(user), time = values(time);"
result=$(mysql -u $user --password=$pass $db -N -e "$Insert")
