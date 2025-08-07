#!/bin/bash

# Biến cấu hình
PROXY_USER="proxyuser"
PROXY_PASS="proxypass"
COUNT=100
IPV6_NET="2001:db8:100::"
IPV6_INTERFACE=$(ip -6 route show default | awk '{print $5}' | head -n1)

# Cài đặt các gói cần thiết
yum install -y gcc git make wget net-tools

# Tải 3proxy 0.9.5 nếu chưa có
cd /root
if [ ! -d "3proxy-0.9.5" ]; then
  wget https://github.com/z3APA3A/3proxy/archive/refs/tags/0.9.5.tar.gz
  tar -xvzf 0.9.5.tar.gz
fi

# Build 3proxy
cd /root/3proxy-0.9.5
make -f Makefile.Linux

# Tạo thư mục chứa proxy
mkdir -p /home/3proxy
cd /home/3proxy

# Lấy địa chỉ IPv4
IP4=$(curl -s ipv4.icanhazip.com)

# Tạo danh sách proxy + cấu hình
echo > proxy.txt
for ((i=1;i<=$COUNT;i++)); do
    LAST_HEX=$(printf "%x\n" $i)
    IP6="$IPV6_NET$LAST_HEX"
    echo "$PROXY_USER:$PROXY_PASS:$IP4:100$i:$IP6" >> proxy.txt
done

# Tạo cấu hình 3proxy
cat <<EOF > 3proxy.cfg
daemon
maxconn 1000
nserver 8.8.8.8
nscache 65536
timeouts 1 5 30 60 180 1800 15 60
users $PROXY_USER:CL:$PROXY_PASS
auth strong
EOF

for ((i=1;i<=$COUNT;i++)); do
    LAST_HEX=$(printf "%x\n" $i)
    echo "proxy -6 -n -a -p100$i -i$IP4 -e$IPV6_NET$LAST_HEX" >> 3proxy.cfg
done

# Tạo interface IPv6
for ((i=1;i<=$COUNT;i++)); do
    LAST_HEX=$(printf "%x\n" $i)
    ip -6 addr add "$IPV6_NET$LAST_HEX"/64 dev "$IPV6_INTERFACE"
done

# Copy file chạy 3proxy
cp /root/3proxy-0.9.5/src/3proxy /usr/local/bin/3proxy
chmod +x /usr/local/bin/3proxy

# Chạy 3proxy
/usr/local/bin/3proxy /home/3proxy/3proxy.cfg

echo "✅ Proxy đã khởi động. File proxy nằm tại /home/3proxy/proxy.txt"
