// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.13;

interface ISHRAPToken {
  /// ERRORS
  /**
   * Error thrown when user tries to call the mint method without mint role assigned
   */
  error NotMinter();

  /**
   * Error thrown when the supply is exhausted (amount to mint + totalSupply() > MAX_SUPPLY)
   */
  error SupplyExhausted();

  /**
   * Error thrown when trying to send the ERC20 something
   */
  error UnsupportedMethod();

  /**
   * Error for empty constructor arguments
   * @param _fieldName The argument that was sent
   */
  error InvalidField(string _fieldName);

  /**
   * Error thrown when minting to the SHRAP contract is called
   */
  error NoMintingToContract();

  /// ERRORS
  /**
   * Event emitted when mint function is called
   */
  event Mint(address _recipient, uint256 _amount);

  /**
   * @param _recipient The recipient of the tokens to mint
   * @param _amount The amount of SHRAP to mint
   */
  function mint(address _recipient, uint256 _amount) external;
}
