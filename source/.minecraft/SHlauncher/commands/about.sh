# shellcheck disable=SC2154

function about() {
	printf "${BLUE}SHlauncher${RESET}, created by LeRouge53\n"
	printf "${BLUE}Git repository${RESET}: https://github.com/leRouge53/SHlauncher\n"
	printf "${BLUE}license${RESET}: GPL v3.0 (https://www.gnu.org/licenses/gpl-3.0.html)\n"
	printf "Thanks you for using this launcher\n"

	if ${parameter[showDeathThreats]}; then
		printf "\n${RED_BOLD}I am railcoining anyone that says this launcher has any connection to SKlauncher.\nD O N T${RESET}\n"
	fi
}

function getStarted() {
	cat << EOF | less -R
${BLUE}This guide uses the "less" command, quit at any time using "q"${RESET}

Welcome and thank you for using SHlauncher. This short guide will explain to you 
how to launch the game and how to optimize the launch of the game.


 ${GREEN_BOLD}${GREEN_UNDER}- Preparation :${RESET}
${BLUE_BOLD}This part will introduce you to the launcher or to a terminal in general.${RESET}

This launcher uses a custom shell to get and analyze commands entered commands.
Although a command usually looks like this, 

	${WHITE_UNDER}instance create -a test neoforge 1.21.1 244${RESET}

It is actually separated in 3 parts :
	- ${WHITE_BOLD}the command name (here "instance")
	- ${WHITE_BOLD}the parameters (-a here, but everything that start with a dash or a double dash)
	- ${WHITE_BOLD}the instructions (rest of the commands)
It is important because the command name NEEDS to be in 1st, the instructions usually follows a
precise order but the parameters can be placed anywhere after the command name, even between instructions.

The available command are : 
	- ${CYAN_BOLD}Primary commands (required to be executed once to be able to launch the game) : 
		- ${WHITE_BOLD}profile ${RESET}: manages the user's profiles (will be explained later)
		- ${WHITE_BOLD}version ${RESET}: manages the version installed, and install new ones
		- ${WHITE_BOLD}instance ${RESET}: manages the instances (will also be explained later)
		- ${WHITE_BOLD}java ${RESET}: manages the java installations
		- ${WHITE_BOLD}launch ${RESET}: launches the game
	- ${CYAN_BOLD}Secondary commands (important, but not required commands) :
		- ${WHITE_BOLD}settings ${RESET}: manages the launcher's settings
		- ${WHITE_BOLD}opendir ${RESET}: open the directory linked the selected instance
		- ${WHITE_BOLD}about ${RESET}: get information about the launcher
		- ${WHITE_BOLD}exit ${RESET}: shut down the launcher
	- ${CYAN_BOLD}Others : 
		- ${WHITE_BOLD}clear ${RESET}: clear the terminal
		- ${WHITE_BOLD}reset ${RESET}: reset the launcher (closes and open back the launcher)
		- ${WHITE_BOLD}debug ${RESET}: same effect as reset, but enable debug mode
    - ${WHITE_BOLD}trace ${RESET}: same effect as reset, but enable trace 
		- ${WHITE_BOLD}echo ${RESET}: print()
And please note that the majority of those commands have an integrated help page available
when using "<command name> help".


With this custom shell, the launcher uses a selection system to avoid having to repeat the same
parameters over and over again. The selected profiles and instances are displayed on the
shell prompt directly like this : 

	SHlauncher ${CYAN}ProfileName${RESET}:${GREEN}InstanceName${RESET}>

if you did not selected anything, the profile or instance name will show up as "None" :

	SHlauncher ${RED}None${RESET}:${RED}None${RESET}>

To select a profile/instance ; you can use the respective command with the instruction "select"
and the name of the object like this : "> profile select test" (select a profile named test).

Please note that you don't have to use the selection system. You can precise the profile and instance name
at each command, but it can become repetitive


 ${GREEN_BOLD}${GREEN_UNDER}- Installing the game :${RESET}
${CYAN_BOLD}To be able to launch the game, you need multiple things to be prepared :${RESET}
	- ${WHITE_BOLD}A version of the game${RESET}
	- ${WHITE_BOLD}An instance representing this version${RESET}
	- ${WHITE_BOLD}A user profile${RESET}
	- ${WHITE_BOLD}A compatible java installation${RESET}

And this section will guide through getting all of that.

	${GREEN_UNDER}- Installing a version of the game${RESET}
 ${BLUE}1.${RESET} before everything, Use "version list" to display every version and pick one you like/recognize.
 ${BLUE}2.${RESET} Then install it using "version install 26.2" (if you chose 26.2) 
		${YELLOW} (IMPORTANT NOTE : installing a version with a modloader has a different syntax. Instead of
		${YELLOW} using "version install <version name>", use 
		${YELLOW} "version install <modloader> <vanilla version> <modloader version>". This syntax is compatible with
		${YELLOW} the vanilla game (without precising the modloader version because there isn't any) but using the
		${YELLOW} vanilla syntax to download a modded version will result in a crash or you downloading a wrong
		${YELLOW} version entirely !)
 ${BLUE}3.${RESET} You can confirm the installation succeeded by displaying it with "version list installed"

	${GREEN_UNDER}- Creating an instance${RESET}
An instance is an object made to represent a version of the game while providing more
information to the launcher. It also allows to use a customized game directory and other similar
stuffs without impacting other instances.
To create and use an an instance : 
 ${BLUE}1.${RESET} type in the shell "instance create" followed by the name of the instance, the modloader,
       the vanilla minecraft version and the modloader's version (if you are using anything other than vanilla)
	   (example command to use minecraft vanilla 26.2: "instance create test vanilla 26.2")
 ${BLUE}2.${RESET} after creating it, type "instance select" with the name of your instance to select it. It should appear
       in you shell prompt.

	${GREEN_UNDER}- Creating and using a profile${RESET}
A profile is an object relatively similar to an instance. But it is made to represent a player instead of a
version of the game. To create one : 
 ${BLUE}1.${RESET} Use the command "profile create" (or "profile auth" if you have minecraft premium)
       followed by a minecraft compatible username
 ${BLUE}2.${RESET} Then select it with "profile select" like an instance, The newly created profile should appear in
       your shell prompt
		${YELLOW} Please note that your username might be yellow and not cyan. It is used to easily check if you
		${YELLOW} have selected a cracked profile or a premium one

${WHITE_DIM}temporary note : profile auth (premium login) is not yet supported. So bruh${WHITE_DIM}

	${GREEN_UNDER}- Downloading java${RESET}
After preparing the game, the only thing left to do is to download java. To do that : 
 ${BLUE}1.${RESET} check which java is required for your version of the game using "version list installed" (for 26.2,
       the required java runtime is 25)
 ${BLUE}2.${RESET} after checking that, enter the command "java install" followed by the version (for the example, 25).

After doing this step, you should be able to launch the game using the "launch" command
EOF
}

function version() {
	# shellcheck disable=SC2154
	echo "$SHlname, version $SHlvers"
}

function testColor() {
	printf "${RED}RED${RESET}\n"
	printf "${RED_BOLD}RED_BOLD${RESET}\n"
	printf "${RED_DIM}RED_DIM${RESET}\n"
	printf "${RED_UNDER}RED_UNDER${RESET}\n\n"

	printf "${GREEN}GREEN${RESET}\n"
	printf "${GREEN_BOLD}GREEN_BOLD${RESET}\n"
	printf "${GREEN_DIM}GREEN_DIM${RESET}\n"
	printf "${GREEN_UNDER}GREEN_UNDER${RESET}\n\n"

	printf "${YELLOW}YELLOW${RESET}\n"
	printf "${YELLOW_BOLD}YELLOW_BOLD${RESET}\n"
	printf "${YELLOW_DIM}YELLOW_DIM${RESET}\n"
	printf "${YELLOW_UNDER}YELLOW_UNDER${RESET}\n\n"

	printf "${BLUE}BLUE${RESET}\n"
	printf "${BLUE_BOLD}BLUE_BOLD${RESET}\n"
	printf "${BLUE_DIM}BLUE_DIM${RESET}\n"
	printf "${BLUE_UNDER}BLUE_UNDER${RESET}\n\n"

	printf "${CYAN}CYAN${RESET}\n"
	printf "${CYAN_BOLD}CYAN_BOLD${RESET}\n"
	printf "${CYAN_DIM}CYAN_DIM${RESET}\n"
	printf "${CYAN_UNDER}CYAN_UNDER${RESET}\n\n"

	printf "${WHITE}WHITE${RESET}\n"
	printf "${WHITE_BOLD}WHITE_BOLD${RESET}\n"
	printf "${WHITE_DIM}WHITE_DIM${RESET}\n"
	printf "${WHITE_UNDER}WHITE_UNDER${RESET}\n"
}

function helpPage() {
	printf "${CYAN}Usage :${RESET} about [<instruction>]\n"
	printf "A command that gives information about the launcher\n"
	printf "${CYAN}Argument list${RESET} :\n"
	printf " - get-started: Prints the get started page of SHlauncher\n"
	printf " - version: Show the version of the launcher\n"
	printf " - about (or nothing): Show useful information and links\n"
	printf " - help: Print this help\n"
}

function argHandler() {
	case $1 in
	"get-started")
		getStarted
	;;
	"version")
		version
	;;
	"test-color")
		testColor
	;;
	"" | "about")
		about
	;;
	"help")
		helpPage
	;;
	*)
		printf "${RED_BOLD}Unknown argument : %s${RESET}\n" "$1"
	esac
}

log "INFO" "about.sh" "settings.sh called with instructions ${instructions[*]}"

parameter[showDeathThreats]=false
declareArgs showDeathThreats NoShort flag

globalArgHandler "$@"

argHandler "${instructions[@]}"