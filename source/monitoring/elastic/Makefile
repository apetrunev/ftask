CUR_DIR := $(shell pwd)

ELASTIC_DEPS := sudo curl wget apt-transport-https dirmngr
ELASTIC_KEY := https://artifacts.elastic.co/GPG-KEY-elasticsearch 
ELASTIC_REPO := https://artifacts.elastic.co/packages/7.x/apt 
ELASTIC_BIN := /usr/share/elasticsearch/bin
ELASTIC_USER := elasticsearch
ELASTIC_GROUP := elasticsearch

ELASTIC_ADMIN := admin
ELASTIC_ADMIN_PASSWD := Qweaz123!
ELASTIC_ADMIN_ROLE := superuser
ELASTIC_BEAT := beat
ELASTIC_BEAT_PASSWD := secret
ELASTIC_BEAT_ROLE := filebeat_writer
ELASTIC_KIBANA := kibana_sys
ELASTIC_KIBANA_PASSWD := secret
ELASTIC_KIBANA_ROLE := kibana_system

KIBANA_DIR := /opt/kibana
KIBANA_LINK := https://artifacts.elastic.co/downloads/kibana/kibana-7.15.1-linux-x86_64.tar.gz
KIBANA_ARCH := $(shell basename $(KIBANA_LINK))

FILEBEAT_LINK := https://artifacts.elastic.co/downloads/beats/filebeat/filebeat-7.15.2-amd64.deb
FILEBEAT_PKG := $(shell basename $(FILEBEAT_LINK))

.PHONY: all clean help

all: help

help:
	@echo "make help"

pkg:
	for pkg in $(ELASTIC_DEPS); do \
	  apt-get -y install $$pkg; \
	done

sourceslist:
	echo "deb $(ELASTIC_REPO) stable main" | sudo tee /etc/apt/sources.list.d/elastic-7.x.list

elasticsearch: pkg sourceslist
	wget -qO - $(ELASTIC_KEY) | sudo apt-key add - || true
	apt-get update
	apt-get -y install elasticsearch
	if ! test -f /etc/elasticsearch/jvm.options.orig; then \
	  cp -vp /etc/elasticsearch/jvm.options /etc/elasticsearch/jvm.options.orig; \
	fi
	$(eval TMP := $(shell mktemp --tmpdir jvm.options.XXX))
	awk '{ \
		if ($$0 ~ /.*-Xms[0-9]+g/){ print "-Xms1g" } \
	    else if ($$0 ~ /.*-Xmx[0-9]+g/) { print "-Xmx1g" } \
	    else { print } \
	}' /etc/elasticsearch/jvm.options > $(TMP)
	cp -v $(TMP) /etc/elasticsearch/jvm.options
	if ! test -f /etc/elasticsearch/elasticsearch.yml.orig; then \
	  cp -vp /etc/elasticsearch/elasticsearch.yml /etc/elasticsearch/elasticsearch.yml.orig; \
	fi
	$(eval TMP := $(shell mktemp --tmpdir elasticsearch.yml.XXX))
	awk ' \
	  /xpack.security.enabled:/ { \
	    print "## ADDED"; \
	    print "xpack.security.enabled: true"; \
	    secured = 1; \
	    next \
	  } \
	  { print } \
	END { \
	  if (!secured) { \
	    print "## ADDED"; \
	    print "xpack.security.enabled: true" \
	  } \
	}' /etc/elasticsearch/elasticsearch.yml > $(TMP)
	cp -v $(TMP) /etc/elasticsearch/elasticsearch.yml
	# Password must be at least 6 characters
	runuser -u root -g $(ELASTIC_GROUP) -m -- /bin/bash -c "$(ELASTIC_BIN)/elasticsearch-users useradd $(ELASTIC_ADMIN) -p $(ELASTIC_ADMIN_PASSWD) -r $(ELASTIC_ADMIN_ROLE)" || true
	runuser -u root -g $(ELASTIC_GROUP) -m -- /bin/bash -c "$(ELASTIC_BIN)/elasticsearch-users useradd $(ELASTIC_BEAT) -p $(ELASTIC_BEAT_PASSWD) -r $(ELASTIC_BEAT_ROLE)" || true
	runuser -u root -g $(ELASTIC_GROUP) -m -- /bin/bash -c "$(ELASTIC_BIN)/elasticsearch-users useradd $(ELASTIC_KIBANA) -p $(ELASTIC_KIBANA_PASSWD) -r $(ELASTIC_KIBANA_ROLE)" || true
	systemctl daemon-reload
	systemctl enable elasticsearch.service
	systemctl start elasticsearch.service

kibana:
	if [ "x$$(getent passwd kibana | cut -d: -f1 | grep -o kibana)" != "xkibana" ]; then \
	  useradd --system --no-create-home --shell /bin/false kibana; \
	else true; fi
	if ! test -d $(KIBANA_DIR); then \
	  mkdir -vp $(KIBANA_DIR); \
	  cd /tmp && wget $(KIBANA_LINK); \
	  tar -C $(KIBANA_DIR) --strip-components=1 -xvzf /tmp/$(KIBANA_ARCH); \
	  chown -vR kibana:kibana $(KIBANA_DIR)/; \
	  if ! test -f $(KIBANA_DIR)/config/kibana.yml; then \
	    cp -vp $(KIBANA_DIR)/config/kibana.yml $(KIBANA_DIR)/config/kibana.yml.orig; \
	  fi; \
	  $(eval TMP := $(shell mktemp --tmpdir kibana.yml.XXX)) \
	  awk '/server.host:/ { \
	    print "server.host: \"0.0.0.0\""; next \
	  } \
	  /elasticsearch.username:/ { \
	    print "elasticsearch.username: \"$(ELASTIC_KIBANA)\""; next \
	  } \
	  /elasticsearch.password:/ { \
	    print "elasticsearch.password: \"$(ELASTIC_KIBANA_PASSWD)\""; next \
	  } \
	  { print }' $(KIBANA_DIR)/config/kibana.yml > $(TMP); \
	  cp -v $(TMP) $(KIBANA_DIR)/config/kibana.yml; \
	  rm -v $(TMP); \
	  cp -v $(CUR_DIR)/kibana.service /etc/systemd/system/; \
	  systemctl daemon-reload; \
	  systemctl enable kibana.service; \
	  systemctl restart kibana.service; \
	else \
	  echo "warn: Kibana already installed"; \
	fi

filebeat:
	cd /tmp && wget $(FILEBEAT_LINK)
	apt-get -y install /tmp/$(FILEBEAT_PKG)
	if ! -f test /etc/filebeat/filebeat.yml.orig; then \
	  cp -vp /etc/filebeat/filebeat.yml /etc/filebeat/filebeat.yml.orig; \
	fi
	$(eval TMP := $(shell mktemp --tmpdir filebeat.yml.XXX))
	awk '/^output.elasticsearch/,/^#/ { \
	  if ($$0 ~ /username:/) { \
	    print "  username: \"$(ELASTIC_BEAT)\""; \
	    next \
	  } else if ($$0 ~ /password:/) { \
	    print "  password: \"$(ELASTIC_BEAT_PASSWD)\""; \
	    next \
	  } else { \
	    print; \
	    next \
	  } \
	} \
        { print }' /etc/filebeat/filebeat.yml > $(TMP)
	cp -v $(TMP) /etc/filebeat/filebeat.yml
	systemctl restart filebeat.service
