#!/bin/sh
# PBS Proに追加されたクラスタをデータベースに追加
# 1日に1度実行される。
# htmlページやグラフについても更新される。

pass=`openssl rsautl -decrypt -inkey ~/.ssh/id_rsa -in /home/web/.ssh/password.rsa`
db="oprate"
table1="rldavrg"
table2="pbsavrg"
table3="statdisk"
table4="disk"

# PBSに追加されたクラスタを追加
sql="SELECT COLUMN_NAME FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = 'oprate' AND TABLE_NAME = 'rldavrg'"
result=$(mysql -u root --password=$pass $db -N -e "$sql")
declare -a ary=($result)
clus=`echo ${ary[*]} |awk '{print $(NF-1)}'`
for i in `/opt/pbs/bin/qstat -Q|grep work|awk '{print $1}'|cut -c 6-`
do 
  if ! `echo ${ary[*]}|grep -q "$i"` ; then
    alter="alter table $db.$table1 add $i float default 0 after $clus"
    result=$(mysql -u root --password=$pass $db -N -e "$alter")
    alter="alter table $db.$table2 add $i float default 0 after $clus"
    result=$(mysql -u root --password=$pass $db -N -e "$alter")
    alter="alter table $db.$table3 add $i float default 0"
    result=$(mysql -u root --password=$pass $db -N -e "$alter")
    /home/web/html/cluster/mkclus.sh
  fi
done

# PBSから外されたクラスタを削除
file=`mktemp`
trap "rm $file" 0 1 2 3 15
/opt/pbs/bin/qstat -Q|grep work|awk '{print $1}'|cut -c 6- >$file
sql="select cluster from disk"
result=$(mysql -u root --password=$pass $db -N -e "$sql")
declare -a ary=($result)
n=`expr ${#ary[@]} - 1`
for i in `seq 0 $n`
do 
  if ! `cat $file|grep -q "${ary[$i]}"` ; then
    alter="alter table $db.$table1 drop  ${ary[$i]}"
    result=$(mysql -u root --password=$pass $db -N -e "$alter")
    alter="alter table $db.$table2 drop  ${ary[$i]}"
    result=$(mysql -u root --password=$pass $db -N -e "$alter")
    alter="alter table $db.$table3 drop  ${ary[$i]}"
    result=$(mysql -u root --password=$pass $db -N -e "$alter")
    alter="delete from $db.$table4 where cluster = '${ary[$i]}'"
    result=$(mysql -u root --password=$pass $db -N -e "$alter")
  fi
done


