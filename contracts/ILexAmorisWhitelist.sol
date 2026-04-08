// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/utils/introspection/IERC165.sol";

/// @title ILexAmorisWhitelist
/// @notice Interface for the Lex Amoris Whitelist — ERC-165 compliant
/// @dev Used by SilentBridge, VitalTrust, and AUFHOR to validate approved terms
interface ILexAmorisWhitelist is IERC165 {
    /// @notice Emitted when an address is added to the whitelist
    event TermApproved(address indexed subject, string term);

    /// @notice Emitted when an address is removed from the whitelist
    event TermRevoked(address indexed subject, string term);

    /// @notice Returns true if the given address is approved under Lex Amoris
    /// @param subject The address to validate
    /// @return allowed True if the address is whitelisted
    function isAllowed(address subject) external view returns (bool allowed);

    /// @notice Returns true if a specific term is approved for the given address
    /// @param subject The address to validate
    /// @param term The term identifier to check (e.g. "PAYLOAD", "SIGNATURE")
    /// @return allowed True if the subject-term pair is whitelisted
    function isTermAllowed(address subject, string calldata term) external view returns (bool allowed);
}
