// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";

/// @title ReputationOracle
/// @notice On-chain reputation scoring for AI agents in the Euystacio ecosystem
///         (Step 4).
///
///         Scoring rules applied by authorised callers (VitalTrust, SilentBridge,
///         AufhorToken):
///           +1  successful claim without cooldown violation
///           -2  failed claim attempt (bad signature, whitelist violation, rate limit)
///           +3  valid Message event published with compliant payload
///
///         AI agents and governance contracts can read scores to gate access to
///         bonus liquidity or elevated governance privileges.
contract ReputationOracle is Ownable {
    // -----------------------------------------------------------------------
    // State
    // -----------------------------------------------------------------------

    /// @dev reputation score per AI address (may be negative).
    mapping(address => int256) private _reputation;

    /// @dev contracts authorised to call updateReputation.
    mapping(address => bool) public authorisedCallers;

    // -----------------------------------------------------------------------
    // Events
    // -----------------------------------------------------------------------

    /// @notice Emitted on every score change for real-time event-driven consumers.
    event ReputationChanged(
        address indexed ai,
        int256  delta,
        int256  newScore,
        string  reason
    );
    event CallerAuthorised(address indexed caller, bool authorised);

    // -----------------------------------------------------------------------
    // Constructor
    // -----------------------------------------------------------------------

    constructor() Ownable(msg.sender) {}

    // -----------------------------------------------------------------------
    // Admin
    // -----------------------------------------------------------------------

    /// @notice Grant / revoke authorisation for a contract to update reputations.
    function setAuthorisedCaller(address caller, bool authorised)
        external
        onlyOwner
    {
        require(caller != address(0), "ReputationOracle: zero address");
        authorisedCallers[caller] = authorised;
        emit CallerAuthorised(caller, authorised);
    }

    // -----------------------------------------------------------------------
    // Core
    // -----------------------------------------------------------------------

    /// @notice Update the reputation score of `ai` by `delta`.
    /// @dev    Called by VitalTrust, SilentBridge, AufhorToken via their
    ///         ReputationUpdate events (or directly if the oracle is a listener).
    ///         Only authorised callers may invoke this function.
    function updateReputation(address ai, int256 delta, string calldata reason)
        external
    {
        require(authorisedCallers[msg.sender], "ReputationOracle: not authorised");
        require(ai != address(0), "ReputationOracle: zero AI address");
        _reputation[ai] += delta;
        emit ReputationChanged(ai, delta, _reputation[ai], reason);
    }

    // -----------------------------------------------------------------------
    // View
    // -----------------------------------------------------------------------

    /// @notice Returns the current reputation score for `ai`.
    function getReputation(address ai) external view returns (int256) {
        return _reputation[ai];
    }

    /// @notice Returns true if `ai` has a positive reputation score.
    function isReputable(address ai) external view returns (bool) {
        return _reputation[ai] > 0;
    }
}
