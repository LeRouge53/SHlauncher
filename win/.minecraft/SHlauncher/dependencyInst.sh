
if $DEP_FAILED; then
    printf "${RED}[FATAL] Failed to lauch : The following dependency(ies) are missing :${RESET}\n"

    if $JQ_NOT_INSTALLED; then 
        echo "jq : JSON shell interpretor"
        read -rp "Would you like to install jq automatically ?(y/n)>" yn
    fi
    if [ "$yn" == "y" ]; then
        if $ONLINE_MODE; then
            winget.exe install --id jqlang.jq
        else
            echo "[ERROR] Can't install, You are in offline mode"
        fi
    else
        echo "aborting autoinstall"
    fi
    set +x
    exit 1
fi