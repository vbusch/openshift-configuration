local version = std.extVar("VERSION");
{
  imagestream(name, repo)::
  {
    "apiVersion": "v1",
    "kind": "ImageStream",
    "metadata": {
      "labels": {
        "app": "enmasse"
      },
      "name": name
    },
    "spec": {
      "dockerImageRepository": repo, 
      "tags": [
        {
          "name": version,
          "from": {
            "kind": "DockerImage",
            "name": repo + ":" + version
          }
        }
      ],
      "importPolicy": {
        "scheduled": true
      }
    }
  },

  deployment_amqp(name, port)::
  {
    "apiVersion": "v1",
    "kind": "DeploymentConfig",
    "metadata": {
      "labels": {
        "component": name,
        "app": "enmasse"
      },
      "name": name
    },
    "spec": {
      "replicas": 1,
      "selector": {
        "component": name
      },
      "triggers": [
        {
          "type": "ConfigChange"
        },
        {
          "type": "ImageChange",
          "imageChangeParams": {
            "automatic": true,
            "containerNames": [
              name
            ],
            "from": {
              "kind": "ImageStreamTag",
              "name": name + ":" + version
            }
          }
        }
      ],
      "template": {
        "metadata": {
          "labels": {
            "component": name,
            "app": "enmasse"
          }
        },
        "spec": {
          "containers": [
            {
              "image": name,
              "name": name,
              "ports": [
                {
                  "name": "amqp",
                  "containerPort": port,
                  "protocol": "TCP"
                }
              ],
              "livenessProbe": {
                "tcpSocket": {
                  "port": "amqp"
                }
              }
            }
          ]
        }
      }
    }
  }
}
