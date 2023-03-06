#!/bin/sh

cat /home/web/html/sh/mailping/mail_temp > /home/web/html/sh/mailping/mail
cat /home/web/html/sh/mailping/list >> /home/web/html/sh/mailping/mail

cat /home/web/html/sh/mailping/signature >>/home/web/html/sh/mailping/mail

/home/web/html/sh/mailping/misc-tools/sendjpmail /home/web/html/sh/mailping/mail

