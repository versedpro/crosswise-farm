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
        uint256 withdrawAmount;   
    }

    IBEP20 crssToken;

    mapping(address => UserDetail) public userDetail;

    uint256 public constant oneMonth = 30 days;
    uint256 public constant unlockPerMonth = 20;

    address public masterChef;

    function initialize(
        IBEP20 _crssToken,
        address _masterChef
    ) public initializer {
        require(address(_crssToken) != address(0), "xCrssToken: Token contract address should not be zero address");
        require(_masterChef != address(0), "xCrssToken: MasterChef contract address should not be zero address");
        
        crssToken = _crssToken;
        masterChef = _masterChef;

        __BEP20_init("Locked Crosswise Token", "xCRSS");
    }
    
    function unlockedToken(address _user) public view returns (uint256) {
        UserDetail storage user = userDetail[_user];

        if(_getNow() <= user.depositTime) {
            return 0;
        }
        else {
            uint256 timePassed = _getNow().sub(user.depositTime);
            uint256 monthPassed = timePassed.div(oneMonth);
            uint256 unlocked;
            if(monthPassed >= 5){
                unlocked = user.totalRewardAmount;
            } else {
                unlocked = user.totalRewardAmount.mul(unlockPerMonth.mul(monthPassed)).div(100);
            }
            return unlocked.sub(user.withdrawAmount);
        }
    }

    function depositToken(address _depositUser, uint256 _rewardAmount) public {
        require(msg.sender == masterChef, "xCrssToken.deposit: Sender must be masterChef contract");

        require(_depositUser != address(0), "xCrssToken.deposit: Deposit user address should not be zero address");

        crssToken.safeTransferFrom(msg.sender, address(this), _rewardAmount);

        _mint(_depositUser, _rewardAmount);

        UserDetail storage user = userDetail[_depositUser];
        user.depositTime = _getNow();
        user.totalRewardAmount = user.totalRewardAmount.add(_rewardAmount);

        emit Deposit(_depositUser, _rewardAmount);
    }

    function withdrawToken(uint256 _amount) public {
        uint256 unlocked = unlockedToken(msg.sender);
        require(unlocked >= _amount, "xCrssToken.withdrawToken: Not enough token to withdraw.");

        UserDetail storage user = userDetail[msg.sender];

        user.withdrawAmount = user.withdrawAmount.add(_amount);

        crssToken.safeTransfer(msg.sender, _amount);
        
        _burn(msg.sender, _amount);

        emit WithdrawToken(msg.sender, _amount);
    }

    function _getNow() public virtual view returns (uint256) {
        return block.timestamp;
    }
}