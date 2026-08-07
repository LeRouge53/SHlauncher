function list() {
    if [ "$(ls)" == "" ]; then
        printf "${YELLOW}No Instances were set up (yet!)${RESET}\n"
    else
        for Finst in *.json; do
            IFS='|' read -r name version modloader gameDir java MinRam MaxRam modloaderVersion <<< "$(jq -r '"\(.name)|\(.version)|\(.modloader)|\(.gameDir)|\(.java)|\(.MinRam)|\(.MaxRam)|\(.modloaderVersion)"' "$Finst")"
            mapfile -t additionalJvmArgs < <(jq -r '.additionalJvmArgs[]' "$Finst")
            mapfile -t customGameArgs < <(jq -r '.customGameArgs[]' "$Finst")

            printf "${BLUE}%s :${RESET}\n" "$name"
            echo " - Version: $version" 
            echo " - Modloader: $modloader $modloaderVersion"
            echo " - Game directory: $gameDir"
            echo " - Java: $java"
            echo " - Minimal ammount of RAM (-Xms): $MinRam"
            echo " - Maximal ammount of RAM (-Xmx): $MaxRam"
            echo " - Additionnal JVM arguments : " "${additionalJvmArgs[@]}"
            echo " - Additionnal game arguments : " "${customGameArgs[@]}"
        done
    fi
}

function SetColor() {
    if [ "$instance" == "None" ]; then \
        DispInst="${RL_START}${RED}${RL_END}${instance}${RL_START}${RESET}${RL_END}"
    else
        DispInst="${RL_START}${GREEN}${RL_END}${instance}${RL_START}${RESET}${RL_END}"
    fi
}


function hp() {
    true
}

function create() {
    name=$1
    modloader=$2
    version=$3
    modloaderVersion=$4

    case $1 in
        "-a" | "--anotherGameDir")
            anotherGameDir=true
            customGameDir=""
            shift
            create "$@"
            return
        ;;
        "-c" | "--customGameDir")
            if [ "$2" == "" ]; then
                printf "${RED_BOLD}-c require another argument (a path to the game directory)${RESET}\n"
                return 1
            fi
            customGameDir="$2"
            anotherGameDir=false
            shift 2
            create "$@"
            return
        ;;
        *)
            true
    esac

    # shellcheck disable=SC2194
    case "" in
        "$name" | "$modloader" | "$version")
        printf "${RED_BOLD}One or more argument were forgotten, this command require at least a name, a modloader (can be vanilla), and a minecraft version${RESET}\n"
        return 1
    esac

    if [[ -f "./$name.json" ]]; then
        printf "${RED_BOLD}The target instance already exist${RESET}\n"
        return 1
    fi

    if [ "$name" == "None" ]; then
        printf "${RED_BOLD}The name of this instance can't be \"None\", please use another name${RESET}\n"
        return 1
    fi

    case $modloader in
        "vanilla" | "Vanilla")
            modloader="vanilla"
        ;;
        "forge" | "Forge")
            modloader="forge"
            if [ "$modloaderVersion" == "" ]; then
                printf "${RED_BOLD}The modloader version is mandatory for this modloader, please specify a modloader version and retry${RESET}\n"
            fi
        ;;
        "neoforge" | "Neoforge" | "NeoForge" | "neoForge")
            modloader="neoforge"
            if [ "$modloaderVersion" == "" ]; then
                printf "${RED_BOLD}The modloader version is mandatory for this modloader, please specify a modloader version and retry${RESET}\n"
            fi
            if ! [[ "$modloaderVersion" =~ \. ]]; then
                # shellcheck disable=SC2001 # nah
                trunkMcVers=$(echo "$version" | sed 's/^1\.//')
                fullModLoaderVers="${trunkMcVers}.${modloaderVersion}"
            else
                fullModLoaderVers=$modloaderVersion
            fi
        ;;
        "fabric" | "Fabric")
            modloader="fabric"
            if [ "$modloaderVersion" == "" ]; then
                printf "${RED_BOLD}The modloader version is mandatory for this modloader, please specify a modloader version and retry${RESET}\n"
            fi
        ;;
        "quilt" | "Quilt")
            modloader="quilt"
            if [ "$modloaderVersion" == "" ]; then
                printf "${RED_BOLD}The modloader version is mandatory for this modloader, please specify a modloader version and retry${RESET}\n"
            fi
        ;;
        *)
            printf "${RED_BOLD}Uknown modloader \"%s\", supported modloaders are Vanilla, Forge, NeoForge, Fabric and Quilt${RESET}\n" "$modloader"
            return 1
    esac

    echo "creating instance $name with modloader $modloader and version $version $modloaderVersion"
    if [ "$modloader" == "vanilla" ]; then
        versionProfile="$version"
    else
        versionProfile="$modloader-$fullModLoaderVers"
    fi

    if $anotherGameDir; then
        # shellcheck disable=SC2154 # il l'est
        gameDir="$dir/.minecraft/instances/$name/"
        mkdir -p "$gameDir"
    elif [ "$customGameDir" != "" ]; then
        gameDir="$customGameDir"
    else
        # shellcheck disable=SC2154
        gameDir="$dir/.minecraft/"
    fi
    
    jq -n \
        --arg name "$name" \
        --arg modloader "$modloader" \
        --arg version "$version" \
        --arg modloaderVersion "$modloaderVersion" \
        --arg gameDir "$gameDir" \
        --arg assetsDir "$dir/.minecraft/assets" \
        --arg java "default" \
        --arg MinRam "2G" \
        --arg MaxRam "4G" \
        --arg versionProfile "$versionProfile" \
        '{
            "name": $name,
            "modloader": $modloader,
            "version": $version,
            "modloaderVersion": $modloaderVersion,
            "versionProfile": $versionProfile,
            "gameDir": $gameDir,
            "assetsDir": $assetsDir,
            "java": $java,
            "MinRam": $MinRam,
            "MaxRam": $MaxRam,
            "additionalJvmArgs": [],
            "customGameArgs": [],
            "selected": false
        }' \
        > "$name".json
}

function sel() {
    name=$1
    if ! [[ -f "$name.json" ]]; then echo "The selected Instance \"$name\" does not exist"; return 1; fi
    if [ "$instance" == "None" ]; then
        instance=$name
        contents="$(jq '.selected = true' "$instance.json")" && echo -E "${contents}" > "$instance.json"
        SetColor
    else
        contents="$(jq '.selected = false' "$instance.json")" && echo -E "${contents}" > "$instance.json"
        instance=$name
        contents="$(jq '.selected = true' "$instance.json")" && echo -E "${contents}" > "$instance.json"
        SetColor
    fi
}

function delete() {
    name=$1
    if ! [[ -f "$name".json ]]; then echo "The selected Instance \"$name\" does not exist"; return 1; fi
    command -p rm -- "$name.json"
    if [ "$instance" == "$name" ]; then
        instance="None"
    fi
    SetColor
}

function reset() {
    for Finst in *.json; do
        contents="$(jq '.selected = false' "$Finst")" && echo -E "${contents}" > "$Finst"
    done
    instance="None"
    SetColor
}

function Main() {
    case $1 in
        "create")
            shift 
            create "$@"
        ;;
        "remove" | "delete")
            shift
            delete "$@"
        ;;
        "list")
            list
        ;;
        "reset")
            reset
        ;;
        "select" | "switch")
            shift
            sel "$@"
        ;;
        "")
            echo "No argument given, assuming \"list\""
            list
        ;;
        *)
            echo "Unregonized argument: $1"
    esac
}

# shellcheck disable=SC2154
mkdir -p "$dir/.minecraft/SHlauncher/instances"
mkdir -p "$dir/.minecraft/instances"
cd "$dir/.minecraft/SHlauncher/instances" || return 1
customGameDir=""
anotherGameDir=false
Main "$@"