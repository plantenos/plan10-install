#!@BINDIR@/bash
# 
# This file is part of Plan10. It is subject to the license terms in
# the LICENSE file found in the top-level directory of this
# distribution.
# This file may not be copied, modified, propagated, or distributed
# except according to the terms contained in the LICENSE file.


export DIALOGRC="${SCHEMECOLOR}"
DG_BACKTITLE="--backtitle plan10-install"
DG_CANCELABEL="--cancel-label Exit"
DG_ANS="/tmp/plan10-install.ans"
DG_OPTS="--cr-wrap --no-mouse --colors"
DG_ITEM=0
DG_ITEMS_OPTS="--no-items"
DG_EXTRA_OPTS=""

DG_COLOR_BOLD="\Zb"
DG_COLOR_RESET="\Zn"
DG_COLOR_BLACK="$DG_COLOR_BOLD\Z0"
DG_COLOR_RED="$DG_COLOR_BOLD\Z1"
DG_COLOR_GREEN="$DG_COLOR_BOLD\Z2"
DG_COLOR_YELLOW="$DG_COLOR_BOLD\Z3"
DG_COLOR_BLUE="$DG_COLOR_BOLD\Z4"
DG_COLOR_MAGENTA="$DG_COLOR_BOLD\Z5"
DG_COLOR_CYAN="$DG_COLOR_BOLD\Z6"
DG_COLOR_WHITE="$DG_COLOR_BOLD\Z7"

# set default color for default option
DG_COLOR_VALUES="${DG_COLOR_CYAN}"
DG_COLOR_WARN="${DG_COLOR_YELLOW}"
DG_COLOR_ERROR="${DG_COLOR_RED}"

[[ $LINES ]] || LINES=$(tput lines)


dg_run() {
	var="${1}"
	shift 1
	local opts=( "${@}" )
	dialog $DG_BACKTITLE $DG_EXTRA_OPTS $DG_OPTS $DG_ITEMS_OPTS "${opts[@]}" 2>"$DG_ANS" || return 1
	# if answer file isn't empty read from it into $var
	[[ -s "$DG_ANS" ]] && printf -v "$var" "%s" "$(<"$DG_ANS")"
	unset opts
}

dg_info() {
	local title="$1" msg="$2" sleep="$3"
	tput civis
	if (( $3 )); then
		dialog $DG_BACKTITLE $DG_OPTS --sleep "$3" --title " $title " --infobox "$msg\n" 0 0
	else
		dialog $DG_BACKTITLE $DG_OPTS --title " $title " --msgbox "$msg\n" 0 0
	fi
	unset title msg sleep
}

dg_action()
{
	local var="$1"   # assign output from dialog to var
	local dlg_t="$2" # dialog type (menu, check, input)
	local title="$3" # dialog title
	local msg="$4"   # dialog message
	local n=0        # number of items to display for menu and check dialogs

	shift 4  # shift off args assigned above

	# adjust n when passed a large list
	local l=$((LINES - 20))
	(( ($# / 2) > l )) && n=$l

	tput civis
	case "$dlg_t" in
		menu) dg_run "${var}" --title " $title " --menu "$msg" 0 0 $n "$@"  || return 1 ;;
		check) dg_run "${var}" --title " $title " --checklist "$msg" 0 0 $n "$@" || return 1 ;;
		input)
			tput cnorm
			local def="$1" # assign default value for input
			shift
			if [[ $1 == 'limit' ]]; then
				dg_run "${var}" --max-input 63 --title " $title " --inputbox "$msg" 0 0 "$def" || return 1
			else
				dg_run "${var}" --title " $title " --inputbox "$msg" 0 0 "$def" || return 1
			fi
			;;
	esac
	unset var dlg_t title msg n def
}

dg_yesno()
{
	local title="$1" msg="$2" yes='Yes' no='No'
	(( $# >= 3 )) && yes="$3"
	(( $# >= 4 )) && no="$4"
	tput civis
	if (( $# == 5 )); then
		dialog $DG_BACKTITLE $DG_OPTS --defaultno --title " $title " --yes-label "$yes" --no-label "$no" --yesno "$msg\n" 0 0 || return 1
	else
		dialog $DG_BACKTITLE $DG_OPTS --title " $title " --yes-label "$yes" --no-label "$no" --yesno "$msg\n" 0 0 || return 1
	fi
	unset title msg yes no
}

dg_build_menu_list(){

	local -n array="${1}"
	local n=0 i
	for i in ${array[@]}; do
		array[$n]="$n $i"
		(( n++ ))
	done
	
	unset i n 
}
