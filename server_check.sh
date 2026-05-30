#!/bin/bash
# ================================================
#  服务器健康巡检脚本 v1.3
#  用法: bash server_check.sh
# ================================================

# 颜色定义
RED=$'\033[0;31m'
GREEN=$'\033[0;32m'
YELLOW=$'\033[1;33m'
BLUE=$'\033[0;34m'
CYAN=$'\033[0;36m'
WHITE=$'\033[1;37m'
GRAY=$'\033[0;37m'
BOLD=$'\033[1m'
DIM=$'\033[2m'
NC=$'\033[0m'

OK="${GREEN}✓${NC}"
WARN="${YELLOW}⚠${NC}"
FAIL="${RED}✗${NC}"
INFO="${CYAN}→${NC}"

LINE="${DIM}────────────────────────────────────────────────────────${NC}"
DLINE="${CYAN}════════════════════════════════════════════════════════${NC}"

section() {
    echo ""
    echo -e "${LINE}"
    echo -e "  ${BOLD}${BLUE}▶ $1${NC}"
    echo -e "${LINE}"
}

row() {
    local label="$1" value="$2" color="${3:-$WHITE}"
    printf "  ${GRAY}%-20s${NC} ${color}%s${NC}\n" "$label" "$value"
}

status_row() {
    local label="$1" status="$2" value="$3"
    local icon color
    case $status in
        ok)   icon="$OK";   color="$GREEN"  ;;
        warn) icon="$WARN"; color="$YELLOW" ;;
        fail) icon="$FAIL"; color="$RED"    ;;
        *)    icon="$INFO"; color="$WHITE"  ;;
    esac
    printf "  ${GRAY}%-20s${NC} %b ${color}%s${NC}\n" "$label" "$icon" "$value"
}

make_bar() {
    local pct=$1 bar_width=30
    local filled=$(( pct * bar_width / 100 ))
    local empty=$(( bar_width - filled ))
    local bar=""
    for ((i=0; i<filled; i++)); do bar+="█"; done
    for ((i=0; i<empty; i++)); do bar+="░"; done
    echo "$bar"
}

# ================================================
# 标题
# ================================================
clear
echo -e "${DLINE}"
echo -e "${CYAN}${BOLD}"
echo -e "   ███████╗███████╗██████╗ ██╗   ██╗███████╗██████╗ "
echo -e "   ██╔════╝██╔════╝██╔══██╗██║   ██║██╔════╝██╔══██╗"
echo -e "   ███████╗█████╗  ██████╔╝██║   ██║█████╗  ██████╔╝"
echo -e "   ╚════██║██╔══╝  ██╔══██╗╚██╗ ██╔╝██╔══╝  ██╔══██╗"
echo -e "   ███████║███████╗██║  ██║ ╚████╔╝ ███████╗██║  ██║"
echo -e "   ╚══════╝╚══════╝╚═╝  ╚═╝  ╚═══╝  ╚══════╝╚═╝  ╚═╝"
echo -e "${NC}"
echo -e "   ${WHITE}${BOLD}服务器健康巡检报告${NC}  ${DIM}$(date '+%Y-%m-%d %H:%M:%S %Z')${NC}"
echo -e "${DLINE}"

# ================================================
# 1. 系统信息
# ================================================
section "系统信息"

HOSTNAME=$(hostname)
OS=$(grep PRETTY_NAME /etc/os-release 2>/dev/null | cut -d'"' -f2 || uname -s)
KERNEL=$(uname -r)
ARCH=$(uname -m)
UPTIME=$(uptime -p 2>/dev/null || uptime | awk -F'up ' '{print $2}' | awk -F',' '{print $1}')
LOAD=$(cat /proc/loadavg | awk '{print $1", "$2", "$3}')
CPU_CORES=$(nproc)
CPU_MODEL=$(grep -m1 "model name\|Model name\|Hardware\|cpu model" /proc/cpuinfo 2>/dev/null | cut -d':' -f2 | xargs)
[ -z "$CPU_MODEL" ] && CPU_MODEL=$(lscpu 2>/dev/null | grep -i "model name" | cut -d':' -f2 | xargs)
[ -z "$CPU_MODEL" ] && CPU_MODEL="$(uname -m) 处理器"

row "主机名" "$HOSTNAME" "$WHITE"
row "系统" "$OS" "$WHITE"
row "内核" "$KERNEL" "$GRAY"
row "架构" "$ARCH" "$GRAY"
row "运行时间" "$UPTIME" "$GREEN"
row "CPU" "$CPU_MODEL" "$WHITE"
row "CPU核心" "${CPU_CORES} 核" "$WHITE"
row "系统负载" "$LOAD" "$YELLOW"

# ================================================
# 2. 内存 & Swap
# ================================================
section "内存 & Swap"

MEM_TOTAL=$(free -m | awk '/^Mem:/{print $2}')
MEM_USED=$(free -m | awk '/^Mem:/{print $3}')
MEM_PCT=$(( MEM_USED * 100 / MEM_TOTAL ))
SWAP_TOTAL=$(free -m | awk '/^Swap:/{print $2}')
SWAP_USED=$(free -m | awk '/^Swap:/{print $3}')

MEM_BAR=$(make_bar $MEM_PCT)
if [ $MEM_PCT -ge 90 ]; then bar_color=$RED
elif [ $MEM_PCT -ge 70 ]; then bar_color=$YELLOW
else bar_color=$GREEN; fi
printf "  ${GRAY}%-20s${NC} ${bar_color}%s${NC} ${WHITE}%s%%${NC} ${GRAY}(%sMiB / %sMiB)${NC}\n" \
    "物理内存" "$MEM_BAR" "$MEM_PCT" "$MEM_USED" "$MEM_TOTAL"

if [ "$SWAP_TOTAL" -gt 0 ]; then
    SWAP_PCT=$(( SWAP_USED * 100 / SWAP_TOTAL ))
    SWAP_BAR=$(make_bar $SWAP_PCT)
    printf "  ${GRAY}%-20s${NC} ${YELLOW}%s${NC} ${WHITE}%s%%${NC} ${GRAY}(%sMiB / %sMiB)${NC}\n" \
        "Swap" "$SWAP_BAR" "$SWAP_PCT" "$SWAP_USED" "$SWAP_TOTAL"
else
    row "Swap" "未启用" "$GRAY"
fi

# ================================================
# 3. 磁盘空间
# ================================================
section "磁盘空间"

while read -r line; do
    pct=$(echo "$line" | awk '{print $5}' | tr -d '%')
    size=$(echo "$line" | awk '{print $2}')
    avail=$(echo "$line" | awk '{print $4}')
    mount=$(echo "$line" | awk '{print $6}')
    [[ "$mount" == /var/lib/docker* ]] && continue
    DISK_BAR=$(make_bar "$pct")
    if [ "$pct" -ge 90 ]; then dcolor=$RED; dstatus="危险"
    elif [ "$pct" -ge 75 ]; then dcolor=$YELLOW; dstatus="偏高"
    else dcolor=$GREEN; dstatus="正常"; fi
    printf "  ${GRAY}%-18s${NC} ${dcolor}%s${NC} ${WHITE}%3s%%${NC} ${GRAY}可用:%s / 共:%s${NC}  ${dcolor}[%s]${NC}\n" \
        "$mount" "$DISK_BAR" "$pct" "$avail" "$size" "$dstatus"
done < <(df -h | grep -E '^/dev')

# ================================================
# 4. 服务状态
# ================================================
section "服务状态"

check_service() {
    local name="$1" service="$2" optional="${3:-false}"
    if systemctl is-active --quiet "$service" 2>/dev/null; then
        status_row "$name" "ok" "运行中"
    elif systemctl list-unit-files 2>/dev/null | grep -q "^${service}"; then
        status_row "$name" "fail" "已停止"
    else
        [ "$optional" != "true" ] && status_row "$name" "warn" "未安装"
    fi
}

check_service "SSH" "ssh"
check_service "Nginx" "nginx" true
check_service "Apache" "apache2" true
check_service "Docker" "docker" true
check_service "Fail2Ban" "fail2ban" true
check_service "Caddy" "caddy" true
check_service "Cron" "cron"

if command -v ufw &>/dev/null; then
    UFW_STATUS=$(ufw status 2>/dev/null | head -1 | awk '{print $2}')
    if [ "$UFW_STATUS" == "active" ]; then
        status_row "防火墙 UFW" "ok" "已启用"
    else
        IPTS=$(iptables -L INPUT 2>/dev/null | wc -l)
        if [ "$IPTS" -gt 3 ]; then
            status_row "防火墙" "ok" "UFW未启用，检测到iptables规则"
        else
            status_row "防火墙 UFW" "warn" "未启用 (请确认云安全组已配置)"
        fi
    fi
fi

if command -v docker &>/dev/null && docker ps &>/dev/null 2>&1; then
    RUNNING=$(docker ps -q | wc -l)
    TOTAL=$(docker ps -aq | wc -l)
    STOPPED=$(( TOTAL - RUNNING ))
    if [ $STOPPED -gt 0 ]; then
        status_row "Docker容器" "warn" "运行:${RUNNING} 停止:${STOPPED} (共${TOTAL})"
    else
        status_row "Docker容器" "ok" "全部运行中 (共${TOTAL})"
    fi
fi

# ================================================
# 5. 安全状态
# ================================================
section "安全状态"

SSH_PORT=$(ss -tlnp 2>/dev/null | grep sshd | awk '{print $4}' | grep -oE '[0-9]+$' | head -1)
[ -z "$SSH_PORT" ] && SSH_PORT=$(ss -tlnp 2>/dev/null | grep ':22' | head -1 | awk '{print $4}' | grep -oE '[0-9]+$')
if [ "$SSH_PORT" == "22" ]; then
    status_row "SSH端口" "warn" "22 (建议修改)"
elif [ -n "$SSH_PORT" ]; then
    status_row "SSH端口" "ok" "$SSH_PORT (非标准端口 ✓)"
fi

PASSWD_AUTH=$(grep "^PasswordAuthentication" /etc/ssh/sshd_config \
    /etc/ssh/sshd_config.d/*.conf 2>/dev/null | grep -v " no" | wc -l)
[ "$PASSWD_AUTH" -eq 0 ] && status_row "密码登录" "ok" "已禁用" \
    || status_row "密码登录" "warn" "已启用 (建议禁用)"

ROOT_LOGIN=$(grep "^PermitRootLogin yes" /etc/ssh/sshd_config \
    /etc/ssh/sshd_config.d/*.conf 2>/dev/null | wc -l)
[ "$ROOT_LOGIN" -eq 0 ] && status_row "Root登录" "ok" "已禁止" \
    || status_row "Root登录" "fail" "允许 (危险!)"

if command -v fail2ban-client &>/dev/null && systemctl is-active --quiet fail2ban 2>/dev/null; then
    BANNED=$(fail2ban-client status sshd 2>/dev/null \
        | grep -i "banned ip\|currently banned" | grep -oE '[0-9]+' | tail -1)
    BANNED=${BANNED:-0}
    if [ "$BANNED" -gt 0 ]; then
        status_row "Fail2Ban封禁" "ok" "已封禁 ${BANNED} 个恶意IP"
    else
        status_row "Fail2Ban封禁" "ok" "运行中，暂无封禁"
    fi
fi

LOGGED_IN=$(who | wc -l)
[ "$LOGGED_IN" -le 2 ] && status_row "当前登录用户" "ok" "${LOGGED_IN} 个" \
    || status_row "当前登录用户" "warn" "${LOGGED_IN} 个 (较多)"

# ================================================
# 6. 网络带宽测速
# ================================================
section "网络带宽测速"

echo -e "  ${DIM}正在测试服务器上传/下载速度，请稍候（约30秒）...${NC}"
echo ""

# 通用进度条绘制函数（最大参考值 Mbps）
draw_speed_bar() {
    local mbps_int=$1 max_ref=${2:-200} bar_width=28
    local pct=$(( mbps_int >= max_ref ? 100 : mbps_int * 100 / max_ref ))
    local filled=$(( pct * bar_width / 100 ))
    local empty=$(( bar_width - filled ))
    local bar=""
    for ((i=0; i<filled; i++)); do bar+="▓"; done
    for ((i=0; i<empty; i++)); do bar+="░"; done
    echo "$bar"
}

# 根据速度设置 bar_color 和 grade 两个变量（直接赋值，避免子shell丢失颜色转义）
set_speed_grade() {
    local mbps_int=$1
    if   [ "$mbps_int" -ge 500 ]; then bar_color="$GREEN";  grade="极速 🚀"
    elif [ "$mbps_int" -ge 100 ]; then bar_color="$GREEN";  grade="优秀"
    elif [ "$mbps_int" -ge 30  ]; then bar_color="$CYAN";   grade="良好"
    elif [ "$mbps_int" -ge 5   ]; then bar_color="$YELLOW"; grade="一般"
    else                               bar_color="$RED";    grade="较慢"; fi
}

# 计算字符串的终端显示宽度（中文/全角字符占2格，ASCII占1格）
display_width() {
    local str="$1" width=0 char
    local i=0 len=${#str}
    while [ $i -lt $len ]; do
        char="${str:$i:1}"
        # 判断是否为多字节UTF-8首字节（中文等全角字符）
        if [[ "$char" > $'\x7f' ]]; then
            width=$(( width + 2 ))
            # 跳过UTF-8续字节
            i=$(( i + 1 ))
            while [ $i -lt $len ]; do
                local next="${str:$i:1}"
                if [[ "$next" > $'\x7f' ]] && [[ "$next" < $'\xc0' ]]; then
                    i=$(( i + 1 ))
                else
                    break
                fi
            done
        else
            width=$(( width + 1 ))
            i=$(( i + 1 ))
        fi
    done
    echo $width
}

# 按显示宽度右补空格，返回固定宽度的字符串
pad_name() {
    local str="$1" target=$2
    local w
    w=$(display_width "$str")
    local pad=$(( target - w ))
    local result="$str"
    for ((p=0; p<pad; p++)); do result+=" "; done
    echo "$result"
}

# —— 下载测速 ——
echo -e "  ${BOLD}${CYAN}▌ 下载测速${NC}"

# 使用多个节点，取最快结果
DL_URLS=(
    "https://speed.cloudflare.com/__down?bytes=50000000"
    "https://mirrors.aliyun.com/ubuntu/ls-lR.gz"
    "https://mirrors.cloud.tencent.com/ubuntu/ls-lR.gz"
)
DL_NAMES=("Cloudflare" "阿里云OSS" "腾讯云CDN")

best_dl=0
best_dl_name=""
best_dl_mbps="0.0"

for i in "${!DL_URLS[@]}"; do
    url="${DL_URLS[$i]}"
    name="${DL_NAMES[$i]}"
    padded=$(pad_name "$name" 12)
    speed=$(curl -o /dev/null -s -w "%{speed_download}" \
        --max-time 12 --connect-timeout 5 "$url" 2>/dev/null)
    if [ -n "$speed" ] && [ "$speed" != "0" ]; then
        mbps=$(echo "$speed" | awk '{printf "%.1f", $1/1024/1024*8}')
        mbps_int=$(echo "$speed" | awk '{printf "%d", $1/1024/1024*8}')
        set_speed_grade "$mbps_int"
        bar=$(draw_speed_bar "$mbps_int" 500)
        printf "  ${GRAY}%s${NC}  ${bar_color}%s${NC}  ${WHITE}%8s Mbps${NC}  ${bar_color}%s${NC}\n" \
            "$padded" "$bar" "$mbps" "$grade"
        if [ "$mbps_int" -gt "$best_dl" ]; then
            best_dl=$mbps_int
            best_dl_name=$name
            best_dl_mbps=$mbps
        fi
    else
        printf "  ${GRAY}%s${NC}  ${RED}%-28s  %8s Mbps  无法连接${NC}\n" \
            "$padded" "░░░░░░░░░░░░░░░░░░░░░░░░░░░░" "—"
    fi
done

echo ""
if [ "$best_dl" -gt 0 ]; then
    echo -e "  ${BOLD}${WHITE}最佳下载：${GREEN}${best_dl_mbps} Mbps${NC}  ${DIM}(via ${best_dl_name})${NC}"
fi
echo ""

# —— 上传测速 ——
echo -e "  ${BOLD}${YELLOW}▌ 上传测速${NC}"

# 使用 /dev/urandom 生成临时文件上传至公共测速端点
TMP_FILE=$(mktemp /tmp/speedtest_upload_XXXXXX)
dd if=/dev/urandom of="$TMP_FILE" bs=1M count=20 2>/dev/null

UL_URLS=(
    "https://speed.cloudflare.com/__up"
    "https://httpbin.org/post"
)
UL_NAMES=("Cloudflare" "httpbin.org")

best_ul=0
best_ul_name=""
best_ul_mbps="0.0"

for i in "${!UL_URLS[@]}"; do
    url="${UL_URLS[$i]}"
    name="${UL_NAMES[$i]}"
    padded=$(pad_name "$name" 12)
    speed=$(curl -o /dev/null -s -w "%{speed_upload}" \
        --max-time 15 --connect-timeout 5 \
        -X POST -F "file=@${TMP_FILE}" "$url" 2>/dev/null)
    if [ -n "$speed" ] && [ "$speed" != "0" ]; then
        mbps=$(echo "$speed" | awk '{printf "%.1f", $1/1024/1024*8}')
        mbps_int=$(echo "$speed" | awk '{printf "%d", $1/1024/1024*8}')
        set_speed_grade "$mbps_int"
        bar=$(draw_speed_bar "$mbps_int" 500)
        printf "  ${GRAY}%s${NC}  ${bar_color}%s${NC}  ${WHITE}%8s Mbps${NC}  ${bar_color}%s${NC}\n" \
            "$padded" "$bar" "$mbps" "$grade"
        if [ "$mbps_int" -gt "$best_ul" ]; then
            best_ul=$mbps_int
            best_ul_name=$name
            best_ul_mbps=$mbps
        fi
    else
        printf "  ${GRAY}%s${NC}  ${RED}%-28s  %8s Mbps  无法连接${NC}\n" \
            "$padded" "░░░░░░░░░░░░░░░░░░░░░░░░░░░░" "—"
    fi
done

rm -f "$TMP_FILE"

echo ""
if [ "$best_ul" -gt 0 ]; then
    echo -e "  ${BOLD}${WHITE}最佳上传：${YELLOW}${best_ul_mbps} Mbps${NC}  ${DIM}(via ${best_ul_name})${NC}"
fi

# ================================================
# 7. 系统更新
# ================================================
section "系统更新"

if command -v apt &>/dev/null; then
    UPDATES=$(apt list --upgradable 2>/dev/null | grep -c "/" | tr -d '[:space:]')
    SECURITY=$(apt list --upgradable 2>/dev/null | grep -c "security" | tr -d '[:space:]')
    UPDATES=${UPDATES:-0}; SECURITY=${SECURITY:-0}
    if [ "$UPDATES" -eq 0 ]; then
        status_row "可用更新" "ok" "系统已是最新"
    elif [ "$SECURITY" -gt 0 ]; then
        status_row "可用更新" "warn" "${UPDATES} 个更新 (含 ${SECURITY} 个安全更新)"
    else
        status_row "可用更新" "info" "${UPDATES} 个更新可用"
    fi
fi

if [ -f /var/run/reboot-required ]; then
    status_row "系统重启" "warn" "需要重启以完成更新"
else
    status_row "系统重启" "ok" "无需重启"
fi

# ================================================
# 完成
# ================================================
echo ""
echo -e "${DLINE}"
echo -e "  ${BOLD}${WHITE}巡检完成${NC}  ${DIM}v1.3  $(date '+%Y-%m-%d %H:%M:%S')${NC}"
echo -e "${DLINE}"
echo ""
