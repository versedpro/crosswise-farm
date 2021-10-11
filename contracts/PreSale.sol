// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.6.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import "./libs/SafeBEP20.sol";
import "./libs/IBEP20.sol";


/**
 * @title Presale smart contract that sells CRSS token using BUSD
 */

contract Presale is Ownable, ReentrancyGuard {
    using SafeMath for uint256;
    using SafeBEP20 for IBEP20;

    /// @notice event emitted when softcap amount is updated
    event UpdateSoftCapAmount(
        uint256 softCapAmount
    );

    /// @notice event emitted when second round amount is updated
    event UpdateSecondRoundAmount(
        uint256 secondRoundAmount
    );

    /// @notice event emitted when hardcap amount is updated
    event UpdateHardCapAmount(
        uint256 hardCapAmount
    );

    /// @notice event emitted when min purchase amount is updated
    event UpdateMinPurchase(
        uint256 minPurchase
    );

    /// @notice event emitted when max busd per wallet is updated
    event UpdateMaxBusdPerWallet(
        uint256 maxBusdPerWallet
    );

    /// @notice event emitted when address is set/unset from whitelist
    event SetWhiteList(
        address indexed addr,
        bool status
    );

    /// @notice event emitted when user deposits busd
    event Deposit(
        address indexed depositUser, 
        uint256 amount
    );
    
    /// @notice event emitted when user withdraws the reward token
    event Withdraw(
        address indexed user, 
        uint256 amount
    );

    /// @notice Information about user that buy crss token
    struct UserDetail {
        uint256 depositTime;
        uint256 totalRewardAmount;
        uint256 withdrawAmount;   
        uint256 depositAmount;
    }

    /// @notice BEP20 token - Reward token
    IBEP20 public immutable crssToken;

    /// @notice BEP20 token - Deposit token
    IBEP20 public immutable busd;
    
    /// @notice User address -> User information
    mapping(address => UserDetail) public userDetail;

    /// @notice Address -> Status(True/False) that represents whitelist.
    mapping(address => bool) public whitelist;

    /// @notice Investors address list
    address[] public investors;

    /// @notice Address that deposited fund will be sent
    address public immutable masterWallet;
    
    /// @notice Sum of each user's deposited busd amount
    uint256 public totalDepositedBusdBalance;

    /// @notice Sum of each user's reward token amount 
    uint256 public totalRewardAmount;

    /// @notice Sum of each user's withdrawed reward token amount
    uint256 public totalWithdrawedAmount;

    /// @notice Presale start time
    uint256 public immutable startTimestamp;

    /// @notice Softcap busd token amount. i.e. 200k BUSD
    uint256 public softCapAmount = 200000 * 1e18;

    /// @notice Second round busd token amount. i.e. 500k BUSD
    uint256 public secondRoundAmount = 500000 * 1e18;

    /// @notice Hardcap busd token amount. i.e. 1.1M BUSD
    uint256 public hardCapAmount = 1100000 * 1e18;

    /// @notice Minimum BUSD token amount for deposit. i.e. 250 BUSD
    uint256 public minPurchase = 250 * 1e18;

    /// @notice Maximum BUSD amount that can be deposited per each wallet. i.e. 25k BUSD
    uint256 public maxBusdPerWallet = 25000 * 1e18;

    /// @notice Day count for 1 month
    uint256 public constant oneMonth = 30 days;

    /// @notice Unlock token percent per month. i.e. 20 = 20%
    uint256 public constant unlockPerMonth = 20;

    /// @notice Maximum CRSS token amount for Presale. i.e. 3M(6% of Max supply) CRSS
    uint256 public constant maxSupply = 3000000 * 1e18;

    /// @notice Token price for first stage. i.e. 0.2 BUSD
    uint256 public constant firstTokenPrice = 2 * 1e17;

    /// @notice Token price for second stage. i.e. 0.3 BUSD
    uint256 public constant secondTokenPrice = 3 * 1e17;

    /// @notice Token price for third stage. i.e. 0.6 BUSD
    uint256 public constant thirdTokenPrice = 6 * 1e17;

    /// @notice Token price for presale. On softcap it's firstTokenPrice and it will be updated to secondTokenPrice and then thirdTokenPrice on hardcap
    uint256 public tokenPrice = firstTokenPrice;


    /**
     * @param _crssToken Address of reward token
     * @param _busd Address of busd-staking token
     * @param _masterWallet Address where collected funds will be forwarded to
     * @param _startTimestamp Presale start time
     */
    
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

    /**
     * @notice Method for getting total investors count
     */
    function investorCount() external view returns (uint256) {
        return investors.length;
    }

    /**
     * @notice Method for getting all investors address
     */
    function allInvestors() external view returns (address[] memory) {
        return investors;
    }
    
    /**
     * @notice Method for updating softcap amount
     * @dev Only admin
     * @param _softCapAmount New softcap amount
     */
    function updateSoftCapAmount(uint256 _softCapAmount) external onlyOwner {
        require(_softCapAmount > 0, "Presale.updateSoftCapAmount: soft cap amount invalid");
        softCapAmount = _softCapAmount;

        emit UpdateSoftCapAmount(_softCapAmount);
    }

    /**
     * @notice Method for updating hardcap amount
     * @dev Only admin
     * @param _hardCapAmount New hardcap amount
     */
    function updateHardCapAmount(uint256 _hardCapAmount) external onlyOwner {
        require(_hardCapAmount > 0, "Presale.updateHardCapAmount: hard cap amount invalid");
        hardCapAmount = _hardCapAmount;

        emit UpdateHardCapAmount(_hardCapAmount);
    }

    /**
     * @notice Method for updating second round amount
     * @dev Only admin
     * @param _secondRoundAmount New second round amount
     */
    function updateSecondRoundAmount(uint256 _secondRoundAmount) external onlyOwner {
        require(_secondRoundAmount > 0, "Presale.updateSoftCapAmount: soft cap amount invalid");
        secondRoundAmount = _secondRoundAmount;

        emit UpdateSoftCapAmount(_secondRoundAmount);
    }

    /**
     * @notice Method for updating min purchase
     * @dev Only admin
     * @param _minPurchase New min purchase per user
     */
    function updateMinPurchase(uint256 _minPurchase) external onlyOwner {
        require(_minPurchase > 0, "Presale.updateMinPurchase: min purchase amount invalid");
        minPurchase = _minPurchase;

        emit UpdateMinPurchase(_minPurchase);
    }

    /**
     * @notice Method for updating maxBusdPerWallet
     * @dev Only admin
     * @param _maxBusdPerWallet New maxBusdPerWallet
     */
    function updateMaxBusdPerWallet(uint256 _maxBusdPerWallet) external onlyOwner {
        require(_maxBusdPerWallet > 0, "Presale.updateMaxBusdPerWallet: max busd amount invalid");
        maxBusdPerWallet = _maxBusdPerWallet;

        emit UpdateMaxBusdPerWallet(_maxBusdPerWallet);
    }

    /**
     * @notice Method for setting whitelist address for presale
     * @dev Only admin
     * @param _addr Address for whitelist
     * @param _status Boolean value that determines to set/unset address to whitelist
     */
    function setWhiteList(address _addr, bool _status) external onlyOwner {
        require(_addr != address(0), "Presale.setWhiteList: Zero Address");
        whitelist[_addr] = _status;

        emit SetWhiteList(_addr, _status);
    }

    /**
     * @notice Method for depositing busd token to buy Crss token
     * @param _amount Busd token amount for depositing
     */
    function deposit(uint256 _amount) external nonReentrant {
        require(whitelist[msg.sender], "Presale.deposit: depositor should be whitelist member");
        require(_getNow() >= startTimestamp, "Presale.deposit: Presale is not active");
        require(totalDepositedBusdBalance + _amount <= hardCapAmount, "deposit is above hardcap limit");
        require(_amount >= minPurchase, "Presale.deposit: Min buy is 250 usd");
        
        UserDetail storage user = userDetail[msg.sender];

        require(user.depositAmount + _amount <= maxBusdPerWallet, "Presale.deposit: deposit amount is bigger than max deposit amount");
        uint256 rewardTokenAmount;

        if (totalDepositedBusdBalance < softCapAmount && softCapAmount.sub(totalDepositedBusdBalance) <= _amount) {
            uint256 amountSoft = softCapAmount.sub(totalDepositedBusdBalance);
            uint256 amountSecond = _amount.sub(amountSoft);
            rewardTokenAmount = amountSoft.mul(1e18).div(firstTokenPrice) + amountSecond.mul(1e18).div(secondTokenPrice);
            tokenPrice = secondTokenPrice;
        }
        else if (totalDepositedBusdBalance < secondRoundAmount && secondRoundAmount.sub(totalDepositedBusdBalance) <= _amount) {
            uint256 amountSecond = secondRoundAmount.sub(totalDepositedBusdBalance);
            uint256 amountHard = _amount.sub(amountSecond);
            rewardTokenAmount = amountSecond.mul(1e18).div(secondTokenPrice) + amountHard.mul(1e18).div(thirdTokenPrice);
            tokenPrice = thirdTokenPrice;
        }
        else {
            rewardTokenAmount = _amount.mul(1e18).div(tokenPrice);
        }
         
        require(totalRewardAmount.add(rewardTokenAmount) <= maxSupply, "Presale.deposit: The desired amount must be less than the total presale amount");
        require(crssToken.balanceOf(address(this)).add(totalWithdrawedAmount).sub(totalRewardAmount) >= rewardTokenAmount, "Presale.deposit: not enough token to reward" );

        busd.safeTransferFrom(msg.sender, masterWallet, _amount);

        if(user.depositAmount == 0) {
            investors.push(msg.sender);
        }

        user.depositTime = _getNow();
        user.depositAmount = user.depositAmount + _amount;
        user.totalRewardAmount = user.totalRewardAmount.add(rewardTokenAmount);
        totalRewardAmount = totalRewardAmount.add(rewardTokenAmount);
        totalDepositedBusdBalance = totalDepositedBusdBalance + _amount;

        emit Deposit(msg.sender, _amount);
    }

    /**
     * @notice Method for withdrawing unlocked reward token.
     * @dev Users can withdraw only unlocked amount.
     * @param _amount Crss token amount to withdraw
     */
    function withdrawToken(uint256 _amount) external nonReentrant {
        uint256 unlocked = unlockedToken(msg.sender);
        require(unlocked >= _amount, "Presale.withdrawToken: Not enough token to withdraw.");

        crssToken.safeTransfer(msg.sender, _amount);

        UserDetail storage user = userDetail[msg.sender];
        user.withdrawAmount = user.withdrawAmount.add(_amount);
        totalWithdrawedAmount = totalWithdrawedAmount.add(_amount);
        
        emit Withdraw(msg.sender, _amount);
    }

    /**
     * @notice Method for getting the unlocked crss token amount per each user
     * @param _user Address of depositor
     * @return uint256 The unlocked token amount
     */
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