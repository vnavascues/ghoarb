// SPDX-License-Identifier: MIT
// solhint-disable-next-line
pragma solidity ^0.8.0;

interface ITypeAndVersion {
    /**
     * @notice Get the current `GhoArb` type and Version.
     * @return typeAndVersion A string that states the current contract type and version.
     */
    function typeAndVersion() external pure returns (string memory);
}
