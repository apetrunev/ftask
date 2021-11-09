require 'fileutils'

class BasicProvision
  @@upgrade = <<-UPGRADE
  if ! test -f /etc/apt/sources.list.bk; then cp -v /etc/apt/sources.list /etc/apt/sources.list.bk; fi
  if test -f /vagrant/base/stable.sources.list; then cp -v /vagrant/base/stable.sources.list /etc/apt/sources.list; fi
  export DEBIAN_FRONTEND=noninteractive
  apt-get -y --allow-releaseinfo-change update
  apt-get -y update
  #apt-get -y upgrade
  #apt-get -y dist-upgrade   
  UPGRADE

  @@timezone = <<-TIMEZONE
  timedatectl set-timezone Europe/Moscow
  TIMEZONE

  @@kernelConfig = <<-'KERNELCONF'
  cp -v $(find /boot -mindepth 1 -maxdepth 1 -type f -name "config-*-amd64" | tail -n1) /vagrant/  
  KERNELCONF

  @@installMainlineKernel = <<-'KERNELMAINLINE'
  find /vagrant -mindepth 1 -maxdepth 1 -type f ! -name "*dbg*" -name "*.deb" -exec sudo apt-get -y install "{}" \;
  KERNELMAINLINE

  @@passwd = <<-PASSWD
  echo vagrant:123 | chpasswd
  PASSWD

  @@installBasicPackages = <<-BASICPACKAGES
  apt-get -y install htop vim make gawk tcpdump iptables ipset net-tools
  BASICPACKAGES

  def upgrade
    return @@upgrade   
  end

  def setTimezone
    return @@timezone
  end

  def saveKernelConfig
    return @@kernelConfig
  end

  def installKernel
    return @@installMainlineKernel
  end

  def setPassword
    return @@passwd
  end

  def installPackages
    return @@installBasicPackages
  end
end
#
# Basic provision for all virtual machines
#
$basicProvision = BasicProvision.new
#
# Create disks for DB virtual machine
#
$dir = "disks"
FileUtils.mkdir $dir unless File.directory?($dir)
$prefix = "db_disk_"
$dbDisks = Array.new(4)
for i in 0...$dbDisks.length
  $dbDisks[i] = "#{$dir}/#{$prefix}#{i}.vdi"
end

Vagrant.configure("2") do |config|
  config.vm.provider "virtualbox"
  #
  # Router
  # 
  config.vm.define "router" do |r|
    r.vm.box = "generic/debian11"
    r.vm.hostname = "router.local"
    # Management network
    r.vm.network "private_network", ip: "192.168.56.2", name: "vboxnet0"
    # Intranet-1
    r.vm.network "private_network", ip: "192.168.57.1", virtualbox__intnet: true
    # Intranet-2
    r.vm.network "private_network", ip: "192.168.58.1", virtualbox__intnet: true

    r.vm.synced_folder "source", "/vagrant", type: "nfs", nfs_version: 3, nfs_udp: false
    
    r.vm.provision "upgrade", type: "shell", inline: $basicProvision.upgrade
    r.vm.provision "pkg", type: "shell", inline: $basicProvision.installPackages
    r.vm.provision "timezone", type: "shell", inline: $basicProvision.setTimezone
    r.vm.provision "kernel config", type: "shell", inline: $basicProvision.saveKernelConfig
    r.vm.provision "passwd", type: "shell", inline: $basicProvision.setPassword

    r.vm.provision "mainline kernel", type: "shell", run: "never", inline: $basicProvision.installKernel

    r.vm.provision "routing", run: "always", type: "shell" do |routing|
      routing.inline = <<-'ROUTING'
        if test -f /vagrant/router/firewall; then
          if ! test -f /etc/network/if-pre-up.d/firewall; then
            echo "Enable firewall rules"
            /vagrant/router/firewall
            cp -v /vagrant/router/firewall /etc/network/if-pre-up.d/
          fi
        fi
        if [ "x$(ip -br l | cut -d' ' -f1 | grep -o dummy0)" != "xdummy0" ]; then
          modprobe --first-time dummy
          ip l add dummy0 type dummy
        else
          ip a flush dev dummy0 
        fi
        ip a add 192.168.254.1/24 brd + dev dummy0
        ip l set up dev dummy0
      ROUTING
    end

    r.vm.provision "dns", run: "always", type: "shell" do |dns|
      dns.inline = <<-DNS
	apt-get -y install unbound
        systemctl stop unbound.service
        if test -d /etc/unbound; then cp -v /vagrant/router/root.hints /etc/unbound/; fi
        if test -d /etc/unbound; then cp -v /vagrant/router/unbound.conf /etc/unbound/; fi
        if test -n "$(command -v unbound-control)"; then 
          sleep 2 && systemctl start unbound.service
        fi
        echo "Set dns settings"
        if [ "x$(cat /etc/resolvconf/resolv.conf.d/head | sed '/^#/d' | grep -o nameserver)" != "xnameserver" ]; then
          echo "nameserver 127.0.0.1" >> /etc/resolvconf/resolv.conf.d/head 
        fi
        if [ "x$(cat /etc/resolvconf/resolv.conf.d/head | sed '/^#/d' | grep -o search)" != "xsearch" ]; then
          echo "search local" >> /etc/resolvconf/resolv.conf.d/head 
        fi
        echo "Update /etc/resolv.conf configuration"
        resolvconf --enable-updates
        resolvconf -u
      DNS
    end
 
    r.vm.provision "monitoring", type: "shell" do |m|
     m.inline = <<-'MONITORING'
       cd /vagrant/monitoring && make nexporter 
     MONITORING
    end
  end
  #
  # DB
  # 
  config.vm.define "db" do |d|
    d.vm.box = "generic/debian11"
    d.vm.hostname = "db.local"
    # Management network
    d.vm.network "private_network", ip: "192.168.56.3", name: "vboxnet0"
    # Intranet-2
    d.vm.network "private_network", ip: "192.168.57.3", virtualbox__intnet: true
 
    d.vm.provider "virtualbox" do |vb|
      if File.exist?(".vagrant/machines/db/virtualbox/id") then
        id = File.read(".vagrant/machines/db/virtualbox/id")
        ret = IO.popen("VBoxManage showvminfo #{id} --machinereadable | grep 'SATA Controller'", "r")
        len = ret.readlines.length
 
        if len == 0 then
          vb.customize [ "storagectl", :id, "--name", "SATA Controller", "--add", "sata", "--controller", "IntelAHCI" ] 
        end
	
        for i in 0...$dbDisks.length
          disk = $dbDisks[i]
          if File.exist?("#{disk}") then
            vb.customize [ "storageattach", :id, "--storagectl", "SATA Controller", "--device", 0, "--port", i, "--type", "hdd", "--medium", "#{disk}" ]  
          end
        end
      else
        vb.customize [ "storagectl", :id, "--name", "SATA Controller", "--add", "sata", "--controller", "IntelAHCI" ]
      
        for i in 0...$dbDisks.length
          disk = $dbDisks[i]
          if not File.exist?("#{disk}") then
            vb.customize [ "createmedium", "disk", "--filename", "#{disk}", "--size", "200" ]
            vb.customize [ "storageattach", :id, "--storagectl", "SATA Controller", "--device", 0, "--port", i, "--type", "hdd", "--medium", "#{disk}" ]  
          end
        end
 
      end
    end 

    d.vm.synced_folder "source", "/vagrant", type: "nfs", nfs_version: 3, nfs_udp: false
     
    d.vm.provision "upgrade", type: "shell", inline: $basicProvision.upgrade
    d.vm.provision "pkg", type: "shell", inline: $basicProvision.installPackages
    d.vm.provision "timezone", type: "shell", inline: $basicProvision.setTimezone
    d.vm.provision "kernel config", type: "shell", inline: $basicProvision.saveKernelConfig
    d.vm.provision "passwd", type: "shell", inline: $basicProvision.setPassword

    d.vm.provision "mainline kernel", type: "shell", run: "never", inline: $basicProvision.installKernel
    
    d.vm.provision "routing", run: "always", type: "shell" do |routing|
      routing.inline = <<-'ROUTING'
        if test -f /vagrant/db/firewall; then
          if ! test -f /etc/network/if-pre-up.d/firewall; then
            echo "Enable firewall rules"
            /vagrant/db/firewall
            cp -v /vagrant/db/firewall /etc/network/if-pre-up.d/
          fi
        fi
        echo "Change default route"
        ip route change default via 192.168.57.1
        echo "Set dns settings"
        if [ "x$(cat /etc/resolvconf/resolv.conf.d/head | sed '/^#/d' | grep -o nameserver)" != "xnameserver" ]; then
          echo "nameserver 192.168.254.1" >> /etc/resolvconf/resolv.conf.d/head 
        fi
        if [ "x$(cat /etc/resolvconf/resolv.conf.d/head | sed '/^#/d' | grep -o search)" != "xsearch" ]; then
          echo "search local" >> /etc/resolvconf/resolv.conf.d/head 
        fi
        resolvconf --enable-updates
        resolvconf -u
      ROUTING
    end
 
    d.vm.provision "storage", type: "shell", run: "always" do |storage|
      storage.inline = <<-'STORAGE'
        apt-get update
        apt-get -y install mdadm lvm2
        mkdir -p /local/files
        mkdir -p /local/backups
        #
        # LVM
        #
        if [ "x$(pvscan | grep -o /dev/sdb)" != "x/dev/sdb" ]; then
          echo "Initialize physical volume on /dev/sdb"
          pvcreate /dev/sdb
        fi
        if [ "x$(pvscan | grep -o /dev/sdc)" != "x/dev/sdc" ]; then
          echo "Initialize physical volume on /dev/sdc"
          pvcreate /dev/sdc
        fi
        if [ "x$(vgdisplay | awk '/VG Name/ { print $0 }' | grep -o vgfiles)" != "xvgfiles" ]; then
          vgcreate vgfiles /dev/sdb /dev/sdc
        fi
        # Activate volume group
        vgchange -ay

        if [ "x$(lvdisplay | awk '/LV Path/ { print $0 }' | grep -o lvfiles)" != "xlvfiles" ]; then
          lvcreate -L 200M -n lvfiles vgfiles
        fi

        if [ "x$(findmnt -n -o SOURCE /local/files | grep -o lvfiles)" != "xlvfiles" ]; then
          # if no partition found on locagical volume create one
          if [ -z "$(file -sL /dev/vgfiles/lvfiles | awk '{ print $5 }')" ]; then
            mkfs.ext4 /dev/vgfiles/lvfiles
          fi
          mount /dev/vgfiles/lvfiles /local/files
        fi
        #
        # RAID
        # 
        if ! test -b /dev/md0; then
          mdadm --zero-superblock --force /dev/sd{d,e}
          wipefs --all --force /dev/sd{d,e}
          yes | mdadm --create --verbose /dev/md0 --level 1 --raid-devices=2 /dev/sd{d,e}
        fi
        if [ "x$(findmnt -n -o SOURCE /local/backups | grep -o /dev/md0p1)" != "x/dev/md0p1" ]; then
          # Create partition 
          if ! test -b /dev/md0p1; then
            awk 'END {
              printf("n\n");
              printf("p\n");
              printf("%s\n", 1);
              printf("\n");
              printf("\n");
              system("sleep 5");
              printf("w\n");
            }' | fdisk /dev/md0

            mkfs.ext4 /dev/md0p1
           
            UUID=$(mdadm --detail --scan | awk '{ print $5 }')
            awk -v UUID=$UUID 'END {
            printf("%s\n%s\n%s\nARRAY /dev/md0 %s\n",
                    "DEVICE /dev/sdd /dev/sde",
                    "CREATE owner=root group=disk mode=0660 auto=yes",
                    "HOMEHOST db",
                     UUID) }' > /etc/mdadm/mdadm.conf
            update-initramfs -u
          fi
          mount /dev/md0p1 /local/backups
        fi 
      STORAGE
    end
    d.vm.provision "postgres", type: "shell" do |pg|
      pg.inline = <<-'POSTGRES'
        apt-get -y install postgresql
        cd /vagrant/db && (
          ./configureDB pg_hba
          ./configureDB pg_ident
          ./configureDB postgresql
          systemctl restart postgresql.service
          ./configureDB db
        )
      POSTGRES
    end

    d.vm.provision "script", type: "shell" do |s|
      s.inline = <<-'SCRIPT'
        apt-get -y install mailutils postfix
        if test -f /vagrant/db/script1.sh; then cp -v /vagrant/db/script1.sh /home/vagrant/; fi
        if test -f /vagrant/db/script2.sh; then cp -v /vagrant/db/script2.sh /home/vagrant/; fi
        if test -f /vagrant/db/script2.service; then
          cp -v /vagrant/db/script2.service /etc/systemd/system/;
          systemctl daemon-reload
          systemctl enable script2.service
          systemctl start script2.service
        fi
      SCRIPT
    end 

    d.vm.provision "monitoring", type: "shell" do |m|
     m.inline = <<-'MONITORING'
       cd /vagrant/monitoring && make nexporter 
     MONITORING
    end
  end
  #
  # WEB
  #
  config.vm.define "web" do |w|
    w.vm.box = "generic/debian11"
    w.vm.hostname = "web.local"
    # Port forwarding
    w.vm.network "forwarded_port", guest: 5000, host: 5000
    w.vm.network "forwarded_port", guest: 3000, host: 3000
    w.vm.network "forwarded_port", guest: 80, host: 8080
    # Management network
    w.vm.network "private_network", ip: "192.168.56.4", name: "vboxnet0"
    # Intranet-2
    w.vm.network "private_network", ip: "192.168.58.4", virtualbox__intnet: true
     
    w.vm.synced_folder "source", "/vagrant", type: "nfs", nfs_version: 3, nfs_udp: false
     
    w.vm.provision "upgrade", type: "shell", inline: $basicProvision.upgrade
    w.vm.provision "pkg", type: "shell", inline: $basicProvision.installPackages
    w.vm.provision "timezone", type: "shell", inline: $basicProvision.setTimezone
    w.vm.provision "kernel config", type: "shell", inline: $basicProvision.saveKernelConfig
    w.vm.provision "passwd", type: "shell", inline: $basicProvision.setPassword

    w.vm.provision "mainline kernel", type: "shell", run: "never", inline: $basicProvision.installKernel 
 
    w.vm.provision "routing", run: "always", type: "shell" do |routing|
      routing.inline = <<-'ROUTING'
        if test -f /vagrant/web/firewall; then
          if ! test -f /etc/network/if-pre-up.d/firewall; then
            echo "Enable firewall rules"
            /vagrant/web/firewall
            cp -v /vagrant/web/firewall /etc/network/if-pre-up.d/
          fi
        fi
        echo "Change default route"
        ip route change default via 192.168.58.1
        echo "Set dns settings"
        if [ "x$(cat /etc/resolvconf/resolv.conf.d/head | sed '/^#/d' | grep -o nameserver)" != "xnameserver" ]; then
          echo "nameserver 192.168.254.1" >> /etc/resolvconf/resolv.conf.d/head 
        fi
        if [ "x$(cat /etc/resolvconf/resolv.conf.d/head | sed '/^#/d' | grep -o search)" != "xsearch" ]; then
          echo "search local" >> /etc/resolvconf/resolv.conf.d/head 
        fi
        resolvconf --enable-updates
        resolvconf -u
      ROUTING
    end   
 
    w.vm.provision "web", type: "shell" do |web|
      web.inline = <<-'WEB'
        apt-get -y install nginx
        apt-get -y install python3-pip python3-dev build-essential libssl-dev libffi-dev python3-setuptools python3-venv
        apt-get -y install certbot python3-certbot-nginx
        if [ "x$(getent passwd app_user | cut -d: -f1 | grep -o app_user)" = "xapp_user" ]; then
          echo "User app_user already exists"
        else 
          useradd --system -s /bin/bash -d /home/app_user -g www-data -m app_user
	fi
        if ! test -d /home/app_user; then exit 1; fi
        su - app_user -c "mkdir -p app && (
	  cd ~/app
          python3 -m venv appenv
          echo \"Activate environment\"
          source ~/app/appenv/bin/activate
          echo \"Install dependencies\"
          pip install uwsgi flask psycopg2-binary
          if test -f /vagrant/web/app.source.tar.gz; then
            echo \"Unpack archive with the application source files\"
            tar -C ~/app -xvzf /vagrant/web/app.source.tar.gz
          fi 
        )"
        if test -f /home/app_user/app/app.service; then 
          cp -v /home/app_user/app/app.service /etc/systemd/system/
          systemctl daemon-reload
          systemctl enable app.service
          systemctl start app.service
        fi
        if test -f /vagrant/web/app; then
          cp -v /vagrant/web/app /etc/nginx/sites-available/
          cd /etc/nginx/sites-enabled/ && ln -fvs ../sites-available/app
          if ! test -d /etc/nginx/ssl; then
            if test -d /vagrant/web/ssl; then cp -vR /vagrant/web/ssl /etc/nginx/; fi
          fi
        fi
        if nginx -t; then
           echo "Configuration is ok. Restart nginx."
           systemctl restart nginx.service
        fi  
      WEB
    end

    w.vm.provision "script", type: "shell" do |s|
      s.inline = <<-'SCRIPT'
        mkdir -vp /local/scripts
        chown -vR app_user:www-data /local/scripts
        if test -f /vagrant/web/script.py; then 
          cp -v /vagrant/web/script.py /home/app_user/;
          chown -vR app_user:www-data /home/app_user/script.py
          su - app_user -c /bin/bash -c "
            pip install psycopg2-binary
            echo '*/5 * * * * /home/app_user/script.py' | crontab -
          "
        fi
      SCRIPT
    end

   w.vm.provision "monitoring", type: "shell" do |m|
     m.inline = <<-'MONITORING'
       cd /vagrant/monitoring && (
         make nexporter
         make prometheus
         make grafana
         ./configureGrafana
         systemctl restart grafana-server.service
       )
     MONITORING
   end
  end
end
