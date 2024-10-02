#!/usr/bin/env bash
###############################################################################
# Configuration
###############################################################################
MODE=$1
DEV=$2

if [ "$DEBUG" == "" ]; then
	DEBUG="false"
fi

if [ "$MBIM_INTERFACE" == "" ]; then
	MBIM_INTERFACE="/dev/cdc-wdm0"
fi

###############################################################################
# Global Variables
###############################################################################
previous_state="none"
state="none"
skip_line=0
ipv4_addresses=()
ipv4_gateway=""
ipv4_dns=()
ipv4_mtu=""
ipv6_addresses=()
ipv6_gateway=""
ipv6_dns=()
ipv6_mtu=""

export previous_state state skip_line \
	ipv4_addresses ipv4_gateway ipv4_dns ipv4_mtu \
	ipv6_addresses ipv6_gateway ipv6_dns ipv6_mtu

###############################################################################
# Function
###############################################################################

function print_debug {
	if [ "$DEBUG" != "false" ]; then
		echo "[State: $state] $1" >&2
	fi
}

function print_full_configuration {
	if [[ "${#ipv4_addresses[@]}" > 0 ]]; then
		printf "IPv4: "
		printf '%s, ' "${ipv4_addresses[@]}"
		printf "\n"

		printf "GW: $ipv4_gateway\n"

		printf "DNS: "
		printf '%s, ' "${ipv4_dns[@]}"
		printf "\n"

		printf "MTU: $ipv4_mtu\n"
	fi

	if [[ "${#ipv6_addresses[@]}" > 0 ]]; then
		echo
		printf "IPv6: "
		printf '%s, ' "${ipv6_addresses[@]}"
		printf "\n"

		printf "GW: $ipv6_gateway\n"

		printf "DNS: "
		printf '%s, ' "${ipv6_dns[@]}"
		printf "\n"

		printf "MTU: $ipv6_mtu\n"
	fi
}

function next_state {
	previous_state="$state"
	state="$1"
}

function parse_ip {
	#      IP [0]: '10.134.203.177/30'
	local line_re="IP \[([0-9]+)\]: '(.+)'"
	local input=$1
	if [[ $input =~ $line_re ]]; then
		local ip_cnt=${BASH_REMATCH[1]}
		local ip=${BASH_REMATCH[2]}
	fi
	echo "$ip"
}

function parse_dns {
	#      IP [0]: '10.134.203.177/30'
	local line_re="DNS \[([0-9]+)\]: '(.+)'"
	local input=$1
	if [[ $input =~ $line_re ]]; then
		local dns_cnt=${BASH_REMATCH[1]}
		local dns=${BASH_REMATCH[2]}
	fi
	echo "$dns"
}

function parse_gateway {
	#    Gateway: '10.134.203.178'
	local line_re="Gateway: '(.+)'"
	local input=$1
	if [[ $input =~ $line_re ]]; then
		local gw=${BASH_REMATCH[1]}
	fi
	echo "$gw"
}

function parse_mtu {
	#        MTU: '1500'
	local line_re="MTU: '([0-9]+)'"
	local input=$1
	if [[ $input =~ $line_re ]]; then
		local mtu=${BASH_REMATCH[1]}
	fi
	echo "$mtu"
}

function parse_input_state_machine {
	state="start"
	while true; do
		if [[ "$skip_line" == 0 ]]; then
			read line || break # TODO: Clean up
		else
			skip_line=0
		fi
		case "$state" in
			"start")
				read line || break # first line is empty, read a new one #TODO: This is not very clean...
				case "$line" in
					*"configuration available: 'none'"*)
						# Skip none state
						# TODO: This is a workaround of the original parser's shortcomming
						continue
						;;
					*"IPv4 configuration available"*)
						next_state "ipv4_ip"
						continue
						;;
					*"IPv6 configuration available"*)
						next_state "ipv6_ip"
						continue
						;;
					*)
						next_state "exit"
						continue
						;;
				esac
				;;
			"error")
				echo "Error in pattern matchin of state $previous_state. Exiting." >&2
				exit 2
				;;
			"exit")
				break
				;;
			"ipv4_ip")
				ipv4=$(parse_ip "$line")
				if [ -z "$ipv4" ]; then
					if [[ "${#ipv4_addresses[@]}" < 1 ]]; then
						next_state "error"
						continue
					else
						next_state "ipv4_gateway"
						skip_line=1
						continue
					fi
				fi
				print_debug "$ipv4"
				ipv4_addresses+=("$ipv4")
				;;
			"ipv4_gateway")
				gw=$(parse_gateway "$line")
				if [ -z "$gw" ]; then
					next_state "error"
					continue
				fi
				print_debug "$gw"
				ipv4_gateway="$gw"
				next_state "ipv4_dns"
				;;
			"ipv4_dns")
				ipv4=$(parse_dns "$line")
				if [ -z "$ipv4" ]; then
					if [[ "${#ipv4_dns[@]}" < 1 ]]; then
						next_state "error"
						continue
					else
						next_state "ipv4_mtu"
						skip_line=1
						continue
					fi
				fi
				print_debug "$ipv4"
				ipv4_dns+=("$ipv4")
				;;
			"ipv4_mtu")
				mtu=$(parse_mtu "$line")
				if [ -z "$mtu" ]; then
					next_state "error"
					continue
				fi
				print_debug "$mtu"
				ipv4_mtu="$mtu"
				next_state "start"
				;;
			"ipv6_ip")
				ipv6=$(parse_ip "$line")
				if [ -z "$ipv6" ]; then
					if [[ "${#ipv6_addresses[@]}" < 1 ]]; then
						next_state "error"
						continue
					else
						next_state "ipv6_gateway"
						skip_line=1
						continue
					fi
				fi
				print_debug "$ipv6"
				ipv6_addresses+=("$ipv6")
				;;
			"ipv6_gateway")
				gw=$(parse_gateway "$line")
				if [ -z "$gw" ]; then
					next_state "error"
					continue
				fi
				print_debug "$gw"
				ipv6_gateway="$gw"
				next_state "ipv6_dns"
				;;
			"ipv6_dns")
				ipv6=$(parse_dns "$line")
				if [ -z "$ipv6" ]; then
					if [[ "${#ipv6_dns[@]}" < 1 ]]; then
						next_state "error"
						continue
					else
						next_state "ipv6_mtu"
						skip_line=1
						continue
					fi
				fi
				print_debug "$ipv6"
				ipv6_dns+=("$ipv6")
				;;
			"ipv6_mtu")
				mtu=$(parse_mtu "$line")
				if [ -z "$mtu" ]; then
					next_state "error"
					continue
				fi
				print_debug "$mtu"
				ipv6_mtu="$mtu"
				next_state "start"
				;;
			*)
				print_debug "Invalid state (came from $previous_state). Exiting."
				exit 0
				;;
		esac
	done
}


interface_stop(){
	ip addr flush dev $DEV
	ip route flush dev $DEV

	ip -6 addr flush dev $DEV
	ip -6 route flush dev $DEV

	#TODO: Nameserver?
}

interface_start() {
	ip link set $DEV up

	if [[ "${#ipv4_addresses[@]}" > 0 ]]; then
		ip addr add ${ipv4_addresses[@]} dev $DEV broadcast + #TODO: Works for multiple addresses?
		ip link set $DEV mtu $ipv4_mtu
		ip route add default via $ipv4_gateway dev $DEV
		#TODO: nameserver ${ipv4_dns[@]}
	else
		echo "No IPv4 address, skipping v4 configuration..."
	fi

	if [[ "${#ipv6_addresses[@]}" > 0 ]]; then
		ip -6 addr add ${ipv6_addresses[@]} dev $DEV #TODO: Works for multiple addresses?
		ip -6 route add default via $ipv6_gateway dev $DEV
		ip -6 link set $DEV mtu $ipv6_mtu
		#TODO: nameserver ${ipv6_dns[@]}"
	else
		echo "No IPv6 address, skipping v6 configuration..."
	fi
}

###############################################################################
# Execution
###############################################################################
set -x
set -e
echo "NOTE: This script does not yet support nameserver configuration."

case "$MODE" in
        "start")
                mbim-network $MBIM_INTERFACE start
		sleep 1
		mbimcli -d $MBIM_INTERFACE -p --query-ip-configuration=0 | {
			parse_input_state_machine
			print_full_configuration
			interface_stop
                	interface_start
		}
                ;;
        "stop")
                mbim-network $MBIM_INTERFACE stop
                interface_stop
                ;;
        *)
                echo "USAGE: $0 start|stop INTERFACE" >&2
                echo "You can set an env variable DEBUG to gather debugging output." >&2
                exit 1
                ;;
esac
