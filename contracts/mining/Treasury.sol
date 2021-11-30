// SPDX-License-Identifier: MIT
import "../utils/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../voyager/VoyagerStorage.sol";
import "hardhat/console.sol";

pragma solidity ^0.8.0;

contract Treasury is AccessControl{
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    // 合约owner
    address private devaddr;
    // 收取挖矿费率的财务部门地址
    address private treasury;
    // DGT合约交互地址
    IERC20 private DGT;
    // NFT合约交互地址
    VoyagerStorage private NFT;
    // todo：奖励截止时间：使用blocktime
    uint256 private bonusEndBlock;
    // todo：每个block分发的DGT数量
    // polygon上Staking挖矿和流动性挖矿的总量: 
    // 首月 - staking(25wDGT) + 流动性挖矿(25wDGT): 0.4 DGT/perblock
    uint256 private DGTPerBlock;

    // staking收益Level分层
    // todo: 数值设定从整数开始
    mapping (uint256 => uint256) public weightOfLevel;
    mapping (address => uint256) public stakeShareOf;
    mapping (address => uint256) public stakeTokenId;
    uint256 public totalStakeShare;

    // INFO | USER VARIABLES
    struct UserInfo {
        uint256 amount;     // How many tokens the user has provided.
        uint256 rewardDebt; // Reward debt. See explanation below.
        // uint256 maxLevel;
        uint256 share;      // set for staking mining
        //
        // The pending DGT entitled to a user is referred to as the pending reward:
        //   每次有份额加入或退出时，对收益进行结算
        //   pending reward = (user.amount * pool.accDGTPerShare) - user.rewardDebt ( - user.taxedAmount)
        //
        // Upon deposit and withdraw, the following occur:
        //   1. The pool's `accDGTPerShare` (and `lastRewardBlock`) gets updated.
        //   2. User receives the pending reward sent to his/her address.
        //   3. User's `amount` gets updated and taxed as 'taxedAmount'.
        //   4. User's `rewardDebt` gets updated.
    }

    // INFO | POOL VARIABLES
    struct PoolInfo {
        IERC20 token;             // Address of token contract.
        uint256 allocPoint;       // How many allocation points assigned to this pool. DGTs to distribute per block.
        uint256 taxRate;          // Rate at which the LP token is taxed.
        uint256 lastRewardBlock;  // Last block number that DGTs distribution occurs.
        uint256 accDGTPerShare;   // Accumulated DGTs per share, times 1e12. See below.
    }

    PoolInfo[] private poolInfo;
    mapping (uint256 => mapping (address => UserInfo)) private userInfo;
    uint256 private totalAllocPoint = 0;
    uint256 private startBlock;

    constructor(
        address _DGT, 
        address NFT_,
        uint256 _DGTPerBlock, 
        uint256 _startBlock, 
        uint256 _bonusEndBlock
    ) {
        DGT = IERC20(_DGT);
        NFT = VoyagerStorage(NFT_);
        // treasury = _treasury;
        devaddr = msg.sender;
        DGTPerBlock = _DGTPerBlock;
        startBlock = _startBlock;
        bonusEndBlock = _bonusEndBlock;
        console.log("treasury deploy success");
    }

    function initializeWeightOfLevel(uint _maxLevel) public onlyOwner {
        for (uint level=0; level < _maxLevel+1; level++) {
            weightOfLevel[level] = 1;
        }
    }

    function setWeightOfLevel(uint level, uint weight) public onlyOwner {
        weightOfLevel[level] = weight;
    }

    function getDevaddr() external view returns (address) {
        return devaddr;
    }

    function setDevaddr(address _addr) public onlyProxy notZeroAddress(_addr) {
        devaddr = _addr;
    }

    function setStakeTokenId(address _user, uint _tokenId) public onlyProxy {
        stakeTokenId[_user] = _tokenId;
    }

    function getDGT() external view returns (IERC20) {
        return DGT;
    }
    
    function getStartBlock() external view returns (uint) {
        return startBlock;
    }

    function getSingleAllocPoint(uint _pid) external view returns (uint) {
        return poolInfo[_pid].allocPoint;
    }

    function getTotalAllocPoint() external view returns (uint) {
        return totalAllocPoint;
    }

    function getPoolInfo() external view returns (PoolInfo[] memory) {
        return poolInfo;
    }

    function getPool(uint _pid) public view returns (PoolInfo memory) {
        return poolInfo[_pid];
    }

    function getDGTPerBlock() external view returns (uint) {
        return DGTPerBlock;
    }

    function setDGTPerBlock(uint _DGTPerBlock) external onlyProxy {
        DGTPerBlock = _DGTPerBlock;
    }

    function getAccDGTPerShare(uint _pid) external view returns (uint) {
        return getPool(_pid).accDGTPerShare;
    }

    function getUserInfo(uint _pid, address _user) public view returns (UserInfo memory) {
        return userInfo[_pid][_user];
    }

    // function getUserMaxLevel(uint _pid, address _user) public view returns (uint) {
    //     return userInfo[_pid][_user].maxLevel;
    // }

    function setTotalStakeShare(uint _value) public onlyProxy {
        totalStakeShare = _value;
    } 

    function setStakeShareOfUser(address _user, uint _share) public onlyProxy {
        stakeShareOf[_user] = _share;
    }

    function setUserAmount(uint _pid, address _user, uint _amount) public onlyProxy {
        userInfo[_pid][_user].amount = _amount;
    }

    function setUserShare(uint _pid, address _user, uint _amount) public onlyProxy {
        userInfo[_pid][_user].share = _amount;
    }

    function setUserRewardDebt(uint _pid, address _user, uint _amount) public onlyProxy {
        userInfo[_pid][_user].rewardDebt = _amount;
    }

    function getUserReward(uint _pid, address _addr) public view returns (uint pending) {
        if (_pid==0) {
            pending = getUserInfo(_pid, _addr).share.mul(getPool(_pid).accDGTPerShare).div(1e12)
                            .sub(getUserInfo(_pid, _addr).rewardDebt);
        } else {
            pending = getUserInfo(_pid, _addr).amount.mul(getPool(_pid).accDGTPerShare).div(1e12)
                            .sub(getUserInfo(_pid, _addr).rewardDebt);
        }
    }

    // function setUserMaxLevel(uint _pid, address _user, uint _maxLevel) public onlyProxy {
    //     userInfo[_pid][_user].maxLevel = _maxLevel;
    // }

    function setAccDGTPerShare(uint _pid, uint _accDGTPerShare)  public onlyProxy {
        poolInfo[_pid].accDGTPerShare = _accDGTPerShare;
    }

    function getLastRewardBlock(uint _pid) external view returns (uint) {
        return getPool(_pid).lastRewardBlock;
    }

    function setLastRewardBlock(uint _pid, uint _lastRewardBlock) public onlyProxy {
        poolInfo[_pid].lastRewardBlock = _lastRewardBlock;
    }

    function getPoolToken(uint _pid) external view returns (IERC20) {
        return getPool(_pid).token;
    }

    function setTotalAllocPoint(uint _value) public onlyProxy {
        totalAllocPoint = _value;
    }

    function setSingleAllocPoint(uint _pid, uint _value) public onlyProxy {
        poolInfo[_pid].allocPoint = _value;
    }

    function addPool(PoolInfo memory _pool) public onlyProxy {
        poolInfo.push(_pool);
    }

    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    function transferDGT(address _to, uint _value) public onlyProxy {
        DGT.transfer(_to, _value);
    }

    function transferNFT(address to_, uint tokenId_) public onlyProxy {
        NFT.transferVoyager(to_, tokenId_);
    }

    function withdrawNFT(address to_, uint tokenId_) public onlyOwner {
        NFT.transferVoyager(to_, tokenId_);
    }

    function withdrawDGT(uint value_) public onlyOwner {
        if ( DGT.balanceOf(address(this)) < value_) {
            value_ = DGT.balanceOf(address(this));
        }

        DGT.transfer(msg.sender, value_);
    }

    // VALIDATION | ELIMINATES POOL DUPLICATION RISK
    function checkPoolDuplicate(IERC20 _token) public view {
        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            require(poolInfo[pid].token != _token, "add: existing pool?");
        }
    }

    // RETURN | REWARD MULTIPLIER OVER GIVEN BLOCK RANGE | INCLUDES START BLOCK
    function getMultiplier(uint256 _from, uint256 _to) public view returns (uint256) {
        _from = _from >= startBlock ? _from : startBlock;
        if (_to <= bonusEndBlock) {
            return _to.sub(_from);
        } else if (_from >= bonusEndBlock) {
            return _to.sub(_from);
        } else {
            return bonusEndBlock.sub(_from).add(
                _to.sub(bonusEndBlock)
            );
        }
    }

    // VIEW | PENDING REWARD，返回用户当前的未提取收益
    function pendingDGT(uint256 _pid, address _user) external view returns (uint256) {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 accDGTPerShare = pool.accDGTPerShare;
        uint256 lpSupply = pool.token.balanceOf(address(this));
        if (block.number > pool.lastRewardBlock && lpSupply != 0) {
            uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number);
            uint256 DGTReward = multiplier.mul(DGTPerBlock).mul(pool.allocPoint).div(totalAllocPoint);
            accDGTPerShare = accDGTPerShare.add(DGTReward.mul(1e12).div(lpSupply));
        }
        return user.amount.mul(accDGTPerShare).div(1e12).sub(user.rewardDebt);
    }
}
