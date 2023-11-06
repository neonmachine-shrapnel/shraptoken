// SPDX-License-Identifier: MIT

pragma solidity 0.8.13;

import "../../layerzero/OFT.sol";

/**
 * The contract that is deployed to other chains (not AVAX mainnet) - and more than likely our subnet
 */
contract BridgedSHRAPToken is OFT {
  // whether the token is shrapnel or not
  bool public immutable isShrapnelChain;
  // layerzero fee handler
  address public immutable feeHandler;

  // used in the constructor to verify fields are not empty
  bytes32 private constant EMPTY_STRING = keccak256(bytes(""));
  /**
   * Error for empty constructor arguments
   * @param _fieldName The argument that was sent
   */
  error InvalidField(string _fieldName);

  /**
   * Contract constructor
   *
   * @param _tokenName - the token name, Shrap
   * @param _tokenSymbol - the token symbol, SHRAP
   * @param _layerZeroEndpoint - the contract address of the layer zero endpoint (where transactions for bridges are broadcoast)
   *
   * @notice the contract is initialized without a minter role set
   */

  constructor(
    string memory _tokenName,
    string memory _tokenSymbol,
    address _layerZeroEndpoint,
    address _feeHandler,
    bool _isShrapnelChain
  ) OFT(_tokenName, _tokenSymbol, _layerZeroEndpoint) {
    feeHandler = _feeHandler;
    isShrapnelChain = _isShrapnelChain;

    // check that the token symbol and name are not empty
    if (keccak256(bytes(_tokenName)) == EMPTY_STRING) {
      revert InvalidField("_tokenName");
    }
    if (keccak256(bytes(_tokenSymbol)) == EMPTY_STRING) {
      revert InvalidField("_tokenSymbol");
    }
    // ensure that _layerZeroEndpoint passed in is not 0 address
    if (_layerZeroEndpoint == address(0)) {
      revert InvalidField("_layerZeroEndpoint");
    }
  }

  function sendFrom(
    address _from,
    uint16 _dstChainId,
    bytes memory _toAddress,
    uint256 _amount,
    address payable _refundAddress,
    address _zroPaymentAddress,
    bytes memory _adapterParams,
    uint256 _fee
  ) public payable override(OFTCore, IOFTCore) {
    if(isShrapnelChain) {
      this.transferFrom(msg.sender, feeHandler, _fee);
    } else {
      require(msg.value >= _fee, "Not enough native sent to pay fee");
    }

    _send(
      _from,
      _dstChainId,
      _toAddress,
      _amount,
      _refundAddress,
      _zroPaymentAddress,
      _adapterParams
    );
  }
}
