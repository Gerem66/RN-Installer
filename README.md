# RN-Installer

## Sources
- [React native](https://reactnative.dev/docs/next/environment-setup)
- [BASH documentation](https://debian-facile.org/doc:programmation:shells:script-bash-variables-arguments-parametres)
- [Commandline tools / Android SDK](https://developer.android.com/studio/command-line)
- [Android NDK](https://developer.android.com/ndk/downloads)
- [Code based on this dockerfile](https://github.com/react-native-community/docker-android)
- [Termux Packages](https://github.com/termux/termux-packages/issues/8350)
    - [AAPT2 Prebuilt binary](https://github.com/rendiix/termux-aapt)

## Tested on
Raspberry Pi 4B\
OS: kali linux 2022.2 raspberry-pi-arm64\
CPU: Broadcom BCM2711, Quad core Cortex-A72 (ARM v8) 64-bit SoC @ 1.5GHz\
RAM: 4GB LPDDR4-3200 SDRAM

## Usage
- Get help: `sudo ./setup-RN-arm64.sh -h`
- Get versions: `sudo ./setup-RN-arm64.sh -v`
- Do nothing: `sudo ./setup-RN-arm64.sh -nu -np -nb -nn -na -nc`

## TODO
- [ ] Test on other devices