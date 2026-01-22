#!/bin/bash

# ============================================================================
# CPU Temperature Monitor with Auto-Throttling
# ============================================================================
# This script monitors CPU core temperatures and automatically adjusts
# frequency and governor based on thermal thresholds.
# 
# Requires: cpupower, lm-sensors (or /sys/class/thermal access)
# Run with: sudo ./cpu-monitor.sh
# ============================================================================

# Configuration
DELAY=5                    # Check interval in seconds
MAX_THRESHOLD=95           # Temperature to trigger throttling (Celsius)
MIN_THRESHOLD=80           # Temperature to restore performance (Celsius)
THROTTLE_FREQ="0.2GHz"     # Frequency when throttled
PERFORMANCE_FREQ="5GHz"    # Frequency when cool (or max available)

# Intel RAPL Power Limit Configuration (in microwatts)
RAPL_PATH="/sys/class/powercap/intel-rapl/intel-rapl:0"
THROTTLE_PL1=10000000      # 20W PL1 when throttled
THROTTLE_PL2=15000000      # 35W PL2 when throttled
PERFORMANCE_PL1=200000000  # 200W PL1 when cool
PERFORMANCE_PL2=115000000  # 115W PL2 when cool

# Track power limit throttle state (will be initialized based on current state)
POWER_THROTTLED=0
MEAN_TEMP=0

# Detect if power is currently throttled based on actual values
detect_power_state() {
    if check_rapl_available; then
        local current_pl1=$(cat "${RAPL_PATH}/constraint_0_power_limit_uw" 2>/dev/null)
        # If PL1 is at or below throttle value, consider it throttled
        if [[ -n "$current_pl1" ]] && [[ $current_pl1 -le $THROTTLE_PL1 ]]; then
            POWER_THROTTLED=1
        else
            POWER_THROTTLED=0
        fi
    fi
}

# Colors for TUI
RED=$'\033[0;31m'
GREEN=$'\033[0;32m'
YELLOW=$'\033[1;33m'
BLUE=$'\033[0;34m'
CYAN=$'\033[0;36m'
NC=$'\033[0m' # No Color
BOLD=$'\033[1m'

# Cursor control sequences
CURSOR_HOME=$'\033[H'
CURSOR_HIDE=$'\033[?25l'
CURSOR_SHOW=$'\033[?25h'
CLEAR_LINE=$'\033[K'

# Track throttled state per CPU
declare -A THROTTLED

# Track previous row data for change detection
declare -A PREV_ROW_DATA

# Header line count (for cursor positioning)
HEADER_LINES=7

# Get number of CPU cores
get_cpu_count() {
    nproc
}

# Get CPU temperature for a specific core
# Tries multiple methods: hwmon, thermal zones, coretemp
get_cpu_temp() {
    local cpu=$1
    local temp=""
    
    # Method 1: Try coretemp hwmon (Intel)
    for hwmon in /sys/class/hwmon/hwmon*/; do
        if [[ -f "${hwmon}name" ]]; then
            name=$(cat "${hwmon}name" 2>/dev/null)
            if [[ "$name" == "coretemp" ]]; then
                # Core temps are usually temp2_input, temp3_input, etc.
                local temp_file="${hwmon}temp$((cpu + 2))_input"
                if [[ -f "$temp_file" ]]; then
                    temp=$(cat "$temp_file" 2>/dev/null)
                    if [[ -n "$temp" ]]; then
                        echo $((temp / 1000))
                        return
                    fi
                fi
            fi
            # Method 2: Try k10temp (AMD)
            if [[ "$name" == "k10temp" ]]; then
                local temp_file="${hwmon}temp1_input"
                if [[ -f "$temp_file" ]]; then
                    temp=$(cat "$temp_file" 2>/dev/null)
                    if [[ -n "$temp" ]]; then
                        echo $((temp / 1000))
                        return
                    fi
                fi
            fi
        fi
    done
    
    # Method 3: Try thermal zones
    for zone in /sys/class/thermal/thermal_zone*/; do
        if [[ -f "${zone}temp" ]]; then
            temp=$(cat "${zone}temp" 2>/dev/null)
            if [[ -n "$temp" ]]; then
                echo $((temp / 1000))
                return
            fi
        fi
    done
    
    # Fallback: return N/A
    echo "N/A"
}

# Get current CPU frequency in GHz
get_cpu_freq() {
    local cpu=$1
    local freq_file="/sys/devices/system/cpu/cpu${cpu}/cpufreq/scaling_cur_freq"
    
    if [[ -f "$freq_file" ]]; then
        local freq=$(cat "$freq_file" 2>/dev/null)
        if [[ -n "$freq" ]]; then
            # Convert kHz to GHz with 2 decimal places
            printf "%.2f" $(echo "scale=2; $freq / 1000000" | bc)
            return
        fi
    fi
    echo "N/A"
}

# Get max CPU frequency in GHz
get_cpu_max_freq() {
    local cpu=$1
    local freq_file="/sys/devices/system/cpu/cpu${cpu}/cpufreq/scaling_max_freq"
    
    if [[ -f "$freq_file" ]]; then
        local freq=$(cat "$freq_file" 2>/dev/null)
        if [[ -n "$freq" ]]; then
            printf "%.2f" $(echo "scale=2; $freq / 1000000" | bc)
            return
        fi
    fi
    echo "N/A"
}

# Get hardware max frequency for a CPU
get_cpu_hw_max_freq() {
    local cpu=$1
    local freq_file="/sys/devices/system/cpu/cpu${cpu}/cpufreq/cpuinfo_max_freq"
    
    if [[ -f "$freq_file" ]]; then
        local freq=$(cat "$freq_file" 2>/dev/null)
        if [[ -n "$freq" ]]; then
            echo "${freq}kHz"
            return
        fi
    fi
    echo "$PERFORMANCE_FREQ"
}

# Get current governor for a CPU
get_cpu_governor() {
    local cpu=$1
    local gov_file="/sys/devices/system/cpu/cpu${cpu}/cpufreq/scaling_governor"
    
    if [[ -f "$gov_file" ]]; then
        cat "$gov_file" 2>/dev/null
        return
    fi
    echo "N/A"
}

# Set CPU to throttled state
throttle_cpu() {
    local cpu=$1
    
    if [[ "${THROTTLED[$cpu]}" != "1" ]]; then
        cpupower -c $cpu frequency-set -u $THROTTLE_FREQ >/dev/null 2>&1
        cpupower -c $cpu frequency-set -g powersave >/dev/null 2>&1
        THROTTLED[$cpu]=1
    fi
}

# Restore CPU to performance state
restore_cpu() {
    local cpu=$1
    local max_freq=$(get_cpu_hw_max_freq $cpu)
    
    if [[ "${THROTTLED[$cpu]}" == "1" ]]; then
        cpupower -c $cpu frequency-set -u $max_freq >/dev/null 2>&1
        cpupower -c $cpu frequency-set -g performance >/dev/null 2>&1
        THROTTLED[$cpu]=0
    fi
}

# Calculate mean temperature from array of temps
calculate_mean_temp() {
    local -n temps=$1
    local sum=0
    local count=0
    
    for temp in "${temps[@]}"; do
        if [[ "$temp" != "N/A" ]]; then
            sum=$((sum + temp))
            ((count++))
        fi
    done
    
    if [[ $count -gt 0 ]]; then
        echo $((sum / count))
    else
        echo "N/A"
    fi
}

# Check if Intel RAPL is available
check_rapl_available() {
    [[ -f "${RAPL_PATH}/constraint_0_power_limit_uw" ]] && \
    [[ -f "${RAPL_PATH}/constraint_1_power_limit_uw" ]]
}

# Get current power limits
get_current_pl1() {
    if [[ -f "${RAPL_PATH}/constraint_0_power_limit_uw" ]]; then
        local pl=$(cat "${RAPL_PATH}/constraint_0_power_limit_uw" 2>/dev/null)
        if [[ -n "$pl" ]]; then
            echo $((pl / 1000000))
            return
        fi
    fi
    echo "N/A"
}

get_current_pl2() {
    if [[ -f "${RAPL_PATH}/constraint_1_power_limit_uw" ]]; then
        local pl=$(cat "${RAPL_PATH}/constraint_1_power_limit_uw" 2>/dev/null)
        if [[ -n "$pl" ]]; then
            echo $((pl / 1000000))
            return
        fi
    fi
    echo "N/A"
}

# Throttle power limits
throttle_power() {
    if [[ $POWER_THROTTLED -ne 1 ]] && check_rapl_available; then
        echo "$THROTTLE_PL1" > "${RAPL_PATH}/constraint_0_power_limit_uw" 2>/dev/null
        echo "$THROTTLE_PL2" > "${RAPL_PATH}/constraint_1_power_limit_uw" 2>/dev/null
        POWER_THROTTLED=1
    fi
}

# Restore power limits
restore_power() {
    if [[ $POWER_THROTTLED -eq 1 ]] && check_rapl_available; then
        echo "$PERFORMANCE_PL1" > "${RAPL_PATH}/constraint_0_power_limit_uw" 2>/dev/null
        echo "$PERFORMANCE_PL2" > "${RAPL_PATH}/constraint_1_power_limit_uw" 2>/dev/null
        POWER_THROTTLED=0
    fi
}

# Move cursor to specific row
move_to_row() {
    local row=$1
    printf "\033[%d;1H" "$row"
}

# Draw the TUI header (only once at start)
draw_header() {
    printf "%s" "$CURSOR_HOME"
    echo -e "${BOLD}${CYAN}============================================================${NC}${CLEAR_LINE}"
    echo -e "${BOLD}${CYAN}           CPU Temperature Monitor & Throttler             ${NC}${CLEAR_LINE}"
    echo -e "${BOLD}${CYAN}============================================================${NC}${CLEAR_LINE}"
    echo -e "${YELLOW}Config:${NC} Delay=${DELAY}s | Throttle>${MAX_THRESHOLD}C | Restore<${MIN_THRESHOLD}C${CLEAR_LINE}"
    echo -e "${CYAN}------------------------------------------------------------${NC}${CLEAR_LINE}"
    echo -e "${BOLD}| N    | GHz      | Max GHz    | T (C)  | Governor     |${NC}${CLEAR_LINE}"
    echo -e "${CYAN}------------------------------------------------------------${NC}${CLEAR_LINE}"
}

# Draw a single CPU row at specific position
draw_cpu_row() {
    local cpu=$1
    local freq=$2
    local max_freq=$3
    local temp=$4
    local governor=$5
    local row=$6
    
    # Build row data string for change detection
    local row_data="${cpu}|${freq}|${max_freq}|${temp}|${governor}|${THROTTLED[$cpu]}"
    
    # Skip if nothing changed
    if [[ "${PREV_ROW_DATA[$cpu]}" == "$row_data" ]]; then
        return
    fi
    PREV_ROW_DATA[$cpu]="$row_data"
    
    # Color temperature based on thresholds
    local temp_color="$GREEN"
    if [[ "$temp" != "N/A" ]]; then
        if [[ $temp -ge $MAX_THRESHOLD ]]; then
            temp_color="$RED"
        elif [[ $temp -ge $MIN_THRESHOLD ]]; then
            temp_color="$YELLOW"
        fi
    fi
    
    # Color governor
    local gov_color="$NC"
    if [[ "$governor" == "powersave" ]]; then
        gov_color="$YELLOW"
    elif [[ "$governor" == "performance" ]]; then
        gov_color="$GREEN"
    fi
    
    # Throttle indicator
    local throttle_indicator=""
    if [[ "${THROTTLED[$cpu]}" == "1" ]]; then
        throttle_indicator="${RED}[T]${NC}"
    fi
    
    # Format each field with padding
    local cpu_fmt=$(printf "%-4s" "$cpu")
    local freq_fmt=$(printf "%-8s" "$freq")
    local max_freq_fmt=$(printf "%-10s" "$max_freq")
    local temp_fmt=$(printf "%-6s" "$temp")
    local gov_fmt=$(printf "%-12s" "$governor")
    
    # Move to row and draw
    move_to_row "$row"
    echo -e "| ${cpu_fmt} | ${freq_fmt} | ${max_freq_fmt} | ${temp_color}${temp_fmt}${NC} | ${gov_color}${gov_fmt}${NC} | ${throttle_indicator}${CLEAR_LINE}"
}

# Draw footer with status at specific row
draw_footer() {
    local row=$1
    local throttled_count=0
    
    for key in "${!THROTTLED[@]}"; do
        if [[ "${THROTTLED[$key]}" == "1" ]]; then
            ((throttled_count++))
        fi
    done
    
    # Get current power limits
    local pl1=$(get_current_pl1)
    local pl2=$(get_current_pl2)
    
    # Power status color
    local power_status_color="$GREEN"
    local power_status="Normal"
    if [[ $POWER_THROTTLED -eq 1 ]]; then
        power_status_color="$RED"
        power_status="Throttled"
    fi
    
    # Mean temp color
    local mean_temp_color="$GREEN"
    if [[ "$MEAN_TEMP" != "N/A" ]]; then
        if [[ $MEAN_TEMP -ge $MAX_THRESHOLD ]]; then
            mean_temp_color="$RED"
        elif [[ $MEAN_TEMP -ge $MIN_THRESHOLD ]]; then
            mean_temp_color="$YELLOW"
        fi
    fi
    
    move_to_row "$row"
    echo -e "${CYAN}------------------------------------------------------------${NC}${CLEAR_LINE}"
    move_to_row "$((row + 1))"
    echo -e "${BOLD}Status:${NC} $(date '+%Y-%m-%d %H:%M:%S') | Throttled CPUs: ${throttled_count}${CLEAR_LINE}"
    move_to_row "$((row + 2))"
    echo -e "${BOLD}Mean Temp:${NC} ${mean_temp_color}${MEAN_TEMP}C${NC} | ${BOLD}Power:${NC} ${power_status_color}${power_status}${NC} (PL1: ${pl1}W, PL2: ${pl2}W)${CLEAR_LINE}"
    move_to_row "$((row + 3))"
    echo -e "${CYAN}============================================================${NC}${CLEAR_LINE}"
    move_to_row "$((row + 4))"
    echo -e "${BOLD}Legend:${NC} ${GREEN}Cool${NC} | ${YELLOW}Warm${NC} | ${RED}Hot/Throttled${NC} | ${RED}[T]${NC}=Throttled${CLEAR_LINE}"
    move_to_row "$((row + 5))"
    echo -e "Press ${BOLD}Ctrl+C${NC} to exit${CLEAR_LINE}"
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}Error: This script must be run as root (sudo)${NC}"
        echo "cpupower requires root privileges to change CPU settings"
        exit 1
    fi
}

# Check dependencies
check_dependencies() {
    if ! command -v cpupower &> /dev/null; then
        echo -e "${RED}Error: cpupower is not installed${NC}"
        echo "Install it with: sudo pacman -S cpupower (Arch) or sudo apt install linux-tools-common (Debian/Ubuntu)"
        exit 1
    fi
    
    if ! command -v bc &> /dev/null; then
        echo -e "${RED}Error: bc is not installed${NC}"
        echo "Install it with: sudo pacman -S bc (Arch) or sudo apt install bc (Debian/Ubuntu)"
        exit 1
    fi
}

# Cleanup on exit
cleanup() {
    # Show cursor again
    printf "%s" "$CURSOR_SHOW"
    
    echo -e "\n${YELLOW}Restoring all CPUs to performance mode...${NC}"
    local cpu_count=$(get_cpu_count)
    for ((cpu=0; cpu<cpu_count; cpu++)); do
        restore_cpu $cpu
    done
    
    # Restore power limits
    if check_rapl_available; then
        echo -e "${YELLOW}Restoring power limits...${NC}"
        POWER_THROTTLED=1  # Force restore
        restore_power
    fi
    
    echo -e "${GREEN}Done. Exiting.${NC}"
    exit 0
}

# Main monitoring loop
main() {
    check_root
    check_dependencies
    
    trap cleanup SIGINT SIGTERM
    
    local cpu_count=$(get_cpu_count)
    
    # Initialize throttled state
    for ((cpu=0; cpu<cpu_count; cpu++)); do
        THROTTLED[$cpu]=0
    done
    
    # Detect initial power state based on current limits
    detect_power_state
    
    # Clear screen once and hide cursor
    clear
    printf "%s" "$CURSOR_HIDE"
    
    # Draw static header once
    draw_header
    
    while true; do
        # Array to collect temperatures for mean calculation
        local -a all_temps=()
        
        # Process each CPU
        for ((cpu=0; cpu<cpu_count; cpu++)); do
            local temp=$(get_cpu_temp $cpu)
            local freq=$(get_cpu_freq $cpu)
            local max_freq=$(get_cpu_max_freq $cpu)
            local governor=$(get_cpu_governor $cpu)
            
            # Collect temperature for mean calculation
            all_temps+=("$temp")
            
            # Temperature-based throttling logic (per CPU)
            if [[ "$temp" != "N/A" ]]; then
                if [[ $temp -ge $MAX_THRESHOLD ]]; then
                    throttle_cpu $cpu
                elif [[ $temp -lt $MIN_THRESHOLD ]]; then
                    restore_cpu $cpu
                fi
            fi
            
            # Calculate row position (header + cpu index)
            local row=$((HEADER_LINES + cpu + 1))
            
            # Draw the row (only if changed)
            draw_cpu_row $cpu "$freq" "$max_freq" "$temp" "$governor" "$row"
        done
        
        # Calculate mean temperature
        MEAN_TEMP=$(calculate_mean_temp all_temps)
        
        # Power limit throttling based on mean temperature
        if [[ "$MEAN_TEMP" != "N/A" ]]; then
            if [[ $MEAN_TEMP -ge $MAX_THRESHOLD ]]; then
                throttle_power
            elif [[ $MEAN_TEMP -lt $MIN_THRESHOLD ]]; then
                restore_power
            fi
        fi
        
        # Calculate footer start row
        local footer_row=$((HEADER_LINES + cpu_count + 1))
        
        # Draw footer (always updates for timestamp)
        draw_footer "$footer_row"
        
        # Wait before next update
        sleep $DELAY
    done
}

# Run main
main "$@"
