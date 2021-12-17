// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../utils/AccessControl.sol";
import "../voyager/VoyagerStorage.sol";
import "./Treasury.sol";
import "hardhat/console.sol";

// Note that it's ownable and the owner wields tremendous power. The ownership
// will be transferred to a governance smart contract once DGT is sufficiently
// distributed and the community can show to govern itself.
contract LiquidityMining is AccessControl {
    using SafeMath for uint;
    using SafeERC20 for IERC20;

    VoyagerStorage internal vs;
    Treasury internal ts;

    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 indexed pid, uint256 amount);

    constructor(
        address _treasury,
        address _voyagerStorage
    )
    {
        require(_treasury != address(0) , "Invalid Address");
        require(_voyagerStorage != address(0) , "Invalid Address");
        ts = Treasury(_treasury);
        vs = VoyagerStorage(_voyagerStorage);
    }

    function setDGTPerBlock(uint _DGTPerBlock) external {
        ts.setDGTPerBlock(_DGTPerBlock);
    }

    function getMaxLevel(address _user) public view returns (uint) {
        uint tokenId = ts.stakeTokenId(_user);

        if (tokenId == 0) {
            return 0;
        }

        return vs.getLevel(tokenId);
    }

    function updateShare() internal {
        uint maxLevel = getMaxLevel(msg.sender);
        uint lastUserShare = ts.getUserInfo(0, msg.sender).share;
        uint curUserShare = ts.getUserInfo(0, msg.sender).amount * ts.weightOfLevel(maxLevel);
        uint lastTotalStakeShare = ts.totalStakeShare();
        ts.setTotalStakeShare(lastTotalStakeShare.sub(lastUserShare).add(curUserShare));
        ts.setUserShare(0, msg.sender, curUserShare);   
    }

    function stakeNFT(uint tokenId) external {
        require(ts.stakeTokenId(msg.sender) == 0 ,"NFT Already staked");

        ts.setStakeTokenId(msg.sender, tokenId);
        vs.transferFrom(msg.sender, address(ts), tokenId);

        updateStakingPool();
        
        if(ts.getUserInfo(0, msg.sender).amount > 0) {
            uint256 pending = ts.getUserInfo(0, msg.sender).share.mul(ts.getAccDGTPerShare(0)).div(1e12)
                                .sub(ts.getUserInfo(0, msg.sender).rewardDebt);

            if(pending > 0) {
                safeDGTTransfer(msg.sender, pending);
            }
        }

        updateShare();

        uint _rewardDebt = ts.getUserInfo(0, msg.sender).share.mul(ts.getPool(0).accDGTPerShare).div(1e12);
        ts.setUserRewardDebt(0, msg.sender, _rewardDebt);          
    }

    function unstakeNFT() external {
        require(ts.stakeTokenId(msg.sender) > 0 ,"No NFT staked");

        uint tokenId = ts.stakeTokenId(msg.sender);

        ts.transferNFT(msg.sender, tokenId);
        ts.setStakeTokenId(msg.sender, 0);

        updateStakingPool();
        
        uint256 pending = ts.getUserInfo(0, msg.sender).share.mul(ts.getPool(0).accDGTPerShare).div(1e12)
                            .sub(ts.getUserInfo(0, msg.sender).rewardDebt);

        if (pending > 0) {
            safeDGTTransfer(msg.sender, pending);
        }

        updateShare();

        uint _rewardDebt = ts.getUserInfo(0, msg.sender).share.mul(ts.getPool(0).accDGTPerShare).div(1e12);
        ts.setUserRewardDebt(0, msg.sender, _rewardDebt);
    }

    function add(uint256 _allocPoint, IERC20 _token, uint256 _taxRate, bool _withUpdate) public 
        onlyOwner {
        if (_withUpdate) {
            massUpdatePools();
        }
        uint256 lastRewardBlock = block.number > ts.getStartBlock() ? block.number : ts.getStartBlock();
        ts.setTotalAllocPoint(ts.getTotalAllocPoint().add(_allocPoint)); 
        ts.addPool(Treasury.PoolInfo({
            token: _token,
            allocPoint: _allocPoint,
            taxRate: _taxRate,
            lastRewardBlock: lastRewardBlock,
            accDGTPerShare: 0
        }));
    }

    function set(uint256 _pid, uint256 _allocPoint, bool _withUpdate) public onlyOwner {
        if (_withUpdate) {
            massUpdatePools();
        }
        uint _totalAllocPoint = ts.getTotalAllocPoint().sub(ts.getPool(_pid).allocPoint).add(_allocPoint);
        ts.setTotalAllocPoint(_totalAllocPoint);
        ts.setSingleAllocPoint(_pid, _allocPoint);
    }

    function massUpdatePools() public {
        uint256 length = ts.getPoolInfo().length;
        for (uint256 pid = 0; pid < length; ++pid) {
            updatePool(pid);
        }
    }

    function updatePool(uint256 _pid) public {
        if (block.number <= ts.getLastRewardBlock(_pid)) { 
            return;
        }
        uint256 lpSupply = ts.getPoolToken(_pid).balanceOf(address(this));
        if (lpSupply == 0) {
            ts.setLastRewardBlock(_pid, block.number); 
            return;
        }

        uint256 multiplier = ts.getMultiplier(ts.getLastRewardBlock(_pid), block.number);
        uint256 DGTReward = multiplier.mul(ts.getDGTPerBlock())
                                      .mul(ts.getSingleAllocPoint(_pid))
                                      .div(ts.getTotalAllocPoint());
        uint _accDGTPerShare = ts.getAccDGTPerShare(_pid).add(DGTReward.mul(1e12).div(lpSupply)); 

        ts.setAccDGTPerShare(_pid, _accDGTPerShare);
        ts.setLastRewardBlock(_pid, block.number); 
    }

    function updateStakingPool() public {
        if (block.number <= ts.getLastRewardBlock(0)) { 
            return;
        }

        uint256 totalStakeShare = ts.totalStakeShare();
        if (totalStakeShare == 0) {
            ts.setLastRewardBlock(0, block.number); 
            return;
        }  

        uint256 multiplier = ts.getMultiplier(ts.getLastRewardBlock(0), block.number);
        uint256 DGTReward = multiplier.mul(ts.getDGTPerBlock()).mul(ts.getSingleAllocPoint(0))
                                      .div(ts.getTotalAllocPoint());

        uint _accDGTPerShare = ts.getAccDGTPerShare(0).add(DGTReward.mul(1e12)
                                 .div(totalStakeShare));

        ts.setAccDGTPerShare(0, _accDGTPerShare);
        ts.setLastRewardBlock(0, block.number); 
    }

    // VALIDATE | AUTHENTICATE _PID
    modifier validatePool(uint256 _pid) {
        require(_pid < ts.getPoolInfo().length, "gov: pool exists?");
        _;
    }

    // WITHDRAW | ASSETS (TOKENS) WITH NO REWARDS | EMERGENCY ONLY
    function emergencyWithdraw(uint256 _pid) public nonReentrant {
        ts.setUserAmount(_pid, msg.sender, 0);
        ts.setUserRewardDebt(_pid, msg.sender, 0);

        ts.getPoolToken(_pid).safeTransfer(address(msg.sender), ts.getUserInfo(_pid, msg.sender).amount);

        emit EmergencyWithdraw(msg.sender, _pid, ts.getUserInfo(_pid, msg.sender).amount);        
    }

    // DEPOSIT | ASSETS (TOKENS)
    function deposit(uint256 _pid, uint256 _amount) public nonReentrant {
        require(_pid > 0, "Only for liquidity mining");
        updatePool(_pid);

        if (ts.getUserInfo(_pid, msg.sender).amount > 0) { 
            uint256 pending = ts.getUserInfo(_pid, msg.sender).amount.mul(ts.getAccDGTPerShare(_pid)).div(1e12)
                                .sub(ts.getUserInfo(_pid, msg.sender).rewardDebt);
            if(pending > 0) { 
                safeDGTTransfer(msg.sender, pending);
            }
        }
        
        if(_amount > 0) { 
            ts.getPool(_pid).token.safeTransferFrom(address(msg.sender), address(this), _amount);
            uint userAmount = ts.getUserInfo(_pid, msg.sender).amount.add(_amount); 
            ts.setUserAmount(_pid, msg.sender, userAmount);
        }

        uint _rewardDebt = ts.getUserInfo(_pid, msg.sender).amount
                             .mul(ts.getPool(_pid).accDGTPerShare)
                             .div(1e12);
        ts.setUserRewardDebt(_pid, msg.sender, _rewardDebt);
        emit Deposit(msg.sender, _pid, _amount);
    }

    function depositStaking(uint _amount) public nonReentrant {
        updateStakingPool();

        if(ts.getUserInfo(0, msg.sender).amount > 0) {
            uint256 pending = ts.getUserInfo(0, msg.sender).share.mul(ts.getAccDGTPerShare(0)).div(1e12)
                                .sub(ts.getUserInfo(0, msg.sender).rewardDebt);

            if(pending > 0) {
                safeDGTTransfer(msg.sender, pending);
            }
        }

        if(_amount > 0) {
            ts.getPool(0).token.safeTransferFrom(address(msg.sender), address(this), _amount);

            uint userAmount = ts.getUserInfo(0, msg.sender).amount.add(_amount);
            ts.setUserAmount(0, msg.sender, userAmount);

            updateShare();
        }

        uint _rewardDebt = ts.getUserInfo(0, msg.sender).share.mul(ts.getPool(0).accDGTPerShare).div(1e12);
        ts.setUserRewardDebt(0, msg.sender, _rewardDebt);
        emit Deposit(msg.sender, 0, _amount);
    }

    // WITHDRAW | ASSETS (TOKENS)
    function withdraw(uint256 _pid, uint256 _amount) public nonReentrant {
        require(ts.getUserInfo(_pid, msg.sender).amount >= _amount, "withdraw: not good");
        updatePool(_pid);
        uint256 pending = ts.getUserInfo(_pid, msg.sender).amount.mul(ts.getPool(_pid).accDGTPerShare)
                            .div(1e12).sub(ts.getUserInfo(_pid, msg.sender).rewardDebt);

        if (pending > 0) { 
            safeDGTTransfer(msg.sender, pending);
        }
        
        if (_amount > 0) {
            ts.setUserAmount(_pid, msg.sender, ts.getUserInfo(_pid, msg.sender).amount.sub(_amount));
            ts.getPool(_pid).token.safeTransfer(address(msg.sender), _amount);
        }
        
        uint _rewardDebt = ts.getUserInfo(_pid, msg.sender).amount.mul(ts.getPool(_pid).accDGTPerShare).div(1e12);
        ts.setUserRewardDebt(_pid, msg.sender, _rewardDebt);
        emit Withdraw(msg.sender, _pid, _amount);
    }

    function withdrawStaking(
        uint256 _amount
    ) public nonReentrant 
    {
        require(ts.getUserInfo(0, msg.sender).amount >= _amount, "withdraw: not good");

        updateStakingPool();
        uint256 pending = ts.getUserInfo(0, msg.sender).share.mul(ts.getPool(0).accDGTPerShare).div(1e12)
                            .sub(ts.getUserInfo(0, msg.sender).rewardDebt);

        if (pending > 0) {
            safeDGTTransfer(msg.sender, pending);
        }

        if (_amount > 0) {
            ts.setUserAmount(0, msg.sender, ts.getUserInfo(0, msg.sender).amount.sub(_amount));
            ts.getPool(0).token.safeTransfer(address(msg.sender), _amount);

            updateShare();
        }

        uint _rewardDebt = ts.getUserInfo(0, msg.sender).share.mul(ts.getPool(0).accDGTPerShare).div(1e12);
        ts.setUserRewardDebt(0, msg.sender, _rewardDebt);
        emit Withdraw(msg.sender, 0, _amount);
    }

    // SAFE TRANSFER FUNCTION | ACCOUNTS FOR ROUNDING ERRORS | ENSURES SUFFICIENT DGT IN POOLS.
    function safeDGTTransfer(address _to, uint256 _amount) internal {
        uint256 DGTBal = ts.getDGT().balanceOf(address(ts));
        if (_amount > DGTBal) {
            ts.transferDGT(_to, DGTBal);
        } else {
            ts.transferDGT(_to, _amount);
        }
    }
}
