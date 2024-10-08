{-# LANGUAGE NamedFieldPuns    #-}
{-# LANGUAGE OverloadedStrings #-}
{-# OPTIONS_GHC -Wno-missing-fields #-}

module Infrastructure.Config
  ( loadBoltCfg
  ) where

import           Data.Default       (def)
import           Data.Maybe         (fromMaybe)
import           Data.Text          (pack, unpack)
import           Database.Bolt      (BoltCfg (..))
import           System.Environment (lookupEnv)

loadBoltCfg :: IO BoltCfg
loadBoltCfg = do
  user <- pack . fromMaybe (unpack $ user def) <$> lookupEnv "NEO4J_USER"
  password <- pack . fromMaybe (unpack $ password def) <$> lookupEnv "NEO4J_PASSWORD"
  host <- fromMaybe (host def) <$> lookupEnv "NEO4J_HOST"
  port <- read . fromMaybe (show $ port def) <$> lookupEnv "NEO4J_BOLT_PORT"
  return def {user, password, host, port}
