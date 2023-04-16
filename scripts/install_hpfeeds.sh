#!/bin/bash

set -e
set -x

SCRIPTS=`dirname "$(readlink -f "$0")"`
MHN_HOME=$SCRIPTS/..

if [ -f /etc/debian_version ]; then
    apt-get -y update
    # this needs to be installed before calling "which pip", otherwise that command fails
    apt-get -y install libffi-dev build-essential python-pip python-dev git libssl-dev supervisor

    PYTHON=`which python`
    PIP=`which pip`
    $PIP install virtualenv
    VIRTUALENV=`which virtualenv`

else
    echo -e "ERROR: Unknown OS\nExiting!"
    exit -1
fi

ldconfig /usr/local/lib/

bash install_mongo.sh

$PIP install virtualenv

mkdir -p /opt
cd /opt
rm -rf /opt/hpfeeds
git clone https://github.com/hpfeeds/hpfeeds.git
chmod 755 -R hpfeeds
cd hpfeeds
$VIRTUALENV -p $PYTHON env
. env/bin/activate

pip install cffi
pip install pyopenssl==17.3.0
pip install pymongo
pip install .
deactivate

mkdir -p /var/log/mhn
mkdir -p /etc/supervisor/
mkdir -p /etc/supervisor/conf.d


cat >> /etc/supervisor/conf.d/hpfeeds-broker.conf <<EOF 
[program:hpfeeds-broker]
command=/opt/hpfeeds/env/bin/python /opt/hpfeeds/broker/feedbroker.py
directory=/opt/hpfeeds
stdout_logfile=/var/log/mhn/hpfeeds-broker.log
stderr_logfile=/var/log/mhn/hpfeeds-broker.err
autostart=true
autorestart=true
startsecs=10
EOF

ldconfig /usr/local/lib/
/etc/init.d/supervisor start || true
sleep 5
supervisorctl update
