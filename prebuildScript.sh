#!/bin/bash

BUILD_CONFIG_PATH="./BuildConfig"
COMMIT_HITORY_FILE_PATH="$BUILD_CONFIG_PATH/submoduleCommitHistory.plist"
MAILRECEPIENTS_FILE_PATH="../BuildConfig/mailRecipients.plist"
MAIL_SENT_TIME_PATH="../BuildConfig/mailSentTimeDetail.plist"
flag=0
#$1 is the submodule name
#$2 is the current branch that submodule is keeping track of


git fetch
git checkout origin/master -- "$BUILD_CONFIG_PATH/submoduleCommitHistory.plist"

mailToDeveloper() {
declare -a FILE_ARRAY1=($(/usr/libexec/PlistBuddy -c "Print" "$MAILRECEPIENTS_FILE_PATH" | sed -e 1d -e '$d'))
osascript <<EOF
tell application "Mail"

set theSubject to "Commit revision not up to date"
set theContent to "There is mismatch in the commit revision pointed by $2 and main branch of $1 repository"
set theAddress to "babitha.shetty@globaldelight.com"
#set theAddress1 to "shikshan.chandrashekar@globaldelight.com"
#set theAddress2 to "anushree@globaldelight.com"
#set theNewAddress to "deepa.pai@globaldelight.com"
#set theAttachmentFile to "$1"

set msg to make new outgoing message with properties {subject:theSubject, content:theContent, visible:true}

set receipientList to the paragraphs of "$(printf '%s\n' "${FILE_ARRAY1[@]}")"

repeat with receipient in receipientList
tell msg to make new to recipient at end of every to recipient with properties {address: receipient}
end repeat

delay 3
send msg
end tell
EOF
}


#list the submodule under main repository
IFS=$'\n'
submoduleList=($(git submodule | awk '{ print $2 }'))
unset IFS

#list the submodule repo path from .gitmodules file
IFS=$'\n'
submodulePathList=($(git config --file .gitmodules --get-regexp url | awk '{print $2}'))
unset IFS

#check if submodule is already checked out or no, if not checkout to the specific branch that you want to keep track of
if ! [ "$(ls -A ${submoduleList[0]})" ]; then
    echo "submodule is not checked out"
     git submodule update --init --recursive
     cd ./${submoduleList[$each]}
     git checkout development
     cd ..

#check if submoduleCommitHistory.plist file exists or no
#if not create the file
    if [ -f "$COMMIT_HITORY_FILE_PATH" ]; then
        echo "$COMMIT_HITORY_FILE_PATH found."
    else
        echo "$COMMIT_HITORY_FILE_PATH not found."
cat > $BUILD_CONFIG_PATH/submoduleCommitHistory.plist <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict/>
</plist>
EOF
    fi
            
#check if mailSentTimeDetail.plist file exists or no
#if not create the file
    if [ -f "$MAIL_SENT_TIME_PATH" ]; then
        echo "$MAIL_SENT_TIME_PATH found."
    else
        echo "$MAIL_SENT_TIME_PATH not found."
cat > $BUILD_CONFIG_PATH/mailSentTimeDetail.plist <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict/>
</plist>
EOF
    fi
fi
echo "submodule is already checked out"

#check the current working branch of each of the submodule
for each in "${!submoduleList[@]}"
    do
        cd ./${submoduleList[$each]}
        git checkout development
        submoduleBranch=($(git symbolic-ref --short HEAD))
        
#get the commit revision of both master branch and developement branch of the submodule repository
        repoCurrentBranchRevision=($(git ls-remote ${submodulePathList[$each]} refs/heads/$submoduleBranch | awk '{print $1}'))
        repoMainBranchRevision=($(git ls-remote ${submodulePathList[$each]} refs/heads/main | awk '{print $1}'))
        
#check if the master branch commit revision and development branch commit revision are equal if not then trigger a mail to the admin
        if [ "$repoCurrentBranchRevision" == "$repoMainBranchRevision" ]; then
            echo "The $submoduleBranch branch of ${submoduleList[$each]} repo is up to date with the main branch"
        else
            echo "The $submoduleBranch branch of ${submoduleList[$each]} repo is not up to date with the main branch"
            
#get the time at which the mail was sent from the submoduleCommitHistory.plist file
        key="Time"
        val=$( /usr/libexec/PlistBuddy -c "Print $key" "$MAIL_SENT_TIME_PATH" )
        eval "export $key='$val'"
#check if the file does not contain the time the mail sent
#this condition will be true only at the time the plist file was created initially
        if [ -z "$val" ]; then
            current_time=$(date +%s)
#trigger a mail
            mailToDeveloper "${submoduleList[$each]}" "$submoduleBranch"
            plutil -replace "$key" -string "$current_time" "$MAIL_SENT_TIME_PATH"
        else
#otherwise get the current time and check if the time at which mail sent was 20 hrs ago, if true then send mail again
            current_time=$(date +%s)
            time_diff=$(( current_time - val))
            hours=$((time_diff/3600))
            if [ $hours -gt 20 ]; then
#trigger a mail to the admin about the mismatch in the commit revision
                mailToDeveloper "${submoduleList[$each]}" "$submoduleBranch"
                plutil -replace "$key" -string "$current_time" "$MAIL_SENT_TIME_PATH"
                flag=1
            fi
        fi
fi

COMMIT_HITORY_FILE_PATH="../BuildConfig/submoduleCommitHistory.plist"
submoduleName="${submoduleList[$each]}"

#get the commit revision value from the plist file for particular submodule
val=$( /usr/libexec/PlistBuddy -c "Print $submoduleName" "$COMMIT_HITORY_FILE_PATH" )
eval "export $submoduleName='$val'"

#check if the commit revision value is stored in the plist file
if [ -z "$val" ]; then
    echo "commit revision of the latest built framework is not present in the plist file"
    
#if not get the latest commit revision id that the submodule is pointing to
    submoduleCurrentBranchRevision=($(git rev-parse @))
    plutil -insert "$submoduleName" -string "$submoduleCurrentBranchRevision" "$COMMIT_HITORY_FILE_PATH"
else
    echo "plist file has the latest commit revision value that is used to build the framework"
    submoduleCurrentBranchRevision="$val"
fi
        
#check if the commit revision of the current branch in the submodule of the main repo and in the submoule repo are same
        if [ "$repoCurrentBranchRevision" == "$submoduleCurrentBranchRevision" ]; then
            echo "Your submodule is up to date"
                
        else
#if not display a dialog asking the user to pull the latest commit to the submodule
            buttonResult="$(osascript -e 'display dialog "Your submodule is not up to date. Do you ant to pull the changes?" buttons {"Yes", "No"}')"
            if [ "$buttonResult" = "button returned:Yes" ]; then
                echo "Yes, continue with partition."
                    git pull
# once the changes is pulled to your system replace the old commit revision id with the new one using which your framework was built
                    submoduleLatestCommitRevision=($(git rev-parse @))
                    plutil -replace "$submoduleName" -string "$submoduleLatestCommitRevision" "$COMMIT_HITORY_FILE_PATH"
                else
                    echo "No, cancel pull."
                fi
            fi
        cd ..
done
if [ flag -eq 1 ]; then
    echo "changed!!"
    git add "$BUILD_CONFIG_PATH/mailSentTimeDetail.plist"
    git commit -m "updated mail sent file"
    git push origin main
else
    echo "not changed!!"
    
fi
    

