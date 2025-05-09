#!/bin/bash

# Libernet Installer
# by Lutfa Ilham
# v1.0.0
# Modified by TEB

if [ "$(id -u)" != "0" ]; then
  echo "This script must be run as root" 1>&2
  exit 1
fi

HOME="/root"
ARCH="$(grep 'DISTRIB_ARCH' /etc/openwrt_release | awk -F '=' '{print $2}' | sed "s/'//g")"
LIBERNET_DIR="${HOME}/libernet"
LIBERNET_WWW="/www/libernet"
STATUS_LOG="${LIBERNET_DIR}/log/status.log"
DOWNLOADS_DIR="${HOME}/Downloads"
LIBERNET_TMP="${DOWNLOADS_DIR}/libernet"
REPOSITORY_URL="https://github.com/pru79/libernet"

function run_patch_script() {
    echo -e "\nRunning patch script to disable authentication..."
    
    # Find files containing the target lines and store them in a variable
    files=$(grep -lE "include\('auth.php'\)|check_session\(\)" /www/libernet/* 2>/dev/null)

    # Check if any files were found
    if [ -z "$files" ]; then
        echo "No files containing auth patterns found."
        return 0
    fi

    # Display the list of files being modified
    echo "Disabling auth code from:"
    echo "$files" | sed 's/^/  /'
    echo

    # Iterate over each file
    for file in $files; do
        # Make a backup of the original file
        cp "$file" "$file.bak"

        # Use sed to comment out the lines
        sed -i -e "/include('auth.php')/s/^/# /" \
               -e "/check_session()/s/^/# /" "$file"

        echo "Updated: $file"
    done

    echo "Done. Original files were backed up with .bak extension."
}

function install_packages() {
  while IFS= read -r line; do
    if [[ $(opkg list-installed "${line}" | grep -c "${line}") != "1" ]]; then
      if [[ "${line}" == "dnsmasq" ]]; then
        if [[ $(opkg list-installed dnsmasq-full | grep -c dnsmasq-full) != "1" ]]; then
          opkg install "${line}"
        else
          echo "dnsmasq-full is already installed, skipping dnsmasq."
        fi
      else
        opkg install "${line}"
      fi
    fi
  done < requirements.txt
}

function install_proprietary_binaries() {
  echo -e "Installing proprietary binaries"
  while IFS= read -r line; do
    if ! which ${line} > /dev/null 2>&1; then
      bin="/usr/bin/${line}"
      echo "Installing ${line} ..."
      curl -sLko "${bin}" "https://github.com/pru79/libernet-proprietary/raw/main/${ARCH}/binaries/${line}"
      chmod +x "${bin}"
    fi
  done < binaries.txt
}

function install_proprietary_packages() {
  echo -e "Installing proprietary packages"
  while IFS= read -r line; do
    if ! which ${line} > /dev/null 2>&1; then
      pkg="/tmp/${line}.ipk"
      echo "Installing ${line} ..."
      curl -sLko "${pkg}" "https://github.com/pru79/libernet-proprietary/raw/main/${ARCH}/packages/${line}.ipk"
      opkg install "${pkg}"
      rm -rf "${pkg}"
    fi
  done < packages.txt
}

function install_proprietary() {
  install_proprietary_binaries
  install_proprietary_packages
}

function install_prerequisites() {
  opkg update
}

function install_requirements() {
  echo -e "Installing packages" \
    && install_prerequisites \
    && install_packages \
    && install_proprietary
}

function enable_uhttp_php() {
  if ! grep -q ".php=/usr/bin/php-cgi" /etc/config/uhttpd; then
    echo -e "Enabling uhttp php execution" \
      && uci set uhttpd.main.interpreter='.php=/usr/bin/php-cgi' \
      && uci add_list uhttpd.main.index_page='index.php' \
      && uci commit uhttpd \
      && echo -e "Restarting uhttp service" \
      && /etc/init.d/uhttpd restart
  else
    echo -e "uhttp php already enabled, skipping ..."
  fi
}

function add_libernet_environment() {
  if ! grep -q LIBERNET_DIR /etc/profile; then
    echo -e "Adding Libernet environment" \
      && echo -e "\n# Libernet\nexport LIBERNET_DIR=${LIBERNET_DIR}" | tee -a '/etc/profile'
  fi
}

function install_libernet() {
  if [[ -f "${LIBERNET_DIR}/bin/service.sh" && $(cat "${STATUS_LOG}") != "0" ]]; then
    echo -e "Stopping Libernet"
    "${LIBERNET_DIR}/bin/service.sh" -ds > /dev/null 2>&1
  fi
  rm -rf "${LIBERNET_WWW}"
  echo -e "Installing Libernet" \
    && mkdir -p "${LIBERNET_DIR}" \
    && echo -e "Copying updater script" \
    && cp -avf update.sh "${LIBERNET_DIR}/" \
    && sed -i "s/^HOST=\".*\"/HOST=\"$bughost\"/" bin/ping-loop.sh \
    && echo "Ping target set to: $bughost" \
    && echo -e "Copying binary" \
    && cp -arvf bin "${LIBERNET_DIR}/" \
    && echo -e "Copying system" \
    && cp -arvf system "${LIBERNET_DIR}/" \
    && echo -e "Copying log" \
    && cp -arvf log "${LIBERNET_DIR}/" \
    && echo -e "Copying web files" \
    && mkdir -p "${LIBERNET_WWW}" \
    && cp -arvf web/* "${LIBERNET_WWW}/" \
    && echo -e "Configuring Libernet" \
    && sed -i "s/LIBERNET_DIR/$(echo ${LIBERNET_DIR} | sed 's/\//\\\//g')/g" "${LIBERNET_WWW}/config.inc.php"
}

function configure_libernet_firewall() {
  if ! uci get network.libernet > /dev/null 2>&1; then
    echo "Configuring Libernet firewall" \
      && uci set network.libernet=interface \
      && uci set network.libernet.proto='none' \
      && uci set network.libernet.ifname='tun1' \
      && uci commit \
      && uci add firewall zone \
      && uci set firewall.@zone[-1].network='libernet' \
      && uci set firewall.@zone[-1].name='libernet' \
      && uci set firewall.@zone[-1].masq='1' \
      && uci set firewall.@zone[-1].mtu_fix='1' \
      && uci set firewall.@zone[-1].input='REJECT' \
      && uci set firewall.@zone[-1].forward='REJECT' \
      && uci set firewall.@zone[-1].output='ACCEPT' \
      && uci commit \
      && uci add firewall forwarding \
      && uci set firewall.@forwarding[-1].src='lan' \
      && uci set firewall.@forwarding[-1].dest='libernet' \
      && uci commit \
      && /etc/init.d/network restart
  fi
}

function configure_libernet_service() {
  echo -e "Configuring Libernet service"
  /etc/init.d/stubby disable
  /etc/init.d/shadowsocks-libev disable
  /etc/init.d/openvpn disable
  /etc/init.d/stunnel disable
}

function setup_system_logs() {
  echo -e "Setup system logs"
  logs=("status.log" "service.log" "connected.log")
  for log in "${logs[@]}"; do
    if [[ ! -f "${LIBERNET_DIR}/log/${log}" ]]; then
      touch "${LIBERNET_DIR}/log/${log}"
    fi
  done
}

function finish_install() {
  router_ip="$(ifconfig br-lan | grep 'inet addr:' | awk '{print $2}' | awk -F ':' '{print $2}')"
  echo -e "Libernet successfully installed!\nLibernet URL: http://${router_ip}/libernet"
  run_patch_script
}

function main_installer() {
  install_requirements \
    && install_libernet \
    && add_libernet_environment \
    && enable_uhttp_php \
    && configure_libernet_firewall \
    && configure_libernet_service \
    && setup_system_logs \
    && finish_install \
    && teb_mod
}

function teb_mod() {
  mkdir -p /usr/lib/lua/luci/controller
  cat <<'EOF' >/usr/lib/lua/luci/controller/libernet.lua
module("luci.controller.libernet", package.seeall)
function index()
entry({"admin","services","libernet"}, template("libernet"), _("Libernet"), 55).leaf=true
end
EOF
  mkdir -p /usr/lib/lua/luci/view
  cat <<'EOF' >/usr/lib/lua/luci/view/libernet.htm
<%+header%>
<div class="cbi-map">
<iframe id="libernet" style="width: 100%; min-height: 650px; border: none; border-radius: 2px;"></iframe>
</div>
<script type="text/javascript">
document.getElementById("libernet").src = "http://" + window.location.hostname + "/libernet";
</script>
<%+footer%>
EOF
}

function main() {
  if [[ $(opkg list-installed git | grep -c git) != "1" ]]; then
    opkg update && opkg install git
  fi
  if [[ $(opkg list-installed git-http | grep -c git-http) != "1" ]]; then
    opkg update && opkg install git-http
  fi
  if [[ ! -d "${DOWNLOADS_DIR}" ]]; then
    mkdir -p "${DOWNLOADS_DIR}"
  fi

  if [[ ! -d "${LIBERNET_TMP}" ]]; then
    if git clone --depth 1 "${REPOSITORY_URL}" "${LIBERNET_TMP}" && cd "${LIBERNET_TMP}"; then
        echo
        read -rp "Please enter your bug host to ping infinitely [default: www.speedtest.net]: " bughost
        
        if [[ -z "$bughost" ]]; then
            bughost="www.speedtest.net"
            echo "Using default ping target: $bughost"
        fi

        main_installer
    else
        echo "Error: Failed to clone repository or enter directory"
        exit 1
    fi
  else
    cd "${LIBERNET_TMP}"
    echo
    read -rp "Please enter your bug host to ping infinitely [default: www.speedtest.net]: " bughost
    
    if [[ -z "$bughost" ]]; then
        bughost="www.speedtest.net"
        echo "Using default ping target: $bughost"
    fi
    
    if [[ -f "bin/ping-loop.sh" ]]; then
        sed -i "s/^HOST=\".*\"/HOST=\"$bughost\"/" bin/ping-loop.sh
        echo "Ping target set to: $bughost"
    else
        echo "Error: ping-loop.sh not found!"
        exit 1
    fi
    
    main_installer
  fi
}

main
