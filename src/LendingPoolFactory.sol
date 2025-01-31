// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {LendingPool} from "./LendingPool.sol";

contract LendingPoolFactory {
    address[] public pools;

    function createLendingPool(address loanToken, address collateralToken) external returns (address) {
        LendingPool lendingPool = new LendingPool(IERC20(loanToken), IERC20(collateralToken));
        pools.push(address(lendingPool));
        return address(lendingPool);
    }
}
