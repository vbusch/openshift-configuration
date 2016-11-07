local version = std.extVar("VERSION");
local broker = import "broker.jsonnet";
local forwarder = import "forwarder.jsonnet";
{
  template(multicast, persistence, secure)::
    local addrtype = (if multicast then "topic" else "queue");
    local addressEnv = (if multicast then { name: "TOPIC_NAME", value: "${ADDRESS}" } else { name: "QUEUE_NAME", value: "${ADDRESS}" });
    local volumeName = "vol-${NAME}";
    local templateName = "%s%s-%s" % [if secure then "tls-" else "", addrtype, (if persistence then "persisted" else "inmemory")];
    local claimName = "pvc-${NAME}";
    {
      "apiVersion": "v1",
      "kind": "Template",
      "metadata": {
        "name": templateName,
        "labels": {
          "addressType": addrtype
        }
      },

      local controller = {
        "apiVersion": "v1",
        "kind": "DeploymentConfig",
        "metadata": {
          "name": "${NAME}",
          "labels": {
            "type": "address-config",
            "address": "${ADDRESS}",
            "store_and_forward": "true",
            "multicast": if multicast then "true" else "false"
          }
        },
        "spec": {
          "replicas": 1,
          "selector": {
            "address": "${ADDRESS}",
            "role": "broker"
          },
          local commonTriggers = [
            {
              "type": "ConfigChange"
            },
            {
              "type": "ImageChange",
              "imageChangeParams": {
                "automatic": true,
                "containerNames": [
                  "broker"
                ],
                "from": {
                  "kind": "ImageStreamTag",
                  "name": "artemis:" + version
                }
              }
            }
          ],
          local multicastTriggers = [
            {
              "type": "ImageChange",
              "imageChangeParams": {
                "automatic": true,
                "containerNames": [
                  "forwarder"
                ],
                "from": {
                  "kind": "ImageStreamTag",
                  "name": "topic-forwarder:" + version
                }
              }
            }
          ],
          "triggers": if multicast
            then commonTriggers + multicastTriggers
            else commonTriggers,
          "template": {
            "metadata": {
              "labels": {
                "role": "broker",
                "address": "${ADDRESS}"
              }
            },
            "spec": {
              local brokerVolume = if persistence
                then broker.persistedVolume(volumeName, claimName)
                else broker.volume(volumeName),
              "volumes": if secure
                then [brokerVolume]
                else [brokerVolume],

              "containers": if multicast
                then [ broker.container(volumeName, addressEnv), forwarder.container(addressEnv) ]
                else [ broker.container(volumeName, addressEnv) ]
            }
          }
        }
      },
      local pvc = {
        "apiVersion": "v1",
        "kind": "PersistentVolumeClaim",
        "metadata": {
          "name": claimName
        },
        "spec": {
          "accessModes": [
            "ReadWriteMany"
          ],
          "resources": {
            "requests": {
              "storage": "${STORAGE_CAPACITY}"
            }
          }
        }
      },
      "objects": if persistence
        then [pvc, controller]
        else [controller],
      "parameters": [
        {
          "name": "STORAGE_CAPACITY",
          "description": "Storage capacity required for volume claims",
          "value": "2Gi"
        },
        {
          "name": "NAME",
          "description": "A valid name for the instance",
          "required": true
        },
        {
          "name": "ADDRESS",
          "description": "The address to use for the %s" % [addrtype],
          "required": true
        }
      ]
    }
}
