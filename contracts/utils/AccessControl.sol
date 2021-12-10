// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./Sig.sol";

contract AccessControl is Ownable, ReentrancyGuard {
    using SafeMath for uint;

    // event ContractUpgrade(address newContract);
    event AdminTransferred(address oldAdmin, address newAdmin);

    address private _admin;
    address public proxy;
    bool public mintIsActive = true;
    bool public mineIsActive = true;

    constructor() {
        _setAdmin(_msgSender());
    }

    function verified(bytes32 hash, bytes memory signature) public view returns (bool){
        return admin() == Sig.recover(hash, signature);
    }

    /**
     * @dev Returns the address of the current admin.
     */
    function admin() public view virtual returns (address) {
        return _admin;
    }

    /**
     * @dev Throws if called by any account other than the admin.
     */
    modifier onlyAdmin() {
        require(admin() == _msgSender(), "Invalid Admin: caller is not the admin");
        _;
    }

    function _setAdmin(address newAdmin) private {
        address oldAdmin = _admin;
        _admin = newAdmin;
        emit AdminTransferred(oldAdmin, newAdmin);
    }

    function setProxy(address _proxy) external onlyOwner {
        require(_proxy != address(0), "Invalid Address");
        proxy = _proxy;
    }

    modifier onlyProxy() {
        require(proxy == _msgSender(), "Not Permit: caller is not the proxy"); 
        _;
    }

    modifier sigVerified(bytes memory signature) {
        require(verified(Sig.ethSignedHash(msg.sender), signature), "Not verified");
        _;
    }

    modifier activeMint() {
        require(mintIsActive, "Unactive to mint");
        _;
    } 

    modifier activeMine() {
        require(mineIsActive, "Unactive to mine");
        _;
    } 
    
    modifier notZeroAddress(address addr) {
        require(addr != address(0), "Zero address");
        _;
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newAdmin`).
     * Can only be called by the current admin.
     */
    function transferAdmin(address newAdmin) public virtual onlyOwner {
        require(newAdmin != address(0), "Invalid Admin: new admin is the zero address");
        _setAdmin(newAdmin);
    }

    /*
    * Pause sale if active, make active if paused
    */
    function flipMintableState() public onlyAdmin {
        mintIsActive = !mintIsActive;
    }
}
