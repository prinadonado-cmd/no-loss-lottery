// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IYieldAdapter {
    function depositToVault(address token, uint256 amount) external;
    function withdrawFromVault(address token, uint256 amount) external;
    function totalAssets(address token) external view returns (uint256);
}

contract NoLossLottery is Ownable, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    error ZeroAddress();
    error ZeroAmount();
    error InvalidRound();
    error InvalidTimestamps();
    error DepositWindowClosed();
    error DepositWindowStillOpen();
    error RoundAlreadyInvested();
    error RoundNotInvested();
    error RoundAlreadyFinalized();
    error RoundNotFinished();
    error NoDeposit();
    error AlreadyWithdrawn();
    error EmptyRound();
    error NothingToWithdraw();

    struct Round {
        address depositToken;
        uint256 depositDeadline;
        uint256 roundEnd;
        uint256 totalDeposited;
        uint256 finalAmount;
        uint256 yieldAmount;
        address winner;
        bool invested;
        bool finalized;
    }

    struct UserInfo {
        uint256 amount;
        bool withdrawn;
        bool exists;
    }

    IYieldAdapter public immutable adapter;
    uint256 public nextRoundId;

    mapping(uint256 => Round) public rounds;
    mapping(uint256 => mapping(address => UserInfo)) public userInfo;
    mapping(uint256 => address[]) public participants;

    event RoundCreated(
        uint256 indexed roundId,
        address indexed token,
        uint256 depositDeadline,
        uint256 roundEnd
    );
    event Deposited(uint256 indexed roundId, address indexed user, uint256 amount);
    event Invested(uint256 indexed roundId, uint256 amount);
    event RoundFinalized(
        uint256 indexed roundId,
        address indexed winner,
        uint256 yieldAmount
    );
    event Withdrawn(uint256 indexed roundId, address indexed user, uint256 amount);

    constructor(address adapterAddress, address initialOwner) Ownable(initialOwner) {
        if (adapterAddress == address(0)) revert ZeroAddress();
        adapter = IYieldAdapter(adapterAddress);
    }

    function createRound(
        address token,
        uint256 depositDeadline,
        uint256 roundEnd
    ) external onlyOwner whenNotPaused returns (uint256 roundId) {
        if (token == address(0)) revert ZeroAddress();
        if (depositDeadline <= block.timestamp || roundEnd <= depositDeadline) {
            revert InvalidTimestamps();
        }

        roundId = nextRoundId;
        nextRoundId++;

        rounds[roundId] = Round({
            depositToken: token,
            depositDeadline: depositDeadline,
            roundEnd: roundEnd,
            totalDeposited: 0,
            finalAmount: 0,
            yieldAmount: 0,
            winner: address(0),
            invested: false,
            finalized: false
        });

        emit RoundCreated(roundId, token, depositDeadline, roundEnd);
    }

    function deposit(uint256 roundId, uint256 amount)
        external
        whenNotPaused
        nonReentrant
    {
        if (amount == 0) revert ZeroAmount();

        Round storage round = rounds[roundId];
        if (round.depositToken == address(0)) revert InvalidRound();
        if (block.timestamp >= round.depositDeadline) revert DepositWindowClosed();
        if (round.invested || round.finalized) revert DepositWindowClosed();

        IERC20(round.depositToken).safeTransferFrom(msg.sender, address(this), amount);

        UserInfo storage user = userInfo[roundId][msg.sender];
        if (!user.exists) {
            user.exists = true;
            participants[roundId].push(msg.sender);
        }

        user.amount += amount;
        round.totalDeposited += amount;

        emit Deposited(roundId, msg.sender, amount);
    }

    function investRound(uint256 roundId)
        external
        onlyOwner
        whenNotPaused
        nonReentrant
    {
        Round storage round = rounds[roundId];
        if (round.depositToken == address(0)) revert InvalidRound();
        if (block.timestamp < round.depositDeadline) revert DepositWindowStillOpen();
        if (round.invested) revert RoundAlreadyInvested();
        if (round.finalized) revert RoundAlreadyFinalized();
        if (round.totalDeposited == 0) revert EmptyRound();

        IERC20(round.depositToken).forceApprove(address(adapter), round.totalDeposited);
        adapter.depositToVault(round.depositToken, round.totalDeposited);

        round.invested = true;

        emit Invested(roundId, round.totalDeposited);
    }

    function finalizeRound(uint256 roundId)
        external
        onlyOwner
        whenNotPaused
        nonReentrant
    {
        Round storage round = rounds[roundId];
        if (round.depositToken == address(0)) revert InvalidRound();
        if (!round.invested) revert RoundNotInvested();
        if (round.finalized) revert RoundAlreadyFinalized();
        if (block.timestamp < round.roundEnd) revert RoundNotFinished();

        uint256 assetsInVault = adapter.totalAssets(round.depositToken);
        adapter.withdrawFromVault(round.depositToken, assetsInVault);

        round.finalAmount = IERC20(round.depositToken).balanceOf(address(this));

        if (round.finalAmount > round.totalDeposited) {
            round.yieldAmount = round.finalAmount - round.totalDeposited;
        } else {
            round.yieldAmount = 0;
        }

        round.winner = _selectWinner(roundId);
        round.finalized = true;

        emit RoundFinalized(roundId, round.winner, round.yieldAmount);
    }

    function withdraw(uint256 roundId)
        external
        whenNotPaused
        nonReentrant
    {
        Round storage round = rounds[roundId];
        if (round.depositToken == address(0)) revert InvalidRound();
        if (!round.finalized) revert RoundNotFinished();

        UserInfo storage user = userInfo[roundId][msg.sender];
        if (user.amount == 0) revert NoDeposit();
        if (user.withdrawn) revert AlreadyWithdrawn();

        uint256 payout = user.amount;

        if (msg.sender == round.winner && round.yieldAmount > 0) {
            payout += round.yieldAmount;
        }

        if (payout == 0) revert NothingToWithdraw();

        user.withdrawn = true;
        IERC20(round.depositToken).safeTransfer(msg.sender, payout);

        emit Withdrawn(roundId, msg.sender, payout);
    }

    function getParticipants(uint256 roundId) external view returns (address[] memory) {
        return participants[roundId];
    }

    function getRoundStatus(uint256 roundId) external view returns (string memory) {
        Round storage round = rounds[roundId];
        if (round.depositToken == address(0)) revert InvalidRound();

        if (round.finalized) {
            return "Finalized";
        }
        if (round.invested) {
            return "Invested";
        }
        return "DepositOpen";
    }

    function _selectWinner(uint256 roundId) internal view returns (address) {
        Round storage round = rounds[roundId];
        address[] storage users = participants[roundId];

        if (users.length == 0) revert EmptyRound();

        uint256 rand = uint256(
            keccak256(
                abi.encodePacked(
                    block.prevrandao,
                    block.timestamp,
                    roundId,
                    round.totalDeposited
                )
            )
        ) % round.totalDeposited;

        uint256 cumulative = 0;

        for (uint256 i = 0; i < users.length; i++) {
            cumulative += userInfo[roundId][users[i]].amount;
            if (rand < cumulative) {
                return users[i];
            }
        }

        return users[users.length - 1];
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }
}