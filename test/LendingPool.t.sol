// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
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
    }

    function test_supply() public {
        // deposit
        vm.startPrank(alice);
        IERC20(mockUSDC).approve(address(lendingPool), 1000e6);
        lendingPool.supply(1000e6);
        vm.stopPrank();

        vm.startPrank(bob);
        lendingPool.borrow(100e6);
        vm.stopPrank();

        console.log("totalSupplyAssets =", lendingPool.totalSupplyAssets());
        console.log("Alice userSupplyShares =", lendingPool.userSupplyShares(alice));

        vm.warp(block.timestamp + 1 days);

        lendingPool.accrueInterest();

        console.log("totalSupplyAssets setelah 1 hari =", lendingPool.totalSupplyAssets());
        console.log("totalBorrowAssets setelah 1 hari =", lendingPool.totalBorrowAssets());
    }
}
