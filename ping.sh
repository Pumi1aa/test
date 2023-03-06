#!/bin/sh
#192.168.100.*の計算機についてpingを確認。
#1時間に1度実行される。
#pingが2回連続で通らなかった場合、計算機がダウンした旨をメールで通知する。


tail -n +11 /home/web/html/tmp/cms.net.zone| grep "192.168.100" > /home/web/html/tmp/ping.dat
filedown=`mktemp`
filealive=`mktemp`
trap "rm $filedown $filealive" 0 1 2 3 15
user="root"
pass=`openssl rsautl -decrypt -inkey ~/.ssh/id_rsa -in /home/web/.ssh/password.rsa`
db="oprate"
table="alive"
date=`date "+%Y-%m-%d %H:%M"`

/usr/sbin/fping -admq -t 50 -i 10 -r 1 -f /home/web/html/tmp/ping.dat >$filealive
reset="truncate table $db.$table"
result=$(mysql -u $user --password=$pass $db -N -e "$reset")
Insert="Insert into $db.$table (cluster) values"
for i in `cat $filealive`
do
  Insert+="(\""$i"\"),"
done
Insert=`echo $Insert|rev|cut -c 2-|rev`
Insert+=" on duplicate key update cluster = values(cluster);"
result=$(mysql -u $user --password=$pass $db -N -e "$Insert")

table="ping"
/usr/sbin/fping -qum -t 50 -i 10 -r 1 -f /home/web/html/tmp/ping.dat >$filedown
sql="select cluster from $db.$table;"
result=$(mysql -u $user --password=$pass $db -N -e "$sql")
declare -a ary0=(); declare -a ary0=($result)
sql="select mail+0 from $db.$table;"
result=$(mysql -u $user --password=$pass $db -N -e "$sql")
declare -a ary1=(); declare -a ary1=($result)
n=$(( ${#ary0[*]} - 1 ))

mailflag=false
for i in `seq 0 $n`
do
  cluster=`grep ${ary0[$i]} $filedown`
  if [ -n "$cluster" ]; then
    if [ ${ary1[$i]} == 0 ] ; then
      sql="update $db.$table set mail=true where cluster='${ary0[$i]}' "
      result=$(mysql -u $user --password=$pass $db -N -e "$sql")
      list+=`echo "${ary0[$i]} \n"`
      mailflag=true
    else
      #echo ${ary1[$i]}
      :
    fi
  else
    sql="delete from $db.$table where cluster='${ary0[$i]}'"
    result=$(mysql -u $user --password=$pass $db -N -e "$sql")
  fi
done
if "${mailflag}"; then
  echo -e -n "$list" |column -x > /home/web/html/sh/mailping/list
  /home/web/html/sh/mailping/mail.sh
fi

Insert="Insert into $db.$table (cluster,time) values"
Inflag=false
for i in `cat $filedown`
do
  if  ! `echo ${ary0[@]}|grep -q $i` ; then
    Insert+="(\"$i\",\"$date\"),"
    Inflag=true
  fi
done
Insert=`echo $Insert|rev|cut -c 2- |rev`;Insert+=";"
if "${Inflag}"; then
  result=$(mysql -u $user --password=$pass $db -N -e "$Insert")
fi
