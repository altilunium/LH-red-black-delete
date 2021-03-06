{-# LANGUAGE TypeApplications #-}
{-@ LIQUID "--no-termination" @-}
{-@ LIQUID "--no-totality" @-}
{-@ LIQUID "--exact-data" @-}

module MightRedBlack where

import Prelude hiding (max)
import Control.Monad 
import Test.QuickCheck hiding (elements)
import Data.List(nub,sort)

data Color = 
   R  -- red
 | B  -- black
 | BB -- double black
 | NB -- negative black
 deriving (Show, Eq)

data RBSet a =
   E  -- black leaf
 | EE -- double black leaf
 | T Color (RBSet a) a (RBSet a)
 deriving (Show, Eq)

{-@ data RBSet a = E 
                 | EE 
                 | T { c     :: Color
                     , lt    :: RBSet a 
                     , key   :: a 
                     , rt    :: RBSet a 
                     }
@-}

-- Helper functions for verification

{-@ type True  = {v:Bool |     v} @-}
{-@ type False = {v:Bool | not v} @-}

{-@ measure color' @-}
color' :: RBSet a -> Color
color' (T c _ _ _) = c
color' E = B
color' EE = BB
                            
{-@ measure normalLeaf @-}
normalLeaf :: RBSet a -> Bool
normalLeaf E = True
normalLeaf _ = False

{-@ inline blackRoot @-}
blackRoot :: RBSet a -> Bool
blackRoot t = color' t == B

--{-@ measure noSpecialColor @-}
{-@ inline noSpecialColor @-}
{-@ noSpecialColor :: x:RBSet a -> {v:Bool | (v => noSpecialChild x) 
                                          && (v => not (isBB' x)) } 
  @-}
--{-@ invariant {t:RBSet a | noSpecialColor t => noSpecialChild t} @-} 
--{-@ invariant {t:RBSet a | noSpecialColor t => not (isBB' t)} @-}  
noSpecialColor :: RBSet a -> Bool
{-noSpecialColor E = True
noSpecialColor EE = False
noSpecialColor (T c a _ b) = c /= BB &&
                             c /= NB &&
                             noSpecialColor a &&
                             noSpecialColor b
-}
noSpecialColor t = (color' t /= BB) 
                && (color' t /= NB)
                && noSpecialChild t

{-@ measure noSpecialChild @-}
noSpecialChild :: RBSet a -> Bool
noSpecialChild (T _ l _ r) = noSpecialColor l && noSpecialColor r
noSpecialChild _ = True

{-@ measure redChildIsBlack @-}
{-@ redChildIsBlack :: x:RBSet a -> {v:Bool | v => redChildIsBlackNT x} @-}
--{-@ invariant {t:RBSet a | redChildIsBlack t => redChildIsBlackNT t} @-} 
redChildIsBlack :: RBSet a  -> Bool
redChildIsBlack E = True
redChildIsBlack EE = True
redChildIsBlack (T R a x b) = color' a == B && 
                              color' b == B && 
                              redChildIsBlack a && redChildIsBlack b
redChildIsBlack (T _ a x b) = redChildIsBlack a && redChildIsBlack b

{-@ measure redChildIsBlackNT @-}
redChildIsBlackNT :: RBSet a  -> Bool
redChildIsBlackNT (T _ l _ r) = redChildIsBlack l && redChildIsBlack r
redChildIsBlackNT _ = True

{-@ measure colorValue @-}
colorValue :: Color -> Int
colorValue NB = -1
colorValue R = 0
colorValue B = 1
colorValue BB = 2

{-@ measure blackHeightL @-}
{-@ blackHeightL :: {x:RBSet a | noSpecialColor x} -> { i : Int | i >= 1}  @-}
blackHeightL :: RBSet a -> Int
blackHeightL (T c l _ _) = blackHeightL l + colorValue c
blackHeightL t = colorValue $ color' t
{-                           
{-@ measure blackHeightL @-}
{-@ blackHeightL :: {x:RBSet a | noSpecialColor x} -> { i : Int | i >= 1}  @-}
blackHeightL :: RBSet a -> Int
blackHeightL E = 1
blackHeightL EE = 2
blackHeightL (T c l _ r) = blackHeightL l
                          + if c == B then 1 else 
                            if c == BB then 2 else 
                            if c == NB then -1 else 0

{-@ measure blackHeightR @-}
{-@ blackHeightR :: {x:RBSet a | noSpecialColor x} -> { i : Int | i >= 1}  @-}
blackHeightR :: RBSet a -> Int
blackHeightR E = 1
blackHeightR EE = 2
blackHeightR (T c l _ r) = blackHeightR r
                          + if c == B then 1 else 
                            if c == BB then 2 else 
                            if c == NB then -1 else 0
-}     
{-@ measure validBlackHeight @-}
{-@ validBlackHeight :: {x:RBSet a | noSpecialChild x} -> Bool @-}
validBlackHeight :: RBSet a -> Bool
validBlackHeight E = True
validBlackHeight EE = True
validBlackHeight (T _ l _ r) = validBlackHeight l && validBlackHeight r
                            && blackHeightL l == blackHeightL r           
                            
{-@ inline prop_CT @-}
{-@ prop_CT :: {x:RBSet a | noSpecialColor x} 
            -> {v:Bool | v => prop_IM x} @-}
{-@ invariant {t:RBSet a | prop_CT t => prop_IM t} @-} 
prop_CT :: (Ord a) => RBSet a -> Bool
prop_CT t = noSpecialColor t 
         && redChildIsBlack t 
         && validBlackHeight t
{-@ type CT a = {v:RBSet a | prop_CT v} @-}

{-@ inline prop_RBSet @-}
{-@ prop_RBSet :: {x:RBSet a | noSpecialColor x} 
               -> {v:Bool | v => prop_CT x} @-}
prop_RBSet :: (Ord a) => RBSet a -> Bool
prop_RBSet t = prop_CT t 
            && blackRoot t
{-@ type RT a = {v:RBSet a | prop_RBSet v} @-}
        
{-@ inline prop_IM @-}
{-@ prop_IM :: {x:RBSet a | noSpecialChild x} -> Bool @-}
prop_IM t = noSpecialChild t 
         && redChildIsBlackNT t 
         && validBlackHeight t 
{-@ type IM a = {v:RBSet a | prop_IM v} @-}
{-         
{-@ measure prop_IM @-}
{-@ prop_IM :: {x:RBSet a | noSpecialChild x} -> Bool @-}
prop_IM E = True
prop_IM EE = True
prop_IM t@(T _ l _ r) = prop_CT l && prop_CT r
                     && blackHeightL l == blackHeightL r

{-@ inline prop_BB @-}
{-@ prop_BB :: {x:RBSet a | noSpecialChild x} -> {v:Bool | (v => prop_IM x)} @-}
prop_BB t = prop_IM t 
         && (color' t /= NB)             
-}
{-@ measure prop_DT @-}
{-@ prop_DT :: {x:RBSet a | noSpecialChild x} -> Bool @-}
prop_DT E = True
prop_DT EE = True
prop_DT t@(T c l x r) = prop_CT l && prop_CT r
                     && blackHeightL l == blackHeightL r
{-@ type DT a = {v:RBSet a | prop_DT v} @-}

{-@ measure prop_IR @-}
{-@ prop_IR :: {x:RBSet a | noSpecialChild x} -> Bool @-}
prop_IR E = False
prop_IR EE = False
prop_IR t@(T c l x r) = prop_CT l && prop_CT r
                     && blackHeightL l == blackHeightL r
{-@ type IR a = {v:RBSet a | prop_IR v} @-}

{-@ measure tooBlack @-}
tooBlack :: Color -> Bool
tooBlack BB = True
tooBlack _ = False

{-@ measure tooRed @-}
tooRed :: Color -> Bool
tooRed NB = True
tooRed _ = False

{-@ inline canBeBlacker @-}
canBeBlacker x = color' x /= BB

{-@ inline isBB' @-}
isBB' t = color' t == BB
{-
{-@ measure canBeRedder @-}
{-@ canBeRedder :: x:RBSet a 
                -> {v:Bool | ((prop_BB x && not normalLeaf x) => v)
                          && ((noSpecialColor x && not normalLeaf x) => v) } @-}
{-@ invariant {t:RBSet a | (prop_BB t && not normalLeaf t) => canBeRedder t} @-} 
{-@ invariant {t:RBSet a | (noSpecialColor t && not normalLeaf t) 
                                            => canBeRedder t } @-} 
canBeRedder :: RBSet a -> Bool
canBeRedder E = False
canBeRedder EE = True
canBeRedder (T c _ _ _) = not (tooRed c)

{-@ inline canBeBubbled @-}
canBeBubbled :: Color -> RBSet a -> RBSet a -> Bool
canBeBubbled c l r = (not ((isBB' l) || (isBB' r)))
                  || ((not (tooBlack c)) 
                        && (canBeRedder l) 
                        && (canBeRedder r))
-}

 -- Private auxiliary functions --
 
{-@ redden :: {x:CT a | color' x == B} 
           -> {v:IM a | blackHeightL v == (blackHeightL x - 1) } @-}
redden :: RBSet a -> RBSet a
redden (T _ a x b) = T R a x b

{-@ blacken' :: IM a -> RT a @-}    
-- blacken for insert
-- never a leaf, could be red or black
blacken' :: RBSet a -> RBSet a
blacken' (T R a x b) = T B a x b
blacken' (T B a x b) = T B a x b

-- blacken for delete
-- root is never red, could be double black 
{-@ blacken :: IM a -> RT a @-}    
blacken :: RBSet a -> RBSet a
blacken (T B a x b) = T B a x b
blacken (T BB a x b) = T B a x b
blacken E = E
blacken EE = E

{-@ isBB :: rb : RBSet a -> { b : Bool | b <=> isBB' rb } @-}
isBB :: RBSet a -> Bool
isBB EE = True
isBB (T BB _ _ _) = True
isBB _ = False

{-@ blacker :: {x:Color | not tooBlack x} 
            -> {v:Color | colorValue v == (colorValue x + 1)} @-}
blacker :: Color -> Color
blacker NB = R
blacker R = B
blacker B = BB
blacker BB = error "too black"

{-@ redder :: {x:Color | not tooRed x} 
           -> {v:Color | (colorValue v == (colorValue x - 1))
                      && ((x == BB) => (v == B)) } @-}
redder :: Color -> Color
redder NB = error "not black enough"
redder R = NB
redder B = R
redder BB = B

{-@ blacker' :: {x:RBSet a | canBeBlacker x} -> RBSet a @-}
blacker' :: RBSet a -> RBSet a
blacker' E = EE
blacker' (T c l x r) = T (blacker c) l x r
{-
{-@ redder' :: {x:RBSet a | (canBeRedder x) && (prop_CT x || prop_IM x)}
            -> {v:RBSet a | (((prop_CT x) && (prop_IM v)) || 
                             ((prop_IM x) && (prop_CT v))) } @-} 
{-@ redder' :: {x:RBSet a | not normalLeaf x && prop_BB x} 
            -> {v:RBSet a | (((isBB' x) && (prop_CT v)) 
                        || (prop_IM v)) 
                        && (blackHeightL v == (blackHeightL x - 1)) } @-}
-}
{-@ redder' :: {x:RBSet a | (prop_IM x && isBB' x) || (prop_CT x)} 
            -> {v:RBSet a | ((prop_IM x && isBB' x && prop_CT v) || 
                             (prop_CT x && prop_IM v))
                         && (blackHeightL v == (blackHeightL x - 1)) } @-}
redder' :: RBSet a -> RBSet a
redder' EE = E
redder' (T c l x r) = T (redder c) l x r 

 -- `balance` rotates away coloring conflicts:
{-{-@ balance :: c:Color 
            -> l:CT a 
            -> a 
            -> {r:CT a | blackHeightL l == blackHeightL r } 
            -> {v:IM a | blackHeightL v == (blackHeightL l + colorValue c)} 
@-}-}
{-@ balance :: c:Color 
            -> {l:RBSet a | (prop_IM l) || (prop_CT l) } 
            -> x:a 
            -> {r:RBSet a | ((prop_IM l && prop_CT r) ||
                             (prop_CT l && prop_IM r)) 
                         && (blackHeightL l == blackHeightL r)} 
            -> {v:RBSet a | (prop_CT v) 
                         && (blackHeightL v == (blackHeightL l + colorValue c))} 
@-}
-- beware beware blackHeight still dont accept NB
balance :: Color -> RBSet a -> a -> RBSet a -> RBSet a

 -- Okasaki's original cases:
balance B (T R (T R a x b) y c) z d = T R (T B a x b) y (T B c z d){-
balance B (T R a x (T R b y c)) z d = T R (T B a x b) y (T B c z d)
balance B a x (T R (T R b y c) z d) = T R (T B a x b) y (T B c z d)
balance B a x (T R b y (T R c z d)) = T R (T B a x b) y (T B c z d)

 -- Six cases for deletion:
balance BB (T R (T R a x b) y c) z d = T B (T B a x b) y (T B c z d)
balance BB (T R a x (T R b y c)) z d = T B (T B a x b) y (T B c z d)
balance BB a x (T R (T R b y c) z d) = T B (T B a x b) y (T B c z d)
balance BB a x (T R b y (T R c z d)) = T B (T B a x b) y (T B c z d)

balance BB a x (T NB (T B b y c) z d@(T B _ _ _)) 
    = T B (T B a x b) y (balance B c z (redden d))
balance BB (T NB a@(T B _ _ _) x (T B b y c)) z d
    = T B (balance B (redden a) x b) y (T B c z d)
-}
--balance color a x b = T color a x b 

 -- `bubble` "bubbles" double-blackness upward:
{-@ bubble :: {c:Color | not (tooBlack c)}
           -> {l:RBSet a | prop_CT l || prop_IM l}
           -> x:a
           -> {r:RBSet a | ((prop_CT l && prop_IM r) || 
                            (prop_IM l && prop_CT r))
                        && (blackHeightL l == blackHeightL r) }
           -> {v:IM a | blackHeightL v == blackHeightL l + (colorValue c) } 
@-}
bubble :: Color -> RBSet a -> a -> RBSet a -> RBSet a
bubble color l x r
 | isBB(l) || isBB(r) = balance (blacker color) (redder' l) x (redder' r)
 | otherwise          = balance color l x r 
          
{-@ max :: {x:RBSet a | not normalLeaf x && prop_CT x} -> a @-}
max :: RBSet a -> a
max E = error "no largest element"
max (T _ _ x E) = x
max (T _ _ x r) = max r

-- Remove this node: it might leave behind a double black node
{-@ remove :: {x:CT a | not normalLeaf x} 
           -> {v:IM a | blackHeightL v == blackHeightL x} @-}
remove :: RBSet a -> RBSet a
-- remove E = E   -- impossible!
-- ; Leaves are easiest to kill:
remove (T R E _ E) = E
remove (T B E _ E) = EE
-- ; Killing a node with one child;
-- ; parent or child is red:
-- remove (T R E _ child) = child
-- remove (T R child _ E) = child
remove (T B E _ (T R a x b)) = T B a x b
remove (T B (T R a x b) _ E) = T B a x b
-- ; Killing a black node with one black child:
-- remove (T B E _ child@(T B _ _ _)) = blacker' child
-- remove (T B child@(T B _ _ _) _ E) = blacker' child
-- ; Killing a node with two sub-trees:
remove (T color l y r) = bubble color l' mx r 
 where mx = max l
       l' = removeMax l

{-@ removeMax :: {x:CT a | not normalLeaf x} 
              -> {v:IM a | blackHeightL v == blackHeightL x} @-}
removeMax :: RBSet a -> RBSet a
removeMax E = error "no maximum to remove"
removeMax s@(T _ _ _ E) = remove s
removeMax s@(T color l x r) = bubble color l x (removeMax r)

{-@ delete :: (Ord a) => a -> x:RT a -> v:RT a @-}   
delete :: (Ord a) => a -> RBSet a -> RBSet a
delete x s = blacken (del x s)

{-@ del :: Ord a => a 
                 -> x:CT a 
                 -> {v:IM a | blackHeightL v == blackHeightL x} @-}
del x E = E
del x s@(T color a' y b') | x < y   = bubble color (del x a') y b'
                        | x > y     = bubble color a' y (del x b')
                        | otherwise = remove s

--
