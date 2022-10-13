
see 
* https://github.com/kyounger/casc-plugin-dependency-calculation
* https://github.com/jenkinsci/plugin-installation-manager-tool 

* Requirements
  * yq (v4)
    ```
    wget https://github.com/mikefarah/yq/releases/download/v4.21.1/yq_linux_amd64  -O /usr/bin/yq &&    chmod +x /usr/bin/yq
    ```
  * curl
  * awk
  * java
    
# Usage
```
Usage: run.sh -v <CI_VERSION> [-f <path/to/plugins.yaml>] [-h] [-x]

    -h          display this help and exit
    -f FILE     path to the plugins.yaml file
    -v          The version of CloudBees CI (e.g. 2.263.4.2)
    -x          Do NOT do an inplace update of plugins.yaml

```

## Example
```
#First add your wanted plugin id to the plugins.yaml
#Here for examle the kubernetes-credentials-provider
echo "- id: kubernetes-credentials-provider" >> casc-sample-bundle/plugins.yaml
#then call tghe run script wich calculates dependencies and tweaks the plugin-catalog.yaml if required
#Plugin dependencies will calculated automaticly 
./run.sh -v  2.319.3.4 -d casc-sample-bundle
```
`plugin.yaml` contains all plugin id`s that should be installed

dependencies and tier3 plugins will be calculated automaticly 






