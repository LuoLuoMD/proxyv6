#!/bin/bash
# ---------------------------------------------
# 💼 Auto IPv6 Proxy Installer by MINH DUC 💼
# Version: 3Proxy 0.9.5 | IPv6 Proxy Generator
# ---------------------------------------------

WORKDIR="/home/3proxy"
WORKDATA="${WORKDIR}/data.txt"

PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin

# ========== 🎲 Hàm random user/pass ==========
random() {
    tr </dev/urandom -dc A-Za-z0-9 | head -c5
    echo
}

# ========== 📦 Sinh IPv6 ngẫu nhiên ==========
array=(1 2 3 4 5 6 7 8 9 0 a b c d e f)
gen64() {
    ip64() {
        echo "${array[$RANDOM % 16]}${array[$RANDOM % 16]}${array[$RANDOM % 16]}${array[$RANDOM % 16]}"
    }
    echo "$1:$(ip64):$(ip64):$(ip64):$(ip64)"
}

# ========== ⚙️ Cài đặt 3proxy ==========
install_3proxy() {
    echo -e "\n📥 Đang cài đặt 3proxy 0.9.5..."
    URL="https://github.com/z3APA3A/3proxy/archive/refs/tags/0.9.5.tar.gz"
    wget -qO- "$URL" | bsdtar -xvf-
    cd 3proxy-0.9.5 || exit
    make -f Makefile.Linux
    mkdir -p /usr/local/etc/3proxy/{bin,logs,stat}
    cp src/3proxy /usr/local/etc/3proxy/bin/
    cd "$WORKDIR" || exit
}

# ========== 📊 Sinh dữ liệu proxy ==========
gen_data() {
    seq $FIRST_PORT $LAST_PORT | while read -r port; do
        echo "${PROXY_USER}/${PROXY_PASS}/${IP4}/${port}/$(gen64 $IP6)"
    done
}

# ========== 📄 Tạo cấu hình 3proxy ==========
gen_3proxy() {
    cat <<EOF
daemon
maxconn 4000
nserver 1.1.1.1
nserver 8.8.4.4
nserver 2001:4860:4860::8888
nserver 2001:4860:4860::8844
nscache 65536
timeouts 1 5 30 60 180 1800 15 60
setgid 65535
setuid 65535
stacksize 6291456
flush
auth strong

users ${PROXY_USER}:CL:${PROXY_PASS}

$(awk -F "/" '{print "auth strong\n" "allow " $1 "\n" "proxy -6 -n -a -p" $4 " -i" $3 " -e"$5"\n" "flush\n"}' ${WORKDATA})
EOF
}

gen_iptables() {
    awk -F "/" '{print "iptables -I INPUT -p tcp --dport " $4 " -m state --state NEW -j ACCEPT"}' ${WORKDATA}
}

gen_ifconfig() {
    awk -F "/" '{print "ifconfig eth0 inet6 add " $5 "/64"}' ${WORKDATA}
}

gen_proxy_file_for_user() {
    awk -F "/" '{print $3 ":" $4 ":" $1 ":" $2 }' ${WORKDATA} > proxy.txt
}

# ========== 🚀 Bắt đầu tiến trình ==========
clear
echo -e "\n🛠️  SCRIPT CÀI ĐẶT PROXY IPv6 - BY MINH DUC 🛠️"
echo -e "==============================================="

read -p "🔢 Nhập số lượng proxy IPv6 cần tạo [default: 100]: " COUNT
COUNT=${COUNT:-100}

read -p "👤 Nhập USERNAME proxy [default: userv6]: " PROXY_USER
PROXY_USER=${PROXY_USER:-userv6}

read -p "🔐 Nhập PASSWORD proxy [default: passv6]: " PROXY_PASS
PROXY_PASS=${PROXY_PASS:-passv6}

# ========== 📦 Cài gói cần thiết ==========
echo -e "\n📦 Đang cài các gói cần thiết..."
yum install -y epel-release
yum install -y gcc net-tools bsdtar zip wget curl make >/dev/null

# ========== 🛠️ Cài và cấu hình 3proxy ==========
install_3proxy

echo "📁 Thư mục làm việc: ${WORKDIR}"
mkdir -p "$WORKDIR" && cd "$WORKDIR" || exit

IP4=$(curl -4 -s icanhazip.com)
IP6=$(curl -6 -s icanhazip.com | cut -f1-4 -d':')

FIRST_PORT=40000
LAST_PORT=$((FIRST_PORT + COUNT - 1))

gen_data > "$WORKDATA"
gen_3proxy > /usr/local/etc/3proxy/3proxy.cfg
gen_iptables > "$WORKDIR/boot_iptables.sh"
gen_ifconfig > "$WORKDIR/boot_ifconfig.sh"

chmod +x "$WORKDIR/boot_iptables.sh" "$WORKDIR/boot_ifconfig.sh"

cat >> /etc/rc.local <<EOF
bash ${WORKDIR}/boot_iptables.sh
bash ${WORKDIR}/boot_ifconfig.sh
ulimit -n 10048
/usr/local/etc/3proxy/bin/3proxy /usr/local/etc/3proxy/3proxy.cfg
EOF

chmod +x /etc/rc.local
bash /etc/rc.local

gen_proxy_file_for_user

echo -e "\n✅ Hoàn tất! File proxy.txt đã được tạo."
echo -e "📝 Định dạng: IP:PORT:USERNAME:PASSWORD"
echo -e "📍 Vị trí: ${WORKDIR}/proxy.txt"
