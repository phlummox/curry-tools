import AbstractCurry
import AbstractCurryGoodies
import GenerationHelper
import ControllerGeneration
import ERD
import ERDGoodies

generateRoutesForERD :: ERD -> CurryProg
generateRoutesForERD (ERD _ entities _) =
 let spiceySysCtrl = "SpiceySystemController" in
 CurryProg
  mappingModuleName
  (["Spicey", "Routes", spiceySysCtrl, dataModuleName] ++
   (map (\e -> controllerModuleName (entityName e)) entities)) -- imports
  [] -- typedecls
  [
    cmtfunc 
      ("Maps the controllers associated to URLs in module RoutesData\n"++
       "into the actual controller operations.")
      (mappingModuleName, "getController")
      1 
      Public 
      (baseType (mappingModuleName, "ControllerReference") ~> controllerType)
      [
        CRule [CPVar (1, "fktref")]
        [
          noGuard (
            CCase (CVar (1, "fktref")) 
              (
                [CBranch (CPComb (dataModuleName, "ProcessListController") [])
                         (constF (spiceySysCtrl, "processListController")),
                 CBranch (CPComb (dataModuleName, "LoginController") [])
                         (constF (spiceySysCtrl, "loginController"))] ++
                concatMap branchesForEntity entities ++
                [CBranch (CPVar (2,"_"))
                  (applyF ("Spicey", "displayError")
                          [string2ac "getController: no mapping found"])]
              )
          )
        ]
        []
      ]
  ] -- functions
  [] -- opdecls
  
-- startpoint controller prefixes
controllerPrefixes = ["List","New"]

branchesForEntity :: Entity -> [CBranchExpr]
branchesForEntity (Entity entityName _) =
  let
    controllerReference = entityName++"Controller"
  in
    map 
      (\pre -> 
        CBranch (CPComb ("RoutesData", pre++controllerReference) [])
          (constF (controllerReference, (lowerFirst pre)++controllerReference))
      )
      controllerPrefixes
  
generateStartpointDataForERD :: ERD -> CurryProg
generateStartpointDataForERD (ERD _ entities _) = CurryProg
  dataModuleName
  ["Authentication"] -- imports
  [
    CType (dataModuleName, "ControllerReference") Public []
          ([CCons (dataModuleName, "ProcessListController") 0 Public [],
            CCons (dataModuleName, "LoginController") 0 Public []] ++
           concatMap controllerReferencesForEntity entities),
    urlMatchType,
    routeType
  ] -- typedecls
  [
   cmtfunc 
     ("This constant specifies the association of URLs to controllers.\n"++
      "Controllers are identified here by constants of type\n"++
      "ControllerReference. The actual mapping of these constants\n"++
      "into the controller operations is specified in the module\n"++
      "ControllerMapping.")
     (dataModuleName, "getRoutes")
     0
     Public 
     (ioType routeMappingType)
     [CRule []
       [noGuard
         (CDoExpr
          [CSPat (CPVar (1,"login"))
                 (constF ("Authentication","getSessionLogin")),
           CSExpr $ applyF (pre "return")
             [list2ac (
               [tupleExpr
                  [string2ac "Processes",
                   applyF (dataModuleName, "Exact")
                          [string2ac "spiceyProcesses"],
                   constF (dataModuleName, "ProcessListController")]
               ] ++
               concatMap startpointsForEntity entities ++
               [tupleExpr
                  [applyF (pre "maybe")
                          [string2ac "Login",
                           applyF (pre "const") [string2ac "Logout"],
                           CVar (1,"login")],
                   applyF (dataModuleName, "Exact") [string2ac "login"],
                   constF (dataModuleName, "LoginController")],
                tupleExpr
                  [string2ac "default",
                   constF (dataModuleName, "Always"),
                   constF (dataModuleName,
                           "List" ++ firstEntityName entities ++ "Controller")]
               ]
             )
            ]
         ]
        )
       ]
       []
     ]
  ] -- functions
  [] -- opdecls
 where
  firstEntityName :: [Entity] -> String
  firstEntityName ((Entity entityName _):_) = entityName

  route :: String -> String -> String -> CExpr
  route desc url controllerDef =
    tupleExpr [string2ac desc,
               applyF (dataModuleName, "Exact") [string2ac url],
               constF (dataModuleName, controllerDef)]
    
  startpointsForEntity :: Entity -> [CExpr]
  startpointsForEntity (Entity entityName _) =
    map (\pre -> route (pre ++ " " ++ entityName)
                       (lowerFirst pre ++ entityName)
                       (pre ++ entityName ++ "Controller"))
        controllerPrefixes
      
  urlMatchType :: CTypeDecl
  urlMatchType =
    CType (dataModuleName, "UrlMatch") Public [] [
      CCons (dataModuleName, "Exact") 1 Public [stringType],
      CCons (dataModuleName, "Matcher") 1 Public [stringType ~> boolType],
      CCons (dataModuleName, "Always") 0 Public []
    ]
    
  routeMappingType :: CTypeExpr
  routeMappingType = listType (baseType (dataModuleName,"Route"))
  
  routeType :: CTypeDecl
  routeType =
    CTypeSyn (dataModuleName, "Route") Public []
      (tupleType [stringType,
                  baseType (dataModuleName, "UrlMatch"),
                  baseType (dataModuleName, "ControllerReference")])
    
  controllerReferencesForEntity :: Entity -> [CConsDecl]
  controllerReferencesForEntity (Entity entityName _) =
    map (\pre ->
          CCons (dataModuleName, pre++entityName++"Controller") 0 Public [])
        controllerPrefixes