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
    DeepSeaPlankton public dsp;

    constructor(
        address _pilotStorage,
        address _voyagerStorage,
        address _treasuryStorage
    ) notZeroAddress(_pilotStorage)
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
        address addr_
    ) external onlyOwner notZeroAddress(addr_) {
        require(IERC20(pS.dgtAddress()).balanceOf(address(this)) >= amount_, 
                                                  "Unsufficient dgt token");
        IERC20(pS.dspAddress()).safeTransferFrom(address(this), addr_, amount_);
    }

    function mintPilotByWhitelist(
        bytes memory signature,
        string memory name_,
        uint256 chargeShare_,
        uint256 a_,
        uint256 c_
    ) external sigVerified(signature) activeMint whenNotPaused nonReentrant
    {
        require(pS.getTokenIDWithoutURI(msg.sender) == 0 && 
                pS.getMintTokenIDWithoutURI(msg.sender) == 0, 
                "Set mintTokenURI first");
        // 白名单1个address铸造1次
        require(!pS.getExpiredWhitelist(msg.sender), "Expired");
        // 白名单总数未超
        require(pS.getWhitelistExpired().add(1) <= pS.getMaxWhitelisted(), 
                                            "Mint over max supply of Pilots");
        
        uint256 tokenID = pS.getTotalMinted();
        
        pS.mintPilot(msg.sender, tokenID);
        
        pS.setMintTokenIDWithoutURI(msg.sender, tokenID);
        pS.setName(tokenID, name_); // 设置工会名称
        pS.setChargeShare(tokenID, chargeShare_); // 设置NFT持有者收费比率
        pS.setA(tokenID, a_);
        pS.setC(tokenID, c_);
        
        pS.setTotalMinted(pS.getTotalMinted().add(1));
        pS.setExpiredWhitelist(msg.sender, true);
        pS.setWhitelistExpired(pS.getWhitelistExpired().add(1));
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
        uint256 monthDSPFee = pS.getA(pilotTokenId_) * 
                          (vS.voyagerCountOfPilot(pilotTokenId_) + 1) ** 2 + 
                          pS.getC(pilotTokenId_);
        // 账户余额判断
        require(IERC20(pS.dgtAddress()).balanceOf(msg.sender) >= mintDGTFee, 
                                            "Unsufficient dgt token");
        require(IERC20(pS.dspAddress()).balanceOf(msg.sender) >= monthDSPFee, 
                                            "Unsufficient dsp token");
        // 转账到当前合约
        uint256 toLeader = mintDGTFee / 10;
        IERC20(pS.dgtAddress()).safeTransferFrom(msg.sender, address(this), mintDGTFee - toLeader);
        IERC20(pS.dgtAddress()).safeTransferFrom(msg.sender, address(tS), toLeader);
        IERC20(pS.dspAddress()).safeTransferFrom(msg.sender, address(tS), monthDSPFee);

        // nextPayTime初始化，startTime后三天 1次，lastPayTime
        // 下一次lock money取决于nextPayTime: 依赖后端轮询
        // 1. 时间未到nextPayTime,不支付
        // 2. 时间已过nextPayTime 且 未到（nextPayRound + 1）,锁定nextPayTime金额
        // 3. 时间超过（nextPayRound + 1）,解锁nextPayRound及之前所有金额给公会长
        uint256 nextPayTime = block.timestamp + uint256(3 days);
        // expiredTime初始化
        uint256 expiredTime = block.timestamp + uint256(3 * quarter_ * 30 days);

        vS.mintVoyager(msg.sender, tokenID);
        vS.setMintTokenIDWithoutURI(msg.sender, tokenID);
        vS.setPilotId(tokenID, pilotTokenId_);
        
        tS.setAccountBalance(pilotTokenId_, msg.sender, monthDSPFee);
        tS.setAccountStartTime(pilotTokenId_, msg.sender, block.timestamp);
        tS.setAccountNextPayTime(pilotTokenId_, msg.sender, nextPayTime);
        tS.setAccountExpiredTime(pilotTokenId_, msg.sender, expiredTime);
    }

    function reedemVoyager(uint256 pilotTokenId_) external activeMint whenNotPaused nonReentrant {
        // 该地址持有
        require(vS.voyagerOfAddressOfPilot(pilotTokenId_, msg.sender) > 0,
                "No Voyager Token Hold");
        // 退款
        tS.updateAccount(pilotTokenId_, msg.sender);
        tS.repayDSP(pilotTokenId_, msg.sender);

        bool isRepayDGT = tS.checkRepayDGT(pilotTokenId_, msg.sender);
        uint256 mintDGTFee = vS.baseMintFee();
        uint256 toLeader = mintDGTFee / 10;
        if (isRepayDGT) {
            require(IERC20(pS.dgtAddress()).balanceOf(address(tS)) >= toLeader, 
                                    "Unsufficient dgt token");
            IERC20(pS.dgtAddress()).safeTransferFrom(address(tS), msg.sender, toLeader);
            require(IERC20(pS.dgtAddress()).balanceOf(address(this)) >= mintDGTFee - toLeader, 
                                    "Unsufficient dgt token");
            IERC20(pS.dgtAddress()).safeTransferFrom(address(this), msg.sender, mintDGTFee - toLeader);
        } else {
            require(IERC20(pS.dgtAddress()).balanceOf(address(tS)) >= toLeader, 
                                    "Unsufficient dgt token");
            IERC20(pS.dgtAddress()).safeTransferFrom(address(tS),
                                                     pS.getLeader(pilotTokenId_),
                                                     toLeader);
        }

        // 销毁NFT
        vS.burn(pilotTokenId_, msg.sender);
    }

    function reedemVoyagerByLeader(
        uint256 pilotTokenId_,
        address addr_
    ) external activeMint whenNotPaused nonReentrant {
        // msg.sender是圈主
        address leader = pS.getPilotByTokenId(pilotTokenId_).leader;
        require(leader == msg.sender, "Not Leader");

        // 该地址持有VoyagerNFT
        require(vS.voyagerOfAddressOfPilot(pilotTokenId_, addr_) > 0,
                "No Voyager Token Hold");
        // 退款
        tS.updateAccount(pilotTokenId_, addr_);
        tS.repayDSP(pilotTokenId_, addr_);
        // 可退DGT
        bool isRepayDGT = tS.checkRepayDGT(pilotTokenId_, msg.sender);
        uint256 mintDGTFee = vS.baseMintFee();
        uint256 toLeader = mintDGTFee / 10;
        if (isRepayDGT) {
            require(IERC20(pS.dgtAddress()).balanceOf(address(tS)) >= toLeader, 
                                    "Unsufficient dgt token");
            IERC20(pS.dgtAddress()).safeTransferFrom(address(tS), msg.sender, toLeader);
            require(IERC20(pS.dgtAddress()).balanceOf(address(this)) >= mintDGTFee - toLeader, 
                                    "Unsufficient dgt token");
            IERC20(pS.dgtAddress()).safeTransferFrom(address(this), msg.sender, mintDGTFee - toLeader);
        } else {
            require(IERC20(pS.dgtAddress()).balanceOf(address(tS)) >= toLeader, 
                                    "Unsufficient dgt token");
            IERC20(pS.dgtAddress()).safeTransferFrom(address(tS),
                                                     pS.getLeader(pilotTokenId_),
                                                     toLeader);
        }

        // 销毁NFT
        vS.burn(pilotTokenId_, addr_);
        pS.setIsBanned(pilotTokenId_, addr_);
    }

    function mintPilot(        
        string memory name_,
        uint256 chargeShare_,
        uint256 a_,
        uint256 c_
    ) external activeMint whenNotPaused nonReentrant
    {
        require(pS.getTokenIDWithoutURI(msg.sender) == 0 && 
                pS.getMintTokenIDWithoutURI(msg.sender) == 0, 
                "Set MintTokenURI First");
        require(pS.getTotalMinted() >= pS.getMaxWhitelisted(), 
                "Whitelist Mint First");

        uint256 tokenID = pS.getTotalMinted();
        uint256 mintFee = pS.getMintFee(msg.sender);
        require(IERC20(pS.dgtAddress()).balanceOf(msg.sender) >= mintFee, 
                                            "Unsufficient dgt token");
        // Pilot铸造费直接作为收入
        IERC20(pS.dgtAddress()).safeTransferFrom(msg.sender, address(this), mintFee);
        pS.mintPilot(msg.sender, tokenID);
        
        pS.setMintTokenIDWithoutURI(msg.sender, tokenID);
        pS.setName(tokenID, name_);
        pS.setChargeShare(tokenID, chargeShare_);
        pS.setA(tokenID, a_);
        pS.setC(tokenID, c_);

        pS.setTotalMinted(pS.getTotalMinted().add(1));
    }

    function levelUp(
        uint256 tokenID
    ) external whenNotPaused nonReentrant {
        require(tokenID != 0, "TokenID Should Not Be 0");
        require(pS.getTokenIDWithoutURI(msg.sender) == 0 && 
                pS.getMintTokenIDWithoutURI(msg.sender) == 0, 
                "Set tokenURI first");

        PilotStorage.Fee memory fee = pS.getLevelUpFee(tokenID);
        
        if (fee.token1 != address(0)) {
            require(IERC20(fee.token1).balanceOf(msg.sender) >= fee.amount1, 
                                            "Unsufficient token1");
            IERC20(fee.token1).safeTransferFrom(msg.sender, address(this), fee.amount1);
        }
        
        if (fee.token2 != address(0)) {
            require(IERC20(fee.token2).balanceOf(msg.sender) >= fee.amount2, 
                                            "Unsufficient token2");
            IERC20(fee.token2).safeTransferFrom(msg.sender, address(this), fee.amount2);
        }

        pS.setLevel(tokenID, pS.getLevel(tokenID) + 1);
        pS.setTokenIDWithoutURI(msg.sender, tokenID);
    }

    function addExp(uint tokenId_, address member_, uint256 exp_) external notZeroAddress(member_) {
        // tokenID合法
        require(tokenId_ < pS.maxSupply(), "Invalid Token Id");
        // 用户存在
        require(vS.getVoyagerOfAddressOfPilot(tokenId_, member_) > 0, "Invalid Member Address");
        // 设置成员经验值
        pS.setExp(tokenId_, member_, pS.getExp(tokenId_, member_)+exp_);
    }

    function levelUpByVoyager(uint tokenId_) external {
        address member_ = msg.sender;
        uint256 memberTokenId = vS.getVoyagerOfAddressOfPilot(tokenId_, member_);
        uint256 level = vS.getLevel(memberTokenId);
        if (pS.exp(tokenId_, member_) >= pS.levelUpExp(level)) {
            require(IERC20(pS.dgtAddress()).balanceOf(member_) >= vS.levelUpFee(), 
                        "Unsufficient dgt token");
            IERC20(pS.dgtAddress()).safeTransferFrom(member_, address(this), vS.levelUpFee());
            level += 1;
            pS.setLevel(memberTokenId, level);
        }
    }

    function setLevelUpFee(
        uint256 tokenId_,
        PilotStorage.Fee memory fee_
    ) external onlyOwner {
        pS.setLevelUpFee(tokenId_, fee_);
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
            if (vS.getPilotId(pilotTokenId_) != pilotTokenId_) {
                return;
            }
            address addr_ = vS.ownerOf(voyagerTokenId);
            tS.claimDGT(pilotTokenId_, addr_);
            tS.claimDSP(pilotTokenId_, addr_);
        }
    }
}
