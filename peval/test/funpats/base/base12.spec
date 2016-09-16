module base12 ( base12.pair, base12.match, base12.goal, base12.main ) where

import Prelude

base12.pair :: a -> b -> (a,b)
base12.pair v1 v2 = (v1,v2)

base12.match :: Prelude.Bool -> Prelude.Bool
base12.match v1 = fcase v1 of
    Prelude.True -> Prelude.True

base12.goal :: (Prelude.Bool,Prelude.Bool) -> Prelude.Bool
base12.goal v1 = base12._pe0 v1

base12.main :: Prelude.Bool
base12.main = (base12.goal (Prelude.True,Prelude.True))
  ?
  (base12.goal (Prelude.False,Prelude.True))

base12._pe0 :: (Prelude.Bool,Prelude.Bool) -> Prelude.Bool
base12._pe0 v1 = fcase v1 of
    (v2,v3) -> fcase v2 of
        Prelude.True -> fcase v3 of
            Prelude.True -> Prelude.True
