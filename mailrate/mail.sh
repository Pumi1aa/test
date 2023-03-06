#!/bin/sh

cat /home/web/html/sh/mailrate/mail_temp >/home/web/html/sh/mailrate/mail

node=`mktemp`
file=`mktemp`
file1=`mktemp`
trap "rm $node $file $file1" 0 1 2 3 15
id=$1

line=`/opt/pbs/bin/qstat -aw $id|tail -n +6`
user=`echo $line|awk '{print $2}'`
que=`echo $line|awk '{print $3}'`
cpu=`echo $line|awk '{print $7}'`
elap=`echo $line|awk '{print $NF}'`
clus=`echo $que|cut -c 6-`
sed -i s/cluster/$clus/ /home/web/html/sh/mailrate/mail
n=`echo ${#clus}`
n=`expr $n + 2`
/opt/pbs/bin/qstat -n $id|tail -n +7|sed -e s/+/'\n'/g|sed s/\ //g|sed /^$/d|cut -c 1-$n|uniq >$node
m=`cat $node|wc -l`

echo "JobID Username Queue CPU ElapTime" >> $file1
echo $id $user $que $cpu $elap >> $file1

echo "Hostname load-avrg Copy Scale Add Triad" >> $file
for i in `cat $node`
do
  load=`sudo -u guest /usr/bin/rsh $i uptime | awk '{print $(NF-2)}'|rev|cut -c 2-|rev`
  sudo -u guest /usr/bin/rcp /home/web/html/sh/mailrate/memchk/stream_openmp $i:~/
  result=`sudo -u guest /usr/bin/rsh $i /home/guest/stream_openmp` 
  copy=`echo "$result"|grep Copy|awk '{printf $2}'`
  scale=`echo "$result"|grep Scale|awk '{printf $2}'`
  add=`echo "$result"|grep Add|awk '{printf $2}'`
  triad=`echo "$result"|grep Triad|awk '{printf $2}'`
  echo $i $load $copy $scale $add $triad >>$file
done

cat $file1|column -t >> /home/web/html/sh/mailrate/mail 
cat /home/web/html/sh/mailrate/mail_temp2 >> /home/web/html/sh/mailrate/mail
cat $file |column -t >> /home/web/html/sh/mailrate/mail 
cat /home/web/html/sh/mailrate/mail_temp3 >> /home/web/html/sh/mailrate/mail
cat /home/web/html/sh/mailrate/signature >> /home/web/html/sh/mailrate/mail

/home/web/html/sh/mailrate/misc-tools/sendjpmail /home/web/html/sh/mailrate/mail

