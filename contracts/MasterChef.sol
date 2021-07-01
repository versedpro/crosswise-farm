// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "./libs/IBEP20.sol";
import "./libs/SafeBEP20.sol";
import "./libs/ICrssReferral.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import "./CrssToken.sol";
import "./xCrssToken.sol";

// MasterChef is the master of Crss. He can make Crss and he is a fair guy.
//
// Note that it's ownable and the owner wields tremendous power. The ownership
// will be transferred to a governance smart contract once CRSS is sufficiently
// distributed and the community can show to govern itself.
//
// Have fun reading it. Hopefully it's bug-free. God bless.
contract MasterChef is Ownable, ReentrancyGuard {
    using SafeMath for uint256;
    using SafeBEP20 for IBEP20;

    // Info of each user.
    struct UserInfo {
        uint256 amount;         // How many LP tokens the user has provided.
        uint256 rewardDebt;     // Reward debt. See explanation below.
        uint256 rewardLockedUp;  // Reward locked up.
        // uint256 nextHarvestUntil; // When can the user harvest again.
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
        uint16 depositFeeBP;      // Deposit fee in basis points
    }

    // The CRSS TOKEN!
    CrssToken public crss;
    // The XCRSS TOKEN!
    xCrssToken public xCrss;
    //steps in time to change crssPerBlock
    uint256 public immutable timeFirstStep;
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

    // Info of each pool.
    PoolInfo[] public poolInfo;
    // Info of each user that stakes LP tokens.
    mapping(uint256 => mapping(address => UserInfo)) public userInfo;
    // Total allocation points. Must be the sum of all allocation points in all pools.
    uint256 public totalAllocPoint = 0;
    // The block number when CRSS mining starts.
    uint256 public startBlock;
    // Total locked up rewards
    uint256 public totalLockedUpRewards;

    // Crss referral contract address.
    ICrssReferral public crssReferral;
    // Referral commission rate in basis points.
    uint16 public referralCommissionRate = 100;
    // Max referral commission rate: 10%.
    uint16 public constant MAXIMUM_REFERRAL_COMMISSION_RATE = 1000;

    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event EmissionRateUpdated(address indexed caller, uint256 previousAmount, uint256 newAmount);
    event ReferralCommissionPaid(address indexed user, address indexed referrer, uint256 commissionAmount);
    event RewardLockedUp(address indexed user, uint256 indexed pid, uint256 amountLockedUp);
    event CrssPerBlockUpdated(uint256 crssPerBlock);

    constructor(
        CrssToken _crss,
        xCrssToken _xCrss,
        address _devAddress,
        address _treasuryAddress,
        uint256 _startBlock
    ) public {
        require(address(_crss) != address(0), "constructor: crss token address is zero address");
        require(address(_xCrss) != address(0), "constructor: xcrss token address is zero address");
        require(_devAddress != address(0), "constructor: dev address is zero address");
        require(_treasuryAddress != address(0), "constructor: treasury address is zero address");
        

        crss = _crss;
        xCrss = _xCrss;
        startBlock = _startBlock;
        crssPerBlock = 1.2 * 10 ** 18;

        devAddress = _devAddress;
        treasuryAddress = _treasuryAddress;

        timeFirstStep = now + 14 days;
    }

    function poolLength() external view returns (uint256) {
        return poolInfo.length;
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
    function add(uint256 _allocPoint, IBEP20 _lpToken, uint16 _depositFeeBP, bool _withUpdate) public onlyOwner {
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
            depositFeeBP: _depositFeeBP
        }));
    }

    // Update the given pool's CRSS allocation point and deposit fee. Can only be called by the owner.
    function set(uint256 _pid, uint256 _allocPoint, uint16 _depositFeeBP, bool _withUpdate) public onlyOwner {
        require(_depositFeeBP <= 10000, "set: invalid deposit fee basis points");
        if (_withUpdate) {
            massUpdatePools();
        }
        totalAllocPoint = totalAllocPoint.sub(poolInfo[_pid].allocPoint).add(_allocPoint);
        poolInfo[_pid].allocPoint = _allocPoint;
        poolInfo[_pid].depositFeeBP = _depositFeeBP;
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
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        if (block.number > pool.lastRewardBlock && lpSupply != 0) {
            uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number);
            uint256 crssReward = multiplier.mul(crssPerBlock).mul(pool.allocPoint).div(totalAllocPoint);
            accCrssPerShare = accCrssPerShare.add(crssReward.mul(1e12).div(lpSupply));
        }
        uint256 pending = user.amount.mul(accCrssPerShare).div(1e12).sub(user.rewardDebt);
        return pending.add(user.rewardLockedUp);
    }
    
    // Harvest All Rewards pools where user has pending balance at same time!  Be careful of gas spending!
    function massHarvest(uint256[] memory pools, bool immediateClaim) public {
        uint256 poolLength = pools.length;
        address nulladdress = address(0);
        for (uint256 i = 0; i < poolLength; i++) {
            deposit(pools[i], 0, nulladdress, immediateClaim);
        }
    }

    // Stake All Rewards to stakepool all pools where user has pending balance at same time!  Be careful of gas spending!
    function massStake(uint256[] memory pools) public {
        uint256 poolLength = pools.length;
        for (uint256 i = 0; i < poolLength; i++) {
            stakeReward(pools[i]);
        }
    }

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
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        if (lpSupply == 0 || pool.allocPoint == 0) {
            pool.lastRewardBlock = block.number;
            return;
        }
        if (now < timeFirstStep)
            crssPerBlock = 1 * 10 ** 18;
        uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number);
        uint256 crssReward = multiplier.mul(crssPerBlock).mul(pool.allocPoint).div(totalAllocPoint);
        crss.mint(devAddress, crssReward.div(115).mul(10));
        crss.mint(address(this), crssReward);
        pool.accCrssPerShare = pool.accCrssPerShare.add(crssReward.mul(1e12).div(lpSupply));
        pool.lastRewardBlock = block.number;
    }

    // user can choose autoStake reward to stake pool instead just harvest
    function stakeReward(uint256 _pid) public {

        UserInfo storage user = userInfo[_pid][msg.sender];

        if (user.amount > 0) {
            PoolInfo storage pool = poolInfo[_pid];

            updatePool(_pid);

            uint256 pending = user.amount.mul(pool.accCrssPerShare).div(1e12).sub(user.rewardDebt);
            if (pending > 0) {
                safeCrssTransfer(msg.sender, pending);
                payReferralCommission(msg.sender, pending);
                
                deposit(stakePoolId, pending, address(0), false);
            }
            user.rewardDebt = user.amount.mul(pool.accCrssPerShare).div(1e12);
        }
    }

    // Deposit LP tokens to MasterChef for CRSS allocation.
    function deposit(uint256 _pid, uint256 _amount, address _referrer, bool immediateClaim) public nonReentrant {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        updatePool(_pid);
        if (_amount > 0 && address(crssReferral) != address(0) && _referrer != address(0) && _referrer != msg.sender) {
            crssReferral.recordReferral(msg.sender, _referrer);
        }
        payOrLockuppendingCrss(_pid, immediateClaim);
        if (_amount > 0) {
            uint256 oldBalance = pool.lpToken.balanceOf(address(this));
            pool.lpToken.safeTransferFrom(address(msg.sender), address(this), _amount);
            uint256 newBalance = pool.lpToken.balanceOf(address(this));
            _amount = newBalance.sub(oldBalance);
            // Once deposit token is Crss.
            // if (address(pool.lpToken) == address(crss)) {
            //     uint256 transferTax = _amount.mul(400).div(10000);
            //     _amount = _amount.sub(transferTax);
            // }
            
            if (pool.depositFeeBP > 0) {
                uint256 depositFee = _amount.mul(pool.depositFeeBP).div(10000);
                pool.lpToken.safeTransfer(treasuryAddress, depositFee.mul(50).div(100));
                pool.lpToken.safeTransfer(devAddress, depositFee.mul(50).div(100));
                user.amount = user.amount.add(_amount).sub(depositFee);
            } else {
                user.amount = user.amount.add(_amount);
            }
        }
        user.rewardDebt = user.amount.mul(pool.accCrssPerShare).div(1e12);
        emit Deposit(msg.sender, _pid, _amount);
    }

    // Withdraw LP tokens from MasterChef.
    function withdraw(uint256 _pid, uint256 _amount) public nonReentrant {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        require(user.amount >= _amount, "withdraw: not good");
        updatePool(_pid);
        payOrLockuppendingCrss(_pid, false);
        if (_amount > 0) {
            user.amount = user.amount.sub(_amount);
            pool.lpToken.safeTransfer(address(msg.sender), _amount);
        }
        user.rewardDebt = user.amount.mul(pool.accCrssPerShare).div(1e12);
        emit Withdraw(msg.sender, _pid, _amount);
    }

    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw(uint256 _pid) public nonReentrant {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        uint256 amount = user.amount;
        user.amount = 0;
        user.rewardDebt = 0;
        user.rewardLockedUp = 0;
        pool.lpToken.safeTransfer(address(msg.sender), amount);
        emit EmergencyWithdraw(msg.sender, _pid, amount);
    }

    // Pay or lockup pending CRSSs.
    function payOrLockuppendingCrss(uint256 _pid, bool _immediateClaim) internal {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];

        if(user.amount > 0)
        {
            uint256 pending = user.amount.mul(pool.accCrssPerShare).div(1e12).sub(user.rewardDebt);
            if (pending > 0) {
                // send rewards
                if(_immediateClaim) {
                    uint256 crssReward = pending.mul(75).div(100);
                    uint256 burnReward = pending.div(25).div(100);

                    safeCrssTransfer(msg.sender, crssReward);
                    safeCrssTransfer(burnAddress, burnReward);
                }
                else {
                    uint256 crssReward = pending.div(2);
                    uint256 xCrssReward = pending.div(2);

                    safeCrssTransfer(msg.sender, crssReward);

                    crss.approve(address(xCrss), xCrssReward);
                    xCrss.depositToken(msg.sender, xCrssReward);
                }   
                payReferralCommission(msg.sender, pending);
                
                
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
        require(msg.sender == devAddress, "setDevAddress: FORBIDDEN");
        require(_devAddress != address(0), "setDevAddress: ZERO");
        devAddress = _devAddress;
    }

    function setTreasuryAddress(address _treasuryAddress) public {
        require(msg.sender == treasuryAddress, "setTreasuryAddress: FORBIDDEN");
        require(_treasuryAddress != address(0), "setTreasuryAddress: ZERO");
        treasuryAddress = _treasuryAddress;
    }

    // Crosswise has to add hidden dummy pools in order to alter the emission, here we make it simple and transparent to all.
    function updateEmissionRate(uint256 _crssPerBlock) public onlyOwner {
        massUpdatePools();
        emit EmissionRateUpdated(msg.sender, crssPerBlock, _crssPerBlock);
        crssPerBlock = _crssPerBlock;
    }

    // Update the crss referral contract address by the owner
    function setcrssReferral(ICrssReferral _crssReferral) public onlyOwner {
        crssReferral = _crssReferral;
    }

    // Update referral commission rate by the owner
    function setReferralCommissionRate(uint16 _referralCommissionRate) public onlyOwner {
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
}
