// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./HasMinters.sol";

contract DeepSeaPlankton is ERC20Burnable, HasMinters, ReentrancyGuard {
    
    event AddMintable(address to, uint value);

    constructor() ERC20("Deep Sea Plankton", "DSP") {
        address[] memory _minters = new address[](1);
        _minters[0] = owner();
        addMinters(_minters);
    }

    mapping (address => uint) public mintable;

    function mintByMinter(address _to, uint256 _value) external onlyMinter nonReentrant {
        _mint(_to, _value);
    }

    function addMintable(address _to, uint _value) external onlyMinter nonReentrant {
        mintable[_to] += _value;

        emit AddMintable(_to, _value);
    }

    function mintByUser() external nonReentrant {
        require(mintable[msg.sender] > 0, "No mintable");
        _mint(msg.sender, mintable[msg.sender]);
        mintable[msg.sender] = 0;
    }
}
