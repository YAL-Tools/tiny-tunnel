@echo off
title Host
node bin/tiny-tunnel.js --host --relay-ip 127.0.0.1 --relay-port 2010 --connect-port 25565
::timeout /t 10