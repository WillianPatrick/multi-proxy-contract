// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { LibERC20Constants } from "../libraries/ERC20/LibConstants.sol";
import { LibBalances } from "../libraries/ERC20/LibBalances.sol";
import { TokenStorage, ERC20Facet } from "../facets/ERC20/ERC20Facet.sol";
import { LibDiamond } from "../libraries/LibDiamond.sol";

contract DiamondInit {    

    function initERC20(string calldata _name, string calldata _symbol, uint8 _decimals, address _admin, uint256 _totalSupply) external {
        //LibERC20Constants.ConstantsStates storage constantsStorage = LibERC20Constants.diamondStorage();
         LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();

        // constantsStorage.name = _name;
        // constantsStorage.symbol = _symbol;
        // constantsStorage.decimals = _decimals;
        // constantsStorage.admin = _admin;
        // LibBalances.mint(_admin, _totalSupply);

        // bytes32 tokenKey = keccak256(abi.encodePacked(_name, _symbol));
        // TokenStorage.TokenData storage ds = TokenStorage.tokenStorage(tokenKey);
        //        ds.name = _name;
        // ds.symbol = _symbol;
        // ds.decimals = _decimals;
        //        // Set the admin role
        // ds.owner = _admin;
        // bytes32 defaultAdminRole = keccak256("DEFAULT_ADMIN_ROLE");
        // ds.roles[defaultAdminRole][_admin] = true;
        //        // Assign the initial supply to the admin
        // ds.balances[_admin] = _totalSupply;
        // ds.totalSupply = _totalSupply;
    }
}
