# Euystacio Smart Contracts

This directory contains all Solidity smart contracts implementing the
**8-Step AI Ecosystem Expansion Plan** for the Euystacio Framework.

---

## Contract Overview

| Contract | Step | Description |
|---|---|---|
| `ILexAmorisWhitelist.sol` | 1 | ERC-165 interface for the Lex Amoris approved-terms whitelist |
| `LexAmorisWhitelist.sol` | 1 | Whitelist implementation with owner-governed term management |
| `VitalTrust.sol` | 1, 2, 5 | AH claim manager with token-bucket rate-limiter and emergency pause |
| `SilentBridge.sol` | 1, 4, 5, 6 | Cross-chain messaging + IoT bio-sensor ingestion via TripleSign |
| `AufhorToken.sol` | 1, 5 | AH ERC-20 token with whitelist-gated transfers and emergency pause |
| `BridgeAggregator.sol` | 3, 5 | Multi-L2 AH pool manager with keeper-triggered rebalancing |
| `ReputationOracle.sol` | 4 | On-chain AI reputation scoring (+1 / −2 / +3 rules) |
| `LexAmorisAuthority.sol` | 1, 5 | LAA – compliance checker and emergency pause coordinator |
| `PeaceBondFund.sol` | 1, 5 | PBF – time-locked peace-bond escrow with whitelist validation |

---

## Step-by-Step Summary

### Step 1 – Lex Amoris Whitelist
`LexAmorisWhitelist` implements `ILexAmorisWhitelist` (ERC-165).  
All ecosystem contracts (`VitalTrust`, `SilentBridge`, `AufhorToken`, `PeaceBondFund`)
call `isAllowed(tag)` before processing any payload or signature.

### Step 2 – Rate-Limiter in VitalTrust
`VitalTrust` embeds a per-address `Bucket` struct:
- `MAX_TOKENS = 5` (5 claims per full bucket)
- `REFILL_RATE = 1 token / 5 hours` (lazy refill; full bucket refill after 25 hours)
- Violations emit a `ReputationUpdate(ai, -2, "rate_limit_exceeded")` event.

### Step 3 – BridgeAggregator (Multi-L2 Pool)
`BridgeAggregator` maintains an `L2Pool` mapping for Optimism, Arbitrum, zkSync …  
Authorised keepers (Gelato / Chainlink Automation) call `rebalance()` every 12 hours
to equalise pool imbalances using a price oracle.

### Step 4 – Reputation Oracle
`ReputationOracle` stores `int256` scores per AI address.  
`VitalTrust`, `SilentBridge`, `AufhorToken`, `PeaceBondFund` all emit
`ReputationUpdate(ai, delta, reason)` events. An off-chain listener (or a direct
authorised caller) relays updates to `ReputationOracle.updateReputation()`.

### Step 5 – Emergency Pause (Multi-Sig)
All critical contracts (`VitalTrust`, `SilentBridge`, `AufhorToken`,
`BridgeAggregator`, `LexAmorisAuthority`, `PeaceBondFund`) inherit
OpenZeppelin `Pausable`.  Only the owner (multi-sig wallet) can call `pause()` /
`unpause()`.

### Step 6 – IoT Bio-Sensors
`SilentBridge.postBioSignal(payload, sig)` accepts a sensor reading signed by a
trusted TripleSign node (Raspberry Pi / ESP32).  The signature is ECDSA-verified
on-chain.  Consent values are validated as `"YES"` or `"NO"`.  The event
`BioSignal(from, sensorId, consent, sensorTimestamp)` is emitted.

### Step 7 – Predictive Analysis (TheGraph Subgraph)
See [`../subgraph/`](../subgraph/). The subgraph indexes `Claimed`, `Message`,
`BioSignal`, `Rebalanced`, and `PoolBalanceUpdated` events into a queryable data
lake for Prophet / LSTM time-series forecasting models.

### Step 8 – Continuous Monitoring
See [`../monitoring/`](../monitoring/):
- `grafana-dashboard.json` – pre-built Grafana dashboard panels.
- `alert-rules.yml` – Prometheus alert rules (pool depletion, negative reputation,
  sensor silence, overdue rebalancing).
- `alertmanager.yml` – Telegram / Discord notification routing.

---

## Dependencies

```json
{
  "@openzeppelin/contracts": "^5.0.0"
}
```

## Deployment Order

1. `LexAmorisWhitelist` (no dependencies)
2. `ReputationOracle` (no dependencies)
3. `LexAmorisAuthority` (← whitelist address)
4. `VitalTrust` (← whitelist address)
5. `SilentBridge` (← whitelist address)
6. `AufhorToken` (← whitelist address)
7. `PeaceBondFund` (← whitelist address)
8. `BridgeAggregator` (← price oracle address)

After deployment:
- Register each contract as an authorised caller in `ReputationOracle`.
- Configure `BridgeAggregator` keepers and register L2 pools.
- Add trusted IoT signers to `SilentBridge`.
- Register all pausable contracts in `LexAmorisAuthority`.
