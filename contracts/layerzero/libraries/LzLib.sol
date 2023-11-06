// SPDX-License-Identifier: BUSL-1.1

pragma solidity >=0.6.0;
pragma experimental ABIEncoderV2;

library LzLib {
  // LayerZero communication
  struct CallParams {
    address payable refundAddress;
    address zroPaymentAddress;
  }

  //---------------------------------------------------------------------------
  // Address type handling

  struct AirdropParams {
    uint256 airdropAmount;
    bytes32 airdropAddress;
  }

  function buildAdapterParams(
    LzLib.AirdropParams memory _airdropParams,
    uint256 _uaGasLimit
  ) internal pure returns (bytes memory adapterParams) {
    if (
      _airdropParams.airdropAmount == 0 &&
      _airdropParams.airdropAddress == bytes32(0x0)
    ) {
      adapterParams = buildDefaultAdapterParams(_uaGasLimit);
    } else {
      adapterParams = buildAirdropAdapterParams(_uaGasLimit, _airdropParams);
    }
  }

  // Build Adapter Params
  function buildDefaultAdapterParams(uint256 _uaGas)
    internal
    pure
    returns (bytes memory)
  {
    // txType 1
    // bytes  [2       32      ]
    // fields [txType  extraGas]
    return abi.encodePacked(uint16(1), _uaGas);
  }

  function buildAirdropAdapterParams(
    uint256 _uaGas,
    AirdropParams memory _params
  ) internal pure returns (bytes memory) {
    require(_params.airdropAmount > 0, "Airdrop amount must be greater than 0");
    require(
      _params.airdropAddress != bytes32(0x0),
      "Airdrop address must be set"
    );

    // txType 2
    // bytes  [2       32        32            bytes[]         ]
    // fields [txType  extraGas  dstNativeAmt  dstNativeAddress]
    return
      abi.encodePacked(
        uint16(2),
        _uaGas,
        _params.airdropAmount,
        _params.airdropAddress
      );
  }

  function getGasLimit(bytes memory _adapterParams)
    internal
    pure
    returns (uint256 gasLimit)
  {
    require(
      _adapterParams.length == 34 || _adapterParams.length > 66,
      "Invalid adapterParams"
    );
    assembly {
      gasLimit := mload(add(_adapterParams, 34))
    }
  }

  // Decode Adapter Params
  function decodeAdapterParams(bytes memory _adapterParams)
    internal
    pure
    returns (
      uint16 txType,
      uint256 uaGas,
      uint256 airdropAmount,
      address payable airdropAddress
    )
  {
    require(
      _adapterParams.length == 34 || _adapterParams.length > 66,
      "Invalid adapterParams"
    );
    assembly {
      txType := mload(add(_adapterParams, 2))
      uaGas := mload(add(_adapterParams, 34))
    }
    require(txType == 1 || txType == 2, "Unsupported txType");
    require(uaGas > 0, "Gas too low");

    if (txType == 2) {
      assembly {
        airdropAmount := mload(add(_adapterParams, 66))
        airdropAddress := mload(add(_adapterParams, 86))
      }
    }
  }

  //---------------------------------------------------------------------------
  // Address type handling
  // TODO: testing
  function bytes32ToAddress(bytes32 _bytes32Address)
    internal
    pure
    returns (address _address)
  {
    require(bytes12(_bytes32Address) == bytes12(0), "Invalid address"); // first 12 bytes should be empty
    return address(uint160(uint256(_bytes32Address)));
  }

  function addressToBytes32(address _address)
    internal
    pure
    returns (bytes32 _bytes32Address)
  {
    return bytes32(uint256(uint160(_address)));
  }
}
