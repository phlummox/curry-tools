--------------------------------------------------------------------------
--- This is the main module to start the executable of the analysis system.
---
--- @author Michael Hanus
--- @version June 2016
--------------------------------------------------------------------------

module Main(main) where

import Distribution   (stripCurrySuffix)
import FilePath       ((</>), (<.>))
import GetOpt
import ReadNumeric    (readNat)
import System         (exitWith,getArgs)

import AnalysisDoc    (getAnalysisDoc)
import AnalysisServer
import Configuration
import Registry

--- Main function to start the analysis system.
--- With option -s or --server, the server is started on a socket.
--- Otherwise, it is started in batch mode to analyze a single module.
main :: IO ()
main = do
  argv <- getArgs
  let (funopts, args, opterrors) = getOpt Permute options argv
  let opts = foldl (flip id) defaultOptions funopts
  unless (null opterrors)
         (putStr (unlines opterrors) >> putStr usageText >> exitWith 1)
  initializeAnalysisSystem
  when (optHelp opts) (printHelp args >> exitWith 1)
  when ((optServer opts && not (null args)) ||
        (not (optServer opts) && length args /= 2))
       (error "Illegal arguments (try `-h' for help)" >> exitWith 1)
  mapIO_ (\ (k,v) -> updateCurrentProperty k v) (optProp opts)
  let verb = optVerb opts
  when (verb >= 0) (updateCurrentProperty "debugLevel" (show verb))
  debugMessage 1 systemBanner
  if optServer opts
   then mainServer (let p = optPort opts in if p == 0 then Nothing else Just p)
   else let [ananame,mname] = args
         in if ananame `elem` registeredAnalysisNames
             then analyzeModuleAsText ananame (stripCurrySuffix mname)
                                      (optReAna opts) >>= putStrLn
             else error $ "Unknown analysis name `"++ ananame ++
                          "' (try `-h' for help)"

--------------------------------------------------------------------------
-- Representation of command line options.
data Options = Options
  { optHelp    :: Bool     -- print help?
  , optVerb    :: Int      -- verbosity level
  , optServer  :: Bool     -- start CASS in server mode?
  , optPort    :: Int      -- port number (if used in server mode)
  , optReAna   :: Bool     -- fore re-analysis?
  , optProp    :: [(String,String)] -- property (of ~/.curryanalsisrc) to be set
  }

-- Default command line options.
defaultOptions :: Options
defaultOptions = Options
  { optHelp    = False
  , optVerb    = -1
  , optServer  = False
  , optPort    = 0
  , optReAna   = False
  , optProp    = []
  }

-- Definition of actual command line options.
options :: [OptDescr (Options -> Options)]
options =
  [ Option "h?" ["help"]  (NoArg (\opts -> opts { optHelp = True }))
           "print help and exit"
  , Option "q" ["quiet"] (NoArg (\opts -> opts { optVerb = 0 }))
           "run quietly (no output)"
  , Option "v" ["verbosity"]
            (ReqArg (safeReadNat checkVerb) "<n>")
            "verbosity/debug level:\n0: quiet (same as `-q')\n1: show worker activity, e.g., timings\n2: show server communication\n3: ...and show read/store information\n4: ...show also stored/computed analysis data\n(default: see debugLevel in ~/.curryanalysisrc)"
  , Option "s" ["server"]
           (NoArg (\opts -> opts { optServer = True }))
           "start analysis system in server mode"
  , Option "p" ["port"]
           (ReqArg (safeReadNat (\n opts -> opts { optPort = n })) "<n>")
           "port number for communication\n(only for server mode;\n if omitted, a free port number is selected)"
  , Option "r" ["reanalyze"]
           (NoArg (\opts -> opts { optReAna = True }))
           "force re-analysis \n(i.e., ignore old analysis information)"
  , Option "D" []
            (ReqArg checkSetProperty "name=v")
           "set property (of ~/.curryanalysisrc)\n`name' as `v'"
  ]
 where
  safeReadNat opttrans s opts =
   let numError = error "Illegal number argument (try `-h' for help)" in
    maybe numError
          (\ (n,rs) -> if null rs then opttrans n opts else numError)
          (readNat s)

  checkVerb n opts = if n>=0 && n<5
                     then opts { optVerb = n }
                     else error "Illegal verbosity level (try `-h' for help)"

  checkSetProperty s opts =
    let (key,eqvalue) = break (=='=') s
     in if null eqvalue
         then error "Illegal property setting (try `-h' for help)"
         else opts { optProp = optProp opts ++ [(key,tail eqvalue)] }


--------------------------------------------------------------------------
-- Printing help:
printHelp :: [String] -> IO ()
printHelp args =
  if null args
   then putStrLn usageText
   else let aname = head args
         in getAnalysisDoc aname >>=
            maybe (putStrLn $
                     "Sorry, no documentation for analysis `" ++ aname ++ "'")
                  putStrLn

-- Help text
usageText :: String
usageText =
  usageInfo ("Usage: cass <options> <analysis name> <module name>\n" ++
             "   or: cass <options> [-s|--server]\n")
            options ++
  unlines ("" : "Registered analyses names:" :
           "(use option `-h <analysis name>' for more documentation)" :
           "" : map showAnaInfo registeredAnalysisInfos)
 where
  maxName = foldr1 max (map (length . fst) registeredAnalysisInfos)
  showAnaInfo (n,t) = n ++ take (maxName - length n) (repeat ' ') ++ ": " ++ t

--------------------------------------------------------------------------
