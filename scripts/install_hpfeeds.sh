#!/bin/bash

set -e
set -x

SCRIPTS=`dirname "$(readlink -f "$0")"`
MHN_HOME=$SCRIPTS/..

apt-get -y update
# this needs to be installed before calling "which pip", otherwise that command fails
apt-get -y install python3 python3-pip git supervisor mongodb

PYTHON3=`which python3`
PIP3=`which pip3`
$PIP3 install virtualenv
VIRTUALENV=`which virtualenv`

$PIP3 install virtualenv

mkdir -p /opt
cd /opt
rm -rf /opt/hpfeeds
git clone https://github.com/hpfeeds/hpfeeds.git
chmod 755 -R hpfeeds
cd hpfeeds
$VIRTUALENV -p $PYTHON3 env
. env/bin/activate

pip install cffi
pip install pyopenssl==23.1.1
pip install pymongo
pip install motor==2.5.1
pip install .
pip install -r requirements.txt
deactivate

mkdir -p /var/log/mhn
mkdir -p /etc/supervisor/
mkdir -p /etc/supervisor/conf.d
mkdir -p /opt/hpfeeds/broker/
cp $SCRIPTS/add_user.py /opt/hpfeeds/broker/add_user.py

cat > /etc/supervisor/conf.d/hpfeeds-broker.conf <<EOF 
[program:hpfeeds-broker]
command=/bin/bash -c 'source /opt/hpfeeds/env/bin/activate && /opt/hpfeeds/env/bin/python /opt/hpfeeds/env/bin/hpfeeds-broker -e tcp:port=10000 --exporter=0.0.0.0:9431 --auth="mongodb://127.0.0.1:27017/hpfeeds"'
directory=/opt/hpfeeds
stdout_logfile=/var/log/mhn/hpfeeds-broker.log
stderr_logfile=/var/log/mhn/hpfeeds-broker.err
autostart=true
autorestart=true
startsecs=10
EOF

/etc/init.d/supervisor start || true
sleep 5
supervisorctl update
