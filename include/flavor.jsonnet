local flavor = import "flavorgen.jsonnet";
{
  generate(secure)::
  {
    "kind": "ConfigMap",
    "apiVersion": "v1",
    "metadata": {
      "labels": {
        "app": "enmasse"
      },
      "name": "flavor"
    },
    "data": {
      local flavors = {
        "vanilla-queue": flavor.generate(secure, "queue-inmemory", null, false),
        "lowvolume-queue": flavor.generate(secure, "queue-inmemory", null, true),
        "vanilla-topic": flavor.generate(secure, "topic-inmemory", null, false),
        "small-persisted-queue": flavor.generate(secure, "queue-persisted", "1Gi", false),
        "large-persisted-queue": flavor.generate(secure, "queue-persisted", "10Gi", false),
        "small-persisted-topic": flavor.generate(secure, "topic-persisted", "1Gi", false),
        "large-persisted-topic": flavor.generate(secure, "topic-persisted", "10Gi", false),
      },
      "json": std.toString(flavors),
    }
  }
}
