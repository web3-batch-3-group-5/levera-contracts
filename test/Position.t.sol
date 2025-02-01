// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {LendingPosition} from "../src/LendingPosition.sol";
import {LendingPool} from "../src/LendingPool.sol";
import {MockUSDC} from "../src/mocks/MockUSDC.sol";
import {MockWBTC} from "../src/mocks/MockWBTC.sol";

contract PositionTest is Test {
    MockUSDC public mockUSDC;
    MockWBTC public mockWBTC;
    LendingPool public lendingPool;
    LendingPosition public lendingPosition;

    address alice = makeAddr("alice");
    address bob = makeAddr("bob");
    uint256 amount = 1_000e6;

    function setUp() public {
        mockUSDC = new MockUSDC();
        mockWBTC = new MockWBTC();
        lendingPool = new LendingPool(mockUSDC, mockWBTC);
        lendingPosition = new LendingPosition(address(lendingPool));

        // Mint some USDC for Alice and Bob
        mockUSDC.mint(address(alice), 100_000e6);
        mockUSDC.mint(address(bob), 100_000e6);

        // Ensure Alice and Bob have tokens
        deal(address(mockUSDC), alice, 100_000e6);
        deal(address(mockUSDC), bob, 100_000e6);
    }

    function test_createPosition() public {
        // Alice creates a position
        vm.startPrank(alice);
        lendingPosition.createPosition();
        vm.stopPrank();

        // Ensure Alice now has an active position
        (uint256 collateralAmountAfter, uint256 borrowedAmountAfter, uint256 timestampAfter, bool isActiveAfter) =
            lendingPosition.userPositions(alice);

        console.log("Alice`s Position active status", isActiveAfter);
        assertEq(isActiveAfter, true, "Alice should have an active position after creating one");

        // Check position's collateralAmount and borrowedAmount should be 0
        assertEq(collateralAmountAfter, 0, "Collateral amount should be 0 initially");
        assertEq(borrowedAmountAfter, 0, "Borrowed amount should be 0 initially");

        // Ensure that the timestamp is set (this test depends on the block.timestamp)
        assertGt(timestampAfter, 0, "Timestamp should be greater than 0");
    }

    function test_supplyCollateralByPosition() public {
        uint256 collateralAmount = 1_00e6;

        // Ensure Alice has enough balance
        deal(address(mockUSDC), alice, 100_000e6);
    }
}
