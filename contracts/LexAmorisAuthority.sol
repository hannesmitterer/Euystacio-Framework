// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "./ILexAmorisWhitelist.sol";

/// @title LexAmorisAuthority (LAA)
/// @notice Governance contract for the Lex Amoris framework.  Validates compliance
///         of AI actions against the whitelist and can trigger ecosystem-wide
///         emergency pause (Step 5).
///
///         The owner is expected to be a multi-sig wallet shared between Hannes
///         (Seedbringer) and the Nexus Core.  In case of a quantum attack or
///         critical vulnerability the owner calls `pause()` which blocks all
///         state-changing operations across the contract.
contract LexAmorisAuthority is Ownable, Pausable {
    // -----------------------------------------------------------------------
    // State
    // -----------------------------------------------------------------------

    ILexAmorisWhitelist public immutable whitelist;

    /// @dev Addresses of contracts that participate in the emergency pause network.
    address[] public pausableContracts;

    // -----------------------------------------------------------------------
    // Events
    // -----------------------------------------------------------------------

    event ComplianceChecked(address indexed ai, string term, bool compliant);
    event PausableContractRegistered(address indexed contractAddr);

    // -----------------------------------------------------------------------
    // Constructor
    // -----------------------------------------------------------------------

    constructor(address whitelist_) Ownable(msg.sender) {
        require(whitelist_ != address(0), "LAA: zero whitelist address");
        whitelist = ILexAmorisWhitelist(whitelist_);
    }

    // -----------------------------------------------------------------------
    // Compliance
    // -----------------------------------------------------------------------

    /// @notice Check whether an AI's action tag is Lex Amoris compliant.
    function checkCompliance(address ai, string calldata term)
        external
        whenNotPaused
        returns (bool compliant)
    {
        compliant = whitelist.isAllowed(term);
        emit ComplianceChecked(ai, term, compliant);
    }

    // -----------------------------------------------------------------------
    // Emergency-pause coordination (Step 5)
    // -----------------------------------------------------------------------

    /// @notice Register a contract address in the emergency-pause network.
    function registerPausableContract(address contractAddr) external onlyOwner {
        require(contractAddr != address(0), "LAA: zero address");
        pausableContracts.push(contractAddr);
        emit PausableContractRegistered(contractAddr);
    }

    function getPausableContractCount() external view returns (uint256) {
        return pausableContracts.length;
    }

    // -----------------------------------------------------------------------
    // Pause (Step 5 – multi-sig owner triggers in emergencies)
    // -----------------------------------------------------------------------

    function pause() external onlyOwner { _pause(); }
    function unpause() external onlyOwner { _unpause(); }
}
