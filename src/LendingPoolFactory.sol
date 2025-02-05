// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {LendingPool} from "./LendingPool.sol";

struct BasePoolParams {
    address loanToken;
    address collateralToken;
}

struct PoolParams {
    BasePoolParams basePoolParams;
    address lendingPool;
}

error PoolAlreadyCreated();

contract LendingPoolFactory {
    mapping(bytes32 => PoolParams) public lendingPools;

    function createLendingPool(BasePoolParams memory params) external {
        bytes32 id = keccak256(abi.encode(params.loanToken, params.collateralToken));
        if (lendingPools[id].lendingPool != address(0)) revert PoolAlreadyCreated();

        LendingPool lendingPool = new LendingPool(IERC20(params.loanToken), IERC20(params.collateralToken));
        lendingPools[id] = PoolParams(params, address(lendingPool));
        Position position = new Position(address(lendingPool));
    }
}
