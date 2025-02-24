// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Position} from "./Position.sol";
import {ILendingPool} from "./interfaces/ILendingPool.sol";

contract PositionFactory {
    event PositionCreated(address positionAddress, address lendingPool, uint256 _baseCollateral, uint8 _leverag);

    mapping(address => bool) public positions;

    function createPosition(address _lendingPool, uint256 _baseCollateral, uint8 _leverage)
        external
        returns (address)
    {
        Position newPosition = new Position(_lendingPool, msg.sender);
        address positionAddr = address(newPosition);
        address collateralToken = ILendingPool(_lendingPool).collateralToken();
        positions[positionAddr] = true;
        ILendingPool(_lendingPool).registerPosition(positionAddr);

        IERC20(collateralToken).transferFrom(msg.sender, address(this), _baseCollateral);
        IERC20(collateralToken).approve(positionAddr, _baseCollateral);

        uint256 borrowAmount = newPosition.convertCollateralPrice(_baseCollateral * (_leverage - 100) / 100);
        uint256 effectiveCollateral = _baseCollateral * _leverage / 100;
        newPosition.setRiskInfo(effectiveCollateral, borrowAmount);
        newPosition.openPosition(_baseCollateral, borrowAmount);

        emit PositionCreated(positionAddr, _lendingPool, _baseCollateral, _leverage);
        return positionAddr;
    }
}
