module colormap02
  ( colormap02.Color (..), colormap02.diff, colormap02.isColor
  , colormap02.coloring, colormap02.correct, colormap02.goal, colormap02.main )
  where

import Prelude

data colormap02.Color
  = colormap02.Red
  | colormap02.Green
  | colormap02.Yellow

colormap02.diff :: a -> a -> Prelude.Bool
colormap02.diff v1 v2 = (v1 == v2) Prelude.=:= Prelude.False

colormap02.isColor :: colormap02.Color -> Prelude.Bool
colormap02.isColor v1 = fcase v1 of
    colormap02.Red -> Prelude.success
    colormap02.Green -> Prelude.success
    colormap02.Yellow -> Prelude.success

colormap02.coloring
  ::
  colormap02.Color -> colormap02.Color -> colormap02.Color -> Prelude.Bool
colormap02.coloring v1 v2 v3 = (colormap02.isColor v1)
  &
  ((colormap02.isColor v2) & (colormap02.isColor v3))

colormap02.correct
  ::
  colormap02.Color -> colormap02.Color -> colormap02.Color -> Prelude.Bool
colormap02.correct v1 v2 v3 = (colormap02.diff v1 v2)
  &
  ((colormap02.diff v1 v3) & (colormap02.diff v2 v3))

colormap02.goal
  ::
  colormap02.Color -> colormap02.Color -> colormap02.Color -> Prelude.Bool
colormap02.goal v1 v2 v3 = colormap02._pe0 v1 v2 v3

colormap02.main :: (colormap02.Color,colormap02.Color,colormap02.Color)
colormap02.main = let v1,v2,v3 free in (colormap02.goal v1 v2 v3) &> (v1,v2,v3)

colormap02._pe0
  ::
  colormap02.Color -> colormap02.Color -> colormap02.Color -> Prelude.Bool
colormap02._pe0 v1 v2 v3 = fcase v1 of
    colormap02.Red -> fcase v2 of
        colormap02.Green -> fcase v3 of
            colormap02.Yellow -> Prelude.True
        colormap02.Yellow -> fcase v3 of
            colormap02.Green -> Prelude.True
    colormap02.Green -> fcase v2 of
        colormap02.Red -> fcase v3 of
            colormap02.Yellow -> Prelude.True
        colormap02.Yellow -> fcase v3 of
            colormap02.Red -> Prelude.True
    colormap02.Yellow -> fcase v2 of
        colormap02.Red -> fcase v3 of
            colormap02.Green -> Prelude.True
        colormap02.Green -> fcase v3 of
            colormap02.Red -> Prelude.True
