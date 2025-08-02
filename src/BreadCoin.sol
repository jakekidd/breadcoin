// SPDX-License-Identifier: MIT
// BreadCoin™ is NOT for human consumption.
// The REAL token backed by REAL foodstamps at a REAL foodbank. Now with 100% more blocks. Adjusted for inflation.
// All rights reversed. Probably
pragma solidity ^0.8.23;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title BreadCoin - Just bread, just vibes
///  block-priced bread; price starts at 0 on deploy, +1 per block #inflation
/// Key Features:
/// 1. Linear pricing: 1 wei per block since launch #inflation
/// 2. Pay-to-knead mechanics with crumb rewards (TBD)
/// 3. Toast (burn) mechanism for deflation
/// 4. Random crumb airdrops for engagement. Maybe. We'll see. Ask me later.
/// 5. Owner can "accept" ETH. DM me with your location, we'll deliver
contract BreadCoin is ERC20, Ownable, ReentrancyGuard {
    uint256 public immutable genesisBlock;
    // 1 million loaves. What do I look like, a bank?
    uint256 public constant MAX_SUPPLY = 1_000_000;
    
    mapping(address => uint256) public _crumbs; // Track how many times each user has kneaded by awarding crumbs, bonus points for kneady kneaders
    
    constructor(address baker) ERC20("BreadCoin", "BREAD") Ownable(baker) {
        genesisBlock = block.number;
    }
    
    // ---- ERC20: 0 decimals ----
    function decimals() public pure override returns (uint8) {
        return 0; // bread doesn't come in slices. wait, it does? since when? THIS CHANGES EVERYTHING
    }
    
    /// @notice Current price per loaf in wei (1 wei per block since genesis)
    function price() public view returns (uint256) {
        uint256 age = block.number - genesisBlock;
        return age == 0 ? 1 : age; // Minimum 1 wei (no free bread!)
    }
    
    /// @notice Quote cost for buying numLoaves
    function quote(uint256 numLoaves) public view returns (uint256) {
        require(numLoaves > 0, "loaves=0");
        uint256 unitPrice = price();
        return unitPrice * numLoaves;
    }
    
    /// @notice Bake (mint) bread by paying ETH. It doesn't grow on trees! Accounts for inflation, 1 wei per genesis block.
    function bake(uint256 numLoaves) external payable nonReentrant {
        require(numLoaves > 0, "don't you want bread?");
        require(totalSupply() + numLoaves <= MAX_SUPPLY, "we ran out sorry :(");
        
        uint256 cost = quote(numLoaves);
        require(msg.value >= cost, "not a soup kitchen");
        
        _mint(msg.sender, numLoaves);
        
        // Refund excess
        if (msg.value > cost) {
            payable(msg.sender).transfer(msg.value - cost);
        }
    }
    
    /// @notice Bake as much bread as possible with sent ETH. Even with inflation, are you sure? You must be hungry
    function bakeMax() external payable nonReentrant {
        require(msg.value > 0, "send some ETH");
        
        uint256 unitPrice = price();
        uint256 maxLoaves = msg.value / unitPrice;
        
        require(maxLoaves > 0, "not enough ETH for even 1 loaf");
        require(totalSupply() + maxLoaves <= MAX_SUPPLY, "would exceed max supply");
        
        uint256 actualCost = unitPrice * maxLoaves;
        
        _mint(msg.sender, maxLoaves);
        
        // Refund excess
        if (msg.value > actualCost) {
            payable(msg.sender).transfer(msg.value - actualCost);
        }
    }
    
    /// @notice Toast (burn) your bread for deflationary vibes. Butter sold separately.
    ///         Why????? Don't do it, you monster. Think of the bread!
    function toast(uint256 amount) external {
        require(amount > 0, "can't toast nothing");
        _burn(msg.sender, amount);
    }
    
    /// @notice Future NFT functionality
    ///         
    function knead() external returns (string memory) {
        _crumbs[msg.sender]++;

        // Waste some gas for dramatic effect
        // Commented out to save gas actually. Now we're more efficient, saving the earth to bake more bread per sq ft.
        // for (uint256 i = 0; i < (bread[msg.sender] % 10); i++) {
        //     keccak256(abi.encode(block.timestamp, msg.sender, i));
        // }

        //  .-""""""-.
        // /          \
        //|   ~~~~~~~~  |
        //|   ~~~~~~~~  |
        //|   ~~~~~~~~  |
        // \          /
        //  '-.......-'
        // TBD NFT
        return "you kneaded this";
    }
    
    /// @notice IGNORE This is just for the manager. Don't call this unless you're Frank, the bread warehouse foreman.
    function makeDough() external onlyOwner nonReentrant {
        payable(owner()).transfer(address(this).balance);
    }
} 