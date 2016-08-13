#!/bin/bash

set -e

role=$1
pg_data=/var/lib/postgresql/9.5/main

# Place configs
cd /code
mv /etc/postgresql /etc/postgresql.bak
cp -r postgresql-$role /etc/postgresql
chown -R postgres:postgres /etc/postgresql/*
sudo -u postgres rm -rf $pg_data

if [ $role == master ]; then

	rm -rf /var/lib/postgresql/*
	sudo -u postgres /usr/lib/postgresql/9.5/bin/initdb $pg_data
	find /var/lib/postgresql
	# Start server
	/etc/init.d/postgresql start

	sudo -u postgres psql -c "CREATE USER replicator REPLICATION LOGIN ENCRYPTED PASSWORD 'thepassword';"
	echo 'hi' | nc -l 9001
fi


if [ $role == slave ]; then
	sudo -u postgres bash -c 'echo "postgres-shards-master:*:*:*:thepassword" > ~postgres/.pgpass && chmod 600 ~postgres/.pgpass'

	echo Waiting for master
	./wait-for-it.sh postgres-shards-master:9001 -s -t 0

    echo Starting base backup as replicator
    sudo -u postgres pg_basebackup -h postgres-shards-master -D $pg_data -U replicator -v -P

    echo Writing recovery.conf file
	cp /etc/postgresql/9.5/main/recovery.conf $pg_data/

	echo Preparing data directory
    rm $pg_data/backup_label
	sudo -u postgres /usr/lib/postgresql/9.5/bin/pg_resetxlog -f $pg_data

	# Start server
	/etc/init.d/postgresql start
fi



# Monitor
cd /var/log
tail -f postgresql/postgresql-9.5-main.log

