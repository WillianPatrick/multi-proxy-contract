// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { LibERC20Constants } from "../../libraries/ERC20/LibConstants.sol";

contract BaseConstantsFacet {

    function admin() external view returns (address) {
        LibERC20Constants.ConstantsStates storage ds = LibERC20Constants.diamondStorage();
        return ds.admin;
    }

    function transferAdminship(address _newAdmin) external {
        LibERC20Constants.enforceIsTokenAdmin();
        LibERC20Constants.setTokenAdmin(_newAdmin);
    } 
}
