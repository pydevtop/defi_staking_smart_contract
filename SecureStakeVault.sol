// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;


interface IERC20Metadata {
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
    function totalSupply() external view returns (uint256);
    function balanceOf(address owner) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);

    function approve(address spender, uint256 value) external returns (bool);
    function transfer(address to, uint256 value) external returns (bool);
    function transferFrom(address from, address to, uint256 value) external returns (bool);
}

library SafeERC20 {
    function safeTransfer(IERC20Metadata token, address to, uint256 value) internal {
        (bool success, bytes memory data) =
            address(token).call(abi.encodeWithSelector(token.transfer.selector, to, value));

        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            "SafeERC20: transfer failed"
        );
    }

    function safeTransferFrom(IERC20Metadata token, address from, address to, uint256 value) internal {
        (bool success, bytes memory data) =
            address(token).call(abi.encodeWithSelector(token.transferFrom.selector, from, to, value));

        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            "SafeERC20: transferFrom failed"
        );
    }
}

contract SecureStakeVault {
    using SafeERC20 for IERC20Metadata;

    IERC20Metadata public immutable stakeToken;
    IERC20Metadata public immutable rewardToken;

    address payable public owner;
    address payable public pendingOwner;

    uint8 public immutable stakeTokenDecimals;
    uint8 public immutable rewardTokenDecimals;

    uint256 public maxStakeableToken;
    uint256 public minimumStakeToken;

    uint256 public totalUnStakedToken;
    uint256 public totalStakedToken;
    uint256 public totalActiveStakedToken;
    uint256 public totalClaimedRewardToken;
    uint256 public totalStakers;
    uint256 public totalReservedRewards;

    uint256 public constant PERCENT_DIVIDER = 10_000;
    uint256 public constant YEAR = 365 days;
    uint256 public constant MAX_DURATION = 365 days;
    uint256 public constant MAX_PENALTY_BPS = 3_000; // 30%

    uint256 public penaltyBps;

    uint256[4] public Duration = [30 days, 90 days, 180 days, 365 days];

    // APY in basis points:
    // 600 = 6%, 1300 = 13%, 2000 = 20%, 4500 = 45%
    uint256[4] public RewardApyBps = [600, 1300, 2000, 4500];

    struct Stake {
        uint256 unstaketime;
        uint256 staketime;
        uint256 amount;
        uint256 rewardTokenAmount;
        uint256 reward;
        uint256 lastharvesttime;
        uint256 remainingreward;
        uint256 harvestreward;
        uint256 persecondreward;
        uint256 penaltyamount;
        bool withdrawan;
        bool unstaked;
    }

    struct User {
        uint256 totalStakedTokenUser;
        uint256 totalUnstakedTokenUser;
        uint256 totalClaimedRewardTokenUser;
        uint256 stakeCount;
        bool alreadyExists;
    }

    mapping(address => User) public Stakers;
    mapping(uint256 => address) public StakersID;
    mapping(address => mapping(uint256 => Stake)) public stakersRecord;

    bool private locked;

    event OwnershipTransferStarted(address indexed oldOwner, address indexed newOwner);
    event OwnershipTransferred(address indexed oldOwner, address indexed newOwner);

    event StakeCreated(address indexed staker, uint256 indexed index, uint256 amount, uint256 reward);
    event Harvest(address indexed staker, uint256 indexed index, uint256 amount);
    event Unstake(address indexed staker, uint256 indexed index, uint256 amount);
    event EmergencyUnstake(address indexed staker, uint256 indexed index, uint256 returnedAmount, uint256 penaltyAmount);

    event StakeLimitsUpdated(uint256 minimumStakeToken, uint256 maxStakeableToken);
    event StakeDurationUpdated(uint256[4] duration);
    event RewardApyUpdated(uint256[4] rewardApyBps);
    event PenaltyUpdated(uint256 penaltyBps);

    modifier onlyOwner() {
        require(msg.sender == owner, "only owner");
        _;
    }

    modifier nonReentrant() {
        require(!locked, "reentrancy");
        locked = true;
        _;
        locked = false;
    }

    constructor(
        address payable _owner,
        address _stakeToken,
        address _rewardToken,
        uint256 _minimumStakeToken,
        uint256 _maxStakeableToken
    ) {
        require(_owner != address(0), "zero owner");
        require(_stakeToken != address(0), "zero stake token");
        require(_rewardToken != address(0), "zero reward token");

        owner = _owner;
        stakeToken = IERC20Metadata(_stakeToken);
        rewardToken = IERC20Metadata(_rewardToken);

        stakeTokenDecimals = IERC20Metadata(_stakeToken).decimals();
        rewardTokenDecimals = IERC20Metadata(_rewardToken).decimals();

        minimumStakeToken = _minimumStakeToken;
        maxStakeableToken = _maxStakeableToken;
        penaltyBps = 1_000; // 10%
    }

    function stake(uint256 amount, uint256 timeperiod) external nonReentrant {
        require(timeperiod <= 3, "invalid time period");
        require(amount >= minimumStakeToken, "stake more than minimum amount");
        require(
            maxStakeableToken == 0 || totalActiveStakedToken + amount <= maxStakeableToken,
            "max stake limit reached"
        );

        uint256 index = Stakers[msg.sender].stakeCount;
        uint256 reward = _calculateReward(amount, timeperiod);
        require(reward > 0, "reward too small");

        uint256 availableRewards = rewardToken.balanceOf(address(this)) - totalReservedRewards;
        require(availableRewards >= reward, "insufficient reward reserve");

        if (!Stakers[msg.sender].alreadyExists) {
            Stakers[msg.sender].alreadyExists = true;
            StakersID[totalStakers] = msg.sender;
            totalStakers++;
        }

        stakeToken.safeTransferFrom(msg.sender, address(this), amount);

        uint256 start = block.timestamp;
        uint256 finish = start + Duration[timeperiod];

        Stakers[msg.sender].totalStakedTokenUser += amount;
        Stakers[msg.sender].stakeCount++;

        totalStakedToken += amount;
        totalActiveStakedToken += amount;
        totalReservedRewards += reward;

        Stake storage rec = stakersRecord[msg.sender][index];
        rec.unstaketime = finish;
        rec.staketime = start;
        rec.amount = amount;
        rec.rewardTokenAmount = _convertStakeToRewardUnits(amount);
        rec.reward = reward;
        rec.lastharvesttime = start;
        rec.remainingreward = reward;
        rec.harvestreward = 0;
        rec.persecondreward = reward / Duration[timeperiod];

        emit StakeCreated(msg.sender, index, amount, reward);
    }

    function harvest(uint256 index) public nonReentrant {
        _harvest(msg.sender, index);
    }

    function unstake(uint256 index) external nonReentrant {
        Stake storage rec = stakersRecord[msg.sender][index];

        require(!rec.unstaked, "already unstaked");
        require(rec.amount > 0, "stake not found");
        require(block.timestamp >= rec.unstaketime, "cannot unstake before lock duration");

        if (!rec.withdrawan) {
            _harvest(msg.sender, index);
        }

        rec.unstaked = true;

        totalActiveStakedToken -= rec.amount;
        totalUnStakedToken += rec.amount;
        Stakers[msg.sender].totalUnstakedTokenUser += rec.amount;

        stakeToken.safeTransfer(msg.sender, rec.amount);

        emit Unstake(msg.sender, index, rec.amount);
    }

    function emergencyUnstake(uint256 index) external nonReentrant {
        Stake storage rec = stakersRecord[msg.sender][index];

        require(!rec.unstaked, "already unstaked");
        require(rec.amount > 0, "stake not found");

        rec.unstaked = true;
        rec.withdrawan = true;

        uint256 penaltyAmount = (rec.amount * penaltyBps) / PERCENT_DIVIDER;
        uint256 returnedAmount = rec.amount - penaltyAmount;

        if (rec.remainingreward > 0) {
            totalReservedRewards -= rec.remainingreward;
            rec.remainingreward = 0;
        }

        rec.penaltyamount = penaltyAmount;

        totalActiveStakedToken -= rec.amount;
        totalUnStakedToken += returnedAmount;
        Stakers[msg.sender].totalUnstakedTokenUser += returnedAmount;

        stakeToken.safeTransfer(msg.sender, returnedAmount);

        emit EmergencyUnstake(msg.sender, index, returnedAmount, penaltyAmount);
    }

    function realtimeRewardPerBlock(address user, uint256 index) public view returns (uint256, uint256) {
        Stake storage rec = stakersRecord[user][index];

        if (rec.withdrawan || rec.unstaked || rec.amount == 0) {
            return (0, block.timestamp);
        }

        uint256 commonTimestamp = block.timestamp;
        if (commonTimestamp > rec.unstaketime) {
            commonTimestamp = rec.unstaketime;
        }

        uint256 lastHarvest = rec.lastharvesttime;
        if (lastHarvest == 0) {
            lastHarvest = rec.staketime;
        }

        if (commonTimestamp <= lastHarvest) {
            return (0, commonTimestamp);
        }

        uint256 rewardTillNow = (commonTimestamp - lastHarvest) * rec.persecondreward;
        if (rewardTillNow > rec.remainingreward) {
            rewardTillNow = rec.remainingreward;
        }

        return (rewardTillNow, commonTimestamp);
    }

    function _harvest(address user, uint256 index) internal {
        Stake storage rec = stakersRecord[user][index];

        require(!rec.withdrawan, "already withdrawn");
        require(!rec.unstaked, "already unstaked");
        require(rec.amount > 0, "stake not found");

        (uint256 rewardTillNow, uint256 commonTimestamp) = realtimeRewardPerBlock(user, index);
        require(rewardTillNow > 0, "nothing to harvest");

        rec.lastharvesttime = commonTimestamp;
        rec.remainingreward -= rewardTillNow;
        rec.harvestreward += rewardTillNow;

        totalReservedRewards -= rewardTillNow;
        totalClaimedRewardToken += rewardTillNow;
        Stakers[user].totalClaimedRewardTokenUser += rewardTillNow;

        if (rec.remainingreward == 0) {
            rec.withdrawan = true;
        }

        rewardToken.safeTransfer(user, rewardTillNow);

        emit Harvest(user, index, rewardTillNow);
    }

    function _calculateReward(uint256 amount, uint256 timeperiod) internal view returns (uint256) {
        uint256 rewardBase = _convertStakeToRewardUnits(amount);
        return (rewardBase * RewardApyBps[timeperiod] * Duration[timeperiod]) / (PERCENT_DIVIDER * YEAR);
    }

    function _convertStakeToRewardUnits(uint256 amount) internal view returns (uint256) {
        if (rewardTokenDecimals == stakeTokenDecimals) {
            return amount;
        }

        if (rewardTokenDecimals > stakeTokenDecimals) {
            return amount * (10 ** (rewardTokenDecimals - stakeTokenDecimals));
        }

        return amount / (10 ** (stakeTokenDecimals - rewardTokenDecimals));
    }

    function getUserStakeCount(address user) external view returns (uint256) {
        return Stakers[user].stakeCount;
    }

    function getRewardBalance() external view returns (uint256 balance, uint256 reserved, uint256 available) {
        balance = rewardToken.balanceOf(address(this));
        reserved = totalReservedRewards;
        available = balance > reserved ? balance - reserved : 0;
    }

    function startOwnershipTransfer(address payable newOwner) external onlyOwner {
        require(newOwner != address(0), "zero new owner");
        pendingOwner = newOwner;
        emit OwnershipTransferStarted(owner, newOwner);
    }

    function acceptOwnership() external {
        require(msg.sender == pendingOwner, "not pending owner");
        address oldOwner = owner;
        owner = pendingOwner;
        pendingOwner = payable(address(0));
        emit OwnershipTransferred(oldOwner, owner);
    }

    function setStakeLimits(uint256 _min, uint256 _max) external onlyOwner {
        require(_max == 0 || _max >= totalActiveStakedToken, "max below active stake");
        minimumStakeToken = _min;
        maxStakeableToken = _max;
        emit StakeLimitsUpdated(_min, _max);
    }

    function setStakeDuration(
        uint256 first,
        uint256 second,
        uint256 third,
        uint256 fourth
    ) external onlyOwner {
        require(first > 0 && second > 0 && third > 0 && fourth > 0, "zero duration");
        require(first <= second && second <= third && third <= fourth, "invalid duration order");
        require(fourth <= MAX_DURATION, "duration too high");

        Duration[0] = first;
        Duration[1] = second;
        Duration[2] = third;
        Duration[3] = fourth;

        emit StakeDurationUpdated(Duration);
    }

    function setRewardApyBps(
        uint256 first,
        uint256 second,
        uint256 third,
        uint256 fourth
    ) external onlyOwner {
        require(first <= 20_000 && second <= 20_000 && third <= 20_000 && fourth <= 20_000, "apy too high");
        RewardApyBps[0] = first;
        RewardApyBps[1] = second;
        RewardApyBps[2] = third;
        RewardApyBps[3] = fourth;
        emit RewardApyUpdated(RewardApyBps);
    }

    function setPenaltyBps(uint256 newPenaltyBps) external onlyOwner {
        require(newPenaltyBps <= MAX_PENALTY_BPS, "penalty too high");
        penaltyBps = newPenaltyBps;
        emit PenaltyUpdated(newPenaltyBps);
    }

    function withdrawBNB() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "no BNB balance");

        (bool success, ) = owner.call{value: balance}("");
        require(success, "BNB transfer failed");
    }

    function withdrawUnrelatedToken(address token, uint256 amount) external onlyOwner {
        require(token != address(stakeToken), "cannot withdraw stake token");
        require(token != address(rewardToken), "cannot withdraw reward token");
        IERC20Metadata(token).safeTransfer(owner, amount);
    }

    function withdrawExcessRewardToken(uint256 amount) external onlyOwner {
        uint256 balance = rewardToken.balanceOf(address(this));
        require(balance > totalReservedRewards, "no excess rewards");

        uint256 excess = balance - totalReservedRewards;
        require(amount <= excess, "amount exceeds excess");

        rewardToken.safeTransfer(owner, amount);
    }

    receive() external payable {}
}
