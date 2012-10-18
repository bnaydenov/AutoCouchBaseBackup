#! /bin/bash
# AutoCouchBaseBackup 2.0 Backup Script
# VER. 0.1
# Author: Bogdan Naydenov bnaydenov@gmail.com

# Note, this is a lobotomized port of AutoMySQLBackup
# (http://sourceforge.net/projects/automysqlbackup/) for backup
# Couchbase 2.0.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
#
#=====================================================================
#=====================================================================
# Set the following variables to your system needs
# (Detailed instructions below variables)
#=====================================================================


# Version of this script
VER='0.1'

# Path to couchbase bin directory where cbbackup is located
PATHTOCOUCHBASEBIN="/opt/couchbase/bin"

# Host name (or IP address) of couchbase server e.g localhost or IP like 127.0.0.1
HOST='127.0.0.1'

# Port that couchbase is listening on
PORT='8091'

# Username to access the couchbase server e.g. dbuser
USERNAME='admin'

# Password to access the couchbase server e.g. password
PASSWORD='p@ss0rd'

# Backup root directory
BACKUPDIR='/backups'

DATE=`date +%Y-%m-%d_%Hh%Mm`                      # Datestamp e.g 2002-09-21
DOW=`date +%A`                                    # Day of the week e.g. Monday
DNOW=`date +%u`                                   # Day number of the week 1 to 7 where 1 represents Monday
DOM=`date +%d`                                    # Date of the Month e.g. 27
M=`date +%B`                                      # Month e.g January
W=`date +%V`                                      # Week Number e.g 37

OPT=""                                            # OPT string for use with cbbackup



# ============================================================
# === ADVANCED OPTIONS ( Read the doc's below for details )===
#=============================================================

# Which day do you want weekly backups? (1 to 7 where 1 is Monday)
DOWEEKLY=6

# Choose Compression type. (gzip or bzip2)
COMP="gzip"

# Choose if the uncompressed folder should be deleted after compression has completed
CLEANUP="yes"

# Additionally keep a copy of the most recent backup in a seperate directory.
LATEST="yes"

# Make Hardlink not a copy
LATESTLINK="yes"


# Command to run before backups (uncomment to use)
# PREBACKUP=""

# Command run after backups (uncomment to use)
# POSTBACKUP=""


#=====================================================================
# Options documentation
#=====================================================================
#
# Set the HOST option to the some server in couchbase cluster you wish to backup. 
# Other clusters nodes will be discovered automaticly
# 
# You can change the backup storage location from /backups to anything
# you like by using the BACKUPDIR setting..
#
# Finally copy autocouchbasebackup.sh to anywhere on your server and make sure
# to set executable permission. You can also copy the script to
# /etc/cron.daily to have it execute automatically every night or simply
# place a symlink in /etc/cron.daily to the file if you wish to keep it
# somwhere else.
#
# NOTE: On Debian copy the file with no extention for it to be run
# by cron e.g just name the file "autocouchbasebackup"
#
# Thats it..
#
#
# === Advanced options ===
#
# To set the day of the week that you would like the weekly backup to happen
# set the DOWEEKLY setting, this can be a value from 1 to 7 where 1 is Monday,
# The default is 6 which means that weekly backups are done on a Saturday.
#
# Use PREBACKUP and POSTBACKUP to specify Pre and Post backup commands
# or scripts to perform tasks either before or after the backup process.
#
#
#=====================================================================
# Backup Rotation..
#=====================================================================
#
# Daily Backups are rotated weekly.
#
# Weekly Backups are run by default on Saturday Morning when
# cron.daily scripts are run. This can be changed with DOWEEKLY setting.
#
# Weekly Backups are rotated on a 5 week cycle.
# Monthly Backups are run on the 1st of the month.
# Monthly Backups are NOT rotated automatically.
#
# It may be a good idea to copy Monthly backups offline or to another
# server.
#
#=====================================================================
# Please Note!!
#=====================================================================
#
# I take no resposibility for any data loss or corruption when using
# this script.
#
# This script will not help in the event of a hard drive crash. You
# should copy your backups offline or to another PC for best protection.
#
# Happy backing up!
#
#=====================================================================
# Restoring
#=====================================================================
# TODO
#=====================================================================
# Change Log
#=====================================================================
# VER 0.1 - (2012-10-18)
# - Initial Release -  basic backup functionality with daily, weekly 
# and monthly rotation. Backup all bucket on all nodes   

#=====================================================================
#=====================================================================
#=====================================================================
#
# Should not need to be modified from here down!!
#
#=====================================================================
#=====================================================================
#=====================================================================

shellout () {
    if [ -n "$1" ]; then
        echo $1
        exit 1
    fi
    exit 0
}


# Do we need to use a username/password?
if [ "$USERNAME" ]; then
 OPT="$OPT -u $USERNAME -p $PASSWORD"
fi



# Create required directories
mkdir -p $BACKUPDIR/daily || shellout 'failed to create directories'
mkdir -p $BACKUPDIR/weekly || shellout 'failed to create directories'
mkdir -p $BACKUPDIR/monthly || shellout 'failed to create directories'

if [ "$LATEST" = "yes" ]; then
    rm -rf "$BACKUPDIR/latest"
    mkdir -p "$BACKUPDIR/latest" || shellout 'failed to create directory'
fi


# Check for correct sed usage
if [ $(uname -s) = 'Darwin' -o $(uname -s) = 'FreeBSD' ]; then
    SED="sed -i ''"
else
    SED="sed -i"
fi


# Functions

# Database dump function
dbdump () {
    mkdir -p $1
    $PATHTOCOUCHBASEBIN/cbbackup http://$HOST:$PORT $1 $OPT
    return 0
}


# Compression function plus latest copy
compression () {
    SUFFIX=""
    dir=$(dirname $1)
    file=$(basename $1)
    if [ -n "$COMP" ]; then
        [ "$COMP" = "gzip" ] && SUFFIX=".tgz"
        [ "$COMP" = "bzip2" ] && SUFFIX=".tar.bz2"
        echo Tar and $COMP to "$file$SUFFIX"
        cd "$dir" && tar -cf - "$file" | $COMP -c > "$file$SUFFIX"
        cd - >/dev/null || return 1
    else
        echo "No compression option set, check advanced settings"
    fi

    if [ "$LATEST" = "yes" ]; then
        if [ "$LATESTLINK" = "yes" ];then
            COPY="ln"
        else
            COPY="cp"
        fi
        $COPY "$1$SUFFIX" "$BACKUPDIR/latest/"
    fi

    if [ "$CLEANUP" = "yes" ]; then
        echo Cleaning up folder at "$1"
        rm -rf "$1"
    fi

    return 0
}

# Run command before we begin
if [ "$PREBACKUP" ]; then
    echo ======================================================================
    echo "Prebackup command output."
    echo
    eval $PREBACKUP
    echo
    echo ======================================================================
    echo
fi

echo ======================================================================
echo AutoCouchbaseBackup VER $VER
echo
echo Backup of Couchbase Database Server - on $HOST in $BACKUPDIR
echo ======================================================================
echo Backup Start `date`
echo ======================================================================

# Monthly Full Backup of all Databases
if [ $DOM = "01" ]; then
    echo Monthly Full Backup
    FILE="$BACKUPDIR/monthly/$DATE.$M"

# Weekly Backup
elif [ $DNOW = $DOWEEKLY ]; then
    echo Weekly Backup
    echo
    echo Rotating 5 weeks Backups...
    if [ "$W" -le 05 ]; then
        REMW=`expr 48 + $W`
    elif [ "$W" -lt 15 ]; then
        REMW=0`expr $W - 5`
    else
        REMW=`expr $W - 5`
    fi
    rm -f $BACKUPDIR/weekly/week.$REMW.*
    echo
    FILE="$BACKUPDIR/weekly/week.$W.$DATE"

# Daily Backup
else
    echo Daily Backup of Databases
    echo Rotating last weeks Backup...
    echo
    rm -f $BACKUPDIR/daily/*.$DOW.*
    echo
    FILE="$BACKUPDIR/daily/$DATE.$DOW"
fi

dbdump $FILE && compression $FILE
#dbdump $FILE

echo ----------------------------------------------------------------------
echo Backup End Time `date`
echo ======================================================================

echo Total disk space used for backup storage..
echo Size - Location
echo `du -hs "$BACKUPDIR"`
echo
echo ======================================================================

# Run command when we're done
if [ "$POSTBACKUP" ]; then
    echo ======================================================================
    echo "Postbackup command output."
    echo
    eval $POSTBACKUP
    echo
    echo ======================================================================
fi

