// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

library ErrorsLib {
    /// @notice Thrown when a zero address is passed as input.
    string internal constant ZERO_ADDRESS = "zero address";

    /// @notice Thrown when a token transfer reverted.
    string internal constant TRANSFER_REVERTED = "transfer reverted";

    /// @notice Thrown when latest round data less than zero.
    string internal constant NegativeAnswer = "negative answer";
}
