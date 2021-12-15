// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "./libs/BEP20UpgradeSafe.sol";
import "./libs/IBEP20.sol";
import "./libs/SafeBEP20.sol";

import "@openzeppelin/contracts/math/SafeMath.sol";


contract xCrssToken is BEP20UpgradeSafe {
 
    using SafeMath for uint256;
    using SafeBEP20 for IBEP20;

    event Deposit(
        address depositUser, 
        uint256 rewardAmount
    );
    
    event WithdrawToken(
        address user, 
        uint256 amount
    );

    struct UserDetail {
        uint256 depositTime;
        uint256 totalRewardAmount;
        uint256 withdrawnAmount;
    }

    IBEP20 crssToken;

    mapping(address => UserDetail[]) public userDetail;

    mapping(address => uint256) public userWithdrawAmount;

    uint256 public constant oneMonth = 30 days;
    uint256 public constant unlockPerMonth = 20;

    address public masterChef;
    address public stakingVault;

    function initialize(
        IBEP20 _crssToken,
        address _masterChef,
        address _stakingVault
    ) public initializer {
        require(address(_crssToken) != address(0), "xCrssToken: Token contract address should not be zero address");
        require(_masterChef != address(0), "xCrssToken: MasterChef contract address should not be zero address");
        
        crssToken = _crssToken;
        masterChef = _masterChef;
        stakingVault = _stakingVault;

        __BEP20_init("Locked Crosswise Token", "xCRSS");
    }

    function removeDepositedElement(address _user , uint _index) public {
        UserDetail[] storage user = userDetail[_user];

        require(_index < user.length, "xCrssToken: Index of user detail array out of bound");

        for (uint i = _index; i < user.length - 1; i++) {
            user[i] = user[i + 1];
        }
        user.pop();
    }
    
    function unlockedTokenAmount(address _user, uint256 _withdrawAmount) public returns (uint256) {
        UserDetail[] storage user = userDetail[_user];

        uint256 totalUnlocked;
        uint256 unlockedToken;
        uint256 fullPassedToken;

        for (uint256 i = 0; i < user.length; i ++) {
            if(_getNow() > user[i].depositTime) {
                uint256 timePassed = _getNow().sub(user[i].depositTime);
                uint256 monthPassed = timePassed.div(oneMonth);
                uint256 unlocked;

                if(monthPassed >= 5){
                    unlocked = user[i].totalRewardAmount;
                } else {
                    unlocked = user[i].totalRewardAmount.mul(unlockPerMonth.mul(monthPassed)).div(100);
                }

                if (unlocked >= _withdrawAmount) {
                    user[i].withdrawnAmount = _withdrawAmount;
                } else {
                    _withdrawAmount = _withdrawAmount.sub(user[i].totalRewardAmount);
                }

                if (user[i].totalRewardAmount == user[i].withdrawnAmount) {
                    removeDepositedElement(_user, i);
                    fullPassedToken.add(unlocked);
                }

                totalUnlocked.add(unlocked);
            }
        }

        unlockedToken = totalUnlocked.sub(userWithdrawAmount[_user]);

        userWithdrawAmount[_user].sub(fullPassedToken);

        return unlockedToken;
    }

    function depositToken(address _depositUser, uint256 _rewardAmount) public {
        require(msg.sender == masterChef || msg.sender == stakingVault, "xCrssToken.deposit: Sender must be masterChef or stakingVault contract");

        require(_depositUser != address(0), "xCrssToken.deposit: Deposit user address should not be zero address");

        crssToken.transferFrom(msg.sender, address(this), _rewardAmount);

        _mint(_depositUser, _rewardAmount);

        UserDetail[] storage user = userDetail[_depositUser];
        UserDetail storage userInfo;

        userInfo.depositTime = _getNow();
        userInfo.totalRewardAmount = _rewardAmount;
        user.push(userInfo);

        emit Deposit(_depositUser, _rewardAmount);
    }

    function withdrawToken(uint256 _amount) public {
        uint256 unlocked = unlockedTokenAmount(msg.sender, _amount);
        require(unlocked >= _amount, "xCrssToken.withdrawToken: Not enough token to withdraw.");

        userWithdrawAmount[msg.sender] = userWithdrawAmount[msg.sender].add(_amount);

        crssToken.transfer(msg.sender, _amount);
        
        _burn(msg.sender, _amount);

        emit WithdrawToken(msg.sender, _amount);
    }

    function _getNow() public virtual view returns (uint256) {
        return block.timestamp;
    }
}