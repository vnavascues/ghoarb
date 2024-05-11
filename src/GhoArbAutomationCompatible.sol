// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { AutomationCompatible } from "@chainlink/contracts/src/v0.8/automation/AutomationCompatible.sol";
import { Ownable2Step } from "@openzeppelin/contracts/access/Ownable2Step.sol";

/**
 * @title GhoArbAutomationCompatible
 * @author vnavascues
 * @notice Make `GhoArb` compatible with Chainlink Automation 2.0.
 */
abstract contract GhoArbAutomationCompatible is AutomationCompatible, Ownable2Step {
    /// @dev Maps an address with the boolean that indicates whether the address is designated as a forwarder.
    mapping(address forwarder => bool isForwarder) private s_addressToIsForwarder;

    /// @dev Emitted when an address has been either set or unset as a forwarder via
    /// `GhoArbAutomationCompatible.setForwarder()`.
    event ForwarderSet(address indexed forwarder, bool isForwarder);

    /// @dev Thrown when the caller is not a forwarder.
    error GhoArb_MsgSenderIsNotForwarder(address msgSender);

    modifier onlyForwarder() {
        _requireMsgSenderIsForwarder();
        _;
    }

    /**
     * @notice Toggle the forwarder status of a given address.
     * @dev Only callable by the `GhoArbAutomationCompatible` owner.
     * @dev Emits an `ForwarderSet` event.
     * @param forwarder The address to be set or unset as a forwarder.
     * @param isForwarder The boolean indicating whether the address is designated as a forwarder.
     */
    function setForwarder(address forwarder, bool isForwarder) public onlyOwner {
        s_addressToIsForwarder[forwarder] = isForwarder;
        emit ForwarderSet(forwarder, isForwarder);
    }

    /**
     * @notice Get whether an address has the forwarder status or not.
     * @param forwarder The address to be set or unset as a forwarder.
     * @return isForwarder The boolean indicating whether the address is designated as a forwarder.
     */
    function getIsForwarder(address forwarder) external view returns (bool) {
        return s_addressToIsForwarder[forwarder];
    }

    /// @dev Reverts with `GhoArbAutomationCompatible.GhoArb_MsgSenderIsNotForwarder` if the caller is not a forwarder.
    function _requireMsgSenderIsForwarder() internal view {
        if (!s_addressToIsForwarder[msg.sender]) {
            revert GhoArb_MsgSenderIsNotForwarder(msg.sender);
        }
    }
}
