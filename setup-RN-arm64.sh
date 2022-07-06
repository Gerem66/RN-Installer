#!/bin/bash
# Source:	https://github.com/Gerem66/RN-Installer

# Check privileges
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root"
    exit
fi

# Tags
RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NO_COLOR='\033[0m'
DTAG="${CYAN}[SETUP RN]${NO_COLOR}"	# Debug tag
STAG="${GREEN}[+]${NO_COLOR}"		# Success tag
ETAG="${RED}[-]${NO_COLOR}"		# Error tag

# Versions
BUCK_JAVA_VERSION=11
CMAKE_VERSION=3.18.1
NDK_VERSION=r23
ANDROID_BUILD_VERSION=31
ANDROID_TOOLS_VERSION=30.0.3
SDK_VERSION=commandlinetools-linux-8512546_latest.zip
NODE_VERSION=16.x


# If contains one message, it will be shown if last command failed
# If contains two messages, first will be shown if last command success, and second if it failed
Result_msg() {
    RESULT=$?
    if [ $# -eq 1 ]; then
        if [ $RESULT -ne 0 ]; then
            echo -e "$ETAG $1"
            [ $UNSAFE -eq 0 ] && exit 1
        fi
    elif [ $# -eq 2 ]; then
        if [ $RESULT -eq 0 ]; then
            echo -e "$STAG $1"
        else
            echo -e "$ETAG $2"
            [ $UNSAFE -eq 0 ] && exit 1
        fi
    fi
}

Debug_msg() {
    echo -e "$DTAG $1"
}

Print_help() {
    echo -e "Install react native context:"
    echo -e "\t- Update and install system packages (with apt-get)"
    echo -e "\t- Install buck"
    echo -e "\t- Install Android SDK/NDK"
    echo -e "\t- Configure React Native (bash or zsh, automatically)\n"
    echo -e "Usage:\n\tsudo ${0} [ARGS]\n"

    echo -e "Arguments:"
    echo -e "\t -h | --help		Print this help message and exit"
    echo -e "\t -v | --versions 	Print all versions and exit"
    echo -e "\t -c | --clean		Only clean all installations and temporary files (skip apt-get commands)"
    echo -e "\t -d | --debug		Enable output commands"
    echo -e "\t -u | --unsafe		Not exit when errors occured (not recommended)"
    echo -e "\t-nu | --no-update	Disable system update before installation (not recommended)"
    echo -e "\t-np | --no-packages	Disable packages installation (git, python, curl, ant, ...)"
    echo -e "\t-nb | --no-buck		Disable buck installation (skip clean too)"
    echo -e "\t-nn | --no-node		Disable buck installation (skip clean too)"
    echo -e "\t-na | --no-android	Disable SDK/NDK installation (skip clean too)"
    echo -e "\t-nc | --no-config	Disable config settings (skip clean too)"
    exit 0
}

Print_versions() {
    VER_TXT="${CYAN}${BOLD}Package|Version|Source${NO_COLOR}\n"
    VER_TXT+="Buck|Latest|https://github.com/facebook/buck.git\n"
    VER_TXT+="Buck Java|$BUCK_JAVA_VERSION|Buck\n"
    VER_TXT+="CMake|$CMAKE_VERSION|sdkmanager\n"
    VER_TXT+="JDK|$SDK_VERSION|https://dl.google.com/android/repository/\n"
    VER_TXT+="NDK|$NDK_VERSION|sdkmanager\n"
    VER_TXT+="Android build|$ANDROID_BUILD_VERSION|sdkmanager\n"
    VER_TXT+="Android tools|$ANDROID_TOOLS_VERSION|sdkmanager\n"
    VER_TXT+="npm|Latest|apt-get\n"
    VER_TXT+="react-native|Latest|npm\n"
    VER_TXT+="Node|$NODE_VERSION|https://deb.nodesource.com/setup_${NODE_VERSION}"

    echo -e "$VER_TXT" | column -t -s "|" -c 50
    exit 0
}

# Arguments
CLEAN=0			# Only clean
DEBUG=0			# Debug mode, to show commands output
OUT='/dev/null'		# Output: /dev/stdout or /dev/null
UNSAFE=0		# Unsafe mode, not quit when errors occured
INSTALL_UPDATE=1
INSTALL_PKGS=1
INSTALL_BUCK=1
INSTALL_NODE=1
INSTALL_ANDROID=1
INSTALL_CONFIG=1

for i in "$@"; do
    case $i in
        -h|--help)		Print_help ;;
        -v|--versions)		Print_versions ;;
        -c|--clean)		CLEAN=1; INSTALL_UPDATE=0; INSTALL_PKGS=0 ;;
        -d|--debug)		DEBUG=1; OUT='/dev/stdout' ;;
        -u|--unsafe)		UNSAFE=1 ;;
        -nu|--no-update)	INSTALL_UPDATE=0 ;;
        -np|--no-packages)	INSTALL_PKGS=0 ;;
        -nb|--no-buck)		INSTALL_BUCK=0 ;;
        -nn|--no-node)		INSTALL_NODE=0 ;;
        -na|--no-android)	INSTALL_ANDROID=0 ;;
        -nc|--no-config)	INSTALL_CONFIG=0 ;;
        *)			echo "Unknown option $i"; exit 1 ;;
    esac
done



echo -e "\n${DTAG} START SETUP\n"



if [ $INSTALL_UPDATE -eq 1 ]; then
    Debug_msg "> Update system packages"
    sudo apt-get update > $OUT; Result_msg "apt update failed!"
    sudo apt-get dist-upgrade -y > $OUT; Result_msg "Packages updated" "apt dist-upgrade failed!"
    sudo apt-get autoremove > $OUT; Result_msg "apt autoremove failed!"
fi

if [ $INSTALL_PKGS -eq 1 ]; then
    Debug_msg "> Install default packages"
    sudo apt-get install -y \
        adb \
        ant \
        git \
        gcc \
        g++ \
        nano \
        make \
        curl \
        cmake \
        unzip \
        nodejs \
        screen \
        watchman \
        sdkmanager \
        openjdk-11-jdk \
        openjdk-11-jre \
        android-tools-adb \
        python3 python3-distutils \
        > $OUT
    Result_msg "Packages installed" "Packages installation failed!"

    Debug_msg "Update npm and install react native"
    [ $DEBUG -eq 0 ] && SILENT='--silent' || SILENT=''
    npm install $SILENT -g npm
    npm install $SILENT -g react-native > $OUT
    Result_msg "React native installation failed!"
fi



if [ $INSTALL_BUCK -eq 1 ]; then
    Debug_msg "> Buck"
    export ANT_OPTS="-Xmx4096m"

    # Clean
    [ -d ./buck ] && ( sudo rm -R buck/; Result_msg "Buck folder package removed" "Buck folder can't be removed!" )
    [ -f /tmp/buck.pex ] && ( sudo rm /tmp/buck.pex; Result_msg "Buck .pex removed" "Buck .pex can't be removed!" )
    [ -f /usr/local/bin/buck ] && ( sudo rm /usr/local/bin/buck; Result_msg "Buck binary removed" "Buck binary can't be removed!" )

    if [ $CLEAN -eq 0 ]; then
        Debug_msg "Download buck"

        [ $DEBUG -eq 0 ] && QUIET='--quiet' || QUIET=''
        git clone $QUIET --depth 1 https://github.com/facebook/buck.git > $OUT; Result_msg "Buck download failed!"
        cd buck

        Debug_msg "Build buck"
        ant > $OUT; Result_msg "Ant build failed!"

        [ $DEBUG -eq 0 ] && VERBOSE=0 || VERBOSE=8
        ./bin/buck build buck \
            --config java.target_level=$BUCK_JAVA_VERSION \
            --config java.source_level=$BUCK_JAVA_VERSION \
            --out /tmp/buck.pex \
            --verbose $VERBOSE \
            > $OUT; Result_msg "Buck build failed!"
        sudo mv /tmp/buck.pex /usr/local/bin/buck; Result_msg "Move builded buck failed!"

        cd ..
        sudo rm -R buck/
        Result_msg "Buck successfully installed" "Remove buck failed"
    fi
fi



# Install node & yarn

if [ $INSTALL_NODE -eq 1 ]; then
    Debug_msg "> Node"

    # Clean
    #TODO - clean...

    if [ $CLEAN -eq 0 ]; then
        curl -sL https://deb.nodesource.com/setup_${NODE_VERSION} | bash - > $OUT
        Result_msg "Node downloading failed!"

        [ $DEBUG -eq 0 ] && VERBOSE='-qq' || VERBOSE=''
        apt-get update $QUIET > $OUT; Result_msg "Update packages failed!"
        apt-get install $QUIET -y nodejs > $OUT; Result_msg "NodeJS installation failed!"
        npm install -g yarn > $OUT; Result_msg "Npm: yarn installation failed!"

        #rm -rf /var/lib/apt/lists/* # Why ?
    fi
fi



# Install android SDK

if [ $INSTALL_ANDROID -eq 1 ]; then
    Debug_msg "> Android"

    ANDROID_HOME=/opt/android
    ANDROID_SDK=/opt/android-sdk
    ANDROID_NDK=${ANDROID_HOME}/ndk/$NDK_VERSION
    ANDROID_SDK_TEMP_ZIP=/tmp/sdk.zip

    # Clean
    [ -d ${ANDROID_HOME} ] && ( sudo rm -R ${ANDROID_HOME}; Result_msg "Android home \"${ANDROID_HOME}\" removed" "Android home \"${ANDROID_HOME}\" can't be removed!" )
    [ -d ${ANDROID_SDK} ] && ( sudo rm -R ${ANDROID_SDK}; Result_msg "Android SDK \"${ANDROID_SDK}\" removed" "Android SDK \"${ANDROID_SDK}\" can't be removed!" )
    [ -f ${ANDROID_SDK_TEMP_ZIP} ] && ( sudo rm ${ANDROID_SDK_TEMP_ZIP}; Result_msg "Temp file \"${ANDROID_SDK_TEMP_ZIP}\" removed" "Temp file \"${ANDROID_SDK_TEMP_ZIP}\" can't be removed!" )

    if [ $CLEAN -eq 0 ]; then
        Debug_msg "Download SDK"
        curl -sS https://dl.google.com/android/repository/${SDK_VERSION} -o ${ANDROID_SDK_TEMP_ZIP}; Result_msg "SDK Downloaded" "SDK downloading failed!"

        Debug_msg "Install SDK"
        mkdir -p ${ANDROID_HOME}/cmdline-tools
        unzip -q -d ${ANDROID_HOME}/cmdline-tools ${ANDROID_SDK_TEMP_ZIP}; Result_msg "cmdline_tools unzip failed!"
        mv ${ANDROID_HOME}/cmdline-tools/cmdline-tools ${ANDROID_HOME}/cmdline-tools/latest
        rm ${ANDROID_SDK_TEMP_ZIP}; Result_msg "\"${ANDROID_SDK_TEMP_ZIP}\" can't be removed!"

        # Disable emulators, skdmanager packets removed:
        #	emulator
        #	system-images;android-21;google_apis;armeabi-v7a

        Debug_msg "Download platform-tools"
        yes | sudo sdkmanager --licenses > $OUT; Result_msg "SDK manager licenses not accepted!"
        yes | sudo sdkmanager "platform-tools" \
            "platforms;android-$ANDROID_BUILD_VERSION" \
            "build-tools;$ANDROID_TOOLS_VERSION" \
            "cmake;$CMAKE_VERSION" \
            "ndk;$NDK_VERSION" > $OUT
        Result_msg "SDK manager installations failed!"

        Debug_msg "Install platform-tools"
        rm -rf ${ANDROID_HOME}/.android; Result_msg "\"${ANDROID_HOME}\" can't be removed!"
        chmod 777 -R ${ANDROID_HOME}

        # Useful ?
        #ln -s ${ANDROID_SDK}/toolchains/llvm/prebuilt/linux-x86_64/lib64/clang/9.0.9 ${ANDROID_SDK}/toolchains/llvm/prebuilt/linux-x86_64/lib64/clang/9.0.8
    fi
fi



# Setup android configuration

if [ $INSTALL_CONFIG -eq 1 ]; then

    Debug_msg "> Configuration"
    STATE_DIR='/tmp/root-state'
    ANDROID_SDK_ROOT='/opt/android-sdk'

    if [ $CLEAN -eq 0 ]; then
        chmod -R 0777 /tmp; Result_msg "Can't change /tmp directory permissions (to 0777)"
        [ ! -d $STATE_DIR ] && ( mkdir $STATE_DIR; Result_msg "Can't create $STATE_DIR directory" )
        chmod 0700 $STATE_DIR; Result_msg "Can't change $STATE_DIR directory permissions (to 0700)"

        chmod -R 777 "$ANDROID_SDK_ROOT"; Result_msg "Can't change "$ANDROID_SDK_ROOT" directory permissions (to 777)"
    fi

    #FILES=('~/.')
    #FILE='./test'
    #PATTERN="abc"
    #FOUND=$(grep -Fnx "$PATTERN" "$FILE")
    #RESULT=$?

    #if [ $RESULT -le 1 ]; then
        # Remove lines if clean mode
    #    if [ $CLEAN -eq 1 ] && [ -n "$FOUND" ]; then
    #        LINE=$(echo "$FOUND" | cut -f1 -d ':')
    #    fi

        # Append otherwise

    #else
    #    echo "An error occured"
    #fi

fi

echo ""
Debug_msg "Finished"
