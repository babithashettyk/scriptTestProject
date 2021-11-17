#!/bin/bash
#brew install jq
BUILD_CONFIG_PATH="./BuildConfig"
file="$BUILD_CONFIG_PATH/submoduleCommitHistory.plist"
file1="../BuildConfig/mailRecipients.plist"

#$1 is the submodule name
#$2 is the current branch that submodule is keeping track of
mailToDeveloper() {
declare -a FILE_ARRAY1=($(/usr/libexec/PlistBuddy -c "Print" "$file1" | sed -e 1d -e '$d'))
#echo "plist content:$FILE_ARRAY1"
#FILE_ARRAY1=("babitha.shetty@globaldelight.com")
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
    if [ -f "$file" ]; then
        echo "$file found."
    else
        echo "$file not found."
cat > $BUILD_CONFIG_PATH/submoduleCommitHistory.plist <<EOF
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
            #trigger a mail to the admin about the mismatch in the commit revision
            mailToDeveloper "${submoduleList[$each]}" "$submoduleBranch"
        fi

file="../BuildConfig/submoduleCommitHistory.plist"
submoduleName="${submoduleList[$each]}"
val=$( /usr/libexec/PlistBuddy -c "Print $submoduleName" "$file" )
eval "export $submoduleName='$val'"
if [ -z "$val" ]; then
    echo "null"
    submoduleCurrentBranchRevision=($(git rev-parse @))
    plutil -insert "$submoduleName" -string "$submoduleCurrentBranchRevision" "$file"
else
    echo "not"
    submoduleCurrentBranchRevision="$val"
fi

#get the latest commit revision that the submodule is pointing to
        
#check if the commit revision of the current branch in the submodule of the main repo and in the submoule repo are same
        if [ "$repoCurrentBranchRevision" == "$submoduleCurrentBranchRevision" ]; then
            echo "Your submodule is up to date"
                
        else
#if not display a dialog asking the user to pull the latest commit to the submodule
            buttonResult="$(osascript -e 'display dialog "Your submodule is not up to date. Do you ant to pull the changes?" buttons {"Yes", "No"}')"
            if [ "$buttonResult" = "button returned:Yes" ]; then
                echo "Yes, continue with partition."
                    git pull
                    submoduleLatestCommitRevision=($(git rev-parse @))
                    plutil -replace "$submoduleName" -string "$submoduleLatestCommitRevision" "$file"
                else
                    echo "No, cancel pull."
                fi
            fi
        cd ..
done


