#!/bin/bash
yum install -y httpd
echo "Instance launched by terraform autoscaling group" > /var/www/html/index.html
systemctl start httpd
systemctl enable httpd
