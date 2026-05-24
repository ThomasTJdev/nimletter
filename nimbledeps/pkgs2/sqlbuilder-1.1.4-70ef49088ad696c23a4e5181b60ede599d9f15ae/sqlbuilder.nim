# Copyright 2019 - Thomas T. Jarløv





import sqlbuilderpkg/insert
export insert

import sqlbuilderpkg/update
export update

import sqlbuilderpkg/delete
export delete

import sqlbuilderpkg/select
export select

# import sqlbuilderpkg/select_legacy
# export select_legacy

import sqlbuilderpkg/totypes
export totypes

import sqlbuilderpkg/utils
export utils



#[
when isMainModule:
  from times import epochTime
  let a = epochTime()
  for i in countup(0,100000):
    let a = sqlSelectMacro("myTable", ["id", "name", "j"], [""], ["email =", "name ="], "", "", "")

  let b = epochTime()

  let c = epochTime()
  for i in countup(0,100000):
    let a = sqlSelect("myTable", ["id", "name", "j"], [""], ["email =", "name ="], "", "", "")

  let d = epochTime()

  echo "Select:"
  echo "Macro:  " & $(b-a)
  echo "Normal: " & $(d-c)
  echo "Diff:   " & $((d-c) - (b-a))

  echo "\n\n"


  let im1 = epochTime()
  for i in countup(0,100000):
    let a = sqlInsertMacro("myTable", ["id", "name", "j"])

  let im2 = epochTime()

  let ip1 = epochTime()
  for i in countup(0,100000):
    let a = sqlInsert("myTable", ["id", "name", "j"])

  let ip2 = epochTime()

  echo "Update:"
  echo "Macro:  " & $(im2-im1)
  echo "Normal: " & $(ip2-ip1)
  echo "Diff:   " & $((ip2-ip1) - (im2-im1))

  echo "\n\n"


  let um1 = epochTime()
  for i in countup(0,100000):
    let a = sqlUpdateMacro("myTable", ["id", "name", "j"], ["id", "session"])

  let um2 = epochTime()

  let up1 = epochTime()
  for i in countup(0,100000):
    let a = sqlUpdate("myTable", ["id", "name", "j"], ["id", "session"])

  let up2 = epochTime()

  echo "Update:"
  echo "Macro:  " & $(um2-um1)
  echo "Normal: " & $(up2-up1)
  echo "Diff:   " & $((up2-up1) - (um2-um1))

  echo "\n\n"


  let dm1 = epochTime()
  for i in countup(0,100000):
    let a = sqlDeleteMacro("myTable", ["id", "name", "j"])

  let dm2 = epochTime()

  let dp1 = epochTime()
  for i in countup(0,100000):
    let a = sqlDelete("myTable", ["id", "name", "j"])

  let dp2 = epochTime()

  echo "Delete:"
  echo "Macro:  " & $(dm2-dm1)
  echo "Normal: " & $(dp2-dp1)
  echo "Diff:   " & $((dp2-dp1) - (dm2-dm1))

]#