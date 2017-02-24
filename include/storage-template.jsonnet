local version = std.extVar("VERSION");
local broker = import "broker.jsonnet";
local router = import "router.jsonnet";
local broker_repo = "${BROKER_REPO}";
local router_repo = "${ROUTER_REPO}";
local forwarder_repo = "${TOPIC_FORWARDER_REPO}";
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
          "app": "enmasse"
        }
      },

      local hawkularConfig = {
        "apiVersion": "v1",
        "kind": "ConfigMap",
        "metadata": {
          "name": "hawkular-config-${NAME}"
        },
        "data": {
          "hawkular-openshift-agent": std.toString({
            "endpoints": [
              {
                "type": "jolokia",
                "protocol": "http",
                "port": 8161,
                "path": "/jolokia",
                "collection_interval": "60s",
                "metrics": [
                  {
                    "name": "java.lang:type=Memory#HeapMemoryUsage#used",
                    "type": "gauge",
                    "id": "VM Heap Memory Used"
                  }
                ]
              }
            ]
          })
        }
      },

      local controller = {
        "apiVersion": "extensions/v1beta1",
        "kind": "Deployment",
        "metadata": {
          "name": "${NAME}",
          "labels": {
            "app": "enmasse",
            "group_id": "${NAME}",
            "address_config": "address-config-${NAME}"
          }
        },
        "spec": {
          "replicas": 1,
          "template": {
            "metadata": {
              "labels": {
                "app": "enmasse",
                "role": "broker",
                "group_id": "${NAME}"
              }
            },
            "spec": {
              local hawkularVolume = broker.hawkularVolume("hawkular-config-${NAME}"),
              local brokerVolume = if persistence
                then broker.persistedVolume(volumeName, claimName)
                else broker.volume(volumeName),
              "volumes": if secure
                then [brokerVolume, router.secret_volume(), hawkularVolume ]
                else [brokerVolume, hawkularVolume ],

              "containers": if multicast
                then [ broker.container(volumeName, broker_repo, addressEnv), router.container(secure, router_repo, addressEnv, "256Mi"), forwarder.container(forwarder_repo, addressEnv) ]
                else [ broker.container(volumeName, broker_repo, addressEnv) ]
            }
          }
        }
      },
      local pvc = {
        "apiVersion": "v1",
        "kind": "PersistentVolumeClaim",
        "metadata": {
          "name": claimName,
          "labels": {
            "group_id": "${NAME}",
            "app": "enmasse"
          }
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
      local mcast = if multicast then "true" else "false",
      local config = {
        "apiVersion": "v1",
        "kind": "ConfigMap",
        "metadata": {
          "name": "address-config-${NAME}",
          "labels": {
            "type": "address-config",
            "group_id": "${NAME}",
            "app": "enmasse"
          }
        },
        "data": {
          "${ADDRESS}": "{\"store_and_forward\": true, \"multicast\": " + mcast + "}"
        }
      },
      "objects": if persistence
        then [pvc, controller, config, hawkularConfig]
        else [controller, config, hawkularConfig],
      "parameters": [
        {
          "name": "STORAGE_CAPACITY",
          "description": "Storage capacity required for volume claims",
          "value": "2Gi"
        },
        {
          "name": "ROUTER_LINK_CAPACITY",
          "description": "The link capacity setting for router",
          "value": "50"
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
