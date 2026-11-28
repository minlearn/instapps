###############

silent() { "$@" >/dev/null 2>&1 || { echo "Error running: $*"; echo "sth error"; exit 1; }; }


debmirror=${1:-http://archive.debian.org/debian}
echo -e "deb ${debmirror} bullseye main\ndeb ${debmirror} bullseye-updates main" > /etc/apt/sources.list # \ndeb ${debmirror}-security bullseye-security main

echo "Installing Dependencies"
silent apt-get update -y
silent apt-get install -y \
  curl \
  sudo \
  mc \
  gpg
echo "Installed Dependencies"

cat > /root/install.sh << 'EOL'
silent() { "$@" >/dev/null 2>&1 || { echo "Error running: $*"; echo "sth error"; exit 1; }; }
echo "Installing"
cd /root

echo "installing x11 supports"
silent apt-get install --no-install-recommends debconf-utils -y
echo keyboard-configuration  keyboard-configuration/unsupported_config_options       boolean true | debconf-set-selections >/dev/null 2>&1; \
echo keyboard-configuration  keyboard-configuration/switch   select  No temporary switch | debconf-set-selections >/dev/null 2>&1; \
echo keyboard-configuration  keyboard-configuration/unsupported_config_layout        boolean true | debconf-set-selections >/dev/null 2>&1; \
echo keyboard-configuration  keyboard-configuration/layoutcode       string  us | debconf-set-selections >/dev/null 2>&1; \
echo keyboard-configuration  keyboard-configuration/compose  select  No compose key | debconf-set-selections >/dev/null 2>&1; \
echo keyboard-configuration  keyboard-configuration/modelcode        string  pc105 | debconf-set-selections >/dev/null 2>&1; \
echo keyboard-configuration  keyboard-configuration/unsupported_options      boolean true | debconf-set-selections >/dev/null 2>&1; \
echo keyboard-configuration  keyboard-configuration/variant  select  English \(US\) | debconf-set-selections >/dev/null 2>&1; \
echo keyboard-configuration  keyboard-configuration/unsupported_layout       boolean true | debconf-set-selections >/dev/null 2>&1; \
echo keyboard-configuration  keyboard-configuration/model    select  Generic 105-key PC \(intl.\) | debconf-set-selections >/dev/null 2>&1; \
echo keyboard-configuration  keyboard-configuration/ctrl_alt_bksp    boolean false | debconf-set-selections >/dev/null 2>&1; \
echo keyboard-configuration  keyboard-configuration/layout   select | debconf-set-selections >/dev/null 2>&1; \
echo keyboard-configuration  keyboard-configuration/toggle   select  No toggling | debconf-set-selections >/dev/null 2>&1; \
echo keyboard-configuration  keyboard-configuration/variantcode      string | debconf-set-selections >/dev/null 2>&1; \
echo keyboard-configuration  keyboard-configuration/altgr    select  The default for the keyboard layout | debconf-set-selections >/dev/null 2>&1; \
echo keyboard-configuration  keyboard-configuration/xkb-keymap       select  us | debconf-set-selections >/dev/null 2>&1; \
echo keyboard-configuration  keyboard-configuration/optionscode      string | debconf-set-selections >/dev/null 2>&1; \
echo keyboard-configuration  keyboard-configuration/store_defaults_in_debconf_db     boolean true | debconf-set-selections >/dev/null 2>&1

silent apt-get install --no-install-recommends keyboard-configuration xserver-xorg xinit xterm libgtk-3-0 libwebkit2gtk-4.0-37 -y

chmod u+s /usr/lib/xorg/Xorg
touch /root/.Xauthority

cat <<EOF | debconf-set-selections
locales locales/locales_to_be_generated multiselect en_US.UTF-8 UTF-8,zh_CN.UTF-8 UTF-8,zh_HK.UTF-8 UTF-8,zh_SG.UTF-8 UTF-8,zh_TW.UTF-8 UTF-8
locales locales/default_environment_locale select en_US.UTF-8
EOF
silent apt-get install -y locales fonts-wqy-zenhei
dpkg-reconfigure --frontend=noninteractive locales
silent apt-get install -y ntpdate dwm chromium

silent apt-get install -y libx264-dev libavcodec-dev libavutil-dev libswscale-dev ffmpeg
silent apt-get install -y ssl-cert xauth x11-xkb-utils xkb-data procps libswitch-perl libyaml-tiny-perl libhash-merge-simple-perl libscalar-list-utils-perl liblist-moreutils-perl libtry-tiny-perl libdatetime-timezone-perl libdatetime-perl libgbm1
wget -q "https://github.com/kasmtech/KasmVNC/releases/download/v1.5.2/kasmvncserver_debian_bullseye_1.5.2_amd64.deb" -O /tmp/kasmvncserver.deb
dpkg -i /tmp/kasmvncserver.deb
rm -rf /tmp/kasmvncserver.deb

mkdir -p /root/.vnc
rm -rf /root/.vnc/xstartup
echo -e 'chromium --no-sandbox --disable-gpu &
exec dwm' > /root/.vnc/xstartup
chmod +x /root/.vnc/xstartup
rm -rf /root/.kasmpasswd
echo -e "root:$(openssl passwd -5 -salt kasm 123456):w" > /root/.kasmpasswd
touch /root/.vnc/.de-was-selected
rm -rf /root/.vnc/kasmvnc.yaml
echo -e 'network:
  protocol: http
  interface: 0.0.0.0
  websocket_port: 8000
  use_ipv4: true
  use_ipv6: true
  ssl:
    require_ssl: false' > /root/.vnc/kasmvnc.yaml
sed -i '/^\[Service\]/a User=root' /usr/lib/systemd/user/kasmvncserver\@.service
sed -i "s|WantedBy=default.target|WantedBy=multi-user.target|g" /usr/lib/systemd/user/kasmvncserver\@.service
mv /usr/lib/systemd/user/kasmvncserver\@.service /etc/systemd/system/kasmvncserver@.service

sed -i "/^127\.0\.0\.1/c 127.0.0.1   localhost $(hostname)" /etc/hosts
ntpdate time.nist.gov
systemctl enable -q --now kasmvncserver@:1.service

echo "Installed"

EOL
chmod +x /root/install.sh

cat > /root/changevncpw.sh << 'EOL'
read -p "new vnc password,dont be too complex: " pass </dev/tty
if [[ -n $pass ]]; then
    echo -e "root:$(openssl passwd -5 -salt kasm $pass):w" > /root/.kasmpasswd
    systemctl restart kasmvncserver@:1.service
fi
EOL
chmod +x /root/changevncpw.sh

bash /root/install.sh
echo "finished, please update the password for vnc by running /root/changevncpw.sh"

echo "Cleaning up"
silent apt-get -y autoremove
silent apt-get -y autoclean
echo "Cleaned"

##############
