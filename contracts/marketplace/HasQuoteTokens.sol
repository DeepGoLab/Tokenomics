// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.0;

import "../utils/AccessControl.sol";

contract HasQuoteTokens is AccessControl {
  event QuoteTokenAdded(address indexed _QuoteToken);
  event QuoteTokenRemoved(address indexed _QuoteToken);

  address[] public QuoteTokens;
  mapping (address => bool) public QuoteToken;

  modifier onlyQuoteToken(address _addr) {
    require(QuoteToken[_addr]);
    _;
  }

  function addQuoteTokens(address[] memory _addedQuoteTokens) external onlyAdmin {
    address _QuoteToken;

    for (uint256 i = 0; i < _addedQuoteTokens.length; i++) {
      _QuoteToken = _addedQuoteTokens[i];

      if (!QuoteToken[_QuoteToken]) {
        QuoteTokens.push(_QuoteToken);
        QuoteToken[_QuoteToken] = true;
        emit QuoteTokenAdded(_QuoteToken);
      }
    }
  }

  function removeQuoteTokens(address[] memory _removedQuoteTokens) external onlyAdmin {
    address _QuoteToken;

    for (uint256 i = 0; i < _removedQuoteTokens.length; i++) {
      _QuoteToken = _removedQuoteTokens[i];

      if (QuoteToken[_QuoteToken]) {
        QuoteToken[_QuoteToken] = false;
        emit QuoteTokenRemoved(_QuoteToken);
      }
    }

    uint256 i = 0;

    while (i < QuoteTokens.length) {
      _QuoteToken = QuoteTokens[i];

      if (!QuoteToken[_QuoteToken]) {
        QuoteTokens[i] = QuoteTokens[QuoteTokens.length - 1];
        delete QuoteTokens[QuoteTokens.length - 1];
      } else {
        i++;
      }
    }
  }

  function isQuoteToken(address _addr) public view returns (bool) {
    return QuoteToken[_addr];
  }
}