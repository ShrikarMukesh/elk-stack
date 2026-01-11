
sudo systemctl start elasticsearch logstash kibana
sudo systemctl restart elasticsearch logstash kibana

sudo systemctl stop elasticsearch logstash kibana

---

sudo nano /etc/elasticsearch/jvm.options

## Modify these lines: Find the -Xms (initial) and -Xmx (maximum) heap size settings. Change them to:

-Xms512m
-Xmx512m

---

## Logstash is also a Java application and requires its own heap limit.

sudo nano /etc/logstash/jvm.options

---

## Kibana runs on Node.js. It does not use jvm.options. Instead, you must set an environment variable or modify its service file to limit the "max old space size

sudo systemctl edit kibana
[Service]
Environment="NODE_OPTIONS=--max-old-space-size=512"

---
