#!/bin/bash

###########################################################################
# Script: LinuxAgentDeploy.sh                                             #
# Description: Runs automate deployment for Linux agents                  # 
# - Additionally checks for existing server and performs rip and replace  #
# - Set variables in configuration below                                  #
# Author: John Duprey - Complete Network                                  #
# Link: https://github.com/johnduprey/CWA-Deployment                      #
###########################################################################

## Configuration

# Specify server address and location id here
server=YOURSERVERHERE       # FQDN only, do not include https://
locationid=YOURLOCATIONID

## END Configuration

# Check for existing agent and compare with server address listed above
agent_installed=0
if [ -d "/usr/local/ltechagent" ]; then
   if [ -f "/usr/local/ltechagent/agent_config" ]; then
      server_url=$(grep -e "server_url" /usr/local/ltechagent/agent_config)
      if [[ $server_url =~ .*${server} ]]; then
         echo "Agent already installed"
         agent_installed=1
      else  # remove agents that do not match server address
         echo Agent server address mismatch - $server_url - starting rip and replace
         if [ -f "/usr/local/ltechagent/uninstaller.sh" ]; then
            echo Issuing uninstall...
            $(/bin/bash /usr/local/ltechagent/uninstaller.sh)
            if [ -d "/usr/local/ltechagent" ]; then
               echo Error: Uninstall failed
            else
               echo Uninstall successful
            fi
         else
            echo Error: Uninstaller missing
         fi
      fi
   fi
fi

# If agent not installed / uninstalled, download new zip from Automate server and install
if [ "$agent_installed" -eq "0" ]; then
   echo Downloading installation package...
   CURL=$(command -v curl); 
   WGET=$(command -v wget); 
   
   # Replace arch detection from LTInstall_General
   arch=$(uname -m)

   install_archive=""
   linux_id=""

   if [ [ "$arch" = "i386" ] || [ "$arch" = "i686" ] ]; then 
      install_archive="ltechagent_x86.zip"
      linux_id="3"
   fi    

   if [ "$arch" = "x86_64" ]; then
      install_archive="ltechagent_x86_64.zip"
      linux_id="4"
   fi    

   if [ "$install_archive" = "" ]; then
      echo Unable to determine architecture
      exit 1
   fi
   
   # Remove existing files if script failed in the past
   rm -f "$install_archive"
   rm -rf LTechAgent

   
   if [ ! -z $WGET ]; then
      # Set wget to only try once - fix for not supplying content length - also hardcode output filename
      $WGET --content-disposition --no-check-certificate -t 1 "https://$server/labtech/deployment.aspx?probe=1&linux=$linux_id" -O $install_archive
   else
      if [ ! -z $CURL ]; then
        $curl "https://$server/labtech/deployment.aspx?probe=1&linux=$linux_id" -o $install_archive -j
      fi
   fi
        
   echo Starting Install...

   unzip "$install_archive"
   pushd LTechAgent
   # Replace location id in install.sh
   sed -i "s/LT_LOCATION_ID=1/LT_LOCATION_ID=${locationid}/" ./install.sh
   bash ./install.sh
   popd

   sleep 5

   echo Validating...
   if [ -d "/usr/local/ltechagent" ]; then
      echo ltechagent directory exists
      if [ -f "/usr/local/ltechagent/state" ]; then
         echo LTSvc running
         agentid=$(grep -oE '"computer_id":.*?([0-9]+)' /usr/local/ltechagent/state | cut -d " " -f2)
         echo Agent installed successfully - ID:$agentid
      else
         echo Error: state file not present, agent may not be checking in 
      fi
   else
      echo Error: ltechagent directory missing
   fi

   echo Installation cleanup...
   rm -f "$install_archive"
   rm -rf LTechAgent
   echo Done.
fi
