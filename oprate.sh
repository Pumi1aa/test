#!/bin/bash
#各計算機のCPU使用率とPBSの使用率を取得。
#1時間に1度実行される。

time=`date +%y-%m-%d\ %R:%S`
cluster=`/opt/pbs/bin/qstat -Q |grep work|awk '{print $1}'|cut -c 6-|sed -z 's/\n/,/g'`
#一時ファイルの設定
file=`mktemp`
trap "rm $file" 0 1 2 3 15
sudo /opt/pbs/bin/pbsnodes -a > $file
# データベース引数
user="root"
pass=`openssl rsautl -decrypt -inkey ~/.ssh/id_rsa -in /home/web/.ssh/password.rsa`
table=rldavrg
tablep=pbsavrg
Insert="insert into oprate."$table" (time,"$cluster"total) values('"$time"',"
Insertp="insert into oprate."$tablep" (time,"$cluster"total) values('"$time"',"

# 各クラスターについてループ
tot=0;totp=0;clus=0;
for i in `/opt/pbs/bin/qstat -Q |grep work|awk '{print $1}'|cut -c 6-`
do
  clus=`expr $clus \+ 1`
  node=`cat $file | grep "partition = $i" -A 2 -B 21 | grep "Mom =" | awk '{print $3}'`
  state=`cat $file | grep "partition = $i" -A 2 -B 21 | grep "state =" |awk '{print $3}'`
  avail=`cat $file | grep "partition = $i" -A 2 -B 21 | grep resources_available.ncpus | awk '{print $3}'`
  assign=`cat $file | grep "partition = $i" -A 2 -B 21 | grep resources_assigned.ncpus | awk '{print $3}'`
  declare -a ary0=(); declare -a ary0=($node)
  declare -a ary1=(); declare -a ary1=($state)
  declare -a ary2=(); declare -a ary2=($avail)
  declare -a ary3=(); declare -a ary3=($assign)
  nodes=${#ary0[*]}
  nodes=`expr $nodes \- 1`
  # 各スレーブノードについてループ
  avrg=0;pbs=0;nnode=1
  for j in `seq 0 $nodes`
  do
    chk=`/usr/sbin/fping -admq -t 50 -i 10 -r 1 ${ary0[$j]}`
    if [ -z "$chk" ]; then
      # ダウンしているとき
      continue
    fi
    # loadavrgの計算。直近15分以内の平均負荷。
    nnode=`expr $nnode \+ 1`
    load=`sudo -u guest /usr/bin/rsh ${ary0[$j]} uptime 2>/dev/null | awk '{print $NF}'`
    if [ -z "$load" ]; then
      continue
    fi
    avrg=`echo "sacle=3; $avrg + $load" | bc`
    pbs=`expr $pbs \+ ${ary3[$j]}`
    # ypbindが切れている時にbindする
    yp=`sudo -u guest /usr/bin/rsh ${ary0[$j]} /usr/bin/ypwhich 2>/dev/null|grep ns1`
    if [ -z "$yp" ]; then
#      echo "ypbind" ${ary0[$j]}
      /usr/bin/sshpass -p `openssl rsautl -decrypt -inkey ~/.ssh/id_rsa -in ~/.ssh/password.rsa` ssh root@${ary0[$j]} "/usr/sbin/ypbind 2>/dev/null"
    fi
    wait
# TCPポート枯渇対策    
    sleep 1m
  done
  #統計処理
  if [ $nnode -ne 0 -a ${ary2[$j]} -ne 0 ]; then
    avrg=`echo "scale=3; $avrg/$nnode/${ary2[$j]}*100"|bc`
    pbs=`echo "scale=3; $pbs/$nnode/${ary2[$j]}*100"|bc`
  fi
  if [ -z "$avrg" ]; then
    avrg=0
  fi
  tot=`echo "scale=3; $tot + $avrg"|bc`
  totp=`echo "scale=3; $totp + $pbs"|bc`
  Insert+="$avrg,"
  Insertp+="$pbs,"
done
# 全計算機の平均値
tot=`echo "scale=3; $tot/$clus"|bc`
totp=`echo "scale=3; $totp/$clus"|bc`
Insert+="$tot);"
Insertp+="$totp);"
#echo $Insert $Insertp

result=$(mysql -u $user --password=$pass $db -N -e "$Insert")
result=$(mysql -u $user --password=$pass $db -N -e "$Insertp")
