#!/bin/bash

set -e
set -x

SCRIPTS=`dirname "$(readlink -f "$0")"`
MHN_HOME=$SCRIPTS/..

apt-get update
apt-get install -y git python3 python3-pip python2.7 python2.7-dev supervisor mongodb
pip3 install virtualenv

mkdir -p /opt
cd /opt/
rm -rf /opt/mnemosyne
git clone https://github.com/pwnlandia/mnemosyne.git
cd mnemosyne
virtualenv --python=/usr/bin/python2.7 env
. env/bin/activate
pip install -r requirements.txt
chmod 755 -R .

IDENT=mnemosyne
SECRET=`python -c 'import uuid;print str(uuid.uuid4()).replace("-","")'`
CHANNELS='amun.events,conpot.events,thug.events,beeswarm.hive,dionaea.capture,dionaea.connections,thug.files,beeswarn.feeder,cuckoo.analysis,kippo.sessions,cowrie.sessions,glastopf.events,glastopf.files,mwbinary.dionaea.sensorunique,snort.alerts,wordpot.events,p0f.events,suricata.events,shockpot.events,elastichoney.events,drupot.events,agave.events'

cat > /opt/mnemosyne/mnemosyne.cfg <<EOF
[webapi]
host = 0.0.0.0
port = 8181

[mongodb]
database = mnemosyne

[hpfriends]
host = localhost
port = 10000
ident = $IDENT
secret = $SECRET
channels = $CHANNELS

[file_log]
enabled = True
file = /var/log/mhn/mnemosyne.log

[loggly_log]
enabled = False
token =

[normalizer]
ignore_rfc1918 = False
EOF

deactivate
. /opt/hpfeeds/env/bin/activate
python /opt/hpfeeds/broker/add_user.py "$IDENT" "$SECRET" "" "$CHANNELS"

mkdir -p /var/log/mhn/

cat > /etc/supervisor/conf.d/mnemosyne.conf <<EOF 
[program:mnemosyne]
command=/opt/mnemosyne/env/bin/python runner.py --config mnemosyne.cfg
directory=/opt/mnemosyne
stdout_logfile=/var/log/mhn/mnemosyne.out
stderr_logfile=/var/log/mhn/mnemosyne.err
autostart=true
autorestart=true
startsecs=10
EOF

supervisorctl update
