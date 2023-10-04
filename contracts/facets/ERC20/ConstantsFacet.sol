// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { LibERC20Constants } from "../../libraries/ERC20/LibConstants.sol";
import "../base/BaseConstantsFacet.sol";

contract ERC20ConstantsFacet is BaseConstantsFacet {

    function name() external view returns (string memory) {
        LibERC20Constants.ConstantsStates storage ds = LibERC20Constants.diamondStorage();
        return ds.name;
    }

    function symbol() external view returns (string memory) {
        LibERC20Constants.ConstantsStates storage ds = LibERC20Constants.diamondStorage();
        return ds.symbol;
    }

    function decimals() external view returns (uint8) {
        LibERC20Constants.ConstantsStates storage ds = LibERC20Constants.diamondStorage();
        return ds.decimals;
    }

}
