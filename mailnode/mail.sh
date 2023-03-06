#!/bin/sh

cat /home/web/html/sh/mailnode/mail_temp >/home/web/html/sh/mailnode/mail
cat /home/web/html/sh/mailnode/result >>/home/web/html/sh/mailnode/mail

cat /home/web/html/sh/mailnode/signature >>/home/web/html/sh/mailnode/mail

/home/web/html/sh/mailnode/misc-tools/sendjpmail /home/web/html/sh/mailnode/mail

