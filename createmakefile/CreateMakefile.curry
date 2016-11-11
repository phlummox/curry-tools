-----------------------------------------------------------------
--- A tool to create a simple makefile for a Curry application.
---
--- @author Michael Hanus
--- @version November 2016
-----------------------------------------------------------------

module CreateMakefile where

import Distribution
import FileGoodies
import FlatCurry.Types
import FlatCurry.Files
import FlatCurry.Read
import List
import System

main :: IO ()
main = do
  args <- getArgs
  case args of
    ["-h"]     -> printUsage
    ["--help"] -> printUsage
    ["-?"]     -> printUsage
    [mainmod] -> createMake (stripCurrySuffix mainmod) Nothing
    [mainmod,target] -> createMake (stripCurrySuffix mainmod) (Just target)
    _ -> do putStrLn $ "ERROR: Illegal arguments: " ++
                       concat (intersperse " " args) ++ "\n"
            printUsage
            exitWith 1

printUsage :: IO ()
printUsage = putStrLn $ unlines
  [ "A tool to create a simple makefile for a Curry application"
  , ""
  , "Usage: curry createmake <main_module_name>\n"
  , "   or: curry createmake <main_module_name> <makefile>"
  ]

-- Create a simple makefile for a main module:
createMake :: String -> Maybe String -> IO ()
createMake mainmod target = do
  allints <- readFlatCurryIntWithImports mainmod
  let allmods = (foldl union [mainmod]
                       (map (\ (Prog _ imps _ _ _) -> imps) allints))
  allsources <- mapIO findSourceFileInLoadPath (filter (/="Prelude") allmods)
  (maybe putStr writeFile target)
     (showMake mainmod (map replacePakcsLib allsources))

showMake :: String -> [String] -> String
showMake mainmod sourcefiles =
  "# Makefile for main module \""++mainmod++"\":\n\n"++
  "CURRYHOME="++installDir++"\n"++
  "CURRYLIB=$(CURRYHOME)/lib\n\n"++
  ".PHONY: all\n"++
  "all: "++mainmod++"\n\n"++
  mainmod++": " ++ concat (intersperse " \\\n\t  " sourcefiles) ++"\n"++
  "\t# create saved state for top-level function \"main\":\n"++
  "\t$(CURRYHOME)/bin/"++curryCompiler++" :l "++mainmod++" :save :q\n\n"++
  ".PHONY: clean\n"++
  "clean:\n\t$(CURRYHOME)/bin/cleancurry\n"

-- add a directory name for a Curry source file by looking up the
-- current load path (CURRYPATH):
findSourceFileInLoadPath :: String -> IO String
findSourceFileInLoadPath modname = do
  loadpath <- getLoadPathForModule modname
  mbfname <- lookupFileInPath (baseName modname) [".lcurry",".curry"] loadpath
  maybe (error ("Curry file for module \""++modname++"\" not found!"))
        (return . dropLocal)
        mbfname
 where
  dropLocal f = if take 2 f == "./" then drop 2 f else f

-- replace CURRY lib directory prefix in a filename by $(CURRYLIB):
replacePakcsLib :: String -> String
replacePakcsLib filename =
  let pakcslib = installDir++"/lib"
      pllength = length pakcslib
   in if take pllength filename == pakcslib
      then "$(CURRYLIB)" ++ drop pllength filename
      else filename
