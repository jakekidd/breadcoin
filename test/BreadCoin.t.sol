// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/Test.sol";
import "../src/BreadCoin.sol";

contract BreadCoinTest is Test {
    BreadCoin public breadCoin;
    address public baker;
    address public user1;
    address public user2;
    
    function setUp() public {
        baker = address(this);
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        
        // Deploy BreadCoin.
        breadCoin = new BreadCoin(baker);
        
        // Give users some ETH.
        vm.deal(user1, 100 ether);
        vm.deal(user2, 100 ether);
    }
    
    // THE ONE AND ONLY THERE CAN BE NO OTHER KIND OF BREADCOIN
    function test_BreadCoin__constructor_setsCorrectInitialValues() public {
        assertEq(breadCoin.name(), "BreadCoin");
        assertEq(breadCoin.symbol(), "BREAD");
        assertEq(breadCoin.decimals(), 0);
        assertEq(breadCoin.totalSupply(), 0);
        assertEq(breadCoin.MAX_SUPPLY(), 1_000_000);
        assertEq(breadCoin.genesisBlock(), block.number);
        assertEq(breadCoin.owner(), baker);
    }
    
    function test_BreadCoin__price_startsAtOneWei() public {
        // At genesis block, price should be 1 wei (minimum)
        assertEq(breadCoin.price(), 1);
    }
    
    function test_BreadCoin__price_increasesWithBlocks() public {
        // Move forward 10 blocks
        vm.roll(block.number + 10);
        assertEq(breadCoin.price(), 10); // age = 10, price = 10 (not 0 so returns age)
        
        // Move forward another 5 blocks
        vm.roll(block.number + 5);
        assertEq(breadCoin.price(), 15); // age = 15, price = 15
    }
    
    function test_BreadCoin__quote_calculatesCorrectCost() public {
        vm.roll(block.number + 10); // Price = 10 wei
        
        assertEq(breadCoin.quote(1), 10);
        assertEq(breadCoin.quote(5), 50);
        assertEq(breadCoin.quote(10), 100);
    }
    

    
    function test_BreadCoin__bake_mintsTokensForPayment() public {
        vm.roll(block.number + 5); // Price = 6 wei
        
        vm.startPrank(user1);
        uint256 cost = breadCoin.quote(10);
        breadCoin.bake{value: cost}(10);
        
        assertEq(breadCoin.balanceOf(user1), 10);
        assertEq(breadCoin.totalSupply(), 10);
        vm.stopPrank();
    }
    
    function test_BreadCoin__bake_refundsExcessPayment() public {
        vm.roll(block.number + 5); // Price = 6 wei
        
        vm.startPrank(user1);
        uint256 cost = breadCoin.quote(10); // 60 wei
        uint256 overpayment = cost + 1000; // Pay extra
        
        uint256 balanceBefore = user1.balance;
        breadCoin.bake{value: overpayment}(10);
        uint256 balanceAfter = user1.balance;
        
        assertEq(breadCoin.balanceOf(user1), 10);
        assertEq(balanceBefore - balanceAfter, cost); // Should only pay actual cost
        vm.stopPrank();
    }
    
    function test_BreadCoin__bakeMax_mintsMaxPossibleTokens() public {
        vm.roll(block.number + 10); // Price = 10 wei
        
        vm.startPrank(user1);
        uint256 ethAmount = 1000; // Send 1000 wei
        uint256 expectedLoaves = ethAmount / 10; // Should get 100 loaves (no bulk discount)
        
        breadCoin.bakeMax{value: ethAmount}();
        
        assertEq(breadCoin.balanceOf(user1), expectedLoaves);
        vm.stopPrank();
    }
    
    function test_BreadCoin__bakeMax_calculatesCorrectAmount() public {
        vm.roll(block.number + 10); // Price = 10 wei
        
        vm.startPrank(user1);
        uint256 ethAmount = 1000; // Send 1000 wei
        uint256 expectedLoaves = ethAmount / 10; // Should get exactly 100 loaves
        
        breadCoin.bakeMax{value: ethAmount}();
        
        assertEq(breadCoin.balanceOf(user1), expectedLoaves);
        vm.stopPrank();
    }
    
    function test_BreadCoin__toast_burnsTokens() public {
        // First bake some bread
        vm.roll(block.number + 5);
        vm.startPrank(user1);
        uint256 cost = breadCoin.quote(20);
        breadCoin.bake{value: cost}(20);
        
        // Toast 5 loaves
        breadCoin.toast(5);
        
        assertEq(breadCoin.balanceOf(user1), 15);
        assertEq(breadCoin.totalSupply(), 15);
        vm.stopPrank();
    }
    
    function test_BreadCoin__knead_incrementsCrumbsAndReturnsMessage() public {
        vm.startPrank(user1);
        
        // Check initial crumbs
        assertEq(breadCoin._crumbs(user1), 0);
        
        // Knead and check return value and crumbs
        string memory result = breadCoin.knead();
        assertEq(result, "you kneaded this");
        assertEq(breadCoin._crumbs(user1), 1);
        
        // Knead again
        breadCoin.knead();
        assertEq(breadCoin._crumbs(user1), 2);
        
        vm.stopPrank();
    }
    
    function test_BreadCoin__makeDough_onlyOwnerCanWithdraw() public {
        // Add some ETH to contract
        vm.roll(block.number + 10);
        vm.startPrank(user1);
        uint256 cost = breadCoin.quote(10);
        breadCoin.bake{value: cost}(10);
        vm.stopPrank();
        
        // User1 should not be able to call makeDough
        vm.startPrank(user1);
        vm.expectRevert();
        breadCoin.makeDough();
        vm.stopPrank();
        
        // Owner should be able to withdraw
        uint256 bakerBalanceBefore = baker.balance;
        uint256 contractBalance = address(breadCoin).balance;
        
        breadCoin.makeDough();
        
        assertEq(address(breadCoin).balance, 0);
        assertEq(baker.balance - bakerBalanceBefore, contractBalance);
    }
    
    function test_BreadCoin__bake_revertsWhenExceedsMaxSupply() public {
        vm.roll(block.number + 1); // Price = 2 wei
        
        vm.startPrank(user1);
        // Try to bake more than max supply
        vm.expectRevert("we ran out sorry :(");
        breadCoin.bake{value: 2_000_000}(1_000_001);
        vm.stopPrank();
    }
    
    function test_BreadCoin__bake_revertsForZeroLoaves() public {
        vm.startPrank(user1);
        vm.expectRevert("don't you want bread?");
        breadCoin.bake{value: 100}(0);
        vm.stopPrank();
    }
    
    function test_BreadCoin__bake_revertsForInsufficientPayment() public {
        vm.roll(block.number + 10); // Price = 10 wei
        
        vm.startPrank(user1);
        uint256 cost = breadCoin.quote(10); // 100 wei
        vm.expectRevert("not a soup kitchen");
        breadCoin.bake{value: cost - 1}(10); // Pay 1 wei less
        vm.stopPrank();
    }
    
    function test_BreadCoin__toast_revertsWhenExceedsBalance() public {
        vm.roll(block.number + 5);
        vm.startPrank(user1);
        
        // Bake 10 loaves
        uint256 cost = breadCoin.quote(10);
        breadCoin.bake{value: cost}(10);
        
        // Try to toast 11 loaves
        vm.expectRevert();
        breadCoin.toast(11);
        vm.stopPrank();
    }
    
    function test_BreadCoin__toast_revertsForZeroAmount() public {
        vm.startPrank(user1);
        vm.expectRevert("can't toast nothing");
        breadCoin.toast(0);
        vm.stopPrank();
    }
    
    function test_BreadCoin__bakeMax_revertsForInsufficientETH() public {
        vm.roll(block.number + 100); // High price = 100 wei
        
        vm.startPrank(user1);
        vm.expectRevert("not enough ETH for even 1 loaf");
        breadCoin.bakeMax{value: 50}(); // Not enough for 1 loaf
        vm.stopPrank();
    }
    
    function test_BreadCoin__bakeMax_revertsForZeroETH() public {
        vm.startPrank(user1);
        vm.expectRevert("send some ETH");
        breadCoin.bakeMax{value: 0}();
        vm.stopPrank();
    }
    
    // Fuzz test for baking random amounts
    function test_BreadCoin__bake_fuzzTest(uint256 loaves, uint256 blocks) public {
        // Bound inputs to reasonable ranges
        loaves = bound(loaves, 1, 1000);
        blocks = bound(blocks, 0, 1000);
        
        vm.roll(block.number + blocks);
        
        vm.startPrank(user1);
        uint256 cost = breadCoin.quote(loaves);
        
        // Only test if we have enough ETH
        if (cost <= user1.balance) {
            breadCoin.bake{value: cost}(loaves);
            assertEq(breadCoin.balanceOf(user1), loaves);
        }
        vm.stopPrank();
    }
    
    receive() external payable {}
} 