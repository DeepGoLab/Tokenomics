// File: access/HasMinters.sol

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";

contract HasMinters is Ownable {
  event MinterAdded(address indexed _minter);
  event MinterRemoved(address indexed _minter);

  address[] public minters;
  mapping (address => bool) public minter;

  modifier onlyMinter {
    require(minter[msg.sender]);
    _;
  }

  function addMinters(address[] memory _addedMinters) public onlyOwner {
    address _minter;

    for (uint256 i = 0; i < _addedMinters.length; i++) {
      _minter = _addedMinters[i];

      if (!minter[_minter]) {
        minters.push(_minter);
        minter[_minter] = true;
        emit MinterAdded(_minter);
      }
    }
  }

  function removeMinters(address[] memory _removedMinters) public onlyOwner {
    address _minter;

    for (uint256 i = 0; i < _removedMinters.length; i++) {
      _minter = _removedMinters[i];

      if (minter[_minter]) {
        minter[_minter] = false;
        emit MinterRemoved(_minter);
      }
    }

    uint256 i = 0;

    while (i < minters.length) {
      _minter = minters[i];

      if (!minter[_minter]) {
        minters[i] = minters[minters.length - 1];
        delete minters[minters.length - 1];
      } else {
        i++;
      }
    }
  }

  function isMinter(address _addr) public view returns (bool) {
    return minter[_addr];
  }

  function getMinters() public view returns (address[] memory) {
    return minters;
  }
}