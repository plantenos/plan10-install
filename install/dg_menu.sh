#!@BINDIR@/bash

dgm_default_title="Plan10 Install Informations"
dgm_update_install="\n
Do you want to update the ${DG_COLOR_BOLD}plan10-install${DG_COLOR_RESET} package?\n
Some functionalities ${DG_COLOR_WARN}may not${DG_COLOR_RESET} work properly if you skip this step!"
   
dgm_update_install_themes="\n
Do you want to update the ${DG_COLOR_BOLD}plan10-install-themes${DG_COLOR_RESET} package?\n
Some functionalities ${DG_COLOR_WARN}may not${DG_COLOR_RESET} work properly if you skip this step!"

dgm_update="\n
plan10-install was updated.\n
The script needs to be restarted to apply changes.\n
Please run the previous command again."

dgm_welcome="\n
This will help you get Plan10 installed and setup on your system.\n\n
Shown in square brackets are ${DG_COLOR_VALUES}[Default values]${DG_COLOR_RESET}.\n\n
You can stop the script at any time by pressing ${DG_COLOR_BOLD}CTRL+C${DG_COLOR_RESET} key.\n\n
Menu Navigation:\n\n
  - Select items with the ${DG_COLOR_BOLD}arrow keys${DG_COLOR_RESET}.\n
  - Use ${DG_COLOR_BOLD}[Space]${DG_COLOR_RESET} to toggle check boxes and ${DG_COLOR_BOLD}[Enter]${DG_COLOR_RESET} to accept.\n
  - Switch between fields using ${DG_COLOR_BOLD}[Tab]${DG_COLOR_RESET} or the ${DG_COLOR_BOLD}arrow keys${DG_COLOR_RESET}.\n
  - Use ${DG_COLOR_BOLD}[Page Up]${DG_COLOR_RESET} and ${DG_COLOR_BOLD}[Page Down]${DG_COLOR_RESET} to jump whole pages\n
  - Press the highlighted key of an option to select it."

dgm_network_fail="\n
A valid network is missing.\n
Please check it and try to run again the Plan10 installer."

dgm_main_menu="\n
  Please make sure to configure the installation to your needs."
  
dgm_template_menu="\n
Edit the following files to suit your needs."

dgm_customize_menu="\n
Define the following variable to suit your needs."

dgm_expert_menu="\n
The ${DG_COLOR_BOLD}base${DG_COLOR_RESET} of the system ${DG_COLOR_WARN}must${DG_COLOR_RESET} \
be installed at least before using the options ${DG_COLOR_BOLD}2${DG_COLOR_RESET} to \
${DG_COLOR_BOLD}4${DG_COLOR_RESET}."

dgm_choose_root_directory="\n
Enter the path of the directory to install the system. It must be an absolute path.\n\n
This path will be also used for partitionning your devices if you ask for it."

dgm_choose_cache_directory="\n
Enter the path for your own cache directory. It must be an absolute path."

dgm_choose_cache_directory_fail="\n
Your entered path is ${DG_COLOR_ERROR}not${DG_COLOR_RESET} a directory. Please retry."

dgm_choose_firmware="\n
Select the firmware interface to use."

dgm_choose_firmware_warm_gpt="\n
Your disk was ${DG_COLOR_ERROR}not${DG_COLOR_RESET} formatted with a ${DG_COLOR_BOLD}GUID${DG_COLOR_RESET} partition table!\n\
To boot with ${DG_COLOR_BOLD}UEFI${DG_COLOR_RESET} it is ${DG_COLOR_WARN}highly${DG_COLOR_RESET} recommended to use ${DG_COLOR_BOLD}GPT${DG_COLOR_RESET}."

dgm_choose_firmware_no_efi="\n
No ${DG_COLOR_BOLD}EFI${DG_COLOR_RESET} system partition ${DG_COLOR_ERROR}found!${DG_COLOR_RESET}\n
Manually check your disk layout before continuing.\n\n
Exit the script to review partitions?"

dgm_edit_pkg_list="\n
Select the list you want to edit.\n\n
You can create or delete a file picking the Create or Delete entry respectively."

dgm_invalid_newroot="\n
Your install directory ${DG_COLOR_VALUES}[$NEWROOT]${DG_COLOR_RESET} is not a valid mountpoint.\n
Please partition and mount first your devices into it."

dgm_auto_part_boot_size="\n
Enter the size (in MiB) of your ${DG_COLOR_BOLD}/boot${DG_COLOR_RESET} partition.\n
Minimum is 16, maximum is 1024.\n\n"

dgm_auto_part_swap_size="\n
Enter the size (in MiB) of your ${DG_COLOR_BOLD}swap${DG_COLOR_RESET} partition.\n
For ease of use and as an example it is filled in to match the size of your system memory (RAM).\n\n"

dgm_auto_part_root_size="\n
Enter the size (in MiB) of your ${DG_COLOR_BOLD}/ (root)${DG_COLOR_RESET} partition.\n
The ${DG_COLOR_BOLD}/home${DG_COLOR_RESET} partition will use the remaining space."

dgm_auto_part_home_size="\n
Enter the size (in MiB) of your ${DG_COLOR_BOLD}/home${DG_COLOR_RESET} partition.\n"

dgm_mount_manual="\n
Enter the mount point. ${DG_COLOR_WARN}Must${DG_COLOR_RESET} be an absolute path.\n\n
Enter ${DG_COLOR_BOLD}swap${DG_COLOR_RESET} for swap partition."
