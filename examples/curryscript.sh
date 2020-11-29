#!/usr/bin/env runcurry
#jit

import System.Environment ( getArgs )

main = do
  putStr "Run-time arguments: "
  getArgs >>= print
