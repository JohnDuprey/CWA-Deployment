#!/bin/bash

###########################################################################
# Script: MacAgentDeploy.sh                                               #
# Description: Runs automate deployment for Mac OS X agents               # 
# - Additionally checks for existing server and performs rip and replace  #
# - Set variables in configuration below                                  #
# Author: John Duprey - Complete Network                                  #
# Link: https://github.com/johnduprey/CWA-Deployment                      #
###########################################################################

## Configuration

# Specify server address and location id here
server=YOURSERVERHERE        # FQDN only, do not include https://
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
   curl -s "https://${server}/Labtech/Deployment.aspx?probe=1&LINUX=2" -o LTechAgent.zip

   echo Starting Install...
   unzip LTechAgent.zip
   sed -i '' "s/LT_LOCATION_ID=1/LT_LOCATION_ID=${locationid}/" ./config.sh

   source ./config.sh
   installer -pkg LTSvc.mpkg -target /
   sleep 5

   echo Validating...
   if [ -d "/usr/local/ltechagent" ]; then
      echo ltechagent directory exists
      if launchctl list | grep com.labtechsoftware.LTSvc; then
         echo LTSvc running
         if [ -f "/usr/local/ltechagent/state" ]; then
            agentid=$(grep -oE '"computer_id":.*?([0-9]+)' /usr/local/ltechagent/state | cut -d " " -f2)
            echo Agent installed successfully - ID:$agentid
         else
            echo Error: state file not present, agent may not be checking in 
         fi
      else
         echo Error: LTSvc not running
      fi
   else
      echo Error: ltechagent directory missing
   fi

   echo Installation cleanup...
   rm config.sh
   rm LTSvc.mpkg
   rm LTechAgent.zip
   echo Done.
fi
