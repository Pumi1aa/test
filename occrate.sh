#!/bin/sh
#PBS実行ジョブについて実稼働率を取得。
#1時間に1度実行される。
#実稼働率（load average）が40%以下の状態が12時間連続している場合に
#使用している各計算機のload averageとメモリバンド幅の性能をメールで通知する。

file=`mktemp`
node=`mktemp`
pbs=`mktemp`
trap "rm $file $node $pbs" 0 1 2 3 15
user="root"
pass=`openssl rsautl -decrypt -inkey ~/.ssh/id_rsa -in /home/web/.ssh/password.rsa`
db="oprate"
table="occrate"
Inflag=false

/opt/pbs/bin/qstat -r |tail -n +6|awk '{print $1}' > $file
sudo /opt/pbs/bin/pbsnodes -a > $pbs
Insert="Insert into $db.$table (queue,JobID,user,elaptime) values"
# データベースに新規ジョブを追加
for i in `cat $file`
do
  line=`/opt/pbs/bin/qstat -aw $i 2>/dev/null|tail -n +6 `
  if [ -z "$line" ]; then
    continue
  fi
  id=`echo $line|awk '{print $1}'`
  user=`echo $line|awk '{print $2}'`
  que=`echo $line|awk '{print $3}'`
  cpu=`echo $line|awk '{print $7}'`
  elap=`echo $line|awk '{print $NF}'`
  clus=`echo $que|cut -c 6-`
  n=`echo ${#clus}`
  n=`expr $n + 2`
  avrg=0;tot=0
  /opt/pbs/bin/qstat -n $i|tail -n +7|sed -e s/+/'\n'/g|sed s/\ //g|sed /^$/d|cut -c 1-$n|uniq >$node
  m=`cat $node|wc -l`
  for j in `cat $node`
  do
    avail=`cat $pbs|grep -A 15 "Mom = $j"|grep resources_available.ncpus|awk '{print $NF}'`
    tot=`expr $tot + $avail`
    load=`sudo -u guest /usr/bin/rsh $j uptime 2>/dev/null | awk '{print $NF}'`
    if [ -z "$load" ]; then
      continue
    fi
    avrg=`echo "scale=3; $avrg + $load/$avail/$m*100"|bc`
  #  echo $i $j
  done
  rate=`echo "scale=3; $cpu/$tot*100"|bc`

  if [ `echo "scale=3; $rate * 0.4 > $avrg"|bc` == 1 ]; then
    Insert+=" (\"$que\", \"$id\", \"$user\", \"$elap\"), "
    Inflag=true
  fi
done

if "${Inflag}"; then
  Insert=`echo $Insert|rev|cut -c 2- |rev`
  Insert+=" on duplicate key update count = count + 1;"
  result=$(mysql -u root --password=$pass $db -N -e "$Insert")
fi

# データベースから終了したジョブを削除
sql="select JobID from $db.$table"
result=$(mysql -u root --password=$pass $db -N -e "$sql")
declare -a list=(); declare -a list=($result)
n=${#list[@]}
n=`expr $n - 1`
for i in `seq 0 $n`
do
  chk=`grep ${list[$i]} $file`
  if [ -z "$chk" ]; then
     sql="delete from $db.$table where JobID='${list[$i]}'"
     result=$(mysql -u root --password=$pass $db -N -e "$sql")
  fi
done

# 12時間以上稼働率が低い場合
sql="select JobID,count from $db.$table"
result=$(mysql -u root --password=$pass $db -N -e "$sql")
declare -a ary=(); declare -a ary=($result)
n=${#ary[@]}
n=`expr $n / 2 - 1`
for i in `seq 0 $n`
do
  j=`expr $i \* 2`
  k=`expr $i \* 2 + 1`
  #echo ${ary[$j]} ${ary[$k]}
  if [ ${ary[$k]} == 12 ]; then
    /home/web/html/sh/mailrate/mail.sh ${ary[$j]}
  fi
done

