// AssemblyScript mapping for SilentBridge events (Step 7 – predictive data collection)
import { BigInt, Bytes } from "@graphprotocol/graph-ts";
import {
  Message as MessageEvent,
  BioSignal as BioSignalEvent,
} from "../generated/SilentBridge/SilentBridge";
import { MessageEvent as MessageEntity, BioSignalEvent as BioSignalEntity } from "../generated/schema";

export function handleMessage(event: MessageEvent): void {
  let id = event.transaction.hash.toHex() + "-" + event.logIndex.toString();
  let entity = new MessageEntity(id);
  entity.from            = event.params.from;
  entity.payloadHash     = event.params.payloadHash;
  entity.payloadTag      = event.params.payloadTag;
  entity.nonce           = event.params.nonce;
  entity.blockTimestamp  = event.block.timestamp;
  entity.transactionHash = event.transaction.hash;
  entity.save();
}

export function handleBioSignal(event: BioSignalEvent): void {
  let id = event.transaction.hash.toHex() + "-" + event.logIndex.toString();
  let entity = new BioSignalEntity(id);
  entity.from            = event.params.from;
  entity.sensorId        = event.params.sensorId;
  entity.consent         = event.params.consent;
  entity.sensorTimestamp = event.params.sensorTimestamp;
  entity.blockTimestamp  = event.block.timestamp;
  entity.transactionHash = event.transaction.hash;
  entity.save();
}
