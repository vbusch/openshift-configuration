local version = std.extVar("VERSION");
local common = import "common.jsonnet";
{
  imagestream(image_name)::
    common.imagestream("subserv", image_name),
  deployment::
    common.deployment_amqp("subserv", 5672)
  service::
    common.service_amqp("subserv", "subscription", 5672)
}
