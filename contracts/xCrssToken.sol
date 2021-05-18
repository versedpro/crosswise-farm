// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "./libs/BEP20UpgradeSafe.sol";
import "./libs/ITokenLocker.sol";
import "./libs/IBEP20.sol";
import "./libs/SafeBEP20.sol";

import "@openzeppelin/contracts/math/SafeMath.sol";

contract xCRSS is BEP20UpgradeSafe, ITokenLocker {
    using SafeBEP20 for IBEP20;
    using SafeMath for uint256;

    uint256 public constant BLOCKS_PER_WEEK = 201600;

    address public governance;

    address public CRSS = address(0x7E0F01918D92b2750bbb18fcebeEDD5B94ebB867);

    uint256 private _startReleaseBlock;
    uint256 private _endReleaseBlock;

    uint256 private _totalLock;
    uint256 private _totalReleased;
    mapping(address => uint256) private _locks;
    mapping(address => uint256) private _released;

    event Lock(address indexed to, uint256 value);
    event UnLock(address indexed account, uint256 value);
    event EditLocker(uint256 indexed _startReleaseBlock, uint256 _endReleaseBlock);

    function initialize(
        address _CRSS,
        uint256 startReleaseBlock_,
        uint256 endReleaseBlock_
    ) public initializer {
        __BEP20_init("Locked Crosswise Token", "xCRSS");
        require(endReleaseBlock_ > startReleaseBlock_, "xCRSS: endReleaseBlock_ is before startReleaseBlock_");
        CRSS = _CRSS;
        _startReleaseBlock = startReleaseBlock_;
        _endReleaseBlock = endReleaseBlock_;
        governance = msg.sender;
        emit EditLocker(startReleaseBlock_, endReleaseBlock_);
    }

    modifier onlyGovernance() {
        require(msg.sender == governance, "xCRSS: !governance");
        _;
    }

    function setGovernance(address _governance) external onlyGovernance {
        governance = _governance;
    }

    function editLocker(uint256 startReleaseBlock_, uint256 endReleaseBlock_) external onlyGovernance {
        require(_startReleaseBlock > block.number && startReleaseBlock_ > block.number, "xCRSS: late");
        require(endReleaseBlock_ > startReleaseBlock_ && endReleaseBlock_ <= startReleaseBlock_.add(BLOCKS_PER_WEEK * 80), "xCRSS: invalid _endReleaseBlock");
        _startReleaseBlock = startReleaseBlock_;
        _endReleaseBlock = endReleaseBlock_;
        emit EditLocker(startReleaseBlock_, endReleaseBlock_);
    }

    function startReleaseBlock() external view override returns (uint256) {
        return _startReleaseBlock;
    }

    function endReleaseBlock() external view override returns (uint256) {
        return _endReleaseBlock;
    }

    function totalLock() external view override returns (uint256) {
        return _totalLock;
    }

    function totalReleased() external view override returns (uint256) {
        return _totalReleased;
    }

    function lockOf(address _account) external view override returns (uint256) {
        return _locks[_account];
    }

    function released(address _account) external view override returns (uint256) {
        return _released[_account];
    }

    function burn(uint256 _amount) public {
        _burn(msg.sender, _amount);
    }

    function lock(address _account, uint256 _amount) external override {
        require(block.number <= _endReleaseBlock, "xCRSS: no more lock");
        require(_account != address(0), "xCRSS: no lock to address(0)");
        require(_amount > 0, "xCRSS: zero lock");

        IBEP20(CRSS).safeTransferFrom(msg.sender, address(this), _amount);
        _mint(_account, _amount);
        _totalLock = _totalLock.add(_amount);
        emit Lock(_account, _amount);
    }

    function unlock(uint256 _amount) public override {
        require(block.number > _startReleaseBlock, "xCRSS: still locked");

        burn(_amount);

        _locks[msg.sender] = _locks[msg.sender].add(_amount);
        claimUnlocked();
        emit UnLock(msg.sender, _amount);
    }

    function unlockAll() external override {
        unlock(super.balanceOf(msg.sender));
    }

    function canUnlockAmount(address _account) public view override returns (uint256) {
        if (block.number < _startReleaseBlock) {
            return 0;
        } else if (block.number >= _endReleaseBlock) {
            return _locks[_account].sub(_released[_account]);
        } else {
            uint256 _releasedBlock = block.number.sub(_startReleaseBlock);
            uint256 _totalVestingBlock = _endReleaseBlock.sub(_startReleaseBlock);
            return _locks[_account].mul(_releasedBlock).div(_totalVestingBlock).sub(_released[_account]);
        }
    }

    function claimUnlocked() public override {
        require(block.number > _startReleaseBlock, "xCRSS: still locked");
        require(_locks[msg.sender] > _released[msg.sender], "xCRSS: no locked");

        uint256 _amount = canUnlockAmount(msg.sender);
        IBEP20(CRSS).safeTransfer(msg.sender, _amount);

        _released[msg.sender] = _released[msg.sender].add(_amount);
        _totalReleased = _totalReleased.add(_amount);
        _totalLock = _totalLock.sub(_amount);
    }

    // This function allows governance to take unsupported tokens out of the contract. This is in an effort to make someone whole, should they seriously mess up.
    // There is no guarantee governance will vote to return these. It also allows for removal of airdropped tokens.
    function governanceRecoverUnsupported(
        address _token,
        address _to,
        uint256 _amount
    ) external onlyGovernance {
        require(_token != CRSS || IBEP20(CRSS).balanceOf(address(this)).sub(_amount) >= _totalLock, "xCRSS: Not enough locked amount left");
        IBEP20(_token).safeTransfer(_to, _amount);
    }
}   