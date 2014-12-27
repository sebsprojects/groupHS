module Group where

import Data.List
import Data.Maybe

import GroupUtils


{-
  Types
-}
type BinOp a = (a -> a -> a)
type MTable a = ([a], [[a]])

data Group a = Group { set :: [a], op :: (BinOp a) }
data GAction a b = GAction (Group a) [b] (a -> b -> b)

instance (Show a, Eq a) => Show (Group a) where
  show (Group s f) =
    "G = {\n" ++ tableToString (groupToTable (Group s f)) 6 ++ "    }"

instance (Show a, Show b, Eq a, Eq b) => Show (GAction a b) where
  show (GAction g xs p) = "Action = {\n\n  " ++ show xs ++ "\n\n  G = {\n" ++
                          tableToString (groupToTable g) 8 ++ "      }\n}"

{-
  Construction
-}
isValidGroup :: Eq a => Group a -> Bool
isValidGroup (Group s f) = formsGroup s f

constructGroup :: Eq a => [a] -> BinOp a -> Maybe (Group a)
constructGroup s f | formsGroup s f = Just (Group s f)
                   | otherwise = Nothing

isValidAction :: (Eq a, Eq b) => GAction a b -> Bool
isValidAction (GAction g xs p) = formsAction g xs p

constructAction :: (Eq a, Eq b) => Group a -> [b] -> (a -> b -> b) ->
                   Maybe (GAction a b)
constructAction g xs p | formsAction g xs p = Just (GAction g xs p)
                       | otherwise = Nothing


{-
  Basics
-}
one :: Eq a =>  Group a -> a
one (Group s f) = fromJust (one_ s f)

inv :: Eq a => Group a -> a -> a
inv (Group s f) x = fromJust $ inv_ s f x

-- | b = xax^-1
conj :: Eq a => Group a -> a -> a -> a
conj (Group s f) a x = f x (f a (inv (Group s f) x))

conjs :: Eq a => Group a -> a -> [a]
conjs (Group s f) a = [conj (Group s f) a x | x <- s]

order :: Eq a => Group a -> Int
order (Group s f) = length s

elemOrder :: Eq a => Group a -> a -> Int
elemOrder (Group s f) x = go (Group s f) x 1
  where go (Group s f) y acc
          | y == e = acc
          | otherwise = go (Group s f) (f y x) (acc + 1)
        e = one (Group s f)

isAbelian :: Eq a => Group a -> Bool
isAbelian g = tab == tab'
  where tab = snd (groupToTable g)
        tab' = [[l !! i |  l <- tab] | i <- [0..length (head tab) - 1]]

isCyclic :: Eq a => Group a -> Bool
isCyclic (Group s f) = go s f
  where go [] f = False
        go (x : xs) f | elemOrder (Group s f) x == o = True
                      | otherwise = go xs f
        o = order (Group s f)


{-
  Generating
-}
minimalGenerator :: Eq a => Group a -> [a]
minimalGenerator g = head $ minimalGeneratingSets g

minimalGeneratingSets :: Eq a => Group a -> [[a]]
minimalGeneratingSets (Group s f) = go 1
  where go l | not (null (gener l)) = gener l
             | otherwise = go (l + 1)
        gener l = [x | x <- lenSubSets l s,
                   setEq s (generateFromSet (Group s f) x)]

generateFromSet :: Eq a => Group a -> [a] -> [a]
generateFromSet (Group s f) xs = go xs
  where go xs | setEq nextGen xs = xs
              | otherwise = go nextGen
          where nextGen = takeCrossProduct (Group s f)
                          (generateFromSetOnce (Group s f) xs)

-- | produces wrong result
generateFromSet2 :: Eq a => Group a -> [a] -> [a]
generateFromSet2 (Group s f) xs = go xs
  where go xs | setEq nextGen xs = xs
              | otherwise = go nextGen
          where nextGen = takeCrossProduct (Group s f) xs

generateFromSetOnce :: Eq a => Group a -> [a] -> [a]
generateFromSetOnce (Group s f) xs =
  nub (foldl (++) [] [generateFrom (Group s f) x | x <- xs])

takeCrossProduct :: Eq a => Group a -> [a] -> [a]
takeCrossProduct (Group s f) xs = nub [f x y | x <- xs, y <- xs]

generateFrom :: Eq a => Group a -> a -> [a]
generateFrom (Group s f) x = go x x
  where go x y | y == e = [y]
               | otherwise = y : go x (f x y)
        e = one (Group s f)


{-
  Subgroups
-}
subgroups :: Eq a => Group a -> [Group a]
subgroups g = go atoms
  where go xs | length xs == length nextGen = nextGen
              | otherwise = go nextGen
          where nextGen = compoSubgroups g atoms xs
        atoms = cyclicSubgroups g

compoSubgroups :: Eq a => Group a -> [Group a] -> [Group a] -> [Group a]
compoSubgroups g ato comp = nubSubgroups r
  where r = map fromJust (filter isJust [subgrp a c | a <- ato, c <- comp])
        subgrp a c | (order g) `mod` (length subg) /= 0 = Nothing
                   | otherwise = constructGroup subg (op g)
          where subg = generateFromSet g (union (set a) (set c))

cyclicSubgroups :: Eq a => Group a -> [Group a]
cyclicSubgroups (Group s f) = nubSubgroups subgrps
  where subgrps = map fromJust (
          filter isJust
          [constructGroup (generateFrom (Group s f) x) f | x <- s])

nubSubgroups :: Eq a => [Group a] -> [Group a]
nubSubgroups subgrps = go subgrps []
  where go [] ys = ys
        go (x : xs) ys
          | null [z | z <- ys, setEq (set x) (set z)] = go xs (x : ys)
          | otherwise = go xs ys

-- | Subgroup -> g in Group
leftCoset :: Eq a => Group a -> a -> [a]
leftCoset (Group s f) g = [f g x | x <- s]

-- | Group -> Subgroup
leftCosets :: Eq a => Group a -> Group a -> [[a]]
leftCosets g h = nubBy setEq [leftCoset h x | x <- (set g)]

rightCoset :: Eq a => Group a -> a -> [a]
rightCoset (Group s f) g = [f x g | x <- s]

rightCosets :: Eq a => Group a -> Group a -> [[a]]
rightCosets g h = nubBy setEq [rightCoset h x | x <- (set g)]

-- | Group -> Subgroup
isNormalSubgroup :: Eq a => Group a -> Group a -> Bool
isNormalSubgroup g h =
  null [x | x <- (set g), not $ setEq (leftCoset h x) (rightCoset h x)]

normalSubgroups :: Eq a => Group a -> [Group a]
normalSubgroups g = [h | h <- subgroups g, isNormalSubgroup g h]

{-
  Isomorphism
-}
areIsomorphic :: (Eq a, Eq b) => Group a -> Group b -> Bool
areIsomorphic g1 g2
  | order g1 /= order g2 = False
  | not $ setEq (map (elemOrder g1) (set g1)) (map (elemOrder g2) (set g2)) =
      False
  | otherwise = True


{-
  Helper for to-be groups
-}
formsGroup :: Eq a => [a] -> BinOp a -> Bool
formsGroup s f = ckSet && ckOne && ckInv && ckClo && ckAssGen
  where ckSet = not $ null s && s == nub s
        ckOne = isJust (one_ s f)
        ckInv = length (filter isJust [inv_ s f x | x <- s]) == length s
        ckClo = null [x | x <- s, y <- s, not $ f x y `elem` s]
        ckAssGen = checkAss (minimalGenerator (Group s f)) f

-- | runs in O(n^3)
checkAss :: Eq a => [a] -> BinOp a -> Bool
checkAss s f = null xs
  where xs = [a | a <- s, b <- s, c <- s, f (f a b) c /= f a (f b c)]

formsAction :: (Eq a, Eq b) => Group a -> [b] -> (a -> b -> b) -> Bool
formsAction (Group s f) xs p = ckCo && ckId && ckCl
  where ckCo = null [g | g <- s, h <- s, x <- xs, p (f g h) x /= p g (p h x)]
        ckId = null [x | x <- xs, p (one (Group s f)) x /= x ]
        ckCl = null [x | g <- s, x <- xs, not $ (p g x) `elem` xs]

one_ :: Eq a => [a] -> BinOp a -> Maybe a
one_ s f | null xs = Nothing
         | otherwise = Just $ head xs
  where xs = [x | x <- s, f x someE == someE]
        someE = head s

-- | slower than above
one_2 :: Eq a => [a] -> BinOp a -> Maybe a
one_2 s f | isNothing ind = Nothing
             | otherwise = Just (s !! (fromJust ind))
  where ind = elemIndex s (snd (groupToTable_ s f))

inv_ :: Eq a => [a] -> BinOp a -> a -> Maybe a
inv_ s f x | isNothing e || not (x `elem` s) = Nothing
           | otherwise = find ((== fromJust e) . (f x)) s
  where e = one_ s f

groupToTable_ :: Eq a => [a] -> BinOp a -> MTable a
groupToTable_ s f = (s, [[f a b | a <- s] | b <- s])

tableToGroup :: Eq a => MTable a -> Maybe (Group a)
tableToGroup (axis, tab) = constructGroup axis (tableToFunction (axis, tab))

tableToFunction :: Eq a => MTable a -> BinOp a
tableToFunction (axis, tab)  = \x y -> (tab !! pos x) !! pos y
  where pos x = fromJust $ elemIndex x axis

groupToTable :: Eq a => Group a -> MTable a
groupToTable (Group s f) = groupToTable_ s f
