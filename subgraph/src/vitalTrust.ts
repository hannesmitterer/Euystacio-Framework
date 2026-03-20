// AssemblyScript mapping for VitalTrust events (Step 7 – predictive data collection)
import { BigInt, Bytes } from "@graphprotocol/graph-ts";
import {
  Claimed as ClaimedEvent,
  ReputationUpdate as ReputationUpdateEvent,
} from "../generated/VitalTrust/VitalTrust";
import { ClaimEvent, ReputationUpdateEvent as ReputationUpdateEntity } from "../generated/schema";

export function handleClaimed(event: ClaimedEvent): void {
  let id = event.transaction.hash.toHex() + "-" + event.logIndex.toString();
  let entity = new ClaimEvent(id);
  entity.claimant        = event.params.claimant;
  entity.amount          = event.params.amount;
  entity.tokensLeft      = event.params.tokensRemaining;
  entity.blockTimestamp  = event.block.timestamp;
  entity.transactionHash = event.transaction.hash;
  entity.save();
}

export function handleReputationUpdate(event: ReputationUpdateEvent): void {
  let id = event.transaction.hash.toHex() + "-" + event.logIndex.toString();
  let entity = new ReputationUpdateEntity(id);
  entity.ai              = event.params.ai;
  entity.delta           = event.params.delta;
  entity.reason          = event.params.reason;
  entity.blockTimestamp  = event.block.timestamp;
  entity.transactionHash = event.transaction.hash;
  entity.save();
}
