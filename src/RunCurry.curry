---------------------------------------------------------------------------
--- This program implements the `runcurry` command that allows
--- to run a Curry program without explicitly invoking the REPL.
---
--- Basically, it has three modes of operation:
--- * execute the main operation of a Curry program whose file name
---   is provided as an argument
--- * execute the main operation of a Curry program whose program text
---   comes from the standard input
--- * execute the main operation of a Curry program whose program text
---   is in a script file (starting with `#!/usr/bin/env runcurry`).
---   If the script file contains the line `#jit`, it is compiled
---   and saved as an executable so that it is faster executed
---   when called the next time.
---
--- Note that the `runcurry` command is intended to compile simple
--- Curry programs which use only base libraries but not other
--- Curry packages.
--- Otherwise, one has to adapt the constant `replOpts` below.
---
--- @author Michael Hanus
--- @version March 2024
---------------------------------------------------------------------------

import Control.Monad               ( unless )
import Curry.Compiler.Distribution ( installDir )
import Data.Char                   ( isSpace )
import Data.List                   ( partition )
import System.Environment          ( getArgs )
import System.IO                   ( getContents, hFlush, stdout )

import System.CurryPath    ( setCurryPath, stripCurrySuffix )
import System.Directory
import System.FilePath     ( (<.>), (</>), isRelative, takeExtension )
import System.Process      ( exitWith, getPID, system )

---------------------------------------------------------------------------
-- The default options for the REPL of the Curry system: quiet compilation
-- and no use of the Curry package manager.
-- If the actual Curry system has different options, this constant
-- should be adapted.
-- The option `--nocypm` is set since the CURRYPATH is explicitly set
-- (by `setCurryPath`) before the runner starts.
replOpts :: String
replOpts = "--nocypm :set v0 :set parser -Wnone :set -time"

---------------------------------------------------------------------------

main :: IO ()
main = do
  args <- getArgs
  case args of
    ("-h":_)     -> putStrLn usageMsg
    ("--help":_) -> putStrLn usageMsg
    ("-?":_)     -> putStrLn usageMsg
    _            -> do setCurryPath True ""
                       checkFirstArg [] args

-- Usage message:
usageMsg :: String
usageMsg = unlines $
  ["Usage:"
  ,""
  ,"As a shell command:"
  ,"> runcurry [Curry system options] <Curry program name> <run-time arguments>"
  ,""
  ,"As a shell script: start script with"
  ,"#!/usr/bin/env runcurry"
  ,"...your Curry program defining operation 'main'..."
  ,""
  ,"In interactive mode:"
  ,"> runcurry"
  ,"...type your Curry program until end-of-file..."
  ]

-- Check whether runcurry is called in script mode, i.e., the argument
-- is not a Curry program but an existing file:
checkFirstArg :: [String] -> [String] -> IO ()
checkFirstArg curryargs [] = do
  -- no program argument provided, use remaining input as program:
  putStrLn "Type in your program with an operation 'main':"
  hFlush stdout
  progname <- getNewProgramName
  getContents >>= writeFile progname
  execAndDeleteCurryProgram progname curryargs [] >>= exitWith
checkFirstArg curryargs (arg1:args) =
  if takeExtension arg1 `elem` [".curry",".lcurry"]
  then execCurryProgram arg1 curryargs args >>= exitWith
  else do
    isexec <- isExecutable arg1
    if isexec
     then do
       -- argument is not a Curry file but it is an executable, hence, a script:
       -- store it in a Curry program, where lines starting with '#' are removed
       progname <- getNewProgramName
       proginput <- readFile arg1
       let (proglines, hashlines) = partition noHashLine (lines proginput)
           progtext = unlines proglines
       if any isHashJITOption hashlines
        then execOrJIT arg1 progname progtext curryargs args >>= exitWith
        else do
          writeFile progname progtext
          execAndDeleteCurryProgram progname curryargs args >>= exitWith
     else checkFirstArg (curryargs ++ [arg1]) args

-- Execute an already compiled binary (if it is newer than the first file arg)
-- or compile the program and execute the binary:
execOrJIT :: String -> String -> String -> [String] -> [String] -> IO Int  
execOrJIT scriptfile progname progtext curryargs rtargs = do
  let binname = if isRelative scriptfile
                  then "." </> scriptfile <.> "bin"
                  else scriptfile <.> "bin"
  binexists <- doesFileExist binname
  binok <- if binexists
             then do
               stime <- getModificationTime scriptfile
               btime <- getModificationTime binname
               return (btime>stime)
            else return False
  if binok
   then do
     ec <- system $ unwords $ binname : rtargs
     if ec==0
      then return 0
      else -- An error occurred with the old binary, hence we try to re-compile:
           compileAndExec binname
   else compileAndExec binname
 where
  compileAndExec binname = do
    writeFile progname progtext
    ec <- saveCurryProgram progname curryargs binname
    if ec==0 then system $ unwords $ binname : rtargs
             else return ec

-- Is a hash line a JIT option, i.e., of the form "#jit"?
isHashJITOption :: String -> Bool
isHashJITOption s = stripSpaces (tail s) == "jit"

noHashLine :: String -> Bool
noHashLine [] = True
noHashLine (c:_) = c /= '#'

-- Generates a new program name for temporary program:
getNewProgramName :: IO String
getNewProgramName = do
  pid <- getPID
  genNewProgName ("RUNCURRY_" ++ show pid)
 where
  genNewProgName name = do
    let progname = name ++ ".curry"
    exname <- doesFileExist progname
    if exname then genNewProgName (name ++ "_0")
              else return progname

-- Is the argument the name of an executable file?
isExecutable :: String -> IO Bool
isExecutable fname = do
  fexists <- doesFileExist fname
  if fexists
    then do ec <- system $ "test -x " ++ fname
            return (ec==0)
    else return False            

-- Saves a Curry program with given Curry system arguments into a binary
-- (last argument) and delete the program after the compilation:
saveCurryProgram :: String -> [String] -> String -> IO Int
saveCurryProgram progname curryargs binname = do
  ec <- system $ installDir </> "bin" </> "curry " ++ replOpts ++ " " ++
                 unwords curryargs ++ " :load " ++ progname ++
                 " :save :quit"
  unless (ec/=0) $ renameFile (stripCurrySuffix progname) binname
  system $ installDir </> "bin" </> "cleancurry" ++ " " ++ progname
  removeFile progname
  return ec

-- Executes a Curry program with given Curry system arguments and
-- run-time arguments:
execCurryProgram :: String -> [String] -> [String] -> IO Int  
execCurryProgram progname curryargs rtargs = system $
  installDir </> "bin" </> "curry " ++ replOpts ++ " " ++
  unwords curryargs ++ " :load " ++ progname ++
  " :set args " ++ unwords rtargs ++ " :eval main :quit"

-- Executes a Curry program with given Curry system arguments and
-- run-time arguments and delete the program after the execution:
execAndDeleteCurryProgram :: String -> [String] -> [String] -> IO Int
execAndDeleteCurryProgram progname curryargs rtargs = do
  ec <- execCurryProgram progname curryargs rtargs
  system $ installDir </> "bin" </> "cleancurry " ++ progname
  removeFile progname
  return ec

-- Strips leading and tailing spaces:
stripSpaces :: String -> String
stripSpaces = reverse . dropWhile isSpace . reverse . dropWhile isSpace
