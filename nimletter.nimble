# Package

version       = "0.8.1"
author        = "ThomasTJdev"
description   = "Newsletter"
license       = "AGPL v3"
srcDir        = "src"
bin           = @["nimletter"]

# Dependencies
requires "nim >= 1.6.18"

requires "https://github.com/ThomasTJdev/mummy == 0.4.1"
requires "https://github.com/ThomasTJdev/mummy_utils >= 0.1.0"
requires "https://github.com/ThomasTJdev/waterpark == 0.1.6"
requires "https://github.com/ThomasTJdev/nim-schedules == 0.2.0"
requires "https://github.com/ThomasTJdev/nimMime >= 0.0.3"
requires "https://github.com/ThomasTJdev/bcryptnim == 0.2.1"
requires "https://github.com/ThomasTJdev/nim-mmgeoip == 0.1.0"
requires "https://github.com/ThomasTJdev/nim_awsSigV4 >= 0.1.0"

# Cache responses
#requires "https://github.com/ThomasTJdev/ready == 0.1.8"

requires "https://github.com/ThomasTJdev/nim_sqlbuilder >= 1.1.1"
requires "https://github.com/ThomasTJdev/nim_awsSES_SNS >= 0.0.1"
requires "https://github.com/ThomasTJdev/nim_yubikey_otp.git >= 0.1.2"

