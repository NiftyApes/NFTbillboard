//SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

// Useful for debugging. Remove when deploying to a live network.

import "hardhat/console.sol";

// Use openzeppelin to inherit battle-tested implementations (ERC20, ERC721, etc)
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Address.sol";


/**
 * A simple billboard smartcontract, where a message state variable is for sale! Folks who mint the NFT 
 * opt in to be advertised to, and so are entitled to a cut from the proceeds
 * 
 * TODOS
 *  - Figure out refund for ads that are replaced too quickly that doesn't encourage too much sybling
 *  - 	- Idea: 10% Protocol Fee paid regardless, small window (1 hour?)
 * @author zherring
 */
contract YourContract is ERC721Enumerable, Ownable {

	// state variables
	uint256 public protocolFee = 10; // percentage protocol takes
	uint256 public protocolRevenue = 0; // protocol's revenue 

	// Epoch data, where I store the number of NFTs minted (will limit withdraws to NFT ids >= total minted) and the amount paid to track how much they're owed
	struct epochData {
		uint256 nftsMinted;
		uint256 amtOwed;
	}
	// storing epoch data
	mapping(uint256 => epochData) public epochs;
	uint256 public currentEpoch = 0;
	mapping(uint256 => mapping(uint256 => bool)) private hasWithdrawn;


	// NFT Data
	using Counters for Counters.Counter;
	Counters.Counter public _tokenIds;
	Counters.Counter private _activeTokens; // Active (non-burned) token count
	//// URI for all tokens
	string private _commonURI;


	function setCommonURI(string memory newURI) public onlyOwner {
			_commonURI = newURI;
	}

	function tokenURI(uint256 tokenId) public view override returns (string memory) {
			require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");
			return _commonURI;
    }
	// Storing NFT withdrawal data
	mapping(uint256 => uint256[]) private nftIdWithdraws;
	
	// Billboard Variables
	string public billboard = "This Space for Sale";
	string public billboardURL = "https://adframe.xyz";
	bool public premium = false;
	uint256 public totalCounter = 0;
	uint256 public basePrice = 270000000000000;
	uint256 public lastPrice = basePrice;
	uint256 public lastUpdateTime;
	uint256 public decreaseRate = 270000000000;
	uint256 public increaseRate = 2700000000000;
	mapping(address => uint) public userBillboardCounter;


	constructor(address _owner, string memory initialURI) ERC721("BillboardNFT", "BBNFT") {
        lastUpdateTime = block.timestamp;
				_commonURI = initialURI;
    }
	// Events
	event BillboardChange(
		address indexed billboardSetter,
		string newBillboard,
		string newBillboardURL,
		bool premium,
		uint256 value
	);

	event WithdrawalSuccessful(uint256 indexed epochNumber, uint256 indexed nftId, uint256 amountOwed);
	event EpochUpdated(uint256 indexed epochIndex, uint256 nftsMinted, uint256 amtOwed);

	/**
	 * Function that allows anyone to change the state variable "billboard" of the contract
	 *
	 * @param _newBillboardMessage (string memory) - new billboard message to save on the contract
	 * @param _newBillboardURL (string memory) - not required
	 */
	function setBillboard(string memory _newBillboardMessage, string memory _newBillboardURL ) public payable {
		// Print data to the hardhat chain console. Remove when deploying to a live network.
		console.log(
			"Setting new billboard '%s' from %s",
			_newBillboardMessage,
			_newBillboardURL,
			msg.sender
		);

		uint256 adjustedPrice = getAdjustedPrice(); // 
		require(msg.value >= adjustedPrice, "Insufficient funds sent");


		// Change state variables
		billboard = _newBillboardMessage;
		billboardURL = _newBillboardURL;
		lastPrice = msg.value + increaseRate;
		lastUpdateTime = block.timestamp;

		uint256 fee = msg.value * protocolFee / 100;
		protocolRevenue += fee;
		uint256 remainder = msg.value - fee;
		// create a new epoch entry
		currentEpoch +=1; // move to next epoch

		// Calculate the amount owed per NFT, handling division by zero by setting amtOwed to 0 if no NFTs have been minted
    uint256 nftsMintedSoFar = _activeTokens.current();
    uint256 amtOwedPerNFT = nftsMintedSoFar > 0 ? remainder / nftsMintedSoFar : 0;

		// Store the new epoch data
    epochs[currentEpoch] = epochData(nftsMintedSoFar, amtOwedPerNFT);
		emit EpochUpdated(currentEpoch, nftsMintedSoFar, amtOwedPerNFT);
		// emit: keyword used to trigger an event
		emit BillboardChange(msg.sender, _newBillboardMessage, _newBillboardURL, msg.value > 0, 0);
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

	function withdrawProtocolFees() public onlyOwner {
        uint256 amount = protocolRevenue;
        protocolRevenue = 0; // Reset the accumulated fees to 0

        // Transfer the accumulated fees to the owner
			(bool success, ) = payable(owner()).call{value: amount}("");
			require(success, "Transfer failed.");
    }

	function claimShare(uint256 epochNumber, uint256 nftId) public {
		   
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

	function claimShareAll(uint256 nftId) public {
    require(ownerOf(nftId) == msg.sender, "Caller does not own the NFT");

    uint256 totalShare = 0;

    for (uint256 epochNumber = 1; epochNumber <= currentEpoch; epochNumber++) {
        if (!hasWithdrawn[epochNumber][nftId] && nftId <= epochs[epochNumber].nftsMinted) {
            epochData storage data = epochs[epochNumber];

            uint256 amountOwed = data.amtOwed;
            require(address(this).balance >= amountOwed, "Insufficient contract balance");

            // Mark as withdrawn
            hasWithdrawn[epochNumber][nftId] = true;

            // Accumulate the amount owed
            totalShare += amountOwed;

            // Emitting successful withdrawal for each epoch
            emit WithdrawalSuccessful(epochNumber, nftId, amountOwed);
        }
    }

    // After calculating the total amount owed across all epochs, transfer it in a single transaction
    if (totalShare > 0) {
        Address.sendValue(payable(msg.sender), totalShare);
    }
}

    function mintNFT() public {
				// this is to limit NFT mints to 1 per address 
				require(balanceOf(msg.sender) == 0, "Address already owns an NFT");

				// incrementing token ID
        _tokenIds.increment();
        uint256 newItemId = _tokenIds.current();
        _mint(msg.sender, newItemId);

				// increment active token counter
				_activeTokens.increment();

        // Adjust the lastPrice by +10 as per requirement
        lastPrice += increaseRate;
        console.log("Minted NFT ID %s to %s", newItemId, msg.sender);
    }

		 /**
     * Function to allow the owner to change the billboard message.
     * @param _newBillboardMessage The new message to set on the billboard.
     * @param _newBillboardURL The new URL to set on the billboard.
     */
		function adminSetBillboardMessage(string memory _newBillboardMessage, string memory _newBillboardURL) public onlyOwner {
				if (bytes(_newBillboardMessage).length == 0) {
						billboard = "This Space for Sale"; // Default message
				} else {
						billboard = _newBillboardMessage;
				}

				if (bytes(_newBillboardURL).length == 0) {
						billboardURL = "https://adframe.xyz"; // Default URL
				} else {
						billboardURL = _newBillboardURL;
				}

				// Optionally, you can emit an event when the billboard message is changed by the admin
				emit BillboardChange(msg.sender, billboard, billboardURL, premium, 0);
		}

		function setProtocolFee(uint256 _newFeePercent) public onlyOwner {
        require(_newFeePercent <= 100, "Fee cannot exceed 100%");
        protocolFee = _newFeePercent;
    }

    // Override the _transfer function to prevent transfers
    function _transfer(
        address from,
        address to,
        uint256 tokenId
    ) internal override {
        revert("NFTs are non-transferable");
    }

		function burn(uint256 tokenId) public {
			require(ownerOf(tokenId) == msg.sender, "Caller is not the token owner");
			_burn(tokenId);

			_activeTokens.decrement();
		}

    function totalActiveTokens() public view returns (uint256) {
        return _activeTokens.current();
    }
	/**
	 * Function that allows the contract to receive ETH
	 */
	receive() external payable {}
}

