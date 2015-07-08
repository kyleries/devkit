# -*- mode: ruby -*-
# vi: set ft=ruby :

password = SecureRandom.hex(10)
puts "Generated password: #{password}"

Vagrant.configure("2") do |config|
  config.vm.box = "puphpet/ubuntu1404-x64"

  config.vm.provision "shell" do |s|
    s.path = "./devify.sh"
    s.privileged = true
    s.args = [ ENV["USER"], password ]
  end

  (3000..3003).each do |port|
    config.vm.network :forwarded_port, :guest => port, :host => port
  end

  %w(.ssh .config).each do |dir|
    dir = "#{Dir.home}/#{dir}"
    Dir.mkdir(dir) unless Dir.exists?(dir)
  end

  unless File.exists?("#{Dir.home}/.config/hub")
    File.open("#{Dir.home}/.config/hub", "w+") do |file|
      file.write "---
github.com:
- user: kyleries
  oauth_token: #{ENV["GITHUB_OAUTH_TOKEN"]}"
    end
  end

  config.vm.synced_folder "~/.ssh", "/home/vagrant/.ssh"
  config.vm.synced_folder "~/.config", "/home/vagrant/.config"

  config.vm.provider "vmware_desktop" do |provider|
    provider.vmx["memsize"] = 4096
    provider.vmx["numvcpus"] = 2
  end
end
