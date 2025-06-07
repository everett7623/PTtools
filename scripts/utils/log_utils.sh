#!/bin/bash

# PTtools 日志工具函数
# 文件路径: scripts/utils/log_utils.sh

# 默认日志配置
LOG_PATH="${LOG_PATH:-/var/log/pttools}"
LOG_FILE="${LOG_FILE:-${LOG_PATH}/install.log}"
ERROR_LOG="${LOG_PATH}/error.log"
DEBUG_LOG="${LOG_PATH}/debug.log"

# 日志级别
LOG_LEVEL_DEBUG=0
LOG_LEVEL_INFO=1
LOG_LEVEL_WARN=2
LOG_LEVEL_ERROR=3

# 当前日志级别（默认INFO）
CURRENT_LOG_LEVEL=${CURRENT_LOG_LEVEL:-1}

# 初始化日志系统
init_logging() {
    # 创建日志目录
    mkdir -p "$LOG_PATH" 2>/dev/null || {
        echo -e "${RED}无法创建日志目录: $LOG_PATH${NC}"
        return 1
    }
    
    # 创建日志文件
    touch "$LOG_FILE" "$ERROR_LOG" "$DEBUG_LOG" 2>/dev/null || {
        echo -e "${RED}无法创建日志文件${NC}"
        return 1
    }
    
    # 设置权限
    chmod 644 "$LOG_FILE" "$ERROR_LOG" "$DEBUG_LOG" 2>/dev/null
    
    log_info "日志系统初始化完成"
    log_info "日志目录: $LOG_PATH"
    log_info "主日志: $LOG_FILE"
}

# 写入日志
write_log() {
    local level="$1"
    local message="$2"
    local log_file="$3"
    local timestamp="$(date +'%Y-%m-%d %H:%M:%S')"
    
    # 写入主日志文件
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE" 2>/dev/null
    
    # 写入特定级别日志文件
    if [[ -n "$log_file" ]] && [[ "$log_file" != "$LOG_FILE" ]]; then
        echo "[$timestamp] [$level] $message" >> "$log_file" 2>/dev/null
    fi
}

# DEBUG级别日志
log_debug() {
    local message="$1"
    
    if [[ $CURRENT_LOG_LEVEL -le $LOG_LEVEL_DEBUG ]]; then
        echo -e "${GRAY}[DEBUG]${NC} $message"
    fi
    
    write_log "DEBUG" "$message" "$DEBUG_LOG"
}

# INFO级别日志
log_info() {
    local message="$1"
    
    if [[ $CURRENT_LOG_LEVEL -le $LOG_LEVEL_INFO ]]; then
        echo -e "${GREEN}[INFO]${NC} $message"
    fi
    
    write_log "INFO" "$message"
}

# WARN级别日志
log_warn() {
    local message="$1"
    
    if [[ $CURRENT_LOG_LEVEL -le $LOG_LEVEL_WARN ]]; then
        echo -e "${YELLOW}[WARN]${NC} $message"
    fi
    
    write_log "WARN" "$message"
}

# ERROR级别日志
log_error() {
    local message="$1"
    
    if [[ $CURRENT_LOG_LEVEL -le $LOG_LEVEL_ERROR ]]; then
        echo -e "${RED}[ERROR]${NC} $message"
    fi
    
    write_log "ERROR" "$message" "$ERROR_LOG"
}

# 记录命令执行
log_command() {
    local command="$1"
    local description="$2"
    
    log_debug "执行命令: $command"
    
    if [[ -n "$description" ]]; then
        log_info "$description"
    fi
    
    # 执行命令并捕获输出
    local output
    local exit_code
    
    output=$(eval "$command" 2>&1)
    exit_code=$?
    
    if [[ $exit_code -eq 0 ]]; then
        log_debug "命令执行成功: $command"
        if [[ -n "$output" ]]; then
            log_debug "命令输出: $output"
        fi
    else
        log_error "命令执行失败: $command (退出码: $exit_code)"
        if [[ -n "$output" ]]; then
            log_error "命令输出: $output"
        fi
    fi
    
    return $exit_code
}

# 记录函数开始
log_function_start() {
    local function_name="$1"
    log_debug "函数开始: $function_name"
}

# 记录函数结束
log_function_end() {
    local function_name="$1"
    local exit_code="${2:-0}"
    
    if [[ $exit_code -eq 0 ]]; then
        log_debug "函数完成: $function_name"
    else
        log_error "函数失败: $function_name (退出码: $exit_code)"
    fi
}

# 记录安装步骤
log_install_step() {
    local step_name="$1"
    local step_number="$2"
    local total_steps="$3"
    
    if [[ -n "$step_number" ]] && [[ -n "$total_steps" ]]; then
        log_info "[$step_number/$total_steps] $step_name"
    else
        log_info "安装步骤: $step_name"
    fi
}

# 记录应用状态
log_app_status() {
    local app_name="$1"
    local status="$2"
    local additional_info="$3"
    
    case "$status" in
        "starting")
            log_info "$app_name 正在启动..."
            ;;
        "running")
            log_info "$app_name 运行正常"
            if [[ -n "$additional_info" ]]; then
                log_info "$additional_info"
            fi
            ;;
        "stopped")
            log_warn "$app_name 已停止"
            ;;
        "failed")
            log_error "$app_name 启动失败"
            if [[ -n "$additional_info" ]]; then
                log_error "$additional_info"
            fi
            ;;
        *)
            log_info "$app_name 状态: $status"
            ;;
    esac
}

# 设置日志级别
set_log_level() {
    local level="$1"
    
    case "${level,,}" in
        "debug")
            CURRENT_LOG_LEVEL=$LOG_LEVEL_DEBUG
            ;;
        "info")
            CURRENT_LOG_LEVEL=$LOG_LEVEL_INFO
            ;;
        "warn")
            CURRENT_LOG_LEVEL=$LOG_LEVEL_WARN
            ;;
        "error")
            CURRENT_LOG_LEVEL=$LOG_LEVEL_ERROR
            ;;
        *)
            log_error "无效的日志级别: $level"
            return 1
            ;;
    esac
    
    log_info "日志级别设置为: $level"
}

# 清理旧日志
cleanup_logs() {
    local days="${1:-7}"  # 默认保留7天
    
    log_info "清理 $days 天前的日志文件..."
    
    find "$LOG_PATH" -name "*.log" -type f -mtime +$days -delete 2>/dev/null || {
        log_warn "清理日志文件时出现问题"
    }
    
    log_info "日志清理完成"
}

# 归档日志
archive_logs() {
    local archive_name="pttools_logs_$(date +%Y%m%d_%H%M%S).tar.gz"
    local archive_path="$LOG_PATH/$archive_name"
    
    log_info "归档日志文件到: $archive_path"
    
    if tar -czf "$archive_path" -C "$LOG_PATH" --exclude="*.tar.gz" . 2>/dev/null; then
        log_info "日志归档成功"
        
        # 清理原日志文件（保留归档）
        find "$LOG_PATH" -name "*.log" -type f -delete 2>/dev/null
        
        # 重新初始化日志
        init_logging
    else
        log_error "日志归档失败"
        return 1
    fi
}

# 显示日志统计
show_log_stats() {
    echo -e "${CYAN}日志统计信息:${NC}"
    
    if [[ -f "$LOG_FILE" ]]; then
        local total_lines=$(wc -l < "$LOG_FILE" 2>/dev/null || echo "0")
        local info_count=$(grep -c "\[INFO\]" "$LOG_FILE" 2>/dev/null || echo "0")
        local warn_count=$(grep -c "\[WARN\]" "$LOG_FILE" 2>/dev/null || echo "0")
        local error_count=$(grep -c "\[ERROR\]" "$LOG_FILE" 2>/dev/null || echo "0")
        local file_size=$(du -h "$LOG_FILE" 2>/dev/null | cut -f1 || echo "0")
        
        echo "  总行数: $total_lines"
        echo "  INFO: $info_count"
        echo "  WARN: $warn_count"
        echo "  ERROR: $error_count"
        echo "  文件大小: $file_size"
    else
        echo "  日志文件不存在"
    fi
}

# 查看最近的日志
tail_log() {
    local lines="${1:-20}"
    
    if [[ -f "$LOG_FILE" ]]; then
        echo -e "${CYAN}最近 $lines 行日志:${NC}"
        tail -n "$lines" "$LOG_FILE" | while read -r line; do
            if [[ "$line" == *"[ERROR]"* ]]; then
                echo -e "${RED}$line${NC}"
            elif [[ "$line" == *"[WARN]"* ]]; then
                echo -e "${YELLOW}$line${NC}"
            elif [[ "$line" == *"[INFO]"* ]]; then
                echo -e "${GREEN}$line${NC}"
            else
                echo "$line"
            fi
        done
    else
        echo -e "${RED}日志文件不存在${NC}"
    fi
}

# 搜索日志
search_log() {
    local keyword="$1"
    local lines="${2:-10}"
    
    if [[ -z "$keyword" ]]; then
        echo -e "${RED}请提供搜索关键词${NC}"
        return 1
    fi
    
    if [[ -f "$LOG_FILE" ]]; then
        echo -e "${CYAN}搜索关键词 '$keyword' 的最近 $lines 条结果:${NC}"
        grep -i "$keyword" "$LOG_FILE" | tail -n "$lines"
    else
        echo -e "${RED}日志文件不存在${NC}"
    fi
}
