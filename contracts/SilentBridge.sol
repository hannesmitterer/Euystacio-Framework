// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./ILexAmorisWhitelist.sol";

/// @title SilentBridge
/// @notice Distortion-free conduit (Vakuum-Brücke) for transmitting payloads
///         within the Euystacio Framework.
/// @dev Before accepting any payload the contract queries the LexAmorisWhitelist
///      to verify alignment with Lex Amoris principles.
contract SilentBridge is Ownable {
    /// @notice The Lex Amoris Whitelist used for term validation
    ILexAmorisWhitelist public lexAmorisWhitelist;

    /// @notice Emitted when a payload is successfully transmitted
    event PayloadTransmitted(address indexed sender, bytes32 indexed payloadHash);

    /// @notice Emitted when the whitelist address is updated
    event WhitelistUpdated(address indexed previous, address indexed next);

    modifier onlyAllowed() {
        require(
            lexAmorisWhitelist.isAllowed(msg.sender),
            "SilentBridge: sender not approved by Lex Amoris"
        );
        _;
    }

    modifier onlyTermAllowed(string memory term) {
        require(
            lexAmorisWhitelist.isTermAllowed(msg.sender, term),
            "SilentBridge: term not approved by Lex Amoris"
        );
        _;
    }

    constructor(address whitelistAddress, address initialOwner) Ownable(initialOwner) {
        require(whitelistAddress != address(0), "SilentBridge: zero whitelist");
        lexAmorisWhitelist = ILexAmorisWhitelist(whitelistAddress);
    }

    // ─── Core ────────────────────────────────────────────────────────────────────

    /// @notice Transmit a payload through the silent bridge.
    ///         Reverts if the sender is not approved by the Lex Amoris Whitelist.
    /// @param payload The raw payload bytes to transmit
    function transmitPayload(bytes calldata payload)
        external
        onlyAllowed
        returns (bytes32 payloadHash)
    {
        require(payload.length > 0, "SilentBridge: empty payload");
        payloadHash = keccak256(payload);
        emit PayloadTransmitted(msg.sender, payloadHash);
    }

    /// @notice Transmit a payload for a specific Lex Amoris term.
    ///         Both global and term-level whitelist checks are applied.
    /// @param payload The raw payload bytes to transmit
    /// @param term    The term identifier that must be approved (e.g. "PAYLOAD")
    function transmitPayloadForTerm(bytes calldata payload, string calldata term)
        external
        onlyAllowed
        onlyTermAllowed(term)
        returns (bytes32 payloadHash)
    {
        require(payload.length > 0, "SilentBridge: empty payload");
        payloadHash = keccak256(payload);
        emit PayloadTransmitted(msg.sender, payloadHash);
    }

    // ─── Admin ───────────────────────────────────────────────────────────────────

    /// @notice Update the Lex Amoris Whitelist address
    /// @param newWhitelist New whitelist contract address
    function setWhitelist(address newWhitelist) external onlyOwner {
        require(newWhitelist != address(0), "SilentBridge: zero address");
        emit WhitelistUpdated(address(lexAmorisWhitelist), newWhitelist);
        lexAmorisWhitelist = ILexAmorisWhitelist(newWhitelist);
    }
}
