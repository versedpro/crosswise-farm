pragma solidity ^0.6.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import "./libs/SafeBEP20.sol";
import "./libs/IBEP20.sol";

contract Presale is Ownable, ReentrancyGuard {
    using SafeMath for uint256;
    using SafeBEP20 for IBEP20;
    event Deposit(
        address indexed depositUser, 
        uint256 amount
    );
    
    event Withdraw(
        address indexed user, 
        uint256 amount
    );

    event SetWhiteList(
        address indexed addr,
        bool status
    );

    struct UserDetail {
        uint256 depositTime;
        uint256 totalRewardAmount;
        uint256 withdrawAmount;   
        uint256 depositAmount;
    }
    
    IBEP20 crssToken;
    IBEP20 busd;
    
    mapping(address => UserDetail) public userDetail;
    mapping(address => uint256) public deposits;
    mapping(address => bool) whitelist;

    address[] public investors;

    address public masterWallet;
    
    uint256 public totalDepositedBusdBalance;
    uint256 public totalRewardAmount;
    uint256 public totalWithdrawedAmount;

    uint256 public constant oneMonth = 30 days;
    uint256 public constant unlockPerMonth = 20;
    uint256 public startTimestamp;
    uint256 public softCapAmount = 200000000000000000000000; // 200k USD
    uint256 public hardCapAmount = 500000000000000000000000; // 500k USD
    uint256 public fistTokenPrice = 200000000000000000; // 0.2 BUSD
    uint256 public secondTokenPrice = 300000000000000000; // 0.3 BUSD
    uint256 public tokenPrice = fistTokenPrice; // First Stage: 0.2 BUSD
    // uint256 public hardCapPrice = 1000000000000000000; //1 BUSD
    uint256 public maxBusdPerWallet = 25000000000000000000000; // 25k BUSD
    uint256 public maxSupply = 2000000000000000000000000; // 2M CRSS

    constructor(
        IBEP20 _crssToken,
        IBEP20 _busd,
        address _masterWallet,
        uint256 _startTimestamp
    ) public {
        require(address(_crssToken) != address(0), "Presale: Token address should not be zero address");
        require(address(_busd) != address(0), "Presale: BUSD token address should not be zero address");
        require(_masterWallet != address(0), "Presale: master wallet address should not be zero address");
        require(_startTimestamp >= _getNow(), "Presale: Presale start time invalid");

        crssToken = _crssToken;
        busd = _busd;
        masterWallet = _masterWallet;
        startTimestamp = _startTimestamp;

    }

    function investorCount() public view returns (uint256) {
        return investors.length;
    }

    function allInvestors() public view returns (address[] memory) {
        return investors;
    }
    
    function updateSoftCapAmount(uint256 _softCapAmount) external onlyOwner {
        require(_softCapAmount > 0, "Presale.updateSoftCapAmount: soft cap amount invalid");
        softCapAmount = _softCapAmount;
    }

    function updateHardCapAmount(uint256 _hardCapAmount) external onlyOwner {
        require(_hardCapAmount > 0, "Presale.updateHardCapAmount: soft cap amount invalid");
        hardCapAmount = _hardCapAmount;
    }

    function updateTokenPrice(uint256 _tokenPrice) external onlyOwner {
        require(_tokenPrice > 0, "Presale.updateTokenPrice: soft cap amount invalid");
        tokenPrice = _tokenPrice;
    }

    function setWhiteList(address _addr, bool _status) external onlyOwner {
        require(_addr != address(0), "Presale.setWhiteList: Zero Address");
        whitelist[_addr] = _status;
        emit SetWhiteList(_addr, _status);
    }

    function deposit(uint256 _amount) external payable nonReentrant {
        require(whitelist[msg.sender], "Presale.deposit: depositor should be whitelist member");
        require(_getNow() >= startTimestamp, "Presale.deposit: Presale is not active");
        require(totalDepositedBusdBalance + _amount <= hardCapAmount, "deposit is above hardcap limit");
        
        UserDetail storage user = userDetail[msg.sender];

        require(user.depositAmount + _amount <= maxBusdPerWallet, "Presale.deposit: deposit amount is bigger than max deposit amount");

        if (totalDepositedBusdBalance >= softCapAmount && tokenPrice != secondTokenPrice) {
            tokenPrice = secondTokenPrice;
        }

        uint256 rewardTokenAmount = _amount.mul(1e18).div(tokenPrice);
        require(totalRewardAmount.add(rewardTokenAmount) > maxSupply, "Presale.deposit: The desired amount must be less than the total presale amount");
        require(crssToken.balanceOf(address(this)).add(totalWithdrawedAmount).sub(totalRewardAmount) >= rewardTokenAmount, "Presale.deposit: not enough token to reward" );
        if(user.depositAmount == 0) {
            investors.push(msg.sender);
        }
        user.depositTime = _getNow();
        user.depositAmount = user.depositAmount + _amount;
        user.totalRewardAmount = user.totalRewardAmount.add(rewardTokenAmount);
        totalRewardAmount = totalRewardAmount.add(rewardTokenAmount);
        totalDepositedBusdBalance = totalDepositedBusdBalance + _amount;

        busd.safeTransferFrom(msg.sender, masterWallet, _amount);
        
        emit Deposit(msg.sender, _amount);
    }

    function withdrawToken(uint256 _amount) external {
        uint256 unlocked = unlockedToken(msg.sender);
        require(unlocked >= _amount, "Presale.withdrawToken: Not enough token to withdraw.");

        UserDetail storage user = userDetail[msg.sender];

        user.withdrawAmount = user.withdrawAmount.add(_amount);
        totalWithdrawedAmount = totalWithdrawedAmount.add(_amount);

        crssToken.transfer(msg.sender, _amount);
        
        emit Withdraw(msg.sender, _amount);
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
    
    function _getNow() internal virtual view returns (uint256) {
        return block.timestamp;
    }
}