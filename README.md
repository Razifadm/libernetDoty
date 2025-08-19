# Libernet
Libernet is open source web app for tunneling internet using SSH, V2Ray, Trojan, Shadowsocks, OpenVPN on OpenWRT with ease.
---
<p align="center">
  <img src="https://i.ibb.co/ccZHLCR/Screenshot-from-2022-02-22-13-50-31.png" alt="dashboard" />
</p>

#Installation
```
curl -fsSL -o install-libernet-clean.sh https://raw.githubusercontent.com/BootLoopLover/libernet/main/install-libernet-clean.sh
chmod +x install-libernet-clean.sh
./install-libernet-clean.sh
```

```
wget https://raw.githubusercontent.com/BootLoopLover/libernet/refs/heads/main/install-libernet-clean.sh
sh install-libernet-clean.sh
#done
```

## Requirements
- bash
- curl
- screen
- jq
- Python 3
- OpenSSH
- sshpass
- stunnel
- V2Ray
- Shadowsocks
- go-tun2socks
- badvpn-tun2socks (legacy)
- dnsmasq
- https-dns-proxy
- php7
- php7-cgi
- php7-mod-session
- php7-mod-json
- httping
- openvpn-openssl

## Working Features:
- SSH with proxy
- SSH-SSL
- SSH-WS-SSL (CDN)
- V2Ray VMess
- V2Ray VLESS
- V2Ray Trojan
- Trojan
- Shadowsocks
- OpenVPN

## Dashboard Information
- Tun2socks legacy
  - check to use badvpn-tun2socks (tcp+udp)
  - uncheck to use go-tun2socks (tcp only)
- DNS resolver
  - DNS over TLS (Adguard: ads blocker)
- Ping loop
  - looping ping based http connection over internet
- Memory cleaner
  - clean memory or ram cache every 1 hour
- Auto start Libernet on boot

<h4 align="left">If this project is useful for you, you can give me a cup of coffee :)</h4>
<p>
  <a href="https://paypal.me/lutfailham">
      <img src="https://www.paypalobjects.com/en_US/i/btn/btn_donateCC_LG.gif" alt="paypal">
  </a>
</p>
