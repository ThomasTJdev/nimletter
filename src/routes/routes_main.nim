


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
  sqlbuilder


import
  ../database/database_connection,
  ../utils/auth,
  ../utils/password_utils,
  ../utils/settings_utils,
  ../utils/validate_data

include
  "../html/sidebar.nimf",
  "../html/dash.nimf",
  "../html/login.nimf",
  "../html/profile.nimf"


proc renderMain*(c: UserData; page = ""): string =
  nimfMain(c, page, getPageName())

proc renderEvent*(c: UserData): string =
  nimfEvent(c, "", getPageName())


var mainRouter*: Router


#
# Status check
#
mainRouter.head("/",
proc(request: Request) =
  resp Http200
)
mainRouter.head("/status",
proc(request: Request) =
  resp Http200
)
mainRouter.get("/status",
proc(request: Request) =
  resp Http200
)



#
# Login
#
mainRouter.get("/login",
proc(request: Request) =
  createTFD()
  if c.loggedIn: redirect("/")

  resp Http200, nimfLogin()
)


mainRouter.post("/api/auth/login",
proc(request: Request) =
  createTFD()
  if c.loggedIn:
    resp Http200

  let
    email = @"email"
    password = @"password"
    otp = @"otp"

  if not isValidEmail(email):
    resp Http400, "Invalid email: " & email
  elif password.len() < 6:
    resp Http400, "Password too short"

  let loginData = checkPasswordAndOTP(email, password, otp)
  if not loginData.passwordOK:
    resp Http401, "Invalid email or password"

  elif loginData.otpRequired and otp == "":
    resp Http200, (
      %* {
        "success": true,
        "otpRequired": loginData.otpRequired,
        "otpProvided": loginData.otpOK
      }
    )

  elif loginData.otpRequired and not loginData.otpOK:
    resp Http401, "Invalid OTP"

  else:
    c.loggedIn = true
    c.loggedInTime = epochTime().toInt()
    c.sessionkey = makeSessionKey()
    insertIntoSessions(loginData.userID, c.sessionkey)
    var headers: httpheaders.HttpHeaders
    loginSetCookie(c)

    resp(Http200 , headers, $(
      %* {
        "success": true,
        "otpRequired": loginData.otpRequired,
        "otpProvided": loginData.otpOK
      }
    ) )
)


mainRouter.get("/logout",
proc(request: Request) =
  createTFD()
  if not c.loggedIn: redirect("/login")

  pg.withConnection conn:
    exec(conn, sqlDelete(
      table = "sessions",
      where = ["token = ?"],
    ), c.sessionkey)

  redirect("/")
)




#
# Pages
#
mainRouter.get("/",
proc(request: Request) =
  createTFD()
  if not c.loggedIn: redirect("/login")

  resp Http200, renderMain(c, "dashboard")
)

mainRouter.get("/contacts",
proc(request: Request) =
  createTFD()
  if not c.loggedIn: redirect("/login")

  resp Http200, renderMain(c)
)

mainRouter.get("/lists",
proc(request: Request) =
  createTFD()
  if not c.loggedIn: redirect("/login")

  resp Http200, renderMain(c)
)

mainRouter.get("/mails",
proc(request: Request) =
  createTFD()
  if not c.loggedIn: redirect("/login")

  resp Http200, renderMain(c)
)

mainRouter.get("/flows",
proc(request: Request) =
  createTFD()
  if not c.loggedIn: redirect("/login")

  resp Http200, renderMain(c)
)

mainRouter.get("/maillog",
proc(request: Request) =
  createTFD()
  if not c.loggedIn: redirect("/login")

  resp Http200, renderMain(c)
)

mainRouter.get("/settings",
proc(request: Request) =
  createTFD()
  if not c.loggedIn: redirect("/login")

  resp Http200, renderMain(c)
)

mainRouter.get("/events",
proc(request: Request) =
  createTFD()
  if not c.loggedIn: redirect("/login")

  resp Http200, renderEvent(c)
)

