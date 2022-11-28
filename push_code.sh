#!/bin/bash 
msg=`date +%Y%m%d`
git add --all
git commit -m "add $msg center"
git push origin main
