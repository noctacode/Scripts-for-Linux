#!/bin/bash

# This script makes backups of docker containers
# It pauses a container, copies its files to a new folder, and restarts the container
# It must be ran as root and it retains the original owner
# In case of filename collisions, it appends additional time numbers to the new filename

# Check if the current user is root
if [ "$(id -u)" -ne 0 ]; then
  echo "This script must be run as root" >&2
  exit 1
fi

# Prompt the user for a folder name
echo "Enter the folder name:"
read folderName

# Check if the folder name entered by the user exists
if [ ! -d "$folderName" ]; then
  echo "Error: Folder '$folderName' does not exist" >&2
  exit 1
fi

# Check the owner of the folder
owner=$(stat -c '%U' "$folderName")
if [ "$owner" != "human" ]; then
  echo "Warning: The owner of the folder is not 'human'"
  read -p "Do you want to change the owner to 'human'? (y/n) " answer
  if [ "$answer" == "y" ]; then
    sudo chown human "$folderName"
  fi
fi

# Stop the container using docker compose
cd "$folderName"
docker compose stop
cd ..

# Get the current date in the YYYYMMdd format
date=$(date +%Y%m%d)

# Set the copy folder name
copyFolderName="${folderName}Backup${date}"

# Add hh, mm, or ss to the copy folder name if it is not unique
if [ -d "$copyFolderName" ]; then
  echo "Warning: The copy folder name is not unique"
  datetime=$(date +%H%M%S)
  for (( i=0; i<${#datetime}; i+=2 )); do
    if [ ! -d "$copyFolderName${datetime:$i:2}" ]; then
      copyFolderName="${copyFolderName}${datetime:$i:2}"
      break
    fi
  done
  echo "The new folder name is $copyFolderName"
fi

# Copy the folder with the name specified by the user, including all contents and subdirectories
cp -rp "$folderName" "$copyFolderName" # -p preserves mode, ownership, and timestamp
while IFS= read -r file; do
  if [ -d "$file" ]; then
    echo -n "!"
  else
    echo -n "."
  fi
done < <(find "$folderName" -type f -o -type d)

# Confirm that the folder was copied
if [ $? -eq 0 ]; then
  echo ""
  echo "Folder successfully copied"
else
  echo ""
  echo "Error copying folder"
fi

# Start the container using docker compose
cd "$folderName"
docker compose up -d
cd ..
