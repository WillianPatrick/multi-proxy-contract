// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { IDiamond } from "../interfaces/IDiamond.sol";
import { IDiamondCut } from "../interfaces/IDiamondCut.sol";

// Remember to add the loupe functions from DiamondLoupeFacet to the diamond.
// The loupe functions are required by the EIP2535 Diamonds standard

error NoSelectorsGivenToAdd();
error NotContractOwner(address _user, address _contractOwner);
error NoSelectorsProvidedForFacetForCut(address _facetAddress);
error CannotAddSelectorsToZeroAddress(bytes4[] _selectors);
error NoBytecodeAtAddress(address _contractAddress, string _message);
error IncorrectFacetCutAction(uint8 _action);
error CannotAddFunctionToDiamondThatAlreadyExists(bytes4 _selector);
error CannotReplaceFunctionsFromFacetWithZeroAddress(bytes4[] _selectors);
error CannotReplaceImmutableFunction(bytes4 _selector);
error CannotReplaceFunctionWithTheSameFunctionFromTheSameFacet(bytes4 _selector);
error CannotReplaceFunctionThatDoesNotExists(bytes4 _selector);
error RemoveFacetAddressMustBeZeroAddress(address _facetAddress);
error CannotRemoveFunctionThatDoesNotExist(bytes4 _selector);
error CannotRemoveImmutableFunction(bytes4 _selector);
error InitializationFunctionReverted(address _initializationContractAddress, bytes _calldata);
error NotTokenAdmin(address currentAdminAddress);

library LibDiamond {
    bytes32 constant DIAMOND_STORAGE_POSITION = keccak256("diamond.standard.diamond.storage");
    bytes32 constant DEFAULT_ADMIN_ROLE = keccak256("DEFAULT_ADMIN_ROLE");
    event OwnershipTransferred(address previousOwner, address _newOwner);
    event AdminshipTransferred(address indexed previousAdmin, address indexed newAdmin);

    function enforceIsTokenAdmin() internal view {
        if(msg.sender != diamondStorage(DIAMOND_STORAGE_POSITION).admin) {
            revert NotTokenAdmin(diamondStorage(DIAMOND_STORAGE_POSITION).admin);
        }        
    }

    function enforceIsTokenAdmin(bytes32 storageKey) internal view {
        if(msg.sender != diamondStorage(storageKey).admin) {
            revert NotTokenAdmin(diamondStorage(storageKey).admin);
        }        
    }

    function setAdmin(address _newAdmin, bytes32 storageKey) internal {
        address previousAdmin = diamondStorage(storageKey).admin;
        diamondStorage(storageKey).admin = _newAdmin;
        diamondStorage(storageKey).accessControl[DEFAULT_ADMIN_ROLE][_newAdmin] = true;
        //diamondStorage(storageKey).roleAdmins[DEFAULT_ADMIN_ROLE] = _newAdmin;
        emit AdminshipTransferred(previousAdmin, _newAdmin);
    }

    function setAdmin(address _newAdmin) internal {
        setAdmin(_newAdmin, DIAMOND_STORAGE_POSITION);
    }    

    struct FacetAddressAndSelectorPosition {
        address facetAddress;
        uint16 selectorPosition;
    }

    struct DiamondStorage {
        mapping(bytes4 => FacetAddressAndSelectorPosition) facetAddressAndSelectorPosition;
        bytes4[] selectors;
        mapping(address => bool) pausedFacets;
        mapping(bytes4 => bool) pausedSelectors;
        address contractOwner;
        address admin;
        mapping(bytes32 => mapping(address => bool)) accessControl;
        mapping(bytes32 => bytes32) roleAdmins; 
        mapping(bytes4 => bytes32) functionRoles;
    }

    function diamondStorage() internal pure returns (DiamondStorage storage ds) {
        bytes32 position = DIAMOND_STORAGE_POSITION;
        assembly {
            ds.slot := position
        }
    }    

    function diamondStorage(bytes32 storageKey) internal pure returns (DiamondStorage storage ds) {
        bytes32 position = storageKey;
        assembly {
            ds.slot := position
        }
    }

    function setContractOwner(address _newOwner, bytes32 storageKey) internal {
        DiamondStorage storage ds = diamondStorage(storageKey);
        address previousOwner = ds.contractOwner;
        diamondStorage(storageKey).contractOwner = _newOwner;
        diamondStorage(storageKey).accessControl[DEFAULT_ADMIN_ROLE][_newOwner] = true;   
        emit OwnershipTransferred(previousOwner, _newOwner);
    }

    function setContractOwner(address _newOwner) internal {
        setContractOwner(_newOwner, DIAMOND_STORAGE_POSITION);
    }    

    function contractOwner(bytes32 storageKey) internal view returns (address contractOwner_) {
        contractOwner_ = diamondStorage(storageKey).contractOwner;
    }

    function contractOwner() internal view returns (address contractOwner_) {
        contractOwner_ = diamondStorage(DIAMOND_STORAGE_POSITION).contractOwner;
    }   

    function contractAdmin(bytes32 storageKey) internal view returns (address contractAdmin_) {
        contractAdmin_ = diamondStorage(storageKey).admin;
    }   

    function contractAdmin() internal view returns (address contractAdmin_) {
        contractAdmin_ = diamondStorage(DIAMOND_STORAGE_POSITION).admin;
    }   

    function enforceIsContractOwner(bytes32 storageKey) internal view {
        if(msg.sender != diamondStorage(storageKey).contractOwner && msg.sender != diamondStorage(storageKey).admin) {
            revert NotContractOwner(msg.sender, diamondStorage(storageKey).contractOwner);
        }        
    }

    function enforceIsContractOwner() internal view {
        enforceIsContractOwner(DIAMOND_STORAGE_POSITION);
    }    

    event DiamondCut(IDiamondCut.FacetCut[] _diamondCut, address _init, bytes _calldata);

    function diamondCut(
        IDiamondCut.FacetCut[] memory _diamondCut,
        address _init,
        bytes memory _calldata
    ) internal {
        for (uint256 facetIndex; facetIndex < _diamondCut.length; facetIndex++) {
            bytes4[] memory functionSelectors = _diamondCut[facetIndex].functionSelectors;
            address facetAddress = _diamondCut[facetIndex].facetAddress;

            if(functionSelectors.length == 0) {
                revert NoSelectorsProvidedForFacetForCut(facetAddress);
            }

            IDiamondCut.FacetCutAction action = _diamondCut[facetIndex].action;
            if (action == IDiamond.FacetCutAction.Add) {
                addFunctions(facetAddress, functionSelectors);
            } else if (action == IDiamond.FacetCutAction.Replace) {
                replaceFunctions(facetAddress, functionSelectors);
            } else if (action == IDiamond.FacetCutAction.Remove) {
                removeFunctions(facetAddress, functionSelectors);
            } else {
                revert IncorrectFacetCutAction(uint8(action));
            }
        }

        emit DiamondCut(_diamondCut, _init, _calldata);
        initializeDiamondCut(_init, _calldata);
    }

    function addFunctions(address _facetAddress, bytes4[] memory _functionSelectors) internal {  
        if(_facetAddress == address(0)) {
            revert CannotAddSelectorsToZeroAddress(_functionSelectors);
        }
        DiamondStorage storage ds = diamondStorage(DIAMOND_STORAGE_POSITION);
        uint16 selectorCount = uint16(ds.selectors.length);                
        enforceHasContractCode(_facetAddress, "LibDiamondCut: Add facet has no code");
        for (uint256 selectorIndex; selectorIndex < _functionSelectors.length; selectorIndex++) {
            bytes4 selector = _functionSelectors[selectorIndex];
            address oldFacetAddress = ds.facetAddressAndSelectorPosition[selector].facetAddress;
            if(oldFacetAddress != address(0)) {
                //revert CannotAddFunctionToDiamondThatAlreadyExists(selector);
                continue;
            }            
            ds.facetAddressAndSelectorPosition[selector] = FacetAddressAndSelectorPosition(_facetAddress, selectorCount);
            ds.selectors.push(selector);
            selectorCount++;
        }
    }

    function replaceFunctions(address _facetAddress, bytes4[] memory _functionSelectors) internal {       
        DiamondStorage storage ds = diamondStorage(DIAMOND_STORAGE_POSITION);
        if(_facetAddress == address(0)) {
            revert CannotReplaceFunctionsFromFacetWithZeroAddress(_functionSelectors);
        }
        enforceHasContractCode(_facetAddress, "LibDiamondCut: Replace facet has no code");
        for (uint256 selectorIndex; selectorIndex < _functionSelectors.length; selectorIndex++) {
            bytes4 selector = _functionSelectors[selectorIndex];
            address oldFacetAddress = ds.facetAddressAndSelectorPosition[selector].facetAddress;
            // can't replace immutable functions -- functions defined directly in the diamond in this case
            if(oldFacetAddress == address(this)) {
                revert CannotReplaceImmutableFunction(selector);
            }
            if(oldFacetAddress == _facetAddress) {
                revert CannotReplaceFunctionWithTheSameFunctionFromTheSameFacet(selector);
            }
            if(oldFacetAddress == address(0)) {
                revert CannotReplaceFunctionThatDoesNotExists(selector);
            }
            // replace old facet address
            ds.facetAddressAndSelectorPosition[selector].facetAddress = _facetAddress;
        }
    }

    function removeFunctions(address _facetAddress, bytes4[] memory _functionSelectors) internal {        
        DiamondStorage storage ds = diamondStorage(DIAMOND_STORAGE_POSITION);
        uint256 selectorCount = ds.selectors.length;
        if(_facetAddress != address(0)) {
            revert RemoveFacetAddressMustBeZeroAddress(_facetAddress);
        }        
        for (uint256 selectorIndex; selectorIndex < _functionSelectors.length; selectorIndex++) {
            bytes4 selector = _functionSelectors[selectorIndex];
            FacetAddressAndSelectorPosition memory oldFacetAddressAndSelectorPosition = ds.facetAddressAndSelectorPosition[selector];
            if(oldFacetAddressAndSelectorPosition.facetAddress == address(0)) {
                revert CannotRemoveFunctionThatDoesNotExist(selector);
            }
            
            
            // can't remove immutable functions -- functions defined directly in the diamond
            if(oldFacetAddressAndSelectorPosition.facetAddress == address(this)) {
                revert CannotRemoveImmutableFunction(selector);
            }
            // replace selector with last selector
            selectorCount--;
            if (oldFacetAddressAndSelectorPosition.selectorPosition != selectorCount) {
                bytes4 lastSelector = ds.selectors[selectorCount];
                ds.selectors[oldFacetAddressAndSelectorPosition.selectorPosition] = lastSelector;
                ds.facetAddressAndSelectorPosition[lastSelector].selectorPosition = oldFacetAddressAndSelectorPosition.selectorPosition;
            }
            // delete last selector
            ds.selectors.pop();
            delete ds.facetAddressAndSelectorPosition[selector];
        }
    }

    function initializeDiamondCut(address _init, bytes memory _calldata) internal {
        if (_init == address(0)) {
            return;
        }
        enforceHasContractCode(_init, "LibDiamondCut: _init address has no code");        
        (bool success, bytes memory error) = _init.delegatecall( _calldata);
        if (!success) {
            if (error.length > 0) {
                // bubble up error
                /// @solidity memory-safe-assembly
                assembly {
                    let returndata_size := mload(error)
                    revert(add(32, error), returndata_size)
                }
            } else {
                revert InitializationFunctionReverted(_init, _calldata);
            }
        }        
    }

    function enforceHasContractCode(address _contract, string memory _errorMessage) internal view {
        uint256 contractSize;
        assembly {
            contractSize := extcodesize(_contract)
        }
        if(contractSize == 0) {
            revert NoBytecodeAtAddress(_contract, _errorMessage);
        }        
    }
}
