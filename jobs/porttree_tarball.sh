#!/bin/sh

cd /var/rsync/release
/bin/tar zcf /tmp/ports.tar.gz.new ports
cp /tmp/ports.tar.gz{.new,.html} 
#chcon -t httpd_sys_content_t /tmp/ports.tar.gz.html
mv -f /tmp/ports.tar.gz.html /var/www/html/distfiles/ports.tar.gz
mv -f /tmp/ports.tar.gz.new /var/rsync/release/ports.tar.gz


