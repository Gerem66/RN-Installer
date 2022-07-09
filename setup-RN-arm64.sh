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
BUCK_VERSION=2021.05.05.01
BUCK_JAVA_VERSION=11
CMAKE_VERSION=3.18.1
NDK_VERSION=r23
ANDROID_BUILD_VERSION=31
ANDROID_TOOLS_VERSION=30.0.3
SDK_VERSION=commandlinetools-linux-8512546_latest.zip
NODE_VERSION=16.x

# Other
PREV_FILE='/tmp/.rnsetup'	# To prevent multiple setups

ThrowError() {
    return 1
}

Exit() {
    if [ $UNSAFE -eq 0 ]; then
        if [ -f "$PREV_FILE" ]; then
            rm "$PREV_FILE"
        fi
        exit $1
    fi
}

CtrlC() {
    UNSAFE=0
    Exit 1
}

# $1 - File
# $2 - Pattern
# output - Line number if found, nothing otherwise
# return
#     0 if found
#     1 if not found
#     2 if an error occured
#     
GetLine() {
    FILE=$1
    PATTERN=$2
    FOUND=$(grep -Fnx "$PATTERN" "$FILE" 2>/dev/null)
    RESULT=$?

    if [ $RESULT -gt 1 ]; then
        return 2
    fi

    if [ -n "$FOUND" ]; then
        LINE=$(echo "$FOUND" | cut -f1 -d ':')
        echo "$LINE"
        return 0 
    fi

    return 1
}

# $1 Filename
# $2 Line number
RemoveLine() {
    sed -i -e "${2}d" $1
}

# If contains one message, it will be shown if last command failed
# If contains two messages, first will be shown if last command success, and second if it failed
Result_msg() {
    RESULT=$?
    ARGS_LENGTH=$#
    if [ $ARGS_LENGTH -eq 1 ]; then
        if [ $RESULT -ne 0 ]; then
            echo -e "$ETAG $1"
            Exit 1
        fi
    elif [ $ARGS_LENGTH -eq 2 ]; then
        if [ $RESULT -eq 0 ]; then
            echo -e "$STAG $1"
        else
            echo -e "$ETAG $2"
            Exit 1
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
    VER_TXT+="Buck|$BUCK_VERSION|https://github.com/facebook/buck.git\n"
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



if [ -f "$PREV_FILE" ]; then
    echo "One setup is already in progress, exiting."
    exit 1
fi

touch "$PREV_FILE"
trap CtrlC INT
TIME_START=$(date +%s)
echo -e "\n${DTAG} START SETUP\n"



if [ $INSTALL_UPDATE -eq 1 ]; then
    Debug_msg "> Update system packages"
    apt-get update > $OUT; Result_msg "apt update failed!"
    apt-get dist-upgrade -y > $OUT; Result_msg "Packages updated" "apt dist-upgrade failed!"
    apt-get autoremove -y > $OUT; Result_msg "apt autoremove failed!"
fi

if [ $INSTALL_PKGS -eq 1 ]; then
    Debug_msg "> Install default packages"
    apt-get install -y \
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
    [ -d ./buck ] && ( rm -rf buck/; Result_msg "Buck folder package removed" "Buck folder can't be removed!" )
    [ -f /tmp/buck.pex ] && ( rm -f /tmp/buck.pex; Result_msg "Buck .pex removed" "Buck .pex can't be removed!" )
    [ -f /usr/local/bin/buck ] && ( rm -f /usr/local/bin/buck; Result_msg "Buck binary removed" "Buck binary can't be removed!" )

    if [ $CLEAN -eq 0 ]; then
        Debug_msg "Download buck"

        [ $DEBUG -eq 0 ] && QUIET='--quiet' || QUIET=''
        git clone $QUIET --depth 1 --branch v${BUCK_VERSION} https://github.com/facebook/buck.git > $OUT 2>&1; Result_msg "Buck download failed!"
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
        mv /tmp/buck.pex /usr/local/bin/buck; Result_msg "Move builded buck failed!"

        cd ..
        rm -rf buck/
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
    [ -d ${ANDROID_HOME} ] && ( rm -rf ${ANDROID_HOME}; Result_msg "Android home \"${ANDROID_HOME}\" removed" "Android home \"${ANDROID_HOME}\" can't be removed!" )
    [ -d ${ANDROID_SDK} ] && ( rm -rf ${ANDROID_SDK}; Result_msg "Android SDK \"${ANDROID_SDK}\" removed" "Android SDK \"${ANDROID_SDK}\" can't be removed!" )
    [ -f ${ANDROID_SDK_TEMP_ZIP} ] && ( rm -f ${ANDROID_SDK_TEMP_ZIP}; Result_msg "Temp file \"${ANDROID_SDK_TEMP_ZIP}\" removed" "Temp file \"${ANDROID_SDK_TEMP_ZIP}\" can't be removed!" )

    if [ $CLEAN -eq 0 ]; then
        Debug_msg "Download SDK"
        curl -sS https://dl.google.com/android/repository/${SDK_VERSION} -o ${ANDROID_SDK_TEMP_ZIP}; Result_msg "SDK Downloaded" "SDK downloading failed!"

        Debug_msg "Install SDK"
        mkdir -p ${ANDROID_HOME}/cmdline-tools
        unzip -q -d ${ANDROID_HOME}/cmdline-tools ${ANDROID_SDK_TEMP_ZIP}; Result_msg "cmdline_tools unzip failed!"
        mv ${ANDROID_HOME}/cmdline-tools/cmdline-tools ${ANDROID_HOME}/cmdline-tools/latest
        rm -f ${ANDROID_SDK_TEMP_ZIP}; Result_msg "\"${ANDROID_SDK_TEMP_ZIP}\" can't be removed!"

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

    # Clean gradle
    [ -d ~/.gradle ] && ( rm -rf ~/.gradle; Result_msg "Gradle (home) was been removed" "Gradle (home) can't be removed!" )
    [ -d /root/.gradle ] && ( sudo rm -rf /root/.gradle; Result_msg "Gradle (root) was been removed" "Gradle (root) can't be removed!" )

    # Clean
    ALL_FILES=( ".bashrc" ".zshrc" )
    ALL_LINES=( "export ANDROID_SDK_ROOT=$ANDROID_SDK_ROOT" "export PATH=\$PATH:\$ANDROID_SDK_ROOT/platform-tools" )
    for USER in /home/*/; do
        for FILE in "${ALL_FILES[@]}"; do
            FILERC="${USER}${FILE}"
            if [ ! -f ${FILERC} ]; then
                continue
            fi

            for LINE in "${ALL_LINES[@]}"; do
                LINE_NB=$(GetLine "$FILERC" "$LINE")
                LINE_NB_STATUS=$?

                if [ $LINE_NB_STATUS -ne 0 ] || [ -z $LINE_NB ]; then
                    continue
                fi
                if [ $LINE_NB -gt 0 ]; then
                    RemoveLine "$FILERC" "$LINE_NB"
                    Result_msg "Line \"${LINE}\" can't be removed from file \"$FILERC\"!"
                fi
            done
        done
    done

    if [ $CLEAN -eq 0 ]; then

        # Permissions
        chmod -R 0777 /tmp; Result_msg "Can't change /tmp directory permissions (to 0777)"
        [ ! -d $STATE_DIR ] && ( mkdir $STATE_DIR; Result_msg "Can't create $STATE_DIR directory" )
        chmod 0700 $STATE_DIR; Result_msg "Can't change $STATE_DIR directory permissions (to 0700)"
        chmod -R 777 "$ANDROID_SDK_ROOT"; Result_msg "Can't change "$ANDROID_SDK_ROOT" directory permissions (to 777)"

        # Exports config
        for USER in /home/*/; do
            for FILE in "${ALL_FILES[@]}"; do
                for LINE in "${ALL_LINES[@]}"; do
                    FILERC="${USER}${FILE}"
                    echo "$LINE" >> "$FILERC"; Result_msg "Can't add configuration to \"$FILERC\""
                done
            done
        done

        # Build gradle
        BEFOREPATH=$(pwd)
        Debug_msg "Create temp project to build gradle (can take few minutes)" # Faster way ?
        cd /tmp
        npx react-native init rn_app_gradle > $OUT 2>&1; Result_msg "Can't create temp project"
        cd /tmp/rn_app_gradle
        echo "sdk.dir=/opt/android-sdk" > ./android/local.properties
        npx react-native run-android --no-jetifier > $OUT 2>&1 # Fail because it's builded for amd64, but gradle built
        cd $BEFOREPATH
        rm -rf /tmp/rn_app_gradle; Result_msg "Can't remove temp project"

        # Replace adb (amd64) to arm64 version (installed with apt)
        PATH_ADB=$(which adb)
        cp $PATH_ADB $ANDROID_SDK_ROOT/platform-tools/adb > $OUT 2>&1
        Result_msg "Adb replaced (amd64 to arm64)" "Can't copy adb to platform-tools"

        # Replace aapt2 (amd) with arm64 executable
        AAPT2_JARS=()

        AAPT2_JAR=$(find /root/.gradle/ -type f -name aapt2-*-linux.jar)
        if [ -n "$AAPT2_JAR" ]; then
            AAPT2_JARS+=($AAPT2_JAR)
        fi
        for USER in /home/*/; do
            AAPT2_JAR=$(find ${USER}.gradle/ -type f -name aapt2-*-linux.jar)
            if [ -n "$AAPT2_JAR" ]; then
                AAPT2_JARS+=($AAPT2_JAR)
            fi
        done

        if [ ${#AAPT2_JARS[@]} -eq 0 ]; then
            ThrowError; Result_msg "Can't find aapt2-*-linux.jar"
        fi

        wget -P /tmp https://github.com/rendiix/termux-aapt/raw/main/prebuilt-binary/arm64/aapt2 > $OUT 2>&1; Result_msg "Can't download aapt2 binary"
        for AAPT2_JAR_PATH in "${AAPT2_JARS[@]}"; do
            jar -uvf "$AAPT2_JAR_PATH" /tmp/aapt2 > $OUT 2>&1
            Result_msg "AAPT2 replaced by arm64 version \"$AAPT2_JAR_PATH\"" "Can't replace aapt2 binary with arm64 version"
        done
        rm -f /tmp/aapt2 > $OUT 2>&1

    fi
fi


TIME_END=$(date +%s)
TIME_DURATION=$(echo $((TIME_END-TIME_START)) | awk '{print int($1/60)"m "int($1%60)"s"}')

echo ""
Debug_msg "Finished (in $TIME_DURATION)"
[ -f "$PREV_FILE" ] && rm -f "$PREV_FILE"
