// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {AggregatorV2V3Interface} from "@chainlink/contracts/v0.8/shared/interfaces/AggregatorV2V3Interface.sol";
import {MockUniswapRouter} from "../src/mocks/MockUniswapRouter.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";
import {PositionFactory} from "../src/PositionFactory.sol";
import {LendingPoolFactory} from "../src/LendingPoolFactory.sol";
import {ILendingPool, PositionType} from "../src/interfaces/ILendingPool.sol";
import {IPosition} from "../src/interfaces/IPosition.sol";
import {LendingPool} from "../src/LendingPool.sol";
import {Position} from "../src/Position.sol";

/*
 * We cannot debug unverified contract hence it's important to create REPL file for setup
 */
contract REPLDeploy is Script {
    // Flame Testnet
    // address private constant MOCK_UNISWAP_ROUTER_ADDR = 0x82069D54DF7fB4d9D9d8B35e2BecA6FE6aBAdF87;
    // address private constant POSITION_FACTORY_ADDR = 0x991de844C6A42AC2D4Bb6B97cE4fCf28296b8B84;
    // Arbitrum Sepolia
    address private constant MOCK_UNISWAP_ROUTER_ADDR = 0x31e632baEcBe002F198e7F8A439d60502dE43412;
    // address private constant POSITION_FACTORY_ADDR = 0xE76cc7b58Df339879f6ff4171c39104415fE3b8D;
    // address private constant LP_FACTORY_ADDR = 0xb196c0E861AEBc7d6a2bd2C99Db0cc36D5EC82a4;
    // address private constant LP_ADDR = 0x0F15bd24515885FB862416e6Bd85B3f067484C3d;

    function init() public {
        uint256 supplyAmount = 10_000e18;
        uint256 baseCollateral = 1e12;
        uint256 leverage = 200;

        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(privateKey);

        // LendingPoolFactory lendingPoolFactory = LendingPoolFactory(LP_FACTORY_ADDR);
        LendingPoolFactory lendingPoolFactory = new LendingPoolFactory(MOCK_UNISWAP_ROUTER_ADDR);
        address lendingPoolAddr = lendingPoolFactory.createLendingPool(
            0xE6DFbEE9D497f1b851915166E26A273cB03F27E1,
            0x472A3ec37E662b295fd25E3b5d805117345a89D1,
            0x6A285E46Fce971CC762653EE9b8F81207A45214E,
            0x32423580b2762696Bf9F6e9149884d54e8150a19,
            80,
            5,
            PositionType.LONG
        );
        address loanToken = ILendingPool(lendingPoolAddr).loanToken();
        address collateralToken = ILendingPool(lendingPoolAddr).collateralToken();
        console.log("Lending Pool Factory deployed at:", address(lendingPoolFactory));
        console.log("Lending Pool deployed at:", lendingPoolAddr);

        MockERC20(loanToken).mint(address(this), supplyAmount);
        MockERC20(loanToken).approve(lendingPoolAddr, supplyAmount);
        ILendingPool(lendingPoolAddr).supply(supplyAmount);

        console.log("====================== After Supply =========================");
        console.log("totalCollateral =", ILendingPool(lendingPoolAddr).totalCollateral());
        console.log("totalSupplyAssets =", ILendingPool(lendingPoolAddr).totalSupplyAssets());
        console.log("totalBorrowAssets =", ILendingPool(lendingPoolAddr).totalBorrowAssets());
        console.log("==============================================================");
        console.log("Loan Token Balance", MockERC20(loanToken).balanceOf(address(this)));
        console.log("Collateral Token Balance", MockERC20(collateralToken).balanceOf(address(this)));

        // PositionFactory positionFactory = PositionFactory(POSITION_FACTORY_ADDR);
        PositionFactory positionFactory = new PositionFactory();
        MockERC20(collateralToken).mint(address(this), baseCollateral);
        MockERC20(collateralToken).approve(address(this), baseCollateral);
        MockERC20(collateralToken).approve(address(positionFactory), baseCollateral);
        console.log("Position Factory deployed at:", address(positionFactory));
        console.log("Loan Token Balance", MockERC20(loanToken).balanceOf(address(this)));
        console.log("Collateral Token Balance", MockERC20(collateralToken).balanceOf(address(this)));

        address onBehalf = positionFactory.createPosition(lendingPoolAddr, baseCollateral, leverage);
        console.log("Position deployed at:", onBehalf);
        console.log("====================== After Create Position =========================");
        console.log("totalCollateral =", ILendingPool(lendingPoolAddr).totalCollateral());
        console.log("totalSupplyAssets =", ILendingPool(lendingPoolAddr).totalSupplyAssets());
        console.log("totalBorrowAssets =", ILendingPool(lendingPoolAddr).totalBorrowAssets());
        console.log("baseCollateral =", IPosition(onBehalf).baseCollateral());
        console.log("effectiveCollateral =", IPosition(onBehalf).effectiveCollateral());
        console.log("borrowShares =", IPosition(onBehalf).borrowShares());
        console.log("==============================================================");
        console.log("Loan Token Balance", MockERC20(loanToken).balanceOf(address(this)));
        console.log("Collateral Token Balance", MockERC20(collateralToken).balanceOf(address(this)));

        positionFactory.deletePosition(lendingPoolAddr, onBehalf);
        console.log("====================== After Delete Position =========================");
        console.log("totalCollateral =", ILendingPool(lendingPoolAddr).totalCollateral());
        console.log("totalSupplyAssets =", ILendingPool(lendingPoolAddr).totalSupplyAssets());
        console.log("totalBorrowAssets =", ILendingPool(lendingPoolAddr).totalBorrowAssets());
        console.log("baseCollateral =", IPosition(onBehalf).baseCollateral());
        console.log("effectiveCollateral =", IPosition(onBehalf).effectiveCollateral());
        console.log("borrowShares =", IPosition(onBehalf).borrowShares());
        console.log("==============================================================");
        console.log("Loan Token Balance", MockERC20(loanToken).balanceOf(address(this)));
        console.log("Collateral Token Balance", MockERC20(collateralToken).balanceOf(address(this)));

        address[] memory pools = lendingPoolFactory.getAllLendingPools();
        console.log("Total Lending Pools:", pools.length);
        for (uint256 i = 0; i < pools.length; i++) {
            console.log("Pool Address Created:", pools[i]);
        }

        vm.stopBroadcast();
    }

    function run() external {
        init();
    }
}
