CUR_DIR := $(shell pwd)
SOURCE_DIR := $(CUR_DIR)/source
DEPS := "coreutils bison flex libncurses-dev bc rsync kmod cpio libelf-dev libssl-dev lz4 nfs-kernel-server"

ROUTER_ADDR := 192.168.56.2
DB_ADDR := 192.168.56.3
WEB_ADDR :=192.168.56.4

HOST_IFACE := vboxnet0

KERNEL_SRC := git://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git

.PHONY: all clean

all: help

help:
	@echo "make -- to show help"
	@echo "make deps"
	@echo "make vms"
	@echo "make kernel"


ssh:
	cd ~/ && (ssh-keygen && \
		  ssh-copy-id vagrant@$(ROUTER_ADDR) && \
		  ssh-copy-id vagrant@$(DB_ADDR) && \
		  ssh-copy-id vagrant@$(WEB_ADDR))

deps:
	@echo "Install dependencies: $(DEPS)"
	@for pkg in $(DEPS); do
	  sudo apt-get -y install $$pkg
	done

.ONESHELL:
kernel: deps 
	mkdir -p $(SOURCE_DIR)
	if ! test -d $(SOURCE_DIR)/linux; then
	  echo "Download mainline kernel source"
	  cd $(SOURCE_DIR)/ && git clone $(KERNEL_SRC)
	else true; fi
	if [ "$$(find $(SOURCE_DIR)/ -mindepth 1 -maxdepth 1 -type f -name "config-*-amd64" -print | wc -l)" -eq 0 ]; then
	  echo "Kernel config file not found"
	else
	  if ! test -f $(SOURCE_DIR)/linux/.config; then 
	    # sort config files
	    # at the top of the list is config for the newest debian kernel
	    # use it for compiling mainline kernel
	    cp -v $$(find $(SOURCE_DIR)/ -mindepth 1 -maxdepth 1 -type f -name "config-*-amd64" -print | tail -n1) $(SOURCE_DIR)/linux/.config
	    cd $(SOURCE_DIR)/linux
	    make mrproper
	    make menuconfig
	    make -j$$(nproc) deb-pkg
	    touch $@
	  else
	    echo "$(SOURCE_DIR)/linux/.config already exists"
	  fi
	fi 
clean:
	find $(SOURCE_DIR)/ -mindepth 1 -maxdepth 1 -type f \( -name "*.deb" -or -name "*.gz" -or -name "*.buildinfo" -or -name "*.changes" -or -name "*.dsc" \) -print
	$(RM) kernel 

