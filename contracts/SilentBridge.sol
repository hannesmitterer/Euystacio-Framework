// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "./ILexAmorisWhitelist.sol";

/// @title SilentBridge
/// @notice Cross-chain messaging bridge with:
///         - Lex Amoris whitelist payload validation (Step 1)
///         - IoT bio-sensor signal ingestion via TripleSign verification (Step 6)
///         - ReputationUpdate events for the ReputationOracle (Step 4)
///         - Emergency pause governed by multi-sig owner (Step 5)
contract SilentBridge is Ownable, Pausable, ReentrancyGuard {
    using ECDSA for bytes32;

    // -----------------------------------------------------------------------
    // Types
    // -----------------------------------------------------------------------

    /// @dev Standard bio-sensor payload structure (Step 6).
    struct BioSignalPayload {
        string  sensorId;   // e.g. "Terlano-Soil-01"
        uint256 timestamp;  // Unix epoch from sensor
        bool    consent;    // true = "YES", false = "NO"
    }

    // -----------------------------------------------------------------------
    // State
    // -----------------------------------------------------------------------

    ILexAmorisWhitelist public immutable lexAmorisWhitelist;

    /// @dev Registered TripleSign signers (sensor node public keys).
    mapping(address => bool) public trustedSigners;

    /// @dev Nonce per sender to prevent replay attacks.
    mapping(address => uint256) public nonces;

    // -----------------------------------------------------------------------
    // Events
    // -----------------------------------------------------------------------

    /// @dev Standard cross-chain message event.
    event Message(
        address indexed from,
        bytes32 indexed payloadHash,
        string  payloadTag,
        uint256 nonce
    );

    /// @dev IoT bio-signal event (Step 6).
    event BioSignal(
        address indexed from,
        string  sensorId,
        bool    consent,
        uint256 sensorTimestamp
    );

    /// @dev ReputationOracle feed (Step 4).
    event ReputationUpdate(address indexed ai, int256 delta, string reason);

    // -----------------------------------------------------------------------
    // Constructor
    // -----------------------------------------------------------------------

    constructor(address whitelist_) Ownable(msg.sender) {
        require(whitelist_ != address(0), "SilentBridge: zero whitelist address");
        lexAmorisWhitelist = ILexAmorisWhitelist(whitelist_);
    }

    // -----------------------------------------------------------------------
    // Signer management (Step 6 – TripleSign node keys)
    // -----------------------------------------------------------------------

    /// @notice Register a trusted IoT node signer.
    function addTrustedSigner(address signer) external onlyOwner {
        require(signer != address(0), "SilentBridge: zero signer");
        trustedSigners[signer] = true;
    }

    /// @notice Revoke a trusted IoT node signer.
    function removeTrustedSigner(address signer) external onlyOwner {
        trustedSigners[signer] = false;
    }

    // -----------------------------------------------------------------------
    // Cross-chain messaging (Step 1 – whitelist validation)
    // -----------------------------------------------------------------------

    /// @notice Post a cross-chain message whose tag must be in the Lex Amoris whitelist.
    /// @param payloadTag   Approved Lex Amoris term describing the payload.
    /// @param payloadHash  keccak256 of the full off-chain payload.
    function postMessage(string calldata payloadTag, bytes32 payloadHash)
        external
        whenNotPaused
        nonReentrant
    {
        // Validate against whitelist (Step 1)
        if (!lexAmorisWhitelist.isAllowed(payloadTag)) {
            emit ReputationUpdate(msg.sender, -2, "whitelist_violation");
            revert("SilentBridge: payload tag not in Lex Amoris whitelist");
        }

        uint256 nonce = nonces[msg.sender]++;
        emit Message(msg.sender, payloadHash, payloadTag, nonce);
        emit ReputationUpdate(msg.sender, 3, "valid_message_published");
    }

    // -----------------------------------------------------------------------
    // IoT bio-sensor ingestion (Step 6)
    // -----------------------------------------------------------------------

    /// @notice Submit a bio-sensor reading signed by a trusted TripleSign node.
    /// @param payload  ABI-encoded BioSignalPayload struct.
    /// @param sig      ECDSA signature over keccak256(payload) by a trusted signer.
    function postBioSignal(bytes calldata payload, bytes calldata sig)
        external
        whenNotPaused
        nonReentrant
    {
        // Verify TripleSign signature
        bytes32 msgHash = keccak256(payload).toEthSignedMessageHash();
        address signer = msgHash.recover(sig);
        require(trustedSigners[signer], "SilentBridge: untrusted signer");

        // Decode payload
        (string memory sensorId, uint256 sensorTimestamp, string memory valueStr) =
            abi.decode(payload, (string, uint256, string));

        // Validate consent value
        bool consent;
        bytes32 valueHash = keccak256(bytes(valueStr));
        if (valueHash == keccak256(bytes("YES"))) {
            consent = true;
        } else if (valueHash == keccak256(bytes("NO"))) {
            consent = false;
        } else {
            revert("SilentBridge: invalid bio-signal value (expected YES or NO)");
        }

        emit BioSignal(msg.sender, sensorId, consent, sensorTimestamp);
        emit ReputationUpdate(msg.sender, 1, "bio_signal_submitted");
    }

    // -----------------------------------------------------------------------
    // Pause (Step 5 – emergency multi-sig governance)
    // -----------------------------------------------------------------------

    function pause() external onlyOwner { _pause(); }
    function unpause() external onlyOwner { _unpause(); }
}
