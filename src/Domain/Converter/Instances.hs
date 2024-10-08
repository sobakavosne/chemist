{-# LANGUAGE FlexibleContexts  #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE NamedFieldPuns    #-}
{-# LANGUAGE OverloadedStrings #-}
{-# OPTIONS_GHC -Wno-orphans #-}
{-# OPTIONS_GHC -Wno-missing-methods #-}
{-# OPTIONS_GHC -Wno-incomplete-patterns #-}

-- | This module defines instances for converting Neo4j elements
--   (nodes and relationships) into Haskell types and their
--   corresponding interactants within the domain model.
--
--   ==== Base
--
--   * Instances of the `FromValue` type class to handle conversion
--     from Bolt's `Value` type to various Haskell types such as `Int`,
--     `String`, and `Float`, as well as lists and optional values.
--
--   * `ElemInteractant` instances for translating Neo4j graph elements
--     into domain-specific types like `Molecule`, `Catalyst`, `Reaction`,
--     and more. The `Identity` type is introduced to facilitate
--     the mapping of Neo4j objects and building relationships.
--   * Instances of `NodeMask` and `RelMask` to prepare data
--     for creating or updating nodes and relationships in the database.
--
--   This module is integral for enabling seamless interaction
--   with Neo4j, facilitating the conversion of graph structures
--   into Haskell types for further processing and manipulation.
--
module Domain.Converter.Instances () where

import           Control.Exception     (throw)
import           Control.Monad         (forM)
import           Data.Bifunctor        (Bifunctor (first, second))
import           Data.Map.Strict       (Map, (!?))
import           Data.Text             (Text, pack, unpack)
import           Database.Bolt         (IsValue (..), Node (..), Path (..),
                                        Relationship (..), URelationship (..),
                                        Value (..), props)
import           Domain.Converter.Type (Elem (SNode, SPath, SRel, SURel),
                                        ElemInteractant (..), FromValue (..),
                                        Identity (..), InteractantElem (..),
                                        ParsingError (..))
import           Models                (ACCELERATE (..), Catalyst (..),
                                        FOLLOW (..), INCLUDE (..),
                                        Interactant (..), Mechanism (..),
                                        Molecule (..), NodeMask (..),
                                        PRODUCT_FROM (..), PathMask (..),
                                        REAGENT_IN (..), Reaction (..),
                                        RelMask (..), Stage (..))

import           Numeric.Extra         (doubleToFloat)

-- | Converts a Bolt `Value` of type `I` (Int) to a Haskell `Int`.
instance FromValue Int where
  fromValue (I i) = Right i

-- | Converts a Bolt `Value` of type `T` (Text) to a Haskell `String`.
instance {-# OVERLAPPING #-} FromValue String where
  fromValue (T t) = (Right . unpack) t
  maybeFromValue (Just (T t)) = (Just . unpack) t
  maybeFromValue _            = Nothing

-- | Converts a Bolt `Value` of type `F` (Double) to a Haskell `Float`.
instance FromValue Float where
  fromValue (F d) = Right (doubleToFloat d)

-- | Converts a Bolt `Value` of type `L` (List) to a Haskell list of the specified type.
instance FromValue a => FromValue [a] where
  fromValue (L l) = mapM fromValue l

-- | Converts a Bolt `Value` of type `N` (Null) to a Haskell `Maybe` type.
instance FromValue a => FromValue (Maybe a) where
  fromValue (N ()) = Right Nothing
  fromValue v      = Just <$> fromValue v

-- | Converts a Neo4j node with label "Molecule" to a Haskell `Molecule` and its `Identity`.
instance ElemInteractant (Molecule, Identity) where
  exactInteractant (SNode (Node {nodeIdentity, labels, nodeProps}))
    | "Molecule" `elem` labels = do
      moleculeId <- unpackProp "id" nodeProps
      moleculeSmiles <- unpackProp "smiles" nodeProps
      moleculeIupacName <- unpackProp "iupacName" nodeProps
      return
        ( Molecule {moleculeId, moleculeSmiles, moleculeIupacName}
        , NodeId nodeIdentity)
    | otherwise = throw $ ParsingError "No 'Molecule' label"

-- | Converts a Neo4j node with label "Catalyst" to a Haskell `Catalyst` and its `Identity`.
instance ElemInteractant (Catalyst, Identity) where
  exactInteractant (SNode (Node {nodeIdentity, labels, nodeProps}))
    | "Catalyst" `elem` labels = do
      catalystId <- unpackProp "id" nodeProps
      catalystSmiles <- unpackProp "smiles" nodeProps
      return
        ( Catalyst
            { catalystId
            , catalystSmiles
            , catalystName = maybeFromValue $ nodeProps !? "name"
            }
        , NodeId nodeIdentity)
    | otherwise = throw $ ParsingError "No 'Catalyst' label"

-- | Converts a Neo4j node with label "Reaction" to a Haskell `Reaction` and its `Identity`.
instance ElemInteractant (Reaction, Identity) where
  exactInteractant (SNode (Node {nodeIdentity, labels, nodeProps}))
    | "Reaction" `elem` labels = do
      reactionId <- unpackProp "id" nodeProps
      reactionName <- unpackProp "name" nodeProps
      return (Reaction {reactionId, reactionName}, NodeId nodeIdentity)
    | otherwise = throw $ ParsingError "No 'Reaction' label"

-- | Converts a Neo4j relationship of type "REAGENT_IN" to a Haskell `REAGENT_IN` and its `Identity`.
instance ElemInteractant (REAGENT_IN, Identity) where
  exactInteractant (SRel (Relationship {startNodeId, relProps})) = do
    reagentAmount <- unpackProp "amount" relProps
    return (REAGENT_IN {reagentAmount}, RelTargetNodeId startNodeId)
  exactInteractant (SURel (URelationship {urelIdentity, urelProps})) = do
    reagentAmount <- unpackProp "amount" urelProps
    return (REAGENT_IN {reagentAmount}, URelId urelIdentity)

-- | Converts a Neo4j relationship of type "PRODUCT_FROM" to a Haskell `PRODUCT_FROM` and its `Identity`.
instance ElemInteractant (PRODUCT_FROM, Identity) where
  exactInteractant (SRel (Relationship {endNodeId, relProps})) = do
    productAmount <- unpackProp "amount" relProps
    return (PRODUCT_FROM {productAmount}, RelTargetNodeId endNodeId)
  exactInteractant (SURel (URelationship {urelIdentity, urelProps})) = do
    productAmount <- unpackProp "amount" urelProps
    return (PRODUCT_FROM {productAmount}, URelId urelIdentity)

-- | Converts a Neo4j relationship of type "ACCELERATE" to a Haskell `ACCELERATE` and its `Identity`.
instance ElemInteractant (ACCELERATE, Identity) where
  exactInteractant (SRel (Relationship {startNodeId, relProps})) = do
    pressure <- unpackProp "pressure" relProps
    temperature <- unpackProp "temperature" relProps
    return (ACCELERATE {pressure, temperature}, RelTargetNodeId startNodeId)
  exactInteractant (SURel (URelationship {urelIdentity, urelProps})) = do
    pressure <- unpackProp "pressure" urelProps
    temperature <- unpackProp "temperature" urelProps
    return (ACCELERATE {pressure, temperature}, URelId urelIdentity)

-- | Converts a Neo4j node with label "Mechanism" to a Haskell `Mechanism` and its `Identity`.
instance ElemInteractant (Mechanism, Identity) where
  exactInteractant (SNode (Node {nodeIdentity, labels, nodeProps}))
    | "Mechanism" `elem` labels = do
      mechanismId <- unpackProp "id" nodeProps
      mechanismName <- unpackProp "name" nodeProps
      mechanismType <- unpackProp "type" nodeProps
      mechanismActivationEnergy <- unpackProp "activationEnergy" nodeProps
      return
        ( Mechanism
            { mechanismId
            , mechanismName
            , mechanismType
            , mechanismActivationEnergy
            }
        , NodeId nodeIdentity)
    | otherwise = throw $ ParsingError "No 'Mechanism' label"

-- | Converts a Neo4j node with label "Stage" to a Haskell `Stage` and its `Identity`.
instance ElemInteractant (Stage, Identity) where
  exactInteractant (SNode (Node {nodeIdentity, labels, nodeProps}))
    | "Stage" `elem` labels = do
      stageOrder <- unpackProp "order" nodeProps
      stageName <- unpackProp "name" nodeProps
      stageDescription <- unpackProp "description" nodeProps
      stageProducts <- unpackProp "products" nodeProps
      return
        ( Stage {stageOrder, stageName, stageDescription, stageProducts}
        , NodeId nodeIdentity)
    | otherwise = throw $ ParsingError "No 'Stage' label"

-- | Converts a Neo4j relationship of type "INCLUDE" to a Haskell `INCLUDE` and its two `Identity` values.
instance ElemInteractant (INCLUDE, Identity, Identity) where
  exactInteractant (SRel (Relationship {startNodeId, endNodeId})) = do
    return (INCLUDE, RelStartNodeId startNodeId, RelTargetNodeId endNodeId)
  exactInteractant (SURel (URelationship {urelIdentity})) = do
    return (INCLUDE, URelId urelIdentity, URelId urelIdentity)

-- | Converts a Neo4j relationship of type "FOLLOW" to a Haskell `FOLLOW` and its `Identity`.
instance ElemInteractant (FOLLOW, Identity) where
  exactInteractant (SRel (Relationship {endNodeId, relProps})) = do
    description <- unpackProp "description" relProps
    return (FOLLOW {description}, RelTargetNodeId endNodeId)
  exactInteractant (SURel (URelationship {urelIdentity, urelProps})) = do
    description <- unpackProp "description" urelProps
    return (FOLLOW {description}, URelId urelIdentity)

-- | Converts a Neo4j node to a Haskell `Interactant` based on its label (if `Node`) or type (if `URelationship`).
instance ElemInteractant (Interactant, Identity) where
  exactInteractant element@(SNode (Node {labels})) = do
    case labels of
      ["Molecule"] ->
        (second . first)
          IMolecule
          (exactInteractant element :: Either ParsingError (Molecule, Identity))
      ["Catalyst"] ->
        (second . first)
          ICatalyst
          (exactInteractant element :: Either ParsingError (Catalyst, Identity))
      ["Reaction"] ->
        (second . first)
          IReaction
          (exactInteractant element :: Either ParsingError (Reaction, Identity))
      _ ->
        (throw . ParsingError . pack)
          ("Unrecognized Node labels: " ++ show labels)
  exactInteractant element@(SURel (URelationship {urelType})) = do
    case urelType of
      "ACCELERATE" ->
        (second . first)
          IAccelerate
          (exactInteractant element :: Either ParsingError ( ACCELERATE
                                                           , Identity))
      "REAGENT_IN" ->
        (second . first)
          IReagentIn
          (exactInteractant element :: Either ParsingError ( REAGENT_IN
                                                           , Identity))
      "PRODUCT_FROM" ->
        (second . first)
          IProductFrom
          (exactInteractant element :: Either ParsingError ( PRODUCT_FROM
                                                           , Identity))
      _ ->
        (throw . ParsingError . pack)
          ("Unrecognized URelationship type: " ++ show urelType)

-- | Converts a Neo4j path to a Haskell `PathMask`
--   (Introduce `PathMask` instance to avoid introducing a new typeclass for a pseudo-collection of `Interactant`'s).
instance ElemInteractant PathMask where
  exactInteractant (SPath (Path {pathNodes, pathRelationships, pathSequence})) = do
    pathNodesMask <- forM pathNodes (fmap fst . parseNode)
    pathRelationshipsMask <- forM pathRelationships (fmap fst . parseURel)
    return
      (PathMask
         {pathNodesMask, pathRelationshipsMask, pathSequenceMask = pathSequence})
    where
      parseNode ::
           ElemInteractant (a, Identity)
        => Node
        -> Either ParsingError (a, Identity)
      parseNode = exactInteractant . SNode
      parseURel ::
           ElemInteractant (a, Identity)
        => URelationship
        -> Either ParsingError (a, Identity)
      parseURel = exactInteractant . SURel

-- | Converts a relation of `Interactants` to a `RelMask`.
instance InteractantElem RelMask where
  exactElem interactant =
    case interactant of
      IAccelerate (ACCELERATE {pressure, temperature}) -> do
        return
          RelMask
            { relPropsMask =
                props
                  [ ("pressure", toValueList pressure)
                  , ("temperature", toValueList temperature)
                  ]
            }
      IProductFrom (PRODUCT_FROM {productAmount}) -> do
        return
          RelMask {relPropsMask = props [("amount", toValue productAmount)]}
      IReagentIn (REAGENT_IN {reagentAmount}) -> do
        return
          RelMask {relPropsMask = props [("amount", toValue reagentAmount)]}
      r ->
        (throw . ParsingError . pack)
          ("Unrecognized 'relation' Interactant: " ++ show r)

-- | Converts a node interactant to a `NodeMask`.
instance InteractantElem NodeMask where
  exactElem interactant =
    case interactant of
      ICatalyst (Catalyst {catalystId, catalystSmiles, catalystName}) -> do
        return
          NodeMask
            { nodePropsMask =
                props
                  [ ("id", toValue catalystId)
                  , ("smiles", toValue catalystSmiles)
                  , ("name", toValue catalystName)
                  ]
            }
      IMolecule (Molecule {moleculeId, moleculeSmiles, moleculeIupacName}) -> do
        return
          NodeMask
            { nodePropsMask =
                props
                  [ ("id", toValue moleculeId)
                  , ("smiles", toValue moleculeSmiles)
                  , ("iupacName", toValue moleculeIupacName)
                  ]
            }
      IReaction (Reaction {reactionId, reactionName}) -> do
        return
          NodeMask
            { nodePropsMask =
                props
                  [("id", toValue reactionId), ("name", toValue reactionName)]
            }
      n ->
        (throw . ParsingError . pack)
          ("Unrecognized 'node' Interactant: " ++ show n)

unpackProp :: FromValue a => Text -> Map Text Value -> Either ParsingError a
unpackProp key properties =
  case properties !? key of
    Just x -> fromValue x
    _      -> throw $ ParsingError ("Missing the key: " <> key)
