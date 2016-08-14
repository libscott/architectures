#!/bin/bash

set -e

role=$1
pgdata=/var/lib/postgresql/9.5/main

P="sudo -u postgres"
# Place configs
cd /code
mv /etc/postgresql /etc/postgresql.bak
cp -r postgresql-$role /etc/postgresql
chown -R postgres:postgres /etc/postgresql/*

if [ $role == master ]; then

    echo "Create archive folder"
    $P mkdir "$pgdata/archive"
	echo "Start server"
	/etc/init.d/postgresql start
    echo "Create replicator user"
	$P psql -c "CREATE USER replicator REPLICATION LOGIN ENCRYPTED PASSWORD 'thepassword';"
    echo "Master ready"
	echo '' | nc -l 9001
fi


if [ $role == slave ]; then
    echo "Create .pgpass"
	$P bash -c 'echo "postgres-master:*:*:*:thepassword" > ~postgres/.pgpass && chmod 600 ~postgres/.pgpass'

	echo "Waiting for master"
	./wait-for-it.sh postgres-master:9001 -s -t 0

    echo "Starting base backup as replicator"
    $P rm -rf $pgdata
    $P pg_basebackup -h postgres-master -D $pgdata -U replicator -v -X stream

    echo "Write recovery.conf file"
	cp /etc/postgresql/9.5/main/recovery.conf $pgdata/

	echo "Start server"
	/etc/init.d/postgresql start
    
    echo "Slave ready"
fi

echo "Monitoring"
cd /var/log
tail -f postgresql/postgresql-9.5-main.log

