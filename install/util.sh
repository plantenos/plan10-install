#!@BINDIR@/bash
# Copyright (c) 2019 Plan 10  <plantenos@protonmail.com>
# All rights reserved.
# 
# This file is part of Plan 10. It is subject to the license terms in
# the LICENSE file found in the top-level directory of this
# distribution.
#
# This file may not be copied, modified, propagated, or distributed
# except according to the terms contained in the LICENSE file.

## 		Clean on exit

clean_install(){
	
	tput cnorm
	out_action "Cleaning up"
	# make sure that all process are killed
	# before umounting
	out_valid "Killing process" 
	kill_process "haveged gpg-agent dirmngr"
	
	out_valid "Umount $NEWROOT"
	mount_umount "$NEWROOT" "umount"
	umount_one "${NEWROOT}${CACHE_DIR}" "${NEWROOT}${CACHE_DIR}"
	
	#if [[ $(awk -F':' '{ print $1}' /etc/passwd | grep usertmp) >/dev/null ]]; then
	#	out_valid "Removing user usertmp"
	#	user_del "usertmp" &>/dev/null
	#fi
		
	# keep the configuration variable from install.conf
	if [[ -f "$NEWROOT$SOURCES_FUNC"/install.conf ]]; then
		out_valid "Keeping the configuration from $NEWROOT$SOURCES_FUNC/install.conf"
		cp -f "$NEWROOT$SOURCES_FUNC"/install.conf /etc/plan10/install.conf
	fi
	
	if [[ -d "$NEWROOT$SOURCES_FUNC" ]]; then
		out_valid "Remove directory $SOURCES_FUNC"
		rm -r "$NEWROOT$SOURCES_FUNC"
	fi
	
	out_valid "Restore your shell options"
	shellopts_restore
	
	exit
}

check_editor(){
	if [[ -z "$EDITOR" ]]; then
		EDITOR="nano"
	fi
}


##		Copying file needed

copy_file(){
	
	local tidy_loop
	
	out_action "Check needed files in ${NEWROOT}"
	if [[  ! -e "$NEWROOT/etc/resolv.conf" ]]; then 
		cp /etc/resolv.conf "$NEWROOT/etc/resolv.conf" || die " Impossible to copy the file resolv.conf" "clean_install"
	else
		out_valid "File resolv.conf already exists"
	fi
	if [[ ! -d "$NEWROOT$SOURCES_FUNC" ]]; then
		out_action "Create $NEWROOT$SOURCES_FUNC directory"
		mkdir -p "$NEWROOT$SOURCES_FUNC" || die " Impossible to create $NEWROOT$SOURCES_FUNC directory" "clean_install"
	fi
	
	for tidy_loop in /etc/plan10/install.conf $GENERAL_DIR/$CONFIG_DIR/customizeChroot; do
		out_notvalid "Copying $tidy_loop"
		cp -f "$tidy_loop" "$NEWROOT$SOURCES_FUNC/" || die " Impossible to copy the file $tidy_loop" "clean_install"
	done
	unset tidy_loop
}

##		Copy directory rootfs in $NEWROOT

copy_rootfs(){
	
	out_action "Copying configuration files in ${NEWROOT}"
	
	cp -af "$GENERAL_DIR/$CONFIG_DIR/rootfs/"* "$NEWROOT"/ || die " Impossible to copy files" "clean_install"
}

## 		Create needed directory

create_dir(){
	out_action "Check for needed directory"
	for id in var/cache/pacman/pkg var/lib/pacman var/log dev run etc etc/pacman.d/;do
		if ! [ -d "$NEWROOT/$id" ]; then 
			out_notvalid "Create ${NEWROOT}/$id directory"
			mkdir -m 0755 -p "$NEWROOT/$id"
		else
			out_valid "${NEWROOT}/$id directory already exist"
		fi
	done
	for id in dev/{pts,shm};do
		if ! [ -d "$NEWROOT/$id" ]; then
			out_notvalid "Create ${NEWROOT}/$id directory"
			mkdir -m 0755 -p "$NEWROOT/$id"
		else
			out_valid "${NEWROOT}/$id directory already exist"
		fi
	done
	for id in sys proc;do
		if ! [ -d "$NEWROOT/$id" ]; then
			out_notvalid "Create ${NEWROOT}/$id directory"
			mkdir -m 0555 -p "$NEWROOT"/{sys,proc}
		else
			out_valid "${NEWROOT}/$id directory already exist"
		fi
	done
	if ! [ -d "$NEWROOT/tmp" ]; then
		out_notvalid "Create ${NEWROOT}/tmp directory"
		mkdir -m 1777 -p "$NEWROOT"/tmp
	else
		out_valid "${NEWROOT}/tmp directory already exist"
	fi
}

##		Enter in $NEWROOT with mc

mc_newroot(){
	
	check_mountpoint "$NEWROOT"
	if (( $? )); then
		dg_info "Midnight Commander" "$dgm_invalid_newroot"
		return 1
	fi
		
	create_dir
	mount_umount "$NEWROOT" "mount"
	mount_one "${CACHE_DIR}" "${CACHE_DIR}" "$NEWROOT/var/cache/pacman/pkg" -o bind
	SHELL=/bin/sh chroot "$NEWROOT" /usr/bin/mc || return 1
	umount_one "$NEWROOT/var/cache/pacman/pkg" "$NEWROOT/var/cache/pacman/pkg"
	mount_umount "$NEWROOT" "umount"
	
}

##		Open an interactive shell on NEWROOT

call_shell(){
	
	check_mountpoint "$NEWROOT"
	if (( $? )); then
		dg_info "Chroot" "$dgm_invalid_newroot"
		return 1
	fi
		
	create_dir
	mount_umount "$NEWROOT" "mount"
	mount_one "${CACHE_DIR}" "${CACHE_DIR}" "$NEWROOT/var/cache/pacman/pkg" -o bind
	clear
	tput cnorm
	out_info "Tape exit when you have finished"
	if [[ -e "$NEWROOT/usr/bin/zsh" ]]; then
		SHELL=/bin/sh chroot "$NEWROOT" /usr/bin/zsh || return 1
	else
		SHELL=/bin/sh chroot "$NEWROOT" || return 1
	fi
	umount_one "$NEWROOT/var/cache/pacman/pkg" "$NEWROOT/var/cache/pacman/pkg"
	mount_umount "$NEWROOT" "umount"
	
}


##		Remove once_file

clean_once_file(){
	
	local action dir f_ file
	local -a list
	
	action="${1}"
	dir="${2}"

	if [[ -d "${SOURCES_FUNC}" ]]; then
		while : ;do
			list=$(find $dir/ -maxdepth 1 -type f -printf "%f ")
			echo ${list[@]}
			if [[ -z ${list[@]} ]]; then
				dg_info "Remove Customize Files" "Directory ${disk} is empty, nothing to do"
				return 0
			fi
			list+="Delete_all"
			dg_action file menu "Delete Customize File" "\nSelect the file to delete. Pick Delete_all to delete all files" ${list[@]}
			if (( $? )); then
				return 0
			fi
			case $file in 
				Delete_all) 	
					for f_ in ${list[@]}; do
						if [[ ! "$f_" = Delete_all ]]; then
							${action} "$dir/$f_"
						fi
					done
					return 0
					;;
				*)	${action} "${dir}/${file}"	
					;;
			esac
		done
	else
		dg_info "Remove Customize Files" "Directory ${SOURCES_FUNC} does not exist"
	fi

	unset action dir f_ file list
}

custo_once() {
	local _tmp cmd
	cmd="${1}"
	_tmp="${SOURCES_FUNC}"
	
	if [[ ! -d $_tmp ]]; then
		mkdir -p -m0755 $_tmp || die "Impossible to create $_tmp"
	fi
    if [[ ! -e $_tmp/customize.${cmd} ]]; then
        "${cmd}" || die "Cannot execute $_"
        touch $_tmp/customize.${cmd}
    else
		return
	fi
    unset _tmp
}

generate_fstab(){
	local _directory
	_directory="${1}"
	
	out_action "Generate fstab"
	genfstab -U "$_directory" > "$_directory/etc/fstab" || die " Impossible to generate fstab"

	unset _directory
}
