# -*- mode: ruby -*-
# vi: set ft=ruby :

servers = [
    {
        :name => "k8s-node-1",
        :type => "master",
        :box => "ubuntu/bionic64",
        :box_version => "20210921.0.0",
        :eth1 => "192.168.56.2",
        :mem => "2048",
        :cpu => "2"
    },
    {
        :name => "k8s-node-2",
        :type => "node",
        :box => "ubuntu/bionic64",
        :box_version => "20210921.0.0",
        :eth1 => "192.168.56.4",
        :mem => "1024",
        :cpu => "1"
    },
    {
        :name => "k8s-node-3",
        :type => "node",
        :box => "ubuntu/bionic64",
        :box_version => "20210921.0.0",
        :eth1 => "192.168.56.6",
        :mem => "1024",
        :cpu => "1"
    }
]

Vagrant.configure("2") do |config|

    servers.each do |opts|
        config.vm.define opts[:name] do |config|

            config.vm.box = opts[:box]
            config.vm.box_version = opts[:box_version]
            config.vm.hostname = opts[:name]
            config.vm.network :private_network, ip: opts[:eth1]
            config.vm.synced_folder ".", "/vagrant", owner: "vagrant", group: "vagrant"

            config.ssh.insert_key = false

            config.vm.provider "virtualbox" do |v|

                v.name = opts[:name]
                v.customize ["modifyvm", :id, "--memory", opts[:mem]]
                v.customize ["modifyvm", :id, "--cpus", opts[:cpu]]

            end

            config.vm.provision "file", source: "./keys/id_rsa.pub", destination: "~/.ssh/id_rsa.pub"
            config.vm.provision "shell", inline: <<-SHELL
                cat /home/vagrant/.ssh/id_rsa.pub >> /home/vagrant/.ssh/authorized_keys
            SHELL

        end

    end

end