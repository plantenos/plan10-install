#!@BINDIR@/bash
# 
# This file is part of Plan10. It is subject to the license terms in
# the LICENSE file found in the top-level directory of this
# distribution.
# This file may not be copied, modified, propagated, or distributed
# except according to the terms contained in the LICENSE file.

## 		Select, check editor

choose_editor(){
	
	local editor 
	local -a list
		
	list=( "nano" "mcedit" "vi" )
	dg_action editor menu "Editor" "\nSelect your editor." ${list[@]}
	if (( $? )); then
		return 0
	fi
	sed -i "s,EDITOR=.*$,EDITOR=\"$editor\",g" /etc/plan10/install.conf
		
	unset editor list 
}

## 		Select config directory

choose_config(){
	
	local -a list list_final
	local template
	
	local msg="\n
Select the environment to install.\n
The minimum space required for the ${DG_COLOR_BOLD}/ (root)${DG_COLOR_RESET} partition is specified between parenthesis."
	
	list=( $(ls -1U $GENERAL_DIR|sort) )
	
	for i in ${list[@]}; do
		i=${i%%/*}
		list_final+=( $i )
		if [[ "${i}" = "minimal" ]];then
			list_final+=( "(${MINIMAL_SPACE}MiB)" )
		elif [[ "${i}" = @("jwm"|"openbox") ]];then
			list_final+=( "(${JWM_OPEN_SPACE}MiB)" )
		elif [[ "${i}" = @("xfce4"|"plasma") ]];then
			list_final+=( "(${XFCE_PLASMA_SPACE}MiB)" )
		else 
			list_final+=( "(UnknownMiB)" )
		fi
	done
	DG_ITEMS_OPTS=""
	dg_action template menu "Templates" "$msg" ${list_final[@]}
	if (( $? )); then
		return 0
	fi
	DG_ITEMS_OPTS="--no-items"
	sed -i "s,CONFIG_DIR=.*$,CONFIG_DIR=\"$template\",g" /etc/plan10/install.conf
	
	unset list template msg list_final
}


##		Choose cache directory for pacman

choose_cache(){
	
	local cache_dir
	dg_action cache_dir input "Cache Directory" "$dgm_choose_cache_directory" "$CACHE_DIR"
	if (( $? ));then
		return 0
	fi
	while [[ ! -d "$cache_dir" ]]; do
		dg_action cache_dir input "Cache Directory" "$dgm_choose_cache_directory_fail" "$CACHE_DIR"
		if (( $? ));then
			return 0
		fi
	done
		
	sed -i "s,CACHE_DIR=.*$,CACHE_DIR=\"$cache_dir\",g" /etc/plan10/install.conf
	
	unset _cache_dir
}

##		Select firmware interface

choose_firmware(){

	local -a list
	local interface

	## Make the menu
	
	list=("BIOS" "UEFI")
	
	dg_action interface menu "Firmware" "$dgm_choose_firmware" ${list[@]}

	if (( $? ));then
		return 0
	fi

	## If UEFI was chosen do some compatibility checks
	if [[ $interface == "UEFI" ]]; then
		if (( $AUTO_PREP )) || (( $MANUAL_PREP ));then
			## Check for partioning table
			if [[ $PTABLE != "gpt" ]]; then
				dg_info "Firmware" "$dgm_choose_firmware_warm_gpt"
			fi
			## Check if the ESP even exists
			if [[ ! $ESP ]]; then
				## Offer to exit out
				dg_yesno "Firmware" "$dgm_choose_firmware_no_efi"
				if (( ! $? )); then
					die "" "clean_install"
				fi
			fi
		fi
	fi

	## Set the global variable FIRMWARE to the chosen value
	sed -i "s,FIRMWARE=.*$,FIRMWARE=\"$interface\",g" /etc/plan10/install.conf

	unset interface list
}

## 		Select root directory

choose_rootdir(){	
	
	local directory 
	
	dg_action directory input "Root Directory" "$dgm_choose_root_directory" "$NEWROOT"
	
	until [[ -d "$directory" ]]; do
		dg_action directory input "Root Directory" "\nPath $directory is not a directory, please retry" "$NEWROOT"
		if (( $? ));then
			return 0
		fi
	done
	
	NEWROOT="${directory}"
	sed -i "s,NEWROOT=.*$,NEWROOT=\"$directory\",g" /etc/plan10/install.conf
		
	unset directory
}

choose_rankmirrors(){
	
	local res e=0 error="/tmp/plan10-install-curl-error" gauge="/tmp/plan10-install-curl-gauge" rank="/tmp/plan10-install-rank" 
	local -a list
	
	echo 0 > "${error}"
	[[ -f "${gauge}" ]] && rm -f "${gauge}"
	( \
		if ! curl "https://www.archlinux.org/mirrorlist/?country=all&protocol=http&ip_version=4" -o /etc/pacman.d/mirrorlist.new 1>&"${gauge}"; then
			echo 1 > "${error}"
		fi
		rm -f "${gauge}"
	) &
	sleep 01
	while [[ -f "${gauge}" ]];do
		e=$(<"${error}")
		if (( $e )); then
			die "Unable to get mirrors list" "clean_install"
		fi
		cat "${gauge}" | tr '\r' '\n' | tail -n1 | awk '{print $1}'|dialog $DG_BACKTITLE $DG_OPTS --title " Rankmirrors " --no-kill --gauge "\nDownloading a fresh list of mirrors..." 0 0
		sleep 1
	done
	echo 100 |dialog $DG_BACKTITLE $DG_OPTS --title "Rankmirrors" --no-kill --gauge "\nDownloading a fresh list of mirrors..." 0 0
	rm -f "${error}"
	list=$(grep "^## [A-Z]" /etc/pacman.d/mirrorlist.new | sed -e '1,2d' -e 's:^## ::' -e 's: :_:g')
	dg_action country menu "Rankmirrors" "\nPlease select your country." ${list[@]}
	if (( $? ));then
		sed -i "s,RANKMIRRORS=.*$,RANKMIRRORS=\"no\",g" /etc/plan10/install.conf
		return 0
	fi
	country=$(echo "${country}"|sed 's:_: :g')
	awk '/^## '"${country}"'$/ {f=1} f==0 {next} /^$/ {exit} {print substr($0, 2)}' \
	/etc/pacman.d/mirrorlist.new | grep -v '#' > /etc/pacman.d/mirrorlist.rank
	touch "${rank}"
	( \
		rankmirrors -v -n 10 /etc/pacman.d/mirrorlist.rank > /etc/pacman.d/mirrorlist
		rm -f "${rank}"
	) &
	while [[ -f "${rank}" ]];do 
		res=$(cat /etc/pacman.d/mirrorlist|tail -n1|grep "http"|awk '{print $2}')
		dialog $DG_BACKTITLE $DG_OPTS --title " Rankmirrors " --infobox "\nTrying server\n\n$res\n" 0 0 
		sleep 1
	done
	rm -f /etc/pacman.d/mirrorlist.rank
	dg_info "Rankmirros" "\nServer was classified is this decreasing speed order:\n\n$(cat /etc/pacman.d/mirrorlist|grep -v "#")"
	sed -i "s,RANKMIRRORS=.*$,RANKMIRRORS=\"yes\",g" /etc/plan10/install.conf
		
	unset res e error gauge rank
}
	
choose_bootloader(){
	
	local boot
	local -a list

	list=("GRUB" "Syslinux")

	# Make different lists for UEFI/BIOS
	if [[ $FIRMWARE == "UEFI" ]]; then
		list+=( "EFISTUB" )
	fi
	dg_action boot menu "Select Bootloader" "\nChoose your bootloader." ${list[@]}
	if (( $? )); then
		return 0
	fi
	sed -i "s,BOOTLOADER=.*$,BOOTLOADER=\"${boot}\",g" /etc/plan10/install.conf
	
	unset list boot

}
