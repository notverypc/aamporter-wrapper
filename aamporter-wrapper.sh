#!/bin/sh

# This script is completely based on the work Sean Kasier did for AutoPkg Notifications.
# Apart from changing a few commands I've added nothing else to the script.
# Sean's orginal work can be found here: http://seankaiser.com/blog/2013/12/16/autopkg-change-notifications/ 
# and here: https://github.com/seankaiser/automation-scripts/tree/master/autopkg

# aamporter automation script which, when run with no arguments, checks current run's output against a default output and sends the output to a user if there are differences

# adjust the following variables for your particular configuration
# you should manually run the script with the initialize option if you change the recipe list, since that will change the output.

product_list="YourProductList.plist"
product_path="PathToYourProductList"
mail_recipient="WhoToEmail"
aamporter_user="aamporterUser"
aamporter_path="Pathto/aamporter.py"


# don't change anything below this line

# define logger behavior
logger="/usr/bin/logger -t aamporter-wrapper"
user_home_dir=`dscl . -read /Users/${aamporter_user} NFSHomeDirectory | awk '{ print $2 }'`

# run aamporter
if [ "${1}" == "help" ]; then
  # show some help with regards to initialization option
  echo "usage: ${0} [initialize]"
  echo "(initializes a new default log for notification checking)"
  exit 0

elif [ "${1}" == "initialize" ]; then
  # initialize default log for automated run to check against for notification if things have changed
  $logger "starting aamporter to initialize a new default output log"

  echo "recipe list: ${product_list}"
  echo "aamporter user: ${aamporter_user}"
  echo "user home dir: ${user_home_dir}"

  # make sure aamporter folder exists in aamporter_user's Documents folder
  if [ ! -d "${user_home_dir}"/Documents/aamporter ]; then
    /bin/mkdir -p "${user_home_dir}"/Documents/aamporter
  fi

  # run aamporter twice, once to get any updates and the second to get a log indicating nothing changed
  $logger "aamporter initial run to temporary log location"
  echo "for this aamporter run, output will be shown"
  ${aamporter_path} -v ${product_path}/${product_list} --munkiimport 2>&1

  $logger "aamporter initial run to saved log location"
  echo "for this aamporter run, output will not be shown, but rather saved to default log location (${user_home_dir}/Documents/aamporter/aamporter.out"
  ${aamporter_path} -p ${product_path}/${product_list} --munkiimport 2>&1 > "${user_home_dir}"/Documents/aamporter/aamporter.out
  $logger "finished aamporter"

elif [ ! -f "${user_home_dir}"/Documents/aamporter/aamporter.out ]; then
  # default log doesn't exist, so tell user to run this script in initialization mode and exit
  echo "ERROR: default log does not exist, please run this script with initialize argument to initialize the log"
  exit -1

else
  # default is to just run aamporter and email log if something changed from normal
  $logger "starting aamporter"
  ${aamporter_path} -p ${product_path}/${product_list} --munkiimport 2>&1 > /tmp/aamporter.out

  $logger "finished aamporter"

  # check output against the saved log and if differences exist, send current log to specified recipient
  if [ "`diff /tmp/aamporter.out \"${user_home_dir}\"/Documents/aamporter/aamporter.out`" != "" ]; then
    # there are differences from a "Nothing downloaded, packaged or imported" run... might be an update or an error
    $logger "sending aamporter log"
    /usr/bin/mail -s "aamporter log" ${mail_recipient}  < /tmp/aamporter.out
    $logger "sent aamporter log to {$mail_recipient}, `wc -l /tmp/aamporter.out | awk '{ print $1 }'` lines in log"
  else
    $logger "aamporter did nothing, so not sending log"
  fi
fi
exit 0

