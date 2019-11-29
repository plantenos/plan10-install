#!@BINDIR@/bash

# This file is part of Plan10. It is subject to the license terms in
# the LICENSE file found in the top-level directory of this
# distribution.
# This file may not be copied, modified, propagated, or distributed
# except according to the terms contained in the LICENSE file.

DISKS=""
PARTITIONER=""
PARTITIONS=""
SIZE_BOOT_MIN=16
FS_OTPS=""
declare -A FS_FLAGS=(
[f2fs]='' 
[jfs]='-q' 
[xfs]='-f' 
[ntfs]='-q' 
[ext2]='-q' [ext3]='-q' [ext4]='-q' 
[vfat]='-F32' 
[nilfs2]='-q' 
[reiserfs]='-q'
[btrfs]=''
)

part_check_template_space() {
	local size="${1}" temp_size
	if [[ "${CONFIG_DIR}" = "minimal" ]];then
		temp_size="${MINIMAL_SPACE}"
	elif [[ "${CONFIG_DIR}" = @("jwm"|"openbox") ]];then
		temp_size="${JWM_OPEN_SPACE}"
	elif [[ "${CONFIG_DIR}" = @("xfce4"|"plasma") ]];then
		temp_size="${XFCE_PLASMA_SPACE}"
	else
		# we don't know the size on personal template
		# so accept it
		temp_size="${size}"
	fi
	if [[ "${size}" -lt "${temp_size}" ]]; then
		unset size temp_size
		return 1
	else
		unset size temp_size
		return 0
	fi
}

part_build_fs_list() {
	
	if [[ -z ${FS_OTPS[@]} ]];then
		[[ "$(which mkfs.ext2 2>/dev/null)" ]]  && FS_OTPS+=( "ext4 ext3 ext2" )
		[[ "$(which mkfs.vfat 2>/dev/null)" ]]  && FS_OTPS+=( "vfat" )
		[[ "$(which mkfs.xfs 2>/dev/null)" ]]   && FS_OTPS+=( "xfs" )
		[[ "$(which mkreiserfs 2>/dev/null)" ]] && FS_OTPS+=( "reiserfs" )
		[[ "$(which mkfs.btrfs 2>/dev/null)" ]] && FS_OTPS+=( "btrfs" )
		[[ "$(which mkfs.jfs 2>/dev/null)" ]] && FS_OTPS+=( "jfs" )
		[[ "$(which mkfs.nilfs2 2>/dev/null)" ]] && FS_OTPS+=( "nilfs2" )
	fi
}

part_build_partitioner_list() {
	
	if [[ -z ${PARTITIONER[@]} ]];then
		[[ "$(which fdisk 2>/dev/null)" ]] && PARTITIONER+=( "fdisk" )
		[[ "$(which parted 2>/dev/null)" ]] && PARTITIONER+=( "parted" )
		[[ "$(which cfdisk 2>/dev/null)" ]] && PARTITIONER+=( "cfdisk" )
		[[ "$(which cgdisk 2>/dev/null)" ]] && PARTITIONER+=( "cgdisk" )
	fi
}

part_find_partnumber() {
		
	local disk="${1}"
	
	disk=${disk##*[a-z]}
	
	printf "%s" "${disk}"
	
	unset disk
}

part_list_disk() {
	
	DISKS="$(lsblk -lno NAME,SIZE,TYPE | awk '/disk/ {print "/dev/" $1 " " $2}')"
	if [[ -z "${DISKS}" ]]; then
		die "No available devices" "clean_install"
	fi
}

part_list_partition() {
	
	PARTITIONS="$(lsblk -lno NAME,SIZE,TYPE | awk '/part/ {print "/dev/" $1 " " $2}')"
	if [[ -z "${PARTITIONS}" ]]; then
		die "No available partitions" "clean_install"
	fi
}

part_umount_partition() {
	
	local disk="${1}"
	local -a part 
	
	part=( $(lsblk -lno MOUNTPOINT ${disk}) )
	
	for i in ${part[@]};do
		umount -R "${i}"
	done
	
	unset disk part
}

# @2:disk(disk size),part(partition size)
# return size in MiB
part_get_size(){
	
	local disk="${1}" regex="${2}"
	
	printf "%s" $(($(lsblk -lbno SIZE,TYPE "${disk}" | awk '/'"${regex}"'/ { print $1 }')/2**20))
	
	unset disk 
}

part_set_size() {
	
	local part="" title="${2}" msg="${3}" size="${4}" disk_size="${5}" min_size="${6}"

	while [[ "${part}" = "" ]]; do
		dg_action part input "${title}" "\n${DG_COLOR_BOLD}${msg}${DG_COLOR_RESET}Disk space left: ${disk_size} MiB" "${size}"
		if (( $? )); then
			return 1
		fi
		if [[ "${part}" = "" ]] || [[ "${part}" -lt "${min_size}" ]]; then
			dg_info "${title}" "\nYou entered an ${DG_COLOR_ERROR}invalid${DG_COLOR_RESET} size, please retry"
			part=""
		elif [[ "${part}" -gt "${disk_size}" ]];then
			dg_info "${title}" "\nThe size is ${DG_COLOR_ERROR}too large${DG_COLOR_RESET}, please retry"
			part=""
		fi
	done
	
	printf -v "$1" "%s" "$part"
	
	unset part title msg size disk_size min_size
}

part_set_fs() {
	
	local type="" mpt="${2}" 
	
	while [[ "${type}" = "" ]]; do
		dg_action type menu "${title}" "\nSelect the fstype to use for your ${DG_COLOR_BOLD}${mpt}${DG_COLOR_RESET} partition" ${FS_OTPS[@]}
		if (( $? )); then
			return 1
		fi
	done
	
	printf -v "$1" "%s" "$type"
	
	unset type mpt
}

part_destroy_disk() {

	local disk="${1}" info part
	
	mount_umount "$NEWROOT" "umount"
	part_umount_partition "${disk}"
	swapoff -a
	
	info="$(parted -s "${disk}" print)"
	
	while read -r part; do
		if [[ -z "${part}" ]];then
			continue
		fi
		parted -s "${disk}" rm "${part}" >/dev/null || die "unable to delete partition ${part}" "clean_install"
	done <<< "$(awk '/^ [1-9][0-9]?/ {print $1}' <<< "${info}" | sort -r)"
	
	unset disk info part
}
	
part_create_table(){
	
	local disk="${1}" table
	
	if [[ "${FIRMWARE}" == "BIOS" ]]; then
		table="msdos" 
	else
		table="gpt" 
	fi
	
	parted -s "${disk}" mklabel "${table}" >/dev/null || die "unable to create table at ${disk}" "clean_install"

	unset disk table
}

part_create_partition(){
	
	local disk="${1}" part_type="${2}" fs_type="${3}" start="${4}" end="${5}"
	
	parted -s "${disk}" mkpart ${part_type} ${fs_type} ${start} ${end} >/dev/null || die "unable to create partition ${disk}" "clean_install"
	
	unset disk part_type fs_type start end
}

part_format() {
	
	local part="$1" fs="$2"

	dg_info "Partition Format" "\nFormatting $part as $fs\n" 1
	mkfs.$fs ${FS_FLAGS[$fs]} ${part} >/dev/null || die "unable to format ${part}" "clean_install"
	
	unset part fs
}

part_boot_flag() {
	local part="${1}" part_num
	
	if [[ "${part}" = /dev/nvme* ]]; then
		part_num=${part##*p}
		part=${part%%p[0-9]*}
	else
		part_num=${part##*[a-z]}
		part=${part%%[0-9]*}
	fi
	if [[ "${FIRMWARE}" == "UEFI" ]]; then
		parted -s "${part}" set "${part_num}" esp on >/dev/null || die "unable to set boot flag at ${1}" "clean_install"
	else
		parted -s "${part}" set "${part_num}" boot on >/dev/null || die "unable to set boot flag at ${1}" "clean_install"
	fi
	
	unset part part_num
}

# @3: do not append newroot if we come from manual part
part_mount() {

	local part="$1" mpt
	
	if [[ -z "${3}" ]];then
		mpt="${NEWROOT}${2}"
	else
		mpt="${2}"
	fi
	
	mkdir -p "${mpt}"
	
	if [[ "${2}" == "swap" ]];then
		mkswap "${part}" || die "unable to mkswap ${part}" "clean_install"
		swapon "${part}" || die "unable to swapon ${part}" "clean_install"
		return 0
	fi
	if grep -qw "${part}" /proc/mounts; then
		dg_info "Mount Partition" "\nPartition ${part} is already mounted\n" 1
		return 0 
	fi
	
	mount "${part}" "${mpt}" >/dev/null || die "unable to mount ${part} to ${mpt}" "clean_install"
	
	unset part mpt
}

part_auto() {
	
	local title="Auto Partition" n_part step
	local boot_size=0 swap_size=0 root_size="" home_size=0 
	local fs_boot="" fs_root="" fs_home=""
	local wboot=0 whome=0 wswap=0 wroot=1 count=1
	local disk disk_size=0 rest_size=0 start_size end_size

	local msg_disk_size="\n
The size of your disk is ${DG_COLOR_WARN}too small${DG_COLOR_RESET} \
to install ${CONFIG_DIR} template.\n
Please choose an another disk."

	local msg_rest_size="\n
The remaining disk space is ${DG_COLOR_WARN}too small${DG_COLOR_RESET} \
to install ${CONFIG_DIR} template.\nPlease retry."

	local msg_root_size="\n
The size of the root partition is ${DG_COLOR_WARN}too small${DG_COLOR_RESET} \
to install ${CONFIG_DIR} template.\nPlease retry."

	disk_hash="$(lsblk -f | base64)"
	
	if (( "${MANUAL_PREP}" )) || (( "${AUTO_PREP}" )); then
		dg_yesno "${title}" "\nPartition are already prepared. Do you want to continue anyway?"
		if (( $? )); then
			return 0
		fi
	fi
	
	DISKS=""
	part_list_disk
	part_build_fs_list
		
	DG_ITEMS_OPTS=""
	while (( ! "${disk_size}" )) ; do
		dg_action disk menu "${title}" "\nSelect the disk to use." ${DISKS[@]}
		if (( $? )); then
			DG_ITEMS_OPTS="--no-items"
			return 0
		fi
		disk_size=$(part_get_size "$disk" "disk")
		if ! part_check_template_space "${disk_size}";then
			dg_info "${title}" "$msg_disk_size"
			disk_size=0
			continue
		fi
	done
	DG_ITEMS_OPTS="--no-items"
			
	rest_size="${disk_size}"
	start_size=1 # mbr at minimum
	
	if [[ "${FIRMWARE}" == "BIOS" ]];then
		n_part=("boot" "Create a separate boot partition" "on" "home" "Create a separate home partition" "on" "swap" "Create a swap partition" "on")
	else
		n_part=("home" "Create a separate home partition" "on" "swap" "Create a swap partition" "on")
	fi
	check_msg="\n
Use space to select/unselect a field.\n"
#Note: If you plan to use syslinux as bootloader leave selected the boot partition. Syslinux will ${DG_COLOR_WARN}fail${DG_COLOR_RESET} without it.\n"
 
	dialog $DG_BACKTITLE --cancel-label " Back " $DG_OPTS --ok-label "Select" --title " Partition Auto Menu " --checklist "$check_msg" 0 0 0 \
		"${n_part[@]}" \
		2>"$DG_ANS"
	
	if (( $? )); then
		return 0
	fi
	
	read -r step < "$DG_ANS"
	
	# boot
	if [[ "${FIRMWARE}" == "UEFI" ]];then
		wboot=1
		boot_size=$(( 512 + "${start_size}" )) #MBR
		rest_size=$(( "${rest_size}" - "${boot_size}" ))
		count=2
	elif [[ $step =~ "boot" ]]; then
		while (( ! "${boot_size}" ));do
			part_set_size boot_size "${title}" "${dgm_auto_part_boot_size}" 512 "${rest_size}" 16 || return 0
			if [[ "${boot_size}" -gt 1024 ]];then
				dg_info "${title}" "\nThe size is ${DG_COLOR_ERROR}too large${DG_COLOR_RESET}, please retry"
				boot_size=0
				continue
			fi
			wboot=1
			boot_size=$(( "${boot_size}" + "${start_size}" )) #MBR
			rest_size=$(( "${rest_size}" - "${boot_size}" ))
			count=2
		done
	fi
	
	# swap
	if [[ $step =~ "swap" ]]; then
		while (( ! "${swap_size}" ));do
			# swap partition come after boot or root
			part_set_size swap_size "${title}" "${dgm_auto_part_swap_size}" 3200 "${rest_size}" 1 || return 0
			if ! part_check_template_space "$(( "${rest_size}" - "${swap_size}" ))";then
				dg_info "${title}" "$msg_rest_size"
				swap_size=0
				continue
			fi
			if (( ! "${wboot}" ));then
				wswap=$(( "${count}" + 1 ))
			else
				wswap="${count}"
				((count++))
			fi
			rest_size=$(( "${rest_size}" - "${swap_size}" ))
		done
	fi
	wroot=$count
	
	# home
	if [[ $step =~ "home" ]]; then
		if (( "${wswap}" )) && (( ! "${wboot}" ));then
				whome=$(( "${wroot}" + 2 ))
		else
			whome=$(( "${wroot}" + 1 ))
		fi
	fi
	
	# Root
	if (( ! "${whome}" ));then
		root_size="${rest_size}"
	else
			while [[ "${root_size}" = "" ]]; do
			part_set_size root_size "${title}" "${dgm_auto_part_root_size}" 7500 "${rest_size}" 2048 || return 0
			if ! part_check_template_space "${root_size}";then
				dg_info "${title}" "$msg_root_size"
				root_size=""
				continue
			fi
			home_rest_size=$(( "${rest_size}" - "${root_size}" ))
			if [[ "${home_rest_size}" -lt 100 ]]; then
				dg_info "${title}" "\nThe remaining home size is ${DG_COLOR_WARN}too small${DG_COLOR_RESET}, please retry."
				root_size=""
				continue
			fi
			dg_yesno "${title}" "\nThe size of your ${DG_COLOR_BOLD}/home${DG_COLOR_RESET} partition will be: ${home_rest_size}MiB."
			if (( $? )); then
				root_size=""
				continue
			fi
		done
	fi
	
	
	if [[ "${FIRMWARE}" == "BIOS" ]] && (( "${wboot}" )); then
		part_set_fs fs_boot "/boot" || return 1
	else
		fs_boot="vfat"
	fi
	part_set_fs fs_root "/ (root)" || return 1
	if (( "${whome}" ));then
		part_set_fs fs_home "/home" || return 1
	fi
		
		
	# Last chance to cancel
	dg_info "${title}" "\nDisk $disk will be ${DG_COLOR_ERROR}totally erased${DG_COLOR_RESET}!\n\nDo you want to process?\n"
	if (( $? )); then
		return 0
	fi
	
	part_destroy_disk "${disk}"
	part_create_table "${disk}"
	
	end_size="${disk_size}"
	# boot partition
	if (( "${wboot}" )); then
		if [[ "${FIRMWARE}" == "BIOS" ]]; then
			part_create_partition "${disk}" "primary" "${fs_boot}" "${start_size}MiB" "${boot_size}MiB"
		else
			part_create_partition "${disk}" "ESP" "fat32" "${start_size}MiB" "${boot_size}MiB"
		fi
		part_format "${disk}${wboot}" "${fs_boot}"
		start_size="${boot_size}"
	else
		wboot="${wroot}"
	fi

	# Swap partition
	if (( "${wswap}" ));then
		end_size=$(( "${start_size}" + "${swap_size}" ))
		part_create_partition "${disk}" "primary" "linux-swap" "${start_size}MiB" "${end_size}MiB"
		start_size="${end_size}"
	fi

	# / partition	
	if (( "${whome}" ));then
		end_size=$(( "${start_size}" + "${root_size}" ))
		part_create_partition "${disk}" "primary" "${fs_root}" "${start_size}MiB" "${end_size}MiB" 
		start_size="${end_size}"
	else
		part_create_partition "${disk}" "primary" "${fs_root}" "${start_size}MiB" "100%" 
	fi
	part_format "${disk}${wroot}" "${fs_root}"
	part_boot_flag "${disk}${wboot}"
	
	# /home partition
	if (( "${whome}" ));then
		part_create_partition "${disk}" "primary" "${fs_home}" "${start_size}MiB" "100%" 
		part_format "${disk}${whome}" "${fs_home}"	
	fi

	# Mount first root
	part_mount "${disk}${wroot}"
	# Mount the rest
	if (( "${wboot}" ));then
		if [[ "${BOOTLOADER}" == "GRUB" ]] && [[ "${FIRMWARE}" == "UEFI" ]];then
			part_mount "${disk}${wboot}" "/efi"
		else
			part_mount "${disk}${wboot}" "/boot"
		fi
	fi
	if (( "${whome}" ));then
		part_mount "${disk}${whome}" "/home"
	fi
	if (( "${wswap}" ));then
		part_mount "${disk}${wswap}" "swap"
	fi
	if [[ "${disk_hash}" != "$(lsblk -f | base64)" ]]; then
		partprobe >/dev/null 2>&1
	fi
	
	AUTO_PREP=1
	
	unset title n_part boot_size swap_size root_size home_size step
	unset fs_boot fs_root fs_home
	unset wboot whome wswap wroot count
	unset disk disk_size rest_size start_size end_size
	unset msg_disk_size msg_root_size
}	

part_manual() {
	
	local disk soft old_opts disk_size

	local msg_disk_size="\n
The size of your disk is ${DG_COLOR_WARN}too small${DG_COLOR_RESET} \
to install ${CONFIG_DIR} template.\n
Please choose an another disk."

	if (( "${MANUAL_PREP}" )) || (( "${AUTO_PREP}" )); then
		dg_yesno "Manual Partition" "\nPartition are already prepared. Do you want to continue anyway?"
		if (( $? )); then
			return 0
		fi
	fi
	
	mount_umount "$NEWROOT" "umount"
	
	DISK=""
	part_list_disk
	part_build_partitioner_list 
	
	dg_action soft menu "Manual Partition" "\nSelect the program to use." ${PARTITIONER[@]}
	if (( $? ));then
		return 0
	fi
	
	old_opts="${DG_EXTRA_OPTS}"
	DG_ITEMS_OPTS=""
	DG_EXTRA_OPTS="--cancel-label Done"
	while : ;do
		dg_action disk menu "Manual Partition" "\nSelect the disk to manage" ${DISKS[@]} || break
		disk_size=$(part_get_size "$disk" "disk")
		if ! part_check_template_space "${disk_size}";then
			dg_info "${title}" "$msg_disk_size"
			disk_size=0
			continue
		fi
		part_umount_partition "${disk}"
		tput cnorm
		"${soft}" "${disk}"
	done
	DG_ITEMS_OPTS="--no-items"
	DG_EXTRA_OPTS="${old_opts}"
	unset disk soft old_opts disk_size msg_disk_size
}

part_format_manual() {

	local disk fs
	
	if (( "${MANUAL_PREP}" )) || (( "${AUTO_PREP}" )); then
		dg_yesno "Manual Format" "\nPartition are already prepared. Do you want to continue anyway?"
		if (( $? )); then
			return 0
		fi
	fi
	
	mount_umount "$NEWROOT" "umount"
	
	part_build_fs_list
	part_list_partition
	
	old_opts="${DG_EXTRA_OPTS}"
	while : ;do
		DG_ITEMS_OPTS=""
		DG_EXTRA_OPTS="--cancel-label Done"
		dg_action disk menu "Manual Format" "\nSelect the partition to format" ${PARTITIONS[@]} || break
		DG_ITEMS_OPTS="--no-items"
		DG_EXTRA_OPTS="${old_opts}"
		part_set_fs fs "${disk}" 
		part_format "${disk}" "${fs}"
	done
	
	DG_ITEMS_OPTS="--no-items"
	DG_EXTRA_OPTS="${old_opts}"
	
	unset disk fs old_opts
}

part_mount_manual() {
	
	local disk mnt old_opts
	
	if (( "${MANUAL_PREP}" )) || (( "${AUTO_PREP}" )); then
		dg_yesno "Manual Mount" "\nPartition are already prepared. Do you want to continue anyway?"
		if (( $? )); then
			return 0
		fi
	fi
	
	mount_umount "$NEWROOT" "umount"
	
	part_list_partition
	
	old_opts="${DG_EXTRA_OPTS}"
	
	while : ;do
		DG_ITEMS_OPTS=""
		DG_EXTRA_OPTS="--cancel-label Done"
		dg_action disk menu "Manual Mount" "\nSelect the partition to mount" ${PARTITIONS[@]} || break
		DG_ITEMS_OPTS="--no-items"
		DG_EXTRA_OPTS="${old_opts}"
		dg_action mnt input "Manual Mount" "$dgm_mount_manual" || break
		part_mount "${disk}" "${mnt}" "manual"
	done
	
	DG_ITEMS_OPTS="--no-items"
	DG_EXTRA_OPTS="${old_opts}"
	
	unset disk mnt old_opts
}
