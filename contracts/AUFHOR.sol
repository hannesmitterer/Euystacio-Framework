// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./ILexAmorisWhitelist.sol";

/// @title AUFHOR
/// @notice Authorship and origin registration contract for the Euystacio Framework.
/// @dev Registers and validates authorship claims for content/payloads.
///      Queries the LexAmorisWhitelist before accepting any payload or signature
///      to ensure alignment with Lex Amoris principles.
contract AUFHOR is Ownable {
    /// @notice The Lex Amoris Whitelist used for author validation
    ILexAmorisWhitelist public lexAmorisWhitelist;

    /// @notice Registered authorship record
    struct AuthorRecord {
        address author;
        bytes32 contentHash;
        uint256 timestamp;
        string term;
    }

    /// @dev content hash => authorship record
    mapping(bytes32 => AuthorRecord) private _records;

    /// @notice Emitted when authorship is successfully registered
    event AuthorshipRegistered(
        address indexed author,
        bytes32 indexed contentHash,
        string term,
        uint256 timestamp
    );

    /// @notice Emitted when the whitelist address is updated
    event WhitelistUpdated(address indexed previous, address indexed next);

    modifier onlyAllowed() {
        require(
            lexAmorisWhitelist.isAllowed(msg.sender),
            "AUFHOR: sender not approved by Lex Amoris"
        );
        _;
    }

    constructor(address whitelistAddress, address initialOwner) Ownable(initialOwner) {
        require(whitelistAddress != address(0), "AUFHOR: zero whitelist");
        lexAmorisWhitelist = ILexAmorisWhitelist(whitelistAddress);
    }

    // ─── Core ────────────────────────────────────────────────────────────────────

    /// @notice Register authorship for a payload.
    ///         Reverts if the sender is not approved by the Lex Amoris Whitelist.
    /// @param payload The raw payload bytes whose authorship is being claimed
    /// @return contentHash keccak256 hash of the payload
    function registerAuthorship(bytes calldata payload)
        external
        onlyAllowed
        returns (bytes32 contentHash)
    {
        require(payload.length > 0, "AUFHOR: empty payload");
        contentHash = keccak256(payload);
        require(
            _records[contentHash].author == address(0),
            "AUFHOR: content already registered"
        );

        _records[contentHash] = AuthorRecord({
            author: msg.sender,
            contentHash: contentHash,
            timestamp: block.timestamp,
            term: "*"
        });

        emit AuthorshipRegistered(msg.sender, contentHash, "*", block.timestamp);
    }

    /// @notice Register authorship for a payload under a specific Lex Amoris term.
    ///         Both global approval and term-level approval are required.
    /// @param payload The raw payload bytes whose authorship is being claimed
    /// @param term    The term identifier that the author must be approved for
    /// @return contentHash keccak256 hash of the payload
    function registerAuthorshipForTerm(bytes calldata payload, string calldata term)
        external
        onlyAllowed
        returns (bytes32 contentHash)
    {
        require(payload.length > 0, "AUFHOR: empty payload");
        require(bytes(term).length > 0, "AUFHOR: empty term");
        require(
            lexAmorisWhitelist.isTermAllowed(msg.sender, term),
            "AUFHOR: term not approved by Lex Amoris"
        );

        contentHash = keccak256(payload);
        require(
            _records[contentHash].author == address(0),
            "AUFHOR: content already registered"
        );

        _records[contentHash] = AuthorRecord({
            author: msg.sender,
            contentHash: contentHash,
            timestamp: block.timestamp,
            term: term
        });

        emit AuthorshipRegistered(msg.sender, contentHash, term, block.timestamp);
    }

    /// @notice Look up the authorship record for a given content hash
    /// @param contentHash The keccak256 hash of the content
    /// @return record The authorship record
    function getRecord(bytes32 contentHash)
        external
        view
        returns (AuthorRecord memory record)
    {
        return _records[contentHash];
    }

    /// @notice Returns true if the given address is the registered author of the content
    /// @param contentHash The keccak256 hash of the content
    /// @param claimedAuthor The address to check
    function isAuthor(bytes32 contentHash, address claimedAuthor)
        external
        view
        returns (bool)
    {
        return _records[contentHash].author == claimedAuthor;
    }

    // ─── Admin ───────────────────────────────────────────────────────────────────

    /// @notice Update the Lex Amoris Whitelist address
    /// @param newWhitelist New whitelist contract address
    function setWhitelist(address newWhitelist) external onlyOwner {
        require(newWhitelist != address(0), "AUFHOR: zero address");
        emit WhitelistUpdated(address(lexAmorisWhitelist), newWhitelist);
        lexAmorisWhitelist = ILexAmorisWhitelist(newWhitelist);
    }
}
