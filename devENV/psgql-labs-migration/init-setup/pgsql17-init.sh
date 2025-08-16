#!/usr/bin/env bash

set -x
export DEBIAN_FRONTEND=noninteractive

# Install utilities for APT package searching and network management (not required for PostgreSQL)
apt-get install --assume-yes --fix-broken --fix-missing \
  ufw \
  apt-file \
  iproute2

# Configure Uncomplicated Fire Wall (UFW) to allow external-to-VirtualBox ssh and PostgreSQL client connections
ufw allow ssh
if [ ! -f /etc/ufw/applications.d/postgresql ]; then
  cat << 'EOF' > /etc/ufw/applications.d/postgresql
[PostgreSQL]
title=PostgreSQL database access
description=PostgreSQL is a SQL RDBMS that you can connect to via clients such as psql.
ports=5432/tcp
EOF
  ufw allow "PostgreSQL"
fi
ufw --force enable

# Install PostgreSQL Repository
if [ ! -f /usr/share/postgresql-common/pgdg/apt.postgresql.org.sh ]; then
  apt-get install --assume-yes --fix-broken --fix-missing postgresql-common
  /usr/share/postgresql-common/pgdg/apt.postgresql.org.sh
fi

# Install PostgreSQL
if [ ! -f /usr/lib/postgresql/17/bin/postgres ]; then
  apt-get install --assume-yes --fix-broken --fix-missing postgresql-17
fi

# Configure PostgreSQL
if [ ! -f /etc/postgresql/17/main/.configured ]; then
  su postgres << 'EOF'
sed --in-place "s/#listen_addresses = 'localhost'/listen_addresses = '*'/" /etc/postgresql/17/main/postgresql.conf
createuser --superuser vagrant
psql --command="ALTER USER vagrant PASSWORD 'vagrant';"
psql --list --tuples-only --quiet | cut --delimiter=\| --fields=1 | grep --word-regexp --quiet vagrant
if [ $? -ne 0 ]; then
  createdb vagrant --owner=vagrant --encoding=UTF8 --locale=en_US.UTF-8 --lc-ctype=C --lc-collate=C --template=template0
fi
cat << 'END' >> /etc/postgresql/17/main/pg_hba.conf

# Allow created user access
host    vagrant         vagrant         127.0.0.1/32            scram-sha-256
host    vagrant         vagrant         0.0.0.0/0             scram-sha-256
END
EOF
  touch /etc/postgresql/17/main/.configured
  systemctl restart postgresql.service
fi

# Tidy up APT state
apt-get autoremove
apt-get clean
apt-file update

# If any installs flagged that a system reboot was needed for activation, take care of that now
if [ -f /var/run/reboot-required ]; then
  shutdown -r now
fi