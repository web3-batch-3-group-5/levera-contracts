// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Position} from "./Position.sol";
import {ILendingPool} from "./interfaces/ILendingPool.sol";

contract PositionFactory {
    event PositionCreated(address positionAddress, address lendingPool, uint256 _baseCollateral, uint8 _leverag);

    mapping(address => bool) public positions;

    function createPosition(address _lendingPool, uint256 _baseCollateral, uint8 _leverage)
        external
        returns (address)
    {
        address collateralToken = ILendingPool(_lendingPool).collateralToken();
        address loanToken = ILendingPool(_lendingPool).loanToken();

        Position newPosition = new Position(_lendingPool, collateralToken);
        address positionAddress = address(newPosition);

        newPosition.initialize(_baseCollateral, _leverage);

        positions[positionAddress] = true;
        emit PositionCreated(positionAddress, _lendingPool, _baseCollateral, _leverage);
        return positionAddress;
    }
}
