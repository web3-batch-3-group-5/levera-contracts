// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {MockV3Aggregator} from "@chainlink/contracts/v0.8/tests/MockV3Aggregator.sol";
import {MockFactory} from "../src/mocks/MockFactory.sol";
import {LendingPoolFactory} from "../src/LendingPoolFactory.sol";
import {LendingPool} from "../src/LendingPool.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";
import {MockUniswapRouter} from "../src/mocks/MockUniswapRouter.sol";
import {ILendingPool, PositionType} from "../src/interfaces/ILendingPool.sol";
import {IPosition} from "../src/interfaces/IPosition.sol";
import {Vault} from "../src/Vault.sol";

contract LendingPoolTest is Test {
    MockERC20 public mockUSDC;
    MockERC20 public mockWBTC;
    address public usdcUsdPriceFeed;
    address public wbtcUsdPriceFeed;
    LendingPool public lendingPool;
    LendingPoolFactory public lendingPoolFactory;
    MockFactory public mockFactory;
    Vault public vault;

    uint8 liquidationThresholdPercentage = 80;
    uint8 interestRate = 5;
    PositionType positionType = PositionType.LONG;

    address alice = makeAddr("alice");
    address bob = makeAddr("bob");

    function setUp() public {
        // Setup Factory
        MockUniswapRouter mockUniswapRouter = new MockUniswapRouter();
        lendingPoolFactory = new LendingPoolFactory(address(mockUniswapRouter));
        mockFactory = new MockFactory();

        // Setup WBTC - USDC lending pool
        address loanToken = mockFactory.createMockToken("usdc", "USDC", 6);
        address collateralToken = mockFactory.createMockToken("wbtc", "WBTC", 8);
        mockUSDC = MockERC20(loanToken);
        mockWBTC = MockERC20(collateralToken);
        usdcUsdPriceFeed = mockFactory.createMockAggregator("usdc", "USDC", 6, 1e6);
        wbtcUsdPriceFeed = mockFactory.createMockAggregator("wbtc", "WBTC", 8, 100_000e8);
        address lendingPoolAddress = lendingPoolFactory.createLendingPool(
            address(mockUSDC),
            address(mockWBTC),
            address(usdcUsdPriceFeed),
            address(wbtcUsdPriceFeed),
            liquidationThresholdPercentage,
            interestRate,
            positionType
        );
        lendingPool = LendingPool(lendingPoolAddress);
        vault = lendingPool.vault();

        console.log("==================DEPLOYED ADDRESSES==========================");
        console.log("Mock USDC deployed at:", address(mockUSDC));
        console.log("Mock WBTC deployed at:", address(mockWBTC));
        console.log("USDC/USD Price Feed deployed at:", address(usdcUsdPriceFeed));
        console.log("WBTC/USD Price Feed deployed at:", address(wbtcUsdPriceFeed));
        console.log("Lending Pool Factory deployed at:", address(lendingPoolFactory));
        console.log("Lending Pool deployed at:", address(lendingPool));
        console.log("Liquidation Threshold Percentage:", liquidationThresholdPercentage);
        console.log("Interest Rate Percentage:", interestRate);
        console.log("Position Type (0 = LONG, 1 = SHORT):", uint8(positionType));
        console.log("Vault deployed at:", address(vault));
        console.log("==============================================================");

        mockUSDC.mint(alice, 100_000e6);
        mockWBTC.mint(alice, 1e8);
        mockUSDC.mint(bob, 100_000e6);
        mockWBTC.mint(bob, 2e8);
        deal(address(mockUSDC), address(vault), 100e6);

        // bytes32 poolId = keccak256(abi.encode(address(mockUSDC), address(mockWBTC)));
        // address vaultAddress = lendingPoolFactory.vaults(poolId);
        // Vault vault = Vault(vaultAddress);
        // console.log("Vault Address:", vaultAddress);
        // // Impersonate Vault Owner
        // address vaultOwner = vault.owner();
        // vm.startPrank(vaultOwner);
        // vault.setLendingPool(address(lendingPool), true);
        // vm.stopPrank();

        // assertTrue(Vault != address(0), "Vault was not created!");
    }

    function supplyLiquidity(uint256 amount) internal {
        IERC20(mockUSDC).approve(address(lendingPool), amount);
        lendingPool.supply(amount);
    }

    function test_supply() public {
        uint256 initialDeposit = 100_000e6;

        bytes32 poolId = keccak256(abi.encode(address(mockUSDC), address(mockWBTC)));
        address vaultAddress = lendingPoolFactory.vaults(poolId);
        Vault vault = Vault(vaultAddress);

        console.log("Vault Address:", vaultAddress);
        console.log("Alice USDC Balance After Mint:", IERC20(mockUSDC).balanceOf(alice));

        address vaultOwner = vault.owner();
        vm.startPrank(vaultOwner);
        vault.setLendingPool(address(lendingPool), true);
        vm.stopPrank();

        // Alice supply liquidity
        vm.startPrank(alice);
        supplyLiquidity(initialDeposit);
        vm.stopPrank();

        // Verify Alice's balance in LendingPool
        uint256 aliceShares = lendingPool.userSupplyShares(alice);
        assertEq(aliceShares, initialDeposit, "Alice should receive correct shares");

        // Verify LendingPool's totalSupplyAssets
        assertEq(lendingPool.totalSupplyAssets(), initialDeposit, "Total supply should update");

        // Ensure LendingPool doesn't hold USDC directly
        assertEq(IERC20(mockUSDC).balanceOf(address(lendingPool)), 0, "LendingPool should not hold USDC directly");

        // Ensure Vault received the USDC
        assertEq(IERC20(mockUSDC).balanceOf(vaultAddress), initialDeposit, "Vault should hold the supplied USDC");

        // Check Alice's USDC balance (should decrease)
        uint256 aliceBalanceAfter = IERC20(mockUSDC).balanceOf(alice);
        assertEq(aliceBalanceAfter, 0, "Alice should have no USDC left after supplying");

        vm.warp(block.timestamp + 1 days);

        lendingPool.accrueInterest();

        console.log("totalSupplyAssets setelah 1 hari =", lendingPool.totalSupplyAssets());
        console.log("totalBorrowAssets setelah 1 hari =", lendingPool.totalBorrowAssets());

        if (lendingPool.totalBorrowAssets() > 0) {
            console.log(
                "Utilization Rate setelah 1 hari =",
                lendingPool.totalSupplyAssets() * 100 / lendingPool.totalBorrowAssets(),
                "%"
            );
        }
    }

    function test_withdraw() public {
        uint256 supplyAmount = 100_000e6;
        uint256 withdrawShares = 50_000e6;

        // Alice supplies liquidity
        vm.startPrank(alice);
        supplyLiquidity(supplyAmount);
        vm.stopPrank();

        // Check Vault USDC balance before withdraw
        address vaultAddress = lendingPoolFactory.vaults(keccak256(abi.encode(address(mockUSDC), address(mockWBTC))));
        uint256 vaultBalanceBefore = IERC20(mockUSDC).balanceOf(vaultAddress);

        // Ensure Alice's initial shares are correct
        assertEq(lendingPool.userSupplyShares(alice), supplyAmount, "Alice should have correct supply shares");

        // Alice withdraws a portion of her shares
        vm.startPrank(alice);
        lendingPool.withdraw(withdrawShares);
        vm.stopPrank();

        // Validate updated shares and balances
        assertEq(lendingPool.userSupplyShares(alice), supplyAmount - withdrawShares, "Alice's shares should decrease");
        assertEq(lendingPool.totalSupplyShares(), supplyAmount - withdrawShares, "Total shares should decrease");

        // Check that Alice received USDC
        assertEq(IERC20(mockUSDC).balanceOf(alice), withdrawShares, "Alice should receive withdrawn USDC");

        // Check Vault's balance after withdrawal
        uint256 vaultBalanceAfter = IERC20(mockUSDC).balanceOf(vaultAddress);
        assertEq(vaultBalanceAfter, vaultBalanceBefore - withdrawShares, "Vault should decrease by withdraw amount");

        // Ensure withdrawal of `0` shares fails
        vm.startPrank(alice);
        vm.expectRevert(LendingPool.ZeroAmount.selector);
        lendingPool.withdraw(0);
        vm.stopPrank();

        // Step 6: Ensure withdrawal of more than owned shares fails
        vm.startPrank(alice);
        vm.expectRevert(LendingPool.InsufficientShares.selector);
        lendingPool.withdraw(supplyAmount); // Trying to withdraw more than available
        vm.stopPrank();
    }

    function test_flashLoan() public {
        // give 100 USDC to lending pool
        deal(address(mockUSDC), address(vault), 100e6);
        uint256 amount = 100e6;

        // encode parameter to bytes: address,uint256
        bytes memory params = abi.encode(address(this), amount);

        lendingPool.flashLoan(address(mockUSDC), amount, params);
    }

    // to receive flashloan
    function onFlashLoan(address token, uint256 amount, bytes calldata params) external {
        console.log("Flashloan received", amount);

        // decode parameter from bytes: address,uint256
        (address receiver, uint256 _amount) = abi.decode(params, (address, uint256));

        // mint
        mockUSDC.mint(receiver, _amount);

        IERC20(token).approve(address(lendingPool), amount);
    }
}
