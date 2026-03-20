// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./ILexAmorisWhitelist.sol";

/// @title VitalTrust
/// @notice Manages AH token claims with on-chain token-bucket rate-limiting and
///         Lex Amoris whitelist validation.  Emergency pause is controlled by the
///         multi-sig owner (Step 5).  Emits ReputationUpdate events consumed by
///         ReputationOracle (Step 4).
///
/// Rate-limiter design (Step 2):
///   - MAX_TOKENS = 5  → at most 5 claims per 24 h window
///   - REFILL_RATE: 1 token refilled every 5 hours
///   - The bucket is lazily refilled on each interaction.
contract VitalTrust is Ownable, Pausable, ReentrancyGuard {
    // -----------------------------------------------------------------------
    // Types
    // -----------------------------------------------------------------------

    /// @dev Token bucket per claimant address.
    struct Bucket {
        uint256 tokens;
        uint256 lastRefill;
    }

    // -----------------------------------------------------------------------
    // Constants
    // -----------------------------------------------------------------------

    uint256 public constant MAX_TOKENS = 5;
    uint256 public constant REFILL_RATE = 1;          // tokens added per period
    uint256 public constant REFILL_PERIOD = 5 hours;  // period length
    uint256 public constant CLAIM_AMOUNT = 1 ether;   // AH units per claim

    // -----------------------------------------------------------------------
    // State
    // -----------------------------------------------------------------------

    ILexAmorisWhitelist public immutable lexAmorisWhitelist;

    /// @dev token buckets per claimant
    mapping(address => Bucket) private _buckets;

    /// @dev total AH deposited and available
    uint256 public totalPool;

    // -----------------------------------------------------------------------
    // Events
    // -----------------------------------------------------------------------

    event Claimed(address indexed claimant, uint256 amount, uint256 tokensRemaining);
    event Deposited(address indexed depositor, uint256 amount);
    /// @dev Consumed by ReputationOracle (Step 4)
    event ReputationUpdate(address indexed ai, int256 delta, string reason);

    // -----------------------------------------------------------------------
    // Constructor
    // -----------------------------------------------------------------------

    constructor(address whitelist_) Ownable(msg.sender) {
        require(whitelist_ != address(0), "VitalTrust: zero whitelist address");
        lexAmorisWhitelist = ILexAmorisWhitelist(whitelist_);
    }

    // -----------------------------------------------------------------------
    // Funding
    // -----------------------------------------------------------------------

    /// @notice Deposit native AH into the trust pool.
    receive() external payable {
        totalPool += msg.value;
        emit Deposited(msg.sender, msg.value);
    }

    // -----------------------------------------------------------------------
    // Claiming (Step 2 – rate limiter)
    // -----------------------------------------------------------------------

    /// @notice Claim CLAIM_AMOUNT from the pool.
    /// @param payloadTag  A Lex Amoris approved term describing the claim purpose.
    function claim(string calldata payloadTag)
        external
        whenNotPaused
        nonReentrant
    {
        // Step 1 – validate payload against Lex Amoris whitelist
        require(
            lexAmorisWhitelist.isAllowed(payloadTag),
            "VitalTrust: payload tag not in Lex Amoris whitelist"
        );

        // Step 2 – refill bucket lazily
        Bucket storage bucket = _buckets[msg.sender];
        _refillBucket(bucket);

        // Step 2 – check rate limit
        if (bucket.tokens == 0) {
            emit ReputationUpdate(msg.sender, -2, "rate_limit_exceeded");
            revert("VitalTrust: rate limit exceeded");
        }

        // Step 2 – consume one token
        bucket.tokens -= 1;

        // Ensure pool has funds
        require(totalPool >= CLAIM_AMOUNT, "VitalTrust: insufficient pool");
        totalPool -= CLAIM_AMOUNT;

        // Transfer
        (bool ok, ) = payable(msg.sender).call{value: CLAIM_AMOUNT}("");
        require(ok, "VitalTrust: transfer failed");

        emit Claimed(msg.sender, CLAIM_AMOUNT, bucket.tokens);
        emit ReputationUpdate(msg.sender, 1, "successful_claim");
    }

    // -----------------------------------------------------------------------
    // View helpers
    // -----------------------------------------------------------------------

    /// @notice Returns the current (lazily-refilled) token count for `account`.
    function availableTokens(address account) external view returns (uint256) {
        Bucket memory b = _buckets[account];
        if (b.lastRefill == 0) return MAX_TOKENS;
        uint256 elapsed = block.timestamp - b.lastRefill;
        uint256 refilled = (elapsed / REFILL_PERIOD) * REFILL_RATE;
        uint256 total = b.tokens + refilled;
        return total > MAX_TOKENS ? MAX_TOKENS : total;
    }

    // -----------------------------------------------------------------------
    // Pause (Step 5 – emergency multi-sig governance)
    // -----------------------------------------------------------------------

    /// @notice Pause the contract (owner / multi-sig only).
    function pause() external onlyOwner { _pause(); }

    /// @notice Unpause the contract (owner / multi-sig only).
    function unpause() external onlyOwner { _unpause(); }

    // -----------------------------------------------------------------------
    // Internal
    // -----------------------------------------------------------------------

    function _refillBucket(Bucket storage b) internal {
        if (b.lastRefill == 0) {
            b.tokens = MAX_TOKENS;
            b.lastRefill = block.timestamp;
            return;
        }
        uint256 elapsed = block.timestamp - b.lastRefill;
        uint256 periods = elapsed / REFILL_PERIOD;
        if (periods > 0) {
            uint256 refilled = periods * REFILL_RATE;
            b.tokens = b.tokens + refilled > MAX_TOKENS
                ? MAX_TOKENS
                : b.tokens + refilled;
            b.lastRefill += periods * REFILL_PERIOD;
        }
    }
}
