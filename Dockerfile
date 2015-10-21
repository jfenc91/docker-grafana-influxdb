FROM	node:0.12.7-wheezy

ENV GRAFANA_VERSION 1.9.1
ENV INFLUXDB_VERSION 0.8.8

# Prevent some error messages
ENV DEBIAN_FRONTEND noninteractive

#RUN		echo 'deb http://us.archive.ubuntu.com/ubuntu/ trusty universe' >> /etc/apt/sources.list
RUN		apt-get -y update && apt-get -y upgrade

# ---------------- #
#   Installation   #
# ---------------- #

# Install all prerequisites
RUN	apt-get -y install wget nginx-light supervisor curl unzip
#RUN apt-get -y install make gcc g++

# Install node for statsd
#RUN \
#  cd /tmp && \
#  wget http://nodejs.org/dist/node-latest.tar.gz && \
#  tar xvzf node-latest.tar.gz && \
#  rm -f node-latest.tar.gz && \
#  cd node-v* && \
#  ./configure && \
#  CXX="g++ -Wno-unused-local-typedefs" make && \
#  CXX="g++ -Wno-unused-local-typedefs" make install && \
#  cd /tmp && \
#  rm -rf /tmp/node-v* && \
#  npm install -g npm && \
#  printf '\n# Node.js\nexport PATH="node_modules/.bin:$PATH"' >> /root/.bashrc
  
#RUN 	apt-get -y install software-properties-common
#RUN		add-apt-repository -y ppa:chris-lea/node.js && apt-get -y update
#RUN		apt-get -y install python-django-tagging python-simplejson python-memcache python-ldap python-cairo \
#			python-pysqlite2 python-support python-pip gunicorn nodejs git openjdk-7-jre build-essential python-dev

# Install Grafana to /src/grafana
RUN		mkdir -p src/grafana && cd src/grafana && \
			wget http://grafanarel.s3.amazonaws.com/grafana-${GRAFANA_VERSION}.tar.gz -O grafana.tar.gz && \
			tar xzf grafana.tar.gz --strip-components=1 && rm grafana.tar.gz

# Install InfluxDB
RUN		wget http://s3.amazonaws.com/influxdb/influxdb_${INFLUXDB_VERSION}_amd64.deb && \
			dpkg -i influxdb_${INFLUXDB_VERSION}_amd64.deb && rm influxdb_${INFLUXDB_VERSION}_amd64.deb
 
# Install statsd
RUN 	npm install statsd-influxdb-backend
RUN 	wget https://github.com/etsy/statsd/archive/v0.7.2.zip
RUN 	unzip v0.7.2.zip
# ----------------- #
#   Configuration   #
# ----------------- #

# Configure InfluxDB
ADD		influxdb/config.toml /etc/influxdb/config.toml 
ADD		influxdb/run.sh /usr/local/bin/run_influxdb
# These two databases have to be created. These variables are used by set_influxdb.sh and set_grafana.sh
ENV		PRE_CREATE_DB data grafana graphite statsd elasticsearch fork
ENV		INFLUXDB_DATA_USER data
ENV		INFLUXDB_DATA_PW data
ENV		INFLUXDB_GRAFANA_USER grafana
ENV		INFLUXDB_GRAFANA_PW grafana
ENV		ROOT_PW root

# Configure Statsd
ADD		./statsd/config.js /statsd-0.7.2/config.js


# Configure Grafana
ADD		./grafana/config.js /src/grafana/config.js
#ADD	./grafana/scripted.json /src/grafana/app/dashboards/default.json

ADD		./configure.sh /configure.sh
ADD		./set_grafana.sh /set_grafana.sh
ADD		./set_influxdb.sh /set_influxdb.sh
RUN 		/configure.sh

# Configure nginx and supervisord
ADD		./nginx/nginx.conf /etc/nginx/nginx.conf
ADD		./supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# ----------- #
#   Cleanup   #
# ----------- #

RUN		apt-get autoremove -y wget curl && \
			apt-get -y clean && \
			rm -rf /var/lib/apt/lists/* && rm /*.sh

# ---------------- #
#   Expose Ports   #
# ---------------- #

# Grafana
EXPOSE	80

# InfluxDB Admin server
EXPOSE	8083

# InfluxDB HTTP API
EXPOSE	8086

# InfluxDB HTTPS API
EXPOSE	8084

# Statsd
EXPOSE  8125
# -------- #
#   Run!   #
# -------- #

CMD		["/usr/bin/supervisord"]
