// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;


import {ERC1967Proxy} from "lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {CapxFam} from "src/CapxFam.sol";
import "forge-std/Script.sol";
contract CapxFamDeployer is Script{
    address public capxFamImplementation;
    address public admin;
    
    constructor(address _admin, address _capxFamImplementation) {
        admin = _admin;
        capxFamImplementation = _capxFamImplementation;
    }

    function deployCapxFam(
        address _initialOwner,
        string memory _name,
        string memory _symbol,
        address _authorizedMinter,
        address _ICapxProfileCredential
    ) external returns (address) {
        ERC1967Proxy proxy = new ERC1967Proxy(
            capxFamImplementation,
            abi.encodeWithSelector(
                CapxFam.initialize.selector,
                _initialOwner,
                _name,
                _symbol,
                _authorizedMinter,
                _ICapxProfileCredential
            )
        );

        return address(proxy);
    }
}
