


import
  std/[
    json,
    strutils,
    times
  ]


import
  mummy, mummy/routers,
  mummy_utils


import
  sqlbuilder,
  yubikey_otp


import
  ../database/database_connection,
  ../utils/auth,
  ../utils/password_utils,
  ../utils/settings_utils,
  ../utils/validate_data


include
  "../html/sidebar.nimf",
  "../html/profile.nimf"

var profileRouter*: Router


profileRouter.get("/profile",
proc(request: Request) =
  createTFD()
  if not c.loggedIn: redirect("/")
  resp Http200, nimfProfile(c, getPageName())
)


profileRouter.get("/api/profile/get-profile",
proc(request: Request) =
  createTFD()
  if not c.loggedIn: redirect("/")

  var data: seq[string]
  pg.withConnection conn:
    data = getRow(conn, sqlSelect(
        table = "users",
        select = [
          "email",
          "yubikey_public",
          "yubikey_clientid"
        ],
        where = [
          "id ="
        ]
      ), c.userID)

  resp Http200, %* ( {
      "email": data[0],
      "yubikey_public": try: data[1].parseJson() except: parseJson("[]"),
      "yubikey_clientid": data[2],
      "success": true
    } )
)


profileRouter.post("/api/profile/save-email",
proc(request: Request) =
  createTFD()
  if not c.loggedIn: resp Http401

  let email = @"email"
  if email == "":
    resp Http400, "Email is required"

  pg.withConnection conn:
    exec(conn, sqlUpdate(
      table = "users",
      data = [
        "email",
      ],
      where = [
        "id ="
      ]
    ), email, c.userID)

  resp Http200, %* {
    "success": true
  }
)


profileRouter.post("/api/profile/save-yubikey",
proc(request: Request) =
  createTFD()
  if not c.loggedIn: resp Http401

  let otp = @"otp"
  let ykname = @"name"
  let clientID = @"clientID"

  if otp == "":
    resp Http400, "Yubikey is required"

  #
  # Check if the Yubikey name is valid
  #
  const validchars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-"

  for c in ykname:
    if $c notin validchars:
      resp Http400, ("Error, wrong Yubikey name [#MS2FA-A-0.1]")

  if ykname.len() <= 1:
    resp Http400, ("Error, wrong Yubikey name [#MS2FA-A-0.2]")

  if otp.len() != 44:
    resp Http400, ("Error, wrong OTP length [#MS2FA-A-1]")


  #
  # Get public ID
  #
  let
    data = yubikeyRegister(clientID, otp)

  if not data.success:
    resp Http400, ("Error registering Yubikey OTP [#MS2FA-A-2]")


  #
  # Get the Yubikey data
  #
  var ykdata: string
  pg.withConnection conn:
    ykdata = getValue(conn, sqlSelect(
        table = "users",
        select = ["yubikey_public"],
        where = ["id ="],
      ), c.userID)


  #
  # Loop data and add
  #
  var ykJson: JsonNode
  if ykdata.len() == 0:
    ykJson = parseJson("[]")
  else:
    try:
      ykJson = parseJson(ykdata)
    except:
      resp Http400, "Error parsing Yubikey data, contact support [#MS2FA-A-4]"

  ykJson.add( %* {
    "name": ykname,
    "publicid": data.publicID,
    "created": toInt(epochTime())
  } )


  #
  # Save data
  #
  pg.withConnection conn:
    exec(conn, sqlUpdate(
      table   = "users",
      data    = [
        "yubikey_public =",
        "yubikey_clientid ="
      ],
      where   = ["id ="]
    ), $ykJson, clientID, c.userID)

  resp Http200, (
    %* {
      "success": true,
      "message": "Yubikey added"
    }
  )
)


profileRouter.post("/api/profile/save-password",
proc(request: Request) =
  createTFD()
  if not c.loggedIn: resp Http401

  let password = @"password"

  if password == "":
    resp Http400, "Password is required"

  let
    salt = makeSalt()
    passwordCreated = makePassword(password, salt)

  pg.withConnection conn:
    exec(conn, sqlUpdate(
      table = "users",
      data = [
        "password",
        "salt"
      ],
      where = [
        "id = "
      ]
    ), passwordCreated, salt, c.userID)

  resp Http200, (
    %* {
      "success": true,
      "message": "Password updated"
    }
  )
)
