#!/usr/bin/env runcurry
#jit

import System(getArgs)

main = do
  putStr "Run-time arguments: "
  getArgs >>= print
