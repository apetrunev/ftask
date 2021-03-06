CUR_DIR := $(shell pwd)
PROMETHEUS_LINK := https://github.com/prometheus/prometheus/releases/download/v2.31.0/prometheus-2.31.0.linux-amd64.tar.gz
PROMETHEUS_DIR := /opt/prometheus
PROMETHEUS_ARCH := $(shell basename $(PROMETHEUS_LINK))
PROMETHEUS_SERVICE := prometheus.service

NODE_EXPORTER_LINK := https://github.com/prometheus/node_exporter/releases/download/v1.2.2/node_exporter-1.2.2.linux-amd64.tar.gz
NODE_EXPORTER_DIR := /opt/node-exporter
NODE_EXPORTER_ARCH := $(shell basename $(NODE_EXPORTER_LINK))
NODE_EXPORTER_SERVICE := node-exporter.service

GRAFANA_LINK := https://dl.grafana.com/enterprise/release/grafana-enterprise_8.2.3_amd64.deb
GRAFANA_PKG := $(shell basename $(GRAFANA_LINK))

.PHONY: all clean prometheus 

all: help

help:
	@echo "make help"

grafana:
	apt-get -y install adduser libfontconfig1
	cd /tmp && wget $(GRAFANA_LINK)
	apt-get -y install /tmp/$(GRAFANA_PKG)
	sudo systemctl daemon-reload
	sudo systemctl enable grafana-server.service
	sudo systemctl start grafana-server

prometheus:
	if [ "x$$(getent passwd prometheus | cut -d: -f1 | grep -o prometheus)" != "xprometheus" ]; then \
	  useradd --system --no-create-home --shell /bin/false prometheus; \
	else true; fi
	mkdir -vp /etc/prometheus
	mkdir -vp /var/lib/prometheus
	chown -vR prometheus:prometheus /etc/prometheus
	chown -vR prometheus:prometheus /var/lib/prometheus
	if ! test -d $(PROMETHEUS_DIR); then \
		mkdir -p $(PROMETHEUS_DIR); \
		if ! test -f /tmp/$(PROMETHEUS_ARCH); then cd /tmp && wget $(PROMETHEUS_LINK); fi; \
	        tar --strip-components=1 -C $(PROMETHEUS_DIR)/ -xvzf /tmp/$(PROMETHEUS_ARCH); \
		chown -vR prometheus:prometheus $(PROMETHEUS_DIR); \
	        cp -vpR $(PROMETHEUS_DIR)/prometheus /usr/local/bin/; \
		cp -vpR $(PROMETHEUS_DIR)/promtool /usr/local/bin/; \
		cp -vpR $(PROMETHEUS_DIR)/consoles /etc/prometheus/; \
		cp -vpR $(PROMETHEUS_DIR)/console_libraries /etc/prometheus/; \
		cp -v $(CUR_DIR)/$(PROMETHEUS_SERVICE) /etc/systemd/system/; \
		cp -v $(CUR_DIR)/prometheus.yml /etc/prometheus/; \
		systemctl daemon-reload; \
		systemctl enable $(PROMETHEUS_SERVICE); \
		systemctl start $(PROMETHEUS_SERVICE); \
		if test -d /etc/nginx/sites-available/; then \
			cp -v $(CUR_DIR)/prometheus /etc/nginx/sites-available/; \
		        cd /etc/nginx/sites-enabled/ && ln -sf ../sites-available/prometheus; \
			if nginx -t; then systemctl restart nginx.service; fi; \
		fi; \
	else true; fi
	
nexporter:
	if [ "x$$(getent passwd node_exporter | cut -d: -f1 | grep -o node_exporter)" != "xnode_exporter" ]; then \
	  useradd --system --no-create-home --shell /bin/false node_exporter; \
	else true; fi
	if ! test -d $(NODE_EXPORTER_DIR); then \
		mkdir -vp $(NODE_EXPORTER_DIR); \
		chown -vR node_exporter:node_exporter $(NODE_EXPORTER_DIR); \
		if ! test -f /tmp/$(NODE_EXPORTER_ARCH); then cd /tmp && wget $(NODE_EXPORTER_LINK); fi; \
		tar --strip-components=1 -C $(NODE_EXPORTER_DIR)/ -xvzf /tmp/$(NODE_EXPORTER_ARCH); \
		chown -vR node_exporter:node_exporter $(NODE_EXPORTER_DIR)/; \
		cp -vR $(NODE_EXPORTER_DIR)/node_exporter /usr/local/bin/; \
		cp -v $(CUR_DIR)/$(NODE_EXPORTER_SERVICE) /etc/systemd/system/; \
		systemctl daemon-reload; \
		systemctl enable $(NODE_EXPORTER_SERVICE); \
		systemctl start $(NODE_EXPORTER_SERVICE); \
	fi
