#!/bin/bash

sudo yum install httpd -y

sudo apachectl start
sudo systemctl enable httpd

sudo firewall-cmd --zone=public --add-service=http
sudo firewall-cmd --permanent --zone=public --add-service=http

cd /var/www/html/

sudo wget https://objectstorage.us-ashburn-1.oraclecloud.com/p/u8j40_AS-7pRypC5boQT24w5QFPDTy-0j27BWBOfmsxbERTiuDtJQBIqfcsOH81F/n/idqfa2z2mift/b/bootcamp-oci/o/oci-f-handson-modulo-compute-website-files.zip

sudo unzip oci-f-handson-modulo-compute-website-files.zip

sudo chown -R apache:apache /var/www/html

sudo rm -rf oci-f-handson-modulo-compute-website-files.zip