PASSWORD_FILE="passwords.enc"
MASTER_USERNAME="rifat"
MASTER_PASSWORD="r107754n" 

encrypt() {
  echo "$1" | openssl enc -aes-256-cbc -a -salt -pass pass:"$password_key"
}

decrypt() {
  echo "$1" | openssl enc -aes-256-cbc -d -a -pass pass:"$password_key"
}

generate_password() {
  echo "$(openssl rand -base64 12)"
}

show_error() {
  zenity --error --text="$1"
}

show_main_menu() {
  zenity --list --title="Main Menu" --column="Option" --hide-header \
    "1. Password Manager" \
    "2. File Organizer" \
    "3. Exit"
}

show_password_manager_menu() {
  zenity --list --title="Password Manager Menu" --column="Option" --hide-header \
    "1. Add New Password" \
    "2. View Passwords" \
    "3. Update Password" \
    "4. Delete Password" \
    "5. Search Passwords" \
    "6. Generate Password" \
    "7. Back to Main Menu"
}

authenticate() {
  input_username=$(zenity --entry --title="Authentication Required" --text="Enter username:")
  input_password=$(zenity --password --title="Authentication Required" --text="Enter password:")
  
  if [ "$input_username" == "$MASTER_USERNAME" ] && [ "$input_password" == "$MASTER_PASSWORD" ]; then
    return 0
  else
    show_error "Authentication failed. Access denied."
    return 1
  fi
}

add_password() {
  service_name=$(zenity --entry --title="Add New Password" --text="Enter service name:")
  if [ -z "$service_name" ]; then
    show_error "Service name cannot be empty."
    return
  fi
  username=$(zenity --entry --title="Add New Password" --text="Enter username:")
  if [ -z "$username" ]; then
    show_error "Username cannot be empty."
    return
  fi
  password=$(zenity --password --title="Add New Password" --text="Enter password:")
  if [ -z "$password" ]; then
    show_error "Password cannot be empty."
    return
  fi
  encrypted_password=$(encrypt "$password")
  echo "$service_name:$username:$encrypted_password" >> "$PASSWORD_FILE"
  zenity --info --text="Password added."
}

view_passwords() {
  if ! authenticate; then
    return
  fi

  if [ ! -f "$PASSWORD_FILE" ]; then
    show_error "No passwords saved."
    return
  fi
  passwords=""
  while IFS=: read -r service username enc_pass; do
    dec_pass=$(decrypt "$enc_pass")
    passwords+="Service: $service, Username: $username, Password: $dec_pass\n"
  done < "$PASSWORD_FILE"
  zenity --info --title="View Passwords" --text="$passwords"
}

update_password() {
  service_name=$(zenity --entry --title="Update Password" --text="Enter service name to update:")
  if [ -z "$service_name" ]; then
    show_error "Service name cannot be empty."
    return
  fi
  username=$(zenity --entry --title="Update Password" --text="Enter username to update:")
  if [ -z "$username" ]; then
    show_error "Username cannot be empty."
    return
  fi
  new_password=$(zenity --password --title="Update Password" --text="Enter new password:")
  if [ -z "$new_password" ]; then
    show_error "New password cannot be empty."
    return
  fi
  new_encrypted_password=$(encrypt "$new_password")
  if [ ! -f "$PASSWORD_FILE" ]; then
    show_error "No passwords saved."
    return
  fi
  tempfile=$(mktemp)
  updated=0
  while IFS=: read -r service stored_username enc_pass; do
    if [ "$service" == "$service_name" ] && [ "$stored_username" == "$username" ]; then
      echo "$service:$stored_username:$new_encrypted_password" >> "$tempfile"
      updated=1
    else
      echo "$service:$stored_username:$enc_pass" >> "$tempfile"
    fi
  done < "$PASSWORD_FILE"
  mv "$tempfile" "$PASSWORD_FILE"
  if [ $updated -eq 1 ]; then
    zenity --info --text="Password updated for service $service_name with username $username."
  else
    show_error "No such entry found."
  fi
}

delete_password() {
  service_name=$(zenity --entry --title="Delete Password" --text="Enter service name to delete:")
  if [ -z "$service_name" ]; then
    show_error "Service name cannot be empty."
    return
  fi
  username=$(zenity --entry --title="Delete Password" --text="Enter username to delete:")
  if [ -z "$username" ]; then
    show_error "Username cannot be empty."
    return
  fi
  if [ ! -f "$PASSWORD_FILE" ]; then
    show_error "No passwords saved."
    return
  fi
  tempfile=$(mktemp)
  deleted=0
  while IFS=: read -r service stored_username enc_pass; do
    if [ "$service" == "$service_name" ] && [ "$stored_username" == "$username" ]; then
      deleted=1
    else
      echo "$service:$stored_username:$enc_pass" >> "$tempfile"
    fi
  done < "$PASSWORD_FILE"
  mv "$tempfile" "$PASSWORD_FILE"
  if [ $deleted -eq 1 ]; then
    zenity --info --text="Password entry for service $service_name with username $username deleted."
  else
    show_error "No such entry found."
  fi
}

search_password() {
  service_name=$(zenity --entry --title="Search Password" --text="Enter service name to search:")
  if [ -z "$service_name" ]; then
    show_error "Service name cannot be empty."
    return
  fi
  username=$(zenity --entry --title="Search Password" --text="Enter username to search:")
  if [ -z "$username" ]; then
    show_error "Username cannot be empty."
    return
  fi
  if [ ! -f "$PASSWORD_FILE" ]; then
    show_error "No passwords saved."
    return
  fi
  found=0
  while IFS=: read -r service stored_username enc_pass; do
    if [ "$service" == "$service_name" ] && [ "$stored_username" == "$username" ]; then
      dec_pass=$(decrypt "$enc_pass")
      zenity --info --title="Search Result" --text="Service: $service, Username: $stored_username, Password: $dec_pass"
      found=1
      break
    fi
  done < "$PASSWORD_FILE"
  if [ $found -eq 0 ]; then
    show_error "No such entry found."
  fi
}

move_file() {
  file=$(zenity --file-selection --title="Select File to Move")
  if [ -z "$file" ]; then
    show_error "No file selected."
    return
  fi
  destination=$(zenity --file-selection --directory --title="Select Destination Directory")
  if [ -z "$destination" ]; then
    show_error "No destination selected."
    return
  fi
  mv "$file" "$destination"
  zenity --info --text="File moved to $destination."
}

copy_file() {
  file=$(zenity --file-selection --title="Select File to Copy")
  if [ -z "$file" ]; then
    show_error "No file selected."
    return
  fi
  destination=$(zenity --file-selection --directory --title="Select Destination Directory")
  if [ -z "$destination" ]; then
    show_error "No destination selected."
    return
  fi
  cp "$file" "$destination"
  zenity --info --text="File copied to $destination."
}

rename_file() {
  file=$(zenity --file-selection --title="Select File to Rename")
  if [ -z "$file" ]; then
    show_error "No file selected."
    return
  fi
  new_name=$(zenity --entry --title="Rename File" --text="Enter new file name:")
  if [ -z "$new_name" ]; then
    show_error "New file name cannot be empty."
    return
  fi
  mv "$file" "$(dirname "$file")/$new_name"
  zenity --info --text="File renamed to $new_name."
}

delete_file() {
  file=$(zenity --file-selection --title="Select File to Delete")
  if [ -z "$file" ]; then
    show_error "No file selected."
    return
  fi
  rm "$file"
  zenity --info --text="File deleted."
}

sort_files() {
  directory=$(zenity --file-selection --directory --title="Select Directory to Sort")
  if [ -z "$directory" ]; then
    show_error "No directory selected."
    return
  fi
  sorted_files=$(ls -1 "$directory" | sort)
  zenity --info --title="Sorted Files" --text="$sorted_files"
}

add_folder() {
  directory=$(zenity --file-selection --directory --title="Select Parent Directory")
  if [ -z "$directory" ]; then
    show_error "No directory selected."
    return
  fi
  folder_name=$(zenity --entry --title="Add Folder" --text="Enter new folder name:")
  if [ -z "$folder_name" ]; then
    show_error "Folder name cannot be empty."
    return
  fi
  mkdir "$directory/$folder_name"
  zenity --info --text="Folder $folder_name added to $directory."
}

add_file() {
  directory=$(zenity --file-selection --directory --title="Select Directory")
  if [ -z "$directory" ]; then
    show_error "No directory selected."
    return
  fi
  file_name=$(zenity --entry --title="Add File" --text="Enter new file name:")
  if [ -z "$file_name" ]; then
    show_error "File name cannot be empty."
    return
  fi
  touch "$directory/$file_name"
  zenity --info --text="File $file_name added to $directory."
}

show_file_organizer_menu() {
  zenity --list --title="File Organizer Menu" --column="Option" --hide-header \
    "1. Move File" \
    "2. Copy File" \
    "3. Rename File" \
    "4. Delete File" \
    "5. Sort Files" \
    "6. Add Folder" \
    "7. Add File" \
    "8. Back to Main Menu"
}

while true; do
  main_choice=$(show_main_menu)
  case $main_choice in
    "1. Password Manager")
      while true; do
        pm_choice=$(show_password_manager_menu)
        case $pm_choice in
          "1. Add New Password") add_password ;;
          "2. View Passwords") view_passwords ;;
          "3. Update Password") update_password ;;
          "4. Delete Password") delete_password ;;
          "5. Search Passwords") search_password ;;
          "6. Generate Password")
            generated_password=$(generate_password)
            zenity --info --title="Generated Password" --text="New Password: $generated_password"
            ;;
          "7. Back to Main Menu") break ;;
          *) show_error "Invalid option. Please try again." ;;
        esac
      done
      ;;
    "2. File Organizer")
      while true; do
        fo_choice=$(show_file_organizer_menu)
        case $fo_choice in
          "1. Move File") move_file ;;
          "2. Copy File") copy_file ;;
          "3. Rename File") rename_file ;;
          "4. Delete File") delete_file ;;
          "5. Sort Files") sort_files ;;
          "6. Add Folder") add_folder ;;
          "7. Add File") add_file ;;
          "8. Back to Main Menu") break ;;
          *) show_error "Invalid option. Please try again." ;;
        esac
      done
      ;;
    "3. Exit")
      zenity --info --text="Exiting."
      exit 0
      ;;
    *) show_error "Invalid option. Please try again." ;;
  esac
done

