# Package

version       = "0.1.2"
author        = "ThomasTJdev"
description   = "AWS SES SNS manager"
license       = "MIT"
srcDir        = "src"


# Dependencies

requires "nim >= 1.6.18"

when NimMajor >= 2:
  requires "smtp >= 0.1.0"