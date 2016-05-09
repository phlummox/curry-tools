-----------------------------------------------------------------------------
--- Translator for Curry programs to implement default rules
--- and deterministic functions.
---
--- @author Michael Hanus
--- @version January 2016
-----------------------------------------------------------------------------

import AbstractCurry.Types
import AbstractCurry.Files
import AbstractCurry.Select
import AbstractCurry.Build
import AbstractCurry.Pretty
import Char(isDigit,digitToInt)
import DefaultRuleUsage
import Directory
import Distribution
import List(isPrefixOf,isSuffixOf,partition)
import System

--------------------------------------------------------------------

banner :: String
banner = unlines [bannerLine,bannerText,bannerLine]
 where
   bannerText =
     "Transformation Tool for Curry with Default Rules (Version of 19/01/16)"
   bannerLine = take (length bannerText) (repeat '=')

------------------------------------------------------------------------
-- Data type for transformation parameters
data TParam = TParam TransScheme -- translation scheme to be used
                     Int         -- verbosity level
                     Bool        -- compile the transformed program?
                     Bool        -- load and execute transformed program?

-- Available translation schemes
data TransScheme = SpecScheme -- as specified in the PADL'16 paper
                 | NoDupScheme -- scheme without checking conditions twice

-- The default translation scheme:
defaultTransScheme :: TransScheme
defaultTransScheme = if curryCompiler == "kics2"
                     then SpecScheme -- due to bug in KiCS2
                     else SpecScheme -- NoDupScheme

defaultTParam :: TParam
defaultTParam = TParam defaultTransScheme 1 False False

setScheme :: TransScheme -> TParam -> TParam
setScheme scm (TParam _ vl cmp ep) = TParam scm vl cmp ep

setVerbosity :: Int -> TParam -> TParam
setVerbosity vl (TParam scm _ cmp ep) = TParam scm vl cmp ep

setRunQuiet :: TParam -> TParam
setRunQuiet = setVerbosity 0

setCompile :: TParam -> TParam
setCompile (TParam scm vl _ ep) = TParam scm vl True ep

setExec :: TParam -> TParam
setExec  (TParam scm vl _ _) = TParam scm vl True True

------------------------------------------------------------------------

main :: IO ()
main = do
  args <- getArgs
  processArgs defaultTParam args
 where
  processArgs tparam args = case args of
     ["-h"]          -> putStrLn $ banner ++ usageInfo
     ("-q":moreargs) -> processArgs (setRunQuiet  tparam) moreargs
     ("-c":moreargs) -> processArgs (setCompile   tparam) moreargs
     ("-r":moreargs) -> processArgs (setExec      tparam) moreargs
     [mname]         -> transMain tparam (stripCurrySuffix mname)
     _               -> printError args

  -- process the further options of the preprocesser mode:
  processOptions tparam optargs = case optargs of
    []             -> Just tparam
    ("-v":opts)    -> processOptions (setVerbosity 2 tparam) opts
    (['-','v',vl]:opts) ->
       if isDigit vl
         then processOptions (setVerbosity (digitToInt vl) tparam) opts
         else Nothing
    (scheme:opts) ->
       if scheme == "nodupscheme"
       then processOptions (setScheme NoDupScheme tparam) opts
       else if scheme == "specscheme"
            then processOptions (setScheme SpecScheme tparam) opts
            else Nothing

  printError args =
    putStrLn $ banner ++
               "ERROR: Illegal arguments for transformation:\n" ++
               unwords args ++ "\n" ++ usageInfo

usageInfo :: String
usageInfo =
  "Usage: ... [-q|-c|-r] <module_name>\n"++
  "-q : work quietly\n"++
  "-c : compile the transformed program\n"++
  "-r : load the transformed program into "++curryCompiler++" (implies -c)\n"

------------------------------------------------------------------------
-- Transformation in "batch" mode:
transMain :: TParam -> String -> IO ()
transMain (TParam scm verbosity compile execprog) progname = do
  let quiet = verbosity == 0
      progfname = progname ++ ".curry"
      saveprogfname = progname++"_ORG.curry"
      transprogfname = progname++"_TRANS.curry"
      putStrNQ s = if quiet then done else putStr s
      putStrLnNQ s = if quiet then done else putStrLn s
  putStrNQ banner
  prog <- readUntypedCurry progname
  system $ "cleancurry " ++ progname
  transprog <- translateProg scm prog >>= return . showCProg . snd
  putStrLnNQ "Transformed module:"
  putStrLnNQ transprog
  if not compile then done else do
    renameFile progfname saveprogfname
    writeFile progfname transprog
    compileAcyFcy quiet progname
    renameFile progfname transprogfname
    renameFile saveprogfname progfname
    putStrLnNQ $ "Transformed program written into '"++transprogfname++"'"
    if not execprog then done else do
      system $ "mate-terminal -x "++installDir++"/bin/curry :l "++progname
      done

compileAcyFcy :: Bool -> String -> IO ()
compileAcyFcy quiet progname = do
  params <- rcParams >>= return . setQuiet quiet
  callFrontendWithParams ACY params progname
  callFrontendWithParams FCY params progname

------------------------------------------------------------------------
-- Start default rules transformation in "preprocessor mode".
-- The Curry program must be read with readUntypedCurry in order to
-- process DET annotations!
transDefaultRules :: Int -> [String] -> String -> CurryProg -> IO CurryProg
transDefaultRules verb moreopts _ inputProg = do
  when (verb>1) $ putStr banner
  trscm <- processOpts moreopts
  when (verb>1) $ putStrLn ("Translation scheme: " ++ show trscm)
  (detfuncnames,newprog) <- translateProg trscm inputProg
  when (verb>0) $ printProofObligation detfuncnames
  return newprog
 where
  processOpts opts = case opts of
    []       -> return defaultTransScheme
    [scheme] ->
       if scheme == "nodupscheme"
       then if curryCompiler == "kics2"
            then return SpecScheme -- due to bug in KiCS2!!!
            else return NoDupScheme
       else if scheme == "specscheme"
            then return SpecScheme
            else showError
    _ -> showError
   where
    showError = do
      putStrLn $ "Unknown options (ignored): " ++ unwords opts
      return defaultTransScheme

printProofObligation :: [QName] -> IO ()
printProofObligation qfs = unless (null qfs) $ do
  putStrLn line
  putStrLn "PROOF OBLIGATIONS:"
  mapIO_ (\ (q,f) -> putStrLn (q++"."++f++" is a deterministic operation.")) qfs
  putStrLn line
 where
  line = take 70 (repeat '=')

------------------------------------------------------------------------
-- Main transformation: transform a Curry program with default rules
-- and deterministic functions into a new Curry program where these
-- features are implemented by standard Curry features.
-- Moreover, the list of deterministic functions is returned
-- (to show the proof obligations to ensure completeness of the
-- transformation).

translateProg :: TransScheme -> CurryProg -> IO ([QName],CurryProg)
translateProg trscm prog@(CurryProg mn imps tdecls fdecls ops) = do
  let usageerrors = checkDefaultRules prog
  unless (null usageerrors) $ do
    putStr (unlines $ "ERROR: ILLEGAL USE OF DEFAULT RULES:" :
               map (\ ((mn,fn),err) -> fn ++ " (module " ++ mn ++ "): " ++ err)
                   usageerrors)
    error "Transformation aborted"
  -- now we do not have to check the correct usage of default rules...
  return $ if null deffuncs && null detfuncnames
            then ([],prog)
            else (detfuncnames, CurryProg mn newimports tdecls newfdecls ops)
 where
  newimports       = if setFunMod `elem` imps then imps else setFunMod:imps
  detfuncnames     = map funcName (filter isDetFun fdecls)
  undetfuncs       = concatMap (transDetFun detfuncnames) fdecls
  (deffuncs,funcs) = partition isDefaultFunc undetfuncs
  defrules         = map (func2rule funcs) deffuncs
  newfdecls        = concatMap (transFDecl trscm defrules) funcs

------------------------------------------------------------------------
-- implementation of deterministic function transformation:

-- Is the function declaration marked as a deterministic function?
isDetFun :: CFuncDecl -> Bool
isDetFun (CmtFunc _ qf ar vis texp rules) =
  isDetFun (CFunc qf ar vis texp rules)
isDetFun (CFunc _ _ _ texp _) = hasDetResultType texp
  where
   hasDetResultType (CTVar _) = False
   hasDetResultType (CFuncType _ rt) = hasDetResultType rt
   hasDetResultType (CTCons tc _) = tc == pre "DET"

-- translate a function (where the names of all deterministic functions
-- is provided as a first argument):
transDetFun :: [QName] -> CFuncDecl -> [CFuncDecl]
transDetFun detfnames (CmtFunc _ qf ar vis texp rules) =
  transDetFun detfnames (CFunc qf ar vis texp rules)
transDetFun detfnames fdecl@(CFunc qf@(mn,fn) ar vis texp rules)
 | qf `elem` detfnames
 = [CFunc qf ar vis (removeDetResultType texp) [newdetrule],
    CFunc neworgname ar Private (removeDetResultType texp) rules]
 | isDefaultFunc fdecl && (mn, fromDefaultName fn) `elem` detfnames
  -- rename default rule of a deterministic function:
 = [CFunc (mn, fromDefaultName fn ++ orgsuffix ++ "'default") ar vis texp rules]
 | otherwise = [fdecl]
 where
  -- new name for original function (TODO: check for unused name)
  neworgname = (mn,fn++orgsuffix)
  orgsuffix = "_ORGNDFUN"

  newdetrule =
    CRule (map CPVar argvars)
          (CSimpleRhs (applyF (setFunMod, "selectValue")
                              [applyF (setFunMod, "set"++show ar)
                                      (CSymbol neworgname : map CVar argvars)])
                      [])

  argvars = map (\i->(i,"x"++show i)) [1..ar]

removeDetResultType :: CTypeExpr -> CTypeExpr
removeDetResultType tv@(CTVar _) = tv
removeDetResultType (CFuncType t1 t2) =
  CFuncType (removeDetResultType t1) (removeDetResultType t2)
removeDetResultType (CTCons tc texps) =
  if tc == pre "DET"
  then head texps
  else CTCons tc (map removeDetResultType texps)


------------------------------------------------------------------------
-- implementation of default rule transformation:

-- Extract the arity and default rule for a default function definition:
func2rule :: [CFuncDecl] -> CFuncDecl -> (QName,(Int,CRule))
func2rule funcs (CFunc (mn,fn) ar _ _ rules) =
  ((mn, fromDefaultName fn), (ar, head rules))
func2rule funcs (CmtFunc _ qf ar vis texp rules) =
  func2rule funcs (CFunc qf ar vis texp rules)

-- Translates a function declaration into a new one that respects
-- the potential default rule (the second argument contains
-- the list of all default rules).
transFDecl :: TransScheme -> [(QName,(Int,CRule))] -> CFuncDecl -> [CFuncDecl]
transFDecl trscm defrules (CmtFunc _ qf ar vis texp rules) =
  transFDecl trscm defrules (CFunc qf ar vis texp rules)
transFDecl trscm defrules fdecl@(CFunc qf@(mn,fn) ar vis texp rules) =
  maybe [fdecl]
        (\ (dar,defrule) ->
             if trscm == SpecScheme
             then [CFunc neworgname ar Private texp rules,
                   transFDecl2ApplyCond applyname fdecl,
                   CFunc deffunname ar Private texp
                         [transDefaultRule applyname ar defrule],
                   CFunc qf ar vis texp [neworgrule_SpecScheme]]
             else -- trscm == NoDupScheme
                  [transFDecl2FunRHS applyname fdecl,
                   CFunc deffunname ar Private texp [defrule],
                   CFunc qf ar vis texp [neworgrule_NoDupScheme]]
        )
        (lookup qf defrules)
 where
  -- new names for auxiliary functions (TODO: check for unused name)
  neworgname = (mn,fn++"_ORGRULES")
  applyname  = (mn,fn++"_APPLICABLE")
  deffunname = (mn,fn++"_DEFAULT")

  neworgrule_SpecScheme =
    CRule (map CPVar argvars)
          (CSimpleRhs (applyF (pre "?")
                              [applyF neworgname (map CVar argvars),
                               applyF deffunname (map CVar argvars)])
                      [])

  neworgrule_NoDupScheme =
    CRule (map CPVar argvars)
          (CSimpleRhs
             (CLetDecl [CLocalPat (CPVar (0,"x0"))
                         (CSimpleRhs
                            (applyF (setFunMod,"set"++show ar)
                                    (CSymbol applyname : map CVar argvars))
                            [])]
                       (applyF (pre "if_then_else")
                          [applyF (setFunMod,"isEmpty") [CVar (0,"x0")],
                           applyF deffunname (map CVar argvars),
                           applyF (setFunMod,"chooseValue")
                                  [CVar (0,"x0"), preUnit]]))
             [])

  argvars = map (\i->(i,"x"++show i)) [1..ar]

-- Translates a function declaration into one where the right-hand side
-- is always Prelude.(), i.e., it just checks for applicability.
-- The first argument is the new name of the translated function.
transFDecl2ApplyCond :: QName -> CFuncDecl -> CFuncDecl
transFDecl2ApplyCond nqf (CmtFunc _ qf ar vis texp rules) =
  transFDecl2ApplyCond nqf (CFunc qf ar vis texp rules)
transFDecl2ApplyCond nqf (CFunc _ ar _ texp rules) =
  CFunc nqf ar Private (adjustResultTypeToUnit texp) (map rule2cond rules)
 where
  rule2cond (CRule rpats (CSimpleRhs _ rlocals)) =
    let singlepatvars = extractSingles (concatMap varsOfPat rpats ++
                                        concatMap varsOfLDecl rlocals)
     in CRule (map (anonymPat singlepatvars) rpats)
              (CSimpleRhs preUnit rlocals)
  rule2cond (CRule rpats (CGuardedRhs gds rlocals)) =
    let singlepatvars = extractSingles (concatMap varsOfPat rpats ++
                                        concatMap (varsOfExp . fst) gds ++
                                        concatMap varsOfLDecl rlocals)
     in CRule (map (anonymPat singlepatvars) rpats)
              (CGuardedRhs (map (\gd -> (fst gd,preUnit)) gds) rlocals)

-- Adjust the result type of a type by setting the result type to ():
adjustResultTypeToUnit :: CTypeExpr -> CTypeExpr
adjustResultTypeToUnit texp =
  if texp == preUntyped
  then texp
  else case texp of
         CFuncType te1 te2 -> CFuncType te1 (adjustResultTypeToUnit te2)
         _                 -> unitType

-- Translates a function declaration into one where the right-hand side
-- is encapsulated in a unary function, i.e., it just checks for applicability
-- and can later be applied to evaluate its right-hand side.
-- The first argument is the new name of the translated function.
transFDecl2FunRHS :: QName -> CFuncDecl -> CFuncDecl
transFDecl2FunRHS nqf (CmtFunc _ qf ar vis texp rules) =
  transFDecl2FunRHS nqf (CFunc qf ar vis texp rules)
transFDecl2FunRHS nqf (CFunc _ ar _ texp rules) =
  CFunc nqf ar Private (adjustResultTypeToFunRHS texp) (map rule2funrhs rules)
 where
  rule2funrhs (CRule rpats (CSimpleRhs rhsexp rlocals)) =
     CRule rpats
           (CSimpleRhs (CLambda [CPVar (999,"_")] rhsexp) rlocals)
  rule2funrhs (CRule rpats (CGuardedRhs gds rlocals)) =
    CRule rpats
          (CGuardedRhs
             (map (\ (gd,rhs) -> (gd,(CLambda [CPVar (999,"_")] rhs))) gds)
             rlocals)

-- Adjust the result type of a type by setting the result type to ():
adjustResultTypeToFunRHS :: CTypeExpr -> CTypeExpr
adjustResultTypeToFunRHS texp =
  if texp == preUntyped
  then texp
  else case texp of
         CFuncType te1 te2 -> CFuncType te1 (adjustResultTypeToFunRHS te2)
         _                 -> CFuncType unitType texp

transDefaultRule :: QName -> Int -> CRule -> CRule
transDefaultRule _ _ (CRule _ (CGuardedRhs _ _)) =
  error "Cannot yet transform guarded default rules!"
transDefaultRule condfunname ar (CRule pats (CSimpleRhs exp locals)) =
  CRule newpats (CGuardedRhs [(checkCond,exp)] locals)
 where
  checkCond = applyF (setFunMod,"isEmpty")
                     [applyF (setFunMod,"set"++show ar)
                             (CSymbol condfunname : args)]

  (newpats,args) = unzip (map arg2patexp (zip [1001..] pats))
  
  arg2patexp (i,pat) = case pat of
    CPVar v     -> if snd v=="_"
                     then let newvar = (i,"patvar_"++show i)
                           in (CPVar newvar, CVar newvar)
                     else (pat, CVar v)
    CPAs asv _  -> (pat, CVar asv)
    _           -> let newvar = (i,"patvar_"++show i)
                    in (CPAs newvar pat, CVar newvar)
  
------------------------------------------------------------------------

preUnit :: CExpr
preUnit = CSymbol (pre "()")

preUntyped :: CTypeExpr
preUntyped = CTCons (pre "untyped") []

setFunMod :: String
setFunMod = "SetFunctions"

--- Extracts all elements with a single occurrence in a given list.
extractSingles :: [a] -> [a]
extractSingles [] = []
extractSingles (x:xs) =
  if null (filter (==x) xs)
  then x : extractSingles xs
  else extractSingles (filter (/=x) xs)

--- Replaces all variables occurring in the first argument by
--- anonymous variables in a pattern.
anonymPat :: [(Int,String)] -> CPattern -> CPattern
anonymPat vs (CPVar v) = CPVar (if v `elem` vs then (fst v,"_") else v)
anonymPat _  (CPLit l) = CPLit l
anonymPat vs (CPComb qc pats) = CPComb qc (map (anonymPat vs) pats)
anonymPat vs (CPAs v pat) =
  if v `elem` vs then anonymPat vs pat
                 else CPAs v (anonymPat vs pat)
anonymPat vs (CPFuncComb qf pats) = CPFuncComb qf (map (anonymPat vs) pats)
anonymPat vs (CPLazy pat) = CPLazy (anonymPat vs pat)
anonymPat vs (CPRecord qc recpats) =
  CPRecord qc (map (\ (n,p) -> (n, anonymPat vs p)) recpats)

------------------------------------------------------------------------
