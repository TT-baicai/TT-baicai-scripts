#!/bin/bash
# ================================================
#  服务器健康巡检脚本 v1.0
#  用法: bash server_check.sh
# ================================================

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
WHITE='\033[1;37m'
GRAY='\033[0;37m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m' # No Color

# 状态图标
OK="${GREEN}✓${NC}"
WARN="${YELLOW}⚠${NC}"
FAIL="${RED}✗${NC}"
INFO="${CYAN}→${NC}"

# 分隔线
LINE="${DIM}────────────────────────────────────────────────────────${NC}"
DLINE="${CYAN}════════════════════════════════════════════════════════${NC}"

# 打印标题
print_header() {
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
    echo ""
}

# 打印章节标题
section() {
    echo ""
    echo -e "${LINE}"
    echo -e "  ${BOLD}${BLUE}▶ $1${NC}"
    echo -e "${LINE}"
}

# 格式化输出行
row() {
    local label="$1"
    local value="$2"
    local color="${3:-$WHITE}"
    printf "  ${GRAY}%-20s${NC} ${color}%s${NC}\n" "$label" "$value"
}

# 状态行
status_row() {
    local label="$1"
    local status="$2"  # ok/warn/fail
    local value="$3"
    local icon
    local color
    case $status in
        ok)   icon="$OK";   color="$GREEN"  ;;
        warn) icon="$WARN"; color="$YELLOW" ;;
        fail) icon="$FAIL"; color="$RED"    ;;
        *)    icon="$INFO"; color="$WHITE"  ;;
    esac
    printf "  ${GRAY}%-20s${NC} %b ${color}%s${NC}\n" "$label" "$icon" "$value"
}

# ================================================
# 1. 系统基础信息
# ================================================
section "系统信息"

HOSTNAME=$(hostname)
OS=$(grep PRETTY_NAME /etc/os-release 2>/dev/null | cut -d'"' -f2 || uname -s)
KERNEL=$(uname -r)
ARCH=$(uname -m)
UPTIME=$(uptime -p 2>/dev/null || uptime | awk -F'up ' '{print $2}' | awk -F',' '{print $1}')
LOAD=$(cat /proc/loadavg | awk '{print $1", "$2", "$3}')
CPU_CORES=$(nproc)
CPU_MODEL=$(grep "model name" /proc/cpuinfo 2>/dev/null | head -1 | cut -d':' -f2 | xargs || echo "未知")

row "主机名" "$HOSTNAME" "$WHITE"
row "系统" "$OS" "$WHITE"
row "内核" "$KERNEL" "$GRAY"
row "架构" "$ARCH" "$GRAY"
row "运行时间" "$UPTIME" "$GREEN"
row "CPU" "$CPU_MODEL" "$WHITE"
row "CPU核心" "${CPU_CORES} 核" "$WHITE"
row "系统负载" "$LOAD" "$YELLOW"

# ================================================
# 2. 内存使用
# ================================================
section "内存 & Swap"

MEM_TOTAL=$(free -m | awk '/^Mem:/{print $2}')
MEM_USED=$(free -m | awk '/^Mem:/{print $3}')
MEM_FREE=$(free -m | awk '/^Mem:/{print $4}')
MEM_PCT=$(( MEM_USED * 100 / MEM_TOTAL ))
SWAP_TOTAL=$(free -m | awk '/^Swap:/{print $2}')
SWAP_USED=$(free -m | awk '/^Swap:/{print $3}')

# 内存进度条
bar_width=30
filled=$(( MEM_PCT * bar_width / 100 ))
empty=$(( bar_width - filled ))
bar=""
for ((i=0; i<filled; i++)); do bar+="█"; done
for ((i=0; i<empty; i++)); do bar+="░"; done

if [ $MEM_PCT -ge 90 ]; then
    bar_color=$RED
elif [ $MEM_PCT -ge 70 ]; then
    bar_color=$YELLOW
else
    bar_color=$GREEN
fi

printf "  ${GRAY}%-20s${NC} ${bar_color}%s${NC} ${WHITE}%s%%${NC} ${GRAY}(%sMiB / %sMiB)${NC}\n" \
    "物理内存" "$bar" "$MEM_PCT" "$MEM_USED" "$MEM_TOTAL"

if [ "$SWAP_TOTAL" -gt 0 ]; then
    SWAP_PCT=$(( SWAP_USED * 100 / SWAP_TOTAL ))
    swap_filled=$(( SWAP_PCT * bar_width / 100 ))
    swap_empty=$(( bar_width - swap_filled ))
    swap_bar=""
    for ((i=0; i<swap_filled; i++)); do swap_bar+="█"; done
    for ((i=0; i<swap_empty; i++)); do swap_bar+="░"; done
    printf "  ${GRAY}%-20s${NC} ${YELLOW}%s${NC} ${WHITE}%s%%${NC} ${GRAY}(%sMiB / %sMiB)${NC}\n" \
        "Swap" "$swap_bar" "$SWAP_PCT" "$SWAP_USED" "$SWAP_TOTAL"
else
    row "Swap" "未启用" "$GRAY"
fi

# ================================================
# 3. 磁盘使用
# ================================================
section "磁盘空间"

df -h | grep -E '^/dev|^overlay' | while read line; do
    fs=$(echo $line | awk '{print $1}')
    size=$(echo $line | awk '{print $2}')
    used=$(echo $line | awk '{print $3}')
    avail=$(echo $line | awk '{print $4}')
    pct=$(echo $line | awk '{print $5}' | tr -d '%')
    mount=$(echo $line | awk '{print $6}')

    disk_filled=$(( pct * bar_width / 100 ))
    disk_empty=$(( bar_width - disk_filled ))
    disk_bar=""
    for ((i=0; i<disk_filled; i++)); do disk_bar+="█"; done
    for ((i=0; i<disk_empty; i++)); do disk_bar+="░"; done

    if [ "$pct" -ge 90 ]; then
        dcolor=$RED
        dstatus="危险"
    elif [ "$pct" -ge 75 ]; then
        dcolor=$YELLOW
        dstatus="偏高"
    else
        dcolor=$GREEN
        dstatus="正常"
    fi

    printf "  ${GRAY}%-18s${NC} ${dcolor}%s${NC} ${WHITE}%3s%%${NC} ${GRAY}可用:%s / 共:%s${NC}  ${dcolor}[%s]${NC}\n" \
        "$mount" "$disk_bar" "$pct" "$avail" "$size" "$dstatus"
done

# ================================================
# 4. 关键服务状态
# ================================================
section "服务状态"

check_service() {
    local name="$1"
    local service="$2"
    if systemctl is-active --quiet "$service" 2>/dev/null; then
        status_row "$name" "ok" "运行中"
    elif systemctl list-units --all 2>/dev/null | grep -q "$service"; then
        status_row "$name" "fail" "已停止"
    else
        status_row "$name" "warn" "未安装"
    fi
}

check_service "SSH" "ssh"
check_service "Nginx" "nginx"
check_service "Apache" "apache2"
check_service "Docker" "docker"
check_service "防火墙 UFW" "ufw"
check_service "Fail2Ban" "fail2ban"
check_service "Caddy" "caddy"
check_service "Cron" "cron"

# Docker 容器状态
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

# SSH端口
SSH_PORT=$(ss -tlnp | grep sshd | awk '{print $4}' | grep -oP ':\K\d+' | head -1)
if [ "$SSH_PORT" == "22" ]; then
    status_row "SSH端口" "warn" "22 (建议修改)"
elif [ -n "$SSH_PORT" ]; then
    status_row "SSH端口" "ok" "$SSH_PORT (非标准端口)"
fi

# 密码登录
PASSWD_AUTH=$(grep "^PasswordAuthentication" /etc/ssh/sshd_config /etc/ssh/sshd_config.d/*.conf 2>/dev/null | grep -v "no" | wc -l)
if [ "$PASSWD_AUTH" -eq 0 ]; then
    status_row "密码登录" "ok" "已禁用"
else
    status_row "密码登录" "warn" "已启用 (建议禁用)"
fi

# Root登录
ROOT_LOGIN=$(grep "^PermitRootLogin yes" /etc/ssh/sshd_config /etc/ssh/sshd_config.d/*.conf 2>/dev/null | wc -l)
if [ "$ROOT_LOGIN" -eq 0 ]; then
    status_row "Root登录" "ok" "已禁止"
else
    status_row "Root登录" "fail" "允许 (危险!)"
fi

# Fail2Ban封禁数
if command -v fail2ban-client &>/dev/null && systemctl is-active --quiet fail2ban 2>/dev/null; then
    BANNED=$(fail2ban-client status sshd 2>/dev/null | grep "Banned IP" | awk '{print $NF}' || echo "0")
    status_row "Fail2Ban封禁" "ok" "已封禁 ${BANNED} 个IP"
fi

# UFW状态
if command -v ufw &>/dev/null; then
    UFW_STATUS=$(ufw status 2>/dev/null | head -1 | awk '{print $2}')
    if [ "$UFW_STATUS" == "active" ]; then
        status_row "防火墙UFW" "ok" "已启用"
    else
        status_row "防火墙UFW" "fail" "未启用"
    fi
fi

# 登录用户
LOGGED_IN=$(who | wc -l)
status_row "当前登录用户" "info" "${LOGGED_IN} 个"

# ================================================
# 6. 网络连通性测试
# ================================================
section "网络连通性"

ping_test() {
    local name="$1"
    local host="$2"
    local result=$(ping -c 3 -W 3 "$host" 2>/dev/null)
    if [ $? -eq 0 ]; then
        local avg=$(echo "$result" | grep "avg" | awk -F'/' '{print $5}' | cut -d'.' -f1)
        local loss=$(echo "$result" | grep "packet loss" | awk '{print $6}')
        if [ "${loss}" == "0%" ]; then
            status_row "$name" "ok" "延迟 ${avg}ms  丢包 ${loss}"
        else
            status_row "$name" "warn" "延迟 ${avg}ms  丢包 ${loss}"
        fi
    else
        status_row "$name" "fail" "不可达"
    fi
}

echo -e "  ${DIM}正在测试网络连通性，请稍候...${NC}"
ping_test "Google DNS"      "8.8.8.8"
ping_test "Cloudflare DNS"  "1.1.1.1"
ping_test "阿里云DNS"        "223.5.5.5"
ping_test "腾讯云DNS"        "119.29.29.29"
ping_test "GitHub"          "github.com"

# ================================================
# 7. 网络测速
# ================================================
section "网络速度测试"

echo -e "  ${DIM}正在测试下载速度，请稍候（约10秒）...${NC}"

# 测试下载速度（使用多个节点）
speed_test() {
    local name="$1"
    local url="$2"
    local speed=$(curl -o /dev/null -s -w "%{speed_download}" \
        --max-time 8 --connect-timeout 3 "$url" 2>/dev/null)
    if [ $? -eq 0 ] && [ -n "$speed" ] && [ "$speed" != "0" ]; then
        # 转换为 Mbps
        local mbps=$(echo "$speed" | awk '{printf "%.2f", $1/1024/1024*8}')
        local mbps_int=$(echo "$mbps" | cut -d'.' -f1)
        if [ "$mbps_int" -ge 100 ] 2>/dev/null; then
            printf "  ${GRAY}%-20s${NC} ${GREEN}%-10s Mbps${NC} ${GREEN}▓▓▓▓▓▓▓▓▓▓ 极速${NC}\n" "$name" "$mbps"
        elif [ "$mbps_int" -ge 50 ] 2>/dev/null; then
            printf "  ${GRAY}%-20s${NC} ${CYAN}%-10s Mbps${NC} ${CYAN}▓▓▓▓▓▓░░░░ 良好${NC}\n" "$name" "$mbps"
        elif [ "$mbps_int" -ge 10 ] 2>/dev/null; then
            printf "  ${GRAY}%-20s${NC} ${YELLOW}%-10s Mbps${NC} ${YELLOW}▓▓▓░░░░░░░ 一般${NC}\n" "$name" "$mbps"
        else
            printf "  ${GRAY}%-20s${NC} ${RED}%-10s Mbps${NC} ${RED}▓░░░░░░░░░ 较慢${NC}\n" "$name" "$mbps"
        fi
    else
        printf "  ${GRAY}%-20s${NC} ${RED}测试失败${NC}\n" "$name"
    fi
}

speed_test "Cloudflare" "https://speed.cloudflare.com/__down?bytes=10000000"
speed_test "GitHub Raw" "https://raw.githubusercontent.com/torvalds/linux/master/README"
speed_test "阿里云OSS" "https://mirrors.aliyun.com/ubuntu/ls-lR.gz"

# ================================================
# 8. 系统更新
# ================================================
section "系统更新"

if command -v apt &>/dev/null; then
    UPDATES=$(apt list --upgradable 2>/dev/null | grep -c upgradable 2>/dev/null || echo 0)
    SECURITY=$(apt list --upgradable 2>/dev/null | grep -c security 2>/dev/null || echo 0)
    if [ "$UPDATES" -eq 0 ]; then
        status_row "可用更新" "ok" "系统已是最新"
    elif [ "$SECURITY" -gt 0 ]; then
        status_row "可用更新" "warn" "${UPDATES} 个更新 (含 ${SECURITY} 个安全更新)"
    else
        status_row "可用更新" "info" "${UPDATES} 个更新可用"
    fi
fi

# 检查是否需要重启
if [ -f /var/run/reboot-required ]; then
    status_row "系统重启" "warn" "需要重启以完成更新"
else
    status_row "系统重启" "ok" "无需重启"
fi

# ================================================
# 汇总
# ================================================
echo ""
echo -e "${DLINE}"
echo -e "  ${BOLD}${WHITE}巡检完成${NC}  ${DIM}$(date '+%Y-%m-%d %H:%M:%S')${NC}"
echo -e "${DLINE}"
echo ""
