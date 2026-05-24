
proc modHexEncode*(input: string): string =
  ## Input: 0 1 2 3 4 5 6 7 8 9 a b c d e f
  ## Result: c b d e f g h i j k l n r t u v
  #
  runnableExamples:
    modHexEncode("0123456789abcdef") == "cbdefghijklnrtuv"
    modHexEncode()

  for i in 0 .. input.len - 1:
    case input[i]
    of '0': result.add("c")
    of '1': result.add("b")
    of '2': result.add("d")
    of '3': result.add("e")
    of '4': result.add("f")
    of '5': result.add("g")
    of '6': result.add("h")
    of '7': result.add("i")
    of '8': result.add("j")
    of '9': result.add("k")
    of 'a': result.add("l")
    of 'b': result.add("n")
    of 'c': result.add("r")
    of 'd': result.add("t")
    of 'e': result.add("u")
    of 'f': result.add("v")
    else: discard


proc modHexDecode*(input: string): string =
  ## Input: c b d e f g h i j k l n r t u v
  ## Result: 0 1 2 3 4 5 6 7 8 9 a b c d e f
  #
  runnableExamples:
    modHexDecode("cbdefghijklnrtuv") == "0123456789abcdef"
    modHexDecode()

  for i in 0 .. input.len - 1:
    case input[i]
    of 'c': result.add("0")
    of 'b': result.add("1")
    of 'd': result.add("2")
    of 'e': result.add("3")
    of 'f': result.add("4")
    of 'g': result.add("5")
    of 'h': result.add("6")
    of 'i': result.add("7")
    of 'j': result.add("8")
    of 'k': result.add("9")
    of 'l': result.add("a")
    of 'n': result.add("b")
    of 'r': result.add("c")
    of 't': result.add("d")
    of 'u': result.add("e")
    of 'v': result.add("f")
    else: discard
