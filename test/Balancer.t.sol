// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/Counter.sol";
import "../interfaces/IBalancerPool.sol";
import "../interfaces/IBalancerVault.sol";


contract BalancerTests is Test {
    Counter public counter;

    Vm public constant vm_std_cheats =
        Vm(address(uint160(uint256(keccak256("hevm cheat code"))))); // vm cheat interface
    
    bytes32 public poolId;
    address public constant user = address(1);
    address public constant wsteth = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;
    address public constant weth = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    IBalancerVault public constant balancerVault = IBalancerVault(0xBA12222222228d8Ba445958a75a0704d566BF2C8);
    IBalancerPool public constant balancerStethPool = IBalancerPool(0x32296969Ef14EB0c6d29669C550D4a0449130230);
    IAsset[] internal assets;

    function setUp() public {
        counter = new Counter();
        counter.setNumber(0);
        
        assets = new IAsset[](2);
        assets[0] = IAsset(wsteth);
        assets[1] = IAsset(weth);

        poolId = balancerStethPool.getPoolId();
    }

    function testBalancerPoolBasics() external {
        vm.startPrank(user);
        IERC20(wsteth).approve(address(balancerVault), type(uint256).max);
        IERC20(weth).approve(address(balancerVault), type(uint256).max);

        uint256 amount = 10 * 1e18;
        deal(wsteth, user, amount);
        assertTrue(IERC20(wsteth).balanceOf(user) > 0);
        console.log("User wsteth balance before deposit", IERC20(wsteth).balanceOf(user));
        
        uint256[] memory underlyingAmounts = new uint256[](2);
        underlyingAmounts[0] = amount;


        bytes memory _userData = abi.encode(
                IBalancerVault.JoinKind.EXACT_TOKENS_IN_FOR_BPT_OUT,
                underlyingAmounts,
                0
            );
        
        IBalancerVault.JoinPoolRequest memory _request = IBalancerVault
                .JoinPoolRequest(assets, underlyingAmounts, _userData, false);
        
        balancerVault.joinPool(
                poolId,
                user,
                user,
                _request
            );
        
        assertEq(IERC20(wsteth).balanceOf(user), 0); // all in position


        // Let's withdraw immediately!
        uint256[] memory minAmountsOut = new uint256[](2);

        _userData = abi.encode(
            IBalancerVault.ExitKind.EXACT_BPT_IN_FOR_ONE_TOKEN_OUT,
            balancerStethPool.balanceOf(user),
            0
        );

        IBalancerVault.ExitPoolRequest memory _request2 = IBalancerVault
            .ExitPoolRequest(assets, minAmountsOut, _userData, false);

        balancerVault.exitPool(
            poolId,
            user,
            payable(user),
            _request2
        );

        console.log("User steth balance after immediate withdraw single sided", IERC20(wsteth).balanceOf(user));
    }
}
