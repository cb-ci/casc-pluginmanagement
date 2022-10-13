#!/usr/bin/env sh

#set -euo pipefail
set +e

show_help() {
cat << EOF
Usage: ${0##*/} -v <CI_VERSION> [-d <path/to/bundle_dir>] [-h] [-x]
    -h              display this help and exit
    -d Directory    path to the bundle dir: expects a plugin.yaml and a plugin-catalog.yaml
    -v              The version of CloudBees CI (e.g. 2.263.4.2)
    -x              Do NOT do an inplace update of plugins.yaml
EOF
}

checkFileExist() {
    if [ ! -f "$1" ]
    then
        echo "File not exist: $1"
        exit 1
    else
        echo "File exist $1"
    fi
}



if [[ ${#} -eq 0 ]]; then
   show_help
   exit 0
fi

# Initialize our own variables:
CI_VERSION=""
BUNDLE_DIR=""

#ARTIFACTORY_REPO_URL="https://\${ARTIFACTORY_USER}:\${ARTIFACTORY_PW}@acaternberg.jfrog.io/artifactory/cloudbees-plugins-remote"
ARTIFACTORY_REPO_URL="https://acaternberg.jfrog.io/artifactory/cloudbees-plugins-remote"


OPTIND=1
# Resetting OPTIND is necessary if getopts was used previously in the script.
# It is a good idea to make OPTIND local if you process options in a function.

while getopts hv:d: opt; do
    case $opt in
        h)
            show_help
            exit 0
            ;;
        v)  CI_VERSION=$OPTARG
            ;;
        d)  BUNDLE_DIR=$OPTARG
            ;;
        *)
            show_help >&2
            exit 1
            ;;
    esac
done
shift "$((OPTIND-1))"   # Discard the options and sentinel --


PLUGINS_PATH=$BUNDLE_DIR/plugins.yaml
PLUGIN_CATALOG_PATH=$BUNDLE_DIR/plugin-catalog.yaml
BUNDLE_YAML_PATH=$BUNDLE_DIR/bundle.yaml
JENKINS_YAML_PATH=$BUNDLE_DIR/jenkins.yaml

checkFileExist $PLUGINS_PATH
checkFileExist $PLUGIN_CATALOG_PATH
checkFileExist $BUNDLE_YAML_PATH
checkFileExist $JENKINS_YAML_PATH

BUNDLE=$(basename "$BUNDLE_DIR")
echo "Updating Bundle: $BUNDLE in $BUNDLE_DIR..."


#adjustable vars. Will inherit from shell, but default to what you see here.

#Updatecenter URL for Manage Masters
CB_UPDATE_CENTER=${CB_UPDATE_CENTER:="https://jenkins-updates.cloudbees.com/update-center/envelope-core-mm"}

#Updatecenter URL for Client Masters
#CB_UPDATE_CENTER=${CB_UPDATE_CENTER:="https://jenkins-updates.cloudbees.com/update-center/envelope-core-cm"}
#calculated vars
CB_UPDATE_CENTER_URL="$CB_UPDATE_CENTER/update-center.json?version=$CI_VERSION"
echo "Update Center URL: $CB_UPDATE_CENTER_URL"

#cache some stuff locally, sure cache directory exists
CACHE_BASE_DIR=${CACHE_BASE_DIR:="$(pwd)/.cache"}
mkdir -p $CACHE_BASE_DIR

#where to download the calculated plugins localy on this computer
DOWNLOAD_DIR=$CACHE_BASE_DIR/downloads/$CI_VERSION
DOWNLOAD_LOG=$CACHE_BASE_DIR/downloads/$CI_VERSION.log
mkdir -p $DOWNLOAD_DIR

#create a space-delimited list of plugins from plugins.yaml to pass to PIMT
LIST_OF_PLUGINS=$(yq e '.plugins[].id ' $PLUGINS_PATH  | tr "\n" " " | uniq)
echo "LIST_OF_PLUGINS As String:$LIST_OF_PLUGINS"

echo "######################"
echo "cache the war file from https://downloads.cloudbees.com/cloudbees-core/traditional/client-master/rolling/war/$CI_VERSION/cloudbees-core-cm.war"

WAR_CACHE_DIR=$CACHE_BASE_DIR/war/$CI_VERSION
if [[ -f $WAR_CACHE_DIR/jenkins.war ]]; then
  echo "$WAR_CACHE_DIR/jenkins.war already exist, remove it if you need to refresh" >&2
else
  echo "$WAR_CACHE_DIR/jenkins.war NOT exist localy,start to download...." >&2
  mkdir -p $WAR_CACHE_DIR
  curl -v  -o $WAR_CACHE_DIR/jenkins.war https://downloads.cloudbees.com/cloudbees-core/traditional/client-master/rolling/war/$CI_VERSION/cloudbees-core-cm.war
fi

echo "######################"
echo "cache PIMT jar"
PIMT_JAR_CACHE_DIR=$CACHE_BASE_DIR/pimt-jar
if [[ -f $PIMT_JAR_CACHE_DIR/jenkins-plugin-manager.jar ]]; then
  echo "$PIMT_JAR_CACHE_DIR/jenkins-plugin-manager.jar already exist, remove it if you need to refresh" >&2
else
  echo "$PIMT_JAR_CACHE_DIR/jenkins-plugin-manager.jar NOT exist local, try to download it from remote...." >&2
  mkdir -p $PIMT_JAR_CACHE_DIR
  JAR_URL=$(curl -sL \
    -H "Accept: application/vnd.github.v3+json" \
    https://api.github.com/repos/jenkinsci/plugin-installation-manager-tool/releases/latest \
    | yq e '.assets[0].browser_download_url' -)
  echo "Download pluginmanagment tool from $JAR_URL"
  curl -sL $JAR_URL > $PIMT_JAR_CACHE_DIR/jenkins-plugin-manager.jar
fi

echo "######################"
echo "start to calculate plugins. If network errors occurs, add your proxy settings! see https://github.com/jenkinsci/plugin-installation-manager-tool#proxy-support"
export JENKINS_UC_HASH_FUNCTION="SHA1"
export CACHE_DIR=${CACHE_DIR:="$CACHE_BASE_DIR/jenkins-plugin-management-cli"}
rm -Rf $DOWNLOAD_DIR/*
WAR_CACHE_DIR=$WAR_CACHE_DIR/jenkins.war
#WAR_CACHE_DIR=/usr/lib/cloudbees-core-cm/cloudbees-core-cm.war
#-Dhttp.proxyPort=3128
#-Dhttp.proxyHost=myproxy.example.com
java -jar $PIMT_JAR_CACHE_DIR/jenkins-plugin-manager.jar \
  --list \
  --war $WAR_CACHE_DIR \
  --plugin-download-directory $DOWNLOAD_DIR \
  --jenkins-update-center "$CB_UPDATE_CENTER_URL" \
  --plugins $LIST_OF_PLUGINS  > $DOWNLOAD_LOG

echo "######################"
echo "calculate the $PLUGIN_CATALOG_PATH"

#cat $PLUGIN_CATALOG_PATH |head -n 7
#cat $PLUGIN_CATALOG_PATH |head -n 7 | tee $PLUGIN_CATALOG_PATH
echo "type: plugin-catalog
version: '1'
name: plugin-casc-catalog
displayName: tier3/Jenkins OSS plugins CloudBees CI $CI_VERSION
configurations:
- description: these are tier3 plugins for CloudBees CI $CI_VERSION (Jenkins OSS, not supoorted by CloudBees. see https://docs.cloudbees.com/docs/cloudbees-common/latest/plugin-support-policies)
  includePlugins:" > $PLUGIN_CATALOG_PATH

#caalculate repo url for plugins in plugin-catalog
#cat $DOWNLOAD_LOG \
#  | sed -n '/^Plugins\ that\ will\ be\ downloaded\:$/,/^Resulting\ plugin\ list\:$/p' \
#  | sed '1d' | sed '$d' | sed '$d' \
#  | awk  -v URL=$ARTIFACTORY_REPO_URL '{print "    "$1 ":\n""      url: "URL"/"$1"/"$2"/"$1".hpi"}' >>  $PLUGIN_CATALOG_PATH

#caalculate just the version for plugins in plugin-catalog
cat $DOWNLOAD_LOG \
  | sed -n '/^Plugins\ that\ will\ be\ downloaded\:$/,/^Resulting\ plugin\ list\:$/p' \
  | sed '1d' | sed '$d' | sed '$d' \
  | awk   '{print "    "$1 ":\n""      version: "$2}' >>  $PLUGIN_CATALOG_PATH



echo "######################"
echo "calculate the $PLUGINS_PATH"
echo "plugins:" > $PLUGINS_PATH
cat $DOWNLOAD_LOG \
  | sed -n '/^All\ requested\ plugins\:$/,/^Plugins\ that\ will\ be\ downloaded\:$/p' \
  | sed '1d' | sed '$d' | sed '$d' \
  | awk   '{print "- id: " $1}'   >> $PLUGINS_PATH

echo "######################"
echo "clean up empty lines from $PLUGINS_PATH"
cat $PLUGINS_PATH | sed '/^\s*$/d' | uniq >  $CACHE_DIR/tmp_plugins.yaml
cat $CACHE_DIR/tmp_plugins.yaml >  $PLUGINS_PATH

echo "######################"
echo "Generated plugins with dependencies calculated:"
cat $PLUGINS_PATH

echo "######################"
echo "Generated plugin-catalog with link to $ARTIFACTORY_REPO_URL"
cat  $PLUGIN_CATALOG_PATH

echo "######################"
#echo "Increasing version number in $BUNDLE_YAML_PATH"
BUNDLE_VERSION=$(yq eval .version $BUNDLE_YAML_PATH)
OLD_BUNDLE_VERSION=$BUNDLE_VERSION
let "BUNDLE_VERSION+=1"
echo "Updating bundle version from $OLD_BUNDLE_VERSION to $BUNDLE_VERSION"
yq -e -i  ".version |= \"$BUNDLE_VERSION\""  $BUNDLE_YAML_PATH
#cat BUNDLE_YAML_PATH

echo "######################"
echo "Updating system message and version from $OLD_BUNDLE_VERSION to $BUNDLE_VERSION in $JENKINS_YAML_PATH"
SYSTEMMESAGE="\"CasC bundle $BUNDLE version $BUNDLE_VERSION\""
#echo $SYSTEMMESAGE
yq -e -i  ".jenkins.systemMessage |= $SYSTEMMESAGE" $JENKINS_YAML_PATH
cat $JENKINS_YAML_PATH |grep systemMessage

exit 0



