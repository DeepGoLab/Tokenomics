// SPDX-License-Identifier: MIT

/** 
 * Guild NFT
 */

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";
import "../dsp/DeepSeaPlankton.sol";
import "../utils/AccessControl.sol";
import "./PilotStorage.sol";
import "./TreasuryStorage.sol";

contract PilotWhale is AccessControl, Pausable {
    using SafeMath for uint;
    using SafeERC20 for IERC20;

    PilotStorage public pS;
    VoyagerStorage public vS;
    TreasuryStorage public tS;

    constructor(
        address _pilotStorage,
        address _voyagerStorage,
        address _treasuryStorage
    ) notZeroAddress(_pilotStorage) notZeroAddress(_voyagerStorage) notZeroAddress(_treasuryStorage)
    {
        pS = PilotStorage(_pilotStorage);
        vS = VoyagerStorage(_voyagerStorage);
        tS = TreasuryStorage(_treasuryStorage);
    }

    modifier notBanned(uint256 tokenId_, address addr_) {
        require(!pS.isBannedOfPilot(tokenId_, addr_), "Address Is Banned");
        _;
    }

    function withdraw(
        uint256 amount_, 
        address addr_,
        address tokenAddress_
    ) external onlyOwner notZeroAddress(addr_) {
        require(tokenAddress_ != pS.dspAddress() && tokenAddress_ != pS.dgtAddress(), 
                                                  "the token address has been excluded");
        require(IERC20(tokenAddress_).balanceOf(address(this)) >= amount_, 
                                                  "Unsufficient token");
        IERC20(tokenAddress_).safeTransferFrom(address(this), addr_, amount_);
    }

    function setToken0URI(string memory uri_, bool isPilot) onlyAdmin external {
        if (isPilot) {
            pS.token0URI(uri_);
        } else {
            vS.token0URI(uri_);
        }
    }

    function mintPilot(
        bytes memory signature,
        string memory name_,
        uint256 chargeShare_,
        uint256 a_,
        uint256 c_,
        bool isWhitelisted
    ) external activeMint whenNotPaused nonReentrant
    {
        if (isWhitelisted) {
            require(verified(Sig.ethSignedHash(msg.sender), signature), "Not verified");
            // 白名单1个address铸造1次
            require(!pS.getExpiredWhitelist(msg.sender), "Expired");
            // 白名单总数未超
            require(pS.getWhitelistExpired().add(1) <= pS.getMaxWhitelisted(), 
                                                "Mint over max supply of Pilots");
        }
        
        require(pS.getTokenIDWithoutURI(msg.sender) == 0 && 
                pS.getMintTokenIDWithoutURI(msg.sender) == 0, 
                "Set mintTokenURI first");
        
        uint256 tokenID = pS.getTotalMinted();

        if (!isWhitelisted) {
            uint256 mintFee = pS.getMintFee(msg.sender);
            require(IERC20(pS.dgtAddress()).balanceOf(msg.sender) >= mintFee, 
                                                "Unsufficient dgt token");
        }

        pS.mintPilot(msg.sender, tokenID);

        if (tokenID == 0) {
            pS.setTokenURI(tokenID, pS._token0URI());
        } else {
            pS.setMintTokenIDWithoutURI(msg.sender, tokenID);
        }
        
        pS.setName(tokenID, name_); // 设置工会名称
        pS.setChargeShare(tokenID, chargeShare_); // 设置NFT持有者收费比率
        pS.setA(tokenID, a_);
        pS.setC(tokenID, c_);
        pS.setLeader(tokenID, msg.sender);
        
        pS.setTotalMinted(pS.getTotalMinted().add(1));
        if (isWhitelisted) {
            pS.setExpiredWhitelist(msg.sender, true);
            pS.setWhitelistExpired(pS.getWhitelistExpired().add(1));
        }
    }

    // function mintPilot(        
    //     string memory name_,
    //     uint256 chargeShare_,
    //     uint256 a_,
    //     uint256 c_
    // ) external activeMint whenNotPaused nonReentrant
    // {
    //     require(pS.getTokenIDWithoutURI(msg.sender) == 0 && 
    //             pS.getMintTokenIDWithoutURI(msg.sender) == 0, 
    //             "Set MintTokenURI First");

    //     uint256 tokenID = pS.getTotalMinted();

    //     // Pilot铸造费直接作为收入
    //     IERC20(pS.dgtAddress()).safeTransferFrom(msg.sender, address(this), mintFee);
    //     pS.mintPilot(msg.sender, tokenID);

    //     if (tokenID == 0) {
    //         pS.setTokenURI(tokenID, pS._token0URI());
    //     } else {
    //         pS.setMintTokenIDWithoutURI(msg.sender, tokenID);
    //     }
        
    //     pS.setName(tokenID, name_); // 设置工会名称
    //     pS.setChargeShare(tokenID, chargeShare_); // 设置NFT持有者收费比率
    //     pS.setA(tokenID, a_);
    //     pS.setC(tokenID, c_);
    //     pS.setLeader(tokenID, msg.sender);
     
    //     pS.setTotalMinted(pS.getTotalMinted().add(1));
    // }

    function ExtenseVoyager(
        uint256 pilotTokenId_,
        uint256 quarter_
    ) external activeMint whenNotPaused nonReentrant notBanned(pilotTokenId_, msg.sender)
    {
        require(vS.getTokenIDWithoutURI(msg.sender) == 0 && 
                vS.getMintTokenIDWithoutURI(msg.sender) == 0, 
                "Set mintTokenURI first");    
        // 该地址未持有
        uint256 tokenID = vS.voyagerOfAddressOfPilot(pilotTokenId_, msg.sender);
        require( tokenID > 0, "Not Minted or Has been burned");

        // dsp费用
        uint256 monthDSPFee = 3 * quarter_ * (pS.getA(pilotTokenId_) * 
                          vS.voyagerCountOfPilot(pilotTokenId_) ** 2 + 
                          pS.getC(pilotTokenId_)) * pS.tokenDecimal();
        
        require(IERC20(pS.dspAddress()).balanceOf(msg.sender) >= monthDSPFee, 
                                            "Unsufficient dsp token");

        IERC20(pS.dspAddress()).safeTransferFrom(msg.sender, address(tS), monthDSPFee);

        uint256 expiredTime = tS.getAcount(pilotTokenId_, msg.sender).expiredTime;

        if (expiredTime >= block.timestamp) {
            uint256 balance = tS.getAcount(pilotTokenId_, msg.sender).balance;
            expiredTime += uint256(3 * quarter_ * 30 days);
            tS.setAccountExpiredTime(pilotTokenId_, msg.sender, expiredTime);
            tS.setAccountBalance(pilotTokenId_, msg.sender, balance + monthDSPFee);
        } else {
            tS.setAccountBalance(pilotTokenId_, msg.sender, monthDSPFee);
            tS.setAccountNextPayTime(pilotTokenId_, msg.sender, block.timestamp + 30 days);
            tS.setAccountExpiredTime(pilotTokenId_, msg.sender, block.timestamp + quarter_ * 3 * 30 days);
            tS.setAccountClaimed(pilotTokenId_, msg.sender, 0);
            tS.setAccountUnlocked(pilotTokenId_, msg.sender, 0);
        }

        // 如果续费间隔超过一个月清空exp
        if (block.timestamp - expiredTime > 30 days) {
            vS.setExp(pilotTokenId_, msg.sender, 0);
        }
    }

    function mintVoyager(
        uint256 pilotTokenId_,
        uint256 quarter_
    ) external activeMint whenNotPaused nonReentrant notBanned(pilotTokenId_, msg.sender)
    {
        require(vS.getTokenIDWithoutURI(msg.sender) == 0 && 
                vS.getMintTokenIDWithoutURI(msg.sender) == 0, 
                "Set mintTokenURI first");    
        // 该地址未持有
        require(vS.voyagerOfAddressOfPilot(pilotTokenId_, msg.sender) == 0,
                "Already Minted");
        uint256 tokenID = vS.getTotalMinted();
        // dgt费用
        uint256 mintDGTFee = vS.baseMintFee();
        // dsp费用
        uint256 monthDSPFee = quarter_ * 3 * (pS.getA(pilotTokenId_) * 
                              (vS.voyagerCountOfPilot(pilotTokenId_) + 1) ** 2 + 
                              pS.getC(pilotTokenId_)) * pS.tokenDecimal();
        
        vS.mintVoyager(msg.sender, tokenID);

        if (tokenID == 0) {
            vS.setTokenURI(tokenID, vS._token0URI());
        } else {
            vS.setMintTokenIDWithoutURI(msg.sender, tokenID);
        }
        // 账户余额判断
        require(IERC20(pS.dgtAddress()).balanceOf(msg.sender) >= mintDGTFee, 
                                            "Unsufficient dgt token");
        require(IERC20(pS.dspAddress()).balanceOf(msg.sender) >= monthDSPFee, 
                                            "Unsufficient dsp token");
        // 转账到当前合约
        // uint256 toLeader = mintDGTFee / 10;
        IERC20(pS.dgtAddress()).safeTransferFrom(msg.sender, address(this), mintDGTFee - mintDGTFee / 10);
        IERC20(pS.dgtAddress()).safeTransferFrom(msg.sender, address(tS), mintDGTFee / 10);
        IERC20(pS.dspAddress()).safeTransferFrom(msg.sender, address(tS), monthDSPFee);

        // // // nextPayTime初始化，startTime后三天 1次，lastPayTime
        // // // 下一次lock money取决于nextPayTime: 依赖后端轮询
        // // // 1. 时间未到nextPayTime,不支付
        // // // 2. 时间已过nextPayTime 且 未到（nextPayRound + 1）,锁定nextPayTime金额
        // // // 3. 时间超过（nextPayRound + 1）,解锁nextPayRound及之前所有金额给公会长
        uint256 nextPayTime = block.timestamp + uint256(3 days);
        // expiredTime初始化
        uint256 expiredTime = block.timestamp + uint256(3 * quarter_ * 30 days);
        
        vS.setPilotId(tokenID, pilotTokenId_);
        vS.setTotalMinted(vS.getTotalMinted().add(1));
        
        tS.setAccountBalance(pilotTokenId_, msg.sender, monthDSPFee);
        tS.setAccountStartTime(pilotTokenId_, msg.sender, block.timestamp);
        tS.setAccountNextPayTime(pilotTokenId_, msg.sender, nextPayTime);
        tS.setAccountExpiredTime(pilotTokenId_, msg.sender, expiredTime);
        vS.setVoyagerOfAddressOfPilot(pilotTokenId_, msg.sender, tokenID);
        vS.setVoyagerCountOfPilot(pilotTokenId_, vS.voyagerCountOfPilot(pilotTokenId_).add(1));
    }

    function reedemVoyager(uint256 pilotTokenId_) external activeMint whenNotPaused nonReentrant {
        (bool isRepayDGT, uint256 dgtAmount) = tS.reedemVoyager(pilotTokenId_);
        if (isRepayDGT) {
            require(IERC20(pS.dgtAddress()).balanceOf(address(this)) >= dgtAmount, 
                                    "Unsufficient dgt token");
            IERC20(pS.dgtAddress()).safeTransferFrom(address(this), msg.sender, dgtAmount);
        } 

        // 销毁NFT
        vS.burn(pilotTokenId_, msg.sender);
    }

    function reedemVoyagerByLeader(
        uint256 pilotTokenId_,
        address addr_
    ) external activeMint whenNotPaused nonReentrant {
        (bool isRepayDGT, uint256 dgtAmount) = tS.reedemVoyagerByLeader(pilotTokenId_, addr_);
        if (isRepayDGT) {
            require(IERC20(pS.dgtAddress()).balanceOf(address(this)) >= dgtAmount, 
                                    "Unsufficient dgt token");
            IERC20(pS.dgtAddress()).safeTransferFrom(address(this), msg.sender, dgtAmount);
        } 
        // 销毁NFT
        vS.burn(pilotTokenId_, addr_);
        pS.setIsBanned(pilotTokenId_, addr_);
    }

    function setTokenURI(
        address _user, 
        uint256 _tokenid, 
        string memory _tokenURI,
        bool isPilot
    ) external onlyAdmin whenNotPaused
    {
        if (isPilot) {
            // uint256 tokenID = pS.getTokenIDWithoutURI(_user);
            // if (tokenID == 0) {
            uint256 tokenID = pS.getMintTokenIDWithoutURI(_user);
            // }
            
            require(tokenID > 0, "Unvalid token");
            require(pS.ownerOf(tokenID) == _user, "Not owner");
            require(_tokenid == tokenID, "Consistent tokenID");

            pS.setTokenURI(tokenID, _tokenURI);

            // pS.setTokenIDWithoutURI(_user, 0);
            pS.setMintTokenIDWithoutURI(_user, 0);
        } else {
            // uint256 tokenID = vS.getTokenIDWithoutURI(_user);
            // if (tokenID == 0) {
            uint256 tokenID = vS.getMintTokenIDWithoutURI(_user);
            // }
            
            require(tokenID > 0, "Unvalid token");
            require(vS.ownerOf(tokenID) == _user, "Not owner");
            require(_tokenid == tokenID, "Consistent tokenID");

            vS.setTokenURI(tokenID, _tokenURI);

            // vS.setTokenIDWithoutURI(_user, 0);
            vS.setMintTokenIDWithoutURI(_user, 0);            
        }

    }

    function levelUp(
        uint256 tokenID
    ) external whenNotPaused nonReentrant {
        require(tokenID != 0, "TokenID Should Not Be 0");
        require(pS.getMintTokenIDWithoutURI(msg.sender) == 0, 
        // pS.getTokenIDWithoutURI(msg.sender) == 0 && 
                "Set tokenURI first");
        uint256 pilotId = vS.getPilotId(tokenID);
        // uint256 memberTokenId = vS.getVoyagerOfAddressOfPilot(tokenID, msg.sender);
        uint256 level = vS.getLevel(tokenID);
        uint256 fee = vS.getLevelUpFee();
        
        require(IERC20(pS.dgtAddress()).balanceOf(msg.sender) >= fee, 
                                "Unsufficient dgt token");
        require(vS.getExp(pilotId, msg.sender) >= vS.levelUpExp(level));
        IERC20(pS.dgtAddress()).safeTransferFrom(msg.sender, address(this), fee);

        vS.setLevel(tokenID, level + 1);
        // pS.setTokenIDWithoutURI(msg.sender, tokenID);
    }

    function addExp(uint pilotId_, address member_, uint256 exp_) external notZeroAddress(member_) onlyAdmin {
        // tokenID合法
        require(pilotId_ < pS.maxSupply(), "Invalid Token Id");
        // 用户存在
        require(vS.getVoyagerOfAddressOfPilot(pilotId_, member_) > 0, "Invalid Member Address");
        // 设置成员经验值
        vS.setExp(pilotId_, member_, vS.getExp(pilotId_, member_)+exp_);
    }

    // 更换会长: 只能由当前会长完成操作
    function changeLeader(uint256 tokenId_, address leader_) external notZeroAddress(leader_) {
        require(msg.sender == pS.getPilotByTokenId(tokenId_).leader, "Invalid Leader");
        pS.setLeader(tokenId_, leader_);
    }

    function claim(uint256 pilotTokenId_) external {
        require(pS.getLeader(pilotTokenId_) == msg.sender, "Not Leader");
        
        tS.updateAccount(pilotTokenId_, msg.sender);
        // 循环所有voyager账户
        for (uint voyagerTokenId = 1; voyagerTokenId < vS._totalMinted(); voyagerTokenId++) {
            if (vS.getPilotId(voyagerTokenId) != pilotTokenId_) {
                continue;
            }
            address addr_ = vS.ownerOf(voyagerTokenId);
            tS.claimDGT(pilotTokenId_, addr_);
            tS.claimDSP(pilotTokenId_, addr_);
        }
    }
}
