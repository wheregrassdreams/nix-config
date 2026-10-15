{ lib }:
{ prefix, values }:
lib.mapAttrs' (name: value: {
  name = "${prefix}${lib.toUpper (lib.replaceStrings [ "-" "." "/" " " ] [ "_" "_" "_" "_" ] name)}";
  inherit value;
}) values
