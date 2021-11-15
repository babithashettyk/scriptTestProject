#!/bin/bash

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
else
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
        fi
        
#get the latest commit revision that the submodule is pointing to
        submoduleCurrentBranchRevision=($(git rev-parse @))
        

        if [ "$repoCurrentBranchRevision" == "$submoduleCurrentBranchRevision" ]; then
            echo "Your submodule is up to date"
                    
        else
            buttonResult="$(osascript -e 'display dialog "Your submodule is not up to date. Do you ant to pull the changes?" buttons {"Yes", "No"}')"
            if [ "$buttonResult" = "button returned:Yes" ]; then
                echo "Yes, continue with partition."
                    git pull --all
                else
                    echo "No, cancel pull."
                fi
            fi
        cd ..
    done

fi
