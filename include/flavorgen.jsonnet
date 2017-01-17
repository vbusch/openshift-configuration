{
  generate(secure, templateName, capacity, shared)::
  local prefix = if secure then "tls-" else "";
  {
    "shared": shared,
    "templateName": prefix + templateName,
    [if capacity != null then "templateParameters"]: {
      "STORAGE_CAPACITY": capacity
    }
  }
}
