#!/usr/bin/env ruby

require 'fileutils'

class BasicProvision
  @@slistOriginal = "/etc/apt/sources.list"
  @@slistBackup = "/etc/apt/sources.list.bk"
  @@slistUpdate = "/vagrant/stable.sources.list"
  
  @@upgrade = <<-UPGRADE
  export DEBIAN_FRONTEND=noninteractive
  apt-get --allow-releaseinfo-change update
  apt-get -y upgrade
  apt-get -y dist-upgrade   
  UPGRADE

  @@timezone = <<-TIMEZONE
  timedatectl set-timezone Europe/Moscow
  TIMEZONE

  @@kernelConfig = <<-KERNELCONF
  cp -v $(find /boot -mindepth 1 -maxdepth 1 -type f -name "config-*-amd64" | tail -n1) /vagrant/  
  KERNELCONF

  @@installMainlineKernel = <<-KERNELMAINLINE
  find /vagrant -mindepth 1 -maxdepth 1 -type f ! -name "*dbg*" -name "*.deb" -exec sudo apt-get -y install "{}" \;
  KERNELMAINLINE

  @@installBasicPackages = <<-BASICPACKAGES
  apt-get -y install htop vim gawk tcpdump iptables
  BASICPACKAGES

  def upgrade
    if not File.exist?(@@slistBackup) then
      begin
        FileUtils.cp(@@slistOriginal, @@slistBackup)
      rescue StandardError => msg  
        puts msg
      end
    end

    if File.exist?(@@slistUpdate) then
      begin
        FileUtils.cp(@@slistUpdate, @@slistOrigianl)
      rescue StandardError => msg
        puts msg
      end
    end
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

$dir = "disks"
$prefix = "db_disk_"
$dbDisks = Array.new(4)

FileUtils.mkdir $dir unless File.directory?($dir)

for i in 0...$dbDisks.length
  $dbDisks[i] = "#{$dir}#{$prefix}#{i}.vdi"
  if not File.exist?("#{$dbDisks[i]}") then
    puts "File #{$dbDisks[i]} does not exist"
  end
end
