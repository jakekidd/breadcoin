// SPDX-License-Identifier: MIT
// BreadCoin™ is NOT for human consumption.
// The REAL token backed by REAL foodstamps at a REAL foodbank. Now with 100% more blocks. Adjusted for inflation.
// All rights reversed. Probably
pragma solidity ^0.8.23;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title BreadCoin - Just bread, just vibes. The economy is in shambles. Invest in Big Bread
///        block-priced bread; price starts at 0.00001 ETH on deploy, +1 wei per block #inflation
/// Key Features:
/// 1. Linear pricing: 0.00001 ETH + 1 wei per block since launch #inflation
/// 2. Pay-to-knead mechanics with crumb rewards (TBD)
/// 3. Toast (burn) mechanism for deflation
/// 4. Random crumb airdrops for engagement. Maybe. We'll see. Ask me later.
/// 5. Baker owner can "accept" ETH, making dough. DM me with your location, we'll deliver
contract BreadCoin is ERC20, Ownable, ReentrancyGuard {
    uint256 public immutable genesisBlock;
    // 1 million loaves. What do I look like, a bank?
    uint256 public constant MAX_SUPPLY = 1_000_000;
    
    // Floor price: 0.00001 ETH because even bread has standards
    // This isn't the ground floor, this is the penthouse floor! Get in on it
    // We're not running a charity here - bread doesn't grow on trees, it grows on... grain? Or something. Idk I'm not a farmer. You are. You're the farmer
    uint256 public constant FLOOR_PRICE = 0.00001 ether; // 10^13 wei - fancy bread deserves fancy prices
    
    mapping(address => uint256) public _crumbs; // Track how many times each user has kneaded by awarding crumbs, bonus points for kneady kneaders
    
    /// @notice Check if it's Sunday (God's day, bread bakery is closed so we can rest and go to church)
    /// @dev This assumes we launch on a Sunday. We'll be closed on our first day, it's just a hype day.
    modifier notOnSunday() {
        // Unix timestamp: Sunday = 0, Monday = 1, ..., Saturday = 6
        uint256 dayOfWeek = (block.timestamp / 86400 + 4) % 7; // +4 adjusts for Unix epoch starting on Thursday
        require(dayOfWeek != 0, "bakery closed on sundays. it's God's day");
        _;
    }
    
    /// @notice Check if the bakery is open (not Sunday)
    function isBakeryOpen() public view returns (bool) {
        uint256 dayOfWeek = (block.timestamp / 86400 + 4) % 7;
        return dayOfWeek != 0;
    }
    
    /// @notice Get current day of week (0=Sunday, 1=Monday, ..., 6=Saturday)
    function getCurrentDay() public view returns (uint256) {
        return (block.timestamp / 86400 + 4) % 7;
    }

    constructor(address baker) ERC20("BreadCoin", "BREAD") Ownable(baker) {
        genesisBlock = block.number;
    }
    
    // ---- ERC20: 0 decimals ----
    function decimals() public pure override returns (uint8) {
        return 0; // bread doesn't come in slices. wait, it does? since when? THIS CHANGES EVERYTHING
    }
    
    /// @notice Current price per loaf in wei (FLOOR_PRICE + 1 wei per block since genesis)
    function price() public view returns (uint256) {
        uint256 age = block.number - genesisBlock;
        return FLOOR_PRICE + age; // Floor price + inflation (we have standards!)
    }
    
    /// @notice Quote cost for buying numLoaves
    function quote(uint256 numLoaves) public view returns (uint256) {
        require(numLoaves > 0, "loaves=0");
        uint256 unitPrice = price();
        return unitPrice * numLoaves;
    }
    
    /// @notice Bake (mint) bread by paying ETH. It doesn't grow on trees! Accounts for inflation, 1 wei per genesis block.
    function bake(uint256 numLoaves) external payable nonReentrant notOnSunday {
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
    function bakeMax() external payable nonReentrant notOnSunday {
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