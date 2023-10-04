// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { LibBalances } from "../../libraries/ERC20/LibBalances.sol";
import { LibERC20Constants } from "../../libraries/ERC20/LibConstants.sol";

contract SupplyRegulatorFacet {
    
    function mint(address _account, uint256 _amount) external {
        LibERC20Constants.enforceIsTokenAdmin();
        LibBalances.mint(_account, _amount);
    }

    function burn(address _account, uint256 _amount) external {
        LibERC20Constants.enforceIsTokenAdmin();
        LibBalances.burn(_account, _amount);
    }
}