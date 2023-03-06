#!/bin/sh
#各マスターノードのHDD使用率を取得。
#1時間に1度実行される。
#HDDの使用率が90,95,98,99%を超えた場合、各ユーザーの使用率とともにメールで通知する。

user="root"
pass=`openssl rsautl -decrypt -inkey ~/.ssh/id_rsa -in /home/web/.ssh/password.rsa`
db="oprate"
table="disk"

Insert="Insert into $db.$table (cluster,used,avail) values "
for i in `/opt/pbs/bin/qstat -Q |grep work|awk '{print $1}'|cut -c 6-`
do
  j=$i"00"
  line=`sudo -u guest /usr/bin/rsh $j "df -BG 2>/dev/null|grep -w \/home"`
  if [ -z "$line" ]; then
    continue
  fi
  #echo $i $line
  used=`echo $line | awk '{print $3}'|rev|cut -c 2-|rev`
  avail=`echo $line | awk '{print $4}'|rev|cut -c 2-|rev`
  if [ -z $used ]; then
    used="1"
    avail="1"
  fi
  Insert+="(\"$i\",$used,$avail),"
done
Insert=`echo $Insert|rev|cut -c 2- |rev`
Insert+=" on duplicate key update cluster = values(cluster), used = values(used),
         avail = values(avail);"
result=$(mysql -u $user --password=$pass $db -N -e "$Insert")

for i in `/opt/pbs/bin/qstat -Q |grep work|awk '{print $1}'|cut -c 6-`
do
  query="select * from $table where cluster = '$i'"
  result=$(mysql -u $user --password=$pass $db -N -e "$query")
  declare -a columns=(); declare -a columns=($result)
  tot=`expr ${columns[1]} \+ ${columns[2]}`
  rate=`echo "scale=5; ${columns[2]} / $tot * 100" | bc`
  mailflag=0
  for j in 90 95 98 99
  do 
    thres=`expr 100 - $j`
    flag=0
    if [ `echo "$rate <= $thres"|bc` == 1 ]; then
      flag=1
    fi
    query="select mail$j+0 from $table where cluster = '$i'"
    result=$(mysql -u $user --password=$pass $db -N -e "$query")
    if [ "$flag" -ne "$result" ]; then
      #HDD使用率がしきい値が下回った場合
      if [ "$flag" == "0" ]; then
        query="update $db.$table set mail$j=$flag where cluster = '$i'"
        result=$(mysql -u $user --password=$pass $db -N -e "$query")
      fi
      #HDD使用率がしきい値を上回った場合
      if [ "$flag" == "1" ]; then
        query="update $db.$table set mail$j=$flag where cluster = '$i'"
        result=$(mysql -u $user --password=$pass $db -N -e "$query")
        mailflag=1
      fi
    fi
  done
  if [ "$mailflag" == "1" ]; then
    /home/web/html/sh/maildisk/mail.sh $i
  fi
done
