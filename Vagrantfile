# -*- mode: ruby -*-
# vi: set ft=ruby :

# Vagrantfile API/syntax version. Don't touch unless you know what you're doing!
VAGRANTFILE_API_VERSION = "2"

# Configuration Parameters
PDC_IP="192.168.99.10"

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|

  config.vm.define "pdc" do |pdc|
    pdc.vm.box = "ubuntu/trusty64"

    pdc.vm.network "private_network", ip: PDC_IP, name: "vboxnet0"
    pdc.vm.provision :hosts do |provisioner|
      provisioner.add_host PDC_IP, ["pdc", "pdc.greenplum.local", "greenplum.local"]
      provisioner.add_localhost_hostnames = false
    end

    pdc.ssh.shell = "bash -c 'BASH_ENV=/etc/profile exec bash'"
    pdc.vm.provision "shell", path: "configure-pdc.sh"
  end
end
    

