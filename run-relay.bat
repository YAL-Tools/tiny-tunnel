@echo off
title Relay
node bin/tiny-tunnel.js --relay --host-port 2010 --guest-port 2011
::timeout /t 10