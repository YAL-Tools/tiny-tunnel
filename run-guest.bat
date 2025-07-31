@echo off
title Guest
node bin/tiny-tunnel.js --guest --relay-ip 127.0.0.1 --relay-port 2011 --server-port 2012
::node bin/tiny-tunnel.js --guest --relay-ip 164.90.175.236 --relay-port 2011 --server-port 2012
::timeout /t 10