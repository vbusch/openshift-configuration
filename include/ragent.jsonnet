local version = std.extVar("VERSION");
local common = import "common.jsonnet";
{
  imagestream(image_name)::
    common.imagestream("ragent", image_name),
  deployment::
    common.deployment_amqp("ragent", 55672)
}
