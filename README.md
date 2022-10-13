
see 
* Inspired by https://github.com/kyounger/casc-plugin-dependency-calculation
* https://github.com/jenkinsci/plugin-installation-manager-tool 

* Requirements
  * yq (v4)
    ```
    wget https://github.com/mikefarah/yq/releases/download/v4.21.1/yq_linux_amd64  -O /usr/bin/yq &&    chmod +x /usr/bin/yq
    ```
  * curl
  * awk
  * java
    

## Example

First add your wanted plugin id to the plugins.yaml
Here for example the kubernetes-credentials-provider plugin
You can get your specifc pluginids here https://docs.cloudbees.com/plugins/ci
```
echo "- id: kubernetes-credentials-provider" >> casc-sample-bundle/plugins.yaml
```

Or one with dependencies:
```
echo "- id: bitbucket-kubernetes-credentials" >> casc-sample-bundle/plugins.yaml
```

Then call the run script wich calculates dependencies and tweaks the plugin-catalog.yaml if required
Plugin dependencies will calculated automaticly
```
#Example for version 2.319.3.4 
./run.sh -v  2.319.3.4 -d casc-sample-bundle
#Example for version 2.361.2.1 
./run.sh -v  2.361.2.1 -d casc-sample-bundle
```

Result: make a git diff to see what haven been changed in the casc-sample-bundle/plugin*.yaml files 

* `plugin.yaml` contains all plugin id`s that should be installed
* `plugin-catalog.yaml` dependencies and tier3 plugins will be calculated  



The `convert-plc-to-custom-plugin-repo-url.sh` is in progress and converts an plugin-catalog.yaml to airgapped Plugin URL






