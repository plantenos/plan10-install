#!@BINDIR@/bash
# Copyright (c) 2019 Plan 10 <plantenos@protonmail.com>
# All rights reserved.
# 
# This file is part of Plan 10. It is subject to the license terms in
# the LICENSE file found in the top-level directory of this
# distribution.
#
# This file may not be copied, modified, propagated, or distributed
# except according to the terms contained in the LICENSE file.

LIBRARY=${LIBRARY:-'/usr/lib/plan10'}
sourcing(){
	
	local list
	
	for list in ${LIBRARY}/install/*; do
		source "${list}"
	done
	
	unset list
}
sourcing

## 		Some global variables needed

HOME_PATH="/var/lib/plan10/plan10-install"
GENERAL_DIR="$HOME_PATH/config"
SOURCES_FUNC="/tmp/plan10-install-tmp"
LOCALTIME="/usr/share/zoneinfo/"
CONFIG="/etc/plan10/install.conf"
QUICK=0
COUNTRY=""
AUTO_PREP=0
MANUAL_PREP=0
MINIMAL_SPACE="2000"
JWM_OPEN_SPACE="4000"
XFCE_PLASMA_SPACE="5000"

if [[ -d /sys/firmware/efi/efivars ]]; then
	modprobe -q efivarfs >/dev/null 2>&1
	FIRMWARE="UEFI"
	grep -q /sys/firmware/efi/efivars /proc/mounts || mount -t efivarfs efivarfs /sys/firmware/efi/efivars
else
	FIRMWARE="BIOS"
fi
# append by default install.conf with the autodetection
# because user can change it if he not agreed
sed -i "s,FIRMWARE=.*$,FIRMWARE=\"$FIRMWARE\",g" /etc/plan10/install.conf

## 		Main menu

main_menu(){
	
	local step=0
	
	while : ; do
		(( step < 8 )) && (( step++ ))
		tput civis
		source "${CONFIG}"
		dialog $DG_BACKTITLE $DG_CANCELABEL $DG_EXTRA_OPTS $DG_OPTS --extra-button --extra-label " Install " --ok-label "Select" --title " Main Menu " --default-item ${step} --menu "$dgm_main_menu" 0 0 0 \
			1 "Path to the mounted disk for installation ${DG_COLOR_VALUES}[$NEWROOT]${DG_COLOR_RESET}" \
			2 "Change the detected installation method ${DG_COLOR_VALUES}[$FIRMWARE]${DG_COLOR_RESET}" \
			3 "Choose a Desktop environment ${DG_COLOR_VALUES}[$CONFIG_DIR]${DG_COLOR_RESET}" \
			4 "Configure the environment (optional)" \
			5 "Choose a bootloader ${DG_COLOR_VALUES}[$BOOTLOADER]${DG_COLOR_RESET}" \
			6 "Disk(s) preparation (optional)" \
			7 "Activate mirror ranking by speed and connection ${DG_COLOR_VALUES}[$RANKMIRRORS]${DG_COLOR_RESET}" \
			8 "Advanced options (optional)" \
			2>"$DG_ANS"
			
		# Install is pressed
		if [[ "$?" == 3 ]];then
			if ! install_system; then
				step=0
				continue
			fi
		fi
		
		read -r step < "$DG_ANS"
	
		case $step in
			1) choose_rootdir ;;
			2) choose_firmware ;;
			3) choose_config ;;
			4) template_menu ;;
			5) choose_bootloader ;;
			6) part_menu ;;
			7) choose_rankmirrors ;; 
			8) ! expert_menu || step=0 ;;
		#	7) QUICK=1 ;; #install_system;;
			*) clean_install ;;
		esac
		
	done
	
	unset step table
}

part_menu() {
	
	local step=0
	
	while : ;do
		(( step < 2 )) && (( step++ ))
		tput civis
		source "${CONFIG}"
		dialog $DG_BACKTITLE --cancel-label " Return " $DG_OPTS --ok-label "Select" --title " Partition Menu " --default-item ${step} --menu "$dgm_partition_menu" 0 0 0 \
			1 "Assisted preparation ${DG_COLOR_ERROR}(erases the whole disk)${DG_COLOR_RESET}" \
			2 "Partition by hand and choose the partitions to use" \
			2>"$DG_ANS"
		read -r step < "$DG_ANS"
		case $step in
			1)	part_auto
				;;
			2)	part_menu_manual 
				;;
			*)	break ;;
		esac
	done
	
	unset step table
}

part_menu_manual() {

	local step=0
	
	while : ;do
		(( step < 3 )) && (( step++ ))
		tput civis
		source "${CONFIG}"
		dialog $DG_BACKTITLE --cancel-label " Return " $DG_OPTS --ok-label "Select" --title " Partition Manual Menu " --default-item ${step} --menu "" 0 0 0 \
			1 "Parts a disks" \
			2 "Format a partitions" \
			3 "Mount a partitions" \
			2>"$DG_ANS"
		read -r step < "$DG_ANS"
		
		case $step in
			1)	part_manual || return 1 ;;
			2)	part_format_manual || return 1 ;;
			3)	part_mount_manual || return 1 ;;
			*)	break ;;
		esac
	done
	
	MANUAL_PREP=1 
	
	unset step table
}

expert_menu(){
	
	local fail=0 step=0
	
	while : ; do
		(( step < 4 )) && (( step++ ))
		tput civis
		source "${CONFIG}"
		dialog $DG_BACKTITLE --cancel-label " Return " $DG_OPTS --ok-label "Select" --title " Expert Menu " --default-item ${step}  --menu "$dgm_expert_menu" 0 0 0 \
			1 "Define cache directory for pacman ${DG_COLOR_VALUES}[$CACHE_DIR]${DG_COLOR_RESET}" \
			2 "Run the Customize Menu" \
			3 "Launch a shell on ${DG_COLOR_VALUES}[$NEWROOT]${DG_COLOR_RESET} root directory" \
			4 "Browse ${DG_COLOR_VALUES}[$NEWROOT]${DG_COLOR_RESET} root directory with Midnight Commander" \
			2>"$DG_ANS"

		read -r step < "$DG_ANS"
		if [[ $step =~ (2|3|4) ]]; then
			check_mountpoint "$NEWROOT"
			if (( $? )); then
				dg_info "Expert Menu" "$dgm_invalid_newroot"
				fail=1
				(( step-- ))
				continue
			fi
			if [[ ! -x "${NEWROOT}"/usr/bin/bash ]]; then
				dg_info "Expert Menu" "\nThe base system ${DG_COLOR_WARN}must${DG_COLOR_RESET} be installed first"
				fail=1
				(( step-- ))
				continue
			fi
		fi
		case $step in
			1)	choose_cache ;;
			2)	customize_newroot ;;
			3)	! call_shell || { fail=1 ; break ; } ;;
			4)	! mc_newroot || { fail=1 ; break ; } ;;
			*)	fail=0 ; break ;;
		esac
	done
	
	unset step table
	
	(( fail ))
}

template_menu(){
	
	local step=0
	
	while : ;do
		(( step < 4 )) && (( step++ ))
		tput civis
		source "${CONFIG}"
		dialog $DG_BACKTITLE --cancel-label " Return " $DG_OPTS --ok-label "Select" --title " Template Menu " --default-item ${step}  --menu "$dgm_template_menu" 0 0 0 \
			1 "Select editor to use ${DG_COLOR_VALUES}[$EDITOR]${DG_COLOR_RESET}" \
			2 "Pacman.conf file used by the script" \
			3 "Packages that will be installed (AUR including)" \
			4 "Automatic configuration script" \
			2>"$DG_ANS"
		
		read -r step < "$DG_ANS"
		case $step in
			1)	choose_editor ;;
			2)	edit_pacman ;;
			3)	edit_pkg_list ;;
			4)	edit_customize_chroot ;;
			*)	break ;;
		esac
	done
	
	unset step table
}

customizeChroot_menu(){
	
	local step=0
	
	while : ;do
		(( step < 7 )) && (( step++ ))
		tput civis
		source "${CONFIG}"
		dialog $DG_BACKTITLE $DG_EXTRA_OPTS $DG_OPTS --cancel-label " Return " --extra-button --extra-label " Apply " --ok-label "Select" --title " Customize Menu " --default-item ${step}  --menu "$dgm_customize_menu" 0 0 0 \
			1 "Define your Hostname ${DG_COLOR_VALUES}[$HOSTNAME]${DG_COLOR_RESET}" \
			2 "Define your Locale ${DG_COLOR_VALUES}[$LOCALE]${DG_COLOR_RESET}" \
			3 "Define your Localtime ${DG_COLOR_VALUES}[$ZONE/$SUBZONE]${DG_COLOR_RESET}" \
			4 "Define your new User ${DG_COLOR_VALUES}[$NEWUSER]${DG_COLOR_RESET}" \
			5 "Define your Keymap console keyboard layout ${DG_COLOR_VALUES}[$KEYMAP]${DG_COLOR_RESET}" \
			6 "Define your Xkeymap Desktop keyboard layout ${DG_COLOR_VALUES}[$XKEYMAP]${DG_COLOR_RESET}" \
			7 "Advanced options" \
			2>"$DG_ANS"
		
		if [[ "$?" == 3 ]];then
			#dg_info "$dgm_default_title" "You will install"
			break
		fi
				
		read -r step < "$DG_ANS"
			
		case $step in
			1)	define_hostname ;;
			2)	define_locale ;; 
			3)	define_localtime ;;
			4)	define_user || die "unable to define a newuser" "clean_install" ;;
			5)	define_keymap ;;
			6)	define_xkeymap ;;
			7)	customizeChroot_expert_menu ;;
			*)	return 1 ;;
		esac
	done
	
	unset step table
}

customizeChroot_expert_menu() {
	
	local step=0
	
	while : ;do
		(( step < 2 )) && (( step++ ))
		tput civis
		source "${CONFIG}"
		dialog $DG_BACKTITLE --cancel-label " Back " $DG_OPTS --ok-label "Select" --title " Customize Expert Menu " --default-item ${step}  --menu "$dgm_customize_expert_menu" 0 0 0 \
			1 "Edit the ${DG_COLOR_BOLD}/etc/66/boot.conf${DG_COLOR_RESET} file" \
			2 "Delete a custo_once file(s)" \
			2>"$DG_ANS"
			
		read -r step < "$DG_ANS"
		case $step in
			1)	edit_conf ;;
			2)	clean_once_file "rm -f" "${SOURCES_FUNC}" ;;
			*)	return 1 ;;
		esac
	done
	
	unset step table
}

set_keymap() {
	if [[ $TERM == 'linux' ]]; then
		define_keymap || die "unable to set your keymap layout" "clean_install"
		source "${CONFIG}"
		loadkeys "$KEYMAP" 
	else
		define_xkeymap || die "unable to set your keymap layout" "clean_install"
		source "${CONFIG}"
		setxkbmap "$XKEYMAP" 
	fi
}

check_network() {
	dg_info "Network Connect" "\nVerifying network connection\n" 1
	if ! ping -q -c 3 www.archlinux.org &>/dev/null; then
		dg_info "Network Connect" "$dgm_network_fail"
		die "" "clean_install"
	fi
}

#copy_airootfs(){
#	out_action "Copy files from airootfs"
#	rsync -a --info=progress2 /run/archiso/sfs/airootfs/ "${NEWROOT}"/ || die "Unable to copy airootfs on ${NEWROOT}" "clean_install"
#	out_action "Remove Oblive user"
#	userdel -R "${NEWROOT}" -r oblive || die "Unable to delete oblive user" "clean_install"
#	out_action "Copy kernel"
#	cp /run/archiso/bootmnt/arch/boot/x86_64/vmlinuz "${NEWROOT}"/boot/vmlinuz-linux || die "Unable to copy kernel on ${NEWROOT}" "clean_install"
#	out_action "Remove mkinitcpio-archiso.conf"
#	rm -f "${NEWROOT}"/etc/mkinitcpio-archiso.conf
#}

start_from(){
	
#	if (( "${QUICK}" ));then
#		if [[ -d /run/archiso/sfs/airootfs/ ]];then
#			copy_airootfs
#			mount_umount "$NEWROOT" "mount"
#			mount_one  "${CACHE_DIR}" "${CACHE_DIR}" "$NEWROOT/var/cache/pacman/pkg" -o bind  
#			check_gpg "$GPG_DIR"
#			sync_data
#			install_package
#			out_action "Build initramfs"
#			chroot "${NEWROOT}" mkinitcpio -p linux || die "Unable to build initramfs on ${NEWROOT}" "clean_install"
#		else
#			out_notvalid "You must start from the ISO to use this mode" "clean_install"
#			return 1
#		fi
#	else
		create_dir
		mount_umount "$NEWROOT" "mount"
		mount_one "${CACHE_DIR}" "${CACHE_DIR}" "$NEWROOT/var/cache/pacman/pkg" -o bind
		copy_file
		check_gpg "$GPG_DIR"
		sync_data
		install_package
		copy_rootfs
#	fi
}
		
##		Start the installation

install_system(){
	
	check_mountpoint "$NEWROOT"
	if (( $? )); then
		dg_info "$dgm_default_title" "$dgm_invalid_newroot"
		return 1
	fi
	
#	if ! start_from; then
#		QUICK=0
#		return 1
#	fi
	start_from
	generate_fstab "$NEWROOT"
	config_gpg
	config_mirrorlist
	define_root 1
	config_bootloader
	config_virtualbox
	if ! customize_newroot;then
		return 1
	fi
#	if (( "${QUICK}" ));then
#		out_action "Do you want to update the fresh installation?"
#		reply_answer_fzf
#		if (( ! $? )); then
#			update_newroot
#		fi
#	fi
	rm -rf "${SOURCES_FUNC}" || out_notvalid "Warning : Unable to remove ${SOURCES_FUNC}"
	dg_info "Install System" "System was installed ${DG_COLOR_BOLD}successfully${DG_COLOR_RESET}\n. You can now reboot." 2
}

customize_newroot(){
	
	# make sure the necessary is present before enter on chroot
	check_mountpoint "$NEWROOT"
	if (( $? )); then
		dg_info "$dgm_default_title" "$dgm_invalid_newroot"
		return 1
	fi
		
	create_dir
	mount_umount "$NEWROOT" "mount"
	mount_one "${CACHE_DIR}" "${CACHE_DIR}" "$NEWROOT/var/cache/pacman/pkg" -o bind
	copy_rootfs
	define_root 
	customizeChroot_menu
	if (( $? )); then
		return 1
	else
		config_custofile
		copy_file
		out_action "Chroot on ${NEWROOT}"	
		chroot "$NEWROOT" "$SOURCES_FUNC"/customizeChroot || die " Failed to enter on ${NEWROOT} or Failed to execute functions customizeChroot" "clean_install"
	fi
}
