// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./ILexAmorisWhitelist.sol";

/// @title LexAmorisWhitelist
/// @notice ERC-165 compliant whitelist contract implementing Lex Amoris principles.
///         Validates approved addresses and terms for the Euystacio AI ecosystem.
/// @dev Deployed on Optimism. The interface ID is verifiable via ERC-165 on Etherscan.
contract LexAmorisWhitelist is ILexAmorisWhitelist, ERC165, Ownable {
    // bytes4(keccak256("isAllowed(address)")) ^ bytes4(keccak256("isTermAllowed(address,string)"))
    bytes4 private constant _INTERFACE_ID_LEX_AMORIS =
        type(ILexAmorisWhitelist).interfaceId;

    /// @dev subject => globally whitelisted
    mapping(address => bool) private _allowed;

    /// @dev subject => term => whitelisted
    mapping(address => mapping(bytes32 => bool)) private _termAllowed;

    constructor(address initialOwner) Ownable(initialOwner) {}

    // ─── ERC-165 ────────────────────────────────────────────────────────────────

    /// @inheritdoc ERC165
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC165, IERC165)
        returns (bool)
    {
        return
            interfaceId == _INTERFACE_ID_LEX_AMORIS ||
            super.supportsInterface(interfaceId);
    }

    // ─── Read ────────────────────────────────────────────────────────────────────

    /// @inheritdoc ILexAmorisWhitelist
    function isAllowed(address subject) external view override returns (bool) {
        return _allowed[subject];
    }

    /// @inheritdoc ILexAmorisWhitelist
    function isTermAllowed(address subject, string calldata term)
        external
        view
        override
        returns (bool)
    {
        return _termAllowed[subject][keccak256(bytes(term))];
    }

    // ─── Admin: global whitelist ─────────────────────────────────────────────────

    /// @notice Approve an address under Lex Amoris (all terms)
    /// @param subject Address to whitelist
    function approve(address subject) external onlyOwner {
        require(subject != address(0), "LexAmoris: zero address");
        _allowed[subject] = true;
        emit TermApproved(subject, "*");
    }

    /// @notice Revoke global approval for an address
    /// @param subject Address to remove from whitelist
    function revoke(address subject) external onlyOwner {
        _allowed[subject] = false;
        emit TermRevoked(subject, "*");
    }

    // ─── Admin: term-level whitelist ─────────────────────────────────────────────

    /// @notice Approve a specific term for an address
    /// @param subject Address to whitelist
    /// @param term    Term identifier (e.g. "PAYLOAD", "SIGNATURE")
    function approveTerm(address subject, string calldata term) external onlyOwner {
        require(subject != address(0), "LexAmoris: zero address");
        require(bytes(term).length > 0, "LexAmoris: empty term");
        _termAllowed[subject][keccak256(bytes(term))] = true;
        emit TermApproved(subject, term);
    }

    /// @notice Revoke a specific term for an address
    /// @param subject Address to update
    /// @param term    Term identifier to revoke
    function revokeTerm(address subject, string calldata term) external onlyOwner {
        _termAllowed[subject][keccak256(bytes(term))] = false;
        emit TermRevoked(subject, term);
    }

    // ─── Batch helpers ────────────────────────────────────────────────────────────

    /// @notice Batch-approve multiple addresses (all terms)
    function batchApprove(address[] calldata subjects) external onlyOwner {
        for (uint256 i = 0; i < subjects.length; ++i) {
            require(subjects[i] != address(0), "LexAmoris: zero address");
            _allowed[subjects[i]] = true;
            emit TermApproved(subjects[i], "*");
        }
    }

    /// @notice Batch-revoke multiple addresses
    function batchRevoke(address[] calldata subjects) external onlyOwner {
        for (uint256 i = 0; i < subjects.length; ++i) {
            _allowed[subjects[i]] = false;
            emit TermRevoked(subjects[i], "*");
        }
    }
}
