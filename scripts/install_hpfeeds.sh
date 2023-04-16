#!/bin/bash

set -e
set -x

SCRIPTS=`dirname "$(readlink -f "$0")"`
MHN_HOME=$SCRIPTS/..

if [ -f /etc/debian_version ]; then
    apt-get -y update
    # this needs to be installed before calling "which pip", otherwise that command fails
    apt-get -y install libffi-dev build-essential python-pip python-dev python3 python3-pip git libssl-dev supervisor

    PYTHON=`which python`
    PYTHON3=`which python3`
    PIP=`which pip`
    PIP3=`which pip3`
    $PIP3 install virtualenv
    VIRTUALENV=`which virtualenv`

else
    echo -e "ERROR: Unknown OS\nExiting!"
    exit -1
fi

ldconfig /usr/local/lib/

bash install_mongo.sh

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
pip install pyopenssl==17.3.0
pip install pymongo
pip install .
pip install -r requirements.txt
deactivate

mkdir -p /var/log/mhn
mkdir -p /etc/supervisor/
mkdir -p /etc/supervisor/conf.d

cat > /opt/hpfeeds/users.json <<EOF
{
  "my-user-ident": {
    "owner": "my-owner",
    "secret": "my-really-strong-passphrase",
    "subchans": ["chan1"],
    "pubchans": ["chan2"]
  }
}
EOF

cat > /etc/supervisor/conf.d/hpfeeds-broker.conf <<EOF 
[program:hpfeeds-broker]
command=/bin/bash -c 'source /opt/hpfeeds/env/bin/activate && /opt/hpfeeds/env/bin/python /opt/hpfeeds/env/bin/hpfeeds-broker -e tcp:port=10000 --exporter=0.0.0.0:9431 --auth=/opt/hpfeeds/users.json'
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
