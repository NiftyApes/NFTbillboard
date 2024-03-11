//SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

// Useful for debugging. Remove when deploying to a live network.

import "hardhat/console.sol";

// Use openzeppelin to inherit battle-tested implementations (ERC20, ERC721, etc)
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Address.sol";


/**
 * A smart contract that allows changing a state variable of the contract and tracking the changes
 * It also allows the owner to withdraw the Ether in the contract
 * @author zherring
 */
contract YourContract is ERC721 {

	// State Variables
	address public immutable owner;
	using Counters for Counters.Counter;
	Counters.Counter private _tokenIds;

	// Epoch data, where I store the number of NFTs minted (will limit withdraws to NFT ids >= total minted) and the amount paid to track how much they're owed
	struct epochData {
		uint256 nftsMinted;
		uint256 amtOwed;
	}
	// storing epoch data
	mapping(uint256 => epochData) public epochs;
	uint256 public currentEpoch = 0;
	mapping(uint256 => mapping(uint256 => bool)) private hasWithdrawn;

	// Custom getter function for epochs mapping, idk if needed but keeping the code just in case
	// function getEpochData(uint256 epochIndex) public view returns (uint256[] memory, uint256[] memory) {
	//     epochData storage data = epochs[epochIndex];
	//     return (data.nftsMinted, data.amtOwed);
	// }



	// // Storing NFT withdrawal data
	// mapping(uint256 => uint256[]) private nftIdWithdraws;
	
	// Billboard Variables
	string public billboard = "This Space for Sale";
	bool public premium = false;
	uint256 public totalCounter = 0;
	uint256 public basePrice = 150;
	uint256 public lastPrice = basePrice;
	uint256 public lastUpdateTime;
	uint256 public decreaseRate = 1;
	mapping(address => uint) public userBillboardCounter;


	// Events: a way to emit log statements from smart contract that can be listened to by external parties
	event BillboardChange(
		address indexed billboardSetter,
		string newBillboard,
		bool premium,
		uint256 value
	);

	event WithdrawalSuccessful(uint256 indexed epochNumber, uint256 indexed nftId, uint256 amountOwed);

	// Constructor: Called once on contract deployment
	// Check packages/hardhat/deploy/00_deploy_your_contract.ts
	
	// ScaffoldETH starter constructor
	// constructor(address _owner) {
	// 	owner = _owner;
	// 	lastUpdateTime = block.timestamp; // Set the last update time to the deployment time
	// }

	// Modifier: used to define a set of rules that must be met before or after a function is executed
	// Check the withdraw() function
	modifier isOwner() {
		// msg.sender: predefined variable that represents address of the account that called the current function
		require(msg.sender == owner, "Not the Owner");
		_;
	}

	event EpochUpdated(uint256 indexed epochIndex, uint256 nftsMinted, uint256 amtOwed);

	/**
	 * Function that allows anyone to change the state variable "billboard" of the contract and increase the counters
	 *
	 * @param _newBillboardMessage (string memory) - new billboard message to save on the contract
	 */
	function setBillboard(string memory _newBillboardMessage) public payable {
		// Print data to the hardhat chain console. Remove when deploying to a live network.
		console.log(
			"Setting new billboard '%s' from %s",
			_newBillboardMessage,
			msg.sender
		);

		uint256 adjustedPrice = getAdjustedPrice(); // 
		require(msg.value >= adjustedPrice, "Insufficient funds sent");

		// Change state variables
		billboard = _newBillboardMessage;
		totalCounter += 1;
		userBillboardCounter[msg.sender] += 1;
		lastPrice = msg.value + 1;
		lastUpdateTime = block.timestamp;


		// create a new epoch entry
		currentEpoch +=1; // move to next epoch

		// Calculate the amount owed per NFT, handling division by zero by setting amtOwed to 0 if no NFTs have been minted
    uint256 nftsMintedSoFar = _tokenIds.current();
    uint256 amtOwedPerNFT = nftsMintedSoFar > 0 ? msg.value / nftsMintedSoFar : 0;

		// Store the new epoch data
    epochs[currentEpoch] = epochData(nftsMintedSoFar, amtOwedPerNFT);
		emit EpochUpdated(currentEpoch, nftsMintedSoFar, amtOwedPerNFT);
		// emit: keyword used to trigger an event
		emit BillboardChange(msg.sender, _newBillboardMessage, msg.value > 0, 0);
	}

	function getAdjustedPrice() public view returns (uint256) {
    uint256 timeElapsed = block.timestamp - lastUpdateTime;
    uint256 decreaseAmount = timeElapsed * decreaseRate;

    uint256 proposedDecrease;
    if (lastPrice > decreaseAmount) {
        proposedDecrease = lastPrice - decreaseAmount;
    } else {
        // If subtracting would cause underflow, set proposedDecrease to basePrice
        proposedDecrease = basePrice;
    }

    uint256 adjustedPrice = proposedDecrease > basePrice ? proposedDecrease : basePrice;
    console.log("Adjusted price is:", adjustedPrice);
    return adjustedPrice;
	}

	/**
	 * Function that allows the owner to withdraw all the Ether in the contract
	 * The function can only be called by the owner of the contract as defined by the isOwner modifier
	 */
	// function withdraw() public isOwner {
	// 	(bool success, ) = owner.call{ value: address(this).balance }("");
	// 	require(success, "Failed to send Ether");
	// }


	function shareWithdraw(uint256 epochNumber, uint256 nftId) public {
		   
    require(ownerOf(nftId) == msg.sender, "Caller does not own the NFT"); // Verify the caller owns the NFT
    require(epochNumber <= currentEpoch, "Invalid epoch number"); // Ensure the epochNumber is valid
		require(!hasWithdrawn[epochNumber][nftId], "Already withdrawn");

    // Get the epoch data
    epochData storage data = epochs[epochNumber];

    // Ensure the NFT ID is within the range for the epoch
    require(nftId <= data.nftsMinted, "NFT ID is not eligible for this epoch");

    uint256 amountOwed = data.amtOwed; // Calculate the amount owed
		require(address(this).balance >= amountOwed, "Insufficient contract balance");

		// Mark as withdrawn
    hasWithdrawn[epochNumber][nftId] = true;

    // Transfer the amount owed to the caller
		Address.sendValue(payable(msg.sender), amountOwed);

    // Emitting successful withdrawal
		 emit WithdrawalSuccessful(epochNumber, nftId, amountOwed);
					
	}

	constructor(address _owner) ERC721("BillboardNFT", "BBNFT") {
        owner = _owner;
        lastUpdateTime = block.timestamp;
    }

    function mintNFT() public {

				// this is to limit NFT mints to 1 per address
				require(balanceOf(msg.sender) == 0, "Address already owns an NFT");

				// incrementing token ID
        _tokenIds.increment();
        uint256 newItemId = _tokenIds.current();
        _mint(msg.sender, newItemId);


        // Adjust the lastPrice by +10 as per requirement
        lastPrice += 10;

        console.log("Minted NFT ID %s to %s", newItemId, msg.sender);
    }

    // Override the _transfer function to prevent transfers
    function _transfer(
        address from,
        address to,
        uint256 tokenId
    ) internal override {
        revert("NFTs are non-transferable");
    }
	/**
	 * Function that allows the contract to receive ETH
	 */
	receive() external payable {}
}

