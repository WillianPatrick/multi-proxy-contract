// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "../libraries/LibDiamond.sol";

contract AccessControlFacet {

   modifier onlyRole(bytes32 role) {
        require(hasRole(role, msg.sender), "AccessControl: sender does not have required role");
        _;
    }

    function hasRole(bytes32 role, address account) public view returns (bool) {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        return (ds.contractOwner == account || ds.admin == account || ds.accessControl[role][account] || ds.accessControl[ds.roleAdmins[role]][account]);
    }

    function getRoleAdmin(bytes32 role) public view returns (bytes32) {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        return ds.roleAdmins[role];
    }

    function setFunctionRole(bytes4 functionSelector, bytes32 role) external {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        require(hasRole(ds.roleAdmins[role], msg.sender), "AccessControl: sender must be an admin to set role");
        ds.functionRoles[functionSelector] = role;
    }

    function removeFunctionRole(bytes4 functionSelector) external {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        require(hasRole(ds.roleAdmins[ds.functionRoles[functionSelector]], msg.sender), "AccessControl: sender must be an admin to remove role");
        delete ds.functionRoles[functionSelector];
    }

}
