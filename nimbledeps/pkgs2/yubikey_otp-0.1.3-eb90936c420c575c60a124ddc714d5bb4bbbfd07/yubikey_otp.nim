

import
  std/[
    httpclient,
    random,
    strutils
  ]

import
  yubikey_otp/[
    modhex
  ]

randomize()




proc yubikeyExtractPublicID*(otp: string): string =
  ## Extract the first 12 characters (public ID) from the OTP
  if otp.len < 12:
    return ""
  let modHexPublicID = otp[0..11]
  return modHexDecode(modHexPublicID)


proc generateNonce(): string =
  ## Generate a secure, random nonce
  ## Nonces are meant to be unique for each request to prevent replay attacks.
  const chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
  for i in 0 .. 20:
    result.add(chars[rand(chars.high)])
  return result


proc yubikeyPublicIDValidate*(publicID, otp: string): bool =
  ## Verify the public ID of a YubiKey OTP
  #
  if publicID == "":
    return false

  if publicID != yubikeyExtractPublicID(otp):
    return false

  return true


proc yubikeyOTPValidate*(
    clientID: string,
    otp: string
  ): bool =
  ## Verify YubiKey OTP

  const
    yubikeyAPI = "https://api.yubico.com/wsapi/2.0/verify"
    params = "?id=$1&otp=$2&nonce=$3"

  let
    nonce = generateNonce()
    url   = yubikeyAPI & params.format(clientID, otp, nonce)
    client = newHttpClient()

  # Make request
  client.headers = newHttpHeaders({ "User-Agent": "Nim Yubikey Client" })
  var response: Response
  try:
    response = client.request(url)
  finally:
    client.close()

  when defined(dev):
    echo url
    echo response.body

  # Check response
  if response.code != Http200:
    return false

  # Check status and nonce
  if "status=OK" notin response.body:
    return false

  if "nonce=" & nonce notin response.body:
    return false

  return true


proc yubikeyRegister*(
    clientID: string,
    otp: string
  ): tuple[success:bool, publicID: string] =
  # Check if the OTP is valid
  if not yubikeyOTPValidate(clientID, otp):
    return (false, "")

  # Extract the public ID
  let publicID = yubikeyExtractPublicID(otp)
  if publicID == "":
    return (false, "")

  return (true, publicID)


proc yubikeyValidate*(
    clientID: string,
    publicID, otp: string
  ): bool =

  # Check public ID first
  if not yubikeyPublicIDValidate(publicID, otp):
    return false

  # Check OTP
  return yubikeyOTPValidate(clientID, otp)

