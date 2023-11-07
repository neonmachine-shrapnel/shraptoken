// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

import "../../layerzero/BasedOFT.sol";
import "./ISHRAPToken.sol";

/// The SHRAP Token - which is implementing extended BasedOFT functionality
contract SHRAPToken is
  BasedOFT,
  ISHRAPToken,
  ERC20Burnable,
  AccessControlEnumerable
{
  /**
   * Tokens Max totalSupply() value
   * @notice burning decreases the totalSupply() value
   */
  uint256 public constant MAX_SUPPLY = 3_000_000_000 * 1e18; // 3 Billion

  /*
   * Minter role is assigned to an address - this is subject to change depending on
   * initial supply mint design and what design we choose for bridging between
   * mainnet and subnet
   */
  bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

  // used in the constructor to verify fields are not empty
  bytes32 private constant EMPTY_STRING = keccak256(bytes(""));

  /**
   * Guard used on functions that only accounts with minter role can call
   */
  modifier onlyMinter() {
    if (!(hasRole(MINTER_ROLE, msg.sender))) {
      revert NotMinter();
    }
    _;
  }

  /**
   * Contract constructor
   *
   * @param _tokenName - the token name, Shrap
   * @param _tokenSymbol - the token symbol, SHRAP
   * @param _defaultAdmin - the initial admin of the contract
   * @param _layerZeroEndpoint - the contract address of the layer zero endpoint (where transactions for bridges are broadcoast)
   *
   * @notice the contract is initialized without a minter role set
   */
  constructor(
    string memory _tokenName,
    string memory _tokenSymbol,
    address _defaultAdmin,
    address _layerZeroEndpoint
  ) BasedOFT(_tokenName, _tokenSymbol, _layerZeroEndpoint) {
    // check that the token symbol and name are not empty
    if (keccak256(bytes(_tokenName)) == EMPTY_STRING) {
      revert InvalidField("_tokenName");
    }
    if (keccak256(bytes(_tokenSymbol)) == EMPTY_STRING) {
      revert InvalidField("_tokenSymbol");
    }

    // ensure that _default admin passed in is not 0 address
    if (_defaultAdmin == address(0)) {
      revert InvalidField("_defaultAdmin");
    }

    if (_layerZeroEndpoint == address(0)) {
      revert InvalidField("_layerZeroEndpoint");
    }

    // make default admin the default admin of this contract
    _setupRole(DEFAULT_ADMIN_ROLE, _defaultAdmin);
  }

  /**
   * MINTING
   * @param _recipient The address receiving the minted tokens (not this contract)
   * @param _amount The amount to mint to the _recipient address
   */
  function mint(address _recipient, uint256 _amount)
    public
    override
    onlyMinter
  {
    if (_recipient == address(this)) {
      revert NoMintingToContract();
    }
    if (totalSupply() + _amount > MAX_SUPPLY) {
      revert SupplyExhausted();
    }
    emit Mint(_recipient, _amount);
    _mint(_recipient, _amount);
  }

  /**
   * Enforces that this contract can't own anything
   */
  receive() external payable {
    revert UnsupportedMethod();
  }

  /**
   * Allows the user to withdraw ETH/Native token from this contract
   */
  function withdrawForcedEther() external onlyRole(DEFAULT_ADMIN_ROLE) {
    (bool success, ) = payable(msg.sender).call{ value: address(this).balance }(
      ""
    );
    if (!success) {
      revert UnsupportedMethod();
    }
  }

  /**
   * supportsInterface override
   */
  function supportsInterface(bytes4 interfaceId)
    public
    view
    virtual
    override(AccessControlEnumerable, OFT)
    returns (bool)
  {
    return
      interfaceId == type(IOFT).interfaceId ||
      interfaceId == type(IERC20).interfaceId ||
      super.supportsInterface(interfaceId);
  }
}
