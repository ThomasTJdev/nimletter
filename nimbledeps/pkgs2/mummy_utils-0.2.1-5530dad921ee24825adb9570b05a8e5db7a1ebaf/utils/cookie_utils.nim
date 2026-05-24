# Copyright Thomas T. Jarløv (TTJ) - ttj@ttj.dk

{.push raises: [].}

import std/[cookies, options, strtabs, times]

import
  mummy,
  mummy/routers

#
# Cookies
#
proc cookies*(request: Request, cookie: string): string =
  ## Get cookies of request.
  return parseCookies(request.headers["Cookie"]).getOrDefault(cookie, "")


proc cookies*(request: Request): StringTableRef =
  ## Get cookies of request.
  return parseCookies(request.headers["Cookie"])


template setCookie*(
    key, value: string,
    domain = "", path = "", expires = "";
    secure = true, httpOnly = true,
    maxAge = none(int),
    sameSite = SameSite.Default
  ) =
  ## Add cookie to response but requires the header to be available.
  headers["Set-Cookie"] = cookies.setCookie(
    key, value,
    domain, path, expires,
    true, secure, httpOnly,
    maxAge, sameSite
  )

template setCookie*(
    key, value: string,
    expires: DateTime | Time,
    domain = "", path = "",
    secure = true, httpOnly = true,
    maxAge = none(int),
    sameSite = SameSite.Default
  ) =
  ## Add cookie to response but requires the header to be available.
  ## Expires is set to a DateTime or Time.
  headers["Set-Cookie"] = cookies.setCookie(
    key, value,
    expires,
    domain, path,
    true,
    secure, httpOnly,
    maxAge, sameSite
  )

template addCookie*(
    key, value: string,
    domain = "", path = "", expires = "";
    secure = true, httpOnly = true,
    maxAge = none(int),
    sameSite = SameSite.Default
  ) =
  ## Add cookie to response but requires the header to be available.
  headers.toBase.add(("Set-Cookie", cookies.setCookie(
    key, value,
    domain, path, expires,
    true, secure, httpOnly,
    maxAge, sameSite
  )))

template addCookie*(
    key, value: string,
    expires: DateTime | Time,
    domain = "", path = "",
    secure = true, httpOnly = true,
    maxAge = none(int),
    sameSite = SameSite.Default
  ) =
  ## Add cookie to response but requires the header to be available.
  headers.toBase.add(("Set-Cookie", cookies.setCookie(
    key, value,
    expires,
    domain, path,
    true,
    secure, httpOnly,
    maxAge, sameSite
  )))