#!/bin/sh

n=2
m=`expr $n - 1`
node=("fep" "date00")
tgt=("/mnt/share/save" "/mnt/home2")

file=`mktemp`
trap 'rm $file' 0 1 2 3 15
user="root"
pass=`openssl rsautl -decrypt -inkey ~/.ssh/id_rsa -in /home/web/.ssh/password.rsa`
db="oprate"
table="statdisk_others"

sql="SELECT COLUMN_NAME FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = '$db' AND TABLE_NAME = '$table'"
result=$(mysql -u root --password=$pass $db -N -e "$sql")
declare -a ary=($result)
for i in `seq 0 $m`
do 
  if ! `echo ${ary[*]}|grep -q "${node[$i]}"` ; then
    alter="alter table $db.$table add ${node[$i]} float default 0"
    result=$(mysql -u root --password=$pass $db -N -e "$alter")
#    /home/web/html/cluster/mkclus.sh
  fi
done

exit

for i in `seq 0 $m`
do
 # sudo -u guest /usr/bin/rsh ${node[$i]} "ionice -c 3 /bin/duc index -q --max-depth=5 ${tgt[$i]}"
  sudo -u guest /usr/bin/rsh ${node[$i]} "ionice -c 3 /bin/duc ls -b ${tgt[$i]} 2>/dev/null" >$file
  if [ -z "$line" ]; then
    continue
  fi
  Insert="Insert into $db.$table (${node[$i]},User) values "
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
  Insert+=" on duplicate key update User = values(User), ${node[$i]} = values(${node[$i]});"
  result=$(mysql -u root --password=$pass $db -N -e "$Insert")
done



