// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {LendingPool} from "../src/LendingPool.sol";
import {MockUSDC} from "../src/mocks/MockUSDC.sol";
import {MockWBTC} from "../src/mocks/MockWBTC.sol";

contract LendingPoolTest is Test {
    MockUSDC public mockUSDC;
    MockWBTC public mockWBTC;
    LendingPool public lendingPool;

    address alice = makeAddr("alice");
    address bob = makeAddr("bob");

    function setUp() public {
        mockUSDC = new MockUSDC();
        mockWBTC = new MockWBTC();
        lendingPool = new LendingPool(mockUSDC, mockWBTC);

        mockUSDC.mint(address(alice), 100_000e6);
        mockWBTC.mint(address(alice), 1000);

        deal(address(mockUSDC), alice, 100_000e6);
        deal(address(mockWBTC), alice, 1000);
    }

    function test_supply() public {
        uint256 initialDeposit = 100_000e6;
        uint256 borrowAmount = 100e6;

        // Alice deposit
        vm.startPrank(alice);
        IERC20(mockUSDC).approve(address(lendingPool), initialDeposit);

        // Alice supply to lending pool
        lendingPool.supply(initialDeposit);
        vm.stopPrank();

        // Verify Alice's balance in LendingPool
        uint256 aliceShares = lendingPool.userSupplyShares(alice);
        assertEq(aliceShares, initialDeposit, "Alice should receive correct shares");

        // Verify LendingPool's totalSupplyAssets
        assertEq(lendingPool.totalSupplyAssets(), initialDeposit, "Total supply should update");

        // Ensure LendingPool received USDC
        assertEq(IERC20(mockUSDC).balanceOf(address(lendingPool)), initialDeposit, "LendingPool should receive USDC");

        // Check Alice's USDC balance (should decrease)
        uint256 aliceBalanceAfter = IERC20(mockUSDC).balanceOf(alice);
        assertEq(aliceBalanceAfter, 0, "Alice should have no USDC left after supplying");

        // Bob Borrow
        vm.startPrank(bob);
        lendingPool.borrow(borrowAmount);
        vm.stopPrank();

        console.log("totalSupplyAssets =", lendingPool.totalSupplyAssets());
        console.log("Alice userSupplyShares =", lendingPool.userSupplyShares(alice));

        vm.warp(block.timestamp + 1 days);

        lendingPool.accrueInterest();

        console.log("totalSupplyAssets setelah 1 hari =", lendingPool.totalSupplyAssets());
        console.log("totalBorrowAssets setelah 1 hari =", lendingPool.totalBorrowAssets());
    }
}
