// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import "./libs/IBEP20.sol";
import "./libs/SafeBEP20.sol";
import "./libs/ICrssReferral.sol";
import "./libs/Ownable.sol";
import './libs/AddrArrayLib.sol';
import './libs/BasicMetaTransaction.sol';
import "./interface/IStrategy.sol";
import "./interface/ICrosswisePair.sol";
import "./interface/ICrosswiseRouter02.sol";

import "./CrssToken.sol";
import "./xCrssToken.sol";

// MasterChef is the master of Crss. He can make Crss and he is a fair guy.
//
// Note that it's ownable and the owner wields tremendous power. The ownership
// will be transferred to a governance smart contract once CRSS is sufficiently
// distributed and the community can show to govern itself.
//
// Have fun reading it. Hopefully it's bug-free. God bless.
contract MasterChef is Ownable, ReentrancyGuard, BasicMetaTransaction {
    using SafeMath for uint256;
    using SafeBEP20 for IBEP20;
    using AddrArrayLib for AddrArrayLib.Addresses;

    // Info of each user.
    struct UserInfo {
        uint256 amount;         // How many LP tokens the user has provided.
        uint256 rewardDebt;     // Reward debt. See explanation below.
        uint256 crssRewardLockedUp;
        bool isVest;
        bool isAuto;
        //
        // We do some fancy math here. Basically, any point in time, the amount of CRSSs
        // entitled to a user but is pending to be distributed is:
        //
        //   pending reward = (user.amount * pool.accCrssPerShare) - user.rewardDebt
        //
        // Whenever a user deposits or withdraws LP tokens to a pool. Here's what happens:
        //   1. The pool's `accCrssPerShare` (and `lastRewardBlock`) gets updated.
        //   2. User receives the pending reward sent to his/her address.
        //   3. User's `amount` gets updated.
        //   4. User's `rewardDebt` gets updated.
    }

    // Info of each pool.
    struct PoolInfo {
        IBEP20 lpToken;           // Address of LP token contract.
        uint256 allocPoint;       // How many allocation points assigned to this pool. CRSSs to distribute per block.
        uint256 lastRewardBlock;  // Last block number that CRSSs distribution occurs.
        uint256 accCrssPerShare;   // Accumulated CRSSs per share, times 1e12. See below.
        uint256 depositFeeBP;      // Deposit fee in basis points
        address strategy;       // Strategy address
    }

    // The CRSS TOKEN!
    CrssToken public crss;
    // The XCRSS TOKEN!
    xCrssToken public xCrss;
    // Crss router addressList
    ICrosswiseRouter02 public crssRouterAddress;
    // Dev address.
    address public devAddress;
    // Deposit Fee address
    address public treasuryAddress;
    // Burn address
    address public constant burnAddress = 0x000000000000000000000000000000000000dEaD;
    // CRSS tokens created per block.
    uint256 public crssPerBlock;
    // Bonus muliplier for early crss makers.
    uint256 public constant BONUS_MULTIPLIER = 1;
    // Max harvest interval: 14 days.
    uint256 public constant MAXIMUM_HARVEST_INTERVAL = 14 days;

    uint256 public constant stakePoolId = 0;

    // Set on global level, could be passed to functions via arguments
    uint256 public constant routerDeadlineDuration = 300; 

    // Info of each pool.
    PoolInfo[] public poolInfo;
    // Info of each user that stakes LP tokens.
    mapping(uint256 => mapping(address => UserInfo)) public userInfo;
    mapping(uint256 => AddrArrayLib.Addresses) private autoAddressByPid;

    mapping(uint256 => uint256) public totalShares;
    
    // Total allocation points. Must be the sum of all allocation points in all pools.
    uint256 public totalAllocPoint = 0;
    // The block number when CRSS mining starts.
    uint256 public startBlock;

    // Crss referral contract address.
    ICrssReferral public crssReferral;
    // Referral commission rate in basis points.
    uint256 public referralCommissionRate = 100;
    // Max referral commission rate: 10%.
    uint256 public constant MAXIMUM_REFERRAL_COMMISSION_RATE = 1000;

    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event EmissionRateUpdated(address indexed caller, uint256 previousAmount, uint256 newAmount);
    event ReferralCommissionPaid(address indexed user, address indexed referrer, uint256 commissionAmount);
    event CrssPerBlockUpdated(uint256 crssPerBlock);

    constructor(
        CrssToken _crss,
        xCrssToken _xCrss,
        ICrosswiseRouter02 _crssRouterAddress,
        address _devAddress,
        address _treasuryAddress,
        uint256 _startBlock
    ) public {
        require(address(_crss) != address(0), "constructor: crss token address is zero address");
        require(address(_xCrss) != address(0), "constructor: xcrss token address is zero address");
        require(address(_crssRouterAddress) != address(0), "constructor: crss router address is zero address");
        require(_devAddress != address(0), "constructor: dev address is zero address");
        require(_treasuryAddress != address(0), "constructor: treasury address is zero address");
        

        crss = _crss;
        xCrss = _xCrss;
        crssRouterAddress = _crssRouterAddress;
        startBlock = _startBlock;
        crssPerBlock = 1.2 * 10 ** 18;

        devAddress = _devAddress;
        treasuryAddress = _treasuryAddress;
    }

    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    function getUserDepositBalanceByPid(uint256 _pid, address _user) internal view returns (uint256) {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        if(pool.strategy == address(0) && user.isAuto) {
            uint256 lpSupply = pool.lpToken.balanceOf(address(this));
            return user.amount.mul(lpSupply).div(totalShares[_pid]);
        }
        else {
            return user.amount;
        }
    }

     function stakedTokens(uint256 _pid, address _user) external view returns (uint256) {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];

        if(pool.strategy != address(0)) {
            uint256 sharesTotal = IStrategy(pool.strategy).sharesTotal();
            uint256 LockedTotal = IStrategy(pool.strategy).wantLockedTotal();
            if (sharesTotal == 0) {
                return 0;
            }
            return user.amount.mul(LockedTotal).div(sharesTotal);
        }
        else if(user.isAuto) {
            uint256 lpSupply = pool.lpToken.balanceOf(address(this));
            return user.amount.mul(lpSupply).div(totalShares[_pid]);
        }
        else {
            return user.amount;
        }
    }
    
    // update crss reward count per block
    function updateCrssPerBlock(uint256 _crssPerBlock) public onlyOwner {
        require(_crssPerBlock != 0, "Reward token count per block can't be zero");
        crssPerBlock = _crssPerBlock * 10 ** 18;
        // emitts event when crssPerBlock updated
        emit CrssPerBlockUpdated(_crssPerBlock * 10 ** 18);
    }

    // Add a new lp to the pool. Can only be called by the owner.
    // XXX DO NOT add the same LP token more than once. Rewards will be messed up if you do.
    function add(uint256 _allocPoint, IBEP20 _lpToken, uint256 _depositFeeBP, address _strategy, bool _withUpdate) public onlyOwner {
        require(_depositFeeBP <= 10000, "add: invalid deposit fee basis points");
        if (_withUpdate) {
            massUpdatePools();
        }
        uint256 lastRewardBlock = block.number > startBlock ? block.number : startBlock;
        totalAllocPoint = totalAllocPoint.add(_allocPoint);
        poolInfo.push(PoolInfo({
            lpToken: _lpToken,
            allocPoint: _allocPoint,
            lastRewardBlock: lastRewardBlock,
            accCrssPerShare: 0,
            depositFeeBP: _depositFeeBP,
            strategy: _strategy
        }));
    }

    // Update the given pool's CRSS allocation point and deposit fee. Can only be called by the owner.
    function set(uint256 _pid, uint256 _allocPoint, uint256 _depositFeeBP, address _strategy, bool _withUpdate) public onlyOwner {
        require(_depositFeeBP <= 10000, "set: invalid deposit fee basis points");
        if (_withUpdate) {
            massUpdatePools();
        }
        totalAllocPoint = totalAllocPoint.sub(poolInfo[_pid].allocPoint).add(_allocPoint);
        poolInfo[_pid].allocPoint = _allocPoint;
        poolInfo[_pid].depositFeeBP = _depositFeeBP;
        poolInfo[_pid].strategy = _strategy;
    }

    // Return reward multiplier over the given _from to _to block.
    function getMultiplier(uint256 _from, uint256 _to) public pure returns (uint256) {
        return _to.sub(_from).mul(BONUS_MULTIPLIER);
    }

    // View function to see pending CRSSs on frontend.
    function pendingCrss(uint256 _pid, address _user) external view returns (uint256) {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 accCrssPerShare = pool.accCrssPerShare;
        uint256 lpSupply;
        if(pool.strategy == address(0)) {
            lpSupply = pool.lpToken.balanceOf(address(this));
        } else {
            lpSupply = IStrategy(pool.strategy).sharesTotal();
        }
        
        if (block.number > pool.lastRewardBlock && lpSupply != 0) {
            uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number);
            uint256 crssReward = multiplier.mul(crssPerBlock).mul(pool.allocPoint).div(totalAllocPoint);
            accCrssPerShare = accCrssPerShare.add(crssReward.mul(1e12).div(lpSupply));
        }

        uint256 amount = getUserDepositBalanceByPid(_pid, _user);
        return amount.mul(accCrssPerShare).div(1e12).sub(user.rewardDebt).add(user.crssRewardLockedUp);
    }
    
    // // Harvest All Rewards pools where user has pending balance at same time!  Be careful of gas spending!
    // function massHarvest(uint256[] memory pools, bool isVest) public {
    //     uint256 poolLength = pools.length;
    //     address nulladdress = address(0);
    //     for (uint256 i = 0; i < poolLength; i++) {
    //         deposit(pools[i], 0, nulladdress, isVest);
    //     }
    // }

    // // Stake All Rewards to stakepool all pools where user has pending balance at same time!  Be careful of gas spending!
    // function massEarn(uint256[] memory pools) public {
    //     uint256 poolLength = pools.length;
    //     for (uint256 i = 0; i < poolLength; i++) {
    //         earn(pools[i]);
    //     }
    // }

    // Update reward variables for all pools. Be careful of gas spending!
    function massUpdatePools() public {
        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            updatePool(pid);
        }
    }

    // Update reward variables of the given pool to be up-to-date.
    function updatePool(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        if (block.number <= pool.lastRewardBlock) {
            return;
        }
        uint256 lpSupply;
        if(pool.strategy == address(0)) {
            lpSupply = pool.lpToken.balanceOf(address(this));
        } else {
            lpSupply = IStrategy(pool.strategy).sharesTotal();
        }
        if (lpSupply == 0 || pool.allocPoint == 0) {
            pool.lastRewardBlock = block.number;
            return;
        }
        uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number);
        uint256 crssReward = multiplier.mul(crssPerBlock).mul(pool.allocPoint).div(totalAllocPoint);
        crss.mint(devAddress, crssReward.mul(87).div(1000));
        crss.mint(address(this), crssReward);
        pool.accCrssPerShare = pool.accCrssPerShare.add(crssReward.mul(1e12).div(lpSupply));
        pool.lastRewardBlock = block.number;
    }
    // user can choose autoStake reward to stake pool instead just harvest
    function earn(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        require(pool.strategy == address(0), "external pool");
        updatePool(_pid);
        address[] memory users = autoAddressByPid[_pid].getAllAddresses();
        uint256 totalPending;
        for(uint256 i = 0; i < users.length ; i++) {
            UserInfo storage user = userInfo[_pid][users[i]];
            uint256 amount = getUserDepositBalanceByPid(_pid, users[i]);
            uint256 pending = amount.mul(pool.accCrssPerShare).div(1e12).sub(user.rewardDebt).add(user.crssRewardLockedUp);
            if(user.isVest) {
                uint256 crssReward = pending.div(2);
                uint256 xCrssReward = pending.div(2);
                totalPending = totalPending.add(crssReward);
                crss.approve(address(xCrss), xCrssReward);
                xCrss.depositToken(users[i], xCrssReward);
            }
            else {
                uint256 crssReward = pending.mul(75).div(100);
                uint256 burnReward = pending.div(25).div(100);
                totalPending = totalPending.add(crssReward);
                safeCrssTransfer(burnAddress, burnReward);
            }
            payReferralCommission(users[i], pending);
            user.crssRewardLockedUp = 0;
            user.rewardDebt = amount.mul(pool.accCrssPerShare).div(1e12);
        }

        if (totalPending > 0) {

            ICrosswisePair pair = ICrosswisePair(address(pool.lpToken));
            // used to extrac balances
            address token0 = pair.token0();
            address token1 = pair.token1();
            if (address(crss) != token0) {
                // Swap half earned to token0
                address[] memory addrPair = new address[](2);
                addrPair[0] = address(crss);
                addrPair[1] = token0;
                crssRouterAddress
                    .swapExactTokensForTokensSupportingFeeOnTransferTokens(
                    totalPending.div(2),
                    0,
                    addrPair,
                    address(this),
                    now + routerDeadlineDuration
                );
            }

            if (address(crss) != token1) {
                // Swap half earned to token1
                address[] memory addrPair = new address[](2);
                addrPair[0] = address(crss);
                addrPair[1] = token1;
                crssRouterAddress
                    .swapExactTokensForTokensSupportingFeeOnTransferTokens(
                    totalPending.div(2),
                    0,
                    addrPair,
                    address(this),
                    now + routerDeadlineDuration
                );
            }
            
            // Get want tokens, ie. add liquidity
            uint256 token0Amt = IBEP20(token0).balanceOf(address(this));
            uint256 token1Amt = IBEP20(token1).balanceOf(address(this));
            if (token0Amt > 0 && token1Amt > 0) {
                IBEP20(token0).safeIncreaseAllowance(
                    address(crssRouterAddress),
                    token0Amt
                );
                IBEP20(token1).safeIncreaseAllowance(
                    address(crssRouterAddress),
                    token1Amt
                );
                crssRouterAddress.addLiquidity(
                    token0,
                    token1,
                    token0Amt,
                    token1Amt,
                    0,
                    0,
                    address(this),
                    now + routerDeadlineDuration
                );
            }
        }
    }

    // Deposit LP tokens to MasterChef for CRSS allocation.
    function deposit(uint256 _pid, uint256 _amount, address _referrer, bool isVest, bool isAuto) public nonReentrant {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msgSender()];
        if(user.amount > 0) {
            require(user.isAuto == isAuto, "Cannot change auto compound in progress");
            require(user.isVest == isVest, "Cannot change vesting option in progress");
        }
        updatePool(_pid);
        if (_amount > 0 && address(crssReferral) != address(0) && _referrer != address(0) && _referrer != msgSender()) {
            crssReferral.recordReferral(msgSender(), _referrer);
        }
        payOrLockuppendingCrss(_pid);
        if (_amount > 0) {
            uint256 oldBalance = pool.lpToken.balanceOf(address(this));
            pool.lpToken.transferFrom(address(msgSender()), address(this), _amount);
            uint256 newBalance = pool.lpToken.balanceOf(address(this));
            _amount = newBalance.sub(oldBalance);
            if (pool.depositFeeBP > 0) {
                uint256 depositFee = _amount.mul(pool.depositFeeBP).div(10000);
                pool.lpToken.transfer(treasuryAddress, depositFee.div(2));
                pool.lpToken.transfer(devAddress, depositFee.div(2));
                _amount = _amount.sub(depositFee);
            }
            if(pool.strategy != address(0)) {
                pool.lpToken.safeIncreaseAllowance(pool.strategy, _amount);
                _amount = IStrategy(pool.strategy).deposit(msgSender(), _amount);
            }
            else if(isAuto) {
                uint256 share = _amount;
                uint256 lpSupply = pool.lpToken.balanceOf(address(this));
                if(lpSupply > 0) {
                    share = _amount.mul(totalShares[_pid]).div(lpSupply);
                    if(share == 0 && totalShares[_pid] == 0) {
                        share = _amount.div(lpSupply);
                    }
                }
                totalShares[_pid] = totalShares[_pid].add(share);
                _amount = share;
            }
            user.amount = user.amount.add(_amount);
            user.isAuto = isAuto;
            user.isVest = isVest;
            autoUserIndex(_pid, msgSender());
        }

        uint256 amount = getUserDepositBalanceByPid(_pid, msgSender());
        user.rewardDebt = amount.mul(pool.accCrssPerShare).div(1e12);
        emit Deposit(msgSender(), _pid, _amount);
    }

    // Withdraw LP tokens from MasterChef.
    function withdraw(uint256 _pid, uint256 _amount) public nonReentrant {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msgSender()];
        
        uint256 lockedAmount;
        if(pool.strategy != address(0)) {
            uint256 LockedTotal = IStrategy(pool.strategy).wantLockedTotal();
            uint256 sharesTotal = IStrategy(pool.strategy).sharesTotal();
            lockedAmount = user.amount.mul(LockedTotal).div(sharesTotal);
        }
        else if(user.isAuto) {
            uint256 lpSupply = pool.lpToken.balanceOf(address(this));
            lockedAmount = user.amount.mul(lpSupply).div(totalShares[_pid]);
        }
        else {
            lockedAmount = user.amount;
        }
        require(lockedAmount >= _amount, "withdraw: not good");

        updatePool(_pid);
        payOrLockuppendingCrss(_pid);

        if (_amount > 0) {
            uint256 shareRemoved;
            if(pool.strategy != address(0)) { 
                shareRemoved = IStrategy(pool.strategy).withdraw(msgSender(), _amount);
            }
            else if(user.isAuto) {
                uint256 lpSupply = pool.lpToken.balanceOf(address(this));
                shareRemoved = _amount.mul(totalShares[_pid]).div(lpSupply);
                totalShares[_pid] = totalShares[_pid].sub(shareRemoved);
            }
            else{
                shareRemoved = _amount;
            }
            user.amount = user.amount.sub(shareRemoved);
            autoUserIndex(_pid, msgSender());
            pool.lpToken.transfer(address(msgSender()), _amount);
        }
        uint256 amount = getUserDepositBalanceByPid(_pid, msgSender());
        user.rewardDebt = amount.mul(pool.accCrssPerShare).div(1e12);
        emit Withdraw(msgSender(), _pid, _amount);
    }

    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw(uint256 _pid) public nonReentrant {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msgSender()];
        uint256 amount;
        if(pool.strategy != address(0)) { 
            uint256 LockedTotal = IStrategy(pool.strategy).wantLockedTotal();
            uint256 sharesTotal = IStrategy(pool.strategy).sharesTotal();
            amount = user.amount.mul(LockedTotal).div(sharesTotal);
            IStrategy(pool.strategy).withdraw(msgSender(), amount);
        }
        else if(user.isAuto) {
            uint256 lpSupply = pool.lpToken.balanceOf(address(this));
            amount = user.amount.mul(lpSupply).div(totalShares[_pid]);
            totalShares[_pid] = totalShares[_pid].sub(user.amount);
        }
        else{
            amount = user.amount;
        }
        user.amount = 0;
        user.rewardDebt = 0;
        user.crssRewardLockedUp = 0;
        autoUserIndex(_pid, msgSender());
        pool.lpToken.transfer(address(msgSender()), amount);
        emit EmergencyWithdraw(msgSender(), _pid, amount);
    }

    // Pay or lockup pending CRSSs.
    function payOrLockuppendingCrss(uint256 _pid) internal {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msgSender()];

        if(user.amount > 0)
        {
            uint256 amount = getUserDepositBalanceByPid(_pid, msgSender());
            uint256 pending = amount.mul(pool.accCrssPerShare).div(1e12).sub(user.rewardDebt).add(user.crssRewardLockedUp);
            if (pending > 0) {
                if(user.isAuto) {
                    user.crssRewardLockedUp = pending;
                    return;
                }
                // send rewards
                if(user.isVest) {
                    uint256 crssReward = pending.div(2);
                    uint256 xCrssReward = pending.div(2);

                    safeCrssTransfer(msgSender(), crssReward);

                    crss.approve(address(xCrss), xCrssReward);
                    xCrss.depositToken(msgSender(), xCrssReward);
                }
                else {
                    uint256 crssReward = pending.mul(75).div(100);
                    uint256 burnReward = pending.div(25).div(100);

                    safeCrssTransfer(msgSender(), crssReward);
                    safeCrssTransfer(burnAddress, burnReward);
                }
                payReferralCommission(msgSender(), pending);
            }
        }
    }

    // Safe crss transfer function, just in case if rounding error causes pool to not have enough CRSSs.
    function safeCrssTransfer(address _to, uint256 _amount) internal {
        uint256 crssBal = crss.balanceOf(address(this));
        if (_amount > crssBal) {
            crss.transfer(_to, crssBal);
        } else {
            crss.transfer(_to, _amount);
        }
    }

    // Update dev address by the previous dev.
    function setDevAddress(address _devAddress) public {
        require(msgSender() == devAddress, "setDevAddress: FORBIDDEN");
        require(_devAddress != address(0), "setDevAddress: ZERO");
        devAddress = _devAddress;
    }

    function setTreasuryAddress(address _treasuryAddress) public {
        require(msgSender() == treasuryAddress, "setTreasuryAddress: FORBIDDEN");
        require(_treasuryAddress != address(0), "setTreasuryAddress: ZERO");
        treasuryAddress = _treasuryAddress;
    }

    // Crosswise has to add hidden dummy pools in order to alter the emission, here we make it simple and transparent to all.
    function updateEmissionRate(uint256 _crssPerBlock) public onlyOwner {
        massUpdatePools();
        emit EmissionRateUpdated(msgSender(), crssPerBlock, _crssPerBlock);
        crssPerBlock = _crssPerBlock;
    }

    // Update the crss referral contract address by the owner
    function setcrssReferral(ICrssReferral _crssReferral) public onlyOwner {
        crssReferral = _crssReferral;
    }

    // Update referral commission rate by the owner
    function setReferralCommissionRate(uint256 _referralCommissionRate) public onlyOwner {
        require(_referralCommissionRate <= MAXIMUM_REFERRAL_COMMISSION_RATE, "setReferralCommissionRate: invalid referral commission rate basis points");
        referralCommissionRate = _referralCommissionRate;
    }

    // Pay referral commission to the referrer who referred this user.
    function payReferralCommission(address _user, uint256 _pending) internal {
        if (address(crssReferral) != address(0) && referralCommissionRate > 0) {
            address referrer = crssReferral.getReferrer(_user);
            uint256 commissionAmount = _pending.mul(referralCommissionRate).div(10000);

            if (referrer != address(0) && commissionAmount > 0) {
                crss.mint(referrer, commissionAmount);
                crssReferral.recordReferralCommission(referrer, commissionAmount);
                emit ReferralCommissionPaid(_user, referrer, commissionAmount);
            }
        }
    }

    function autoUserIndex( uint256 _pid, address _user ) internal {
        AddrArrayLib.Addresses storage addr = autoAddressByPid[_pid];

        uint256 amount = userInfo[_pid][_user].amount;
        bool isAuto = userInfo[_pid][_user].isAuto;
        if(isAuto) {
            if( amount > 0 ){ // add user
                addr.pushAddress(_user);
            }else if( amount == 0 ){ // remove user
                addr.removeAddress(_user);
            }
        }
    }
}
