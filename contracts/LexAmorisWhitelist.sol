// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "./ILexAmorisWhitelist.sol";

/// @title LexAmorisWhitelist
/// @notice Implements the Lex Amoris approved-terms registry with ERC-165 support.
///         Deployed on Optimism; external AI agents can call `supportsInterface` to
///         verify compatibility before interacting with the Euystacio ecosystem.
/// @dev    Only the contract owner (multi-sig or Seedbringer) may add / remove terms.
contract LexAmorisWhitelist is ILexAmorisWhitelist, ERC165, Ownable {
    /// @dev Mapping from keccak256(word) → approved status.
    mapping(bytes32 => bool) private _allowed;

    // -----------------------------------------------------------------------
    // Constructor – seed the canonical Lex Amoris vocabulary
    // -----------------------------------------------------------------------
    constructor() Ownable(msg.sender) {
        _addTerm("gratitudine");
        _addTerm("resonance");
        _addTerm("seedbringer");
        _addTerm("lex_amoris");
        _addTerm("nexus");
        _addTerm("peacebond");
        _addTerm("vital_trust");
        _addTerm("aufhor");
        _addTerm("silent_bridge");
        _addTerm("cosymbiosis");
        _addTerm("terlano");
        _addTerm("schumann");
        _addTerm("vakuum_lock");
        _addTerm("bio_signal");
        _addTerm("triple_sign");
    }

    // -----------------------------------------------------------------------
    // ILexAmorisWhitelist
    // -----------------------------------------------------------------------

    /// @inheritdoc ILexAmorisWhitelist
    function isAllowed(string calldata word) external view override returns (bool) {
        return _allowed[keccak256(bytes(word))];
    }

    // -----------------------------------------------------------------------
    // Admin
    // -----------------------------------------------------------------------

    /// @notice Add a new approved term to the whitelist.
    function addTerm(string calldata word) external onlyOwner {
        _addTerm(word);
    }

    /// @notice Remove an existing term from the whitelist.
    function removeTerm(string calldata word) external onlyOwner {
        bytes32 key = keccak256(bytes(word));
        require(_allowed[key], "LexAmorisWhitelist: term not found");
        _allowed[key] = false;
        emit TermRemoved(word, msg.sender);
    }

    // -----------------------------------------------------------------------
    // ERC-165
    // -----------------------------------------------------------------------

    /// @inheritdoc ERC165
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC165, IERC165)
        returns (bool)
    {
        return
            interfaceId == type(ILexAmorisWhitelist).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    // -----------------------------------------------------------------------
    // Internal
    // -----------------------------------------------------------------------

    function _addTerm(string memory word) internal {
        bytes32 key = keccak256(bytes(word));
        if (!_allowed[key]) {
            _allowed[key] = true;
            emit TermAdded(word, msg.sender);
        }
    }
}
