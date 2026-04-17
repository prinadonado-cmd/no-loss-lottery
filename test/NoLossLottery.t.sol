// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";

import "../src/TestToken.sol";
import "../src/MockYieldVault.sol";
import "../src/YieldAdapter.sol";
import "../src/NoLossLottery.sol";

contract NoLossLotteryTest is Test {
    address internal owner = address(this);
    address internal alice = address(0xA11CE);
    address internal bob = address(0xB0B);
    address internal carol = address(0xCA01);

    TestToken internal token;
    MockYieldVault internal vault;
    YieldAdapter internal adapter;
    NoLossLottery internal lottery;

    uint256 internal roundId;

    function setUp() public {
                token = new TestToken(owner);
        vault = new MockYieldVault(owner);
        adapter = new YieldAdapter(address(vault), owner);
        lottery = new NoLossLottery(address(adapter), owner);

        // Lottery должна владеть adapter, чтобы только она могла инвестировать/забирать
        adapter.transferOwnership(address(lottery));

        // Adapter должен владеть vault, потому что именно adapter вызывает vault.withdraw(...)
        vault.transferOwnership(address(adapter));
        
        token.mint(alice, 1_000 ether);
        token.mint(bob, 1_000 ether);
        token.mint(carol, 1_000 ether);

        roundId = lottery.createRound(
            address(token),
            block.timestamp + 1 days,
            block.timestamp + 7 days
        );
    }

    function _deposit(address user, uint256 amount) internal {
        vm.startPrank(user);
        token.approve(address(lottery), amount);
        lottery.deposit(roundId, amount);
        vm.stopPrank();
    }

    function testCreateRound() public {
        (
            address depositToken,
            uint256 depositDeadline,
            uint256 roundEnd,
            uint256 totalDeposited,
            uint256 finalAmount,
            uint256 yieldAmount,
            address winner,
            bool invested,
            bool finalized
        ) = lottery.rounds(roundId);

        assertEq(depositToken, address(token));
        assertGt(depositDeadline, block.timestamp);
        assertGt(roundEnd, depositDeadline);
        assertEq(totalDeposited, 0);
        assertEq(finalAmount, 0);
        assertEq(yieldAmount, 0);
        assertEq(winner, address(0));
        assertFalse(invested);
        assertFalse(finalized);
    }

    function testDepositSingleUser() public {
        _deposit(alice, 100 ether);

        (uint256 amount, bool withdrawn, bool exists) = lottery.userInfo(roundId, alice);
        assertEq(amount, 100 ether);
        assertFalse(withdrawn);
        assertTrue(exists);

        (
            ,
            ,
            ,
            uint256 totalDeposited,
            ,
            ,
            ,
            ,
            
        ) = lottery.rounds(roundId);

        assertEq(totalDeposited, 100 ether);
    }

    function testDepositMultipleTimesSameUser() public {
        _deposit(alice, 100 ether);
        _deposit(alice, 50 ether);

        (uint256 amount, , ) = lottery.userInfo(roundId, alice);
        assertEq(amount, 150 ether);

        (
            ,
            ,
            ,
            uint256 totalDeposited,
            ,
            ,
            ,
            ,
            
        ) = lottery.rounds(roundId);

        assertEq(totalDeposited, 150 ether);
    }

    function testDepositMultipleUsers() public {
        _deposit(alice, 100 ether);
        _deposit(bob, 200 ether);
        _deposit(carol, 700 ether);

        (
            ,
            ,
            ,
            uint256 totalDeposited,
            ,
            ,
            ,
            ,
            
        ) = lottery.rounds(roundId);

        assertEq(totalDeposited, 1_000 ether);

        address[] memory users = lottery.getParticipants(roundId);
        assertEq(users.length, 3);
    }

    function testCannotDepositAfterDeadline() public {
        vm.warp(block.timestamp + 1 days + 1);

        vm.startPrank(alice);
        token.approve(address(lottery), 100 ether);
        vm.expectRevert(NoLossLottery.DepositWindowClosed.selector);
        lottery.deposit(roundId, 100 ether);
        vm.stopPrank();
    }

    function testInvestRound() public {
        _deposit(alice, 100 ether);
        _deposit(bob, 200 ether);

        vm.warp(block.timestamp + 1 days + 1);

        lottery.investRound(roundId);

        (
            ,
            ,
            ,
            uint256 totalDeposited,
            ,
            ,
            ,
            bool invested,
            
        ) = lottery.rounds(roundId);

        assertEq(totalDeposited, 300 ether);
        assertTrue(invested);

        assertEq(token.balanceOf(address(vault)), 300 ether);
    }

    function testFinalizeRoundAndYield() public {
        _deposit(alice, 100 ether);
        _deposit(bob, 200 ether);

        vm.warp(block.timestamp + 1 days + 1);
        lottery.investRound(roundId);

        token.mint(owner, 30 ether);
        token.approve(address(vault), 30 ether);
        vault.addYield(address(token), 30 ether);

        vm.warp(block.timestamp + 7 days + 1);
        lottery.finalizeRound(roundId);

        (
            ,
            ,
            ,
            uint256 totalDeposited,
            uint256 finalAmount,
            uint256 yieldAmount,
            address winner,
            ,
            bool finalized
        ) = lottery.rounds(roundId);

        assertEq(totalDeposited, 300 ether);
        assertEq(finalAmount, 330 ether);
        assertEq(yieldAmount, 30 ether);
        assertTrue(winner == alice || winner == bob);
        assertTrue(finalized);
    }

    function testWithdrawForRegularUser() public {
        _deposit(alice, 100 ether);
        _deposit(bob, 200 ether);

        vm.warp(block.timestamp + 1 days + 1);
        lottery.investRound(roundId);

        token.mint(owner, 30 ether);
        token.approve(address(vault), 30 ether);
        vault.addYield(address(token), 30 ether);

        vm.warp(block.timestamp + 7 days + 1);
        lottery.finalizeRound(roundId);

        (
             ,
            ,
            ,
            ,
            ,
            ,
            address winner,
             ,
    
        ) = lottery.rounds(roundId);

        address regularUser = winner == alice ? bob : alice;
        uint256 principal = winner == alice ? 200 ether : 100 ether;

        uint256 balanceBefore = token.balanceOf(regularUser);

        vm.prank(regularUser);
        lottery.withdraw(roundId);

        uint256 balanceAfter = token.balanceOf(regularUser);
        assertEq(balanceAfter - balanceBefore, principal);
    }

    function testWithdrawForWinnerGetsYield() public {
        _deposit(alice, 100 ether);
        _deposit(bob, 200 ether);

        vm.warp(block.timestamp + 1 days + 1);
        lottery.investRound(roundId);

        token.mint(owner, 30 ether);
        token.approve(address(vault), 30 ether);
        vault.addYield(address(token), 30 ether);

        vm.warp(block.timestamp + 7 days + 1);
        lottery.finalizeRound(roundId);

        (
            ,
            ,
            ,
            ,
            ,
            uint256 yieldAmount,
            address winner,
            ,
            
        ) = lottery.rounds(roundId);

                (uint256 winnerDeposit, , ) = lottery.userInfo(roundId, winner);
        uint256 balanceBefore = token.balanceOf(winner);

        vm.prank(winner);
        lottery.withdraw(roundId);

        uint256 balanceAfter = token.balanceOf(winner);
        assertEq(balanceAfter - balanceBefore, winnerDeposit + yieldAmount);
    }

    function testCannotWithdrawTwice() public {
        _deposit(alice, 100 ether);

        vm.warp(block.timestamp + 1 days + 1);
        lottery.investRound(roundId);

        vm.warp(block.timestamp + 7 days + 1);
        lottery.finalizeRound(roundId);

        vm.prank(alice);
        lottery.withdraw(roundId);

        vm.prank(alice);
        vm.expectRevert(NoLossLottery.AlreadyWithdrawn.selector);
        lottery.withdraw(roundId);
    }
}