// AssemblyScript mapping for BridgeAggregator events (Step 7 – predictive data collection)
import { BigInt, Bytes } from "@graphprotocol/graph-ts";
import {
  Rebalanced as RebalancedEvent,
  PoolBalanceUpdated as PoolBalanceUpdatedEvent,
} from "../generated/BridgeAggregator/BridgeAggregator";
import { RebalancedEvent as RebalancedEntity, PoolBalanceSnapshot } from "../generated/schema";

export function handleRebalanced(event: RebalancedEvent): void {
  let id = event.transaction.hash.toHex() + "-" + event.logIndex.toString();
  let entity = new RebalancedEntity(id);
  entity.fromL2          = event.params.from;
  entity.toL2            = event.params.to;
  entity.amount          = event.params.amount;
  entity.blockTimestamp  = event.block.timestamp;
  entity.transactionHash = event.transaction.hash;
  entity.save();
}

export function handlePoolBalanceUpdated(event: PoolBalanceUpdatedEvent): void {
  let id = event.transaction.hash.toHex() + "-" + event.logIndex.toString();
  let entity = new PoolBalanceSnapshot(id);
  entity.l2Id            = event.params.l2Id;
  entity.balance         = event.params.newBalance;
  entity.blockTimestamp  = event.block.timestamp;
  entity.transactionHash = event.transaction.hash;
  entity.save();
}
