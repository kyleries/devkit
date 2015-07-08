USERNAME=$1
PASSWORD=$2

fancy_echo() {
  printf "\n%b\n" "$1"
}

install_if_needed() {
  local package="$1"

  if [ $(dpkg-query -W -f='${Status}' "$package" 2>/dev/null | grep -c "ok installed") -eq 0 ];
  then
    sudo aptitude install -y "$package";
  fi
}

append_to_zshrc() {
  local text="$1" zshrc
  local skip_new_line="$2"

  if [[ -w "$HOME/.zshrc.local" ]]; then
    zshrc="$HOME/.zshrc.local"
  else
    zshrc="$HOME/.zshrc"
  fi

  if ! grep -Fqs "$text" "$zshrc"; then
    if (( skip_new_line )); then
      printf "%s\n" "$text" >> "$zshrc"
    else
      printf "\n%s\n" "$text" >> "$zshrc"
    fi
  fi
}

#!/usr/bin/env bash

trap 'ret=$?; test $ret -ne 0 && printf "failed\n\n" >&2; exit $ret' EXIT
set -e # Exit immediately if a pipeline returns a non-zero status

# Create some basic directories
if [[ ! -d "$HOME/.bin/" ]]; then
  mkdir "$HOME/.bin"
fi

if [ ! -f "$HOME/.zshrc" ]; then
  touch "$HOME/.zshrc"
fi

append_to_zshrc 'export PATH="$HOME/.bin:$PATH"'

fancy_echo "Creating group/user..."
groupadd $USERNAME
useradd -p `openssl passwd -1 $PASSWORD` -g $USERNAME -d /home/$USERNAME -s /bin/zsh -m $USERNAME || exit $?

if [[ -d "/root/.ssh/authorized_keys" ]]; then
  fancy_echo "Copy root user authorized keys to my user..."
  mkdir /home/$USER_NAME/.ssh && cat ~/.ssh/authorized_keys >> /home/$USER_NAME/.ssh/authorized_keys
  chown -R $USER_NAME:$USER_NAME /home/$USER_NAME/.ssh

  fancy_echo "Setting PasswordAuthentication to no..."
  sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/g' /etc/ssh/sshd_config
  restart ssh
fi

fancy_echo "Adding user to sudoers"
usermod -a -G sudo $USERNAME
echo "\"$USERNAME\" ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

fancy_echo "If this is a vagrant setup, copy over local ssh keys..."
if [[ -d "/home/vagrant/" ]]; then
  fancy_echo "Copying sync'd files/dirs from 'vagrant' user"
  cp -R /home/vagrant/.ssh /home/$USERNAME/.
  cp -R /home/vagrant/.config /home/$USERNAME/.
fi

fancy_echo "Chown everything inside /home/USERNAME"
chown -R $USERNAME:$USERNAME /home/$USERNAME

fancy_echo "Updating system packages ..."
if command -v aptitude >/dev/null; then
  fancy_echo "Using aptitude ..."
else
  fancy_echo "Installing aptitude ..."
  sudo apt-get install -y aptitude
fi

sudo aptitude update

fancy_echo "Installing git, for source control management ..."
install_if_needed git

fancy_echo "Installing base ruby build dependencies ..."
sudo aptitude build-dep -y ruby2.2.2

fancy_echo "Installing libraries for common gem dependencies ..."
sudo aptitude install -y libxslt1-dev libcurl4-openssl-dev libksba8 libksba-dev libqtwebkit-dev libreadline-dev

fancy_echo "Installing Postgres, a good open source relational database ..."
install_if_needed postgresql
install_if_needed postgresql-server-dev-all

fancy_echo "Installing Redis, a good key-value database ..."
install_if_needed redis-server

fancy_echo "Installing ctags, to index files for vim tab completion of methods, classes, variables ..."
install_if_needed exuberant-ctags

fancy_echo "Installing vim ..."
install_if_needed vim-gtk

fancy_echo "Installing tmux, to save project state and switch between projects ..."
install_if_needed tmux

fancy_echo "Installing ImageMagick, to crop and resize images ..."
install_if_needed imagemagick

fancy_echo "Installing curl ..."
install_if_needed curl

fancy_echo "Installing zsh ..."
install_if_needed zsh

fancy_echo "Installing node, to render the rails asset pipeline ..."
install_if_needed nodejs

fancy_echo "Changing your shell to zsh ..."
chsh -s $(which zsh)

silver_searcher_from_source() {
  git clone git://github.com/ggreer/the_silver_searcher.git /tmp/the_silver_searcher
  sudo aptitude install -y automake pkg-config libpcre3-dev zlib1g-dev liblzma-dev
  sh /tmp/the_silver_searcher/build.sh
  cd /tmp/the_silver_searcher
  sh build.sh
  sudo make install
  cd
  rm -rf /tmp/the_silver_searcher
}

if ! command -v ag >/dev/null; then
  fancy_echo "Installing The Silver Searcher (better than ack or grep) to search the contents of files ..."

  if aptitude show silversearcher-ag &>/dev/null; then
    install_if_needed silversearcher-ag
  else
    silver_searcher_from_source
  fi
fi

chruby_from_source() {
  wget -O /tmp/chruby-0.3.9.tar.gz https://github.com/postmodern/chruby/archive/v0.3.9.tar.gz
  cd /tmp/
  tar -xzvf chruby-0.3.9.tar.gz
  cd /tmp/chruby-0.3.9/
  sudo make install
  cd
  rm -rf /tmp/chruby-0.3.9/

  append_to_zshrc 'source /usr/local/share/chruby/chruby.sh'
  append_to_zshrc 'source /usr/local/share/chruby/auto.sh'
}

ruby_install_from_source() {
  wget -O /tmp/ruby-install-0.5.0.tar.gz https://github.com/postmodern/ruby-install/archive/v0.5.0.tar.gz
  cd /tmp/
  tar -xzvf ruby-install-0.5.0.tar.gz
  cd /tmp/ruby-install-0.5.0/
  sudo make install
  cd
  rm -rf /tmp/ruby-install-0.5.0/
}

chruby_from_source
ruby_version="2.2.2"

fancy_echo "Installing ruby-install for super easy installation of rubies..."
ruby_install_from_source

fancy_echo "Installing Ruby $ruby_version ..."
ruby-install ruby "$ruby_version"

fancy_echo "Loading chruby and changing to Ruby $ruby_version ..."
source ~/.zshrc
chruby $ruby_version

fancy_echo "Setting default Ruby to $ruby_version ..."
append_to_zshrc "chruby ruby-$ruby_version"

fancy_echo "Updating to latest Rubygems version ..."
gem update --system

fancy_echo "Installing Bundler to install project-specific Ruby gems ..."
gem install bundler --no-document --pre

fancy_echo "Configuring Bundler for faster, parallel gem installation ..."
number_of_cores=$(nproc)
bundle config --global jobs $((number_of_cores - 1))

fancy_echo "Installing Suspenders, thoughtbot's Rails template ..."
gem install suspenders --no-document

fancy_echo "Installing Parity, shell commands for development, staging, and production parity ..."
gem install parity --no-document

fancy_echo "Installing Heroku CLI client ..."
curl -s https://toolbelt.heroku.com/install-ubuntu.sh | sh

fancy_echo "Installing the heroku-config plugin to pull config variables locally to be used as ENV variables ..."
heroku plugins:install git://github.com/ddollar/heroku-config.git

# Ruby/Rails stack done! Now let's go!

fancy_echo "Installing Golang..."
sudo apt-get install golang

fancy_echo "Setting up Go workspace..."
if [[ ! -d "$HOME/gocode/" ]]; then
  mkdir "$HOME/gocode"
fi
if [[ ! -d "$HOME/gocode/src/github.com/kyleries/" ]]; then
  mkdir "$HOME/gocode/src/github.com/kyleries/"
fi
append_to_zshrc 'export GOPATH="$HOME/gocode"'
source ~/.zshrc

fancy_echo "Installing GitHub CLI client ..."
go get github.com/github/hub

fancy_echo "Aliasing hub to git..."
append_to_zshrc 'eval "$(hub alias -s)"'
source ~/.zshrc

fancy_echo "Installing homesick to manage dotfiles..."
gem install homesick --no-document

fancy_echo "Setup dotfiles via homesick..."
sudo -H -u $USERNAME homesick clone git@github.com:kyleries/dotfiles.git
sudo -H -u $USERNAME homesick symlink dotfiles
