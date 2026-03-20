// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./ILexAmorisWhitelist.sol";

/// @title AufhorToken (AUFHOR)
/// @notice Simplified AH token that validates all interactions against the
///         Lex Amoris whitelist (Step 1) and supports emergency pause (Step 5).
///
/// @dev    Full ERC-20 functionality can be layered on top; this contract focuses
///         on the Euystacio-specific governance hooks required by the 8-step plan.
contract AufhorToken is Ownable, Pausable, ReentrancyGuard {
    // -----------------------------------------------------------------------
    // State
    // -----------------------------------------------------------------------

    ILexAmorisWhitelist public immutable lexAmorisWhitelist;

    string  public constant name     = "Aufhor Token";
    string  public constant symbol   = "AH";
    uint8   public constant decimals = 18;

    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    // -----------------------------------------------------------------------
    // Events
    // -----------------------------------------------------------------------

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    /// @dev Consumed by ReputationOracle (Step 4).
    event ReputationUpdate(address indexed ai, int256 delta, string reason);

    // -----------------------------------------------------------------------
    // Constructor
    // -----------------------------------------------------------------------

    constructor(address whitelist_, uint256 initialSupply) Ownable(msg.sender) {
        require(whitelist_ != address(0), "AufhorToken: zero whitelist address");
        lexAmorisWhitelist = ILexAmorisWhitelist(whitelist_);
        _mint(msg.sender, initialSupply);
    }

    // -----------------------------------------------------------------------
    // ERC-20 core (whitelist-gated)
    // -----------------------------------------------------------------------

    /// @notice Transfer tokens; `tag` must be an approved Lex Amoris term.
    function transfer(address to, uint256 value, string calldata tag)
        external
        whenNotPaused
        nonReentrant
        returns (bool)
    {
        _requireWhitelisted(tag);
        _transfer(msg.sender, to, value);
        return true;
    }

    function approve(address spender, uint256 value)
        external
        whenNotPaused
        returns (bool)
    {
        allowance[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }

    function transferFrom(address from, address to, uint256 value, string calldata tag)
        external
        whenNotPaused
        nonReentrant
        returns (bool)
    {
        _requireWhitelisted(tag);
        require(allowance[from][msg.sender] >= value, "AufhorToken: insufficient allowance");
        allowance[from][msg.sender] -= value;
        _transfer(from, to, value);
        return true;
    }

    // -----------------------------------------------------------------------
    // Minting (owner only)
    // -----------------------------------------------------------------------

    function mint(address to, uint256 value) external onlyOwner whenNotPaused {
        _mint(to, value);
    }

    // -----------------------------------------------------------------------
    // Pause (Step 5)
    // -----------------------------------------------------------------------

    function pause() external onlyOwner { _pause(); }
    function unpause() external onlyOwner { _unpause(); }

    // -----------------------------------------------------------------------
    // Internal
    // -----------------------------------------------------------------------

    function _requireWhitelisted(string calldata tag) internal {
        if (!lexAmorisWhitelist.isAllowed(tag)) {
            emit ReputationUpdate(msg.sender, -2, "whitelist_violation");
            revert("AufhorToken: tag not in Lex Amoris whitelist");
        }
    }

    function _transfer(address from, address to, uint256 value) internal {
        require(to != address(0), "AufhorToken: transfer to zero address");
        require(balanceOf[from] >= value, "AufhorToken: insufficient balance");
        balanceOf[from] -= value;
        balanceOf[to]   += value;
        emit Transfer(from, to, value);
    }

    function _mint(address to, uint256 value) internal {
        require(to != address(0), "AufhorToken: mint to zero address");
        totalSupply   += value;
        balanceOf[to] += value;
        emit Transfer(address(0), to, value);
    }
}
