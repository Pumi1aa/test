#!/bin/bash
#各計算ノードのHDD使用率を取得。
#1時間に1度実行される。
#HDDの使用率が90%を超えた場合、メールで通知する。

#一時ファイルの設定
file=`mktemp`
file1=`mktemp`
file2=`mktemp`
trap "rm $file $file1 $file2" 0 1 2 3 15
sudo /opt/pbs/bin/pbsnodes -a > $file
# データベース引数
user="root"
pass=`openssl rsautl -decrypt -inkey ~/.ssh/id_rsa -in /home/web/.ssh/password.rsa`
db="oprate"
table="disk_node"
Insert="insert into $db.$table (node,route,work) values  "
Inflag=false

# 各クラスターについてループ
for i in `/opt/pbs/bin/qstat -Q |grep work|awk '{print $1}'|cut -c 6-`
do
  clus=`expr $clus \+ 1`
  node=`cat $file | grep "partition = $i" -A 2 -B 21 | grep "Mom =" | awk '{print $3}'`
  declare -a ary0=(); declare -a ary0=($node)
  nodes=${#ary0[*]}
  nodes=`expr $nodes \- 1`
  # 各スレーブノードについてループ
  for j in `seq 0 $nodes`
  do
    chk=`/usr/sbin/fping -admq -t 50 -i 10 -r 1 ${ary0[$j]}`
    if [ -z "$chk" ]; then
      # ダウンしているとき
      continue
    fi
    line=`sudo -u guest /usr/bin/rsh ${ary0[$j]} " df / /work 2>/dev/null|tail -n 2"`
    if [ -z "$line" ]; then
      continue
    fi
    route=`echo "$line" |head -n 1 |awk '{print $5}'|sed -e s/%//g`
    work=`echo "$line" |tail -n 1 |awk '{print $5}'|sed -e s/%//g`
    if [ $route -ge 90 ] || [ $work -ge 90 ]; then
      echo ${ary0[$j]} >> $file2
      Inflag=true
      Insert+="(\"${ary0[$j]}\", $route, $work),"
    fi
  done
done

#HDD使用率がしきい値が下回った場合
sql="select node from $db.$table;"
result=$(mysql -u $user --password=$pass $db -N -e "$sql")
declare -a ary0=(); declare -a ary0=($result)
n=`expr ${#ary0[@]} - 1`
for i in `seq 0 $n`
do
   chk=`grep ${ary0[$i]} $file2`
   if [ -z "$chk" ]; then
     sql="delete from $db.$table where node='${ary0[$i]}'"
     result=$(mysql -u $user --password=$pass $db -N -e "$sql")
   fi
done

#HDD使用率がしきい値が上回った場合
if "${Inflag}"; then
  Insert=`echo $Insert|rev|cut -c 2- |rev`
  Insert+=" on duplicate key update node = values(node), mail=b'1';"
  result=$(mysql -u $user --password=$pass $db -N -e "$Insert")
fi

sql="select node,route,work from $db.$table where mail=0;"
result=$(mysql -u $user --password=$pass $db -N -e "$sql")

if [ -n "$result" ]; then
  : > $file1
  echo "計算機"  "使用%" >> $file1
  echo "　　" "/" "/work" >> $file1
  declare -a ary=(); declare -a ary=($result)
  n=${#ary[@]}
  n=`expr $n / 3`
  for i in `seq 1 $n`
  do
    j=`expr 3 \* $i - 3`;k=`expr 3 \* $i - 2`;l=`expr 3 \* $i - 1`;
    echo  "${ary[$j]} ${ary[$k]}"%" ${ary[$l]}"%" "|sed -e s/.cms.net//g >> $file1
  done
  cat $file1 |column -t > /home/web/html/sh/mailnode/result
  /home/web/html/sh/mailnode/mail.sh
fi
