-- | Module providing asynchronous service functions for interacting 
-- with the Neo4j database. This module contains functions to 
-- retrieve, create, and delete reactions, as well as fetch health 
-- status and find paths between molecules.
--
-- The services use the `withNeo4j` wrapper to manage database connections 
-- and operations asynchronously, ensuring efficient execution of database 
-- queries without blocking the main thread. The functions also handle 
-- necessary conversions between raw database representations and 
-- application-specific data types.
--
-- Functions included:
-- 
-- * `getPathAsync` - Finds the shortest path between two molecules.
-- * `getHealthAsync` - Retrieves the health status of the Neo4j database.
-- * `getReactionAsync` - Fetches details of a reaction by its identifier.
-- * `getMechanismAsync` - Retrieves details of a mechanism by its identifier.
-- * `postReactionAsync` - Creates a new reaction in the database.
-- * `deleteReactionAsync` - Deletes a reaction from the database.
--
module Domain.Service
  ( getPathAsync
  , getHealthAsync
  , getReactionAsync
  , getMechanismAsync
  , postReactionAsync
  , deleteReactionAsync
  ) where

import           Control.Concurrent.Async   (async, wait)
import           Domain.Converter.Converter (toMechanismDetails, toPath,
                                             toRawReactionDetails, toReaction,
                                             toReactionDetails)
import           Infrastructure.Database    (checkNeo4j, createReaction,
                                             fetchMechanism, fetchReaction,
                                             findPath, removeReaction,
                                             withNeo4j)
import           Models                     (HealthCheck, MechanismDetails,
                                             MechanismID, MoleculeID, PathMask,
                                             Reaction, ReactionDetails,
                                             ReactionID)
import           Prelude                    hiding (id)

-- | Asynchronously fetch the health status of the Neo4j database.
--   Uses the `withNeo4j` wrapper to establish a connection
--   and execute the health check query.
--
-- __Returns:__
--
-- * `HealthCheck` containing the status information of the database.
getHealthAsync :: IO HealthCheck
getHealthAsync = wait =<< (async . withNeo4j) checkNeo4j

-- | Asynchronously fetches the details of a reaction based on its unique `ReactionID`.
--   Converts the raw reaction data retrieved from the database into
--   `ReactionDetails` format.
--
-- __Parameters:__
--
-- * `ReactionID` - the unique identifier of the reaction.
--
-- __Returns:__
--
-- * A tuple of `ReactionDetails` and an optional `MechanismID`, if a mechanism is associated.
getReactionAsync :: ReactionID -> IO (ReactionDetails, Maybe MechanismID)
getReactionAsync id =
  toReactionDetails =<< wait =<< (async . withNeo4j . fetchReaction) id

-- | Asynchronously creates a new reaction in the database.
--   Converts the given `ReactionDetails` to raw details before calling the
--   database function to store the reaction.
--
-- __Parameters:__
--
-- * `ReactionDetails` - the details of the reaction to be created.
--
-- __Returns:__
--
-- * `Reaction` - the created reaction with its unique ID.
postReactionAsync :: ReactionDetails -> IO Reaction
postReactionAsync details =
  toReaction =<< wait =<< async . withNeo4j . createReaction =<< toRawReactionDetails details

-- | Asynchronously deletes a reaction from the database based on its `ReactionID`.
--   Uses `withNeo4j` to execute the delete operation.
--
-- __Parameters:__
--
-- * `ReactionID` - the unique identifier of the reaction to be deleted.
--
-- __Returns:__
--
-- * `ReactionID` of the deleted reaction.
deleteReactionAsync :: ReactionID -> IO ReactionID
deleteReactionAsync id = wait =<< (async . withNeo4j . removeReaction) id

-- | Asynchronously finds the shortest path between two molecules based on their `MoleculeID`s.
--   Fetches the path from the database and converts it to a `PathMask`.
--
-- __Parameters:__
--
-- * `MoleculeID` - the starting molecule's ID.
-- * `MoleculeID` - the ending molecule's ID.
--
-- __Returns:__
--
-- * `PathMask` representing the shortest path between the two molecules.
getPathAsync :: MoleculeID -> MoleculeID -> IO PathMask
getPathAsync start end = toPath =<< wait =<< (async . withNeo4j) (findPath start end)

-- | Asynchronously fetches the details of a mechanism based on its `MechanismID`.
--   Converts the raw mechanism data into `MechanismDetails`.
--
-- __Parameters:__
--
-- * `MechanismID` - the unique identifier of the mechanism.
--
-- __Returns:__
--
-- * `MechanismDetails` representing the mechanism and its stages.
getMechanismAsync :: MechanismID -> IO MechanismDetails
getMechanismAsync id =
  toMechanismDetails =<< wait =<< (async . withNeo4j . fetchMechanism) id
