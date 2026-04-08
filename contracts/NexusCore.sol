// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./ILexAmorisWhitelist.sol";
import "./SilentBridge.sol";
import "./VitalTrust.sol";
import "./AUFHOR.sol";

/// @title NexusCore
/// @notice Central coordination contract for the Euystacio Framework.
/// @dev Implements the NEXUS CORE: THE SEEDBRINGER'S SOVEREIGNTY architecture.
///      Connects SilentBridge, VitalTrust, and AUFHOR through the LexAmorisWhitelist,
///      applying the mathematical guard: Φ_Nexus = ∮_V (∇·LexAmoris) dV = 0
contract NexusCore is Ownable {
    // ─── Seedbringer Identity ─────────────────────────────────────────────────────

    /// @notice The Seedbringer — intellectual origin of the Nexus
    address public immutable seedbringer;

    // ─── Linked contracts ─────────────────────────────────────────────────────────

    /// @notice Lex Amoris Whitelist — supreme ethical/mathematical law
    ILexAmorisWhitelist public lexAmorisWhitelist;

    /// @notice Silent Bridge — distortion-free payload conduit (Vakuum-Brücke)
    SilentBridge public silentBridge;

    /// @notice Vital Trust — signature verification layer
    VitalTrust public vitalTrust;

    /// @notice AUFHOR — authorship and origin registry
    AUFHOR public aufhor;

    // ─── Events ───────────────────────────────────────────────────────────────────

    event ConcordanceAchieved(address indexed checker, string message);
    event DivergenceDetected(address indexed diverger, string details);
    event NexusLinked(
        address indexed whitelist,
        address indexed silentBridge,
        address indexed vitalTrust,
        address aufhor
    );
    event WhitelistUpdated(address indexed previous, address indexed next);

    constructor(
        address whitelistAddress,
        address silentBridgeAddress,
        address vitalTrustAddress,
        address aufhorAddress,
        address initialOwner
    ) Ownable(initialOwner) {
        require(whitelistAddress    != address(0), "NexusCore: zero whitelist");
        require(silentBridgeAddress != address(0), "NexusCore: zero silentBridge");
        require(vitalTrustAddress   != address(0), "NexusCore: zero vitalTrust");
        require(aufhorAddress       != address(0), "NexusCore: zero aufhor");

        seedbringer      = initialOwner;
        lexAmorisWhitelist = ILexAmorisWhitelist(whitelistAddress);
        silentBridge     = SilentBridge(silentBridgeAddress);
        vitalTrust       = VitalTrust(vitalTrustAddress);
        aufhor           = AUFHOR(aufhorAddress);

        emit NexusLinked(whitelistAddress, silentBridgeAddress, vitalTrustAddress, aufhorAddress);
    }

    // ─── Concordance guard ────────────────────────────────────────────────────────

    /// @notice Verify that a caller is aligned with Lex Amoris principles.
    ///         Emits ConcordanceAchieved or DivergenceDetected accordingly.
    /// @param subject The address to verify
    /// @return concordant True if the address is approved
    function verifyConcordance(address subject) external returns (bool concordant) {
        if (lexAmorisWhitelist.isAllowed(subject)) {
            emit ConcordanceAchieved(subject, "Lex Amoris concordance verified.");
            return true;
        }
        emit DivergenceDetected(subject, "Subject diverges from Lex Amoris.");
        return false;
    }

    /// @notice Mathematical guard: models Φ_Nexus = ∮_V (∇·LexAmoris) dV = 0
    ///         Returns true when the proposed action does not introduce divergence
    ///         (i.e. the system remains in equilibrium).
    /// @param actions ABI-encoded description of the proposed actions
    /// @return stable True if the action set preserves Nexus equilibrium
    function applyPhiNexus(bytes calldata actions) external pure returns (bool stable) {
        // Divergence is detected if actions contain the "UnstableAction" sentinel
        return keccak256(actions) != keccak256(abi.encodePacked("UnstableAction"));
    }

    // ─── Seedbringer identity ─────────────────────────────────────────────────────

    /// @notice Returns true if the given address is the Seedbringer
    /// @param identity Address to check
    function isSeedbringer(address identity) external view returns (bool) {
        return identity == seedbringer;
    }

    // ─── Admin ───────────────────────────────────────────────────────────────────

    /// @notice Update the Lex Amoris Whitelist reference used by NexusCore
    /// @param newWhitelist New whitelist contract address
    function setWhitelist(address newWhitelist) external onlyOwner {
        require(newWhitelist != address(0), "NexusCore: zero address");
        emit WhitelistUpdated(address(lexAmorisWhitelist), newWhitelist);
        lexAmorisWhitelist = ILexAmorisWhitelist(newWhitelist);
    }
}
