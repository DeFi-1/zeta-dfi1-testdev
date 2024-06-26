// SPDX-License-Identifier: MIT
pragma solidity 0.8.7;
 
import "@zetachain/protocol-contracts/contracts/zevm/SystemContract.sol";
import "@zetachain/protocol-contracts/contracts/zevm/interfaces/zContract.sol";
import "@zetachain/toolkit/contracts/SwapHelperLib.sol";
import "@zetachain/toolkit/contracts/BytesHelperLib.sol";
import "@zetachain/toolkit/contracts/OnlySystem.sol";
 
contract Swap is zContract, OnlySystem {
    SystemContract public systemContract;
    uint256 constant BITCOIN = 18332;
 
    constructor(address systemContractAddress) {
        systemContract = SystemContract(systemContractAddress);
    }
 
    function onCrossChainCall(
        zContext calldata context,
        address zrc20,
        uint256 amount,
        bytes calldata message
    ) external virtual override onlySystem(systemContract) {
        address targetTokenAddress;
        bytes memory recipientAddress;
 
        if (context.chainID == BITCOIN) {
            targetTokenAddress = BytesHelperLib.bytesToAddress(message, 0);
            recipientAddress = abi.encodePacked(
                BytesHelperLib.bytesToAddress(message, 20)
            );
        } else {
            (address targetToken, bytes memory recipient) = abi.decode(
                message,
                (address, bytes)
            );
            targetTokenAddress = targetToken;
            recipientAddress = recipient;
        }
 
        (address gasZRC20, uint256 gasFee) = IZRC20(targetTokenAddress)
            .withdrawGasFee();
 
        uint256 inputForGas = SwapHelperLib.swapTokensForExactTokens(
            systemContract,
            zrc20,
            gasFee,
            gasZRC20,
            amount
        );
 
        uint256 outputAmount = SwapHelperLib.swapExactTokensForTokens(
            systemContract,
            zrc20,
            amount - inputForGas,
            targetTokenAddress,
            0
        );
 
        IZRC20(gasZRC20).approve(targetTokenAddress, gasFee);
        IZRC20(targetTokenAddress).withdraw(recipientAddress, outputAmount);
    }
}