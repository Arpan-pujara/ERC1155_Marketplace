// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ITokenUpgradeable {
    function mintNewPropertyToken(
        string calldata __uri,
        uint256 _amount,
        address _propOwnerAddress
    ) external;

    function totalSupply(uint256 id) external view returns (uint256);

    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes calldata data
    ) external;

    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] calldata ids,
        uint256[] calldata amounts,
        bytes calldata data
    ) external;

    function balanceOf(
        address account,
        uint256 id
    ) external view returns (uint256);
}
