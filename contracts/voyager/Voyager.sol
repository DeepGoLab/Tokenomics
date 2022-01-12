// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "../utils/AccessControl.sol";
import "../dsp/DeepSeaPlankton.sol";
import "./VoyagerStorageV1.sol";

contract Voyager is AccessControl, Pausable {
    using SafeMath for uint;
    using SafeERC20 for IERC20;

    VoyagerStorageV1 public vS;
    DeepSeaPlankton public dsp;

    constructor(
        address _voyagerStorage
    )
    {
        require(_voyagerStorage != address(0) , "Invalid Address");
        vS = VoyagerStorageV1(_voyagerStorage);
    }
    
    function mintVoyagerByWhitelist(
        bytes memory signature
    ) external sigVerified(signature) activeMint whenNotPaused nonReentrant
    {
        require(vS.getWhitelistLevel(msg.sender)>0, "Level not Set");
        require(vS.getTokenIDWithoutURI(msg.sender) == 0 && 
                vS.getMintTokenIDWithoutURI(msg.sender) == 0, 
                "Set mintTokenURI first");
        require(!vS.getExpiredWhitelist(msg.sender), "Expired");
        require(vS.getWhitelistExpired().add(1) <= vS.getMaxWhitelisted(), 
                                            "Mint over max supply of Voyagers");
        
        uint256 tokenID = vS.getTotalMinted();
        
        vS.mintVoyager(msg.sender, tokenID);
        
        if (tokenID == 0) {
            vS._setTokenURI(tokenID, vS.getToken0URI());
        } else {
            vS.setMintTokenIDWithoutURI(msg.sender, tokenID);
        }

        vS.setLevel(tokenID, vS.getWhitelistLevel(msg.sender));
        
        vS.setTotalMinted(vS.getTotalMinted().add(1));
        vS.setWhitelistLevel(msg.sender, 0); 
        vS.setExpiredWhitelist(msg.sender, true);
        vS.setWhitelistExpired(vS.getWhitelistExpired().add(1));
    }

    function mintVoyager() external activeMint whenNotPaused nonReentrant
    {
        require(vS.getTokenIDWithoutURI(msg.sender) == 0 && 
                vS.getMintTokenIDWithoutURI(msg.sender) == 0, 
                "Set mintTokenURI first");
        
        (uint256 fee1, uint256 fee2) = vS.getMintFee();

        require(IERC20(vS.dgtAddress()).balanceOf(msg.sender) >= fee1, 
                                            "Unsufficient dgt token");
        require(IERC20(vS.dspAddress()).balanceOf(msg.sender) >= fee2, 
                                            "Unsufficient dsp token");

        IERC20(vS.dgtAddress()).safeTransferFrom(msg.sender, address(this), fee1);
        IERC20(vS.dspAddress()).safeTransferFrom(msg.sender, address(this), fee2);

        uint256 tokenID = vS.getTotalMinted();
        vS.mintVoyager(msg.sender, tokenID);
        
        if (tokenID == 0) {
            vS._setTokenURI(tokenID, vS.getToken0URI());
        } else {
            vS.setMintTokenIDWithoutURI(msg.sender, tokenID);
        }
        
        vS.setTotalMinted(vS.getTotalMinted().add(1));
    }

    function levelUp(
        uint256 tokenID
    ) external whenNotPaused nonReentrant
    {
        require(tokenID != 0, "TokenID Should Not Be 0");
        require(vS.getTokenIDWithoutURI(msg.sender) == 0 && 
                vS.getMintTokenIDWithoutURI(msg.sender) == 0, 
                "Set tokenURI first");
        require(vS.getVoyager(vS.getAllVoyagerIndex(tokenID)).level < vS.maxLevel(), 
                                                          "Already max level");

        (uint256 fee1, uint256 fee2) = vS.getLevelUpFeeV2(tokenID);
        
        require(IERC20(vS.dgtAddress()).balanceOf(msg.sender) >= fee1, 
                                            "Unsufficient dgt token");
        require(IERC20(vS.dspAddress()).balanceOf(msg.sender) >= fee2, 
                                            "Unsufficient dsp token");
       
        IERC20(vS.dgtAddress()).safeTransferFrom(msg.sender, address(this), fee1);
        IERC20(vS.dspAddress()).safeTransferFrom(msg.sender, address(this), fee2);

        vS.setTokenLevelCount(msg.sender, vS.getLevel(tokenID), 
                              vS.getTokenLevelCount(msg.sender, 
                                                    vS.getLevel(tokenID)
                                                   ) - 1);
        vS.setLevel(tokenID, vS.getLevel(tokenID) + 1);
        vS.setLevelStartHoldingTime(tokenID, block.timestamp);
        vS.setTokenLevelCount(msg.sender, vS.getLevel(tokenID), 
                    vS.getTokenLevelCount(msg.sender, vS.getLevel(tokenID))+1);
        vS.setTokenIDWithoutURI(msg.sender, tokenID);

        if (vS.getVoyager(vS.getAllVoyagerIndex(tokenID)).level > vS.getMaxLevelOfOwner(msg.sender)) {
            vS.setMaxLevelOfOwner(msg.sender, vS.getVoyager(vS.getAllVoyagerIndex(tokenID)).level);
        }
    }

    function setTokenURI(
        address _user, 
        uint256 _tokenid, 
        uint256 _level, 
        string memory _tokenURI
    ) external onlyAdmin whenNotPaused
    {
        uint256 tokenID = vS.getTokenIDWithoutURI(_user);
        if (tokenID == 0) {
            tokenID = vS.getMintTokenIDWithoutURI(_user);
        }
        uint256 level = vS.getVoyager(vS.getAllVoyagerIndex(tokenID)).level;

        require(tokenID > 0, "Unvalid token");
        require(vS.ownerOf(tokenID) == _user, "Not owner");
        require(_tokenid == tokenID, "Consistent tokenID");
        require(level == _level, "Consistent level");
        require(!vS.getSetByOwner(tokenID, level), "Set over once");
        vS._setTokenURI(tokenID, _tokenURI);

        vS.setTokenIDWithoutURI(_user, 0);
        vS.setMintTokenIDWithoutURI(_user, 0);
        vS.setSetByOwner(tokenID, level, true);
    }

    function changeTokenURI(
        uint256 tokenID, 
        string memory _tokenURI
    ) external onlyAdmin whenNotPaused
    {
        vS._setTokenURI(tokenID, _tokenURI);
    }

    function setToken0URI(
        string memory _tokenURI
    ) external onlyAdmin whenNotPaused
    {
        vS.token0URI(_tokenURI);
    }

    function setWhitelistLevel(
        address addr, 
        uint level
    ) external onlyAdmin 
    {
        vS.setWhitelistLevel(addr, level);
    }

    function setFee1TokenAddress(
        address _token1
    ) external onlyOwner whenNotPaused notZeroAddress(_token1) nonReentrant
    {
        vS.setFee1TokenAddress(_token1);
    }

    function setFee2TokenAddress(
        address _token2
    ) external onlyOwner whenNotPaused notZeroAddress(_token2) nonReentrant
    {
        vS.setFee2TokenAddress(_token2);
        dsp = DeepSeaPlankton(_token2);
    }

    function withdrawDGT(uint256 _amount, address _to) external onlyOwner whenNotPaused nonReentrant {
        require(IERC20(vS.dgtAddress()).balanceOf(address(this)) >= _amount, "Insufficient balance");
        IERC20(vS.dgtAddress()).transfer(_to, _amount);
    }

    function burnDSP() external onlyOwner whenNotPaused nonReentrant {
        dsp.burn(IERC20(vS.dspAddress()).balanceOf(address(this)));
    }    
    
    function setPause() external onlyOwner
    {
        _pause();
        emit Paused(msg.sender);
    }

    function unPause() external onlyOwner
    {
        _unpause();
        emit Unpaused(msg.sender);
    }
}
