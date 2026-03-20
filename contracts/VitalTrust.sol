// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import "./ILexAmorisWhitelist.sol";

/// @title VitalTrust
/// @notice Trust verification contract for the Euystacio Framework.
/// @dev Validates signatures against the Lex Amoris Whitelist before acceptance.
///      Only signers approved by the whitelist may contribute valid signatures.
contract VitalTrust is Ownable {
    using ECDSA for bytes32;

    /// @notice The Lex Amoris Whitelist used for signer validation
    ILexAmorisWhitelist public lexAmorisWhitelist;

    /// @notice Emitted when a signature is accepted
    event SignatureAccepted(address indexed signer, bytes32 indexed messageHash);

    /// @notice Emitted when the whitelist address is updated
    event WhitelistUpdated(address indexed previous, address indexed next);

    constructor(address whitelistAddress, address initialOwner) Ownable(initialOwner) {
        require(whitelistAddress != address(0), "VitalTrust: zero whitelist");
        lexAmorisWhitelist = ILexAmorisWhitelist(whitelistAddress);
    }

    // ─── Core ────────────────────────────────────────────────────────────────────

    /// @notice Verify an ECDSA signature and confirm the recovered signer is
    ///         approved by the Lex Amoris Whitelist.
    /// @param message   The original message that was signed
    /// @param signature The 65-byte ECDSA signature
    /// @return signer   The recovered signer address
    function verifySignature(bytes calldata message, bytes calldata signature)
        external
        returns (address signer)
    {
        bytes32 messageHash = MessageHashUtils.toEthSignedMessageHash(keccak256(message));
        signer = messageHash.recover(signature);

        require(
            lexAmorisWhitelist.isAllowed(signer),
            "VitalTrust: signer not approved by Lex Amoris"
        );

        emit SignatureAccepted(signer, messageHash);
    }

    /// @notice Verify an ECDSA signature for a specific Lex Amoris term.
    ///         Both global approval and term-level approval are required.
    /// @param message   The original message that was signed
    /// @param signature The 65-byte ECDSA signature
    /// @param term      The term identifier that the signer must be approved for
    /// @return signer   The recovered signer address
    function verifySignatureForTerm(
        bytes calldata message,
        bytes calldata signature,
        string calldata term
    ) external returns (address signer) {
        bytes32 messageHash = MessageHashUtils.toEthSignedMessageHash(keccak256(message));
        signer = messageHash.recover(signature);

        require(
            lexAmorisWhitelist.isAllowed(signer),
            "VitalTrust: signer not approved by Lex Amoris"
        );
        require(
            lexAmorisWhitelist.isTermAllowed(signer, term),
            "VitalTrust: term not approved by Lex Amoris"
        );

        emit SignatureAccepted(signer, messageHash);
    }

    // ─── Admin ───────────────────────────────────────────────────────────────────

    /// @notice Update the Lex Amoris Whitelist address
    /// @param newWhitelist New whitelist contract address
    function setWhitelist(address newWhitelist) external onlyOwner {
        require(newWhitelist != address(0), "VitalTrust: zero address");
        emit WhitelistUpdated(address(lexAmorisWhitelist), newWhitelist);
        lexAmorisWhitelist = ILexAmorisWhitelist(newWhitelist);
    }
}
