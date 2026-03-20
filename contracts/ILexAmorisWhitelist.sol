// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/utils/introspection/IERC165.sol";

/// @title ILexAmorisWhitelist
/// @notice ERC-165 interface for the Lex Amoris approved-terms whitelist.
///         Any contract that wishes to validate payloads or signatures against
///         the Lex Amoris governance framework must interact through this interface.
interface ILexAmorisWhitelist is IERC165 {
    /// @notice Returns true if `word` is an approved Lex Amoris term.
    /// @param word The term to check (case-sensitive UTF-8 string).
    function isAllowed(string calldata word) external view returns (bool);

    /// @notice Emitted when an approved term is added to the whitelist.
    event TermAdded(string indexed word, address indexed addedBy);

    /// @notice Emitted when an approved term is removed from the whitelist.
    event TermRemoved(string indexed word, address indexed removedBy);
}
