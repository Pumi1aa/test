#!/bin/sh

user="guest"
db="oprate"
table="disk"
cluster=$1
cat /home/web/html/sh/maildisk/mail_temp > /home/web/html/sh/maildisk/mail
sed -i s/cluster/$cluster/ /home/web/html/sh/maildisk/mail
query="select * from $table where cluster = '$cluster'"
result=$(mysql -u $user $db -N -e "$query")
declare -a columns=(); declare -a columns=($result)
tot=`expr ${columns[1]} \+ ${columns[2]}`
rate=`echo "scale=5; ${columns[2]} / $tot * 100" | bc|awk '{printf "%.3f", $1}'`
sed -i s/rate/$rate/ /home/web/html/sh/maildisk/mail

rate=`echo "scale=5; 100 - $rate"|bc`
line=`echo -e  "サイズ 使用中 残り 使用率% マウント位置 \n $tot ${columns[1]} ${columns[2]} $rate /home"|column -t  `
echo "$line" >>/home/web/html/sh/maildisk/mail
 
query="select User,$cluster from statdisk where $cluster > 50 order by $cluster desc"
result=$(mysql -u $user $db -N -e "$query")
line=`echo "$result"|sed "s/size/size(GB)/" |column -t `
echo >>/home/web/html/sh/maildisk/mail

echo "$line" >>/home/web/html/sh/maildisk/mail
cat /home/web/html/sh/maildisk/signature >>/home/web/html/sh/maildisk/mail

CR=$(printf '\r')
cat /home/web/html/sh/maildisk/mail | \
    sed "/^\$/s/\$/$CR/" | \
    sed "/[^$CR]\$/s/\$/$CR/" | \
    base64                                       > /home/web/html/sh/maildisk/mail.base64

MAILFILE="/home/web/html/sh/maildisk/msg"
sed s/cluster/$cluster/g /home/web/html/sh/maildisk/header > $MAILFILE
echo '--SECTION'                                 >> $MAILFILE
echo 'Content-Transfer-Encoding: base64'         >> $MAILFILE
echo 'Content-Type: text/plain; charset="UTF-8"' >> $MAILFILE
echo ''                                          >> $MAILFILE
cat /home/web/html/sh/maildisk/mail.base64 >> $MAILFILE

echo '--SECTION'                                 >> $MAILFILE
echo 'Content-Transfer-Encoding: base64'         >> $MAILFILE
echo 'Content-Type: image/png; name="duc.png"'       >> $MAILFILE
echo 'Content-Disposition: attachment; filename="duc.png"' >> $MAILFILE
echo ''                                          >> $MAILFILE
cat /home/web/html/cluster/$1/duc.png | base64                        >> $MAILFILE

echo '--SECTION--' >> ${MAILFILE}

/home/web/html/sh/maildisk/misc-tools/sendjpmail /home/web/html/sh/maildisk/msg

