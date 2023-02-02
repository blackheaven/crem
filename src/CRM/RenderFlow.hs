{-# LANGUAGE GADTs #-}

module CRM.RenderFlow where

import CRM.Render
import CRM.StateMachine
import "base" Data.String (IsString)
import "text" Data.Text

newtype MachineLabel = MachineLabel {getLabel :: Text}
  deriving newtype (Eq, Show, IsString)

data TreeMetadata a
  = LeafLabel a
  | BinaryLabel (TreeMetadata a) (TreeMetadata a)
  deriving stock (Show)

renderFlow :: TreeMetadata MachineLabel -> StateMachineT m input output -> Either String (Mermaid, MachineLabel, MachineLabel)
renderFlow (LeafLabel label) (Basic machine) =
  Right
    ( Mermaid ("state " <> getLabel label <> " {")
        <> renderGraph (baseMachineAsGraph machine)
        <> Mermaid "}"
    , label
    , label
    )
renderFlow (BinaryLabel leftLabels rightLabels) (Compose machine1 machine2) = do
  (leftMermaid, leftLabelIn, leftLabelOut) <- renderFlow leftLabels machine1
  (rightMermaid, rightLabelIn, rightLabelOut) <- renderFlow rightLabels machine2
  Right
    ( leftMermaid
        <> rightMermaid
        <> Mermaid (getLabel leftLabelOut <> " --> " <> getLabel rightLabelIn)
    , leftLabelIn
    , rightLabelOut
    )
renderFlow (BinaryLabel upperLabels lowerLabels) (Parallel machine1 machine2) = do
  (upperMermaid, upperLabelIn, upperLabelOut) <- renderFlow upperLabels machine1
  (lowerMermaid, lowerLabelIn, lowerLabelOut) <- renderFlow lowerLabels machine2
  let
    inLabel = "fork_" <> getLabel upperLabelIn <> getLabel lowerLabelIn
    outLabel = "join_" <> getLabel upperLabelOut <> getLabel lowerLabelOut
  Right
    ( upperMermaid
        <> lowerMermaid
        <> Mermaid ("state " <> inLabel <> " <<fork>>")
        <> Mermaid ("state " <> outLabel <> " <<join>>")
        <> Mermaid (inLabel <> " --> " <> getLabel upperLabelIn)
        <> Mermaid (inLabel <> " --> " <> getLabel lowerLabelIn)
        <> Mermaid (getLabel upperLabelOut <> " --> " <> outLabel)
        <> Mermaid (getLabel lowerLabelOut <> " --> " <> outLabel)
    , MachineLabel inLabel
    , MachineLabel outLabel
    )
renderFlow (BinaryLabel upperLabels lowerLabels) (Alternative machine1 machine2) = do
  (upperMermaid, upperLabelIn, upperLabelOut) <- renderFlow upperLabels machine1
  (lowerMermaid, lowerLabelIn, lowerLabelOut) <- renderFlow lowerLabels machine2
  let
    inLabel = "fork_choice_" <> getLabel upperLabelIn <> getLabel lowerLabelIn
    outLabel = "join_choice_" <> getLabel upperLabelOut <> getLabel lowerLabelOut
  Right
    ( upperMermaid
        <> lowerMermaid
        <> Mermaid ("state " <> inLabel <> " <<choice>>")
        <> Mermaid ("state " <> outLabel <> " <<choice>>")
        <> Mermaid (inLabel <> " --> " <> getLabel upperLabelIn)
        <> Mermaid (inLabel <> " --> " <> getLabel lowerLabelIn)
        <> Mermaid (getLabel upperLabelOut <> " --> " <> outLabel)
        <> Mermaid (getLabel lowerLabelOut <> " --> " <> outLabel)
    , MachineLabel inLabel
    , MachineLabel outLabel
    )
renderFlow (BinaryLabel forwardLabels backwardsLabels) (Feedback machine1 machine2) = do
  (forwardMermaid, forwardLabelIn, forwardLabelOut) <- renderFlow forwardLabels machine1
  (backwardMermaid, backawardLabelIn, backwardLabelOut) <- renderFlow backwardsLabels machine2
  Right
    ( forwardMermaid
        <> backwardMermaid
        <> Mermaid (getLabel forwardLabelOut <> " --> " <> getLabel backawardLabelIn)
        <> Mermaid (getLabel backwardLabelOut <> " --> " <> getLabel forwardLabelIn)
    , forwardLabelIn
    , forwardLabelOut
    )
renderFlow (BinaryLabel leftLabels rightLabels) (Kleisli machine1 machine2) = do
  (leftMermaid, leftLabelIn, leftLabelOut) <- renderFlow leftLabels machine1
  (rightMermaid, rightLabelIn, rightLabelOut) <- renderFlow rightLabels machine2
  Right
    ( leftMermaid
        <> rightMermaid
        <> Mermaid (getLabel leftLabelOut <> " --> " <> getLabel rightLabelIn)
    , leftLabelIn
    , rightLabelOut
    )
renderFlow labels _ = Left $ "Labels structure " <> show labels <> " does not match machine structure" -- TODO: this sucks

-- renderFlow (Basic machine) = renderMermaid $ baseMachineAsGraph machine
-- renderFlow (Compose smt smt') = _wb
-- renderFlow (Parallel smt smt') = _wc
-- renderFlow (Alternative smt smt') = _wd
-- renderFlow (Feedback smt smt') = _we
-- renderFlow (Kleisli smt smt') = _wf
