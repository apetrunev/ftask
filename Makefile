CUR_DIR := $(shell pwd)
SOURCE_DIR := $(CUR_DIR)/source
UNBOUND_TAR : $(CUR_DIR)/unbound-1.13.2.tar.gz
DEPS := "coreutils bison flex libncurses-dev bc rsync kmod cpio libelf-dev libssl-dev lz4 nfs-kernel-server"

HOST_IFACE := vboxnet0

.PHONY: all clean

all: help

help:
	@echo "make -- to show help"
	@echo "make deps"
	@echo "make vms"
	@echo "make kernel"

deps:
	@echo "Install dependencies: $(DEPS)"
	@for pkg in $(DEPS); do
	  sudo apt-get install -y $$pkg
	done

vms:
	if [ "x$$(ip -4 -br addr | grep -o $(HOST_IFACE))" != "x$(HOST_IFACE)" ]; then \
	  VBoxManage hostonlyif create; \
	else true; fi
	vagrant up
	touch $@

kupdate:
	vagrant provision --provision-with "mainline kernel"

.ONESHELL:
kernel: 
	mkdir -p $(SOURCE_DIR)
	if ! test -d $(SOURCE_DIR)/linux; then
	  echo "Download mainline kernel source"
	  cd $(SOURCE_DIR)/linux && git clone git://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git
	fi
	if test -z $$(find $(SOURCE_DIR)/ -mindepth 1 -maxdepth 1 -type -name "config-*-amd64" -print | wc -l); then
	  echo "error: kernel configuration file not found"
	  flase
	fi
	if test -z
	cp -v $$(find $(SOURCE_DIR)/ -mindepth 1 -maxdepth 1 -type f -name "config-*-amd64" -print | tail -n1) $(SOURCE_DIR)/linux/.config
	cd $(SOURCE_DIR)/linux
	make mrproper
	make menuconfig
	#make -j$$(nproc) deb-pkg
	touch $@

clean:
	$(RM) -f vms kernel 

