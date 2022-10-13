#! /bin/bash

PLUGIN_CATALOG=${1:-convert-plugin-catalog-testfile.yaml}
CACHE_BASE_DIR=$(pwd)
PLUGIN_CATALOG_UPDATE_FILE=$CACHE_BASE_DIR/plugin-catalog_update.yaml
#ARTIFACTORY_REPO_URL="https://test:Test1234@acaternberg.jfrog.io/artifactory/cloudbees-plugins-remote"
ARTIFACTORY_REPO_URL="https://acaternberg.jfrog.io/artifactory/cloudbees-plugins-remote"

# echo "type: plugin-catalog
# version: '1'
# name: casc-catalog
# displayName: Catalog with tier3 plugins
# configurations:
# - description: these are tier3 plugins
#   includePlugins:" > $PLUGIN_CATALOG_UPDATE_FILE
head -n 7  $PLUGIN_CATALOG >  $PLUGIN_CATALOG_UPDATE_FILE

COUNTER=0
for line in $(yq eval '(.configurations.[].includePlugins | with_entries(select(.value.*))' $PLUGIN_CATALOG)
do
    if [[ "$COUNTER" -eq 0 ]]
    then
        PLUGINID=${line%?}
    elif [[ "$COUNTER" -eq 2 ]]
    then
         if [[ $line == *"http"* ]]
         then
             echo "      $PLUGINID:" >> $PLUGIN_CATALOG_UPDATE_FILE
             echo "        url: $line" >> $PLUGIN_CATALOG_UPDATE_FILE
         else
             VERSION=${line}
             echo "      $PLUGINID:" >> $PLUGIN_CATALOG_UPDATE_FILE
             echo "        url: $ARTIFACTORY_REPO_URL/$PLUGINID/$VERSION/$PLUGINID.hpi" >> $PLUGIN_CATALOG_UPDATE_FILE
         fi
         PLUGINID=""
         VERSION=""
         COUNTER=0
         continue
    fi
    COUNTER=$[$COUNTER +1]
done

cat $PLUGIN_CATALOG_UPDATE_FILE
diff $PLUGIN_CATALOG_UPDATE_FILE $PLUGIN_CATALOG
