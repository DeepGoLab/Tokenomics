// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../utils/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./VoyagerStorage.sol";
import "./PilotStorage.sol";
import "./PilotWhale.sol";

contract TreasuryStorage is AccessControl{
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    PilotStorage public pS;
    VoyagerStorage public vS;

    struct Account {
        // 余额
        uint256 balance;
        // 已解锁金额,不可退；其余可退
        uint256 unlocked;
        // 起始时间
        uint256 startTime;
        // 下次结算时间
        uint256 nextPayTime; // next - start < 30 days. 则next + 27 days, 其余next + 30 days
        // 到期时间
        uint256 expiredTime;
        // 已收取DSP金额
        uint256 claimed;
    }
    // pilot Id -> voyager address -> Account
    mapping(uint256 => mapping(address => Account)) public accountOfVoyagerOfPilot;
    mapping(uint256 => mapping(address => bool)) public isDGTClaimed;

    constructor(
        address pilotStorage_,
        address voyagerStorage_
    ) notZeroAddress(pilotStorage_) notZeroAddress(voyagerStorage_) {
        pS = PilotStorage(pilotStorage_);
        vS = VoyagerStorage(voyagerStorage_);
    }

    function reedemVoyager(
        uint256 pilotTokenId_
    ) external onlyProxy returns (bool isRepayDGT, uint256 dgtAmount) {
        // 该地址持有
        require(vS.voyagerOfAddressOfPilot(pilotTokenId_, msg.sender) > 0,
                "No Voyager Token Hold");
        // 退款
        updateAccount(pilotTokenId_, msg.sender);
        repayDGT(pilotTokenId_, msg.sender);
        repayDSP(pilotTokenId_, msg.sender);

        isRepayDGT = checkRepayDGT(pilotTokenId_, msg.sender);
        dgtAmount = vS.baseMintFee() / 10;
    }

    function reedemVoyagerByLeader(
        uint256 pilotTokenId_,
        address addr_
    ) external onlyProxy returns (bool isRepayDGT, uint256 dgtAmount) {
        // msg.sender是圈主
        address leader = pS.getPilotByTokenId(pilotTokenId_).leader;
        require(leader == msg.sender, "Not Leader");

        // 该地址持有VoyagerNFT
        require(vS.voyagerOfAddressOfPilot(pilotTokenId_, addr_) > 0,
                "No Voyager Token Hold");
        // 退款
        updateAccount(pilotTokenId_, msg.sender);
        repayDGT(pilotTokenId_, msg.sender);
        repayDSP(pilotTokenId_, msg.sender);

        isRepayDGT = checkRepayDGT(pilotTokenId_, msg.sender);
        dgtAmount = vS.baseMintFee() / 10;
    }
    
    function getRepayDGT() public view returns(uint256) {
        return vS.baseMintFee();
    }

    function getRepayDSP(
        uint256 pilotTokenId_, 
        address addr_
    ) public view returns(uint256) {
        Account memory account = accountOfVoyagerOfPilot[pilotTokenId_][addr_];
        return account.balance.sub(account.unlocked);
    }

    // function getUnclaimedDGT(

    // ) {

    // }

    // function getUnclaimedDSP() {}

    function checkRepayDGT(
        uint256 pilotTokenId_, 
        address addr_
    ) public view returns(bool isRepay)
    {
        Account memory account = accountOfVoyagerOfPilot[pilotTokenId_][addr_];

        if (account.unlocked == 0) {
            isRepay = true;
        }
    }

    function repayDGT(
        uint256 pilotTokenId_, 
        address addr_
    ) internal {
        bool isRepayDGT = checkRepayDGT(pilotTokenId_, addr_);
        uint256 mintDGTFee = vS.baseMintFee();
        uint256 toLeader = mintDGTFee / 10;

        if (isRepayDGT) {
            require(IERC20(pS.dgtAddress()).balanceOf(address(this)) >= toLeader, 
                                    "Unsufficient dgt token");
            IERC20(pS.dgtAddress()).safeTransferFrom(address(this), addr_, toLeader);
        } 

        _claimDGT(pilotTokenId_, addr_);
    }

    function repayDSP(
        uint256 pilotTokenId_, 
        address addr_
    ) internal {
        uint256 repayAmount = getRepayDSP(pilotTokenId_, addr_);
        // 回款
        IERC20(pS.dspAddress()).safeTransferFrom(address(this), addr_, repayAmount); 
        
        _claimDSP(pilotTokenId_, addr_);

        // 销毁账户
        delete accountOfVoyagerOfPilot[pilotTokenId_][addr_];
    }

    function getClaimDSP(
        uint256 pilotTokenId_, 
        address addr_
    ) public view returns(uint256) {
        Account memory account = accountOfVoyagerOfPilot[pilotTokenId_][addr_];
        return account.unlocked - account.claimed;
    }

    // claim单个账户，claim所有账户
    function claimDSP(
        uint256 pilotTokenId_, 
        address addr_
    ) external onlyProxy {
        _claimDSP(pilotTokenId_, addr_);
    }

    function _claimDSP(
        uint256 pilotTokenId_, 
        address addr_
    ) internal {
        uint256 claimAmount = getClaimDSP(pilotTokenId_, addr_);
        address leader = pS.getLeader(pilotTokenId_);
        address nftOwner = pS.ownerOf(pilotTokenId_);
        uint256 chargeShare = pS.getChargeShare(pilotTokenId_);
        // 回款
        IERC20(pS.dspAddress()).safeTransferFrom(address(this), nftOwner, 
                                                 claimAmount * chargeShare / 10000);
        IERC20(pS.dspAddress()).safeTransferFrom(address(this), leader, 
                                   claimAmount - claimAmount * chargeShare / 10000); 
        // 销毁账户
        accountOfVoyagerOfPilot[pilotTokenId_][addr_].claimed += claimAmount;
    }

    function claimDGT(
        uint256 pilotTokenId_, 
        address addr_
    ) external onlyProxy {
        _claimDGT(pilotTokenId_, addr_);
    }

    function _claimDGT(
        uint256 pilotTokenId_, 
        address addr_
    ) internal {
        bool isRepayDGT = checkRepayDGT(pilotTokenId_, addr_);
        if(!isRepayDGT || isDGTClaimed[pilotTokenId_][addr_]) {
            return;
        }
        uint256 mintDGTFee = vS.baseMintFee();
        uint256 toLeader = mintDGTFee / 10;
        address nftOwner = pS.ownerOf(pilotTokenId_);
        uint256 chargeShare = pS.getChargeShare(pilotTokenId_);

        require(IERC20(pS.dgtAddress()).balanceOf(address(this)) >= toLeader, 
                        "Unsufficient dgt token");
        IERC20(pS.dgtAddress()).safeTransferFrom(address(this), nftOwner, 
                                                 toLeader * chargeShare / 10000);
        IERC20(pS.dgtAddress()).safeTransferFrom(address(this),
                                                 pS.getLeader(pilotTokenId_),
                                      toLeader - toLeader * chargeShare / 10000);
        isDGTClaimed[pilotTokenId_][addr_] = true;
    }

    function updateAccount(
        uint256 pilotTokenId_, 
        address addr_
    ) public {
        Account memory account = accountOfVoyagerOfPilot[pilotTokenId_][addr_];
        if (block.timestamp - account.startTime < 3 days ||
            account.nextPayTime > block.timestamp) {
            return;
        }

        uint256 nextPayTime;
        uint256 month;
        uint256 unlocked;
        uint256 allMonth = (account.expiredTime - account.startTime) / 30 days;

        if (account.nextPayTime - account.startTime < 30 days) {
            nextPayTime = account.nextPayTime + 27 days;
            month = 1;
        } else {
            nextPayTime = account.nextPayTime + 30 days;
            month = (block.timestamp - account.startTime) / 30 days + 1; 
        }
        
        unlocked = month * account.balance / allMonth;

        if (unlocked > account.unlocked) {
            accountOfVoyagerOfPilot[pilotTokenId_][addr_].unlocked = unlocked;
        } 

        if (account.nextPayTime < account.expiredTime) {
            accountOfVoyagerOfPilot[pilotTokenId_][addr_].nextPayTime = nextPayTime;
        }

        // if (account.claimed < unlocked) {
        //     require(IERC20(pS.dspAddress()).balanceOf(address(this)) >= unlocked - account.claimed, 
        //                                     "Unsufficient dsp token");
        //     // 转账给会长
        //     address leader = pS.getPilotByTokenId(pilotTokenId_).leader;
        //     IERC20(pS.dspAddress()).safeTransferFrom(address(this), leader, unlocked - account.claimed);
        //     accountOfVoyagerOfPilot[pilotTokenId_][addr_].claimed = unlocked;
        // }
    }

    function setAccountBalance(
        uint256 pilotTokenId_, 
        address addr_, 
        uint256 balance_
    ) external onlyProxy {
        accountOfVoyagerOfPilot[pilotTokenId_][addr_].balance = balance_;
    }

    function setAccountUnlock(
        uint256 pilotTokenId_, 
        address addr_, 
        uint256 unlocked_
    ) external onlyProxy {
        accountOfVoyagerOfPilot[pilotTokenId_][addr_].unlocked = unlocked_;
    }

    function setAccountStartTime(
        uint256 pilotTokenId_, 
        address addr_, 
        uint256 startTime_       
    ) external onlyProxy {
        accountOfVoyagerOfPilot[pilotTokenId_][addr_].startTime = startTime_;
    }

    function setAccountNextPayTime(
        uint256 pilotTokenId_, 
        address addr_, 
        uint256 nextPayTime_       
    ) external onlyProxy {
        accountOfVoyagerOfPilot[pilotTokenId_][addr_].nextPayTime = nextPayTime_;
    }    

    function setAccountExpiredTime(
        uint256 pilotTokenId_, 
        address addr_, 
        uint256 expiredTime_       
    ) external onlyProxy {
        accountOfVoyagerOfPilot[pilotTokenId_][addr_].expiredTime = expiredTime_;
    }    

    function setAccountClaimed(
        uint256 pilotTokenId_, 
        address addr_, 
        uint256 claimed_       
    ) external onlyProxy {
        accountOfVoyagerOfPilot[pilotTokenId_][addr_].claimed = claimed_;
    }    

    function setAccountUnlocked(
        uint256 pilotTokenId_, 
        address addr_, 
        uint256 unlocked_       
    ) external onlyProxy {
        accountOfVoyagerOfPilot[pilotTokenId_][addr_].unlocked = unlocked_;
    }    

    function getAcount(uint256 pilotTokenId_, address addr_) public view returns(Account memory) {
        return accountOfVoyagerOfPilot[pilotTokenId_][addr_];
    }
}
