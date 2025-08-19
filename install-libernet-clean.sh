#!/bin/bash

 

# 🔄 Update dan install bash & curl
echo "📦 Mengupdate paket dan menginstal bash & curl..."
opkg update && opkg install bash curl

# ⬇️ Jalankan installer Libernet resmi
echo "📥 Mengunduh dan menjalankan installer Libernet..."
bash -c "$(curl -fsSL 'https://raw.githubusercontent.com/dotywrt/libernet/main/install.sh')"

# 🧩 Tambahkan menu LuCI untuk Libernet
echo "🛠️  Menambahkan menu Libernet ke LuCI..."
cat <<'EOF' > /usr/lib/lua/luci/controller/libernet.lua
module("luci.controller.libernet", package.seeall)
function index()
entry({"admin","services","libernet"}, template("libernet"), _("Libernet"), 55).leaf=true
end
EOF

cat <<'EOF' > /usr/lib/lua/luci/view/libernet.htm
<%+header%>
<div class="cbi-map">
<iframe id="libernet" style="width: 100%; min-height: 650px; border: none; border-radius: 2px;"></iframe>
</div>
<script type="text/javascript">
document.getElementById("libernet").src = "http://" + window.location.hostname + "/libernet";
</script>
<%+footer%>
EOF

# 🧹 Hapus autentikasi dari file PHP Libernet
echo "🧼 Membersihkan autentikasi dari file PHP..."
for file in index.php config.php about.php speedtest.php system.php; do
  target="/www/libernet/$file"
  if [ -f "$target" ]; then
    echo "✅ Membersihkan $file ..."
    sed -i '/include[[:space:]]*(["'"'"']auth.php["'"'"'])[[:space:]]*;/d' "$target"
    sed -i '/check_session[[:space:]]*(.*)[[:space:]]*;/d' "$target"
  else
    echo "⚠️  File tidak ditemukan: $target"
  fi
done

# 📢 Selesai
echo -e "\n🎉 ${GREEN}Libernet telah dipasang dan dibersihkan dari login!${NC}"
echo -e "🌐 Silakan akses melalui: ${YELLOW}LuCI → Services → Libernet${NC}"
echo -e "atau buka langsung: ${YELLOW}http://<IP-Router>/libernet${NC}"
