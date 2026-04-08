// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title IExistingContract
 * @notice Interface for existing external contracts that the Nexus Core integrates with.
 *         Provides identity validation and historical action retrieval.
 */
interface IExistingContract {
    /**
     * @notice Validates whether a given user address is a recognised identity.
     * @param user The address of the user to validate.
     * @return True if the identity is valid, false otherwise.
     */
    function validateIdentity(address user) external view returns (bool);

    /**
     * @notice Retrieves the encoded historical actions associated with a user.
     * @param user The address of the user whose history is requested.
     * @return ABI-encoded bytes representing the user's historical actions.
     */
    function getHistoricalActions(address user) external view returns (bytes memory);
}

/**
 * @title NexusCoreLinked
 * @notice The Nexus Core — Seedbringer's Sovereignty.
 *
 * Integrates with existing smart contracts through the IExistingContract interface
 * to validate user identities and retrieve historical actions.  Concordance with the
 * Lex Amoris is enforced by verifying hashed submissions against the canonical Lex
 * Amoris hash and confirming the user's linked identity.  Deviations are neutralised
 * automatically via the Peace Protocols.
 *
 * Architectural Trinity:
 *   1. The Seedbringer  — Hannes Mitterer (Origin & Intellectual Author)
 *   2. The Vacuum Bridge — Distortion-free conduit
 *   3. The Lex Amoris   — Supreme mathematical and ethical law
 *
 * Mathematical Guard:
 *   Φ_Nexus = ∮_V (∇ · LexAmoris) dV = 0   (zero divergence, permanent stability)
 */
contract NexusCoreLinked {
    // -------------------------------------------------------------------------
    // State
    // -------------------------------------------------------------------------

    /// @notice Immutable address of the Seedbringer (contract deployer).
    address public immutable seedbringer;

    /// @dev Canonical hash of the Lex Amoris — the supreme ethical law.
    ///      Pre-computed as keccak256(abi.encodePacked("LexAmoris")) for determinism.
    bytes32 private constant LEX_AMORIS_HASH =
        0xa34c24341a8577185cbf72c100a7aeeedc43166af81df9d10ebca6bd51bbcba2;

    /// @notice Linked external contract used for identity validation.
    IExistingContract public identityContract;

    /// @notice Linked external contract used to retrieve historical action logs.
    IExistingContract public actionLogContract;

    // -------------------------------------------------------------------------
    // Events
    // -------------------------------------------------------------------------

    /// @notice Emitted when a user's linked identity has been validated.
    /// @param user    The address that was validated.
    /// @param isValid Whether the identity was confirmed as valid.
    event IdentityValidated(address indexed user, bool isValid);

    /// @notice Emitted when historical actions for a user have been fetched and logged.
    /// @param user           The address whose history was retrieved.
    /// @param historicalData The raw encoded historical action data.
    event ActionHistoryLogged(address indexed user, bytes historicalData);

    /// @notice Emitted when a submission achieves full concordance with the Lex Amoris.
    /// @param checker The address that triggered the concordance check.
    /// @param message A human-readable confirmation message.
    event ConcordanceAchieved(address indexed checker, string message);

    /// @notice Emitted when a divergence from the Lex Amoris is detected.
    /// @param diverger The address responsible for the divergence.
    /// @param details  A human-readable description of the deviation.
    event DivergenceDetected(address indexed diverger, string details);

    // -------------------------------------------------------------------------
    // Constructor
    // -------------------------------------------------------------------------

    /**
     * @param identityContractAddress  Address of the existing contract that exposes
     *                                 identity validation logic.
     * @param actionLogContractAddress Address of the existing contract that exposes
     *                                 historical action retrieval logic.
     */
    constructor(address identityContractAddress, address actionLogContractAddress) {
        require(identityContractAddress != address(0), "NexusCoreLinked: zero identity address");
        require(actionLogContractAddress != address(0), "NexusCoreLinked: zero action-log address");

        seedbringer = msg.sender;
        identityContract = IExistingContract(identityContractAddress);
        actionLogContract = IExistingContract(actionLogContractAddress);
    }

    // -------------------------------------------------------------------------
    // Modifiers
    // -------------------------------------------------------------------------

    /// @dev Restricts access to the Seedbringer only.
    modifier onlySeedbringer() {
        require(msg.sender == seedbringer, "NexusCoreLinked: caller is not the Seedbringer");
        _;
    }

    // -------------------------------------------------------------------------
    // Public / External Functions
    // -------------------------------------------------------------------------

    /**
     * @notice Validates the linked identity of a user by delegating to the
     *         external identity contract.
     * @param user The address of the user whose identity is being validated.
     * @return isValid True if the external contract confirms the identity.
     */
    function validateLinkedIdentity(address user) external returns (bool isValid) {
        isValid = identityContract.validateIdentity(user);
        emit IdentityValidated(user, isValid);
    }

    /**
     * @notice Fetches historical actions for a user from the external action-log
     *         contract and emits them as an on-chain event.
     * @param user The address of the user whose history is being retrieved.
     */
    function fetchAndLogActions(address user) external {
        bytes memory historicalData = actionLogContract.getHistoricalActions(user);
        emit ActionHistoryLogged(user, historicalData);
    }

    /**
     * @notice Verifies concordance with the Lex Amoris by checking:
     *           1. The submitted hash matches the canonical Lex Amoris hash.
     *           2. The calling user's identity is valid according to the linked
     *              identity contract.
     *         Emits ConcordanceAchieved on success or DivergenceDetected on failure.
     *         Deviations are automatically neutralised via the Peace Protocols.
     * @param submittedHash The hash submitted by the caller for concordance verification.
     * @param user          The address whose identity is checked as part of verification.
     * @return True if full concordance is achieved, otherwise reverts.
     */
    function verifyLexAmoris(bytes32 submittedHash, address user) external returns (bool) {
        bool isIdentityValid = identityContract.validateIdentity(user);
        emit IdentityValidated(user, isIdentityValid);

        if (submittedHash == LEX_AMORIS_HASH && isIdentityValid) {
            emit ConcordanceAchieved(msg.sender, "Lex Amoris and Identity Validated.");
            return true;
        }

        emit DivergenceDetected(
            msg.sender,
            !isIdentityValid
                ? "Divergence detected: identity not valid."
                : "Divergence detected: hash does not match Lex Amoris."
        );
        neutralizeDeviation(msg.sender);

        // neutralizeDeviation always reverts, but the compiler needs a return.
        return false;
    }

    /**
     * @notice Confirms whether an address is the Seedbringer.
     * @param identity The address to check.
     * @return True if identity matches the Seedbringer.
     */
    function validateSeedbringer(address identity) external view returns (bool) {
        return identity == seedbringer;
    }

    /**
     * @notice Allows the Seedbringer to update the linked identity contract address.
     * @param newAddress The new contract address.
     */
    function setIdentityContract(address newAddress) external onlySeedbringer {
        require(newAddress != address(0), "NexusCoreLinked: zero address");
        identityContract = IExistingContract(newAddress);
    }

    /**
     * @notice Allows the Seedbringer to update the linked action-log contract address.
     * @param newAddress The new contract address.
     */
    function setActionLogContract(address newAddress) external onlySeedbringer {
        require(newAddress != address(0), "NexusCoreLinked: zero address");
        actionLogContract = IExistingContract(newAddress);
    }

    // -------------------------------------------------------------------------
    // Internal Functions — Peace Protocols
    // -------------------------------------------------------------------------

    /**
     * @dev Neutralises a detected deviation.  Any action that diverges from the
     *      Nexus principles is logged and immediately halted.  This function always
     *      reverts so that the entire transaction is rolled back.
     */
    function neutralizeDeviation(address /*offender*/) private pure {
        revert("NexusCoreLinked: deviation neutralized by Peace Protocols.");
    }
}
