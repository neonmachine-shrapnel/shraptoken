// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

interface ISubnetBridgeReceiver {
  /**
   * nSHRAP = native token of the Shrapnel Subnet
   * SHRAP = ERC20 Shrap Token on AVAX C Chain
   *
   * Note: ChainIds here are used for example - these are not the real values
   *
   *  Shrapnel Subnet (ChainId 1)                                              AVAX C-Chain (ChainId 2)
   *  ┌──────────────────────────────────────────┐                             ┌──────────────────────────────────────────┐
   *  │                                          │                             │                                          │
   *  │   ┌───────────────────┐                  │                             │   ┌───────────────────┐                  │
   *  │   │ User (address X)  │                  │                             │   │ User (address X)  │                  │
   *  │   │ Balance 10 nSHRAP │                  │                             │   │ Balance 10 SHRAP  │                  │
   *  │   │                   │                  │                             │   │                   │                  │
   *  │   └──┬────────────────┘                  │                             │   └───▲───────────────┘                  │
   *  │      │                                   │                             │       │                                  │
   *  │      │  sendFrom(                        │                             │       │                                  │
   *  │      │   X, // from                      │                             │       │                                  │
   *  │      │   2, // dest chainId              │                             │       │                                  │
   *  │      │   X, // to on dest chain          │                             │       │                                  │
   *  │      │   amount, // tokens to send (wei) │                             │       │                                  │
   *  │      │   X, // LZ refund address (fees)  │                             │       │                                  │
   *  │      │   zeroAddress, // future param    │                             │       │                                  │
   *  │      │   adapterParams,                  │                             │       │  transfer(                       │
   *  │      │   { value: amount + fee }         │                             │       │    ShrapToken.address,           │
   *  │      │  );                               │                             │       │    X,                            │
   *  │      │                                   │                             │       │    amount                        │
   *  │      │                                   │                             │       │  );                              │
   *  │      │                                   │                             │       │                                  │
   *  │      │                                   │                             │       │                                  │
   *  │      │                                   │                             │       │                                  │
   *  │    ┌─▼───────────────────────────┐       │                             │    ┌──┴──────────────────────────┐       │
   *  │    │                             │       │                             │    │                             │       │
   *  │    │ SubnetReceiverBridge.sol    │       │                             │    │ ShrapToken.sol              │       │
   *  │    │                             │       │                             │    │                             │       │
   *  │    │                             │       │                             │    │                             │       │
   *  │    │ balance of this contract:   │       │                             │    │                             │       │
   *  │    │ amount                      │       │     ┌────────────────┐      │    │                             │       │
   *  │    │                             │       │     │   Layerzero    │      │    │                             │       │
   *  │    │                             ├───────┼─────►   Offchain     ├──────┼────►                             │       │
   *  │    │                             │  fee  │     │ Infrastructure │      │    │                             │       │
   *  │    │                             │       │     └────────────────┘      │    │                             │       │
   *  │    │                             │       │                             │    │                             │       │
   *  │    └─────────────────────────────┘       │                             │    └─────────────────────────────┘       │
   *  │                                          │                             │                                          │
   *  └──────────────────────────────────────────┘                             └──────────────────────────────────────────┘
   */

  /// ### Events
  /**
   * @dev Emitted when `_amount` tokens are moved from the `_sender` to (`_dstChainId`, `_toAddress`)
   * `_nonce` is the outbound nonce
   */
  event SendToChain(
    uint16 indexed _dstChainId,
    address indexed _from,
    bytes indexed _toAddress,
    uint256 _amount
  );

  /**
   * @dev Emitted when `_amount` tokens are received from `_srcChainId` into the `_toAddress` on the local chain.
   * `_nonce` is the inbound nonce.
   */
  event ReceiveFromChain(
    uint16 indexed _srcChainId,
    bytes indexed _srcAddress,
    address indexed _toAddress,
    uint256 _amount
  );

  // event emitted when ChainId mapping is updated (so we can bridge to multiple chains)
  event ChainIdUpdated(uint16 _chainId, bool _status);

  // event emitted when someone deposits to the contract
  event Deposit(address _depositor, uint256 _amount);

  // event emitted when someone withdraws from the contract
  event Withdrawal(address _withdrawer, uint256 _amount);

  // event emitted when useCustomAdapterParams is updated
  event SetUseCustomAdapterParams(bool _useCustomAdapterParams);

  /// FUNCTIONS

  /**
   * External function used to help calculate gas amount user has to know to bridge funds
   */
  function estimateSendFee(
    uint16 _dstChainId,
    bytes memory _toAddress,
    uint256 _amount,
    bool _useZro,
    bytes memory _adapterParams
  ) external returns (uint256 nativeFee, uint256 zroFee);

  /**
   * Function used to update class variable useCustomAdapterParams
   */
  function setUseCustomAdapterParams(bool _useCustomAdapterParams) external;

  /**
   * Function called by LZEndpoint when bridging into this network (from ERC20 to Native)
   */
  function nonblockingLzReceive(
    uint16 _srcChainId,
    bytes memory _srcAddress,
    uint64 _nonce,
    bytes memory _payload
  ) external;

  /**
   * Allows any address to deposit the native token to the contract
   */
  function depositToEscrow() external payable;

  /**
   * Allows the DEFAULT_ADMIN_ROLE to withdraw the native token from the contract
   */
  function withdrawFromEscrow(uint256 _amountOut, address payable _destination)
    external;

  /**
   * Function that allows the DEFAULT_ADMIN_ROLE to add new supported chain ids to the bridge
   */
  function toggleChainIdAccepted(uint16 _chainId) external;

  /**
   * The function used to swap and send native token to ERC20
   *
   * @param _from The address sending the native token
   * @param _dstChainId The destination chainId
   * @param _toAddress The address to send the tokens on the destination chain
   * @param _amount The amount to send
   * @param _refundAddress The refund address if gas is miscalculated
   * @param _zroPaymentAddress TODO: No idea what this does ?
   * @param _adapterParams allows for configuration of custom data in the request
   */
  function sendFrom(
    address _from,
    uint16 _dstChainId,
    bytes memory _toAddress,
    uint256 _amount,
    address payable _refundAddress,
    address _zroPaymentAddress,
    bytes memory _adapterParams
  ) external payable;
}
