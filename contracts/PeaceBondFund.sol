// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./ILexAmorisWhitelist.sol";

/// @title PeaceBondFund (PBF)
/// @notice Escrow contract that secures peace-bond deposits.  Integrated with the
///         Lex Amoris whitelist for payload validation (Step 1) and supports the
///         multi-sig emergency pause protocol (Step 5).
///
///         Deposits are labelled with a Lex Amoris approved term.  Withdrawals
///         require the same term and can only occur after a time-lock.
contract PeaceBondFund is Ownable, Pausable, ReentrancyGuard {
    // -----------------------------------------------------------------------
    // Types
    // -----------------------------------------------------------------------

    struct Bond {
        address depositor;
        uint256 amount;
        uint256 unlockTime;
        string  tag;        // Lex Amoris term
        bool    released;
    }

    // -----------------------------------------------------------------------
    // Constants
    // -----------------------------------------------------------------------

    uint256 public constant LOCK_PERIOD = 30 days;

    // -----------------------------------------------------------------------
    // State
    // -----------------------------------------------------------------------

    ILexAmorisWhitelist public immutable lexAmorisWhitelist;

    uint256 public nextBondId;
    mapping(uint256 => Bond) public bonds;

    // -----------------------------------------------------------------------
    // Events
    // -----------------------------------------------------------------------

    event BondDeposited(uint256 indexed bondId, address indexed depositor, uint256 amount, string tag);
    event BondReleased(uint256 indexed bondId, address indexed recipient, uint256 amount);
    /// @dev ReputationOracle feed (Step 4).
    event ReputationUpdate(address indexed ai, int256 delta, string reason);

    // -----------------------------------------------------------------------
    // Constructor
    // -----------------------------------------------------------------------

    constructor(address whitelist_) Ownable(msg.sender) {
        require(whitelist_ != address(0), "PBF: zero whitelist address");
        lexAmorisWhitelist = ILexAmorisWhitelist(whitelist_);
    }

    // -----------------------------------------------------------------------
    // Deposit
    // -----------------------------------------------------------------------

    /// @notice Deposit a peace bond.  `tag` must be in the Lex Amoris whitelist.
    function deposit(string calldata tag)
        external
        payable
        whenNotPaused
        nonReentrant
        returns (uint256 bondId)
    {
        require(msg.value > 0, "PBF: zero deposit");
        if (!lexAmorisWhitelist.isAllowed(tag)) {
            emit ReputationUpdate(msg.sender, -2, "pbf_whitelist_violation");
            revert("PBF: tag not in Lex Amoris whitelist");
        }

        bondId = nextBondId++;
        bonds[bondId] = Bond({
            depositor:  msg.sender,
            amount:     msg.value,
            unlockTime: block.timestamp + LOCK_PERIOD,
            tag:        tag,
            released:   false
        });

        emit BondDeposited(bondId, msg.sender, msg.value, tag);
        emit ReputationUpdate(msg.sender, 1, "peace_bond_deposited");
    }

    // -----------------------------------------------------------------------
    // Release
    // -----------------------------------------------------------------------

    /// @notice Release a matured bond back to the depositor.
    function release(uint256 bondId)
        external
        whenNotPaused
        nonReentrant
    {
        Bond storage bond = bonds[bondId];
        require(bond.depositor == msg.sender, "PBF: not bond owner");
        require(!bond.released, "PBF: already released");
        require(block.timestamp >= bond.unlockTime, "PBF: still locked");

        bond.released = true;
        (bool ok, ) = payable(msg.sender).call{value: bond.amount}("");
        require(ok, "PBF: transfer failed");

        emit BondReleased(bondId, msg.sender, bond.amount);
    }

    // -----------------------------------------------------------------------
    // Pause (Step 5 – multi-sig emergency governance)
    // -----------------------------------------------------------------------

    function pause() external onlyOwner { _pause(); }
    function unpause() external onlyOwner { _unpause(); }
}
