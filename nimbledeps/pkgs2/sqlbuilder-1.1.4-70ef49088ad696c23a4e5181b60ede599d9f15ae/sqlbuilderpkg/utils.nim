# Copyright Thomas T. Jarløv (TTJ) - ttj@ttj.dk


type
  ArgObj* = object ## Argument object
    val*: string
    isNull*: bool

  ArgsContainer* = object ## Argument container used for queries and args
    query*: seq[ArgObj]
    args*: seq[string]

  ArgsFormat = object
    use: bool
    column: string
    value: ArgObj

  SQLJoinType* = enum
    INNER
    LEFT
    RIGHT
    CROSS
    FULL

  SQLQueryType* = enum
    INSERT
    UPDATE

  SQLJoinObject* = ref object
    joinType*: SQLJoinType
    table*: string
    tableAs*: string
    on*: seq[string]


when defined(test):
  var testout*: string


const dbNullVal* = ArgObj(isNull: true) ## Global NULL value


proc argType*(v: ArgObj): ArgObj =
  ## Checks if a ``ArgObj`` is NULL and return
  ## ``dbNullVal``. If it's not NULL, the passed
  ## ``ArgObj`` is returned.
  if v.isNull:
    return dbNullVal
  else:
    return v


proc argType*(v: string | int): ArgObj =
  ## Transforms a string or int to a ``ArgObj``
  var arg: ArgObj
  arg.isNull = false
  arg.val = $v
  return arg


proc argTypeSetNull*(v: ArgObj): ArgObj =
  if v.isNull:
    return dbNullVal
  elif v.val.len() == 0:
    return dbNullVal
  else:
    return v


proc argTypeSetNull*(v: string | int): ArgObj =
  var arg: ArgObj
  if len($v) == 0:
    return dbNullVal
  else:
    arg.isNull = false
    arg.val = $v
    return arg


proc dbValOrNullString*(v: string | int): string =
  ## Return NULL obj if len() == 0, else return value obj
  if len($v) == 0:
    return ""
  return v


proc dbValOrNull*(v: string | int): ArgObj =
  ## Return NULL obj if len() == 0, else return value obj
  if len($v) == 0:
    return dbNullVal
  var arg: ArgObj
  arg.val = $v
  arg.isNull = false
  return arg


proc argFormat*(v: tuple): ArgsFormat =
  ## Formats the tuple, so int, float, bool, etc. can be used directly.
  result.use = v[0]
  result.column = v[1]
  result.value = argType(v[2])


template genArgs*[T](arguments: varargs[T, argType]): ArgsContainer =
  ## Create argument container for query and passed args. This allows for
  ## using NULL in queries.
  var argsContainer: ArgsContainer
  argsContainer.query = @[]
  argsContainer.args = @[]
  for arg in arguments:
    let argObject = argType(arg)
    if argObject.isNull:
      argsContainer.query.add(argObject)
    else:
      argsContainer.query.add(argObject)
      argsContainer.args.add(argObject.val)
  argsContainer


template genArgsSetNull*[T](arguments: varargs[T, argType]): ArgsContainer =
  ## Create argument container for query and passed args
  var argsContainer: ArgsContainer
  argsContainer.query = @[]
  argsContainer.args = @[]
  for arg in arguments:
    let argObject = argTypeSetNull(arg)
    if argObject.isNull:
      argsContainer.query.add(argObject)
    else:
      argsContainer.query.add(argObject)
      argsContainer.args.add(argObject.val)
  argsContainer


template genArgsColumns*[T](queryType: SQLQueryType, arguments: varargs[T, argFormat]): tuple[select: seq[string], args: ArgsContainer] =
  ## Create argument container for query and passed args and selecting which
  ## columns to update. It's and expansion of `genArgs()`, since you can
  ## decide which columns, there should be included.
  ##
  ##
  ## Lets say, that you are importing data from a spreadsheet with static
  ## columns, and you need to update your DB with the new values.
  ##
  ## If the spreadsheet contains an empty field, you can update your DB with the
  ## NULL value. But sometimes the spreadsheet only contains 5 out of the 10
  ## static columns. Now you don't know the values of the last 5 columns,
  ## which will result in updating the DB with NULL values.
  ##
  ## This template allows you to use the same query, but dynamic selecting only the
  ## columns which shall be updated. When importing your spreadsheet, check
  ## if the column exists (bool), and pass that as the `use: bool` param. If
  ## the column does not exists, it will be skipped in the query.
  ##
  ## The objects `ArgsFormat` is:
  ## (use: bool, column: string, value: ArgObj)
  var
    select: seq[string]
    argsContainer: ArgsContainer
  argsContainer.query = @[]
  argsContainer.args = @[]
  for arg in arguments:
    let argObject = argType(arg.value)
    if not arg.use:
      continue
    if (
      queryType == SQLQueryType.INSERT and
      (argObject.isNull or argObject.val.len() == 0)
    ):
      continue
    if arg.column != "":
      select.add(arg.column)
    if argObject.isNull or argObject.val.len() == 0:
      argsContainer.query.add(dbNullVal)
    else:
      argsContainer.query.add(argObject)
      argsContainer.args.add(argObject.val)
  (select, argsContainer)
