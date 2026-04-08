// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/// @title IPriceOracle
/// @notice Minimal interface for a price oracle (Chainlink-compatible).
interface IPriceOracle {
    /// @notice Returns the AH/stablecoin rate scaled to 1e18 for the given L2.
    function getRate(bytes32 l2Id) external view returns (uint256);
}

/// @title BridgeAggregator
/// @notice Manages cross-L2 AH liquidity pools and rebalances them using price
///         oracles (Step 3).  Supports Optimism, Arbitrum, zkSync and any future
///         L2 registered by the owner.
///
///         Rebalancing logic:
///         - Find the pool with the highest AH balance (richest) and the one
///           with the lowest (poorest).
///         - Transfer `delta / 2` units from richest to poorest.
///         - Trigger can be called by an authorised keeper (Gelato / Chainlink)
///           every 12 h.
///
///         Emergency pause (Step 5) limits keeper access during incidents.
contract BridgeAggregator is Ownable, Pausable, ReentrancyGuard {
    // -----------------------------------------------------------------------
    // Types
    // -----------------------------------------------------------------------

    struct L2Pool {
        string  name;       // human-readable label (e.g. "Optimism")
        address bridge;     // canonical bridge contract on this L2
        uint256 balance;    // tracked AH balance (off-chain synced by keeper)
        bool    active;
    }

    // -----------------------------------------------------------------------
    // Constants
    // -----------------------------------------------------------------------

    uint256 public constant REBALANCE_INTERVAL = 12 hours;

    // -----------------------------------------------------------------------
    // State
    // -----------------------------------------------------------------------

    IPriceOracle public priceOracle;

    bytes32[]                    public l2Ids;
    mapping(bytes32 => L2Pool)   public pools;

    mapping(address => bool) public authorisedKeepers;
    uint256 public lastRebalance;

    // -----------------------------------------------------------------------
    // Events
    // -----------------------------------------------------------------------

    event L2Registered(bytes32 indexed l2Id, string name, address bridge);
    event Rebalanced(bytes32 indexed from, bytes32 indexed to, uint256 amount);
    event PoolBalanceUpdated(bytes32 indexed l2Id, uint256 newBalance);
    event KeeperUpdated(address indexed keeper, bool authorised);

    // -----------------------------------------------------------------------
    // Constructor
    // -----------------------------------------------------------------------

    constructor(address oracle_) Ownable(msg.sender) {
        require(oracle_ != address(0), "BridgeAggregator: zero oracle");
        priceOracle = IPriceOracle(oracle_);
    }

    // -----------------------------------------------------------------------
    // Admin
    // -----------------------------------------------------------------------

    /// @notice Register a new L2 pool (Optimism, Arbitrum, zkSync …).
    function registerL2(bytes32 l2Id, string calldata name_, address bridge_)
        external
        onlyOwner
    {
        require(!pools[l2Id].active, "BridgeAggregator: already registered");
        pools[l2Id] = L2Pool({name: name_, bridge: bridge_, balance: 0, active: true});
        l2Ids.push(l2Id);
        emit L2Registered(l2Id, name_, bridge_);
    }

    /// @notice Allow a keeper (Gelato / Chainlink Automation) to trigger rebalance.
    function setKeeper(address keeper, bool authorised) external onlyOwner {
        authorisedKeepers[keeper] = authorised;
        emit KeeperUpdated(keeper, authorised);
    }

    /// @notice Update the price oracle address.
    function setPriceOracle(address oracle_) external onlyOwner {
        require(oracle_ != address(0), "BridgeAggregator: zero oracle");
        priceOracle = IPriceOracle(oracle_);
    }

    // -----------------------------------------------------------------------
    // Balance sync (called by off-chain keeper after bridging events)
    // -----------------------------------------------------------------------

    /// @notice Keeper updates the recorded AH balance for a given L2 pool.
    function updatePoolBalance(bytes32 l2Id, uint256 newBalance)
        external
        whenNotPaused
    {
        require(authorisedKeepers[msg.sender], "BridgeAggregator: not a keeper");
        require(pools[l2Id].active, "BridgeAggregator: unknown L2");
        pools[l2Id].balance = newBalance;
        emit PoolBalanceUpdated(l2Id, newBalance);
    }

    // -----------------------------------------------------------------------
    // Rebalancing (Step 3)
    // -----------------------------------------------------------------------

    /// @notice Trigger a rebalancing cycle.  Can only be called by an authorised
    ///         keeper and at most once per REBALANCE_INTERVAL.
    function rebalance() external whenNotPaused nonReentrant {
        require(authorisedKeepers[msg.sender], "BridgeAggregator: not a keeper");
        require(
            block.timestamp >= lastRebalance + REBALANCE_INTERVAL,
            "BridgeAggregator: too soon"
        );
        require(l2Ids.length >= 2, "BridgeAggregator: need at least 2 L2s");

        lastRebalance = block.timestamp;

        // Find richest and poorest active pool
        bytes32 richId;
        bytes32 poorId;
        uint256 maxBal;
        uint256 minBal = type(uint256).max;

        for (uint256 i = 0; i < l2Ids.length; i++) {
            bytes32 id = l2Ids[i];
            if (!pools[id].active) continue;
            uint256 bal = pools[id].balance;
            if (bal > maxBal) { maxBal = bal; richId = id; }
            if (bal < minBal) { minBal = bal; poorId = id; }
        }

        if (maxBal <= minBal) return; // already balanced

        // Move half the disparity from rich → poor
        uint256 delta = (maxBal - minBal) / 2;
        if (delta == 0) return;

        pools[richId].balance -= delta;
        pools[poorId].balance += delta;

        emit Rebalanced(richId, poorId, delta);
    }

    // -----------------------------------------------------------------------
    // View
    // -----------------------------------------------------------------------

    function getL2Count() external view returns (uint256) {
        return l2Ids.length;
    }

    // -----------------------------------------------------------------------
    // Pause (Step 5)
    // -----------------------------------------------------------------------

    function pause() external onlyOwner { _pause(); }
    function unpause() external onlyOwner { _unpause(); }
}
