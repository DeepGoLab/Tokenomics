// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

library Sig {

    using ECDSA for bytes32;

    function addressHash(address _addr) public pure returns(bytes32) {
        return keccak256(abi.encodePacked(_addr));
    }

    function ethSignedHash(address _addr) public pure returns(bytes32) {
        return keccak256(abi.encodePacked(_addr)).toEthSignedMessageHash();
    }

    function recover(bytes32 hash, bytes memory signature) public pure returns(address) {
        return hash.recover(signature);
    }

    function verified(bytes32 hash, bytes memory signature, address signer) public pure returns (bool){
        return signer == recover(hash, signature);
    }
}
