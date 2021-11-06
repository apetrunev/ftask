#!/bin/bash -x

CUR_DIR=$(pwd)

openssl req -x509 -nodes -days 365 -newkey rsa:4096 \
	-keyout ${CUR_DIR}/private.key \
	-out ${CUR_DIR}/self-signed.crt <<ANS

RU
Komi
Syktyvkar


web.local
alexeypetrunev@gmail.com

ANS
