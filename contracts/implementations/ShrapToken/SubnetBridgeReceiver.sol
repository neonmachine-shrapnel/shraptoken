// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import "../../layerzero/lzApp/NonblockingLzApp.sol";

import "./ISubnetBridgeReceiver.sol";

contract SubnetBridgeReceiver is
  ISubnetBridgeReceiver,
  NonblockingLzApp,
  AccessControlEnumerable
{
  using SafeMath for uint256;
  using ExcessivelySafeCall for address;

  uint256 public constant NO_EXTRA_GAS = 0;
  uint16 public constant FUNCTION_TYPE_SEND = 1;
  bool public useCustomAdapterParams;

  /// ### Storage
  mapping(uint16 => bool) public chainIds;

  /**
   * The constructor for this bridge contract
   * @param _lzEndpoint The lzEndpoint deployed on this network
   * @param _chainId The dest chainId that will be supported at first
   * @param _defaultAdmin The admin of the contract at the time of deployment
   */

  constructor(
    address _lzEndpoint,
    uint16 _chainId,
    address _defaultAdmin
  ) NonblockingLzApp(_lzEndpoint) {
    // chainId is set
    chainIds[_chainId] = true;

    // set up _defaultAdmin with the DEFAULT_ADMIN_ROLE
    _setupRole(DEFAULT_ADMIN_ROLE, _defaultAdmin);
  }

  // Used by offchain sources to pre-emptively calculate gasEstimate cost
  function estimateSendFee(
    uint16 _dstChainId,
    bytes memory _toAddress,
    uint256 _amount,
    bool _useZro,
    bytes memory _adapterParams
  ) public view virtual override returns (uint256 nativeFee, uint256 zroFee) {
    // mock the payload for send()
    bytes memory payload = abi.encode(_toAddress, _amount);
    return
      lzEndpoint.estimateFees(
        _dstChainId,
        address(this),
        payload,
        _useZro,
        _adapterParams
      );
  }

  // fired when the contract recevies the native token
  function nonblockingLzReceive(
    uint16 _srcChainId,
    bytes memory _srcAddress,
    uint64 _nonce,
    bytes memory _payload
  ) public virtual override(ISubnetBridgeReceiver, NonblockingLzApp) {
    require(_msgSender() == address(this), "non-LZApp calling nbLR");
    _nonblockingLzReceive(_srcChainId, _srcAddress, _nonce, _payload);
  }

  function _nonblockingLzReceive(
    uint16 _srcChainId,
    bytes memory _srcAddress,
    uint64, // nonce
    bytes memory _payload
  ) internal override {
    require(chainIds[_srcChainId], "Invalid _srcChainId");

    (bytes memory toAddress, uint256 amount) = abi.decode(
      _payload,
      (bytes, uint256)
    );

    require(toAddress.length == 20, "Invalid Address");

    address sendTo = address(bytes20(toAddress));

    _sendShrap(amount, payable(sendTo));
  }

  /**
   * Contract can receive method
   */
  receive() external payable {}

  /**
   * Allows anyone to deposit straight to the escrow amount
   *
   * @notice Cannot be withdrawn unless it's an admin doing it
   */
  function depositToEscrow() external payable override {
    emit Deposit(msg.sender, msg.value);
  }

  /**
   * Allows an admin role to drain this bridge escrow contract
   */
  function withdrawFromEscrow(uint256 _amountOut, address payable _destination)
    external
    override
    onlyRole(DEFAULT_ADMIN_ROLE)
  {
    emit Withdrawal(msg.sender, _amountOut);
    _sendShrap(_amountOut, _destination);
  }

  /**
   * Helper function to send shrap (the native token of the subnet)
   */
  function _sendShrap(uint256 _amountOut, address payable _destination)
    internal
  {
    (bool sent, ) = _destination.call{ value: _amountOut }("");
    require(sent, "Failed to send Ether");
  }

  // overriding the virtual function in LzReceiver
  function _blockingLzReceive(
    uint16 _srcChainId,
    bytes memory _srcAddress,
    uint64 _nonce,
    bytes memory _payload
  ) internal virtual override {
    (bool success, bytes memory reason) = address(this).excessivelySafeCall(
      gasleft(),
      150,
      abi.encodeWithSelector(
        this.nonblockingLzReceive.selector,
        _srcChainId,
        _srcAddress,
        _nonce,
        _payload
      )
    );
    // try-catch all errors/exceptions
    if (!success) {
      failedMessages[_srcChainId][_srcAddress][_nonce] = keccak256(_payload);
      emit MessageFailed(_srcChainId, _srcAddress, _nonce, _payload, reason);
    }
  }

  // Taken from the OFT Pattern
  function sendFrom(
    address _from,
    uint16 _dstChainId,
    bytes memory _toAddress,
    uint256 _amount,
    address payable _refundAddress,
    address _zroPaymentAddress,
    bytes memory _adapterParams
  ) public payable virtual override {
    require(msg.value > _amount, "amount is greater than value!");
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

  function _send(
    address _from,
    uint16 _dstChainId,
    bytes memory _toAddress,
    uint256 _amount,
    address payable _refundAddress,
    address _zroPaymentAddress,
    bytes memory _adapterParams
  ) internal virtual {
    bytes memory payload = abi.encode(_toAddress, _amount);
    if (useCustomAdapterParams) {
      _checkGasLimit(
        _dstChainId,
        FUNCTION_TYPE_SEND,
        _adapterParams,
        NO_EXTRA_GAS
      );
    } else {
      require(_adapterParams.length == 0, "_adapterParams must be empty");
    }

    // as the msg.value contains gasEstimate + _amount, the gas we send the
    // lzEndpoint needs to be calculated
    uint256 gasToSend = msg.value.sub(_amount);

    _lzSend(
      _dstChainId,
      payload,
      _refundAddress,
      _zroPaymentAddress,
      _adapterParams,
      gasToSend
    );

    emit SendToChain(_dstChainId, _from, _toAddress, _amount);
  }

  // used to update useCustomAdapterParams class var
  function setUseCustomAdapterParams(bool _useCustomAdapterParams)
    external
    override
    onlyRole(DEFAULT_ADMIN_ROLE)
  {
    useCustomAdapterParams = _useCustomAdapterParams;
    emit SetUseCustomAdapterParams(_useCustomAdapterParams);
  }

  // actual class methods
  function toggleChainIdAccepted(uint16 _chainId)
    external
    override
    onlyRole(DEFAULT_ADMIN_ROLE)
  {
    emit ChainIdUpdated(_chainId, chainIds[_chainId]);
    if (chainIds[_chainId]) {
      delete chainIds[_chainId];
    } else {
      chainIds[_chainId] = true;
    }
  }
}
