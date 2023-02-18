#!/bin/bash

#Configuration Variables and Parameters

#Parameters
SCRIPTPATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
TARGET_DIRECTORY="$SCRIPTPATH/../target"
PRODUCT=${1}
VERSION=${2}
DATE=`date +%Y-%m-%d`
TIME=`date +%H:%M:%S`
LOG_PREFIX="[$DATE $TIME]"

function printSignature() {
  cat "$SCRIPTPATH/utils/ascii_art.txt"
  echo
}

function printUsage() {
  echo -e "\033[1mUsage:\033[0m"
  echo "$0 [APPLICATION_NAME] [APPLICATION_VERSION]"
  echo
  echo -e "\033[1mOptions:\033[0m"
  echo "  -h (--help)"
  echo
  echo -e "\033[1mExample::\033[0m"
  echo "$0 wso2am 2.6.0"

}

#Start the generator
printSignature

#Argument validation
if [[ "$1" == "-h" ||  "$1" == "--help" ]]; then
    printUsage
    exit 1
fi
if [ -z "$1" ]; then
    echo "Please enter a valid application name for your application"
    echo
    printUsage
    exit 1
else
    echo "Application Name : $1"
fi
if [[ "$2" =~ [0-9]+.[0-9]+.[0-9]+ ]]; then
    echo "Application Version : $2"
else
    echo "Please enter a valid version for your application (format [0-9].[0-9].[0-9])"
    echo
    printUsage
    exit 1
fi

#Functions
go_to_dir() {
    pushd $1 >/dev/null 2>&1
}

log_info() {
    echo "${LOG_PREFIX}[INFO]" $1
}

log_warn() {
    echo "${LOG_PREFIX}[WARN]" $1
}

log_error() {
    echo "${LOG_PREFIX}[ERROR]" $1
}

deleteInstallationDirectory() {
    log_info "Cleaning $TARGET_DIRECTORY directory."
    rm -rf "$TARGET_DIRECTORY"

    if [[ $? != 0 ]]; then
        log_error "Failed to clean $TARGET_DIRECTORY directory" $?
        exit 1
    fi
}

createInstallationDirectory() {
    if [ -d "${TARGET_DIRECTORY}" ]; then
        deleteInstallationDirectory
    fi
    mkdir -pv "$TARGET_DIRECTORY"

    if [[ $? != 0 ]]; then
        log_error "Failed to create $TARGET_DIRECTORY directory" $?
        exit 1
    fi
}

copyDarwinDirectory(){
  createInstallationDirectory
  cp -r "$SCRIPTPATH/darwin" "${TARGET_DIRECTORY}/"
  chmod -R 755 "${TARGET_DIRECTORY}/darwin/scripts"
  chmod -R 755 "${TARGET_DIRECTORY}/darwin/Resources"
  chmod 755 "${TARGET_DIRECTORY}/darwin/Distribution"
}

copyBuildDirectory() {
    sed -i '' -e 's/__VERSION__/'${VERSION}'/g' "${TARGET_DIRECTORY}/darwin/scripts/postinstall"
    sed -i '' -e 's/__PRODUCT__/'${PRODUCT}'/g' "${TARGET_DIRECTORY}/darwin/scripts/postinstall"
    chmod -R 755 "${TARGET_DIRECTORY}/darwin/scripts/postinstall"

    sed -i '' -e 's/__VERSION__/'${VERSION}'/g' "${TARGET_DIRECTORY}/darwin/Distribution"
    sed -i '' -e 's/__PRODUCT__/'${PRODUCT}'/g' "${TARGET_DIRECTORY}/darwin/Distribution"
    chmod -R 755 "${TARGET_DIRECTORY}/darwin/Distribution"
    chmod -R 755 "${TARGET_DIRECTORY}/darwin/Resources/"

    rm -rf "${TARGET_DIRECTORY}/darwinpkg"
    mkdir -p "${TARGET_DIRECTORY}/darwinpkg"

    #Copy cellery product to /Library/Cellery
    mkdir -p "${TARGET_DIRECTORY}"/darwinpkg/Library/${PRODUCT}/${VERSION}
    cp -a "$SCRIPTPATH"/application/. "${TARGET_DIRECTORY}"/darwinpkg/Library/${PRODUCT}/${VERSION}
    chmod -R 755 "${TARGET_DIRECTORY}"/darwinpkg/Library/${PRODUCT}/${VERSION}

    rm -rf "${TARGET_DIRECTORY}/package"
    mkdir -p "${TARGET_DIRECTORY}/package"
    chmod -R 755 "${TARGET_DIRECTORY}/package"

    rm -rf "${TARGET_DIRECTORY}/pkg"
    mkdir -p "${TARGET_DIRECTORY}/pkg"
    chmod -R 755 "${TARGET_DIRECTORY}/pkg"
}

function buildPackage() {
    log_info "Application installer package building started.(1/3)"
    pkgbuild --identifier "org.${PRODUCT}.${VERSION}" \
    --version "${VERSION}" \
    --scripts "${TARGET_DIRECTORY}/darwin/scripts" \
    --root "${TARGET_DIRECTORY}/darwinpkg" \
    "${TARGET_DIRECTORY}/package/${PRODUCT}.pkg" > /dev/null 2>&1
}

function buildProduct() {
    log_info "Application installer product building started.(2/3)"
    productbuild --distribution "${TARGET_DIRECTORY}/darwin/Distribution" \
    --resources "${TARGET_DIRECTORY}/darwin/Resources" \
    --package-path "${TARGET_DIRECTORY}/package" \
    "${TARGET_DIRECTORY}/pkg/$1" > /dev/null 2>&1
}

function signProduct() {
    local name=$1
    local developer_identiy=$2
    log_info "Application installer signing process started.(3/3)"
    mkdir -pv "${TARGET_DIRECTORY}/pkg-signed"
    chmod -R 755 "${TARGET_DIRECTORY}/pkg-signed"

    if [ -z "$developer_identiy" ]; then
        read -p "Please enter the Apple Developer Installer Certificate ID:" developer_identiy
    fi

    # "Developer ID Application: Shan Yu (4TDFARXPF6)"
    productsign --sign "${developer_identiy}" \
    "${TARGET_DIRECTORY}/pkg/$name" \
    "${TARGET_DIRECTORY}/pkg-signed/$name" || {
        echo "productsign failed"
        exit 1
    }

    pkgutil --check-signature "${TARGET_DIRECTORY}/pkg-signed/$name"
}

function createInstaller() {
    log_info "Application installer generation process started.(3 Steps)"
    buildPackage
    buildProduct ${PRODUCT}-macos-installer-x64-${VERSION}.pkg
    if [ -z "$SIGN_YES" ]; then
        while true; do
            read -p "Do you wish to sign the installer (You should have Apple Developer Certificate) [y/N]?" answer
            [[ $answer == "y" || $answer == "Y" ]] && FLAG=true && break
            [[ $answer == "n" || $answer == "N" || $answer == "" ]] && log_info "Skipped signing process." && FLAG=false && break
            echo "Please answer with 'y' or 'n'"
        done
    fi
    [[ $FLAG == "true" || "$SIGN_YES" == "true" ]] && signProduct ${PRODUCT}-macos-installer-x64-${VERSION}.pkg "$SIGN_IDENTITY"
    log_info "Application installer generation steps finished."
}

function createUninstaller(){
    cp "$SCRIPTPATH/darwin/Resources/uninstall.sh" "${TARGET_DIRECTORY}/darwinpkg/Library/${PRODUCT}/${VERSION}"
    sed -i '' -e "s/__VERSION__/${VERSION}/g" "${TARGET_DIRECTORY}/darwinpkg/Library/${PRODUCT}/${VERSION}/uninstall.sh"
    sed -i '' -e "s/__PRODUCT__/${PRODUCT}/g" "${TARGET_DIRECTORY}/darwinpkg/Library/${PRODUCT}/${VERSION}/uninstall.sh"
}

function notarizationPkg() {
    echo "notarization macOS app..."
    local name=${TARGET_DIRECTORY}/pkg-signed/${PRODUCT}-macos-installer-x64-${VERSION}.pkg
    xcrun notarytool submit $name --keychain-profile "NotarizationItemName" --wait
    # xcrun notarytool info c440cb54-12e7-4745-838e-66a26282c69d  --keychain-profile "NotarizationItemName"
    # xcrun notarytool log 4e2cd70c-5388-4741-98f2-80c166eac10f --keychain-profile "NotarizationItemName" developer_log.json
    echo "$name"
}

#Pre-requisites

#Main script
log_info "Installer generating process started."

copyDarwinDirectory
copyBuildDirectory
createUninstaller
createInstaller
notarizationPkg

exit 0
