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

  @@installBasicPackages = <<-BASICPACKAGES
  apt-get -y install htop vim gawk tcpdump iptables ipset net-tools
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
    r.vm.network "private_network", ip: "192.168.57.2", virtualbox__intnet: true
    # Intranet-2
    r.vm.network "private_network", ip: "192.168.58.2", virtualbox__intnet: true

    r.vm.synced_folder "source", "/vagrant", type: "nfs", nfs_version: 3, nfs_udp: false
    
    r.vm.provision "upgrade", type: "shell", inline: $basicProvision.upgrade
    r.vm.provision "pkg", type: "shell", inline: $basicProvision.installPackages
    r.vm.provision "timezone", type: "shell", inline: $basicProvision.setTimezone
    r.vm.provision "kernel config", type: "shell", inline: $basicProvision.saveKernelConfig
    r.vm.provision "mainline kernel", type: "shell", run: "never", inline: $basicProvision.installKernel

    r.vm.provision "router packages", type: "shell", inline: "apt-get -y install unbound"

    r.vm.provision "settings", type: "shell" do |settings|
      settings.inline = <<-SETTINGS
        if test -d /etc/unbound; then cp -v /vagrant/router/root.hints /etc/unbound/; fi
        if test -d /etc/unbound; then cp -v /vagrant/router/unbound.conf /etc/unbound/; fi
        if test -n "$(command -v unbound-control)"; then 
          systemctl start unbound.service
          unbound-control reload
        fi
      SETTINGS
    end

    r.vm.provision "routing", type: "shell" do |routing|
      routing.inline = <<-'SERVICES'
        sysctl -w net.ipv4.ip_forward=1
	iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
      SERVICES
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
    d.vm.network "private_network", ip: "192.168.58.3", virtualbox__intnet: true
 
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
    d.vm.provision "mainline kernel", type: "shell", run: "never", inline: $basicProvision.installKernel
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
          pvcreate /dev/sdb
        fi
        if [ "x$(pvscan | grep -o /dev/sdc)" != "x/dev/sdc" ]; then
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
      POSTGRES
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
    w.vm.provision "mainline kernel", type: "shell", run: "never", inline: $basicProvision.installKernel 
 
    w.vm.provision "web", type: "shell" do |web|
      web.inline = <<-'WEB'
        apt-get -y install nginx
        apt-get -y install python3-pip python3-dev build-essential libssl-dev libffi-dev python3-setuptools python3-venv
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
        fi
        if nginx -t; then
           echo "Configuration is ok. Restart nginx."
           systemctl restart nginx.service
        fi  
        mkdir -vp /local/files
      WEB
    end 
  end
end
