

import
  std/[
    exitprocs,
    parseopt,
    strutils,
    times
  ]

from std/cpuinfo import countProcessors
from std/os import getEnv
from std/strutils import toLowerAscii


import
  mummy, mummy/routers,
  mummy_utils,
  schedules

import
  ./src/database/database_connection,
  ./src/database/database_setup,
  ./src/database/database_testdata,
  ./src/email/email_channel,
  ./src/scheduling/check_schedule

import
  ./src/routes/routes_analytics,
  ./src/routes/routes_assets,
  ./src/routes/routes_contacts,
  ./src/routes/routes_errors,
  ./src/routes/routes_event,
  ./src/routes/routes_flows,
  ./src/routes/routes_lists,
  ./src/routes/routes_mail,
  ./src/routes/routes_main,
  ./src/routes/routes_optin,
  ./src/routes/routes_profile,
  ./src/routes/routes_settings,
  ./src/routes/routes_subscriptions,
  ./src/routes/routes_users,
  ./src/routes/routes_webhooks_sns

var
  scheduleThread: Thread[void]

#
# Add routes
#
var routerMain*: Router

# Error handlers - registered unconditionally so both dev and release builds
# return consistent, safe responses for unmatched routes and panics.
routerMain.notFoundHandler = routeCustom404
routerMain.methodNotAllowedHandler = routeCustom404
routerMain.errorHandler = routeErrorHandler

for r in mainRouter.routes:
  routerMain.routes.add(r)

for r in analyticsRouter.routes:
  routerMain.routes.add(r)

for r in assetRouter.routes:
  routerMain.routes.add(r)

for r in contactsRouter.routes:
  routerMain.routes.add(r)

for r in eventRouter.routes:
  routerMain.routes.add(r)

for r in flowsRouter.routes:
  routerMain.routes.add(r)

for r in listsRouter.routes:
  routerMain.routes.add(r)

for r in mailRouter.routes:
  routerMain.routes.add(r)

for r in optinRouter.routes:
  routerMain.routes.add(r)

for r in profileRouter.routes:
  routerMain.routes.add(r)

for r in settingsRouter.routes:
  routerMain.routes.add(r)

for r in subscriptionsRouter.routes:
  routerMain.routes.add(r)

for r in usersRouter.routes:
  routerMain.routes.add(r)

for r in webhooksSnsRouter.routes:
  routerMain.routes.add(r)



proc scheduleStart() {.thread.} =
  echo "Starting thread: scheduling"
  {.gcsafe.}:
    schedules:
      every(seconds=60, id="tick", throttle=2):
        echo "Schedule check: " & $now() & " on thread " & $getThreadId()
        checkAndSendScheduledEmails(minutesBack = 2, until = now())

      # 24 hours
      #every(minutes=30, id="tick", throttle=2):
      cron(minute="10", hour="0", day_of_month="*", month="*", day_of_week="*", id="backup"):
        echo "Backup schedule check: " & $now() & " on thread " & $getThreadId()
        checkAndSendScheduledEmails(minutesBack = (25 * 60), until = now() - initDuration(minutes = 59), isBackupRun = true)



when isMainModule:
  echo "Starting thread: nimletter"

  for kind, key, val in getOpt():
    echo "[" & ($now())[0..18] & "] - CLI_RUN: running on"

    case kind
    of cmdShortOption, cmdLongOption:

      case key
      of "v", "version":
        echo "\nVersion: "
        quit(0)

      of "h", "help":
        echo "\nHelp yourself bro"
        quit(0)

      of "TESTING_BUILD_AND_QUIT":
        echo "TESTING_BUILD_AND_QUIT #1"
        quit(0)

      of "DELETE_DATABASE":
        echo "DELETE_DATABASE"
        databaseDelete()
        quit(0)

      of "CREATE_DATABASE":
        echo "CREATE_DATABASE"
        databaseCreate()
        quit(0)

      of "INSERT_TESTDATA":
        echo "INSERT_TESTDATA"
        insertTestData()
        quit(0)

      # of "INSERT_TESTDATA_CLICKOPEN":
      #   echo "INSERT_TESTDATA_CLICKOPEN"
      #   insertTestData()
      #   quit(0)

      of "DEV_RESET":
        echo "DEV_RESET"
        databaseDelete()
        databaseCreate()
        insertTestData()
        quit(0)

      of "FORCE_SCHEDULE_RUN":
        echo "FORCE_SCHEDULE_RUN"
        checkAndSendScheduledEmails()
        quit(0)

      of "FORCE_SCHEDULE_RUN_43200":
        echo "FORCE_SCHEDULE_RUN_43200 (30 days)"
        checkAndSendScheduledEmails(minutesBack = 43200)
        quit(0)

      of "CREATE_DATABASE_AND_INSERT_TESTDATA":
        databaseCreate()
        insertTestData()

      else:
        echo "Unknown option: " & key
        quit(1)

    else:
      echo "Unknown option: " & key
      quit(1)

  if getEnv("TESTING_BUILD_AND_QUIT").toLowerAscii() == "true":
    echo "TESTING_BUILD_AND_QUIT #2"
    quit(0)



  #
  # Mailing thread
  #
  mailChannel.open()
  createThread mailThread, mailPendingEmails

  addExitProc(proc() =
    joinThreads mailThread
  )


  #
  # Scheduling thread
  #
  createThread scheduleThread, scheduleStart

  addExitProc(proc() =
    joinThreads scheduleThread
  )


  #
  # Start server
  #
  let server = newServer(
        routerMain,
        workerThreads = (when defined(dev): 4 else: max(countProcessors() * 20, 4)),
        maxBodyLen = 1024 * 1024 * 30, # 30 MB
      )

  echo "\n=> nimletter up and running on port 5555\n"

  server.serve(Port(parseInt(getEnv("LISTEN_PORT", "5555"))), address = getEnv("LISTEN_IP", "0.0.0.0"))
