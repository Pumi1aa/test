#!/bin/sh
#各ユーザーのHDD使用率を取得。
#1時間に1度実行される。
#ducコマンドを用いている。

file=`mktemp`
trap 'rm $file' 0 1 2 3 15
pass=`openssl rsautl -decrypt -inkey ~/.ssh/id_rsa -in /home/web/.ssh/password.rsa`
db="oprate"
table="statdisk"

for i in `/opt/pbs/bin/qstat -Q |grep work|awk '{print $1}'|cut -c 6-`
do
  j=$i"00"
  if [ $i == "yoyogi" ]; then
    j=$i
  else
    chk=`sudo -u guest /usr/bin/rsh $j "/usr/local/bin/duc --version 2>/dev/null|grep kyotocabinet"`
    if [ -z "$chk" ]; then
      continue
    fi
    if [ -z "$chk" ];  then
      /usr/bin/sshpass -p $pass ssh root@$j &>/dev/null << EOF
      if [ -f /root/duc-1.4.4.tar.gz ]; then
        exit
      fi
      yum install -y kyotocabinet-devel
      wget https://github.com/zevv/duc/releases/download/1.4.4/duc-1.4.4.tar.gz
      tar -xf duc-1.4.4.tar.gz
      cd /root/duc-1.4.4
      ./configure --with-db-backend=kyotocabinet
      make
      make install
EOF
    fi
  fi
  chk=`/usr/bin/sshpass -p $pass ssh root@$j 2>/dev/null "ps x|grep duc|grep -v grep|grep -w /home"`
  if [ -n "$chk" ]; then
    continue
  fi
  /usr/bin/sshpass -p $pass ssh root@$j 2>/dev/null << EOF
  #ionice -c 3 /usr/local/bin/duc index -q --max-depth=5 /home
  ionice -c 3 /usr/local/bin/duc index -q /home
  cp -rf /root/.duc.db* /home/guest/
EOF
  sudo -u guest /usr/bin/rsh $j "ionice -c 3 /usr/local/bin/duc ls -b /home" >$file
  sudo -u guest /usr/bin/rsh $j "ionice -c 3 /usr/local/bin/duc graph /home; rcp /home/guest/duc.png fep:/home/guest/"
  cp /home/guest/duc.png /home/web/html/cluster/$i
  Insert="insert into $db.$table ($i,User) values"
  for j in `cat $file`
  do
    if [[ "$j" =~ ^[0-9]+$ ]]; then
      k=`expr $j \/ 1024 \/ 1024 \/ 1024`
      Insert+="($k,"
    else 
      Insert+="\"$j\"),"
    fi
  done
  Insert=`echo $Insert|rev|cut -c 2-|rev`
  Insert+=" on duplicate key update User = values(User), $i = values($i);"
  result=$(mysql -u root --password=$pass $db -N -e "$Insert")
done
